/// I gesti che riguardano Drive: collegarlo, sceglierne la cartella, dire
/// dove vanno i download e cosa non ha funzionato.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/drive.dart';
import '../data/library.dart';
import '../data/library_repository.dart';
import '../data/network.dart';
import '../format/malf.dart';
import '../providers.dart';
import 'theme.dart';
import 'widgets/kit.dart';

/// Collega Drive da capo: accesso, permesso sui file, cartella.
///
/// Sono tre passi perché sono tre cose diverse per Google: chi sei, cosa
/// l'app può leggere, e dove sta la libreria. Ognuno si salta se è già fatto.
Future<void> connectDrive(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!ref.read(cloudAccountProvider).signedIn) {
    await ref.read(cloudAccountProvider.notifier).signIn();
    if (!ref.read(cloudAccountProvider).signedIn) return;
  }
  try {
    await ref.read(driveAuthProvider).authorize();
  } on DriveAuthRequired {
    return;
  } on DriveException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    return;
  }
  if (!context.mounted) return;
  final folder = await showKagamiSheet<DriveFolder>(
    context,
    title: 'Cartella su Drive',
    scrollable: true,
    builder: (_) => const DriveFolderBrowser(),
  );
  if (folder == null) return;
  await ref.read(driveFolderProvider.notifier).choose(folder);
}

/// Il permesso sui file, chiesto da un avviso: l'account c'è già.
Future<void> authorizeDrive(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(driveAuthProvider).authorize();
  } on DriveAuthRequired {
    return;
  } on DriveException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    return;
  }
  reloadLibrary(ref);
}

/// Dove scaricare. La cartella scelta, se c'è; altrimenti si chiede una volta
/// se sceglierne una, e chi preferisce di no ha lo spazio dell'app — che però
/// sparisce disinstallando, ed è per questo che la cartella si propone prima.
///
/// `null` se l'utente ha rinunciato.
Future<String?> downloadDestination(BuildContext context, WidgetRef ref) async {
  final root = ref.read(libraryRootProvider);
  if (root != null) return root;
  final private = ref.read(appDirectoriesProvider).privateLibrary;
  if (await ref.read(downloadPrivateProvider.future)) return private;
  if (!context.mounted) return null;
  final folder = await showKagamiSheet<bool>(
    context,
    title: 'Dove salvo i manga?',
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Non c\'è una cartella per i manga sul telefono. In una cartella '
            'i capitoli scaricati restano anche se l\'app si disinstalla, e '
            'Kagami li legge insieme a quelli che ci sono già. Nello spazio '
            'dell\'app non serve nessun permesso, ma se ne vanno con lei.',
            style: KagamiType.body(13.5, height: 1.5, color: context.tokens.muted),
          ),
          const SizedBox(height: 20),
          KButton(
            label: 'Scegli una cartella',
            icon: LucideIcons.folderOpen,
            expand: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
          KGhostButton(
            label: 'Nello spazio dell\'app',
            icon: LucideIcons.smartphone,
            expand: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    ),
  );
  if (folder == null) return null;
  if (!folder) {
    await ref.read(downloadPrivateProvider.notifier).preferPrivate();
    return private;
  }
  final location = await ref.read(libraryLocationProvider.future);
  if (!await location.hasAccess() && !await location.requestAccess()) {
    return null;
  }
  final chosen = await location.choose();
  if (chosen != null) ref.read(libraryRootProvider.notifier).select(chosen);
  return chosen;
}

/// Scarica dei capitoli di una serie, chiedendo prima dove se serve.
Future<void> downloadChapters(
  BuildContext context,
  WidgetRef ref,
  String seriesKey,
  Iterable<String> chapterIds,
) async {
  final ids = chapterIds.toList(growable: false);
  if (ids.isEmpty) return;
  final destination = await downloadDestination(context, ref);
  if (destination == null) return;
  ref.read(downloadsProvider.notifier).enqueue(seriesKey, ids, destination);
}

/// Il navigatore delle cartelle di Drive.
///
/// Su Android non c'è un selettore di sistema per le cartelle di Drive: si
/// scende un livello alla volta, come nel pannello del server.
class DriveFolderBrowser extends ConsumerStatefulWidget {
  const DriveFolderBrowser({super.key});

  @override
  ConsumerState<DriveFolderBrowser> createState() => _DriveFolderBrowserState();
}

class _DriveFolderBrowserState extends ConsumerState<DriveFolderBrowser> {
  late final DriveClient _client = DriveClient(ref.read(driveAuthProvider).token, network: NetworkMonitor.instance);

  /// Da dove si è partiti: il proprio Drive o ciò che altri hanno condiviso.
  bool _shared = false;
  final List<DriveItem> _path = [];
  Future<List<DriveItem>>? _children;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  void _load() {
    final here = _path.lastOrNull;
    _children = here == null
        ? (_shared ? _client.sharedFolders() : _client.children('root'))
        : _client.children(here.id);
  }

