/// La sincronizzazione della cartella del telefono con quella di Drive:
/// direzione, cancellazioni, ora del giro programmato, giro a mano.
///
/// È ciò che prima si impostava in FolderSync. Le regole stanno in
/// `data/folder_sync.dart`; qui c'è quello che serve a sceglierle sapendo
/// cosa fanno.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/drive.dart';
import '../data/folder_sync.dart';
import '../l10n.dart';
import '../providers.dart';
import 'drive_ui.dart';
import 'theme.dart';
import 'widgets/kit.dart';

/// Come la si riassume in una riga, fra le impostazioni.
String folderSyncSummary(SyncSettings settings) {
  final l10n = currentL10n();
  final direction = settings.direction;
  if (direction == null) return l10n.syncSummaryOff;
  final what = switch (direction) {
    SyncDirection.download => l10n.syncSummaryDownload,
    SyncDirection.upload => l10n.syncSummaryUpload,
    SyncDirection.both => l10n.syncSummaryBoth,
  };
  final minutes = settings.scheduleMinutes;
  return minutes == null
      ? l10n.syncSummaryManual(what)
      : l10n.syncSummaryDaily(what, clockOf(minutes));
}

String clockOf(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  /// Senza un'ora scelta, il giro programmato parte di notte: il telefono è
  /// in carica e sul Wi-Fi, e nessuno sta leggendo.
  static const int _defaultMinutes = 3 * 60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(folderSyncSettingsProvider).value;
    final root = ref.watch(libraryRootProvider);
    final folder = ref.watch(driveFolderProvider).value;
    final notifier = ref.read(folderSyncSettingsProvider.notifier);
    if (settings == null) {
      return Scaffold(appBar: AppBar(title: Text(l10n.syncTitle)));
    }
    final direction = settings.direction;
    final muted = context.tokens.muted;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            l10n.syncIntro,
            style: KagamiType.body(13, height: 1.5, color: muted),
          ),
          const SizedBox(height: 22),
          KSection(l10n.syncFolders),
          KGroup(
            children: [
              KTile(
                icon: LucideIcons.smartphone,
                title: l10n.syncOnPhone,
                subtitle: root ?? l10n.syncNoFolderChosen,
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () => _chooseRoot(ref),
              ),
              KTile(
                icon: LucideIcons.cloud,
                title: l10n.syncOnDrive,
                subtitle: folder?.name ?? l10n.syncDriveNotConnected,
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () => connectDrive(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 26),
          KSection(l10n.syncDirection),
          KSegmented(
            options: [
              l10n.syncDirectionOff,
              l10n.syncDirectionFromDrive,
              l10n.syncDirectionToDrive,
              l10n.syncDirectionBoth,
            ],
            icons: const [
              LucideIcons.power,
              LucideIcons.cloudDownload,
              LucideIcons.cloudUpload,
              LucideIcons.arrowDownUp,
            ],
            index: direction == null ? 0 : direction.index + 1,
            onChanged: (index) => _setDirection(
              context,
              ref,
              index == 0 ? null : SyncDirection.values[index - 1],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            switch (direction) {
              null => l10n.syncDescOff,
              SyncDirection.download => l10n.syncDescDownload,
              SyncDirection.upload => l10n.syncDescUpload,
              SyncDirection.both => l10n.syncDescBoth,
            },
            style: KagamiType.body(13, height: 1.5, color: muted),
          ),
          if (direction != null) ...[
            const SizedBox(height: 14),
            KGroup(
              children: [
                KTile(
                  icon: LucideIcons.trash2,
                  title: l10n.syncDeletions,
                  subtitle: switch (direction) {
                    SyncDirection.download => l10n.syncDeletionsDownload,
                    SyncDirection.upload => l10n.syncDeletionsUpload,
                    SyncDirection.both => l10n.syncDeletionsBoth,
                  },
                  onTap: () => notifier.change(
                    (current) => current.copyWith(deletions: !current.deletions),
                  ),
                  trailing: Switch(
                    value: settings.deletions,
                    onChanged: (value) => notifier.change(
                      (current) => current.copyWith(deletions: value),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              settings.deletions
                  ? l10n.syncDeletionsOnNote
                  : l10n.syncDeletionsOffNote,
              style: KagamiType.body(12.5, height: 1.45, color: muted),
            ),
            const SizedBox(height: 26),
            KSection(l10n.syncDaily),
            KGroup(
              children: [
                KTile(
                  icon: LucideIcons.clock,
                  title: l10n.syncScheduled,
                  subtitle: settings.scheduleMinutes == null
                      ? l10n.syncManualOnly
                      : l10n.syncAtTime(clockOf(settings.scheduleMinutes!)),
                  onTap: () => _toggleSchedule(ref, settings),
                  trailing: Switch(
                    value: settings.scheduleMinutes != null,
                    onChanged: (_) => _toggleSchedule(ref, settings),
                  ),
                ),
                if (settings.scheduleMinutes != null) ...[
                  KTile(
                    icon: LucideIcons.alarmClock,
                    title: l10n.syncTime,
                    subtitle: clockOf(settings.scheduleMinutes!),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                    onTap: () => _chooseTime(context, ref, settings),
                  ),
                  KTile(
                    icon: LucideIcons.wifi,
                    title: l10n.syncWifiOnly,
                    subtitle: settings.wifiOnly
                        ? l10n.syncWifiOnlyOn
                        : l10n.syncWifiOnlyOff,
                    onTap: () => notifier.change(
                      (current) => current.copyWith(wifiOnly: !current.wifiOnly),
                    ),
                    trailing: Switch(
                      value: settings.wifiOnly,
                      onChanged: (value) => notifier.change(
                        (current) => current.copyWith(wifiOnly: value),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (settings.scheduleMinutes != null) ...[
              const SizedBox(height: 10),
              Text(
                l10n.syncScheduleNote,
                style: KagamiType.body(12.5, height: 1.45, color: muted),
              ),
            ],
            const SizedBox(height: 26),
            KSection(l10n.syncNow),
            _RunNow(ready: settings.ready),
          ],
        ],
      ),
    );
  }

  Future<void> _chooseRoot(WidgetRef ref) async {
    final location = await ref.read(libraryLocationProvider.future);
    if (!await location.hasAccess() && !await location.requestAccess()) return;
    final chosen = await location.choose();
    if (chosen == null) return;
    ref.read(libraryRootProvider.notifier).select(chosen);
    ref.invalidate(libraryCatalogProvider);
  }

  /// Caricare su Drive vuole il permesso di scrivere, che l'app non chiede
  /// finché non serve: lo si chiede qui, e senza non si cambia direzione.
  Future<void> _setDirection(
    BuildContext context,
    WidgetRef ref,
    SyncDirection? direction,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (direction?.uploads ?? false) {
      try {
        await ref.read(driveAuthProvider).authorize(write: true);
      } on DriveAuthRequired {
        return;
      } on DriveException catch (error) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
        return;
      }
    }
    await ref.read(folderSyncSettingsProvider.notifier).change(
          (current) => direction == null
              ? current.copyWith(clearDirection: true)
              : current.copyWith(direction: direction),
        );
  }

  Future<void> _toggleSchedule(WidgetRef ref, SyncSettings settings) =>
      ref.read(folderSyncSettingsProvider.notifier).change(
            (current) => current.scheduleMinutes == null
                ? current.copyWith(scheduleMinutes: _defaultMinutes)
                : current.copyWith(clearSchedule: true),
          );

  Future<void> _chooseTime(
    BuildContext context,
    WidgetRef ref,
    SyncSettings settings,
  ) async {
    final minutes = settings.scheduleMinutes ?? _defaultMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: context.l10n.syncTimePickerHelp,
    );
    if (picked == null) return;
    await ref.read(folderSyncSettingsProvider.notifier).change(
          (current) =>
              current.copyWith(scheduleMinutes: picked.hour * 60 + picked.minute),
        );
  }
}

/// Il giro a mano e l'esito dell'ultimo, programmato o no.
class _RunNow extends ConsumerWidget {
  const _RunNow({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(folderSyncRunProvider);
    final notifier = ref.read(folderSyncRunProvider.notifier);
    final progress = status.progress;
    final last = status.last;
    final muted = context.tokens.muted;
    final l10n = context.l10n;
    return KGroup(
      children: [
        if (progress == null)
          KTile(
            icon: LucideIcons.refreshCw,
            title: l10n.syncRunNow,
            subtitle: ready
                ? l10n.syncRunNowReady
                : l10n.syncRunNowNotReady,
            onTap: ready ? notifier.run : null,
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        switch (progress.phase) {
                          SyncPhase.listing => l10n.syncPhaseListing,
                          SyncPhase.comparing => l10n.syncPhaseComparing,
                          SyncPhase.transferring => progress.total == 0
                              ? l10n.syncPhaseNothing
                              : l10n.syncPhaseFiles(
                                  progress.done,
                                  progress.total,
                                ),
                        },
                        style: KagamiType.body(14, weight: 600),
                      ),
                      const SizedBox(height: 8),
                      progress.fraction == null
                          ? const LinearProgressIndicator(minHeight: 5)
                          : KProgress(value: progress.fraction!),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.syncStop,
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: notifier.cancel,
                ),
              ],
            ),
          ),
        if (status.message != null)
          KTile(
            icon: LucideIcons.info,
            title: status.message!,
          ),
        if (last != null)
          KTile(
            icon: last.error == null
                ? LucideIcons.circleCheck
                : LucideIcons.triangleAlert,
            tint: last.error == null ? null : context.tokens.danger,
            title: _when(l10n, last),
            subtitle: _outcome(l10n, last),
          )
        else if (progress == null)
          KTile(
            icon: LucideIcons.history,
            title: l10n.syncNever,
            subtitle: l10n.syncNeverNote,
            tint: muted,
          ),
      ],
    );
  }

  static String _when(AppLocalizations l10n, SyncReport report) {
    final local = report.at.toLocal();
    final date = DateFormat.Md(l10n.localeName).format(local);
    final time = clockOf(local.hour * 60 + local.minute);
    return report.scheduled
        ? l10n.syncLastScheduled(date, time)
        : l10n.syncLastManual(date, time);
  }

  static String _outcome(AppLocalizations l10n, SyncReport report) {
    final parts = [
      if (report.downloaded > 0) l10n.syncOutcomeDownloaded(report.downloaded),
      if (report.uploaded > 0) l10n.syncOutcomeUploaded(report.uploaded),
      if (report.deletedLocal > 0)
        l10n.syncOutcomeDeletedLocal(report.deletedLocal),
      if (report.trashed > 0) l10n.syncOutcomeTrashed(report.trashed),
      if (report.failed > 0) l10n.syncOutcomeFailed(report.failed),
    ];
    final error = report.error;
    if (error != null) {
      return parts.isEmpty
          ? error
          : l10n.syncOutcomeErrorSoFar(error, parts.join(', '));
    }
    return parts.isEmpty ? l10n.syncOutcomeAligned : parts.join(', ');
  }
}
