/// Toglie dalla cartella della libreria del telefono i dati personali che
/// Kagami vi aveva messo (D5): le copie automatiche e lo stato storico.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../format/malf.dart';
import 'backup.dart';
import 'db/account_databases.dart';
import 'user_repository.dart';

/// Una volta per cartella (segno `moved.reading:<radice>`): le copie di
/// `reading/backup/` vanno in `<support>/backup/<slot>/` e, se già importati,
/// `state.json` e `collections.json` in `<support>/legacy/`.
///
/// Si copia, si confronta la dimensione e solo allora si cancella
/// l'originale. Una copia fallita lascia l'originale e non mette il segno, così
/// si riprova all'avvio dopo. `reading/downloads.json` non si tocca. Va chiamata
/// solo con la cartella del telefono: da una sorgente altrui `reading/` non si
/// legge mai.
Future<bool> moveReadingOutOfLibrary({
  required UserRepository repository,
  required String root,
  required String support,
  String slot = AccountDatabases.guest,
}) async {
  final marker = 'moved.reading:$root';
  if (await repository.readSetting(marker) != null) return false;

  var complete = true;
  final reading = p.join(root, readingDirectory);

  final backups = Directory(p.join(reading, 'backup'));
  if (await backups.exists()) {
    final target = BackupService.backupDirectory(support, slot);
    final originals = await backups
        .list()
        .where((e) => e is File && e.path.endsWith('.json.gz'))
        .cast<File>()
        .toList();
    for (final original in originals) {
      complete &= await _move(original, File(p.join(target.path, p.basename(original.path))));
    }
    try {
      await backups.delete(); // solo se vuota
    } on FileSystemException {
      // Resta ciò che non è una copia: non è nostro da togliere.
    }
    for (final old in (await BackupService.listIn(target)).skip(keptBackups)) {
      await old.delete();
    }
  }

  final imported = await repository.readSetting('imported.reading:$root') != null;
  for (final name in const ['state.json', 'collections.json']) {
    final original = File(p.join(reading, name));
    if (!await original.exists()) continue;
    // Non ancora importato: resta dov'è e senza segno, o un'importazione
    // riuscita più tardi lo lascerebbe nella libreria per sempre.
    complete &= imported && await _move(original, File(p.join(support, 'legacy', name)));
  }

  if (!complete) return false;
  await repository.writeSetting(marker, DateTime.now().toUtc().toIso8601String());
  return true;
}

Future<bool> _move(File original, File destination) async {
  try {
    await destination.parent.create(recursive: true);
    final copy = await original.copy(destination.path);
    if (await copy.length() != await original.length()) return false;
    await copy.setLastModified(await original.lastModified());
    await original.delete();
    return true;
  } on FileSystemException {
    return false;
  }
}
