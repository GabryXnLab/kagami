package dev.local.kagami

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/**
 * Dice a Dart quando la rete va e viene.
 *
 * Senza, l'app se ne accorgerebbe solo riprovando a intervalli: con il
 * callback del sistema una tavola rimasta indietro riparte nel momento in cui
 * il telefono ritrova il segnale, non al prossimo tentativo. Il segnale è
 * `VALIDATED`, cioè una rete su cui il sistema ha verificato che internet
 * risponde davvero — il Wi-Fi di un albergo che chiede la password non conta.
 *
 * Il lato Dart sta in `lib/src/data/network.dart` e se questo canale manca —
 * build Linux, test — si arrangia con i suoi tentativi.
 */
class NetworkWatcher(messenger: BinaryMessenger, context: Context) : EventChannel.StreamHandler {
    private val channel = EventChannel(messenger, "kagami/network")
    private val connectivity =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var callback: ConnectivityManager.NetworkCallback? = null

    init {
        channel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        emit(online())
        val watcher = object : ConnectivityManager.NetworkCallback() {
            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                emit(capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED))
            }

            override fun onLost(network: Network) {
                // La rete persa può non essere l'unica: si chiede al sistema
                // come stanno le cose adesso invece di dire subito "niente".
                emit(online())
            }
        }
        callback = watcher
        connectivity.registerDefaultNetworkCallback(watcher)
    }

    override fun onCancel(arguments: Any?) {
        callback?.let { runCatching { connectivity.unregisterNetworkCallback(it) } }
        callback = null
        sink = null
    }

    fun dispose() {
        onCancel(null)
        channel.setStreamHandler(null)
    }

    private fun online(): Boolean {
        val network = connectivity.activeNetwork ?: return false
        val capabilities = connectivity.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    // Il callback arriva su un thread del sistema, il canale vuole il
    // principale.
    private fun emit(value: Boolean) {
        main.post { sink?.success(value) }
    }
}
