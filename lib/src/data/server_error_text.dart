/// Il testo di un errore del server nella lingua dell'utente.
///
/// I messaggi di `ServerException` li scrive il motore (`packages/kagami_archive`)
/// in italiano, perché li produce anche il server, che una lingua non ce l'ha.
/// Quelli che nascono sul telefono o che il server dice con un `code` noto
/// si traducono qui; gli altri restano come arrivano.
library;

import 'package:kagami_archive/remote.dart' show ServerException;

import '../l10n.dart';

String serverErrorText(ServerException error) {
  final l10n = currentL10n();
  return switch (error.code) {
    'update_server' => l10n.serverErrorUpdateServer,
    'tickets_unavailable' => l10n.serverErrorTicketsUnavailable,
    'impostor' => l10n.serverErrorImpostor,
    'other_server' => l10n.serverErrorOtherServer,
    'not_owner' => l10n.serverErrorNotOwner,
    _ => error.message,
  };
}
