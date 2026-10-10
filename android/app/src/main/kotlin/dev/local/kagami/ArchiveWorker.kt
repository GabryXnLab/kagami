package dev.local.kagami

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.ForegroundInfo
import androidx.work.NetworkType
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
import java.util.Calendar
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * I download dell'archivio, e il controllo quotidiano delle serie in corso.
 *
 * Il motore dell'archivio è Dart (`lib/src/archive/`), come la
 * sincronizzazione: il lavoro accende un motore Flutter senza schermo su
 * `archiveMain` o `archiveCheckMain` e aspetta che dica `done`. Gira in
 * primo piano con una notifica che dice a che punto è, perché una serie
 * intera sono ore, e un'app in secondo piano il sistema la congela.
 *
 * Com'è finita lo dice Dart: `retry` se è mancata la rete — il lavoro si
 * rimette in coda e riparte quando torna —, `stopped` se l'ha fermato
 * qualcuno. La coda sta in un file, quindi ripartire vuol dire riprendere.
 */
class ArchiveWorker(context: Context, parameters: WorkerParameters) :
    Worker(context, parameters) {

    private val main = Handler(Looper.getMainLooper())

    @Volatile
    private var channel: MethodChannel? = null

    @Volatile
    private var end = "done"

    @Volatile
    private var checkFailed = false

    /** L'avviso delle serie ferme alla verifica del sito, scritto da Dart. */
    private var verify: Pair<String, String>? = null

    private val check get() = inputData.getBoolean(CHECK, false)

    override fun doWork(): Result {
        val foreground = runCatching {
            setForegroundAsync(foregroundInfo(applicationContext.getString(if (check) R.string.archive_checking else R.string.archive_downloading), null, 0, 0)).get()
        }.isSuccess
        val finished = CountDownLatch(1)
        var engine: FlutterEngine? = null
        var images: ArchiveImages? = null
        var browser: PageBrowser? = null
        main.post {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(applicationContext)
                loader.ensureInitializationComplete(applicationContext, null)
                val started = FlutterEngine(applicationContext)
                engine = started
                images = ArchiveImages(started.dartExecutor.binaryMessenger)
                browser = PageBrowser(started.dartExecutor.binaryMessenger, applicationContext)
                channel = MethodChannel(started.dartExecutor.binaryMessenger, CHANNEL).apply {
                    setMethodCallHandler { call, result ->
                        when (call.method) {
                            "done" -> {
                                end = call.argument<String>("end") ?: "done"
                                checkFailed = call.argument<Boolean>("checkFailed") ?: false
                                val title = call.argument<String>("verifyTitle")
                                val text = call.argument<String>("verifyText")
                                verify = if (title != null && text != null) title to text else null
                                result.success(null)
                                finished.countDown()
                            }
                            "progress" -> {
                                if (foreground) {
                                    runCatching {
                                        setForegroundAsync(
                                            foregroundInfo(
                                                call.argument<String>("title") ?: "",
                                                call.argument<String>("text"),
                                                call.argument<Int>("done") ?: 0,
                                                call.argument<Int>("total") ?: 0,
                                            ),
                                        )
                                    }
                                }
                                result.success(null)
                            }
                            else -> result.notImplemented()
                        }
                    }
                }
                started.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(
                        loader.findAppBundlePath(),
                        if (check) CHECK_ENTRYPOINT else ENTRYPOINT,
                    ),
                )
            } catch (_: Throwable) {
                finished.countDown()
            }
        }
        // Un lavoro normale ha dieci minuti; in primo piano si tiene sotto le
        // sei ore che Android 15 concede in un giorno ai servizi dataSync.
        val completed = finished.await(if (foreground) 5L * 60 + 30 else 9L, TimeUnit.MINUTES)
        if (!completed) {
            main.post { channel?.invokeMethod("stop", null) }
            finished.await(1, TimeUnit.MINUTES)
            end = "stopped"
        }
        main.post {
            channel?.setMethodCallHandler(null)
            channel = null
            images?.dispose()
            browser?.dispose()
            engine?.destroy()
        }
        verify?.let { (title, text) -> ArrivalNotifier.verify(applicationContext, title, text) }
        if (check && !isStopped) {
            val minutes = inputData.getInt(MINUTES, -1)
            if (minutes >= 0) {
                // Senza rete all'ora scelta il controllo si perdeva fino al
                // giorno dopo: si riprova fra mezz'ora, e da lì si torna all'ora.
                schedule(
                    applicationContext,
                    minutes,
                    inputData.getBoolean(WIFI_ONLY, true),
                    ExistingWorkPolicy.APPEND_OR_REPLACE,
                    retryMinutes = if (checkFailed) RETRY_MINUTES else null,
                )
            }
        }
        // Fermato dal sistema, il lavoro lo riprova WorkManager; tolto
        // dall'app, lo si lascia stare. Negli altri casi la coda va avanti.
        if (!isStopped && (end == "retry" || (end == "stopped" && !completed))) {
            start(applicationContext, delayMinutes = if (end == "retry") 1 else 0, policy = ExistingWorkPolicy.APPEND_OR_REPLACE)
        }
        return Result.success()
    }

    override fun onStopped() {
        main.post { channel?.invokeMethod("stop", null) }
    }

    private fun foregroundInfo(title: String, text: String?, done: Int, total: Int): ForegroundInfo {
        val manager = applicationContext.getSystemService(NotificationManager::class.java)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    NOTIFICATION_CHANNEL,
                    applicationContext.getString(R.string.archive_downloading),
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = applicationContext.getString(R.string.channel_archive_description)
                },
            )
            Notification.Builder(applicationContext, NOTIFICATION_CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(applicationContext)
        }
        builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title.ifEmpty { applicationContext.getString(R.string.archive_downloading) })
            .setOngoing(true)
            .setOnlyAlertOnce(true)
        if (text != null) builder.setContentText(text)
        if (total > 0) builder.setProgress(total, done, false)
        val notification = builder.build()
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ForegroundInfo(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            ForegroundInfo(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        const val CHECK = "check"
        const val MINUTES = "minutes"
        const val WIFI_ONLY = "wifiOnly"
        const val QUEUE_NAME = "kagami.archive"
        const val CHECK_NAME = "kagami.archive-check"
        private const val CHANNEL = "kagami/archive-worker"
        private const val ENTRYPOINT = "archiveMain"
        private const val CHECK_ENTRYPOINT = "archiveCheckMain"
        private const val NOTIFICATION_CHANNEL = "archive"
        private const val NOTIFICATION_ID = 11
        private const val RETRY_MINUTES = 30L

        /** Il giro della coda. `KEEP` dall'app: se sta già girando, prende da sé ciò che arriva. */
        fun start(context: Context, delayMinutes: Int = 0, policy: ExistingWorkPolicy = ExistingWorkPolicy.KEEP) {
            val request = OneTimeWorkRequest.Builder(ArchiveWorker::class.java)
                .setInitialDelay(delayMinutes.toLong(), TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(QUEUE_NAME, policy, request)
        }

        fun stop(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(QUEUE_NAME)
        }

        /**
         * Il controllo all'ora [minutes] del giorno: un lavoro singolo che,
         * finito, mette in coda quello del giorno dopo, come la
         * sincronizzazione ([FolderSyncScheduler]).
         */
        fun schedule(
            context: Context,
            minutes: Int,
            wifiOnly: Boolean,
            policy: ExistingWorkPolicy,
            retryMinutes: Long? = null,
        ) {
            val now = System.currentTimeMillis()
            val next = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, minutes / 60)
                set(Calendar.MINUTE, minutes % 60)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (timeInMillis <= now) add(Calendar.DAY_OF_YEAR, 1)
            }
            val delay = retryMinutes?.let { TimeUnit.MINUTES.toMillis(it) } ?: (next.timeInMillis - now)
            val request = OneTimeWorkRequest.Builder(ArchiveWorker::class.java)
                .setInitialDelay(delay, TimeUnit.MILLISECONDS)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(if (wifiOnly) NetworkType.UNMETERED else NetworkType.CONNECTED)
                        .build(),
                )
                .setInputData(
                    Data.Builder()
                        .putBoolean(CHECK, true)
                        .putInt(MINUTES, minutes)
                        .putBoolean(WIFI_ONLY, wifiOnly)
                        .build(),
                )
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(CHECK_NAME, policy, request)
        }
    }
}

/** Il lato Kotlin di `ArchiveScheduler` in `lib/src/archive/runner.dart`. */
class ArchiveScheduler(messenger: BinaryMessenger, private val context: Context) :
    MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "kagami/archive")

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> ArchiveWorker.start(context)
            "stop" -> ArchiveWorker.stop(context)
            // `keep`: all'avvio dell'app si rimette il controllo solo se la
            // catena dei giorni si è spezzata, senza spostare quello in attesa.
            "schedule" -> ArchiveWorker.schedule(
                context,
                call.argument<Int>("minutes")!!,
                call.argument<Boolean>("wifiOnly")!!,
                if (call.argument<Boolean>("keep") == true) ExistingWorkPolicy.KEEP else ExistingWorkPolicy.REPLACE,
            )
            "unschedule" -> WorkManager.getInstance(context).cancelUniqueWork(ArchiveWorker.CHECK_NAME)
            // I cookie della WebView che ha superato la verifica del sito,
            // compresi quelli HttpOnly che da JavaScript non si vedono.
            "cookies" -> {
                result.success(CookieManager.getInstance().getCookie(call.argument<String>("url")!!))
                return
            }
            else -> {
                result.notImplemented()
                return
            }
        }
        result.success(null)
    }
}
