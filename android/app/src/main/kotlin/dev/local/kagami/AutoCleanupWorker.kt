package dev.local.kagami

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * La pulizia automatica dei capitoli, ad app chiusa.
 *
 * Le regole e il piano sono Dart (`lib/src/data/auto_cleanup.dart`): l'app
 * lascia su disco ogni capitolo sul telefono con il momento da cui si può
 * togliere, e questo lavoro, alla prima scadenza, accende un motore Flutter
 * senza schermo su `autoCleanupMain` in `lib/main.dart`. Così le cartelle
 * tolte si annotano per la sincronizzazione con lo stesso codice del foglio
 * «Libera spazio», invece che con una sua copia qui.
 *
 * Togliere cartelle è questione di secondi: niente primo piano.
 */
class AutoCleanupWorker(context: Context, parameters: WorkerParameters) :
    Worker(context, parameters) {

    private val main = Handler(Looper.getMainLooper())

    override fun doWork(): Result {
        val finished = CountDownLatch(1)
        var next = -1L
        var engine: FlutterEngine? = null
        var channel: MethodChannel? = null
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
                            next = (call.argument<Number>("next") ?: -1).toLong()
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
        finished.await(9L, TimeUnit.MINUTES)
        main.post {
            channel?.setMethodCallHandler(null)
            engine?.destroy()
        }
        // L'app, se si apre prima, riprogramma da sé con `REPLACE`: qui si
        // accoda il seguente senza fermare questo, che sta finendo.
        if (!isStopped && next >= 0) {
            AutoCleanupScheduler.enqueue(applicationContext, next, ExistingWorkPolicy.APPEND_OR_REPLACE)
        }
        return Result.success()
    }

    companion object {
        private const val CHANNEL = "kagami/cleanup-worker"
        private const val ENTRYPOINT = "autoCleanupMain"
    }
}

/** Il lato Dart sta in `AutoCleanupScheduler`, `lib/src/data/auto_cleanup.dart`. */
class AutoCleanupScheduler(messenger: BinaryMessenger, private val context: Context) :
    MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "kagami/cleanup-schedule")

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "schedule" -> {
                enqueue(context, call.argument<Number>("at")!!.toLong(), ExistingWorkPolicy.REPLACE)
                result.success(null)
            }
            "cancel" -> {
                WorkManager.getInstance(context).cancelUniqueWork(NAME)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val NAME = "kagami.auto-cleanup"

        /** Il giro all'istante [at] (millisecondi), o subito se è già passato. */
        fun enqueue(context: Context, at: Long, policy: ExistingWorkPolicy) {
            val delay = (at - System.currentTimeMillis()).coerceAtLeast(0)
            val request = OneTimeWorkRequest.Builder(AutoCleanupWorker::class.java)
                .setInitialDelay(delay, TimeUnit.MILLISECONDS)
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(NAME, policy, request)
        }
    }
}