  void _open(DriveItem folder) => setState(() {
        _path.add(folder);
        _load();
      });

  void _back() => setState(() {
        _path.removeLast();
        _load();
      });

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    final here = _path.lastOrNull;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: here == null
                ? KSegmented(
                    options: const ['Il mio Drive', 'Condivisi con me'],
                    icons: const [LucideIcons.hardDrive, LucideIcons.users],
                    index: _shared ? 1 : 0,
                    onChanged: (index) => setState(() {
                      _shared = index == 1;
                      _load();
                    }),
                  )
                : Row(
                    children: [
                      IconButton(
                        tooltip: 'Indietro',
                        onPressed: _back,
                        icon: const Icon(LucideIcons.arrowLeft, size: 20),
                      ),
                      Expanded(
                        child: Text(
                          here.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KagamiType.title(15, weight: 700),
                        ),
                      ),
                    ],
                  ),
          ),
          Flexible(
            child: FutureBuilder<List<DriveItem>>(
              future: _children,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return KEmpty(
                    icon: LucideIcons.cloudOff,
                    compact: true,
                    title: 'Drive non risponde',
                    message: '${snapshot.error}',
                    action: KGhostButton(
                      label: 'Riprova',
                      icon: LucideIcons.refreshCw,
                      onPressed: () => setState(_load),
                    ),
                  );
                }
                final items = snapshot.data;
                if (items == null) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final folders = items.where((item) => item.folder).toList();
                final isLibrary = items.any(
                  (item) => !item.folder && item.name == libraryIndexFile,
                );
                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    if (here != null) ...[
                      KCard(
                        child: Row(
                          children: [
                            Icon(
                              isLibrary
                                  ? LucideIcons.folderCheck
                                  : LucideIcons.folderX,
                              size: 20,
                              color: isLibrary ? context.colors.primary : muted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isLibrary
                                    ? 'Contiene library.json: è una libreria'
                                    : 'Non contiene library.json: la '
                                        'libreria è la cartella che lo ha',
                                style: KagamiType.body(13, color: muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      KButton(
                        label: 'Usa questa cartella',
                        icon: LucideIcons.check,
                        expand: true,
                        onPressed: isLibrary
                            ? () => Navigator.of(context).pop(
                                  DriveFolder(id: here.id, name: here.name),
                                )
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (folders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Nessuna cartella qui',
                          textAlign: TextAlign.center,
                          style: KagamiType.body(13, color: muted),
                        ),
                      )
                    else
                      KGroup(
                        children: [
                          for (final folder in folders)
                            KTile(
                              icon: LucideIcons.folder,
                              title: folder.name,
                              trailing: const Icon(
                                LucideIcons.chevronRight,
                                size: 18,
                              ),
                              onTap: () => _open(folder),
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Una sorgente che non ha risposto mentre le altre sì: una riga sopra la
/// libreria, con il gesto che la rimette a posto.
class LibraryNotices extends ConsumerWidget {
  const LibraryNotices({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(libraryCatalogProvider).value?.notices ?? const [];
    if (notices.isEmpty) return const SizedBox.shrink();
    final notice = notices.first;
    final (message, action, onPressed) = noticeOf(context, ref, notice);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: KCard(
        child: Row(
          children: [
            Icon(LucideIcons.cloudOff, size: 20, color: context.tokens.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: KagamiType.body(13, height: 1.4)),
            ),
            TextButton(onPressed: onPressed, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

/// Cosa dire di un problema di una sorgente, e come rimediarvi.
(String, String, VoidCallback) noticeOf(
  BuildContext context,
  WidgetRef ref,
  Object notice,
) =>
    switch (notice) {
      DriveAuthRequired() => (
          'Kagami non ha ancora il permesso di leggere Google Drive',
          'Autorizza',
          () => authorizeDrive(context, ref),
        ),
      DriveSignedOut() => (
          notice.toString(),
          'Accedi',
          () => ref.read(cloudAccountProvider.notifier).signIn(),
        ),
      DriveOffline() => (
          'Sei offline: si leggono i capitoli sul telefono e le tavole di '
          'Drive già scaricate. Il resto torna da solo con la rete',
          'Riprova',
          () async {
            if (await NetworkMonitor.instance.check()) reloadLibrary(ref);
          },
        ),
      DriveException(:final message) => (
          'Drive: $message. Si vede quello che c\'è sul telefono',
          'Riprova',
          () => reloadLibrary(ref),
        ),
      LibraryException(:final problem) => (
          problem.message,
          'Riprova',
          () => reloadLibrary(ref),
        ),
      _ => ('$notice', 'Riprova', () => reloadLibrary(ref)),
    };
