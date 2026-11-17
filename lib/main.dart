import 'dart:async';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kagami_archive/renderer.dart' show installPageRenderer;
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'src/archive/background.dart';
import 'src/archive/page_browser.dart' show platformPageBrowser;
import 'src/data/auto_cleanup.dart';
import 'src/data/cloud.dart';
import 'src/data/db/account_databases.dart';
import 'src/data/folder_sync_schedule.dart';
import 'src/data/library_location.dart';
import 'src/data/network.dart';
import 'src/data/notifications.dart';
import 'src/data/sentry_scrub.dart';
import 'src/data/share_intake.dart';
import 'src/l10n.dart';
import 'src/native_licenses.dart';
import 'src/providers.dart';
import 'src/ui/account_scope.dart';
import 'src/ui/app_shell.dart';
import 'src/ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerNativeLicenses();
  // La sessione dell'account si ripristina prima del primo fotogramma:
  // altrimenti l'app si crederebbe scollegata per un istante e lo direbbe.
  await initCloud();
  NetworkMonitor.instance.start();
  // Le pagine che i siti vogliono rese (`browser.pages`): la WebView invisibile, dove c'è.
  installPageRenderer(platformPageBrowser());
  ArrivalNotifications.instance.start();
  SharedText.instance.start();
  final directories = await AppDirectories.resolve();
  final databases = AccountDatabases(await getApplicationDocumentsDirectory());
  // Quale file di dati si apre dipende da chi è dentro: la sessione si attende
  // (tetto 5 s) solo se serve a decidere, cioè se la nota dello slot manca.
  final undecided = await databases.readNote() is SlotNoteAbsent;
  final slot = await databases.resolveActive(
    uid: undecided ? (await const CloudAuth().restoredAccount())?.id : null,
    support: Directory(directories.support),
    onUnreadable: (error) => Sentry.captureException(error),
  );
  // Chi è entrato con un account prima di questa correzione ha già lo slot
  // dell'account nella nota: il file di prima lo prende qui, prima di aprirlo.
  try {
    await databases.claimLegacy(slot);
  } catch (error) {
    await Sentry.captureException(error);
  }
  // Lo slot segue l'account voluto: un altro uid lo cambia, una sessione persa
  // no; l'uscita esplicita la chiede `CloudAccountNotifier`.
  final slots = AccountSlots(databases, slot)
    ..follow(
      const CloudAuth().changes().map((account) => account?.id),
      onError: (error) => Sentry.captureException(error),
    );
  await _withSentry(
    () => runApp(
      SentryWidget(
        child: AccountScope(
          slots: slots,
          directories: directories,
          child: const KagamiApp(),
        ),
      ),
    ),
  );
}

// Il progetto Sentry è di chi compila: `--dart-define=SENTRY_DSN=…`. Senza,
// il DSN è vuoto e Sentry resta spento, senza bisogno di un ramo apposta.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> _withSentry(FutureOr<void> Function() appRunner) =>
    SentryFlutter.init((options) {
      options.dsn = _sentryDsn;
      options.environment = kReleaseMode ? 'production' : 'debug';
      options.tracesSampleRate = 0.2;
      // Il progetto è di chi compila: indirizzi, email e id di Drive restano
      // sul telefono (`sentry_scrub.dart`).
      options.beforeSend = scrubEvent;
    }, appRunner: appRunner);

/// Il giro programmato della sincronizzazione con Drive: lo avvia
/// `FolderSyncWorker.kt` in un motore senza schermo, ad app chiusa. Sta qui
/// perché il Kotlin cerca il punto d'ingresso nella libreria principale.
@pragma('vm:entry-point')
Future<void> folderSyncMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Il giro gira ad app chiusa: senza Sentry anche qui un suo errore non lo
  // vedrebbe nessuno.
  await _withSentry(runScheduledFolderSync);
}

/// La pulizia automatica dei capitoli, nel lavoro di `AutoCleanupWorker.kt`:
/// toglie ciò che è scaduto mentre l'app era chiusa.
@pragma('vm:entry-point')
Future<void> autoCleanupMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _withSentry(runScheduledAutoCleanup);
}

/// La coda dei download, nel lavoro in primo piano di `ArchiveWorker.kt`.
@pragma('vm:entry-point')
Future<void> archiveMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _withSentry(() => runBackgroundArchive(check: false));
}

/// Il controllo quotidiano delle serie in corso, e poi la coda.
@pragma('vm:entry-point')
Future<void> archiveCheckMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _withSentry(() => runBackgroundArchive(check: true));
}

const _localeChannel = MethodChannel('kagami/locale');

class KagamiApp extends ConsumerStatefulWidget {
  const KagamiApp({super.key});

  @override
  ConsumerState<KagamiApp> createState() => _KagamiAppState();
}

class _KagamiAppState extends ConsumerState<KagamiApp> {
  @override
  void initState() {
    super.initState();
    _restoreLibraryRoot();
  }

  Future<void> _restoreLibraryRoot() async {
    final location = await ref.read(libraryLocationProvider.future);
    final root = location.root;
    if (root != null && mounted) {
      ref.read(libraryRootProvider.notifier).select(root);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.dark;
    final locale = ref.watch(appLanguageProvider).value;
    appLocale = locale;
    // La lingua arriva anche da un backup o dall'account, non solo dalle
    // impostazioni: la si dice ad Android ogni volta che cambia, per le
    // notifiche scritte dal Kotlin.
    ref.listen(appLanguageProvider, (_, next) {
      if (!Platform.isAndroid || !next.hasValue) return;
      _localeChannel.invokeMethod<void>(
        'set',
        next.value?.toLanguageTag() ?? '',
      );
    });
    return DynamicColorBuilder(
      builder: (light, dark) => MaterialApp(
        title: 'Kagami',
        debugShowCheckedModeBanner: false,
        theme: kagamiTheme(Brightness.light, light?.primary),
        darkTheme: kagamiTheme(Brightness.dark, dark?.primary),
        themeMode: mode,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppShell(),
      ),
    );
  }
}
