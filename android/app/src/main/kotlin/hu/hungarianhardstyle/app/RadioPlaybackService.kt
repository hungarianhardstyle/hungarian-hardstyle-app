package hu.hungarianhardstyle.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.AudioPlaybackConfiguration
import android.media.MediaPlayer
import android.net.wifi.WifiManager
import android.os.Build
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
 * A JAVÍTÁS NÉGY RÉSZE:
 *  1. `setWakeMode(PARTIAL_WAKE_LOCK)` a lejátszón, ÉS egy szolgáltatás-szintű
 *     wake lock, ami az **újracsatlakozás alatt is** tart (a MediaPlayer saját
 *     lockja ilyenkor elengedődik);
 *  2. nagy teljesítményű Wi-Fi lock, hogy a Wi-Fi energiatakarékos módja ne
 *     ejtse el a streamet;
 *  3. az URL is mentődik, és a rendszer által újraindított szolgáltatás
 *     (`START_STICKY`, `intent == null`) **folytatja** a lejátszást;
 *  4. a hiba/lezárás utáni újracsatlakozás változatlanul 3 másodperc;
 *  5. **hangfókusz**: más app (Spotify/YouTube) indulásakor elhallgatunk, és
 *     amint az befejezi, **magunktól folytatjuk** (`registerPlaybackWatcher`).
 */
class RadioPlaybackService : Service() {
    private var player: MediaPlayer? = null
    private var streamUrl: String? = null
    private var volume = 1f
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var focusRequest: AudioFocusRequest? = null

    /**
     * Elhallgattunk-e azért, mert egy MÁSIK app (Spotify/YouTube) elvette a
     * fókusz? Ilyenkor a lejátszási **szándék megmarad**, és amint a másik app
     * abbahagyja, folytatjuk (lásd [registerPlaybackWatcher]).
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
            AudioManager.AUDIOFOCUS_LOSS -> pauseForFocusLoss()
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> pauseForFocusLoss()
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
        streamUrl = preferences().getString(KEY_URL, null)
        // A fókusz visszaszerzéséhez figyelni kell, mikor hagyja abba a MÁSIK
        // app a lejátszást (lásd [registerPlaybackWatcher]). API 26-tól elérhető.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            registerPlaybackWatcher()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> play(intent.getStringExtra(EXTRA_URL))
            ACTION_STOP -> {
                stopPlayer()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            ACTION_VOLUME -> {
                volume = intent.getFloatExtra(EXTRA_VOLUME, 1f)
                player?.setVolume(volume, volume)
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
        preferences().edit().putBoolean(KEY_PLAYING, true).putString(KEY_URL, url).apply()
        reconnectHandler.removeCallbacks(reconnect)
        startForeground(NOTIFICATION_ID, notification())
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
     *  - **ideiglenes** elvesztésnél a rendszer küldi a `AUDIOFOCUS_GAIN`-t;
     *  - **végleges** elvesztésnél (Spotify/YouTube „elvette") a rendszer
     *    **nem** küld semmit, ezért a [registerPlaybackWatcher] figyeli, mikor hagyja
     *    abba a másik app, és akkor kér fókuszt újra.
     *
     * A szolgáltatás **fut tovább** (az értesítés is megmarad), csak a hang
     * hallgat el — így nem kell újraindítani a lejátszást a felhasználónak.
     */
    private fun pauseForFocusLoss() {
        reconnectHandler.removeCallbacks(reconnect)
        releasePlayer()
        releaseLocks()
        pausedByFocus = true
        // Amíg a másik app szól, figyeljük, mikor hagyja abba (lásd
        // [resumeAfterFocusLoss]) — és a visszahívás mellett a 2 másodperces
        // őrkutya is indul, mert a visszahívás nem garantált.
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

    private fun isPlaybackRequested() = preferences().getBoolean(KEY_PLAYING, false)

    private fun acquireLocks() {
        if (wakeLock == null) {
            wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG)
                .apply { setReferenceCounted(false) }
        }
        wakeLock?.takeIf { !it.isHeld }?.acquire()
        if (wifiLock == null) {
            wifiLock = (applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager)
                .createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, WIFI_LOCK_TAG)
                .apply { setReferenceCounted(false) }
        }
        wifiLock?.takeIf { !it.isHeld }?.acquire()
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
        preferences().edit().putBoolean(KEY_PLAYING, false).remove(KEY_URL).apply()
        reconnectHandler.removeCallbacks(reconnect)
        reconnectHandler.removeCallbacks(focusWatchdog)
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
        return builder
            .setContentTitle("Real Hardstyle FM")
            .setContentText("Real Hardstyle FM")
            .setSmallIcon(R.drawable.ic_stat_huhs)
            .setColor(Color.rgb(242, 56, 61))
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        stopPlayer()
        unregisterPlaybackWatcher()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopPlayer()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_PLAY = "hu.hungarianhardstyle.app.radio.PLAY"
        const val ACTION_STOP = "hu.hungarianhardstyle.app.radio.STOP"
        const val ACTION_VOLUME = "hu.hungarianhardstyle.app.radio.VOLUME"
        const val EXTRA_URL = "url"
        const val EXTRA_VOLUME = "volume"
        private const val PREFS = "huhs_radio"
        private const val KEY_PLAYING = "playing"
        private const val KEY_URL = "url"
        private const val WAKE_LOCK_TAG = "huhs:radio"
        private const val WIFI_LOCK_TAG = "huhs:radio-wifi"
        private const val CHANNEL_ID = "huhs_radio"
        private const val NOTIFICATION_ID = 421
        private const val RECONNECT_DELAY_MS = 3_000L
        private const val FOCUS_RETRY_DELAY_MS = 2_000L
    }
}
