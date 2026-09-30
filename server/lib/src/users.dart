/// Chi può usare il server, e lo spazio di ognuno.
///
/// L'elenco è di indirizzi Google: il proprietario (quello del comando di
/// avvio) più chi lui aggiunge dall'app. Ogni utente ha la sua cartella in
/// `users/`, con il suo permesso di Drive, la sua coda e le serie che
/// segue, e un suo giro: il Drive di uno non vede mai i lavori di un altro.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/stores.dart';

import 'config.dart';
import 'google.dart';
import 'worker.dart';

class Member {
  const Member({required this.email, required this.addedAt, this.owner = false});

  factory Member.fromJson(Map<String, Object?> json) => Member(
        email: json['email'] as String,
        addedAt: DateTime.tryParse('${json['addedAt']}') ?? DateTime.now(),
      );

  final String email;
  final DateTime addedAt;
  final bool owner;

  Map<String, Object?> toJson() => {'email': email, 'addedAt': addedAt.toIso8601String()};
}

/// Ciò che l'API usa di un utente.
abstract interface class UserSpace {
  ArchiveFiles get files;
  JobControl get jobs;
  DriveSetup get drive;

  Future<void> close();

  /// Chiude e cancella tutto: permesso, coda, serie seguite.
  Future<void> destroy();
}

/// Un indirizzo scritto dal proprietario, ripulito; `null` se non lo è.
String? normalizeEmail(String value) {
  final email = value.trim().toLowerCase();
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ? email : null;
}

class Accounts {
  Accounts(this.file, {required this.owner, required this.open});

  final File file;

  /// L'indirizzo del proprietario: sempre ammesso, non si toglie.
  final String owner;

  /// Apre lo spazio di un utente, col suo giro acceso.
  final Future<UserSpace> Function(String email) open;

  List<Member>? _members;
  final Map<String, Future<UserSpace>> _spaces = {};

  /// Le modifiche all'elenco una alla volta: le richieste dell'API arrivano
  /// insieme.
  Future<void> _last = Future.value();

  Future<T> _serial<T>(Future<T> Function() body) {
    final result = _last.then((_) => body());
    _last = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<List<Member>> list() async {
    final stored = _members ??= [
      for (final row in ((await readJsonFile(file))?['users'] as List? ?? const []).whereType<Map<String, Object?>>())
        Member.fromJson(row),
    ];
    final owners = stored.where((member) => member.email == owner);
    return [
      Member(email: owner, addedAt: owners.firstOrNull?.addedAt ?? DateTime.now(), owner: true),
      for (final member in stored)
        if (member.email != owner) member,
    ];
  }

  Future<Member?> find(String email) async => (await list()).where((member) => member.email == email).firstOrNull;

  Future<Member> add(String email) => _serial(() async {
        final known = await find(email);
        if (known != null) return known;
        final member = Member(email: email, addedAt: DateTime.now());
        await _save([...await list(), member]);
        return member;
      });

  /// Toglie l'utente e cancella il suo spazio. Dice se c'era.
  Future<bool> remove(String email) => _serial(() async {
        if (email == owner) throw ArgumentError('Il proprietario non si toglie.');
        final members = await list();
        if (!members.any((member) => member.email == email)) return false;
        await _save([for (final member in members) if (member.email != email) member]);
        final space = _spaces.remove(email);
        if (space != null) await (await space).destroy();
        return true;
      });

  Future<void> _save(List<Member> members) async {
    _members = members;
    await writeSecret(
      file,
      const JsonEncoder.withIndent('  ').convert({'users': [for (final member in members) member.toJson()]}),
    );
  }

  /// Lo spazio di un utente ammesso, aperto al primo bisogno.
  Future<UserSpace> space(String email) => _spaces[email] ??= open(email);

  /// Accende i giri di tutti: le code lasciate a metà ripartono da sole.
  Future<void> openAll() async {
    for (final member in await list()) {
      await space(member.email);
    }
  }

  Future<void> close() async {
    for (final space in _spaces.values) {
      await (await space).close();
    }
    _spaces.clear();
  }
}
