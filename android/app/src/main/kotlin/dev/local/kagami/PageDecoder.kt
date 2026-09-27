package dev.local.kagami

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapRegionDecoder
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.os.Build
import android.os.Debug
import android.os.Handler
import android.os.Looper
import android.os.Process
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMethodCodec
import io.flutter.view.TextureRegistry
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Decodifica una **fascia** di tavola invece della tavola intera, e taglia in
 * tessere le tavole alte che l'archivio non ha ancora diviso.
 *
 * Il lettore ci arriva solo per le tavole alte senza tessere: le tessere
 * dell'archivio, le tavole basse e le tessere già tagliate qui sono file
 * interi, e li decodifica il codec di Flutter. Il lato Dart sta in
 * `lib/src/data/page_decoder.dart` e sa cavarsela senza questo canale.
 *
 * La risposta non passa da `MethodChannel`. Da Flutter 3.29 il thread di
 * Android e quello dell'interfaccia sono lo stesso, e una fascia sono
 * megabyte di pixel: il codec standard li ricopiava sul thread principale.
 * Qui i pixel finiscono in un buffer nativo sul thread del decodificatore, e
 * la risposta parte da lì.
 *
 * Una tavola alta non si ritaglia fascia per fascia dal file: il
 * decodificatore WebP non sa saltare le righe sopra il ritaglio, e l'ultima
 * fascia di una tavola da 16383 px costava quanto la tavola intera. La tavola
 * si decodifica una volta, resta qui (due al massimo) e le fasce se ne
 * ritagliano; solo quelle troppo grandi per starci restano al ritaglio dal
 * file.
 *
 * Niente di tutto questo alloca a ogni fascia: le tavole si decodificano
 * dentro bitmap già esistenti (`inBitmap`), le fasce si disegnano in una
 * bitmap riusata e la risposta in un buffer riusato. Ogni bitmap nativa nuova
 * è memoria che il GC di Android deve contare, e le tavole ne erano
 * cinquanta megabyte l'una.
 *
 * Un thread solo, con due file: prima le fasce che lo schermo aspetta, poi il
 * taglio in tessere, un pezzo alla volta — la decodifica della tavola, poi
 * una tessera — così una fascia chiesta aspetta al più una tessera. Il taglio
 * lavora sulla tavola che viene dopo quella sullo schermo, quindi è anche la
 * sua decodifica anticipata.
 *
 * Con le texture accese la fascia non torna a Dart: la si copia in una bitmap
 * `HARDWARE` e la si disegna su un [TextureRegistry.SurfaceProducer], che il
 * lettore mostra con un `Texture`. La bitmap resta finché la texture vive,
 * per ridisegnarla se la superficie viene rifatta.
 *
 * Risposta, little-endian: dodici `int32` — esito (0 riuscita, 1 errore,
 * 2 texture non disponibili), larghezza, altezza, byte per riga,
 * microsecondi di lavoro, raccolte e millisecondi del GC di Android, raccolte
 * e millisecondi bloccanti, numero della texture (-1 se ci sono i pixel), se
 * per questa fascia si è decodificata una tavola intera, uno di riserva — poi,
 * se non è una texture, i pixel RGBA.
 */
