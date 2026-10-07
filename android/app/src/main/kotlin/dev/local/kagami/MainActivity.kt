package dev.local.kagami

import android.app.LocaleManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.LocaleList
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pages: PageDecoder? = null
    private var network: NetworkWatcher? = null
    private var arrivals: ArrivalNotifier? = null
    private var sync: FolderSyncScheduler? = null
    private var archiveImages: ArchiveImages? = null
    private var archive: ArchiveScheduler? = null
    private var shared: SharedText? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pages = PageDecoder(flutterEngine.dartExecutor.binaryMessenger, flutterEngine.renderer)
        network = NetworkWatcher(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        arrivals = ArrivalNotifier(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
            .also { it.launchedBy(intent) }
        sync = FolderSyncScheduler(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        archiveImages = ArchiveImages(flutterEngine.dartExecutor.binaryMessenger)
        archive = ArchiveScheduler(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        shared = SharedText(flutterEngine.dartExecutor.binaryMessenger).also { it.launchedBy(intent) }
        // Un link che si apre nel browser: un pacchetto intero per una riga
        // di Intent non vale la dipendenza.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kagami/links")
            .setMethodCallHandler { call, result ->
                if (call.method != "open") return@setMethodCallHandler result.notImplemented()
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(call.arguments as String)))
                    result.success(true)
                } catch (_: ActivityNotFoundException) {
                    result.success(false)
                }
            }
        // Il client «Web» del progetto Firebase, per cui Google dà il codice
        // del server: il plugin Gradle di Google lo scrive fra le risorse da
        // google-services.json, e senza quel file non c'è.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kagami/google")
            .setMethodCallHandler { call, result ->
                if (call.method != "webClientId") return@setMethodCallHandler result.notImplemented()
                @Suppress("DiscouragedApi")
                val id = resources.getIdentifier("default_web_client_id", "string", packageName)
                result.success(if (id == 0) null else getString(id))
            }
        // La lingua scelta nell'app vale anche per ciò che scrive il Kotlin
        // (notifiche e canali), anche ad app chiusa: da Android 13 il sistema
        // ricorda una lingua per app. Prima resta quella del sistema.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kagami/locale")
            .setMethodCallHandler { call, result ->
                if (call.method != "set") return@setMethodCallHandler result.notImplemented()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    getSystemService(LocaleManager::class.java).applicationLocales =
                        LocaleList.forLanguageTags(call.arguments as String)
                }
                result.success(null)
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        arrivals?.opened(intent)
        shared?.opened(intent)
    }

    override fun onDestroy() {
        pages?.dispose()
        pages = null
        network?.dispose()
        network = null
        arrivals?.dispose()
        arrivals = null
        sync?.dispose()
        sync = null
        archiveImages?.dispose()
        archiveImages = null
        archive?.dispose()
        archive = null
        shared?.dispose()
        shared = null
        super.onDestroy()
    }
}
