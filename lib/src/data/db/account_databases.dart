/// Un file SQLite per account (per uid) e uno per l'uso senza account: cambiare
/// account vuol dire cambiare file, mai fondere. Qui stanno solo nomi, nota
/// dello slot attivo e adozione del file di prima; chi apre il database e chi
/// ascolta l'accesso stanno altrove. Contratto: `handoff/.../FASE-9.md`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'database.dart';

/// Stato della nota `kagami-slot.json`: tre casi che non vanno confusi.
/// Assente = mai deciso (si migra); illeggibile = errore (si apre lo slot della
/// sessione senza migrare né riscrivere la nota); presente = [slot].
sealed class SlotNote {
  const SlotNote();
}

class SlotNoteAbsent extends SlotNote {
  const SlotNoteAbsent();
}

class SlotNoteUnreadable extends SlotNote {
  const SlotNoteUnreadable(this.error);
  final Object error;
}

class SlotNoteActive extends SlotNote {
  const SlotNoteActive(this.slot);
  final String slot;
}

/// Ciò che può cambiare lo slot: un evento di auth con l'uid della sessione
/// (`null` se non c'è) o un'uscita esplicita (`signOut`, `forget`).
sealed class SlotEvent {
  const SlotEvent();
}

class SessionChanged extends SlotEvent {
  const SessionChanged(this.uid);
  final String? uid;
}

class SignedOut extends SlotEvent {
  const SignedOut();
}

/// Lo slot che segue l'account voluto, non la sessione: una sessione persa
/// (`null`) non cambia niente, un uid va al suo slot, l'uscita esplicita a guest.
String nextSlot(String current, SlotEvent event) => switch (event) {
      SessionChanged(uid: null) => current,
      SessionChanged(:final uid?) => AccountDatabases.slotOf(uid),
      SignedOut() => AccountDatabases.guest,
    };

class AccountDatabases {
  AccountDatabases(this.documents);

  /// `<documents>`: dove drift_flutter tiene `kagami.sqlite` e dove stanno
  /// anche i file nuovi.
  final Directory documents;

  static const guest = 'guest';
  static const _legacyName = 'kagami.sqlite';
  static const _noteName = 'kagami-slot.json';
  static final _uid = RegExp(r'^[A-Za-z0-9-]{1,64}$');

  /// Lo slot di un account. L'uid viene dal backend, ma finisce in un percorso.
  static String slotOf(String uid) {
    if (!_uid.hasMatch(uid)) throw ArgumentError.value(uid, 'uid');
    return 'u-$uid';
  }

  String slotFor(String uid) => slotOf(uid);

  static bool _validSlot(String slot) =>
      slot == guest || (slot.startsWith('u-') && _uid.hasMatch(slot.substring(2)));

  File fileFor(String slot) {
    if (!_validSlot(slot)) throw ArgumentError.value(slot, 'slot');
    return File(p.join(documents.path, 'kagami-$slot.sqlite'));
  }

  File get _legacy => File(p.join(documents.path, _legacyName));
  File get _note => File(p.join(documents.path, _noteName));

  Future<SlotNote> readNote() async {
    final note = _note;
    try {
      if (!await note.exists()) return const SlotNoteAbsent();
      final json = jsonDecode(await note.readAsString());
      final slot = json is Map ? json['slot'] : null;
      if (slot is String && _validSlot(slot)) return SlotNoteActive(slot);
      return SlotNoteUnreadable(FormatException('slot non valido: $slot'));
    } catch (e) {
      return SlotNoteUnreadable(e);
    }
  }

  /// Scrive la nota su un file temporaneo e la rinomina: un'interruzione lascia
  /// la nota di prima, mai una a metà.
  Future<void> writeNote(String slot) async {
    if (!_validSlot(slot)) throw ArgumentError.value(slot, 'slot');
    final tmp = File('${_note.path}.tmp');
    await tmp.writeAsString(jsonEncode({'slot': slot}), flush: true);
    await tmp.rename(_note.path);
  }

