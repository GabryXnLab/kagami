package dev.local.kagami

import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Il testo condiviso con Kagami da un'altra app (Condividi → Kagami): uno o
 * più link, o il JSON di un'automazione. Dart decide che farne
 * (`lib/src/data/share_intake.dart`): un link solo si verifica in «Scarica un
 * manga», di più si importano in blocco.
 *
 * Come per le notifiche: l'intent che ha avviato l'app Dart lo chiede con
 * `launched` quando è pronto, uno arrivato con l'app aperta glielo si manda
 * con `shared`.
 */
class SharedText(messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "kagami/share")
    private var launched: String? = null

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "launched") return@setMethodCallHandler result.notImplemented()
            result.success(launched)
            launched = null
        }
    }

    fun launchedBy(intent: Intent?) {
        launched = textOf(intent)
    }

    fun opened(intent: Intent?) {
        val text = textOf(intent) ?: return
        channel.invokeMethod("shared", text)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun textOf(intent: Intent?): String? {
        if (intent?.type?.startsWith("text/") != true) return null
        val text = when (intent.action) {
            Intent.ACTION_SEND -> intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
            Intent.ACTION_SEND_MULTIPLE ->
                intent.getCharSequenceArrayListExtra(Intent.EXTRA_TEXT)?.joinToString("\n")
            else -> null
        }
        return text?.takeIf { it.isNotBlank() }
    }
}
