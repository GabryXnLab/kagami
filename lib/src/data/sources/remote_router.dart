/// Chi smista un indirizzo remoto verso la sorgente che lo serve.
library;

import '../library.dart';

/// Il [RemoteFiles] dell'app quando le sorgenti remote possono essere più di
/// una: `drive:` va al Drive dell'account, `remote:<id>/` alla sorgente con
/// quell'id. Lettore e copertine continuano a chiedere un indirizzo a un
/// punto solo, senza sapere quante sorgenti ci sono.
///
/// Ogni sorgente riceve i suoi indirizzi interi, prefisso compreso, come
/// li ha scritti il suo scaffale.
class RemoteRouter implements RemoteFiles {
  /// Il Drive dell'account, quando è collegato.
  RemoteFiles? primary;

  final Map<String, RemoteFiles> _sources = {};

  void attach(String sourceId, RemoteFiles files) => _sources[sourceId] = files;

  /// Stacca la sorgente, ma solo se è ancora [files]: chi si spegne dopo che
  /// un'altra istanza ha preso il suo posto non la porta via con sé.
  void detach(String sourceId, RemoteFiles files) {
    if (identical(_sources[sourceId], files)) _sources.remove(sourceId);
  }

  RemoteFiles? _of(String address) {
    final id = sourceIdOf(address);
    return id != null
        ? _sources[id]
        : (address.startsWith(remotePrefix) ? primary : null);
  }

  /// Una sorgente che non c'è (staccata, scaduta, mai esistita) è un errore:
  /// mai un file vuoto, che il lettore mostrerebbe come una tavola bianca.
  @override
  Future<String> fetch(String address, {bool urgent = false}) {
    final files = _of(address);
    if (files == null) {
      return Future.error(StateError(
        sourceIdOf(address) == null
            ? 'Drive non è collegato'
            : 'La sorgente di $address non è collegata',
      ));
    }
    return files.fetch(address, urgent: urgent);
  }

  @override
  String? peek(String address) => _of(address)?.peek(address);

  @override
  void warm(Iterable<String> addresses) {
    for (final MapEntry(key: files, value: own) in _split(addresses).entries) {
      files.warm(own);
    }
  }

  @override
  void rememberChapter(String series, String chapter, List<String> addresses) {
    for (final MapEntry(key: files, value: own) in _split(addresses).entries) {
      files.rememberChapter(series, chapter, own);
    }
  }

  /// Gli indirizzi per sorgente, nell'ordine in cui sono arrivati; quelli di
  /// una sorgente che non c'è si lasciano cadere: precaricare è un favore.
  Map<RemoteFiles, List<String>> _split(Iterable<String> addresses) {
    final split = <RemoteFiles, List<String>>{};
    for (final address in addresses) {
      final files = _of(address);
      if (files != null) (split[files] ??= []).add(address);
    }
    return split;
  }
}
