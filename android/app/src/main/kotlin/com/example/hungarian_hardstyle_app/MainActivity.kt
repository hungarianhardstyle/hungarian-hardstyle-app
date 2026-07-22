package com.example.hungarian_hardstyle_app

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
                            val intent = Intent(this, RadioPlaybackService::class.java)
                                .setAction(RadioPlaybackService.ACTION_PLAY)
                                .putExtra(RadioPlaybackService.EXTRA_URL, url)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(null)
                        }
                    }
                    "stop" -> {
                        startService(Intent(this, RadioPlaybackService::class.java).setAction(RadioPlaybackService.ACTION_STOP))
                        result.success(null)
                    }
                    "volume" -> {
                        val volume = (call.arguments as? Number)?.toFloat() ?: 1f
                        startService(
                            Intent(this, RadioPlaybackService::class.java)
                                .setAction(RadioPlaybackService.ACTION_VOLUME)
                                .putExtra(RadioPlaybackService.EXTRA_VOLUME, volume),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hu_hs/media")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveImage" || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    result.error("unsupported", "A képmentés ezen az Android-verzión nem támogatott.", null)
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val name = call.argument<String>("name") ?: "huhs-image.jpg"
                if (bytes == null || bytes.isEmpty()) {
                    result.error("missing_bytes", "A kép adatai hiányoznak.", null)
                    return@setMethodCallHandler
                }
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, name)
                    put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                    put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/Hungarian Hardstyle")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
                val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                if (uri == null) {
                    result.error("insert_failed", "A kép mentése sikertelen.", null)
                    return@setMethodCallHandler
                }
                try {
                    contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                        ?: error("output_failed")
                    values.clear()
                    values.put(MediaStore.Images.Media.IS_PENDING, 0)
                    contentResolver.update(uri, values, null, null)
                    result.success(null)
                } catch (error: Exception) {
                    contentResolver.delete(uri, null, null)
                    result.error("write_failed", error.message, null)
                }
            }
    }

}
