package hu.hungarianhardstyle.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.AudioPlaybackConfiguration
import android.media.MediaMetadata
import android.media.MediaPlayer
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.annotation.RequiresApi

/**
 * A Real Hardstyle FM rádió lejátszása előtér-szolgáltatásként.
 *
 * A tulajdonos jelzése: *„Rádiót nézzük meg mert volt rá panasz, hogy ha valaki
 * nincs belépve, 5 perc után megszakad… Cél az, hogy folyamatosan menjen a
 * rádió, ha be vagy lépve, ha nem"*.
 *
 * A MÉRT GYÖKÉR: a szolgáltatás **nem tartotta ébren a készüléket**. Streaming
 * lejátszásnál ez a klasszikus hiba: képernyő ki + nincs WAKE_LOCK → a CPU
 * elalszik, a hálózat elhallgat, és a stream a puffer kifogyása után megáll.
 * (Bejelentkezve az app egyéb hátterei időnként felébresztették a folyamatot,
 * ezért tűnt úgy, hogy „bejelentkezve jobb".)
 *
 * A JAVÍTÁS ÖT RÉSZE:
 *  1. `setWakeMode(PARTIAL_WAKE_LOCK)` a lejátszón, ÉS egy szolgáltatás-szintű
 *     wake lock, ami az **újracsatlakozás alatt is** tart (a MediaPlayer saját
 *     lockja ilyenkor elengedődik) — ezért szól a rádió **kikapcsolt képernyő**
 *     mellett is, amíg az app fut;
 *  2. nagy teljesítményű Wi-Fi lock, hogy a Wi-Fi energiatakarékos módja ne
 *     ejtse el a streamet;
 *  3. az URL is mentődik, és a rendszer által újraindított szolgáltatás
 *     (`START_STICKY`, `intent == null`) **folytatja** a lejátszást;
 *  4. a hiba/lezárás utáni újracsatlakozás változatlanul 3 másodperc;
 *  5. **hangfókusz**: más app (Spotify/YouTube) indulásakor elhallgatunk, és
 *     amint az befejezi, **magunktól folytatjuk** (`registerPlaybackWatcher`) —
 *     ezt a figyelést egy **korlátozott ideig** ébren tartó lock védi, hogy
 *     képernyő-ki mellett is működjön (lásd [acquireFocusWatchLock]).
 */
class RadioPlaybackService : Service() {
    private var player: MediaPlayer? = null
    private var streamUrl: String? = null
    private var volume = 1f
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var focusRequest: AudioFocusRequest? = null

    /**
     * A **zárképernyő** és az értesítés médiakártyája — 2026-10-01 (a tulajdonos
     * kérése: *„kiírhatná itt is a zenét ami szól + zárképernyőn is lehessen
     * látni a radio a real hardstyle fm logóval"*).
     *
     * ⚠️ MIÉRT KELL A `MediaSession`: a zárképernyő (és az Android 13+
     * médialejátszó-kártyája) a **MediaSession** metaadatából rajzol, NEM az
     * értesítés szövegéből. Enélkül a zárképernyőn csak az app neve látszik.
     */
    private var mediaSession: MediaSession? = null

    /** A most szóló szám és a következő (üres, ha a rádió nem küld címet). */
    private var trackTitle: String = ""
    private var trackNext: String = ""
    private val metadataHandler = Handler(Looper.getMainLooper())

    /**
     * A metaadat-frissítő kör: 20 másodpercenként újraolvassa a stream fejlécét.
     *
     * ⚠️ Azért NATÍV (nem a Dart-oldalról jön), mert a rádió **háttérben** is szól
     * — ilyenkor a Flutter-motor állhat, a szolgáltatás viszont fut. A Dart-oldal
     * csak akkor küld címet (`ACTION_METADATA`), ha az app épp nyitva van.
     *
     * ⚠️ A kör **lambda**, nem külön `Runnable`-alosztály: a rádió forrás-lintje
     * (`test/core/android_radio_service_test.dart`) a fókusz-őrkutya törzsét a
     * `run` függvény szövegéből keresi — egy második ilyen függvény elfedné azt
     * (ezt a kapu azonnal jelezte).
     */
    private val metadataRefresh: Runnable = Runnable { refreshMetadata() }

