/// Impostazioni: la destinazione con chi legge, le schermate in cui si entra
/// di proposito, l'aspetto e le voci che portano alle pagine di libreria,
/// lettura, account e dati.
///
/// La voce che conta è «Dati». Da quando lo stato utente vive nel database
/// dell'app, portarsi via i propri dati non è una funzione in più: è il modo
/// in cui sopravvivono a una reinstallazione.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/backup.dart';
import '../data/cloud.dart';
import '../data/folder_sync.dart';
import '../data/page_decoder.dart';
import '../data/reader_probe.dart';
import '../data/reader_settings.dart';
import '../l10n.dart';
import '../providers.dart';
import 'app_shell.dart';
import 'archive_screen.dart';
import 'drive_ui.dart';
import 'history_screen.dart';
import 'statistics_screen.dart';
import 'sync_screen.dart';
import 'theme.dart';
import 'widgets/kit.dart';

String _themeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
      ThemeMode.dark => l10n.settingsThemeDark,
      ThemeMode.light => l10n.settingsThemeLight,
      ThemeMode.system => l10n.settingsThemeSystem,
    };

/// La scelta attuale accanto alla freccia, come in una riga che apre un
/// elenco.
class _Value extends StatelessWidget {
  const _Value([this.value]);

  final String? value;

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              value!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KagamiType.title(14, color: muted),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Icon(LucideIcons.chevronRight, size: 18, color: muted),
      ],
    );
  }
}

/// Una scelta fra pochi valori in un foglio: si tocca e il foglio si chiude.
Future<void> _choose<T>(
  BuildContext context, {
  required String title,
  required T current,
  required List<T> values,
  required String Function(T) label,
  required ValueChanged<T> onChosen,
}) =>
    showKagamiSheet<void>(
      context,
      title: title,
      scrollable: true,
      builder: (sheet) => RadioGroup<T>(
        groupValue: current,
        onChanged: (value) {
          onChosen(value as T);
          Navigator.of(sheet).pop();
        },
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final value in values)
              RadioListTile<T>(value: value, title: Text(label(value))),
          ],
        ),
      ),
    );

class _Theme extends ConsumerWidget {
  const _Theme();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.dark;
    return KTile(
      icon: LucideIcons.sunMoon,
      title: l10n.settingsTheme,
      trailing: _Value(_themeLabel(l10n, mode)),
      onTap: () => _choose<ThemeMode>(
        context,
        title: l10n.settingsTheme,
        current: mode,
        values: ThemeMode.values,
        label: (value) => _themeLabel(l10n, value),
        onChosen: ref.read(themeModeProvider.notifier).set,
      ),
    );
  }
}

/// La lingua dell'interfaccia: quella del sistema o una delle tradotte.
class _Language extends ConsumerWidget {
  const _Language();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chosen = ref.watch(appLanguageProvider).value;
    String label(Locale? locale) => locale == null
        ? l10n.settingsLanguageSystem
        : languageNames[locale.languageCode]!;
    return KTile(
      icon: LucideIcons.languages,
      title: l10n.settingsLanguage,
      trailing: _Value(label(chosen)),
      onTap: () => _choose<Locale?>(
        context,
        title: l10n.settingsLanguage,
        current: chosen,
        values: [null, ...AppLocalizations.supportedLocales],
        label: label,
        onChosen: ref.read(appLanguageProvider.notifier).set,
      ),
    );
  }
}

