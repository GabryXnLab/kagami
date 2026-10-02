package dev.local.kagami

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapRegionDecoder
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

/**
 * Miniatura della copertina e tessere delle tavole alte, per l'archivio.
 *
 * Sul server le fa Pillow (`mangaarchive/images.py`); qui Android, perché
 * decodificare e ricodificare in Dart una tavola da 16383 pixel vorrebbe
 * dire una bitmap da decine di megabyte nella memoria di Dart. Il lato Dart
 * sta in `lib/src/archive/image_tools.dart`, e senza questo canale rinuncia:
 * una tavola senza tessere resta una tavola MALF valida.
 *
 * Le tessere sono le stesse del server: parti uguali dall'alto in basso,
 * alte quanto chiede Dart, WebP con perdita alla qualità data. La tavola si
 * decodifica **una volta** e le tessere se ne ritagliano: il decodificatore
 * WebP non sa saltare le righe sopra un ritaglio, e ritagliare dal file
 * costerebbe l'ultima tessera quanto la tavola intera. Solo una tavola
 * troppo grande per stare in memoria si ritaglia dal file.
 *
 * Due thread in secondo piano: l'archivio scarica più tavole insieme e con
 * uno solo le tessere diventavano la fila; più di due tavole decodificate
 * insieme (fino a 64 MB l'una) sono troppa memoria per un telefono che
 * intanto può stare leggendo.
 */
class ArchiveImages(messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "kagami/archive-images")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newFixedThreadPool(2) { runnable ->
        Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND)
            runnable.run()
        }, "kagami-archive-images")
    }

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path == null) {
            result.notImplemented()
            return
        }
        val work: () -> Any? = when (call.method) {
            "thumbnail" -> {
                { thumbnail(File(path), call.argument<Int>("width")!!, call.argument<Int>("height")!!) }
            }
            "tiles" -> {
                { tiles(File(path), call.argument<List<Int>>("heights")!!, call.argument<Int>("quality")!!) }
            }
            else -> {
                result.notImplemented()
                return
            }
        }
        worker.execute {
            val answer = try {
                work()
            } catch (_: Throwable) {
                // Anche un OutOfMemoryError: una tessera che non si fa non
                // deve far cadere l'app, il lettore leggerà la tavola.
                null
            }
            main.post { result.success(answer) }
        }
    }

    /** Come `Image.thumbnail` di Pillow: rimpicciolisce, non ingrandisce mai. */
    private fun thumbnail(file: File, width: Int, height: Int): ByteArray? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= width && bounds.outHeight / (sample * 2) >= height) {
            sample *= 2
        }
        val decoded = BitmapFactory.decodeFile(
            file.path,
            BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: return null
        val scale = minOf(1.0, width.toDouble() / decoded.width, height.toDouble() / decoded.height)
        val target = if (scale < 1.0) {
            Bitmap.createScaledBitmap(
                decoded,
                maxOf(1, (decoded.width * scale).toInt()),
                maxOf(1, (decoded.height * scale).toInt()),
                true,
            )
        } else {
            decoded
        }
        try {
            return encode(target, 80)
        } finally {
            if (target !== decoded) target.recycle()
            decoded.recycle()
        }
    }

    private fun tiles(file: File, heights: List<Int>, quality: Int): List<ByteArray>? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        val width = bounds.outWidth
        val height = bounds.outHeight
        // Le dimensioni del record non sono quelle del file: meglio nessuna
        // tessera che tessere che non combaciano con l'indice.
        if (width <= 0 || height != heights.sum()) return null
        return if (width.toLong() * height * 4 <= WHOLE_LIMIT) {
            val page = BitmapFactory.decodeFile(file.path) ?: return null
            try {
                var top = 0
                heights.map { tall ->
                    val piece = Bitmap.createBitmap(page, 0, top, width, tall)
                    top += tall
                    try {
                        encode(piece, quality)
                    } finally {
                        if (piece !== page) piece.recycle()
                    }
                }
            } finally {
                page.recycle()
            }
        } else {
            val decoder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                BitmapRegionDecoder.newInstance(file.path)
            } else {
                @Suppress("DEPRECATION")
                BitmapRegionDecoder.newInstance(file.path, false)
            } ?: return null
            try {
                var top = 0
                heights.map { tall ->
                    val piece = decoder.decodeRegion(Rect(0, top, width, top + tall), null)
                        ?: return null
                    top += tall
                    try {
                        encode(piece, quality)
                    } finally {
                        piece.recycle()
                    }
                }
            } finally {
                decoder.recycle()
            }
        }
    }

    private fun encode(bitmap: Bitmap, quality: Int): ByteArray {
        val format = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Bitmap.CompressFormat.WEBP_LOSSY
        } else {
            @Suppress("DEPRECATION")
            Bitmap.CompressFormat.WEBP
        }
        val output = ByteArrayOutputStream()
        bitmap.compress(format, quality, output)
        return output.toByteArray()
    }

    companion object {
        /** Oltre, la tavola intera non si tiene in memoria: 64 MB di pixel. */
        private const val WHOLE_LIMIT = 64L shl 20
    }
}
