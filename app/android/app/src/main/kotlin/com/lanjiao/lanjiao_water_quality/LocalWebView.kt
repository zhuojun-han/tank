package com.lanjiao.lanjiao_water_quality

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Color
import android.net.Uri
import android.provider.MediaStore
import android.view.View
import android.view.ContextThemeWrapper
import android.webkit.ConsoleMessage
import android.webkit.PermissionRequest
import android.webkit.RenderProcessGoneDetail
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.content.FileProvider
import androidx.webkit.WebViewAssetLoader
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.File
import java.net.URLConnection

/** No network server is started: HTTPS requests are satisfied by APK assets. */
class LocalWebViewFactory(
    private val activity: Activity,
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    companion object {
        const val VIEW_TYPE = "lanjiao/local-webview"
        const val ORIGIN = "https://appassets.androidplatform.net"
        private const val PICK_IMAGE = 40821
        private const val CAMERA_PERMISSION = 40822
    }

    private var fileCallback: ValueCallback<Array<Uri>>? = null
    private var cameraFile: File? = null
    private var cameraUri: Uri? = null
    private var permissionPending = false

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        LocalWebView(ContextThemeWrapper(context, R.style.LanjiaoWebTheme), viewId, messenger, this)

    fun chooseImage(callback: ValueCallback<Array<Uri>>, capture: Boolean) {
        finishPicker(null)
        fileCallback = callback
        if (capture) {
            if (activity.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                permissionPending = true
                activity.requestPermissions(arrayOf(Manifest.permission.CAMERA), CAMERA_PERMISSION)
            } else launchCamera()
        } else {
            try {
                activity.startActivityForResult(
                    Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "image/*"
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }, PICK_IMAGE,
                )
            } catch (_: ActivityNotFoundException) {
                finishPicker(null)
            }
        }
    }

    private fun launchCamera() {
        try {
            val directory = File(activity.cacheDir, "webview-camera").apply { mkdirs() }
            // Only disposable camera outputs belong in this directory. Keep the
            // most recent file while WebView may still be reading it.
            directory.listFiles()?.sortedByDescending { it.lastModified() }
                ?.forEachIndexed { index, file ->
                    if (index >= 2 || System.currentTimeMillis() - file.lastModified() > 86_400_000L) file.delete()
                }
            cameraFile = File.createTempFile("capture-", ".jpg", directory)
            cameraUri = FileProvider.getUriForFile(
                activity, "${activity.packageName}.webview.files", cameraFile!!,
            )
            activity.startActivityForResult(
                Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                    putExtra(MediaStore.EXTRA_OUTPUT, cameraUri)
                    clipData = ClipData.newRawUri("photo", cameraUri)
                    addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }, PICK_IMAGE,
            )
        } catch (_: Exception) {
            finishPicker(null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_IMAGE) return false
        val uri = if (resultCode == Activity.RESULT_OK) cameraUri ?: data?.data else null
        finishPicker(uri?.let { arrayOf(it) })
        return true
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != CAMERA_PERMISSION) return false
        if (permissionPending && grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) launchCamera()
        else finishPicker(null)
        permissionPending = false
        return true
    }

    fun cancelPicker() = finishPicker(null)

    private fun finishPicker(value: Array<Uri>?) {
        val callback = fileCallback
        fileCallback = null
        if (value == null) cameraFile?.delete()
        cameraFile = null
        cameraUri = null
        callback?.onReceiveValue(value)
    }
}