/// La quarta destinazione: chi legge, ciò in cui si entra di proposito —
/// scaricare, cronologia, statistiche, incognito — e le impostazioni vere,
/// ognuna nella sua pagina.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final incognito = ref.watch(incognitoProvider).value ?? false;
    void open(Widget page) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => page),
        );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, navBarInset),
          children: [
            Text(l10n.settingsTitle, style: KagamiType.display(30)),
            if (cloudAvailable) ...[
              const SizedBox(height: 28),
              Entrance(child: _Profile(onTap: () => open(const _AccountPage()))),
            ],
            const SizedBox(height: 28),
            Entrance(
              index: 1,
              child: KGroup(
                children: [
                  KTile(
                    icon: LucideIcons.download,
                    title: l10n.moreDownload,
                    subtitle: l10n.moreDownloadSubtitle,
                    trailing: const _Value(),
                    onTap: () => open(const ArchiveScreen()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Entrance(
              index: 2,
              child: KGroup(
                children: [
                  KTile(
                    icon: LucideIcons.history,
                    title: l10n.moreHistory,
                    subtitle: l10n.moreHistorySubtitle,
                    trailing: const _Value(),
                    onTap: () => open(const HistoryScreen()),
                  ),
                  KTile(
                    icon: LucideIcons.chartColumn,
                    title: l10n.moreStatistics,
                    subtitle: l10n.moreStatisticsSubtitle,
                    trailing: const _Value(),
                    onTap: () => open(const StatisticsScreen()),
                  ),
                  KTile(
                    icon: incognito ? LucideIcons.eyeOff : LucideIcons.eye,
                    title: l10n.moreIncognito,
                    subtitle: l10n.moreIncognitoSubtitle,
                    tint: incognito ? context.colors.primary : null,
                    onTap: ref.read(incognitoProvider.notifier).toggle,
                    trailing: Switch(
                      value: incognito,
                      onChanged: (_) =>
                          ref.read(incognitoProvider.notifier).toggle(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Entrance(
              index: 3,
              child: KGroup(children: [_Theme(), _Language()]),
            ),
            const SizedBox(height: 22),
            Entrance(
              index: 4,
              child: KGroup(
                children: [
                  KTile(
                    icon: LucideIcons.libraryBig,
                    title: l10n.settingsLibrary,
                    subtitle: cloudAvailable
                        ? l10n.settingsLibraryNote
                        : l10n.settingsLibraryNoteLocal,
                    trailing: const _Value(),
                    onTap: () => open(const _LibraryPage()),
                  ),
                  KTile(
                    icon: LucideIcons.bookOpen,
                    title: l10n.settingsReading,
                    subtitle: l10n.settingsReadingNote,
                    trailing: const _Value(),
                    onTap: () => open(const _ReadingPage()),
                  ),
                  KTile(
                    icon: LucideIcons.userRound,
                    title: l10n.settingsAccount,
                    subtitle: l10n.settingsAccountNote,
                    trailing: const _Value(),
                    onTap: () => open(const _AccountPage()),
                  ),
                  KTile(
                    icon: LucideIcons.database,
                    title: l10n.settingsData,
                    subtitle: l10n.settingsDataNote,
                    trailing: const _Value(),
                    onTap: () => open(const _DataPage()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Entrance(index: 5, child: KGroup(children: [_About()])),
          ],
        ),
      ),
    );
  }
}

/// Chi legge: la foto e il nome dell'account Google, o l'invito ad
/// accedere. Toccandolo si apre la pagina dell'account.
class _Profile extends ConsumerWidget {
  const _Profile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final muted = context.tokens.muted;
    final account = ref.watch(cloudAccountProvider).account;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: account == null
            ? Icon(LucideIcons.userRound, size: 36, color: muted)
            : Text(
                account.label.characters.first.toUpperCase(),
                style: KagamiType.display(36),
              ),
      ),
    );
    final photo = account?.photo;

    return Semantics(
      button: true,
      label: l10n.settingsAccount,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Stack(
              children: [
                ClipOval(
                  child: SizedBox.square(
                    dimension: 88,
                    child: photo == null
                        ? placeholder
                        : Image.network(
                            photo,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => placeholder,
                          ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary,
                      border: Border.all(color: scheme.surface, width: 2),
                    ),
                    child: Icon(
                      account == null ? LucideIcons.logIn : LucideIcons.cloudCheck,
                      size: 12,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              account?.label ?? l10n.settingsAccountSignIn,
              textAlign: TextAlign.center,
              style: KagamiType.title(19, weight: 800),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                account == null || account.label == account.email
                    ? l10n.settingsAccountSignInNote
                    : account.email,
                textAlign: TextAlign.center,
                style: KagamiType.body(13, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una pagina delle impostazioni: il titolo in alto e le sue schede.
class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: children,
        ),
      );
}

class _LibraryPage extends ConsumerWidget {
  const _LibraryPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final root = ref.watch(libraryRootProvider);
    return _Page(
      title: l10n.settingsLibrary,
      children: [
        KGroup(
          children: [
            KTile(
              icon: LucideIcons.folder,
              title: l10n.settingsFolder,
              subtitle: root ?? l10n.settingsNoFolder,
              trailing: const _Value(),
              onTap: () async {
                final location = await ref.read(libraryLocationProvider.future);
                final chosen = await location.choose();
                if (chosen == null) return;
                ref.read(libraryRootProvider.notifier).select(chosen);
                ref.invalidate(libraryCatalogProvider);
                ref.invalidate(readingProvider);
              },
            ),
            KTile(
              icon: LucideIcons.refreshCw,
              title: l10n.settingsReloadIndexes,
              subtitle: l10n.settingsReloadIndexesNote,
              onTap: () {
                ref.invalidate(libraryCatalogProvider);
                ref.invalidate(readingProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.settingsIndexesReloaded)),
                );
              },
            ),
          ],
        ),
        if (cloudAvailable) ...[
          const SizedBox(height: 26),
          KSection(l10n.settingsGoogleDrive),
          const _Drive(),
        ],
      ],
    );
  }
}

class _ReadingPage extends StatelessWidget {
  const _ReadingPage();

  @override
  Widget build(BuildContext context) => _Page(
        title: context.l10n.settingsReading,
        children: const [
          _ReaderDefaults(),
          SizedBox(height: 12),
          _RatingInviteSwitch(),
          SizedBox(height: 12),
          _ProbeSwitch(),
        ],
      );
}

class _RatingInviteSwitch extends ConsumerWidget {
  const _RatingInviteSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final on = ref.watch(ratingInviteProvider).value ?? true;
    return KGroup(
      children: [
        KTile(
          icon: LucideIcons.star,
          title: l10n.settingsRatingInvite,
          subtitle: l10n.settingsRatingInviteNote,
          onTap: () => ref.read(ratingInviteProvider.notifier).set(!on),
          trailing: Switch(
            value: on,
            onChanged: ref.read(ratingInviteProvider.notifier).set,
          ),
        ),
      ],
    );
  }
}

/// L'account, cioè dove vivono i dati personali oltre a questo telefono.
///
/// È la stessa promessa del backup — voti, stati, capitoli letti, cronologia,
/// raccolte e impostazioni non muoiono con l'installazione — senza il file da
/// ricordarsi di fare.
class _AccountPage extends StatelessWidget {
  const _AccountPage();

  @override
  Widget build(BuildContext context) => _Page(
        title: context.l10n.settingsAccount,
        children: const [_Account()],
      );
}

class _DataPage extends ConsumerWidget {
  const _DataPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final root = ref.watch(libraryRootProvider);
    final autoBackup = ref.watch(autoBackupProvider).value ?? true;
    return _Page(
      title: l10n.settingsData,
      children: [
        KGroup(
          children: [
            KTile(
              icon: LucideIcons.databaseBackup,
              title: l10n.settingsAutoBackup,
              subtitle: l10n.settingsAutoBackupNote,
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
              title: l10n.settingsExport,
              subtitle: l10n.settingsExportNote,
              onTap: () => _export(context, ref),
            ),
            KTile(
              icon: LucideIcons.upload,
              title: l10n.settingsImport,
              subtitle: l10n.settingsImportNote,
              onTap: () => _import(context, ref),
            ),
            if (root != null) _AutoBackups(root: root),
          ],
        ),
        const SizedBox(height: 22),
        KGroup(
          children: [
            KTile(
              icon: LucideIcons.trash2,
              title: l10n.settingsWipe,
              subtitle: l10n.settingsWipeNote,
              tint: context.tokens.danger,
              onTap: () => _wipe(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final service = ref.read(backupServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final bytes = await service.export();
    final saved = await FilePicker.saveFile(
      dialogTitle: l10n.settingsExportDialog,
      fileName: service.fileName(),
      bytes: bytes,
      mimeType: 'application/gzip',
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved == null
              ? l10n.settingsExportCancelled
              : l10n.settingsExportSaved,
        ),
      ),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final service = ref.read(backupServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.pickFiles(
      dialogTitle: l10n.settingsImportDialog,
      type: FileType.any,
    );
    final file = picked.firstOrNull;
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final summary = await service.inspect(bytes);
    if (summary == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsImportInvalid)),
      );
      return;
    }
    if (!context.mounted) return;

    final mode = await showKagamiSheet<ImportMode>(
      context,
      title: l10n.settingsImportSheetTitle,
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
                  KFigure(value: '${summary.series}', label: l10n.settingsImportSeries),
                  KFigure(value: '${summary.chapters}', label: l10n.settingsImportRead),
                  KFigure(value: '${summary.collections}', label: l10n.settingsImportCollections),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              summary.createdAt == null
                  ? l10n.settingsImportExplainUnknownDate
                  : l10n.settingsImportExplain(
                      DateFormat.yMd(l10n.localeName)
                          .format(summary.createdAt!.toLocal()),
                    ),
              style: KagamiType.body(13, color: context.tokens.muted),
            ),
            const SizedBox(height: 22),
            KButton(
              label: l10n.settingsImportMerge,
              icon: LucideIcons.merge,
              expand: true,
              onPressed: () => Navigator.of(context).pop(ImportMode.merge),
            ),
            const SizedBox(height: 10),
            KGhostButton(
              label: l10n.settingsImportReplace,
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
        content: Text(
          done ? l10n.settingsImportDone : l10n.settingsImportFailed,
        ),
      ),
    );
  }

  Future<void> _wipe(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showKagamiSheet<bool>(
      context,
      title: l10n.settingsWipeSheetTitle,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.settingsWipeExplain,
              style: KagamiType.body(13.5, color: context.tokens.muted),
            ),
            const SizedBox(height: 22),
            KButton(
              label: l10n.settingsWipeConfirm,
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
      SnackBar(content: Text(l10n.settingsWipeDone)),
    );
  }
}


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
    final l10n = context.l10n;
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
            title: l10n.settingsDriveConnect,
            subtitle: l10n.settingsDriveConnectNote,
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
          title: l10n.settingsDriveFolder,
          subtitle: folder.name,
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () => connectDrive(context, ref),
        ),
        KTile(
          icon: LucideIcons.arrowDownUp,
          title: l10n.settingsDriveSync,
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
          title: l10n.settingsDriveDownloadsGo,
          subtitle: root != null
              ? l10n.settingsDriveDownloadsFolder(root)
              : private
                  ? l10n.settingsDriveDownloadsApp
                  : l10n.settingsDriveDownloadsAsk,
        ),
        FutureBuilder<void>(
          future: cache.ready(),
          builder: (context, _) => KTile(
            icon: LucideIcons.hardDrive,
            title: l10n.settingsDriveCache,
            subtitle: l10n.settingsDriveCacheNote(
              _size(cache.bytes),
              _size(limit),
            ),
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => _chooseLimit(context, limit),
          ),
        ),
        KTile(
          icon: LucideIcons.trash2,
          title: l10n.settingsDriveClearCache,
          subtitle: l10n.settingsDriveClearCacheNote,
          onTap: () async {
            await cache.clear();
            if (mounted) setState(() {});
          },
        ),
        KTile(
          icon: LucideIcons.cloudOff,
          title: l10n.settingsDriveDisconnect,
          subtitle: l10n.settingsDriveDisconnectNote,
          tint: context.tokens.danger,
          onTap: () => ref.read(driveFolderProvider.notifier).choose(null),
        ),
      ],
    );
  }

  Future<void> _chooseLimit(BuildContext context, int current) async {
    final chosen = await showKagamiSheet<int>(
      context,
      title: context.l10n.settingsDriveCacheLimitTitle,
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
    final l10n = context.l10n;
    if (!cloudAvailable) {
      return KGroup(
        children: [
          KTile(
            icon: LucideIcons.cloudOff,
            title: l10n.settingsAccountUnavailable,
            subtitle: l10n.settingsAccountUnavailableNote,
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
            title: l10n.settingsAccountSignIn,
            subtitle: l10n.settingsAccountSignInNote,
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
            title: l10n.settingsAccountSyncNow,
            subtitle: _lastSync(l10n, status.lastSyncAt),
            trailing: status.busy ? const _Working() : null,
            onTap: status.busy ? null : notifier.syncNow,
          ),
          KTile(
            icon: LucideIcons.logOut,
            title: l10n.settingsAccountSignOut,
            subtitle: l10n.settingsAccountSignOutNote,
            onTap: status.busy ? null : notifier.signOut,
          ),
          KTile(
            icon: LucideIcons.cloudOff,
            title: l10n.settingsAccountForget,
            subtitle: l10n.settingsAccountForgetNote,
            tint: context.tokens.danger,
            onTap: status.busy ? null : () => _forget(context, ref),
          ),
        ],
        if (status.error != null)
          KTile(
            icon: LucideIcons.triangleAlert,
            title: status.error!,
            subtitle: l10n.settingsAccountErrorNote,
            tint: context.tokens.danger,
          ),
      ],
    );
  }

  Future<void> _forget(BuildContext context, WidgetRef ref) async {
    final confirmed = await showKagamiSheet<bool>(
      context,
      title: context.l10n.settingsAccountForgetSheetTitle,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.settingsAccountForgetExplain,
              style: KagamiType.body(13.5, color: context.tokens.muted),
            ),
            const SizedBox(height: 22),
            KButton(
              label: context.l10n.settingsAccountForgetConfirm,
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

  static String _lastSync(AppLocalizations l10n, DateTime? value) {
    if (value == null) return l10n.settingsAccountNeverSynced;
    final local = value.toLocal();
    return l10n.settingsAccountLastSync(
      DateFormat.Md(l10n.localeName).format(local),
      DateFormat.Hm(l10n.localeName).format(local),
    );
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
              title: context.l10n.settingsReaderDirection,
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
              title: context.l10n.settingsReaderBackground,
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
              title: context.l10n.settingsReaderKeepAwake,
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
              title: context.l10n.settingsReaderProgressBar,
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
    final l10n = context.l10n;
    final probe = ReaderProbe.instance;
    final decoder = PageDecoder.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([probe.enabled, decoder.textureMode]),
      builder: (context, _) => KGroup(
        children: [
          KTile(
            icon: LucideIcons.gauge,
            title: l10n.settingsProbe,
            subtitle: l10n.settingsProbeNote,
            onTap: () => probe.setEnabled(!probe.on),
            trailing: _WithInfo(
              title: l10n.settingsProbe,
              paragraphs: [
                l10n.settingsProbeInfo1,
                l10n.settingsProbeInfo2,
                l10n.settingsProbeInfo3,
                l10n.settingsProbeInfo4,
              ],
              child: Switch(value: probe.on, onChanged: probe.setEnabled),
            ),
          ),
          // Solo dove c'è il decodificatore nativo: altrove non ci sono
          // fasce native da mostrare in nessun modo.
          if (decoder.canDecodeRegions)
            KTile(
              icon: LucideIcons.layers,
              title: l10n.settingsTexture,
              subtitle: l10n.settingsTextureNote,
              onTap: () => decoder.textures = !decoder.textures,
              trailing: _WithInfo(
                title: l10n.settingsTexture,
                paragraphs: [
                  l10n.settingsTextureInfo1,
                  l10n.settingsTextureInfo2,
                  l10n.settingsTextureInfo3,
                  l10n.settingsTextureInfo4,
                ],
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
            tooltip: context.l10n.settingsWhatItDoes,
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
    final l10n = context.l10n;
    final service = ref.watch(backupServiceProvider);
    return FutureBuilder<List<File>>(
      future: service.backupsIn(root),
      builder: (context, snapshot) {
        final files = snapshot.data ?? const <File>[];
        return KTile(
          icon: LucideIcons.hardDriveDownload,
          title: l10n.settingsBackupsTitle,
          subtitle: files.isEmpty
              ? l10n.settingsBackupsNone
              : l10n.settingsBackupsLatest(files.length, _name(files.first)),
          trailing: IconButton(
            tooltip: l10n.settingsBackupNow,
            icon: const Icon(LucideIcons.play, size: 17),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final bytes = await service.export();
              final directory = Directory('$root/reading/backup');
              await directory.create(recursive: true);
              final file = File('${directory.path}/${service.fileName()}');
              await file.writeAsBytes(bytes, flush: true);
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.settingsBackupWritten(file.path))),
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
              ? context.l10n.settingsVersion(
                  snapshot.data!.version,
                  snapshot.data!.buildNumber,
                )
              : context.l10n.settingsTagline,
        ),
      );
}
