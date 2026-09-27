/// Impostazioni: aspetto, libreria, lettura e dati.
///
/// La sezione che conta è l'ultima. Da quando lo stato utente vive nel
/// database dell'app, portarsi via i propri dati non è una funzione in più: è
/// il modo in cui sopravvivono a una reinstallazione.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/backup.dart';
import '../data/cloud.dart';
import '../data/folder_sync.dart';
import '../data/page_decoder.dart';
import '../data/reader_probe.dart';
import '../data/reader_settings.dart';
import '../providers.dart';
import 'drive_ui.dart';
import 'sync_screen.dart';
import 'theme.dart';
import 'widgets/kit.dart';

const Map<ThemeMode, String> _themeLabels = {
  ThemeMode.dark: 'Scuro',
  ThemeMode.light: 'Chiaro',
  ThemeMode.system: 'Come il sistema',
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.dark;
    final root = ref.watch(libraryRootProvider);
    final autoBackup = ref.watch(autoBackupProvider).value ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          const KSection('Aspetto'),
          KSegmented(
            options: [
              for (final value in ThemeMode.values) _themeLabels[value]!,
            ],
            icons: const [
              LucideIcons.smartphone,
              LucideIcons.sun,
              LucideIcons.moon,
            ],
            index: ThemeMode.values.indexOf(mode),
            onChanged: (index) => ref
                .read(themeModeProvider.notifier)
                .set(ThemeMode.values[index]),
          ),
          const SizedBox(height: 26),
          const KSection('Libreria'),
          KGroup(
            children: [
              KTile(
                icon: LucideIcons.folder,
                title: 'Cartella',
                subtitle: root ?? 'Nessuna cartella scelta',
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () async {
                  final location =
                      await ref.read(libraryLocationProvider.future);
                  final chosen = await location.choose();
                  if (chosen == null) return;
                  ref.read(libraryRootProvider.notifier).select(chosen);
                  ref.invalidate(libraryCatalogProvider);
                  ref.invalidate(readingProvider);
                },
              ),
              KTile(
                icon: LucideIcons.refreshCw,
                title: 'Rileggi gli indici',
                subtitle: 'Da fare quando la sincronizzazione ha appena '
                    'portato roba nuova',
                onTap: () {
                  ref.invalidate(libraryCatalogProvider);
                  ref.invalidate(readingProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Indici riletti')),
                  );
                },
              ),
            ],
          ),
          if (cloudAvailable) ...[
            const SizedBox(height: 26),
            const KSection('Google Drive'),
            const _Drive(),
          ],
          const SizedBox(height: 26),
          const KSection('Lettura'),
          const _ReaderDefaults(),
          const SizedBox(height: 12),
          const _ProbeSwitch(),
          const SizedBox(height: 26),
          const KSection('Account'),
          const _Account(),
          const SizedBox(height: 26),
          const KSection('Dati'),
          KGroup(
            children: [
              KTile(
                icon: LucideIcons.databaseBackup,
                title: 'Copia automatica nella libreria',
                subtitle: 'Una volta al giorno in reading/backup/, che la '
                    'sincronizzazione porta su Drive insieme ai manga',
                onTap: () =>
                    ref.read(autoBackupProvider.notifier).set(!autoBackup),
                trailing: Switch(
                  value: autoBackup,
                  onChanged: (value) =>
                      ref.read(autoBackupProvider.notifier).set(value),
                ),
              ),
              KTile(
                icon: LucideIcons.download,
                title: 'Esporta i dati',
                subtitle:
                    'Stato, voti, cronologia, raccolte e segnalibri in un file',
                onTap: () => _export(context, ref),
              ),
              KTile(
                icon: LucideIcons.upload,
                title: 'Importa da un backup',
                subtitle: 'Dice cosa contiene prima di toccare niente',
                onTap: () => _import(context, ref),
              ),
              if (root != null) _AutoBackups(root: root),
              KTile(
                icon: LucideIcons.trash2,
                title: 'Elimina i dati personali',
                subtitle:
                    'Stato, voti, cronologia e raccolte. I manga non si toccano',
                tint: context.tokens.danger,
                onTap: () => _wipe(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const KSection('Informazioni'),
          const KGroup(children: [_About()]),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final service = ref.read(backupServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final bytes = await service.export();
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Dove salvare il backup',
      fileName: service.fileName(),
      bytes: bytes,
      mimeType: 'application/gzip',
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved == null ? 'Esportazione annullata' : 'Backup salvato',
        ),
      ),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final service = ref.read(backupServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Scegli un backup di Kagami',
      type: FileType.any,
    );
    final file = picked.firstOrNull;
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final summary = await service.inspect(bytes);
    if (summary == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Non è un backup di Kagami')),
      );
      return;
    }
    if (!context.mounted) return;

    final mode = await showKagamiSheet<ImportMode>(
      context,
      title: 'Importare questo backup?',
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KCard(
              color: context.colors.surfaceContainerHigh,
              child: KFigureRow(
                children: [
                  KFigure(value: '${summary.series}', label: 'Serie'),
                  KFigure(value: '${summary.chapters}', label: 'Letti'),
                  KFigure(value: '${summary.collections}', label: 'Raccolte'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Fatto il ${_date(summary.createdAt)}. Fondere tiene quello che '
              'hai già e aggiunge: i capitoli letti si sommano e per il resto '
              'vince il record più recente. Sostituire cancella i dati di '
              'questo dispositivo.',
              style: KagamiType.body(13, color: context.tokens.muted),
            ),
            const SizedBox(height: 22),
            KButton(
              label: 'Fondi',
              icon: LucideIcons.merge,
              expand: true,
              onPressed: () => Navigator.of(context).pop(ImportMode.merge),
            ),
            const SizedBox(height: 10),
            KGhostButton(
              label: 'Sostituisci',
              icon: LucideIcons.replace,
              expand: true,
              onPressed: () => Navigator.of(context).pop(ImportMode.replace),
            ),
          ],
        ),
      ),
    );
    if (mode == null) return;
    final done = await service.import(bytes, mode);
    ref.invalidate(readingProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(done ? 'Dati importati' : 'Importazione non riuscita'),
      ),
    );
  }

  Future<void> _wipe(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showKagamiSheet<bool>(
      context,
      title: 'Eliminare tutti i dati personali?',
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Spariscono stato, voti, preferiti, capitoli letti, cronologia, '
              'sessioni, raccolte e segnalibri di questo dispositivo. I manga '
              'e gli indici della libreria non vengono toccati.\n\n'
              'Se non hai un backup, questa è l\'ultima occasione per farlo.',
              style: KagamiType.body(13.5, color: context.tokens.muted),
            ),
            const SizedBox(height: 22),
            KButton(
              label: 'Elimina tutto',
              icon: LucideIcons.trash2,
              expand: true,
              tone: context.tokens.danger,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await ref.read(userRepositoryProvider).wipe();
    ref.invalidate(readingProvider);
    messenger.showSnackBar(
      const SnackBar(content: Text('Dati personali eliminati')),
    );
  }

  static String _date(DateTime? value) {
    if (value == null) return 'data ignota';
    final local = value.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}

/// L'account, cioè dove vivono i dati personali oltre a questo telefono.
///
/// È la stessa promessa del backup — voti, stati, capitoli letti, cronologia,
/// raccolte e impostazioni non muoiono con l'installazione — senza il file da
/// ricordarsi di fare.
/// Drive: la cartella, lo spazio che le tavole lette occupano, e dove
/// vanno quelle scaricate.
class _Drive extends ConsumerStatefulWidget {
  const _Drive();

  @override
  ConsumerState<_Drive> createState() => _DriveState();
}

class _DriveState extends ConsumerState<_Drive> {
  static const List<int> _limits = [512 << 20, 1 << 30, 2 << 30, 5 << 30];

  @override
  Widget build(BuildContext context) {
    final folder = ref.watch(driveFolderProvider).value;
    final root = ref.watch(libraryRootProvider);
    final private = ref.watch(downloadPrivateProvider).value ?? false;
    final limit =
        ref.watch(driveCacheLimitProvider).value ?? DriveCacheLimit.standard;
    final cache = ref.watch(driveFileCacheProvider);
    if (folder == null) {
      return KGroup(
        children: [
          KTile(
            icon: LucideIcons.cloud,
            title: 'Collega Google Drive',
            subtitle: 'Legge la libreria da Drive senza portarla tutta sul '
                'telefono, e scarica solo ciò che si sceglie',
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => connectDrive(context, ref),
          ),
        ],
      );
    }
    return KGroup(
      children: [
        KTile(
          icon: LucideIcons.cloud,
          title: 'Cartella su Drive',
          subtitle: folder.name,
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => connectDrive(context, ref),
        ),
        KTile(
          icon: LucideIcons.arrowDownUp,
          title: 'Sincronizzazione della cartella',
          subtitle: folderSyncSummary(
            ref.watch(folderSyncSettingsProvider).value ?? const SyncSettings(),
          ),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SyncScreen()),
          ),
        ),
        KTile(
          icon: LucideIcons.download,
          title: 'I capitoli scaricati vanno',
          subtitle: root != null
              ? 'Nella cartella della libreria: $root'
              : private
                  ? 'Nello spazio dell\'app: se ne vanno disinstallandola'
                  : 'Si chiede al primo download',
        ),
        FutureBuilder<void>(
          future: cache.ready(),
          builder: (context, _) => KTile(
            icon: LucideIcons.hardDrive,
            title: 'Tavole lette da Drive',
            subtitle: '${_size(cache.bytes)} in cache, al massimo '
                '${_size(limit)}. Si rileggono senza rete',
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => _chooseLimit(context, limit),
          ),
        ),
        KTile(
          icon: LucideIcons.trash2,
          title: 'Svuota la cache',
          subtitle: 'I capitoli scaricati non si toccano',
          onTap: () async {
            await cache.clear();
            if (mounted) setState(() {});
          },
        ),
        KTile(
          icon: LucideIcons.cloudOff,
          title: 'Scollega Drive',
          subtitle: 'La libreria torna a essere la cartella del telefono. '
              'I capitoli scaricati restano',
          tint: context.tokens.danger,
          onTap: () => ref.read(driveFolderProvider.notifier).choose(null),
        ),
      ],
    );
  }

  Future<void> _chooseLimit(BuildContext context, int current) async {
    final chosen = await showKagamiSheet<int>(
      context,
      title: 'Spazio per le tavole',
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: KSegmented(
          options: [for (final limit in _limits) _size(limit)],
          index: _limits.indexOf(current).clamp(0, _limits.length - 1),
          onChanged: (index) => Navigator.of(context).pop(_limits[index]),
        ),
      ),
    );
    if (chosen == null) return;
    await ref.read(driveCacheLimitProvider.notifier).set(chosen);
    if (mounted) setState(() {});
  }

  static String _size(int bytes) => bytes >= 1 << 30
      ? '${(bytes / (1 << 30)).toStringAsFixed(bytes % (1 << 30) == 0 ? 0 : 1)} GB'
      : '${(bytes / (1 << 20)).round()} MB';
}

