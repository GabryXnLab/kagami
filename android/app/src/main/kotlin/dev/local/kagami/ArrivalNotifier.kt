package dev.local.kagami

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.work.Data
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

/**
 * Le notifiche dei capitoli nuovi, una per serie.
 *
 * Quando e di cosa avvisare lo decide Dart (`lib/src/data/arrivals.dart`);
 * qui c'è solo il sistema. Ogni notifica ha per etichetta la chiave della
 * serie, quindi un secondo arrivo aggiorna quella già mostrata invece di
 * aggiungerne un'altra, e aprire la scheda la toglie. Toccarla apre la
 * scheda: la chiave torna a Dart con `open`, o con `launched` se l'app era
 * chiusa e il tocco l'ha avviata.
 *
 * Con `watch` Dart consegna ciò che serve a controllare la cartella locale
 * ad app chiusa, e qui si programma `LibraryWatchWorker`.
 *
 * Il lato Dart sta in `lib/src/data/notifications.dart`.
 */
class ArrivalNotifier(messenger: BinaryMessenger, private val context: Context) :
    MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "kagami/notifications")
    private var launched: String? = null

    init {
        channel.setMethodCallHandler(this)
    }

    /** L'intent con cui l'app è partita: Dart lo chiede quando è pronto. */
    fun launchedBy(intent: Intent?) {
        launched = intent?.getStringExtra(EXTRA_SERIES)
    }

    /** Un tocco sulla notifica con l'app già aperta. */
    fun opened(intent: Intent?) {
        val key = intent?.getStringExtra(EXTRA_SERIES) ?: return
        channel.invokeMethod("open", key)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "show" -> {
                show(
                    context,
                    call.argument<String>("key")!!,
                    call.argument<String>("title")!!,
                    call.argument<String>("text")!!,
                )
                result.success(null)
            }
            "dismiss" -> {
                context.getSystemService(NotificationManager::class.java)
                    .cancel(call.argument<String>("key")!!, NOTIFICATION_ID)
                result.success(null)
            }
            "watch" -> {
                watch(call.argument<String>("watch")!!, call.argument<String>("record")!!)
                result.success(null)
            }
            "launched" -> {
                result.success(launched)
                launched = null
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Ogni ora, finché l'app resta installata. `UPDATE` sostituisce i
     * percorsi senza ripartire da zero col conto del periodo.
     */
    private fun watch(watchFile: String, recordFile: String) {
        val request = PeriodicWorkRequest.Builder(
            LibraryWatchWorker::class.java,
            1,
            TimeUnit.HOURS,
        ).setInputData(
            Data.Builder()
                .putString(LibraryWatchWorker.WATCH, watchFile)
                .putString(LibraryWatchWorker.RECORD, recordFile)
                .build(),
        ).build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            LibraryWatchWorker.NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            request,
        )
    }

    companion object {
        const val EXTRA_SERIES = "dev.local.kagami.series"
        private const val CHANNEL_ID = "arrivals"
        private const val GROUP = "dev.local.kagami.arrivals"
        private const val NOTIFICATION_ID = 1

        fun show(context: Context, key: String, title: String, text: String) {
            val manager = context.getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        "Capitoli nuovi",
                        NotificationManager.IMPORTANCE_DEFAULT,
                    ).apply {
                        description = "Un capitolo nuovo di una serie che segui è arrivato nella libreria."
                    },
                )
            }
            // Il dato rende l'intent diverso per ogni serie: con intent uguali il
            // sistema riuserebbe lo stesso PendingIntent, e ogni notifica
            // aprirebbe la serie dell'ultima.
            val intent = Intent(context, MainActivity::class.java)
                .setAction(Intent.ACTION_VIEW)
                .setData(Uri.fromParts("kagami", "series", key))
                .putExtra(EXTRA_SERIES, key)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val tap = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
            val notification = builder
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(title)
                .setContentText(text)
                .setContentIntent(tap)
                .setAutoCancel(true)
                .setGroup(GROUP)
                .setCategory(Notification.CATEGORY_RECOMMENDATION)
                .build()
            manager.notify(key, NOTIFICATION_ID, notification)
        }
    }
}
