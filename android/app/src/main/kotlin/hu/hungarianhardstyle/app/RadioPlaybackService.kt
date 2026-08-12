package hu.hungarianhardstyle.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

class RadioPlaybackService : Service() {
    private var player: MediaPlayer? = null
    private var streamUrl: String? = null
    private var volume = 1f
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
        }
        return START_NOT_STICKY
    }

    private fun play(url: String?) {
        if (url.isNullOrBlank()) return
        streamUrl = url
        reconnectHandler.removeCallbacks(reconnect)
        getSharedPreferences("huhs_radio", MODE_PRIVATE).edit().putBoolean("playing", true).apply()
        startForeground(NOTIFICATION_ID, notification())
        startPlayer(url)
    }

    private fun startPlayer(url: String) {
        releasePlayer()
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
            reconnectHandler.postDelayed(reconnect, RECONNECT_DELAY_MS)
        }
    }

    private fun isPlaybackRequested() =
        getSharedPreferences("huhs_radio", MODE_PRIVATE).getBoolean("playing", false)

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
        getSharedPreferences("huhs_radio", MODE_PRIVATE).edit().putBoolean("playing", false).apply()
        reconnectHandler.removeCallbacks(reconnect)
        streamUrl = null
        releasePlayer()
    }

    private fun notification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Real Hardstyle FM")
            .setContentText("Real Hardstyle FM")
            .setSmallIcon(android.R.drawable.ic_media_play)
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
        private const val CHANNEL_ID = "huhs_radio"
        private const val NOTIFICATION_ID = 421
        private const val RECONNECT_DELAY_MS = 3_000L
    }
}
