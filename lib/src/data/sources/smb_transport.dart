/// Una libreria MALF su una condivisione SMB (un NAS di casa, un computer),
/// in sola lettura, con `dart_smb2`. Sta nell'app e non nel pacchetto
/// dell'archiviatore: il pacchetto nativo non si compila con `dart compile
/// exe`, e il server non lo può avere (`docs/libreria.md`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_smb2/dart_smb2.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:kagami_archive/remote.dart' show isPrivateAddress;
import 'package:kagami_archive/transport.dart';

/// Un file o una cartella come li dà la sessione.
class SmbItem {
  const SmbItem({required this.name, required this.folder, this.size, this.modified});

  final String name;
  final bool folder;
  final int? size;
  final DateTime? modified;
}

/// La cucitura sopra `dart_smb2`: i test mettono una sessione finta, perché
/// la CI non ha un Samba. Ogni metodo deve abbandonare davvero il lavoro
/// quando [cancel] scatta (un'`Smb2Exception` `cancelled`). I percorsi sono
/// relativi alla condivisione, separati da `/`, `''` è la radice.
abstract interface class SmbSession {
  Future<List<SmbItem>> list(String path, Smb2CancelToken cancel);

  /// [Smb2Exception] `notFound` se non c'è.
  Future<SmbItem> stat(String path, Smb2CancelToken cancel);

  Future<Uint8List> read(String path, int offset, int length, Smb2CancelToken cancel);

  Future<void> close();
}

/// La sessione vera: un `Smb2Pool` con due lavoratori.
class PoolSmbSession implements SmbSession {
  PoolSmbSession._(this._pool);

  final Smb2Pool _pool;

  static Future<PoolSmbSession> connect({
    required String host,
    required String share,
    String? user,
    String? password,
    String? domain,
    required bool seal,
    required Duration timeout,
  }) async =>
      PoolSmbSession._(await Smb2Pool.connect(
        host: host,
        share: share,
        user: user,
        password: password,
        domain: domain,
        workers: 2,
        timeout: timeout,
        seal: seal,
      ));

  static SmbItem _item(String name, Smb2Stat stat) => SmbItem(
        name: name,
        folder: stat.isDirectory,
        size: stat.isDirectory ? null : stat.size,
        modified: stat.modified,
      );

  @override
  Future<List<SmbItem>> list(String path, Smb2CancelToken cancel) async => [
        for (final entry in await _pool.listDirectory(path, cancelToken: cancel))
          if (entry.name != '.' && entry.name != '..') _item(entry.name, entry.stat),
      ];

  @override
  Future<SmbItem> stat(String path, Smb2CancelToken cancel) async {
    final stat = await _pool.stat(path, cancelToken: cancel);
    return _item(path.isEmpty ? '' : path.split('/').last, stat);
  }

  @override
  Future<Uint8List> read(String path, int offset, int length, Smb2CancelToken cancel) =>
      _pool.readFileRange(path, offset: offset, length: length, cancelToken: cancel);

  @override
  Future<void> close() => _pool.disconnect();
}

/// L'host di una sorgente SMB, controllato prima di costruire il trasporto.
/// Senza [seal] (SMB 3 cifrato) la password e i dati viaggiano in chiaro
/// sulla rete: ammesso solo verso la rete di casa, come `http` per il WebDAV.
///
/// [FormatException] con il motivo, da mostrare all'utente.
String smbHost(String text, {required bool seal}) {
  final host = text.trim().toLowerCase();
  if (host.isEmpty || host.contains(RegExp(r'[\s/\\@?#]')) || host.contains('://')) {
    throw const FormatException('Serve il nome o l’indirizzo del computer, senza smb://');
  }
  if (host.contains(':') && InternetAddress.tryParse(host) == null) {
    throw const FormatException('Si usa solo la porta 445: niente «:porta»');
  }
  if (!seal && !isPrivateAddress(Uri(scheme: 'smb', host: host))) {
    throw const FormatException('In chiaro solo verso la rete di casa: serve la cifratura (SMB 3)');
  }
  return host;
}

/// Il nome di una condivisione: niente separatori.
String smbShare(String text) {
  final share = text.trim();
  if (share.isEmpty || share.contains(RegExp(r'[/\\]'))) {
    throw const FormatException('Serve il nome della condivisione, senza «/»');
  }
  return share;
}

typedef SmbConnector = Future<SmbSession> Function();

class SmbTransport implements StorageTransport {
  /// [connect] apre la sessione alla prima richiesta (e di nuovo se la
  /// connessione è caduta).
  SmbTransport(
    this._connect, {
    @visibleForTesting this.limit = const Duration(seconds: 20),
    @visibleForTesting this.maxText = 8 * 1024 * 1024,
  });

  final SmbConnector _connect;

  /// Il tempo massimo di ogni operazione (e di ogni blocco di un download).
  final Duration limit;

  /// Quanti byte al massimo si leggono come testo (un indice).
  final int maxText;

