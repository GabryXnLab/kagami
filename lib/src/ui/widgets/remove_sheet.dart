/// Il foglio che toglie delle serie dalla libreria, anche da Drive.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kagami_archive/remote.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/drive.dart';
import '../../data/drive_library.dart';
import '../../data/series_removal.dart';
import '../../format/malf.dart';
import '../../l10n.dart';
import '../../providers.dart';
import '../theme.dart';
import 'cleanup_sheet.dart' show driveWriter;
import 'kit.dart';

/// Chiede conferma e toglie [entries]. `true` se le ha tolte: chi sta
/// guardando una di quelle serie deve uscire.
Future<bool> confirmRemoveSeries(
  BuildContext context,
  WidgetRef ref,
  List<SeriesEntry> entries,
) async {
  if (entries.isEmpty) return false;
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final onDrive = entries.any(
    (entry) => ref.read(seriesHoldersProvider(entry.key)).any((shelf) => shelf is DriveRepository),
  );
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
                    l10n.removeSeriesDrive,
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
  if (sure != true) return false;
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
  await ref.read(removedSeriesProvider.notifier).hide(removed);
  ref.read(selectionProvider.notifier).clear();
  messenger.showSnackBar(SnackBar(content: Text(l10n.removeSeriesDone(removed.length))));
  return removed.length == entries.length;
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
