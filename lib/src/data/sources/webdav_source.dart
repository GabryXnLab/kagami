/// Una libreria MALF su WebDAV (un NAS, Nextcloud), in sola lettura.
library;

import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/transport.dart';
import 'package:kagami_archive/webdav.dart';

import '../../format/malf.dart';
import 'path_shelf.dart';
import 'source.dart';

/// Un trasporto che legge la password alla prima richiesta: il costruttore
/// delle sorgenti è sincrono e il segreto no. Una password mancante è
/// [TransportAuthRequired], che lo scaffale traduce in
/// [SourceState.needsAuth] senza chiedere niente al server.
class SecretWebDavTransport implements StorageTransport {
  SecretWebDavTransport({
    required this.address,
    required this.user,
    required this.secrets,
    required this.sourceId,
  });

  final Uri address;
  final String user;
  final SourceSecrets secrets;
  final String sourceId;

  Future<StorageTransport>? _inner;
  bool _closed = false;

  Future<StorageTransport> _open() => _inner ??= () async {
        final password = await secrets.read(sourceId);
        if (password == null && user.isNotEmpty) {
          _inner = null;
          throw const TransportAuthRequired();
        }
        final transport = WebDavTransport(address, user: user, password: password);
        if (_closed) transport.close();
        return transport;
      }();

  @override
  Future<List<RemoteEntry>> list(String path) async => (await _open()).list(path);

  @override
  Future<RemoteEntry?> stat(String path) async => (await _open()).stat(path);

  @override
  Future<String> text(String path) async => (await _open()).text(path);

  @override
  Future<void> download(String path, File target, {int resumeFrom = 0}) async =>
      (await _open()).download(path, target, resumeFrom: resumeFrom);

  @override
  void close() {
    _closed = true;
    _inner?.then((transport) => transport.close(), onError: (_) {});
  }
}

class WebDavSource implements StorageSource {
  WebDavSource({
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

/// Esito di «Prova connessione».
sealed class WebDavProbe {
  const WebDavProbe();
}

class WebDavProbeOk extends WebDavProbe {
  const WebDavProbeOk(this.series);
  final int series;
}

class WebDavProbeAuth extends WebDavProbe {
  const WebDavProbeAuth();
}

class WebDavProbeUnreachable extends WebDavProbe {
  const WebDavProbeUnreachable();
}

class WebDavProbeNoLibrary extends WebDavProbe {
  const WebDavProbeNoLibrary();
}

/// Cerca `library.json` sotto [root]; una cartella che c'è senza indice non
/// è una libreria, e per la prova è un esito a sé.
Future<WebDavProbe> probeWebDav(StorageTransport transport, String root) async {
  final segments = root.split('/').where((s) => s.isNotEmpty);
  final path = [...segments, libraryIndexFile].join('/');
  try {
    final entry = await transport.stat(path);
    if (entry == null || entry.folder) return const WebDavProbeNoLibrary();
    final library = LibraryIndex.fromJson(
      jsonDecode(await transport.text(path)) as Map<String, Object?>,
    );
    return WebDavProbeOk(library.series.length);
  } on TransportAuthRequired {
    return const WebDavProbeAuth();
  } on TransportNotFound {
    return const WebDavProbeNoLibrary();
  } on FormatException {
    return const WebDavProbeNoLibrary();
  } on TypeError {
    return const WebDavProbeNoLibrary();
  } on TransportException {
    return const WebDavProbeUnreachable();
  } on SocketException {
    return const WebDavProbeUnreachable();
  }
}
