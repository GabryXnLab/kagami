package dev.local.kagami

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.View
import android.webkit.CookieManager
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
        val timeout = (call.argument<Int>("timeoutMs") ?: 45000).toLong()
        main.post { open(url, ready, timeout, result) }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun open(url: String, ready: String, timeout: Long, result: MethodChannel.Result) {
        val view = try {
            WebView(context)
        } catch (error: Throwable) {
            // Senza il pacchetto della WebView (aggiornato a metà, disattivato).
            return result.success(null)
        }
        view.settings.javaScriptEnabled = true
        view.settings.domStorageEnabled = true
        CookieManager.getInstance().setAcceptCookie(true)
        CookieManager.getInstance().setAcceptThirdPartyCookies(view, true)
        view.webViewClient = WebViewClient()
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
            view.stopLoading()
            view.destroy()
            CookieManager.getInstance().flush()
            result.success(html)
        }
        lateinit var poll: Runnable
        poll = Runnable {
            view.evaluateJavascript(ready) { found ->
                when {
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
}