class _Account extends ConsumerWidget {
  const _Account();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!cloudAvailable) {
      return const KGroup(
        children: [
          KTile(
            icon: LucideIcons.cloudOff,
            title: 'Account non disponibile qui',
            subtitle: 'Questa build non ha Firebase: i dati restano '
                'dove sono, sul dispositivo',
          ),
        ],
      );
    }

    final status = ref.watch(cloudAccountProvider);
    final notifier = ref.read(cloudAccountProvider.notifier);
    final account = status.account;

    return KGroup(
      children: [
        if (account == null)
          KTile(
            icon: LucideIcons.logIn,
            title: 'Accedi con Google',
            subtitle: 'Voti, stato, capitoli letti, cronologia e raccolte '
                'seguono l\'account invece del telefono',
            trailing: status.busy ? const _Working() : null,
            onTap: status.busy ? null : notifier.signIn,
          )
        else ...[
          KTile(
            icon: LucideIcons.userRound,
            title: account.label,
            subtitle: account.email,
          ),
          KTile(
            icon: LucideIcons.refreshCw,
            title: 'Sincronizza adesso',
            subtitle: _lastSync(status.lastSyncAt),
            trailing: status.busy ? const _Working() : null,
            onTap: status.busy ? null : notifier.syncNow,
          ),
          KTile(
            icon: LucideIcons.logOut,
            title: 'Esci',
            subtitle: 'Manda su l\'ultima lettura, poi chiude la sessione',
            onTap: status.busy ? null : notifier.signOut,
          ),
          KTile(
            icon: LucideIcons.cloudOff,
            title: 'Smetti di tenerne copia',
            subtitle: 'Cancella i dati dall\'account. Quelli di questo '
                'telefono restano dove sono',
            tint: context.tokens.danger,
            onTap: status.busy ? null : () => _forget(context, ref),
          ),
        ],
        if (status.error != null)
          KTile(
            icon: LucideIcons.triangleAlert,
            title: status.error!,
            subtitle: 'I dati di questo telefono non sono stati toccati',
            tint: context.tokens.danger,
          ),
      ],
    );
  }

  Future<void> _forget(BuildContext context, WidgetRef ref) async {
    final confirmed = await showKagamiSheet<bool>(
      context,
      title: 'Cancellare i dati dall\'account?',
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sparisce la copia tenuta per te, e l\'accesso si chiude. '
              'Stato, voti, cronologia e raccolte di questo telefono restano '
              'dove sono — ma da un altro telefono non si vedranno più.',
              style: KagamiType.body(13.5, color: context.tokens.muted),
            ),
            const SizedBox(height: 22),
            KButton(
              label: 'Cancella dall\'account',
              icon: LucideIcons.cloudOff,
              expand: true,
              tone: context.tokens.danger,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await ref.read(cloudAccountProvider.notifier).forget();
  }

  static String _lastSync(DateTime? value) {
    if (value == null) return 'Mai sincronizzato su questo telefono';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return 'L\'ultima volta il ${local.day}/${local.month} '
        'alle ${two(local.hour)}:${two(local.minute)}';
  }
}