private class LocalWebView(
    context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
    private val factory: LocalWebViewFactory,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val webView = WebView(context)
    private val channel = MethodChannel(messenger, "lanjiao/local-webview/$viewId")
    private var disposed = false
    private var rendererGone = false
    private var ready = false
    private val pending = mutableSetOf<String>()
    private val assetLoader = WebViewAssetLoader.Builder()
        .addPathHandler("/native-photo/", WebViewAssetLoader.PathHandler { path ->
            // Only opaque JPEG draft names are addressable. No caller-provided
            // filesystem path or arbitrary private file is ever exposed.
            if (!path.matches(Regex("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\\.jpg"))) {
                return@PathHandler notFound()
            }
            try {
                val directory = File(context.filesDir, "webview-photo-drafts").canonicalFile
                val file = File(directory, path).canonicalFile
                if (file.parentFile != directory || !file.isFile || file.length() > 2 * 1024 * 1024) {
                    return@PathHandler notFound()
                }
                val bounds = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }
                android.graphics.BitmapFactory.decodeFile(file.path, bounds)
                if (bounds.outMimeType != "image/jpeg" || bounds.outWidth !in 1..1600 || bounds.outHeight !in 1..1600) {
                    return@PathHandler notFound()
                }
                WebResourceResponse("image/jpeg", null, file.inputStream()).apply {
                    responseHeaders = mapOf("X-Content-Type-Options" to "nosniff", "Cache-Control" to "no-store")
                }
            } catch (_: Exception) { notFound() }
        })
        .addPathHandler("/", WebViewAssetLoader.PathHandler { path ->
            if (path.split('/').any { it == ".." } || path.contains('\\')) return@PathHandler notFound()
            val asset = "www/${path.ifEmpty { "index.html" }}"
            try {
                val mime = when (asset.substringAfterLast('.', "")) {
                    "js", "mjs" -> "text/javascript"
                    "css" -> "text/css"
                    "html" -> "text/html"
                    "json" -> "application/json"
                    "svg" -> "image/svg+xml"
                    "webp" -> "image/webp"
                    "woff2" -> "font/woff2"
                    else -> URLConnection.guessContentTypeFromName(asset) ?: "application/octet-stream"
                }
                WebResourceResponse(mime, "UTF-8", context.assets.open(asset)).apply {
                    responseHeaders = mapOf("X-Content-Type-Options" to "nosniff", "Cache-Control" to "no-cache")
                }
            } catch (_: Exception) { notFound() }
        }).build()

    init {
        channel.setMethodCallHandler(this)
        webView.setBackgroundColor(Color.rgb(244, 250, 248))
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true // Ephemeral UI drafts only; SQLite owns business data.
            allowFileAccess = false
            allowContentAccess = false
            @Suppress("DEPRECATION")
            allowFileAccessFromFileURLs = false
            @Suppress("DEPRECATION")
            allowUniversalAccessFromFileURLs = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(false)
            mediaPlaybackRequiresUserGesture = true
            builtInZoomControls = false
            displayZoomControls = false
            textZoom = 100
        }
        val debuggable = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        WebView.setWebContentsDebuggingEnabled(debuggable)
        webView.webChromeClient = object : WebChromeClient() {
            override fun onPermissionRequest(request: PermissionRequest) = request.deny()
            override fun onConsoleMessage(message: ConsoleMessage): Boolean {
                if (debuggable && message.messageLevel() == ConsoleMessage.MessageLevel.ERROR) {
                    android.util.Log.e("LanjiaoWebView", "${message.sourceId()}:${message.lineNumber()} ${message.message()}")
                }
                return true
            }
            override fun onShowFileChooser(
                view: WebView,
                callback: ValueCallback<Array<Uri>>,
                params: FileChooserParams,
            ): Boolean {
                if (!isLocal(Uri.parse(view.url ?: ""))) {
                    callback.onReceiveValue(null)
                    return true
                }
                factory.chooseImage(callback, params.isCaptureEnabled)
                return true
            }
        }
        webView.webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView, url: String, favicon: android.graphics.Bitmap?) {
                ready = false
                channel.invokeMethod("loading", null)
            }

            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
                if (request.url.scheme == "data" || request.url.scheme == "blob") return null
                if (!isLocal(request.url)) return notFound()
                return assetLoader.shouldInterceptRequest(request.url) ?: notFound()
            }

            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                if (isLocal(request.url)) return false
                if (request.isForMainFrame && request.url.scheme in listOf("https", "http")) {
                    try {
                        context.startActivity(Intent(Intent.ACTION_VIEW, request.url).apply {
                            addCategory(Intent.CATEGORY_BROWSABLE)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        })
                    } catch (_: ActivityNotFoundException) {
                        channel.invokeMethod("error", "未找到可打开链接的浏览器。")
                    }
                }
                return true
            }

            override fun onPageFinished(view: WebView, url: String) {
                if (isLocal(Uri.parse(url))) {
                    ready = true
                    channel.invokeMethod("ready", null)
                }
            }

            override fun onReceivedError(view: WebView, request: WebResourceRequest, error: android.webkit.WebResourceError) {
                if (request.isForMainFrame) channel.invokeMethod("error", "本地页面加载失败，请重试。")
            }

            override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
                rendererGone = true
                ready = false
                channel.invokeMethod("error", "页面已停止运行，请重新打开；已保存的数据仍在本机。")
                return true
            }
        }

        if (WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
            WebViewCompat.addWebMessageListener(webView, "LanJiaoNative", setOf(LocalWebViewFactory.ORIGIN)) {
                    view, message, sourceOrigin, isMainFrame, _ ->
                if (isMainFrame && isLocal(sourceOrigin) && isLocal(Uri.parse(view.url ?: ""))) {
                    receive(message.data ?: "")
                }
            }
        }
    }

    override fun getView(): View = webView

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed || rendererGone) {
            result.error("view_unavailable", "页面已停止运行。", null)
            return
        }
        when (call.method) {
            "start" -> {
                if (!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)) {
                    result.error("webview_update_required", "请更新 Android System WebView 后再打开应用。", null)
                } else {
                    webView.loadUrl("${LocalWebViewFactory.ORIGIN}/index.html")
                    result.success(null)
                }
            }
            "event" -> {
                val name = call.argument<String>("name") ?: ""
                val detail = JSONObject.wrap(call.argument<Any>("detail"))
                evaluate("window.dispatchEvent(new CustomEvent(${JSONObject.quote(name)},{detail:$detail}));")
                result.success(null)
            }
            "lifecycle" -> {
                val state = call.arguments as? String ?: "paused"
                if (state == "resumed") webView.onResume()
                evaluate("document.documentElement.dataset.nativeLifecycle=${JSONObject.quote(state)};window.dispatchEvent(new CustomEvent('lanjiao:lifecycle',{detail:{state:${JSONObject.quote(state)}}}));")
                if (state != "resumed") webView.onPause()
                result.success(null)
            }
            "back" -> {
                if (!ready) { result.success(false); return }
                webView.evaluateJavascript(
                    "(()=>{if(typeof window.__lanjiaoHandleBack==='function')return window.__lanjiaoHandleBack()===true;return false;})()",
                ) { consumed ->
                    if (consumed == "true") result.success(true)
                    else if (webView.canGoBack()) { webView.goBack(); result.success(true) }
                    else result.success(false)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun receive(raw: String) {
        // Bound outstanding calls and message size. Backup files travel through
        // the native file service, not unbounded JavaScript messages.
        if (raw.length > 12 * 1024 * 1024) return
        val request = try { JSONObject(raw) } catch (_: Exception) { return }
        val id = request.optString("id")
        if (id.isEmpty() || id.length > 160) return
        if (request.optInt("version") != 1 || request.opt("params") !is JSONObject ||
            !request.optString("method").matches(Regex("[a-zA-Z][a-zA-Z0-9_.]{0,79}"))) {
            reply(id, false, error = "invalid_request", message = "无法识别此操作，请更新应用。")
            return
        }
        if (pending.size >= 16 || !pending.add(id)) {
            reply(id, false, error = "busy", message = "正在处理，请稍后重试。")
            return
        }
        channel.invokeMethod("request", mapOf(
            "method" to request.getString("method"),
            "params" to jsonMap(request.getJSONObject("params")),
        ), object : MethodChannel.Result {
            override fun success(result: Any?) {
                pending.remove(id)
                reply(id, true, result)
            }
            override fun error(code: String, message: String?, details: Any?) {
                pending.remove(id)
                reply(id, false, error = code, message = message ?: "操作未完成，请重试。")
            }
            override fun notImplemented() {
                pending.remove(id)
                reply(id, false, error = "unsupported_method", message = "当前版本不支持此操作。")
            }
        })
    }

    private fun reply(id: String, ok: Boolean, result: Any? = null, error: String = "", message: String = "") {
        val envelope = JSONObject().put("version", 1).put("id", id).put("ok", ok)
        if (ok) envelope.put("result", JSONObject.wrap(result))
        else envelope.put("error", JSONObject().put("code", error).put("message", message))
        evaluate("window.__lanjiaoReceive&&window.__lanjiaoReceive($envelope);")
    }

    private fun evaluate(script: String) {
        if (!disposed && !rendererGone && isLocal(Uri.parse(webView.url ?: ""))) webView.evaluateJavascript(script, null)
    }

    override fun dispose() {
        disposed = true
        factory.cancelPicker()
        channel.setMethodCallHandler(null)
        pending.clear()
        webView.stopLoading()
        webView.destroy()
    }

    companion object {
        private fun isLocal(uri: Uri): Boolean = uri.scheme == "https" &&
            uri.host == "appassets.androidplatform.net" && uri.port in listOf(-1, 443) && uri.userInfo == null

        private fun notFound() = WebResourceResponse(
            "text/plain", "UTF-8", 404, "Not Found", emptyMap(), ByteArrayInputStream(ByteArray(0)),
        )

        private fun jsonValue(value: Any?): Any? = when (value) {
            JSONObject.NULL -> null
            is JSONObject -> jsonMap(value)
            is JSONArray -> (0 until value.length()).map { jsonValue(value.get(it)) }
            else -> value
        }

        private fun jsonMap(value: JSONObject): Map<String, Any?> = value.keys().asSequence()
            .associateWith { jsonValue(value.get(it)) }
    }
}
