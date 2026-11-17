/// Il foglio che toglie delle serie dalla libreria, anche da Drive.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kagami_archive/remote.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/drive.dart';
import '../../data/drive_ownership.dart';
import '../../data/series_removal.dart';
import '../../format/malf.dart';
import '../../l10n.dart';
import '../../providers.dart';
import '../theme.dart';
import 'cleanup_sheet.dart' show driveWriter;
import 'kit.dart';

/// Le serie fra [entries] che l'app può togliere: quelle che hanno solo una
/// sorgente senza diritto di cancellare (una condivisione, un Drive la cui
/// cartella non è dell'account) non si propongono.
List<SeriesEntry> _removable(WidgetRef ref, List<SeriesEntry> entries, bool? driveOwned) => [
      for (final entry in entries)
        if (canRemoveSeries(ref.read(seriesHoldersProvider(entry.key)), driveOwned: driveOwned)) entry,
    ];

/// Se qualcuna di [entries] sta nel Drive dell'account.
bool _onOwnDrive(WidgetRef ref, List<SeriesEntry> entries) =>
    entries.any((entry) => ownDriveShelf(ref.read(seriesHoldersProvider(entry.key))) != null);

/// Chiede conferma e toglie [entries]. `true` se le ha tolte: chi sta
/// guardando una di quelle serie deve uscire.
Future<bool> confirmRemoveSeries(
  BuildContext context,
  WidgetRef ref,
  List<SeriesEntry> all,
) async {
  // Non letta vuol dire non propria finché Drive non risponde: su Drive
  // non si cancella (FASE-5b §5).
  final driveOwned = await _driveOwned(ref);
  if (!context.mounted) return false;
  final l10n = context.l10n;
  final entries = _removable(ref, all, driveOwned);
  if (entries.isEmpty) {
    // Si dice perché: la serie sta solo in un Drive non proprio.
    if (driveOwned != true && _onOwnDrive(ref, all)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.removeSeriesDriveNotOwned)));
    }
    return false;
  }
  final onDrive = _onOwnDrive(ref, entries);
  final sure = await showKagamiSheet<bool>(
    context,
    title: l10n.removeSeriesTitle(entries.length),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.removeSeriesBody(entries.length, entries.first.title),
            style: KagamiType.body(13.5, height: 1.5, color: context.tokens.muted),
          ),
          if (onDrive) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.cloud, size: 16, color: context.tokens.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    driveOwned == true ? l10n.removeSeriesDrive : l10n.removeSeriesDriveNotOwned,
                    style: KagamiType.body(13, height: 1.45, color: context.tokens.muted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          KButton(
            label: l10n.removeSeriesConfirm,
            icon: LucideIcons.trash2,
            tone: context.tokens.danger,
            expand: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ),
  );
  if (sure != true || !context.mounted) return false;
  return removeSeriesNow(context, ref, entries);
}

/// Toglie [entries] senza chiedere: lo fa chi ha già avuto il consenso per
/// un altro verso, come il collegamento di una scheda manuale a un sito.
/// [keepUrls] sono i link i cui lavori in coda non si toccano. Con
/// [announce] falso non dà la conferma finale.
Future<bool> removeSeriesNow(
  BuildContext context,
  WidgetRef ref,
  List<SeriesEntry> all, {
  Set<String> keepUrls = const {},
  bool announce = true,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final driveOwned = await _driveOwned(ref);
  final entries = _removable(ref, all, driveOwned);
  if (entries.isEmpty) return false;
  final onDrive = driveOwned == true && _onOwnDrive(ref, entries);
  final sync = ref.read(syncFilesProvider);
  // Un giro in corso potrebbe riportare proprio le cartelle che si tolgono.
  if (await sync.busy()) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.cleanupSyncBusy)));
    return false;
  }
  DriveClient? writer;
  if (onDrive) {
    writer = await driveWriter(ref, messenger, l10n);
    if (writer == null) return false;
  }
  final archive = ref.read(archiveFilesProvider);
  final folderId = ref.read(driveFolderProvider).value?.id;
  final link = ref.read(serverLinkProvider).value;
  final removed = <SeriesEntry>[];
  try {
    for (final entry in entries) {
      await removeSeries(
        entry,
        holders: ref.read(seriesHoldersProvider(entry.key)),
        archive: archive,
        sync: sync,
        drive: ref.read(driveFilesProvider),
        writer: writer,
        folderId: folderId,
        driveOwned: driveOwned,
        keepUrls: keepUrls,
      );
      removed.add(entry);
      if (link != null) await _leaveServer(ServerClient(link, ref.read(serverAccessProvider).idToken), entry.key);
    }
  } on DriveException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.removeSeriesFailed(error.message))));
  } finally {
    writer?.close();
  }
  if (removed.isEmpty) return false;
  // Prima Drive si rilegge, poi il catalogo, che segue le serie tolte.
  ref.read(driveRepositoryProvider)?.refresh();
  // Una serie che resta in un Drive non proprio resta anche in griglia.
  await ref.read(removedSeriesProvider.notifier).hide([
    for (final entry in removed)
      if (driveOwned == true || !_onOwnDrive(ref, [entry])) entry,
  ]);
  ref.read(selectionProvider.notifier).clear();
  if (announce) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.removeSeriesDone(removed.length))));
  }
  return removed.length == entries.length;
}

/// Se la cartella di Drive è dell'account; `null` se Drive non l'ha detto.
Future<bool?> _driveOwned(WidgetRef ref) async {
  try {
    return await ref.read(driveFolderOwnedProvider.future);
  } on Object {
    return null;
  }
}

/// Il server che segue la serie, o che ha in coda dei suoi capitoli, la
/// riscaricherebbe nella cartella appena tolta: smette di seguirla e i suoi
/// lavori escono dalla coda. Se non risponde, il suo controllo della
/// libreria non la trova più in `library.json`.
Future<void> _leaveServer(ServerClient client, String key) async {
  try {
    final queue = await client.queue();
    final urls = {
      for (final series in await client.ongoing())
        if (series.key == key && series.url.isNotEmpty) series.url,
      for (final outcome in queue.history)
        if (outcome.seriesKey == key) ?outcome.url,
    };
    for (final job in queue.jobs) {
      if (urls.contains(job.url)) await client.cancel(job.id);
    }
    if (urls.isNotEmpty) await client.forget(key).catchError((Object _) {});
  } on ServerException {
    // Non è una serie sua, o il server è spento.
  } on IOException {
    // Senza rete: lo stesso.
  } finally {
    client.close();
  }
}