/// Il giro d'attesa delle operazioni dell'account: stanno tutte dentro una
/// riga, e una riga non può diventare vuota mentre la si guarda.
class _Working extends StatelessWidget {
  const _Working();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 17,
        height: 17,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
}

/// I valori predefiniti del lettore: quelli che una serie senza impostazioni
/// proprie eredita.
class _ReaderDefaults extends ConsumerStatefulWidget {
  const _ReaderDefaults();

  @override
  ConsumerState<_ReaderDefaults> createState() => _ReaderDefaultsState();
}

class _ReaderDefaultsState extends ConsumerState<_ReaderDefaults> {
  ReaderSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await ref.read(readerSettingsProvider).forSeries('');
    if (mounted) setState(() => _settings = settings);
  }

  Future<void> _save(ReaderSettings settings) async {
    setState(() => _settings = settings);
    await ref.read(readerSettingsProvider).save('', settings);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KSegmented(
          options: [for (final mode in ReaderMode.values) mode.label],
          icons: const [LucideIcons.gripHorizontal, LucideIcons.square],
          index: settings.mode.index,
          onChanged: (index) =>
              _save(settings.copyWith(mode: ReaderMode.values[index])),
        ),
        const SizedBox(height: 12),
        KGroup(
          children: [
            KTile(
              icon: LucideIcons.arrowLeftRight,
              title: 'Direzione in paginata',
              subtitle: settings.direction.label,
              onTap: () => _save(
                settings.copyWith(
                  direction: settings.direction == ReaderDirection.rightToLeft
                      ? ReaderDirection.leftToRight
                      : ReaderDirection.rightToLeft,
                ),
              ),
            ),
            KTile(
              icon: LucideIcons.contrast,
              title: 'Sfondo',
              subtitle: settings.background.label,
              onTap: () => _save(
                settings.copyWith(
                  background: ReaderBackground.values[
                      (settings.background.index + 1) %
                          ReaderBackground.values.length],
                ),
              ),
            ),
            KTile(
              icon: LucideIcons.lightbulb,
              title: 'Tieni acceso lo schermo',
              onTap: () => _save(
                settings.copyWith(keepAwake: !settings.keepAwake),
              ),
              trailing: Switch(
                value: settings.keepAwake,
                onChanged: (value) =>
                    _save(settings.copyWith(keepAwake: value)),
              ),
            ),
            KTile(
              icon: LucideIcons.listOrdered,
              title: 'Barra di avanzamento',
              onTap: () => _save(
                settings.copyWith(showProgress: !settings.showProgress),
              ),
              trailing: Switch(
                value: settings.showProgress,
                onChanged: (value) =>
                    _save(settings.copyWith(showProgress: value)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// La misura della fluidità del lettore: vedi [ReaderProbe].
class _ProbeSwitch extends StatelessWidget {
  const _ProbeSwitch();

  @override
  Widget build(BuildContext context) {
    final probe = ReaderProbe.instance;
    final decoder = PageDecoder.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([probe.enabled, decoder.textureMode]),
      builder: (context, _) => KGroup(
        children: [
          KTile(
            icon: LucideIcons.gauge,
            title: 'Misura la fluidità',
            subtitle: 'Nel lettore, in alto: fotogrammi lenti e saltati, da '
                'dove arrivano le fasce, GC. Un tocco sui numeri li azzera',
            onTap: () => probe.setEnabled(!probe.on),
            trailing: _WithInfo(
              title: 'Misura la fluidità',
              paragraphs: _probeInfo,
              child: Switch(value: probe.on, onChanged: probe.setEnabled),
            ),
          ),
          // Solo dove c'è il decodificatore nativo: altrove non ci sono
          // fasce native da mostrare in nessun modo.
          if (decoder.canDecodeRegions)
            KTile(
              icon: LucideIcons.layers,
              title: 'Fasce native come texture',
              subtitle: 'Prova: le tavole ancora da tagliare arrivano alla '
                  'GPU senza passare dall\'interfaccia. Si spegne riaprendo '
                  "l'app",
              onTap: () => decoder.textures = !decoder.textures,
              trailing: _WithInfo(
                title: 'Fasce native come texture',
                paragraphs: _textureInfo,
                child: Switch(
                  value: decoder.textures,
                  onChanged: (value) => decoder.textures = value,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _probeInfo = [
  'Mostra nel lettore, in alto a sinistra, un riquadro di numeri su quanto '
      'è fluida la lettura. Serve a capire perché lo scorrimento scatta: non '
      'cambia niente di come si legge, e costa pochissimo.',
  'Il numero che conta di più è «saltati»: i fotogrammi che mancano mentre '
      'la pagina scorre. Ognuno è un piccolo scatto che si vede. «Partiti '
      'tardi» e «Lenti» dicono se l\'app era occupata, «GC Android» se il '
      'sistema stava liberando memoria.',
  '«Tessere», «intere», «del telefono» e «native» dicono da dove è arrivato '
      'ogni pezzo di tavola: le prime tre sono le vie leggere, l\'ultima è il '
      'ritaglio fatto al momento, che è quella che pesa.',
  'Un tocco sul riquadro azzera i numeri, così si misura da un punto preciso '
      'del capitolo. Riaprendo l\'app la misura si spegne da sola.',
];

const _textureInfo = [
  'Le tavole molto alte di un webtoon si leggono a pezzi. Quasi sempre i pezzi '
      'sono già pronti: tagliati dall\'archivio sul server, o dal telefono la '
      'prima volta che si apre il capitolo. Quando non lo sono, li ritaglia al '
      'momento il decodificatore di Android.',
  'Normalmente i pixel di quei pezzi passano dall\'app prima di arrivare allo '
      'schermo. Con questa opzione vanno direttamente alla scheda grafica: '
      'l\'app ha meno lavoro mentre si scorre, e lo scorrimento può scattare '
      'meno. La qualità dell\'immagine non cambia.',
  'È una prova: è un modo di disegnare nuovo, non ancora verificato su questo '
      'telefono. Se vedi tavole nere, righe o sfarfallii, spegnila. Se il '
      'telefono non lo supporta, l\'app torna da sola al modo normale.',
  'Sui capitoli già tagliati in tessere non cambia niente, perché lì questa '
      'strada non si usa. Riaprendo l\'app si spegne da sola.',
];

/// Un interruttore con accanto la spiegazione di cosa fa.
class _WithInfo extends StatelessWidget {
  const _WithInfo({
    required this.title,
    required this.paragraphs,
    required this.child,
  });

  final String title;
  final List<String> paragraphs;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Cosa fa',
            icon: const Icon(LucideIcons.info, size: 18),
            onPressed: () => showKagamiSheet<void>(
              context,
              title: title,
              scrollable: true,
              builder: (context) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final paragraph in paragraphs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          paragraph,
                          style: KagamiType.body(14, color: context.colors.onSurface),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      );
}

/// Le copie automatiche che stanno nella libreria: serve saperlo, altrimenti
/// il backup automatico è una promessa che nessuno può verificare.
class _AutoBackups extends ConsumerWidget {
  const _AutoBackups({required this.root});

  final String root;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(backupServiceProvider);
    return FutureBuilder<List<File>>(
      future: service.backupsIn(root),
      builder: (context, snapshot) {
        final files = snapshot.data ?? const <File>[];
        return KTile(
          icon: LucideIcons.hardDriveDownload,
          title: 'Copie nella libreria',
          subtitle: files.isEmpty
              ? 'Nessuna copia ancora: la prima si fa alla prossima apertura'
              : '${files.length} copie, l\'ultima ${_name(files.first)}',
          trailing: IconButton(
            tooltip: 'Fai una copia adesso',
            icon: const Icon(LucideIcons.play, size: 17),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final bytes = await service.export();
              final directory = Directory('$root/reading/backup');
              await directory.create(recursive: true);
              final file = File('${directory.path}/${service.fileName()}');
              await file.writeAsBytes(bytes, flush: true);
              messenger.showSnackBar(
                SnackBar(content: Text('Copia scritta in ${file.path}')),
              );
            },
          ),
        );
      },
    );
  }

  static String _name(File file) => file.uri.pathSegments.last;
}

class _About extends StatelessWidget {
  const _About();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) => KTile(
          icon: LucideIcons.info,
          title: 'Kagami',
          subtitle: snapshot.hasData
              ? 'versione ${snapshot.data!.version} '
                  '(${snapshot.data!.buildNumber})'
              : 'lettore per archivi MALF locali',
        ),
      );
}
