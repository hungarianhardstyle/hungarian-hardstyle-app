package com.example.hungarian_hardstyle_app

import android.media.AudioManager
import android.media.MediaPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var player: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hu_hs/radio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> {
                        val url = call.arguments as? String
                        if (url == null) {
                            result.error("missing_url", "Radio URL missing", null)
                        } else {
                            player?.release()
                            player = MediaPlayer().apply {
                                setAudioStreamType(AudioManager.STREAM_MUSIC)
                                setDataSource(url)
                                setOnPreparedListener { start() }
                                setOnErrorListener { _, _, _ -> true }
                                prepareAsync()
                            }
                            result.success(null)
                        }
                    }
                    "stop" -> {
                        player?.stop()
                        player?.reset()
                        result.success(null)
                    }
                    "volume" -> {
                        val volume = (call.arguments as? Number)?.toFloat() ?: 1f
                        player?.setVolume(volume, volume)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        player?.release()
        player = null
        super.onDestroy()
    }
}