  /// Fa adottare a [slot] il file di prima. Una volta sola e senza scrivere
  /// sopra niente: se la nota non è assente o il vecchio file non c'è, non fa
  /// nulla. Ripetuta dopo un'interruzione a qualunque punto arriva allo stesso
  /// stato. Restituisce se ha adottato. Con [support] anche le copie
  /// automatiche di prima (`<support>/backup/*.json.gz`) passano nello slot.
  Future<bool> adoptLegacy(String slot, {Directory? support}) async {
    final target = fileFor(slot);
    if (await readNote() is! SlotNoteAbsent) return false;
    final legacy = _legacy;
    if (!await legacy.exists()) return false;

    if (!await target.exists()) {
      // VACUUM INTO e non un rename: aprendo il file SQLite riapplica un
      // journal o un WAL rimasti, che accanto a un file spostato si perderebbero.
      final tmp = File('${target.path}.tmp');
      if (await tmp.exists()) await tmp.delete();
      final db = KagamiDatabase.forTesting(NativeDatabase(legacy));
      try {
        await db.customStatement(
          "VACUUM INTO '${tmp.path.replaceAll("'", "''")}'",
        );
      } finally {
        await db.close();
      }
      await tmp.rename(target.path);
    }

    // Prima della nota: dopo un'interruzione la nota assente rifà il giro, e
    // spostare solo i nomi che mancano lo rende idempotente.
    if (support != null) await _adoptBackups(support, slot);
    await writeNote(slot);
    await legacy.rename('${legacy.path}.adopted');
    return true;
  }

  File get _claimed => File(p.join(documents.path, 'kagami-legacy-claimed.json'));

  /// Il passaggio da Firebase a Hestia: al primo avvio nessuno ha ancora una
  /// sessione sul backend nuovo, quindi il file di prima lo adotta `guest`, e
  /// il primo accesso apriva un file vuoto (e lo mandava su). Qui il primo
  /// account che entra dopo un'adozione prende una copia di `guest`, ma solo
  /// se il suo file non ha dati di lettura: non è una fusione, e i dati di un
  /// account non finiscono mai sopra quelli di un altro. Una volta sola per
  /// telefono (nota `kagami-legacy-claimed.json`); il file di `guest` resta.
  /// Va chiamata con il file di [slot] chiuso. Restituisce se ha copiato.
  Future<bool> claimLegacy(String slot) async {
    if (slot == guest || !_validSlot(slot)) return false;
    if (await _claimed.exists()) return false;
    if (!await File('${_legacy.path}.adopted').exists()) return false;
    final source = fileFor(guest);
    if (!await source.exists() || !await _hasReading(source)) return false;
    final target = fileFor(slot);
    if (await target.exists() && await _hasReading(target)) {
      // L'account ha già dati suoi: il file di prima non era suo.
      await _writeClaimed(slot, copied: false);
      return false;
    }
    final tmp = File('${target.path}.tmp');
    if (await tmp.exists()) await tmp.delete();
    final db = KagamiDatabase.forTesting(NativeDatabase(source));
    try {
      await db.customStatement("VACUUM INTO '${tmp.path.replaceAll("'", "''")}'");
    } finally {
      await db.close();
    }
    for (final suffix in const ['-journal', '-wal', '-shm']) {
      final side = File('${target.path}$suffix');
      if (await side.exists()) await side.delete();
    }
    await tmp.rename(target.path);
    await _writeClaimed(slot, copied: true);
    return true;
  }

  Future<void> _writeClaimed(String slot, {required bool copied}) =>
      _claimed.writeAsString(jsonEncode({'slot': slot, 'copied': copied}), flush: true);

  /// Se il file ha dati di lettura (serie, letti, posizioni, raccolte): le sole
  /// impostazioni non contano, le scrive anche la prima sincronizzazione.
  static Future<bool> _hasReading(File file) async {
    final db = KagamiDatabase.forTesting(NativeDatabase(file));
    try {
      for (final table in const [
        'series_states', 'chapter_reads', 'progresses', 'collection_rows', 'bookmarks',
      ]) {
        final rows = await db.customSelect('SELECT 1 FROM $table LIMIT 1').get();
        if (rows.isNotEmpty) return true;
      }
      return false;
    } finally {
      await db.close();
    }
  }

  Future<void> _adoptBackups(Directory support, String slot) async {
    final from = Directory(p.join(support.path, 'backup'));
    if (!await from.exists()) return;
    final to = Directory(p.join(from.path, slot));
    final copies = await from
        .list()
        .where((e) => e is File && e.path.endsWith('.json.gz'))
        .cast<File>()
        .toList();
    for (final copy in copies) {
      final target = File(p.join(to.path, p.basename(copy.path)));
      if (await target.exists()) continue;
      await to.create(recursive: true);
      await copy.rename(target.path);
    }
  }

  /// Lo slot con cui parte l'app. Nota presente: quello. Assente: lo slot della
  /// sessione ([uid], `null` = nessuna) adotta il file di prima e la nota lo
  /// fissa. Illeggibile: lo slot della sessione, senza migrare né riscrivere la
  /// nota, e [onUnreadable] lo riferisce. Un [uid] non valido vale «nessuna sessione».
  Future<String> resolveActive({
    String? uid,
    Directory? support,
    void Function(Object error)? onUnreadable,
  }) async {
    String bySession() {
      try {
        return uid == null ? guest : slotOf(uid);
      } on ArgumentError {
        return guest;
      }
    }

    switch (await readNote()) {
      case SlotNoteActive(:final slot):
        return slot;
      case SlotNoteUnreadable(:final error):
        onUnreadable?.call(error);
        return bySession();
      case SlotNoteAbsent():
        final slot = bySession();
        if (!await adoptLegacy(slot, support: support)) await writeNote(slot);
        return slot;
    }
  }
}

/// Se la sessione con [uid] (`null` = nessuna) è quella dello [slot]: solo
/// allora si legge o si scrive il backend con i dati di quel file. `guest` non
/// è di nessuna sessione, e un uid non valido non è di nessuno slot.
bool sessionOwnsSlot(String slot, String? uid) {
  if (uid == null) return false;
  try {
    return slot == AccountDatabases.slotOf(uid);
  } on ArgumentError {
    return false;
  }
}

/// Lo slot attivo, ascoltabile da chi monta il contenitore dell'app. Segue gli
/// eventi di auth ([follow]) e l'uscita esplicita ([leave]) con [nextSlot].
class AccountSlots extends ValueNotifier<String> {
  AccountSlots(this.databases, super.initial);

