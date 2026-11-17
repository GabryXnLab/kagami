/// La pagina resa dal browser (`browser.pages`, `docs/siti.md`): per i siti
/// che costruiscono serie, tavole o risultati solo col JavaScript.
///
/// Il pacchetto un browser non ce l'ha: lo installa chi ospita il motore, il
/// server col suo Chromium, il telefono Android con la WebView invisibile.
/// Senza, le pagine da rendere falliscono con [RendererMissing].
library;

import 'model.dart' show ProviderError;

/// Un browser che apre una pagina e ne dà il DOM serializzato.
abstract interface class PageRenderer {
  /// `document.documentElement.outerHTML` di [url] appena [ready], un'espressione
  /// JavaScript scritta dal motore (mai dal file del sito), è vera; `null` se
  /// entro [timeout] non lo diventa o se la pagina finisce fuori da [hosts].
  Future<String?> render(String url, {required List<String> hosts, required String ready, required Duration timeout});
}

PageRenderer? _renderer;

/// Il browser di questo processo; `null` lo toglie.
void installPageRenderer(PageRenderer? renderer) => _renderer = renderer;

/// Il browser installato, se c'è.
PageRenderer? get pageRenderer => _renderer;

/// Il sito va letto da un browser, e qui non ce n'è.
class RendererMissing extends ProviderError {
  const RendererMissing(super.message);
}

/// Il browser non ha visto la pagina pronta entro il tempo.
class RenderTimeout extends ProviderError {
  const RenderTimeout(super.message);
}