    private fun refreshMetadata() {
        if (!isPlaybackRequested()) return
        Thread {
            val track = runCatching { RadioMetadataReader.fetch() }.getOrNull()
            if (track != null && !track.isEmpty && track.title != trackTitle) {
                trackTitle = track.title
                trackNext = track.next
                metadataHandler.post { applyMetadata() }
            }
            if (isPlaybackRequested()) {
                metadataHandler.postDelayed(metadataRefresh, METADATA_REFRESH_MS)
            }
        }.start()
    }

    /**
     * Elhallgattunk-e azért, mert egy MÁSIK app (Spotify/YouTube) **véglegesen**
     * elvette a fókusz? Ilyenkor a lejátszási **szándék megmarad**, és amint a
     * másik app abbahagyja, magunktól folytatjuk (lásd
     * [registerPlaybackWatcher] és [resumeAfterFocusLoss]).
     */
    private var pausedByFocus = false

    /**
     * A rendszer lejátszás-figyelője. **Szándékosan `null`** az alapértéke, és a
     * példány is csak API 26-tól jön létre: a `AudioPlaybackCallback` osztály a
     * régebbi Androidokon nem létezik, ezért nem lehet mezőinicializálóban
     * példányosítani (az a szolgáltatás létrehozásakor **azonnal** lefutna, és a
     * régi készülékeken `NoClassDefFoundError`-ral elhasalna az app).
     */
    private var playbackWatcher: AudioManager.AudioPlaybackCallback? = null

    private val audioManager by lazy {
        getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    /**
     * „SZÓLJON TOVÁBB, HA A SPOTIFY BEFEJEZTE" — a tulajdonos kérése:
     * *„ha megy a háttérben a rádió és valaki elindít pl egy spotifyt, akkor
     * kussoljon be a rádió, ha kikapcsolja a spotifyt, vagy youtubeot, stb,
     * menjen tovább a rádió"*.
     *
     * MIÉRT KELL EZ: a fókusz **végleges** elvesztése után az Android **nem**
     * küld vissza `AUDIOFOCUS_GAIN`-t (a másik app „elvette", nem ideiglenesen
     * vette el), ezért magunktól kell visszaszereznünk. Új fókuszt kérni viszont
     * csak akkor szabad, ha a másik app **már nem játszik** — különben elvennénk
     * tőle a fókuszt, ami pont az ellenkezője annak, amit a tulajdonos kért.
     *
     * EZT KÉT ÚTON FIGYELJÜK, és mindkettő ugyanazt a döntést hívja:
     *  1. `registerAudioPlaybackCallback` (API 26+) — **azonnal** szól, amikor a
     *     rendszer lejátszás-listája változik (a másik app abbahagyta);
     *  2. `focusWatchdog` — 2 másodpercenként **megkérdezi** a publikus
     *     `AudioManager.isMusicActive()`-et. Ez azért kell, mert a visszahívás
     *     nem garantált minden készüléken, és mert az „aktív-e egy másik
     *     lejátszás" kérdésre a rendszer-API-k (`isActive`, `getClientUid`)
     *     **nem fordulnak le** — a szándék- és UID-alapú szűrés nem járható út.
     */
    @RequiresApi(Build.VERSION_CODES.O)
    private fun registerPlaybackWatcher() {
        if (playbackWatcher != null) return
        val watcher = object : AudioManager.AudioPlaybackCallback() {
            override fun onPlaybackConfigChanged(configs: MutableList<AudioPlaybackConfiguration>?) {
                // A lista csak RIAKASZTÁS: a döntést a közös út hozza.
                resumeAfterFocusLoss()
            }
        }
        playbackWatcher = watcher
        audioManager.registerAudioPlaybackCallback(watcher, Handler(Looper.getMainLooper()))
    }

    /**
     * Ha a rádió csak **elhallgatott** (más app elvette a fókuszt), és a másik
     * app már nem játszik, akkor fókuszt kérünk és **folytatjuk**.
     *
     * Szándékos védelem: amíg a másik app szól (`isMusicActive`), **nem**
     * kérünk fókuszt — különben elhallgattatnánk azt, amit a felhasználó
     * éppen hallgat.
     */
    private fun resumeAfterFocusLoss() {
        if (!pausedByFocus || !isPlaybackRequested()) return
        val url = streamUrl
        if (url.isNullOrBlank()) return
        // ⚠️ HÍVÁS VÉDELME: hívás közben a rendszer „mode"-ja IN_CALL /
        // IN_COMMUNICATION, ilyenkor a zene-stream NEM aktív, ezért a
        // `isMusicActive` önmagában nem védené meg a hívást — a rádió
        // beleszólna. Ez a kapu publikus API, nem kell hozzá engedély.
        val mode = audioManager.mode
        if (mode == AudioManager.MODE_IN_CALL || mode == AudioManager.MODE_IN_COMMUNICATION) return
        val musicPlaying = runCatching { audioManager.isMusicActive }.getOrDefault(true)
        if (musicPlaying) return
        if (!requestAudioFocus()) return
        reconnectHandler.removeCallbacks(focusWatchdog)
        pausedByFocus = false
        // Az értesítés frissítése nem kötelező (a szolgáltatás végig előtérben
        // maradt), de gondoskodunk róla, hogy ott legyen.
        runCatching { startForeground(NOTIFICATION_ID, notification()) }
        startPlayer(url)
    }

    /** 2 másodpercenként megkérdezi, folytathatjuk-e (lásd [resumeAfterFocusLoss]). */
    private val focusWatchdog = object : Runnable {
        override fun run() {
            // Ha közben leállt a rádió, nincs mit figyelni — így nem pörög tovább.
            if (!isPlaybackRequested()) return
            resumeAfterFocusLoss()
            if (pausedByFocus) reconnectHandler.postDelayed(this, FOCUS_RETRY_DELAY_MS)
        }
    }

    private fun unregisterPlaybackWatcher() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        playbackWatcher?.let { audioManager.unregisterAudioPlaybackCallback(it) }
        playbackWatcher = null
    }

