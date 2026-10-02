package hu.hungarianhardstyle.app

import android.app.PictureInPictureParams
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.util.Rational
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import androidx.activity.enableEdgeToEdge
import androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import java.io.File
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import com.ryanheise.audioservice.AudioServiceFragmentActivity

// FIGYELEM: a bázis-osztály `AudioServiceFragmentActivity` (nem közvetlenül a
// `FlutterFragmentActivity`), mert a megvásárolt zenék háttér-lejátszása
// (audio_service) ezen keresztül kapcsolódik a médiamunkamenethez. Ez az osztály
// a `FlutterFragmentActivity`-ből származik, ezért az ujjlenyomat/PIN-es
// belépés (BiometricPrompt) és a többi Metódus-csatorna változatlanul működik.
class MainActivity : AudioServiceFragmentActivity() {
    private var systemBackCallback: OnBackInvokedCallback? = null

    /**
     * Kis képernyő (PiP) — a tulajdonos kérése: *„ha leteszi az appot hatterben
     * menjen a stream kiskepernyon”*.
     *
     * A Twitch-oldal kapcsolja be (`hu_hs/pip` → `setEnabled`); amikor a
     * felhasználó elhagyja az appot, a [onUserLeaveHint] ilyenkor lép be a kis
     * képernyőre. Rádióhallgatás vagy böngészés közben **nem** ugrik be, mert ott
     * a kapcsoló kikapcsolt.
     */
    private var pictureInPictureEnabled = false

    /**
     * Azonnali belépés a kis képernyőre (a felület gombja kéri).
     *
     * Ugyanazokat a kapukat használja, mint a [onUserLeaveHint]: csak akkor lép
     * be, ha a Twitch-oldal kérte, az Android támogatja (API 26+) és a készülék
     * tudja a szolgáltatást. Visszatérés: sikerült-e (a felület ebből dönt a
     * tartalék útról).
     */
    private fun enterPictureInPictureNow(): Boolean {
        if (!pictureInPictureEnabled) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) return false
        return runCatching {
            enterPictureInPictureMode(
                PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(16, 9))
                    .build(),
            )
        }.getOrDefault(false)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        enterPictureInPictureNow()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: android.content.res.Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // A Play Console „teljes képernyős mód" javaslata: Android 15+ (targetSdk 35
        // felett) a rendszer **kötelezően** teljes képernyős, ezért ott ez a hívás
        // nem változtat semmit. A visszamenőleges kompatibilitás miatt kell: így a
        // régebbi Androidokon is ugyanígy indul az app.
        //
        // MÉRVE (2026-09-24, android-34 emulátor, ugyanaz a két csomag): a hívás
        // tényleg lefut (az ablak `mAttrs`-ában megjelenik a
        // `layoutInDisplayCutoutMode=always`), a **felület viszont pixelre ugyanaz**
        // marad — a sorok (360, 419, 494, …, 2138, 2337, 2364, 2374) egyeznek, csak
        // a statuszsáv sávja lesz ~11%-kal sötétebb. Ezért nem tud eltörni tőle
        // semmi; a részletek az AGENTS.md-ben.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val callback = OnBackInvokedCallback {
                // Android 13+ otherwise finishes this Flutter Activity before
                // PopScope receives the system-back event.
                flutterEngine.navigationChannel.popRoute()
            }
            systemBackCallback = callback
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                // Let the IME consume the first back press while it is open;
                // Flutter still receives back normally once it is dismissed.
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
                callback,
            )
        }
        // Kis képernyő (PiP): a Twitch-oldal kapcsolja be/ki (lásd a mezőt),
        // és ugyanaz az oldal kérheti azonnali belépést is (a felület gombja).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hu_hs/pip")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setEnabled" -> {
                        pictureInPictureEnabled = call.arguments as? Boolean ?: false
                        result.success(null)
                    }
                    "enter" -> result.success(enterPictureInPictureNow())
                    else -> result.notImplemented()
                }
            }
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
                    // A „most szól" cím a felületről (2026-10-01): az app nyitva
                    // van, tehát a Dart-oldal már kiolvasta a stream fejlécét —
                    // ezt adjuk tovább a szolgáltatásnak, hogy az értesítés és a
                    // zárképernyő azonnal a szóló számot mutassa. Háttérben a
                    // szolgáltatás maga olvassa (lásd RadioMetadataReader).
                    "metadata" -> {
                        val args = call.arguments as? Map<*, *>
                        val title = (args?.get("title") as? String).orEmpty()
                        val next = (args?.get("next") as? String).orEmpty()
                        startService(
                            Intent(this, RadioPlaybackService::class.java)
                                .setAction(RadioPlaybackService.ACTION_METADATA)
                                .putExtra(RadioPlaybackService.EXTRA_TITLE, title)
                                .putExtra(RadioPlaybackService.EXTRA_NEXT, next),
                        )
                        result.success(null)
                    }
                    "closeApp" -> {
                        finishAndRemoveTask()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hu_hs/auth")
            .setMethodCallHandler { call, result ->
                if (call.method != "deviceCredential") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val executor = ContextCompat.getMainExecutor(this)
                val prompt = BiometricPrompt(
                    this,
                    executor,
                    object : BiometricPrompt.AuthenticationCallback() {
                        override fun onAuthenticationSucceeded(
                            authResult: BiometricPrompt.AuthenticationResult,
                        ) {
                            result.success(true)
                        }

                        override fun onAuthenticationError(
                            errorCode: Int,
                            errString: CharSequence,
                        ) {
                            result.success(false)
                        }
                    },
                )
                val promptInfo = BiometricPrompt.PromptInfo.Builder()
                    .setTitle("Android-kódos feloldás")
                    .setSubtitle("PIN-kód, jelszó vagy mintarajz szükséges")
                    .setAllowedAuthenticators(DEVICE_CREDENTIAL)
                    .build()
                prompt.authenticate(promptInfo)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hu_hs/install_referrer")
            .setMethodCallHandler { call, result ->
                if (call.method != "getInstallReferrer") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val client = InstallReferrerClient.newBuilder(this).build()
                client.startConnection(object : InstallReferrerStateListener {
                    override fun onInstallReferrerSetupFinished(responseCode: Int) {
                        try {
                            if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                                result.success(client.installReferrer.installReferrer)
                            } else {
                                result.success(null)
                            }
                        } catch (_: Exception) {
                            result.success(null)
                        } finally {
                            client.endConnection()
                        }
                    }

                    override fun onInstallReferrerServiceDisconnected() {
                        result.success(null)
                    }
                })
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

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            systemBackCallback?.let { onBackInvokedDispatcher.unregisterOnBackInvokedCallback(it) }
        }
        systemBackCallback = null
        super.onDestroy()
    }

}








