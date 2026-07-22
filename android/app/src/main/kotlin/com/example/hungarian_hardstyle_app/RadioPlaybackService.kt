package com.example.hungarian_hardstyle_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder

class RadioPlaybackService : Service() {
    private var player: MediaPlayer? = null

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Hungarian Hardstyle rádió", NotificationManager.IMPORTANCE_LOW),
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
            ACTION_VOLUME -> player?.setVolume(intent.getFloatExtra(EXTRA_VOLUME, 1f), intent.getFloatExtra(EXTRA_VOLUME, 1f))
        }
        return START_STICKY
    }

    private fun play(url: String?) {
        if (url.isNullOrBlank()) return
        startForeground(NOTIFICATION_ID, notification())
        stopPlayer()
        player = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            setOnPreparedListener { start() }
            setOnErrorListener { _, _, _ -> true }
            try {
                setDataSource(url)
                prepareAsync()
            } catch (_: Exception) {
                stopPlayer()
            }
        }
    }

    private fun stopPlayer() {
        player?.runCatching { stop() }
        player?.release()
        player = null
    }

    private fun notification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Real Hardstyle FM")
            .setContentText("Hungarian Hardstyle rádió")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        stopPlayer()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_PLAY = "com.example.hungarian_hardstyle_app.radio.PLAY"
        const val ACTION_STOP = "com.example.hungarian_hardstyle_app.radio.STOP"
        const val ACTION_VOLUME = "com.example.hungarian_hardstyle_app.radio.VOLUME"
        const val EXTRA_URL = "url"
        const val EXTRA_VOLUME = "volume"
        private const val CHANNEL_ID = "huhs_radio"
        private const val NOTIFICATION_ID = 421
    }
}
