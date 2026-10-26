package ca.occasiotech.myoccasio

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var exportResult: MethodChannel.Result? = null
    private var exportBytes: ByteArray? = null
    private var authenticationResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // A process-death callback has no in-memory PKCE verifier. Consume it;
        // Flutter must never treat authorization codes as navigation routes.
        if (intent?.data?.scheme == AUTH_SCHEME) intent = Intent(intent).setData(null)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "ca.occasiotech.myoccasio/authentication").setMethodCallHandler { call, result ->
            when (call.method) {
                "cancel" -> {
                    val pending = authenticationResult
                    authenticationResult = null
                    pending?.error("cancelled", "Sign-in was cancelled.", null)
                    result.success(null)
                }
                "authenticate" -> {
                    if (authenticationResult != null) {
                        result.error("busy", "Sign-in is already open.", null)
                        return@setMethodCallHandler
                    }
                    val value = call.argument<String>("url")
                    val uri = value?.let { Uri.parse(it) }
                    val localDebug = (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0 && uri?.scheme == "http" &&
                        uri.host in setOf("127.0.0.1", "localhost", "::1")
                    if (value == null || value.length > 2048 || uri == null ||
                        (uri.scheme != "https" && !localDebug) || uri.host.isNullOrEmpty() ||
                        uri.userInfo != null || uri.fragment != null || uri.path?.endsWith("/auth/native") != true ||
                        uri.queryParameterNames != setOf("request") ||
                        uri.getQueryParameters("request").size != 1 ||
                        !Regex("^[A-Za-z0-9_-]{43}$").matches(uri.getQueryParameter("request") ?: "")) {
                        result.error("invalid_url", "Invalid sign-in address.", null)
                        return@setMethodCallHandler
                    }
                    authenticationResult = result
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, uri)
                            .addCategory(Intent.CATEGORY_BROWSABLE)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    } catch (_: Exception) {
                        authenticationResult = null
                        result.error("unavailable", "Could not open the system browser.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "ca.occasiotech.myoccasio/documents").setMethodCallHandler { call, result ->
            if (call.method != "export") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (exportResult != null) {
                result.error("busy", "A file export is already open.", null)
                return@setMethodCallHandler
            }
            val bytes = call.argument<ByteArray>("bytes")
            val name = call.argument<String>("name")
            val mimeType = call.argument<String>("mimeType")
            if (bytes == null || bytes.isEmpty() || bytes.size > 4 * 1024 * 1024 ||
                name.isNullOrBlank() || mimeType.isNullOrBlank()) {
                result.error("invalid_file", "Invalid document.", null)
                return@setMethodCallHandler
            }
            exportResult = result
            exportBytes = bytes
            try {
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mimeType
                    putExtra(Intent.EXTRA_TITLE, name.replace(Regex("[\\\\/\\p{Cntrl}]"), "_"))
                }
                startActivityForResult(intent, EXPORT_DOCUMENT)
            } catch (_: Exception) {
                exportBytes = null
                exportResult = null
                result.error("export_unavailable", "Could not open file picker.", null)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        val uri = intent.data
        if (uri?.scheme == AUTH_SCHEME) {
            setIntent(Intent(intent).setData(null))
            val result = authenticationResult ?: return
            authenticationResult = null
            if (uri.host != "callback" || !uri.path.isNullOrEmpty() ||
                uri.port != -1 || uri.userInfo != null || uri.fragment != null ||
                uri.toString().length > 2048) {
                result.error("invalid_callback", "Invalid sign-in callback.", null)
            } else {
                result.success(uri.toString())
            }
            return
        }
        super.onNewIntent(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != EXPORT_DOCUMENT) return
        val result = exportResult ?: return
        val bytes = exportBytes
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) {
            exportBytes = null
            exportResult = null
            result.success(false)
            return
        }
        // A provider can be remote; don't block the Flutter/UI thread on writes.
        Thread {
            val succeeded = try {
                contentResolver.openOutputStream(uri, "w")?.use { it.write(bytes) }
                    ?: throw java.io.IOException("No output stream")
                true
            } catch (_: Exception) { false }
            runOnUiThread {
                if (exportResult !== result) return@runOnUiThread
                exportBytes = null
                exportResult = null
                if (succeeded) result.success(true)
                else result.error("export_failed", "Could not write document.", null)
            }
        }.start()
    }

    override fun onDestroy() {
        val authentication = authenticationResult
        authenticationResult = null
        authentication?.error("interrupted", "Sign-in was interrupted.", null)
        val result = exportResult
        exportResult = null
        exportBytes = null
        result?.error("export_interrupted", "File export was interrupted.", null)
        super.onDestroy()
    }

    companion object {
        private const val EXPORT_DOCUMENT = 6104
        private const val AUTH_SCHEME = "ca.occasiotech.myoccasio.auth"
    }
}
