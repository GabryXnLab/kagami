/// La sincronizzazione della cartella del telefono con quella di Drive:
/// direzione, cancellazioni, ora del giro programmato, giro a mano.
///
/// È ciò che prima si impostava in FolderSync. Le regole stanno in
/// `data/folder_sync.dart`; qui c'è quello che serve a sceglierle sapendo
/// cosa fanno.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/drive.dart';
import '../data/folder_sync.dart';
import '../providers.dart';
import 'drive_ui.dart';
import 'theme.dart';
import 'widgets/kit.dart';

/// Come la si riassume in una riga, fra le impostazioni.
String folderSyncSummary(SyncSettings settings) {
  final direction = settings.direction;
  if (direction == null) return 'Spenta';
  final what = switch (direction) {
    SyncDirection.download => 'Da Drive al telefono',
    SyncDirection.upload => 'Dal telefono a Drive',
    SyncDirection.both => 'In entrambe le direzioni',
  };
  final minutes = settings.scheduleMinutes;
  return minutes == null ? '$what, a mano' : '$what, ogni giorno alle ${clockOf(minutes)}';
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
    final settings = ref.watch(folderSyncSettingsProvider).value;
    final root = ref.watch(libraryRootProvider);
    final folder = ref.watch(driveFolderProvider).value;
    final notifier = ref.read(folderSyncSettingsProvider.notifier);
    if (settings == null) {
      return Scaffold(appBar: AppBar(title: const Text('Sincronizzazione')));
    }
    final direction = settings.direction;
    final muted = context.tokens.muted;

    return Scaffold(
      appBar: AppBar(title: const Text('Sincronizzazione')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            'Tiene uguali la cartella dei manga sul telefono e quella su '
            'Drive, senza FolderSync. Se lo usi ancora su questa cartella, '
            'spegnilo: due sincronizzazioni sugli stessi file si pestano i '
            'piedi.',
            style: KagamiType.body(13, height: 1.5, color: muted),
          ),
          const SizedBox(height: 22),
          const KSection('Cartelle'),
          KGroup(
            children: [
              KTile(
                icon: LucideIcons.smartphone,
                title: 'Sul telefono',
                subtitle: root ?? 'Nessuna cartella scelta',
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () => _chooseRoot(ref),
              ),
              KTile(
                icon: LucideIcons.cloud,
                title: 'Su Drive',
                subtitle: folder?.name ?? 'Drive non è collegato',
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () => connectDrive(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const KSection('Direzione'),
          KSegmented(
            options: const ['Spenta', 'Da Drive', 'Verso Drive', 'Entrambe'],
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
              null => 'Niente si muove da solo. La libreria di Drive si legge '
                  'lo stesso, e «Scarica» funziona come sempre.',
              SyncDirection.download => 'Quello che arriva su Drive scende '
                  'sul telefono. Dal telefono non sale niente.',
              SyncDirection.upload => 'Quello che c\'è sul telefono sale su '
                  'Drive — per esempio le copie dei dati in reading/backup. '
                  'Gli indici della libreria restano quelli del server.',
              SyncDirection.both => 'Quello che cambia da una parte arriva '
                  'dall\'altra; se è cambiato da tutt\'e due, vince il più '
                  'recente. Gli indici della libreria scendono e basta: sono '
                  'del server.',
            },
            style: KagamiType.body(13, height: 1.5, color: muted),
          ),
          if (direction != null) ...[
            const SizedBox(height: 14),
            KGroup(
              children: [
                KTile(
                  icon: LucideIcons.trash2,
                  title: 'Propaga le cancellazioni',
                  subtitle: switch (direction) {
                    SyncDirection.download => 'Toglie dal telefono ciò che '
                        'sparisce da Drive',
                    SyncDirection.upload => 'Sposta nel cestino di Drive ciò '
                        'che togli dal telefono',
                    SyncDirection.both => 'Da una parte all\'altra; da Drive '
                        'solo nel cestino',
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
                  ? '«Libera spazio» toglie i capitoli letti anche da Drive, '
                      'al giro seguente.'
                  : 'Un file tolto da una parte resta dall\'altra e non '
                      'torna indietro: «Libera spazio» libera il telefono e '
                      'lascia i capitoli su Drive.',
              style: KagamiType.body(12.5, height: 1.45, color: muted),
            ),
            const SizedBox(height: 26),
            const KSection('Ogni giorno'),
            KGroup(
              children: [
                KTile(
                  icon: LucideIcons.clock,
                  title: 'Sincronizzazione programmata',
                  subtitle: settings.scheduleMinutes == null
                      ? 'Solo a mano'
                      : 'Alle ${clockOf(settings.scheduleMinutes!)}, anche ad '
                          'app chiusa',
                  onTap: () => _toggleSchedule(ref, settings),
                  trailing: Switch(
                    value: settings.scheduleMinutes != null,
                    onChanged: (_) => _toggleSchedule(ref, settings),
                  ),
                ),
                if (settings.scheduleMinutes != null) ...[
                  KTile(
                    icon: LucideIcons.alarmClock,
                    title: 'Ora',
                    subtitle: clockOf(settings.scheduleMinutes!),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                    onTap: () => _chooseTime(context, ref, settings),
                  ),
                  KTile(
                    icon: LucideIcons.wifi,
                    title: 'Solo con Wi-Fi',
                    subtitle: settings.wifiOnly
                        ? 'Aspetta una rete che non si paga a consumo'
                        : 'Anche con i dati mobili',
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
                'Android decide il momento esatto: se all\'ora scelta manca '
                'la rete, il giro parte appena torna.',
                style: KagamiType.body(12.5, height: 1.45, color: muted),
              ),
            ],
            const SizedBox(height: 26),
            const KSection('Adesso'),
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
      helpText: 'Ora della sincronizzazione',
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
    return KGroup(
      children: [
        if (progress == null)
          KTile(
            icon: LucideIcons.refreshCw,
            title: 'Sincronizza adesso',
            subtitle: ready
                ? 'Si può continuare a leggere: le copie vanno avanti da sole'
                : 'Servono la cartella del telefono e quella di Drive',
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
                          SyncPhase.listing => 'Guardo cosa c\'è su Drive…',
                          SyncPhase.comparing => 'Confronto con il telefono…',
                          SyncPhase.transferring => progress.total == 0
                              ? 'Niente da copiare'
                              : 'File ${progress.done} di ${progress.total}',
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
                  tooltip: 'Interrompi',
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
            title: _when(last),
            subtitle: _outcome(last),
          )
        else if (progress == null)
          KTile(
            icon: LucideIcons.history,
            title: 'Mai sincronizzata',
            subtitle: 'Il primo giro su una cartella già piena è veloce: i '
                'file uguali si riconoscono dalla misura',
            tint: muted,
          ),
      ],
    );
  }

  static String _when(SyncReport report) {
    final local = report.at.toLocal();
    final how = report.scheduled ? 'programmata' : 'a mano';
    return 'Ultima, $how: ${local.day}/${local.month} alle '
        '${clockOf(local.hour * 60 + local.minute)}';
  }

  static String _outcome(SyncReport report) {
    final parts = [
      if (report.downloaded > 0) '${report.downloaded} scaricati',
      if (report.uploaded > 0) '${report.uploaded} caricati',
      if (report.deletedLocal > 0) '${report.deletedLocal} tolti dal telefono',
      if (report.trashed > 0) '${report.trashed} nel cestino di Drive',
      if (report.failed > 0) '${report.failed} non riusciti, si riprovano',
    ];
    final error = report.error;
    if (error != null) {
      return parts.isEmpty ? error : '$error. Fin lì: ${parts.join(', ')}';
    }
    return parts.isEmpty ? 'Era già tutto allineato' : parts.join(', ');
  }
}