  final AccountDatabases databases;

  /// I cambi in fila: due eventi vicini non scrivono la nota fuori ordine.
  Future<void> _queue = Future.value();

  /// La nota si scrive prima di notificare: un'interruzione a metà lascia lo
  /// slot di prima, mai uno che il file non conferma.
  Future<void> switchTo(String slot) async {
    if (slot == value) return;
    // Il file di [slot] qui è ancora chiuso: il contenitore che lo apre nasce
    // solo dopo la notifica. Una copia fallita non deve impedire l'accesso.
    try {
      await databases.claimLegacy(slot);
    } on Object catch (error) {
      debugPrint('claimLegacy: $error');
    }
    await databases.writeNote(slot);
    value = slot;
  }

  Future<void> _apply(SlotEvent event) {
    final next = _queue.then((_) {
      final String slot;
      try {
        slot = nextSlot(value, event);
      } on ArgumentError {
        // Un uid che non può stare in un nome di file non è di nessuno slot.
        return null;
      }
      return switchTo(slot);
    });
    _queue = next.catchError((Object _) {});
    return next;
  }

  /// Applica [nextSlot] a ogni uid della sessione (`null` = sessione persa,
  /// che non cambia slot). Una nota che non si scrive lascia lo slot di prima,
  /// e [onError] lo riferisce.
  StreamSubscription<String?> follow(
    Stream<String?> uids, {
    void Function(Object error)? onError,
  }) =>
      uids.listen((uid) {
        _apply(SessionChanged(uid)).catchError((Object error) => onError?.call(error));
      });

  /// Quando i cambi già chiesti sono applicati.
  @visibleForTesting
  Future<void> get idle => _queue;

  /// L'uscita voluta (`signOut`, `forget`): si torna ai dati dell'uso senza
  /// account.
  Future<void> leave() => _apply(const SignedOut());
}
