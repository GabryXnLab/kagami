package dev.local.kagami

import android.content.Context
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * Programma la sincronizzazione della cartella a un'ora fissa.
 *
 * Un lavoro periodico di ventiquattr'ore scivolerebbe: WorkManager conta il
 * periodo da quando il lavoro è partito davvero, e con la rete che si fa
 * aspettare l'ora scelta si sposterebbe un po' ogni giorno. Qui ogni giro è
 * un lavoro singolo che, finito, mette in coda il successivo alla stessa
 * ora del giorno dopo ([FolderSyncWorker]).
 *
 * Il lato Dart sta in `lib/src/data/folder_sync_schedule.dart`.
 */
class FolderSyncScheduler(messenger: BinaryMessenger, private val context: Context) :
    MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "kagami/sync-schedule")

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "schedule" -> {
                enqueue(
                    context,
                    call.argument<Int>("minutes")!!,
                    call.argument<Boolean>("wifiOnly")!!,
                    ExistingWorkPolicy.REPLACE,
                )
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
        const val NAME = "kagami.folder-sync"

        /**
         * Il prossimo giro all'ora [minutes] (dalla mezzanotte, ora del
         * telefono). Dall'app si usa `REPLACE`, che toglie quello di prima;
         * dal lavoro che sta finendo `APPEND_OR_REPLACE`, che accoda il
         * seguente senza fermare quello in corso.
         */
        fun enqueue(context: Context, minutes: Int, wifiOnly: Boolean, policy: ExistingWorkPolicy) {
            val now = System.currentTimeMillis()
            val next = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, minutes / 60)
                set(Calendar.MINUTE, minutes % 60)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (timeInMillis <= now) add(Calendar.DAY_OF_YEAR, 1)
            }
            val request = OneTimeWorkRequest.Builder(FolderSyncWorker::class.java)
                .setInitialDelay(next.timeInMillis - now, TimeUnit.MILLISECONDS)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(
                            if (wifiOnly) NetworkType.UNMETERED else NetworkType.CONNECTED,
                        )
                        .build(),
                )
                .setInputData(
                    Data.Builder()
                        .putInt(FolderSyncWorker.MINUTES, minutes)
                        .putBoolean(FolderSyncWorker.WIFI_ONLY, wifiOnly)
                        .build(),
                )
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(NAME, policy, request)
        }
    }
}
