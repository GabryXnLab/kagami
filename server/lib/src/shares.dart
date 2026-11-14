/// Le condivisioni della libreria che l'app affida al server perché le
/// ritiri alla scadenza (`shares`, `PUT /v2/me/shares` in docs/server-api.md).
library;

import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/stores.dart' show readJsonFile;

import 'config.dart' show writeSecret;

/// Un permesso di Drive su una cartella, da ritirare da [expiresAt] in poi.
class HeldShare {
  const HeldShare({required this.folderId, required this.permissionId, required this.expiresAt});

  static HeldShare? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final (folderId, permissionId) = (json['folderId'], json['permissionId']);
    final expiresAt = DateTime.tryParse('${json['expiresAt']}')?.toUtc();
    if (folderId is! String || permissionId is! String || expiresAt == null) return null;
    return HeldShare(folderId: folderId, permissionId: permissionId, expiresAt: expiresAt);
  }

  final String folderId;
  final String permissionId;
  final DateTime expiresAt;

  bool sameAs(HeldShare other) => folderId == other.folderId && permissionId == other.permissionId;

  @override
  bool operator ==(Object other) => other is HeldShare && sameAs(other) && expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(folderId, permissionId, expiresAt);

  Map<String, Object?> toJson() =>
      {'folderId': folderId, 'permissionId': permissionId, 'expiresAt': expiresAt.toUtc().toIso8601String()};
}

/// L'elenco di un utente, su `shares.json` del suo spazio.
class ShareKeeper {
  ShareKeeper(this.file);

  final File file;

  /// Sostituzione e passata una alla volta: la passata toglie solo ciò che ha
  /// ritirato, dall'elenco com'è quando finisce.
  Future<void> _last = Future.value();

  Future<T> _serial<T>(Future<T> Function() body) {
    final result = _last.then((_) => body());
    _last = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<List<HeldShare>> list() async => [
        for (final row in (await readJsonFile(file))?['shares'] as List? ?? const [])
          ?HeldShare.fromJson(row),
      ];

  Future<void> replace(List<HeldShare> shares) => _serial(() => _save(shares));

  Future<void> _save(List<HeldShare> shares) =>
      writeSecret(file, jsonEncode({'shares': [for (final share in shares) share.toJson()]}));

  /// Ritira con [unshare] le voci scadute a [now]; esce solo quella per cui
  /// [unshare] è tornato normale (404 compreso, lo decide chi la passa). Un
  /// errore lascia la voce, e la passata va avanti con le altre. Dà gli errori.
  Future<List<String>> sweep(DateTime now, Future<void> Function(String folderId, String permissionId) unshare) async {
    final due = [for (final share in await list()) if (!now.isBefore(share.expiresAt)) share];
    if (due.isEmpty) return const [];
    final done = <HeldShare>[];
    final problems = <String>[];
    for (final share in due) {
      try {
        await unshare(share.folderId, share.permissionId);
        done.add(share);
      } on Object catch (error) {
        problems.add('${share.folderId}/${share.permissionId}: $error');
      }
    }
    if (done.isNotEmpty) {
      await _serial(() async => _save([for (final share in await list()) if (!done.contains(share)) share]));
    }
    return problems;
  }
}