class PageDecoder(
    private val messenger: BinaryMessenger,
    private val textures: TextureRegistry,
) : BinaryMessenger.BinaryMessageHandler {
    private val main = Handler(Looper.getMainLooper())
    private val lock = Object()
    private val urgent = ArrayDeque<() -> Unit>()
    private var job: TileJob? = null

    @Volatile
    private var running = true

    // In sottofondo: una tavola intera costa fino a un quarto di secondo di
    // CPU, e non deve prendersi i core veloci che servono a chi disegna.
    private val worker = Thread({
        Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND)
        loop()
    }, "kagami-pages").apply { start() }

    // Aprire il file e leggerne l'intestazione costa quanto una decodifica
    // piccola, e di una stessa tavola si chiedono molte fasce di fila.
    private val open = object : LinkedHashMap<String, BitmapRegionDecoder>(4, 0.75f, true) {
        override fun removeEldestEntry(eldest: Map.Entry<String, BitmapRegionDecoder>): Boolean {
            if (size <= MAX_OPEN) return false
            eldest.value.recycle()
            return true
        }
    }

    // Le tavole intere da cui si ritagliano le fasce, per sottocampionamento
    // e percorso: quella sullo schermo e quella che si sta tagliando.
    private val pages = LinkedHashMap<String, Bitmap>(4, 0.75f, true)

    // L'ultima tavola uscita: la prossima si decodifica dentro di lei.
    private var spare: Bitmap? = null

    // La fascia in uscita, riusata: la si riconfigura alla misura di ognuna.
    private var band: Bitmap? = null
    private val canvas = Canvas()
    private val paint = Paint(Paint.FILTER_BITMAP_FLAG)

    // Il buffer della risposta, riusato: l'engine lo copia prima che `reply`
    // torni.
    private var out: ByteBuffer? = null

    private var pageDecoded = false

    private val live = HashMap<Long, BandTexture>()
    private val idle = ArrayDeque<BandTexture>()

    init {
        messenger.setMessageHandler(CHANNEL, this, messenger.makeBackgroundTaskQueue())
    }

    fun dispose() {
        messenger.setMessageHandler(CHANNEL, null)
        enqueue {
            open.values.forEach { it.recycle() }
            open.clear()
            pages.values.forEach { it.recycle() }
            pages.clear()
            spare?.recycle()
            spare = null
            band?.recycle()
            band = null
            out = null
            val producers = (live.values + idle).map { it.producer }
            live.values.forEach { it.forget() }
            idle.forEach { it.forget() }
            live.clear()
            idle.clear()
            main.post { producers.forEach { it.release() } }
            job?.let { finish(it, false) }
            running = false
        }
    }

    override fun onMessage(message: ByteBuffer?, reply: BinaryMessenger.BinaryReply) {
        val call = message?.let { StandardMethodCodec.INSTANCE.decodeMethodCall(it) }
        when (call?.method) {
            "decode" -> {
                val path = call.argument<String>("path") ?: return reply.reply(failure())
                val top = call.argument<Int>("top") ?: 0
                val height = call.argument<Int>("height") ?: 0
                val targetWidth = call.argument<Int>("targetWidth") ?: 0
                val maxPixels = call.argument<Int>("maxPixels") ?: Int.MAX_VALUE
                val texture = call.argument<Boolean>("texture") ?: false
                enqueue {
                    val answer = try {
                        decode(path, top, height, targetWidth, maxPixels, texture)
                    } catch (error: Throwable) {
                        failure(if (texture && error is NoTextures) STATUS_NO_TEXTURES else STATUS_FAILED)
                    }
                    reply.reply(answer)
                }
            }
            "release" -> {
                val id = (call.argument<Number>("texture"))?.toLong()
                enqueue {
                    if (id != null) release(id)
                    reply.reply(success())
                }
            }
            "tile" -> {
                val path = call.argument<String>("path")
                val directory = call.argument<String>("directory")
                val bandHeight = call.argument<Int>("bandHeight") ?: 0
                val targetWidth = call.argument<Int>("targetWidth") ?: 0
                if (path == null || directory == null || bandHeight <= 0) {
                    reply.reply(failure())
                    return
                }
                val next = TileJob(path, File(directory), bandHeight, targetWidth, reply)
                synchronized(lock) {
                    // Il lato Dart ne chiede uno alla volta; uno nuovo vuol dire
                    // che il vecchio non serve più.
                    job?.let { finish(it, false) }
                    job = next
                    lock.notifyAll()
                }
            }
            else -> reply.reply(failure())
        }
    }

    private fun enqueue(task: () -> Unit) {
        synchronized(lock) {
            urgent.addLast(task)
            lock.notifyAll()
        }
    }

    private fun loop() {
        while (running) {
            var task: (() -> Unit)? = null
            var tiling: TileJob? = null
            synchronized(lock) {
                while (running && urgent.isEmpty() && job == null) lock.wait()
                task = urgent.removeFirstOrNull()
                if (task == null) tiling = job
            }
            try {
                task?.invoke() ?: tiling?.let { step(it) }
            } catch (error: Throwable) {
                tiling?.let { finish(it, false) }
            }
        }
    }

    private fun success(): ByteBuffer =
        ByteBuffer.allocateDirect(4).order(ByteOrder.LITTLE_ENDIAN).putInt(0)

    // L'engine legge la risposta fino alla posizione del buffer, non fino al
    // limite: il buffer si consegna così com'è dopo averlo scritto.
    private fun failure(status: Int = STATUS_FAILED): ByteBuffer =
        ByteBuffer.allocateDirect(4).order(ByteOrder.LITTLE_ENDIAN).putInt(status)

    private fun decode(
        path: String,
        top: Int,
        height: Int,
        targetWidth: Int,
        maxPixels: Int,
        texture: Boolean,
    ): ByteBuffer {
        val started = System.nanoTime()
        pageDecoded = false
        val cut = cut(path, top, height, targetWidth, maxPixels)
        val micros = ((System.nanoTime() - started) / 1000).toInt()
        try {
            if (texture) {
                // Le superfici con i buffer della GPU ci sono dalla 29: prima
                // Flutter ripiega su SurfaceTexture, che qui non si prova.
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) throw NoTextures()
                val id = try {
                    show(cut.bitmap)
                } catch (error: Throwable) {
                    throw NoTextures()
                }
                return header(HEADER, cut.bitmap, micros, id)
            }
            val buffer = header(HEADER + cut.bitmap.byteCount, cut.bitmap, micros, -1)
            cut.bitmap.copyPixelsToBuffer(buffer)
            return buffer
        } finally {
            if (cut.owned) cut.bitmap.recycle()
        }
    }

    /** Una fascia pronta: nella bitmap riusata, o in una propria da buttare. */
    private class Cut(val bitmap: Bitmap, val owned: Boolean)

    /** Le righe da [top] per [height] della tavola, larghe al più [targetWidth]. */
    private fun cut(path: String, top: Int, height: Int, targetWidth: Int, maxPixels: Int): Cut {
        val decoder = decoder(path)
        val full = Rect(0, 0, decoder.width, decoder.height)
        val rows = if (height <= 0) {
            full
        } else {
            Rect(0, top.coerceIn(0, decoder.height), decoder.width,
                (top + height).coerceIn(0, decoder.height))
        }
        if (rows.width() <= 0 || rows.height() <= 0) {
            throw IllegalStateException("fascia vuota: $path")
        }
        // Il sottocampionamento è l'unico modo di non pagare i pixel che non
        // si vedranno: si scende finché la fascia resta almeno larga quanto lo
        // schermo la mostrerà.
        var sample = 1
        while (targetWidth > 0 && rows.width() / (sample * 2) >= targetWidth) sample *= 2
        // L'ultima difesa: una tavola chiesta intera non deve diventare una
        // bitmap da cinquanta megabyte per il solo fatto di essere alta.
        while (
            sample < 1 shl 10 &&
            (rows.width().toLong() / sample) * (rows.height().toLong() / sample) > maxPixels
        ) sample *= 2
        val page = if (rows != full) page(path, sample) else null
        if (page != null) {
            val from = Rect(0, (rows.top / sample).coerceIn(0, page.height - 1), page.width,
                ((rows.bottom + sample - 1) / sample).coerceIn(1, page.height))
            return Cut(draw(page, from, targetWidth), false)
        }
        val options = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val region = decoder.decodeRegion(rows, options)
            ?: throw IllegalStateException("fascia non decodificata: $path")
        if (targetWidth <= 0 || region.width <= targetWidth) return Cut(region, true)
        val drawn = draw(region, Rect(0, 0, region.width, region.height), targetWidth)
        region.recycle()
        return Cut(drawn, false)
    }

    /**
     * Il pezzo [from] di [source] nella bitmap riusata, ridotto a [targetWidth]
     * se è più largo: il sottocampionamento scende a potenze di due, e il resto
     * lo toglie la riduzione, che è sempre meno pixel di quelli appena letti.
     */
    private fun draw(source: Bitmap, from: Rect, targetWidth: Int): Bitmap {
        val width = if (targetWidth > 0 && from.width() > targetWidth) targetWidth else from.width()
        val height = (from.height().toLong() * width / from.width()).toInt().coerceAtLeast(1)
        val target = bandBitmap(width, height)
        canvas.setBitmap(target)
        canvas.drawBitmap(source, from, Rect(0, 0, width, height), paint)
        canvas.setBitmap(null)
        return target
    }

    private fun bandBitmap(width: Int, height: Int): Bitmap {
        val need = width.toLong() * height * 4
        val current = band
        if (current != null && !current.isRecycled && current.allocationByteCount >= need) {
            if (current.width != width || current.height != height) {
                current.reconfigure(width, height, Bitmap.Config.ARGB_8888)
            }
            return current
        }
        current?.recycle()
        // Un po' più alta del necessario: le fasce hanno quasi tutte la stessa
        // misura, ma le tavole cambiano larghezza.
        val fresh = Bitmap.createBitmap(width, maxOf(height, BAND_ROWS), Bitmap.Config.ARGB_8888)
        fresh.reconfigure(width, height, Bitmap.Config.ARGB_8888)
        band = fresh
        return fresh
    }

    /** La tavola intera sottocampionata, o `null` se è troppo grande per tenerla. */
    private fun page(path: String, sample: Int): Bitmap? {
        val key = "$sample|$path"
        pages[key]?.let { if (!it.isRecycled) return it }
        val decoder = decoder(path)
        val need = (decoder.width / sample + 1).toLong() * (decoder.height / sample + 1) * 4
        if (need > MAX_PAGE_BYTES) return null
        val options = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inMutable = true
        }
        val reuse = spare?.takeIf { !it.isRecycled && it.allocationByteCount >= need }
        if (reuse != null) {
            spare = null
            options.inBitmap = reuse
        }
        val page = try {
            BitmapFactory.decodeFile(path, options)
        } catch (error: IllegalArgumentException) {
            null
        } ?: run {
            // La bitmap da riusare non andava bene per questo file: se ne fa
            // una nuova, una volta.
            reuse?.let { keepSpare(it) }
            options.inBitmap = null
            BitmapFactory.decodeFile(path, options)
        } ?: throw IllegalStateException("tavola non decodificata: $path")
        pageDecoded = true
        pages[key] = page
        while (pages.size > MAX_PAGES) {
            val eldest = pages.entries.first()
            pages.remove(eldest.key)
            keepSpare(eldest.value)
        }
        return page
    }

    private fun keepSpare(bitmap: Bitmap) {
        val current = spare
        if (current == null || current.isRecycled ||
            current.allocationByteCount < bitmap.allocationByteCount
        ) {
            current?.recycle()
            spare = bitmap
        } else {
            bitmap.recycle()
        }
    }

    private fun header(size: Int, bitmap: Bitmap, micros: Int, texture: Long): ByteBuffer {
        var buffer = out
        if (buffer == null || buffer.capacity() < size) {
            buffer = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN)
            // Una fascia fuori misura non si tiene: le altre sono molto più
            // piccole.
            out = if (size <= MAX_KEPT_BUFFER) buffer else out
        }
        buffer!!.clear()
        // Una riga può essere più lunga della sua larghezza: la bitmap la
        // allinea come le conviene, e chi legge i pixel deve saperlo.
        buffer.putInt(STATUS_OK)
            .putInt(bitmap.width)
            .putInt(bitmap.height)
            .putInt(bitmap.rowBytes)
            .putInt(micros)
            .putInt(stat("art.gc.gc-count"))
            .putInt(stat("art.gc.gc-time"))
            .putInt(stat("art.gc.blocking-gc-count"))
            .putInt(stat("art.gc.blocking-gc-time"))
            .putInt(texture.toInt())
            .putInt(if (pageDecoded) 1 else 0)
            .putInt(0)
        return buffer
    }

    private fun stat(name: String): Int = Debug.getRuntimeStat(name)?.toLongOrNull()?.toInt() ?: 0

    private fun decoder(path: String): BitmapRegionDecoder {
        open[path]?.let { if (!it.isRecycled) return it }
        val file = File(path)
        if (!file.isFile) throw IllegalStateException("tavola assente: $path")
        val decoder = FileInputStream(file).use { stream ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                BitmapRegionDecoder.newInstance(stream)
            } else {
                @Suppress("DEPRECATION")
                BitmapRegionDecoder.newInstance(stream, false)
            }
        } ?: throw IllegalStateException("formato non ritagliabile: $path")
        open[path] = decoder
        return decoder
    }

    // ---- Tessere del telefono ----

    private class TileJob(
        val path: String,
        val directory: File,
        val bandHeight: Int,
        val targetWidth: Int,
        val reply: BinaryMessenger.BinaryReply,
    ) {
        var next = 0
        var height = -1
        var done = false
    }

    /** Un pezzo del taglio: la prima volta la misura, poi una tessera. */
    private fun step(job: TileJob) {
        if (job.height < 0) {
            job.height = decoder(job.path).height
            job.directory.mkdirs()
        }
        if (job.next >= job.height) {
            File(job.directory, "done").writeText("")
            finish(job, true)
            return
        }
        val rows = minOf(job.bandHeight, job.height - job.next)
        val cut = cut(job.path, job.next, rows, job.targetWidth, Int.MAX_VALUE)
        try {
            val target = File(job.directory, "${job.next}.jpg")
            val partial = File(job.directory, "${job.next}.jpg.part")
            FileOutputStream(partial).use { stream ->
                if (!cut.bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, stream)) {
                    throw IllegalStateException("tessera non scritta: ${job.path}")
                }
            }
            if (!partial.renameTo(target)) throw IllegalStateException("tessera non salvata")
        } finally {
            if (cut.owned) cut.bitmap.recycle()
        }
        job.next += rows
    }

    private fun finish(job: TileJob, ok: Boolean) {
        synchronized(lock) {
            if (job.done) return
            job.done = true
            if (this.job === job) this.job = null
        }
        job.reply.reply(if (ok) success() else failure())
    }

    // ---- Texture ----

    private class NoTextures : Exception()

    /** Una texture del lettore: il produttore di superfici e ciò che mostra. */
    private inner class BandTexture(val producer: TextureRegistry.SurfaceProducer) :
        TextureRegistry.SurfaceProducer.Callback {
        var picture: Bitmap? = null

        @RequiresApi(Build.VERSION_CODES.Q)
        fun show(bitmap: Bitmap) {
            val copy = bitmap.copy(Bitmap.Config.HARDWARE, false)
                ?: throw IllegalStateException("texture non caricata")
            picture?.recycle()
            picture = copy
            producer.setSize(copy.width, copy.height)
            draw()
        }

        fun draw() {
            val shown = picture ?: return
            val surface = producer.surface
            if (!surface.isValid) return
            val canvas = surface.lockHardwareCanvas()
            try {
                canvas.drawBitmap(shown, 0f, 0f, null)
            } finally {
                surface.unlockCanvasAndPost(canvas)
            }
        }

        fun forget() {
            picture?.recycle()
            picture = null
        }

        // La superficie è stata rifatta (dopo che il sistema ha chiesto
        // memoria): si ridisegna la stessa fascia, dal thread del
        // decodificatore come tutto il resto.
        override fun onSurfaceAvailable() {
            enqueue { runCatching { draw() } }
        }

        override fun onSurfaceCleanup() {}
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun show(bitmap: Bitmap): Long {
        val entry = idle.removeFirstOrNull() ?: create()
        try {
            entry.show(bitmap)
        } catch (error: Throwable) {
            entry.forget()
            idle.addLast(entry)
            throw error
        }
        val id = entry.producer.id()
        live[id] = entry
        return id
    }

    /** Un produttore nuovo: si crea sul thread principale, e lo si aspetta. */
    private fun create(): BandTexture {
        var made: BandTexture? = null
        val ready = CountDownLatch(1)
        main.post {
            try {
                val producer = textures.createSurfaceProducer()
                made = BandTexture(producer).also { producer.setCallback(it) }
            } finally {
                ready.countDown()
            }
        }
        if (!ready.await(2, TimeUnit.SECONDS)) throw IllegalStateException("texture non creata")
        return made ?: throw IllegalStateException("texture non creata")
    }

    private fun release(id: Long) {
        val entry = live.remove(id) ?: return
        entry.forget()
        if (idle.size < MAX_IDLE) {
            idle.addLast(entry)
        } else {
            main.post { entry.producer.release() }
        }
    }

    private companion object {
        const val CHANNEL = "kagami/pages"
        const val MAX_OPEN = 4
        const val MAX_PAGES = 2
        const val MAX_PAGE_BYTES = 64L shl 20
        const val MAX_KEPT_BUFFER = 16 shl 20
        const val MAX_IDLE = 16
        const val BAND_ROWS = 1024
        const val HEADER = 48
        const val JPEG_QUALITY = 95
        const val STATUS_OK = 0
        const val STATUS_FAILED = 1
        const val STATUS_NO_TEXTURES = 2
    }
}
