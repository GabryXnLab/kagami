package dev.local.kagami

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.View
import android.webkit.CookieManager
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONTokener

/**
 * La pagina di una serie dietro la verifica del sito, letta da una WebView
 * che nessuno vede: il browser dei controlli delle serie seguite
 * (`PageBrowser` di `kagami_archive`, lato Dart `NativePageBrowser`).
 *
 * Una WebView di Flutter vive in un widget, e ad app chiusa, nel motore
 * senza schermo di `ArchiveWorker`, un widget non c'è: questa non è
 * attaccata a nessuna finestra. È grande quanto lo schermo, perché in una
 * WebView di un pixel la verifica non si risolve da sola. I cookie sono
 * quelli di tutte le WebView dell'app: una verifica superata a mano vale
 * anche qui finché Cloudflare la tiene buona. Quella che chiede di spuntare
 * «Verify you are human» qui non la spunta nessuno: la pagina non arriva.
 */
class PageBrowser(messenger: BinaryMessenger, private val context: Context) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "kagami/page-browser")
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "seriesPage") return result.notImplemented()
        val url = call.argument<String>("url")
        val ready = call.argument<String>("ready")
        if (url == null || ready == null) return result.error("args", "url e ready", null)
        // Solo pagine di siti in https: mai file:, content: o http.
        if (!url.startsWith("https://")) return result.success(null)
        val hosts = (call.argument<List<String>>("hosts") ?: emptyList()).map { it.lowercase() }
        // Come `pageHostAllowed` in `page_browser.dart`: https su un host dichiarato dal sito.
        if (!hostAllowed(url, hosts)) return result.success(null)
        val timeout = (call.argument<Int>("timeoutMs") ?: 45000).toLong()
        main.post { open(url, hosts, ready, timeout, result) }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun open(url: String, hosts: List<String>, ready: String, timeout: Long, result: MethodChannel.Result) {
        val view = try {
            WebView(context)
        } catch (error: Throwable) {
            // Senza il pacchetto della WebView (aggiornato a metà, disattivato).
            return result.success(null)
        }
        view.settings.javaScriptEnabled = true
        view.settings.domStorageEnabled = true
        // Spenti in modo esplicito: la pagina non deve poter leggere file né content provider dell'app.
        view.settings.allowFileAccess = false
        view.settings.allowContentAccess = false
        CookieManager.getInstance().setAcceptCookie(true)
        CookieManager.getInstance().setAcceptThirdPartyCookies(view, true)
        // Un reindirizzamento fuori da https o da un host dichiarato dal sito non si segue,
        // e la pagina che non arriva fa finire la lettura con `null`.
        var blocked = false
        view.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                if (hostAllowed(request.url.toString(), hosts)) return false
                if (request.isForMainFrame) blocked = true
                return true
            }
        }
        val metrics = context.resources.displayMetrics
        view.measure(
            View.MeasureSpec.makeMeasureSpec(metrics.widthPixels, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(metrics.heightPixels, View.MeasureSpec.EXACTLY),
        )
        view.layout(0, 0, metrics.widthPixels, metrics.heightPixels)
        // I timer di JavaScript sono di tutte le WebView del processo, e una
        // WebView dell'app messa in pausa li ferma anche qui.
        view.resumeTimers()
        view.onResume()
        view.loadUrl(url)
        val deadline = SystemClock.uptimeMillis() + timeout
        var done = false
        fun finish(html: String?) {
            if (done) return
            done = true
            // Ricontrollo finale: la pagina letta dev'essere su un host dichiarato.
            val html = if (blocked || !hostAllowed(view.url ?: "", hosts)) null else html
            view.stopLoading()
            view.destroy()
            CookieManager.getInstance().flush()
            result.success(html)
        }
        lateinit var poll: Runnable
        poll = Runnable {
            view.evaluateJavascript(ready) { found ->
                when {
                    blocked -> finish(null)
                    found == "true" -> view.evaluateJavascript("document.documentElement.outerHTML") { html ->
                        finish((runCatching { JSONTokener(html).nextValue() }.getOrNull() as? String)?.let { "<!DOCTYPE html>$it" })
                    }
                    SystemClock.uptimeMillis() > deadline -> finish(null)
                    else -> main.postDelayed(poll, 1000)
                }
            }
        }
        main.postDelayed(poll, 1000)
    }

    private fun hostAllowed(url: String, hosts: List<String>): Boolean {
        val uri = runCatching { android.net.Uri.parse(url) }.getOrNull() ?: return false
        return uri.scheme == "https" && uri.userInfo == null && uri.host?.lowercase() in hosts
    }
}