    /** MÁS APP hangja: elhallgatunk, majd folytatjuk (lásd [registerPlaybackWatcher]). */
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS -> pauseForFocusLoss(permanent = true)
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> pauseForFocusLoss(permanent = false)
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> player?.setVolume(0.2f, 0.2f)
            AudioManager.AUDIOFOCUS_GAIN -> {
                pausedByFocus = false
                reconnectHandler.removeCallbacks(focusWatchdog)
                player?.setVolume(volume, volume)
                val url = streamUrl
                if (isPlaybackRequested() && !url.isNullOrBlank()) {
                    startForeground(NOTIFICATION_ID, notification())
                    startPlayer(url)
                }
            }
        }
    }
    private val reconnectHandler = Handler(Looper.getMainLooper())
    private val reconnect = Runnable {
        streamUrl?.takeIf { isPlaybackRequested() }?.let(::startPlayer)
    }

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Real Hardstyle FM", NotificationManager.IMPORTANCE_LOW),
            )
        }
        createMediaSession()
        streamUrl = preferences().getString(KEY_URL, null)
        // A fókusz visszaszerzéséhez figyelni kell, mikor hagyja abba a MÁSIK
        // app a lejátszást (lásd [registerPlaybackWatcher]). API 26-tól elérhető.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            registerPlaybackWatcher()
        }
    }

    /**
     * A médiamunkamenet létrehozása: ebből lesz a zárképernyő kártyája, és innen
     * vezérelhető a lejátszás (fejhallgató-gomb, autó, óra).
     */
    private fun createMediaSession() {
        if (mediaSession != null) return
        mediaSession = MediaSession(this, "huhs-radio").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() {
                    val url = streamUrl ?: RadioMetadataReader.STREAM_URL
                    if (!isPlaybackRequested()) play(url) else startPlayer(url)
                }

                override fun onPause() {
                    // ⚠️ A szünet NEM viszi el a vezérlőt (lásd `pauseRadio`) — a
                    // tulajdonos jelzése: *„néha eltűnik az értesítési mezőből a
                    // rádió vezérlője”*.
                    pauseRadio()
                }

                override fun onStop() {
                    stopEverything()
                }

                /**
                 * ⚠️ A „Leállítás" gomb a **médiakártyán** (zárképernyő, gyors
                 * beállítások) ezen az úton jön: a kártya a PlaybackState
                 * **egyedi akcióit** is kirajzolja, és a rendszer ezt a
                 * visszahívást hívja meg. A tulajdonos jelzése: *„nincs stop
                 * gomb, a zárképernyőn sincs"*.
                 */
                override fun onCustomAction(action: String, extras: Bundle?) {
                    if (action == CUSTOM_ACTION_STOP) stopEverything()
                }
            })
            isActive = true
        }
        applyMetadata()
    }

    /**
     * Teljes leállítás EGY helyen: a lejátszó, a hangfókusz, az értesítés és a
     * szolgáltatás is lezárul. Ezt hívja a médiakártya stop-gombja, a
     * fejhallgató-gomb (`onStop`), a `ACTION_STOP` intent és a „Lomtárba húzás”.
     */
    private fun stopEverything() {
        stopPlayer()
        runCatching { stopForeground(STOP_FOREGROUND_REMOVE) }
        stopSelf()
    }

    /**
     * A „Leállítás" művelet, amit a **médiakártya** és az **értesítés** is kap.
     *
     * Két csatornán adjuk át, mert a rendszerek máshonnan rajzolnak:
     *  * az **értesítés** akció-sora (`Notification.Action`) — az árnyékolt
     *    értesítésben és a kompakt sorban látszik;
     *  * a **PlaybackState egyedi akciója** — a médiakártya (zárképernyő,
     *    gyors beállítások) ebből rajzol.
     */
    private fun stopPendingIntent(): PendingIntent {
        val intent = Intent(this, RadioPlaybackService::class.java).setAction(ACTION_STOP)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        return PendingIntent.getService(this, 2, intent, flags)
    }

    /**
     * A **szünet/folytatás** gomb (az értesítés akció-sora) — a tulajdonos
     * jelzése: *„kéne egy pause gomb is az értesítési és a zárképernyős rádió
     * vezérlőre”*.
     */
    private fun togglePausePendingIntent(): PendingIntent {
        val intent = Intent(this, RadioPlaybackService::class.java).setAction(ACTION_TOGGLE_PAUSE)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        return PendingIntent.getService(this, 3, intent, flags)
    }

    /**
     * Szünet: a hang elhallgat, de a **vezérlő megmarad**.
     *
     * ⚠️ MIÉRT (a tulajdonos jelzése, 2026-10-03): *„néha eltűnik az értesítési
     * mezőből a rádió vezérlője”*. A szünet eddig `stopForeground(STOP_FOREGROUND_REMOVE)`
     * volt (a munkamenet `onPause`-ában), ezért a kártya **eltűnt** — utána csak az
     * appból lehetett újraindítani. Mostantól a szünet **megtartja** az értesítést
     * („Folytatás” gombbal), így a vezérlő mindig ott marad.
     */
    private fun pauseRadio() {
        preferences().edit().putBoolean(KEY_PAUSED, true).apply()
        reconnectHandler.removeCallbacks(reconnect)
        reconnectHandler.removeCallbacks(focusWatchdog)
        stopMetadataRefresh()
        releasePlayer()
        releaseLocks()
        abandonAudioFocus()
        applyMetadata()
        runCatching { startForeground(NOTIFICATION_ID, notification()) }
    }

    /**
     * A metaadat kiírása a **médiamunkamenetbe** (zárképernyő) ÉS az
     * **értesítésbe** — egy helyen, hogy a kettő ne tudjon széttartani.
     */
    private fun applyMetadata() {
        val session = mediaSession ?: return
        val title = trackTitle.ifBlank { "Real Hardstyle FM" }
        runCatching {
            session.setMetadata(
                MediaMetadata.Builder()
                    .putString(MediaMetadata.METADATA_KEY_TITLE, title)
                    .putString(MediaMetadata.METADATA_KEY_ARTIST, "Real Hardstyle FM")
                    .putString(MediaMetadata.METADATA_KEY_ALBUM, "Real Hardstyle Radio")
                    .putBitmap(
                        MediaMetadata.METADATA_KEY_ALBUM_ART,
                        BitmapFactory.decodeResource(resources, R.drawable.realhardstyle_logo),
                    )
                    .build(),
            )
            session.setPlaybackState(
                PlaybackState.Builder()
                    .setActions(
                        PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or
                            PlaybackState.ACTION_PLAY_PAUSE or PlaybackState.ACTION_STOP,
                    )
                    // A „Leállítás" a médiakártyán (zárképernyő, gyors beállítások).
                    // ⚠️ A `CustomAction.Builder` ikonja **erőforrás-azonosító**
                    // (nem `Icon`) — ez a framework API-ja.
                    .addCustomAction(
                        PlaybackState.CustomAction.Builder(
                            CUSTOM_ACTION_STOP,
                            "Leállítás",
                            R.drawable.ic_radio_stop,
                        ).build(),
                    )
                    .setState(
                        if (player?.isPlaying == true) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,
                        PlaybackState.PLAYBACK_POSITION_UNKNOWN,
                        1f,
                    )
                    .build(),
            )
        }
        if (isPlaybackRequested()) {
            runCatching { startForeground(NOTIFICATION_ID, notification()) }
        }
    }

    private fun startMetadataRefresh() {
        metadataHandler.removeCallbacks(metadataRefresh)
        metadataHandler.post(metadataRefresh)
    }

    private fun stopMetadataRefresh() {
        metadataHandler.removeCallbacks(metadataRefresh)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> play(intent.getStringExtra(EXTRA_URL))
            ACTION_STOP -> {
                stopPlayer()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            // Szünet a felületről (`pause` a `hu_hs/radio` csatornán): ugyanaz,
            // mint az értesítés szünet gombja — a vezérlő megmarad.
            ACTION_PAUSE -> pauseRadio()
            ACTION_VOLUME -> {
                volume = intent.getFloatExtra(EXTRA_VOLUME, 1f)
                player?.setVolume(volume, volume)
            }
            // A szünet/folytatás gomb (az értesítés akció-sora).
            ACTION_TOGGLE_PAUSE -> {
                if (player?.isPlaying == true) {
                    pauseRadio()
                } else {
                    val url = streamUrl
                        ?: preferences().getString(KEY_URL, null)
                        ?: RadioMetadataReader.STREAM_URL
                    play(url)
                }
            }
            // A Dart-oldal (a felület) küldi a címet, amikor az app nyitva van —
            // ilyenkor nincs okunk külön hálózati kört indítani.
            ACTION_METADATA -> {
                val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
                val next = intent.getStringExtra(EXTRA_NEXT).orEmpty()
                if (title.isNotBlank() && title != trackTitle) {
                    trackTitle = title
                    trackNext = next
                    applyMetadata()
                }
            }
            else -> {
                // A rendszer indította újra a szolgáltatást (nincs intent): ha a
                // lejátszás be volt kapcsolva, folytatjuk — a rádió folyamatos.
                if (isPlaybackRequested() && !streamUrl.isNullOrBlank()) {
                    startForeground(NOTIFICATION_ID, notification())
                    if (requestAudioFocus()) {
                        pausedByFocus = false
                        startPlayer(streamUrl!!)
                    }
                } else {
                    stopSelf()
                }
            }
        }
        return START_STICKY
    }

    private fun play(url: String?) {
        if (url.isNullOrBlank()) return
        streamUrl = url
        preferences().edit().putBoolean(KEY_PLAYING, true).putBoolean(KEY_PAUSED, false).putString(KEY_URL, url).apply()
        reconnectHandler.removeCallbacks(reconnect)
        startForeground(NOTIFICATION_ID, notification())
        startMetadataRefresh()
        if (!requestAudioFocus()) {
            // Ha egy másik app éppen hangot játszik, és nem kapjuk meg a fókuszt,
            // nem játszunk rá a másikra — a felhasználó koppintott, ezért
            // megpróbáljuk, de a fókusz megszerzése nélkül nem indulunk el.
            return
        }
        pausedByFocus = false
        startPlayer(url)
    }

    /**
     * HANGFÓKUSZ — a tulajdonos kérése: *„ha megy a rádió, de valaki telefonon
     * elindítja a spotifyt vagy a youtubeot, szól tovább a rádió, közben el kéne
     * hallgatnia"*.
     *
     * Enélkül a rádió **soha nem kap jelzést** arról, hogy más app hangot indít.
     * Ezért kérünk fókuszt, és a változásra:
     *  - **végleges elvesztés** (Spotify/YouTube elindul): a rádió **elhallgat**,
     *    de **nem adja fel** — amint a másik app abbahagyja, a [registerPlaybackWatcher]
     *    visszaszerzi a fókuszt és **folytatja** (a tulajdonos kérése);
     *  - **ideiglenes elvesztés** (hívás, navigáció): szünet, majd a fókusz
     *    visszakapásakor **folytatja** (ez a rádióknál megszokott viselkedés);
     *  - **halkítás** (duck): lehalkítjuk, majd visszaállítjuk a hangerőt.
     */
    private fun requestAudioFocus(): Boolean {
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = focusRequest ?: AudioFocusRequest
                .Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(focusListener)
                .build()
                .also { focusRequest = it }
            audioManager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                focusListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN,
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(focusListener)
        }
    }

    /**
     * MÁS APP elvette a hangot: **elhallgatunk, de nem adjuk fel**.
     *
     * A lejátszási SZÁNDÉK megmarad (`playing` igaz, az URL mentve), a fókusz
     * kérése pedig a helyén marad — ezért tudunk magunktól folytatni:
     *  - **végleges** elvesztésnél (Spotify/YouTube „elvette") a rendszer
     *    **nem** küld semmit, ezért a [registerPlaybackWatcher] és a
     *    [focusWatchdog] figyeli, mikor hagyja abba a másik app, és akkor kér
     *    fókuszt újra;
     *  - **ideiglenes** elvesztésnél (hívás, navigáció) a rendszer **küldi** a
     *    `AUDIOFOCUS_GAIN`-t, ezért itt **nem** indítunk őrkutyát: az csak
     *    ártana, mert hívás közben a zene-stream nem aktív, és a 2
     *    másodpercenkénti próbálkozás visszavenné a fókuszt a hívástól.
     *
     * A szolgáltatás **fut tovább** (az értesítés is megmarad), csak a hang
     * hallgat el — így nem kell újraindítani a lejátszást a felhasználónak.
     */
    private fun pauseForFocusLoss(permanent: Boolean) {
        reconnectHandler.removeCallbacks(reconnect)
        releasePlayer()
        // A hang elhallgat, de a CPU **ébren marad**: különben kikapcsolt
        // képernyő mellett az őrkutya nem futna le, és a rádió némán maradna
        // akkor is, amikor a másik app már abbahagyta.
        acquireFocusWatchLock()
        // ⚠️ SZÁNDÉKOS: a jelző csak a VÉGLEGES elvesztést jelöli, mert csak
        // akkor kell magunknak visszaszereznünk a fókuszt. Ideiglenes
        // elvesztésnél (hívás) a rendszer küldi a `AUDIOFOCUS_GAIN`-t, és ha a
        // jelző bekapcsolva maradna, az őrkutya hívás közben visszavenné a
        // fókuszt a hívástól.
        pausedByFocus = permanent
        if (!permanent) return
        // Csak a végleges elvesztésnél figyelünk — lásd a fenti indoklást.
        reconnectHandler.removeCallbacks(focusWatchdog)
        reconnectHandler.postDelayed(focusWatchdog, FOCUS_RETRY_DELAY_MS)
    }

    private fun startPlayer(url: String) {
        releasePlayer()
        acquireLocks()
        player = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            setOnPreparedListener { start() }
            setOnCompletionListener { scheduleReconnect() }
            setOnErrorListener { _, _, _ ->
                scheduleReconnect()
                true
            }
            try {
                // A lejátszó saját ébrentartása: képernyő-ki mellett is szól.
                setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
                setDataSource(url)
                prepareAsync()
                setVolume(volume, volume)
            } catch (_: Exception) {
                scheduleReconnect()
            }
        }
    }

    private fun scheduleReconnect() {
        releasePlayer()
        reconnectHandler.removeCallbacks(reconnect)
        if (isPlaybackRequested()) {
            // A lockot SZÁNDÉKOSAN nem engedjük el: az újracsatlakozás is
            // ébren fut, különben a képernyő-ki melletti újrapróbálkozás
            // elaludna, és a rádió némán megállna.
            reconnectHandler.postDelayed(reconnect, RECONNECT_DELAY_MS)
        } else {
            releaseLocks()
        }
    }

    // ⚠️ A SZÜNET (2026-10-03) külön állapot: a `KEY_PLAYING` marad (ettől marad
    // életben az értesítés és a szolgáltatás), de a `KEY_PAUSED` jelzi, hogy a
    // felhasználó **szándékosan** állította meg — ilyenkor nem folytatjuk magunktól
    // (fókusz-visszaszerzés, újraindítás), és nem frissítjük a metaadatot sem.
    private fun isPlaybackRequested() =
        preferences().getBoolean(KEY_PLAYING, false) && !preferences().getBoolean(KEY_PAUSED, false)

    /**
     * Streameléshez: a CPU **korlátlanul** ébren marad, és a Wi-Fi is nagy
     * teljesítményen megy. Ez az, ami miatt a rádió **kikapcsolt képernyő**
     * mellett is szól — enélkül a CPU elaludna, és a stream a puffer kifogyása
     * után megállna (ez volt a bejelentett hiba).
     */
    private fun acquireLocks() {
        if (wakeLock == null) {
            wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG)
                .apply { setReferenceCounted(false) }
        }
        // Ha épp egy KORLÁTOZOTT lockot tartunk (fókusz-figyelés), lecseréljük
        // korlátlanra: streamelés közben nem járhat le a lock.
        wakeLock?.let { lock ->
            if (lock.isHeld) lock.release()
            lock.acquire()
        }
        if (wifiLock == null) {
            wifiLock = (applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager)
                .createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, WIFI_LOCK_TAG)
                .apply { setReferenceCounted(false) }
        }
        wifiLock?.takeIf { !it.isHeld }?.acquire()
    }

    /**
     * Fókusz miatti elhallgatás: **a CPU ébren marad**, hogy a 2 másodperces
     * őrkutya kikapcsolt képernyő mellett is lefusson, és a rádió magától
     * folytatódjon, amint a másik app abbahagyja.
     *
     * KÉT SZÁNDÉKOS KORLÁT:
     *  1. a Wi-Fi lockot **elengedjük** (nem streamelünk) — a folytatásnál a
     *     [acquireLocks] úgyis visszaszerzi;
     *  2. a CPU-lock **korlátozott ideig** tart ([FOCUS_WATCH_WAKE_LOCK_MS]),
     *     hogy egy elfeledett szünet (pl. a felhasználó egy órán át Spotify-t
     *     hallgat) ne fogyassza a telepet. Ha lejár, az őrkutya a következő
     *     ébredésnél (képernyő be) folytatja — a rádió tehát nem veszik el.
     */
    private fun acquireFocusWatchLock() {
        if (wakeLock == null) {
            wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG)
                .apply { setReferenceCounted(false) }
        }
        wakeLock?.let { lock ->
            if (lock.isHeld) lock.release()
            lock.acquire(FOCUS_WATCH_WAKE_LOCK_MS)
        }
        wifiLock?.let { if (it.isHeld) it.release() }
    }

    private fun releaseLocks() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wifiLock?.let { if (it.isHeld) it.release() }
    }

    private fun releasePlayer() {
        player?.runCatching {
            setOnPreparedListener(null)
            setOnCompletionListener(null)
            setOnErrorListener(null)
            reset()
        }
        player?.release()
        player = null
    }

    private fun stopPlayer() {
        preferences().edit().putBoolean(KEY_PLAYING, false).putBoolean(KEY_PAUSED, false).remove(KEY_URL).apply()
        reconnectHandler.removeCallbacks(reconnect)
        reconnectHandler.removeCallbacks(focusWatchdog)
        stopMetadataRefresh()
        streamUrl = null
        pausedByFocus = false
        releasePlayer()
        releaseLocks()
        abandonAudioFocus()
    }

    private fun preferences() = getSharedPreferences(PREFS, MODE_PRIVATE)

    private fun notification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        // ⚠️ A CÍM a most szóló szám (a tulajdonos kérése); amíg nincs metaadat,
        // a rádió neve áll ott — így a kártya sosem üres.
        builder
            .setContentTitle(trackTitle.ifBlank { "Real Hardstyle FM" })
            .setContentText("Real Hardstyle FM")
            .setSmallIcon(R.drawable.ic_stat_huhs)
            .setLargeIcon(BitmapFactory.decodeResource(resources, R.drawable.realhardstyle_logo))
            .setColor(Color.rgb(242, 56, 61))
            .setOngoing(true)
            .setShowWhen(false)
        if (trackNext.isNotBlank()) {
            builder.setSubText("Következő: $trackNext")
        }
        // A médiakártya-stílus köti össze az értesítést a zárképernyőn megjelenő
        // munkamenettel (és a fejhallgató-gombbal).
        //
        // ⚠️ A GOMBOK (a tulajdonos jelzése, 2026-10-03): *„kéne egy pause gomb is
        // az értesítési és a zárképernyős rádió vezérlőre”*. Eddig **csak** a
        // „Leállítás” volt az akció-sorban, és a `setShowActionsInCompactView(0)`
        // miatt a kompakt nézetben (árnyékolt sor, zárképernyő) is csak az
        // látszott — a play/pause **eltűnt** onnan.
        //
        // Mostantól két akció van, és MINDKETTŐ látszik a kompakt nézetben:
        //   0 = szünet/folytatás (állapotfüggő felirattal és ikonnal),
        //   1 = leállítás.
        val playing = player?.isPlaying == true
        builder.addAction(
            Notification.Action.Builder(
                Icon.createWithResource(
                    this,
                    if (playing) R.drawable.ic_radio_pause else R.drawable.ic_radio_play,
                ),
                if (playing) "Szüneteltetés" else "Folytatás",
                togglePausePendingIntent(),
            ).build(),
        )
        builder.addAction(
            Notification.Action.Builder(
                Icon.createWithResource(this, R.drawable.ic_radio_stop),
                "Leállítás",
                stopPendingIntent(),
            ).build(),
        )
        mediaSession?.let { session ->
            builder.setStyle(
                Notification.MediaStyle()
                    .setMediaSession(session.sessionToken)
                    .setShowActionsInCompactView(0, 1),
            )
        }
        return builder.build()
    }

    override fun onDestroy() {
        stopPlayer()
        stopMetadataRefresh()
        runCatching { mediaSession?.release() }
        mediaSession = null
        unregisterPlaybackWatcher()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // ⚠️ A „Lomtárba húzás” eddig **leállította** a rádiót (és az értesítést is
        // eltüntette) — a tulajdonos jelzése szerint viszont *„néha eltűnik az
        // értesítési mezőből a rádió vezérlője”*. A rádió mostantól **fut
        // tovább** (mint egy zenelejátszó), és a vezérlő is megmarad; csak akkor
        // zárul le, ha a felhasználó tényleg leállította.
        if (!isPlaybackRequested()) {
            stopPlayer()
            runCatching { stopForeground(STOP_FOREGROUND_REMOVE) }
            stopSelf()
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_PLAY = "hu.hungarianhardstyle.app.radio.PLAY"
        const val ACTION_STOP = "hu.hungarianhardstyle.app.radio.STOP"

        /**
         * A **felületről** kért szünet (`pause` a `hu_hs/radio` csatornán) — a
         * tulajdonos jelzése: *„kéne egy pause gomb is az értesítési és a
         * zárképernyős rádió vezérlőre”*. Ugyanazt teszi, mint az értesítés
         * szünet gombja: a hang elhallgat, a vezérlő **megmarad**.
         */
        const val ACTION_PAUSE = "hu.hungarianhardstyle.app.radio.PAUSE"
        const val ACTION_VOLUME = "hu.hungarianhardstyle.app.radio.VOLUME"

        /** A szünet/folytatás gomb az értesítés akció-sorából. */
        const val ACTION_TOGGLE_PAUSE = "hu.hungarianhardstyle.app.radio.TOGGLE_PAUSE"

        /**
         * A médiakártya „Leállítás" gombjának azonosítója (a PlaybackState
         * egyedi akciója) — a rendszer ezt küldi vissza az `onCustomAction`-ben.
         */
        const val CUSTOM_ACTION_STOP = "hu.hungarianhardstyle.app.radio.CUSTOM_STOP"

        /** A felület által küldött „most szól" cím (lásd [applyMetadata]). */
        const val ACTION_METADATA = "hu.hungarianhardstyle.app.radio.METADATA"
        const val EXTRA_URL = "url"
        const val EXTRA_VOLUME = "volume"
        const val EXTRA_TITLE = "title"
        const val EXTRA_NEXT = "next"
        private const val PREFS = "huhs_radio"
        private const val KEY_PLAYING = "playing"
        private const val KEY_URL = "url"

        /**
         * A **szünet** jelzője (2026-10-03) — a tulajdonos kérése: *„kéne egy pause
         * gomb is az értesítési és a zárképernyős rádió vezérlőre”*. A `KEY_PLAYING`
         * marad (ettől él az értesítés), de ez a jelző mondja meg, hogy a
         * felhasználó **szándékosan** állította meg — ilyenkor nem folytatjuk
         * magunktól (fókusz-visszaszerzés, rendszer-újraindítás).
         */
        private const val KEY_PAUSED = "paused"
        private const val WAKE_LOCK_TAG = "huhs:radio"
        private const val WIFI_LOCK_TAG = "huhs:radio-wifi"
        private const val CHANNEL_ID = "huhs_radio"
        private const val NOTIFICATION_ID = 421
        private const val RECONNECT_DELAY_MS = 3_000L
        private const val FOCUS_RETRY_DELAY_MS = 2_000L
        private const val FOCUS_WATCH_WAKE_LOCK_MS = 20 * 60 * 1_000L

        /** A „most szól" frissítés üteme — a rádió blokkonként ~4 másodpercnyi hangot küld. */
        private const val METADATA_REFRESH_MS = 20_000L
    }
}
