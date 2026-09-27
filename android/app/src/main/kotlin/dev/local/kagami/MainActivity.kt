package dev.local.kagami

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pages = PageDecoder(flutterEngine.dartExecutor.binaryMessenger, flutterEngine.renderer)
        network = NetworkWatcher(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        arrivals = ArrivalNotifier(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
            .also { it.launchedBy(intent) }
        sync = FolderSyncScheduler(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        archiveImages = ArchiveImages(flutterEngine.dartExecutor.binaryMessenger)
        archive = ArchiveScheduler(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
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
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        arrivals?.opened(intent)
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
        super.onDestroy()
    }
}
