/// Una libreria MALF su SMB (un NAS di casa), in sola lettura. La prova di
/// connessione è quella del WebDAV (`probeWebDav`): cerca `library.json` su
/// un `StorageTransport`, qualunque sia.
library;

import 'package:kagami_archive/transport.dart';

import 'path_shelf.dart';
import 'smb_transport.dart';
import 'source.dart';

/// Il trasporto di una sorgente SMB: la password si legge dai segreti alla
/// prima richiesta (il costruttore delle sorgenti è sincrono e il segreto
/// no). Con un utente e senza password è [TransportAuthRequired], che lo
/// scaffale traduce in [SourceState.needsAuth] senza chiedere niente al
/// server; utente vuoto = ospite.
SmbTransport secretSmbTransport({
  required String host,
  required String share,
  required String user,
  required String domain,
  required bool seal,
  required SourceSecrets secrets,
  required String sourceId,
}) =>
    SmbTransport(() async {
      final password = await secrets.read(sourceId);
      if (password == null && user.isNotEmpty) throw const TransportAuthRequired();
      return PoolSmbSession.connect(
        host: host,
        share: share,
        user: user.isEmpty ? null : user,
        password: password,
        domain: domain.isEmpty ? null : domain,
        seal: seal,
        timeout: const Duration(seconds: 10),
      );
    });

class SmbSource implements StorageSource {
  SmbSource({
    required this.config,
    required this.transport,
    required this.shelf,
    required this.files,
  });

  @override
  final SourceConfig config;

  final StorageTransport transport;

  @override
  final PathShelf shelf;

  @override
  final PathFiles files;

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(download: true);

  /// Lo dice leggendo, con [SourceUnavailable].
  @override
  Future<SourceState> probe() async => SourceState.ready;

  @override
  void dispose() => transport.close();
}
