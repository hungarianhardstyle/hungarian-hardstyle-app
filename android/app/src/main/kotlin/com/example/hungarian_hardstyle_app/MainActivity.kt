package com.example.hungarian_hardstyle_app

import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
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
                    "isPlaying" -> {
                        result.success(getSharedPreferences("huhs_radio", MODE_PRIVATE).getBoolean("playing", false))
                    }
                    "stop" -> {
                        getSharedPreferences("huhs_radio", MODE_PRIVATE).edit()
                            .putBoolean("playing", false).apply()
                        val stopIntent = Intent(this, RadioPlaybackService::class.java)
                            .setAction(RadioPlaybackService.ACTION_STOP)
                        startService(stopIntent)
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
                if (call.method != "saveImage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val name = call.argument<String>("name") ?: "huhs-image.jpg"
                if (bytes == null || bytes.isEmpty()) {
                    result.error("missing_bytes", "A kép adatai hiányoznak.", null)
                    return@setMethodCallHandler
                }
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    if (checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
                        PackageManager.PERMISSION_GRANTED
                    ) {
                        requestPermissions(
                            arrayOf(android.Manifest.permission.WRITE_EXTERNAL_STORAGE),
                            401,
                        )
                        result.error("permission_required", "A képmentéshez tárhelyengedély szükséges.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val directory = File(
                            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
                            "Hungarian Hardstyle",
                        ).apply { mkdirs() }
                        val file = File(directory, name)
                        file.outputStream().use { it.write(bytes) }
                        MediaScannerConnection.scanFile(
                            this,
                            arrayOf(file.absolutePath),
                            arrayOf("image/jpeg"),
                            null,
                        )
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("write_failed", error.message, null)
                    }
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