  static const int _block = 1024 * 1024;

  Future<SmbSession>? _session;
  bool _closed = false;

  Future<SmbSession> _open() {
    if (_closed) throw const TransportOffline('Sorgente chiusa');
    return _session ??= () async {
      final connecting = _connect();
      try {
        // Il pool ha il suo tempo massimo, ma impiega il doppio: qui si
        // smette di aspettare, e una sessione che arriva dopo si chiude.
        return await connecting.timeout(limit * 2, onTimeout: () {
          unawaited(connecting.then((late) => late.close(), onError: (Object _) {}));
          throw const TransportOffline();
        });
      } on Object catch (error) {
        _session = null;
        throw _translate(error, connecting: true);
      }
    }();
  }

  /// Un'operazione con il suo tempo massimo: allo scadere il token annulla
  /// davvero la richiesta, che altrimenti terrebbe il lavoratore bloccato.
  Future<T> _run<T>(Future<T> Function(SmbSession session, Smb2CancelToken cancel) operation) async {
    final session = await _open();
    final cancel = Smb2CancelToken();
    final timer = Timer(limit, () => cancel.cancel('tempo scaduto'));
    try {
      return await operation(session, cancel);
    } on Object catch (error) {
      throw _translate(error);
    } finally {
      timer.cancel();
    }
  }

  static Object _translate(Object error, {bool connecting = false}) {
    if (error is TransportException) return error;
    if (error is Smb2Exception) {
      return switch (error.type) {
        Smb2ErrorType.auth || Smb2ErrorType.accessDenied => const TransportAuthRequired(),
        Smb2ErrorType.notFound => const TransportNotFound(),
        Smb2ErrorType.connection || Smb2ErrorType.timeout || Smb2ErrorType.cancelled =>
          const TransportOffline(),
        Smb2ErrorType.notSupported when connecting =>
          const TransportException('Il server non parla una versione di SMB che Kagami legge: serve SMB 2.1 o più recente'),
        _ => TransportException(error.message),
      };
    }
    return error;
  }

  static String _join(List<String> segments) => segments.join('/');

  @override
  Future<List<RemoteEntry>> list(String path) async {
    final segments = transportSegments(path);
    final items = await _run((session, cancel) => session.list(_join(segments), cancel));
    return [
      for (final item in items)
        RemoteEntry(
          path: _join([...segments, item.name]),
          name: item.name,
          folder: item.folder,
          size: item.size,
          modified: item.modified,
        ),
    ];
  }

  @override
  Future<RemoteEntry?> stat(String path) async {
    final segments = transportSegments(path);
    final SmbItem item;
    try {
      item = await _run((session, cancel) => session.stat(_join(segments), cancel));
    } on TransportNotFound {
      return null;
    }
    return RemoteEntry(
      path: _join(segments),
      name: item.name,
      folder: item.folder,
      size: item.size,
      modified: item.modified,
    );
  }

  @override
  Future<String> text(String path) async {
    final segments = transportSegments(path);
    final joined = _join(segments);
    final item = await _run((session, cancel) => session.stat(joined, cancel));
    final size = item.size ?? 0;
    if (item.folder) throw TransportException('$path è una cartella');
    if (size > maxText) throw TransportException('Il file $path è troppo grande per essere un indice');
    if (size == 0) return '';
    final bytes = await _run((session, cancel) => session.read(joined, 0, size, cancel));
    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw TransportException('Il file $path non è testo UTF-8');
    }
  }

  @override
  Future<void> download(String path, File target, {int resumeFrom = 0}) async {
    final joined = _join(transportSegments(path));
    if (resumeFrom < 0 ||
        (resumeFrom > 0 && (!await target.exists() || await target.length() < resumeFrom))) {
      throw ArgumentError.value(resumeFrom, 'resumeFrom', 'oltre ciò che c’è in target');
    }
    final item = await _run((session, cancel) => session.stat(joined, cancel));
    if (item.folder) throw TransportException('$path è una cartella');
    final size = item.size ?? 0;
    // Il file sul server è più corto di ciò che c'è già: è cambiato, si riparte.
    var offset = resumeFrom > size ? 0 : resumeFrom;
    final file = await target.open(mode: offset > 0 ? FileMode.append : FileMode.write);
    try {
      if (offset > 0) {
        await file.truncate(offset);
        await file.setPosition(offset);
      }
      // Blocco per blocco e scritto subito: se la rete cade, da lì si riprende.
      while (offset < size) {
        final length = size - offset < _block ? size - offset : _block;
        final bytes = await _run((session, cancel) => session.read(joined, offset, length, cancel));
        if (bytes.isEmpty) throw const TransportException('La condivisione ha chiuso il file a metà');
        await file.writeFrom(bytes);
        offset += bytes.length;
      }
    } finally {
      await file.close();
    }
  }

  @override
  void close() {
    _closed = true;
    final session = _session;
    _session = null;
    session?.then((open) => open.close(), onError: (Object _) {});
  }
}
