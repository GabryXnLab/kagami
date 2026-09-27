package dev.local.kagami

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.work.ExistingWorkPolicy
import androidx.work.ForegroundInfo
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Il giro programmato della sincronizzazione, ad app chiusa.
 *
 * La sincronizzazione è Dart (`lib/src/data/folder_sync.dart`): riscriverla
 * qui vorrebbe dire due motori con le stesse regole da tenere d'accordo.
 * Il lavoro accende quindi un motore Flutter senza schermo, che esegue
 * `folderSyncMain` in `lib/main.dart` e dice `done` sul canale quando ha
 * finito. Il token di Drive lo dà `google_sign_in` anche senza un'attività:
 * il permesso è già stato concesso dall'app, e rinnovarlo non mostra niente.
 *
 * Una libreria può essere gigabyte, e un lavoro normale ha dieci minuti:
 * si chiede di girare in primo piano, con una notifica. Se il sistema non
 * lo concede, il giro si ferma ai dieci minuti e riprende al seguente da
 * dove era arrivato — Dart salva a che punto è.
 */
class FolderSyncWorker(context: Context, parameters: WorkerParameters) :
    Worker(context, parameters) {

    private val main = Handler(Looper.getMainLooper())

    @Volatile
    private var channel: MethodChannel? = null

    override fun doWork(): Result {
        val foreground = runCatching { setForegroundAsync(foregroundInfo()).get() }.isSuccess
        val finished = CountDownLatch(1)
        var engine: FlutterEngine? = null
        main.post {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(applicationContext)
                loader.ensureInitializationComplete(applicationContext, null)
                val started = FlutterEngine(applicationContext)
                engine = started
                channel = MethodChannel(started.dartExecutor.binaryMessenger, CHANNEL).apply {
                    setMethodCallHandler { call, result ->
                        if (call.method == "done") {
                            result.success(null)
                            finished.countDown()
                        } else {
                            result.notImplemented()
                        }
                    }
                }
                started.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRYPOINT),
                )
            } catch (_: Throwable) {
                finished.countDown()
            }
        }
        finished.await(if (foreground) 3L * 60 else 9L, TimeUnit.MINUTES)
        main.post {
            channel?.setMethodCallHandler(null)
            channel = null
            engine?.destroy()
        }
        // Fermato dal sistema, il lavoro si riprova da sé; tolto dall'app, ne
        // ha già messo in coda un altro. Negli altri casi tocca a lui.
        if (!isStopped) {
            val minutes = inputData.getInt(MINUTES, -1)
            if (minutes >= 0) {
                FolderSyncScheduler.enqueue(
                    applicationContext,
                    minutes,
                    inputData.getBoolean(WIFI_ONLY, true),
                    ExistingWorkPolicy.APPEND_OR_REPLACE,
                )
            }
        }
        // Sempre riuscito: un lavoro fallito farebbe fallire anche il
        // seguente accodato. Com'è andata lo scrive Dart, e l'app lo mostra.
        return Result.success()
    }

    override fun onStopped() {
        main.post { channel?.invokeMethod("stop", null) }
    }

    private fun foregroundInfo(): ForegroundInfo {
        val manager = applicationContext.getSystemService(NotificationManager::class.java)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    NOTIFICATION_CHANNEL,
                    "Sincronizzazione",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "La cartella del telefono e quella di Drive si stanno allineando."
                },
            )
            Notification.Builder(applicationContext, NOTIFICATION_CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(applicationContext)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Sincronizzazione con Drive")
            .setContentText("Kagami sta allineando la cartella dei manga")
            .setOngoing(true)
            .build()
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ForegroundInfo(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            ForegroundInfo(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        const val MINUTES = "minutes"
        const val WIFI_ONLY = "wifiOnly"
        private const val CHANNEL = "kagami/sync"
        private const val ENTRYPOINT = "folderSyncMain"
        private const val NOTIFICATION_CHANNEL = "sync"
        private const val NOTIFICATION_ID = 7
    }
}
