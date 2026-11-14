/// Lo scaffale di una sorgente già esistente, rivestito del contratto delle
/// sorgenti.
library;

import '../library.dart';
import 'source.dart';

/// Un involucro sottile: la cartella scelta, lo spazio dell'app e il Drive
/// dell'account hanno già il loro scaffale (e i loro provider), e qui si
/// limitano a dire chi sono e cosa permettono. Nessuna logica di lettura.
class ShelfSource implements StorageSource {
  ShelfSource({
    required this.config,
    required this.shelf,
    this.capabilities = const SourceCapabilities(
      write: true,
      trash: true,
      closedApp: true,
    ),
    this.files,
  });

  @override
  final SourceConfig config;

  @override
  final LibraryShelf shelf;

  @override
  final SourceCapabilities capabilities;

  @override
  final RemoteFiles? files;

  /// Lo scaffale c'è già: se non risponde lo dice leggendo, con
  /// [SourceUnavailable], e non c'è niente da chiedere prima.
  @override
  Future<SourceState> probe() async => SourceState.ready;

  /// Chi ha creato lo scaffale lo chiude: l'involucro non possiede niente.
  @override
  void dispose() {}
}
