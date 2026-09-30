package dev.local.kagami

import android.content.Context
import android.os.Build
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONException
import org.json.JSONObject
import java.io.File
import java.time.OffsetDateTime

/**
 * I capitoli nuovi della cartella locale, ad app chiusa.
 *
 * FolderSync porta i capitoli quando vuole, e l'app se ne accorge solo
 * rileggendo la libreria. Questo lavoro, ogni ora, rilegge `library.json`
 * della cartella scelta — un file solo, com'è giusto per un indice — e
 * annuncia ciò che l'app avrebbe annunciato.
 *
 * Non conosce lo stato utente: gliel'ha lasciato Dart nel file [WATCH],
 * uscendo dall'app (`lib/src/data/notifications.dart`), con le sole serie da
 * annunciare e i loro conteggi. Ciò che annuncia lo scrive in [RECORD], che
 * Dart rilegge prima di confrontare, così un arrivo non suona due volte.
 * Drive resta fuori: servirebbe il token dell'account senza l'app.
 */
class LibraryWatchWorker(context: Context, parameters: WorkerParameters) :
    Worker(context, parameters) {

    // Un `library.json` a metà — FolderSync lo sta scrivendo proprio ora — non
    // è un errore: si riguarda al giro dopo.
    override fun doWork(): Result = try {
        check()
    } catch (_: JSONException) {
        Result.success()
    }

    private fun check(): Result {
        val watchFile = File(inputData.getString(WATCH) ?: return Result.success())
        val recordFile = File(inputData.getString(RECORD) ?: return Result.success())
        if (!watchFile.exists()) return Result.success()
        val watch = JSONObject(watchFile.readText())
        val index = File(watch.getString("root"), "library.json")
        if (!index.exists()) return Result.success()
        val series = JSONObject(index.readText()).optJSONArray("series")
            ?: return Result.success()
        val watched = watch.getJSONObject("series")
        val record = if (recordFile.exists()) JSONObject(recordFile.readText()) else JSONObject()

        var changed = false
        for (position in 0 until series.length()) {
            val entry = series.getJSONObject(position)
            val key = entry.optString("key")
            val mark = watched.optJSONObject(key) ?: continue
            val count = entry.optInt("archivedChapterCount")
            val notified = maxOf(mark.getInt("notified"), record.optInt(key))
            if (count <= notified) continue
            record.put(key, count)
            changed = true
            // Scheda aperta dopo l'ultimo arrivo, magari su un altro telefono:
            // quei capitoli li si è già visti.
            val arrived = arrivedAt(entry.optString("latestChapterArchivedAt"))
            val opened = mark.optLong("opened", 0)
            if (arrived != null && opened >= arrived) continue
            val fresh = minOf(count - mark.getInt("seen"), count - mark.getInt("read"))
            if (fresh <= 0) continue
            ArrivalNotifier.show(
                applicationContext,
                key,
                entry.optString("title", mark.optString("title")),
                applicationContext.resources.getQuantityString(R.plurals.arrivals_new, fresh, fresh),
            )
        }
        if (changed) recordFile.writeText(record.toString())
        return Result.success()
    }

    // `java.time` c'è da Android 8; prima si rinuncia al confronto con
    // l'apertura altrove, e resta quello coi conteggi.
    private fun arrivedAt(value: String): Long? =
        if (value.isEmpty() || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) null
        else runCatching { OffsetDateTime.parse(value).toInstant().toEpochMilli() }.getOrNull()

    companion object {
        const val NAME = "kagami.library-watch"
        const val WATCH = "watch"
        const val RECORD = "record"
    }
}
