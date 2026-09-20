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
import android.media.MediaPlayer
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager

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
 *  4. a hiba/lezárás utáni újracsatlakozás változatlanul 3 másodperc.
 */
class RadioPlaybackService : Service() {
    private var player: MediaPlayer? = null
    private var streamUrl: String? = null
    private var volume = 1f
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var focusRequest: AudioFocusRequest? = null

    private val audioManager by lazy {
        getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    /** MÁS APP hangja: elhallgatunk (lásd [requestAudioFocus] doksiját). */
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS -> pauseForFocusLoss(permanent = true)
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> pauseForFocusLoss(permanent = false)
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> player?.setVolume(0.2f, 0.2f)
            AudioManager.AUDIOFOCUS_GAIN -> {
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
                    if (requestAudioFocus()) startPlayer(streamUrl!!)
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
     *    és nem is kapja vissza magától — a felület is „leállt"-ot mutat;
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

    private fun pauseForFocusLoss(permanent: Boolean) {
        reconnectHandler.removeCallbacks(reconnect)
        releasePlayer()
        releaseLocks()
        if (permanent) {
            // A rádió elhallgat, és a felület is ezt mutatja (a felhasználó
            // indíthatja újra a gombbal).
            preferences().edit().putBoolean(KEY_PLAYING, false).apply()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
        // Ideiglenes elvesztésnél a `playing` igaz marad: a fókusz
        // visszakapásakor magától folytatjuk.
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
        streamUrl = null
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
    }
}
