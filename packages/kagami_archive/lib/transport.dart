/// Come si legge una libreria MALF che non sta su Drive: una cartella
/// raggiunta per percorsi (WebDAV, un domani SMB), dall'app e dal server.
///
/// I percorsi sono relativi alla radice del trasporto, separati da `/`,
/// senza `/` iniziale; `''` è la radice. La codifica per la rete la fa il
/// trasporto, quindi un titolo con spazi, `#` o lettere giapponesi si passa
/// com'è.
library;

import 'dart:io';

/// Un file o una cartella sul trasporto. [path] è nella stessa forma dei
/// percorsi che si passano: ciò che `list` restituisce si ripassa a `stat` e
/// `download` senza ritocchi.
class RemoteEntry {
  const RemoteEntry({
    required this.path,
    required this.name,
    required this.folder,
    this.size,
    this.modified,
    this.etag,
  });

  final String path;
  final String name;
  final bool folder;
  final int? size;
  final DateTime? modified;

  /// Com'è arrivato dal server, virgolette comprese.
  final String? etag;

  @override
  String toString() => 'RemoteEntry($path${folder ? '/' : ''})';
}

abstract interface class StorageTransport {
  /// Il contenuto di una cartella, senza la cartella stessa.
  /// [TransportNotFound] se la cartella non c'è.
  Future<List<RemoteEntry>> list(String path);

  /// `null` solo se il server ha risposto che non c'è; ogni altro esito che
  /// non è una risposta è un'eccezione (non ho potuto chiedere ≠ non c'è).
  Future<RemoteEntry?> stat(String path);

  Future<String> text(String path);

  /// Scarica in [target] a flusso. Con [resumeFrom] riprende da lì se il
  /// server lo concede, altrimenti riscrive da capo. Se la rete cade, ciò
  /// che era arrivato resta in [target], da cui si riprende.
  Future<void> download(String path, File target, {int resumeFrom = 0});

  void close();
}

/// Per archiviare su una sorgente: dichiarata, nessuno la implementa ancora.
abstract interface class WritableTransport implements StorageTransport {
  Future<void> upload(String path, File source);
  Future<void> createFolder(String path);
  Future<void> remove(String path);
  Future<void> rename(String from, String to);
}

class TransportException implements Exception {
  const TransportException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;
}

/// La sorgente non risponde: rete che manca, host spento, tempo scaduto.
/// Come `DriveOffline`, è uno stato che passa.
class TransportOffline extends TransportException {
  const TransportOffline([super.message = 'La sorgente non risponde']);
}

/// Credenziali mancanti, sbagliate o senza permesso: serve un gesto
/// dell'utente, non un nuovo tentativo.
class TransportAuthRequired extends TransportException {
  const TransportAuthRequired({super.status})
      : super('La sorgente chiede utente e password');
}

class TransportNotFound extends TransportException {
  const TransportNotFound() : super('Non trovato sulla sorgente', status: 404);
}

/// Il tetto di un file letto intero come testo (indici, siti). Il più grande
/// misurato è un `pages.json` di qualche MiB; un file di una libreria altrui
/// oltre questo è un errore di quel file, non la memoria del telefono.
const int textLimitBytes = 64 * 1024 * 1024;

/// Il tetto di un file scaricato su disco (una tavola, una copertina): non
/// pesa sulla memoria, ma una sorgente che non finisce mai non deve riempire
/// il disco. Si applica mentre arriva, non a download finito.
const int downloadLimitBytes = 1024 * 1024 * 1024;

/// Se un percorso letto da un indice MALF (`path`, `cover`, `file` di una
/// tavola o di una tessera) è ammesso: relativo, con segmenti separati da `/`,
/// non vuoti, né `.` né `..`, senza `\` né NUL, e senza `:` nel primo segmento
/// (unità di Windows, `file:`, `content:`). La regola è di `docs/malf.md`:
/// gli indici di una libreria altrui sono scritti da chi la condivide, e un
/// `..` porterebbe letture e scritture fuori dalla sua cartella.
bool isIndexPath(String path) {
  if (path.isEmpty || path.contains(r'\') || path.contains('\u0000')) return false;
  final segments = path.split('/');
  if (segments.first.contains(':')) return false;
  for (final segment in segments) {
    if (segment.isEmpty || segment == '.' || segment == '..') return false;
  }
  return true;
}

/// I segmenti di un percorso del trasporto; un segmento vuoto, `.` o `..`
/// è un errore di chi chiama, e non deve arrivare in rete.
List<String> transportSegments(String path) {
  if (path.isEmpty) return const [];
  final segments = path.split('/');
  for (final segment in segments) {
    if (segment.isEmpty || segment == '.' || segment == '..') {
      throw ArgumentError.value(path, 'path', 'percorso non valido');
    }
  }
  return segments;
}
