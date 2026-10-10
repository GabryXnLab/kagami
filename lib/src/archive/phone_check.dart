/// Il controllo delle serie seguite fatto dal telefono: lo stesso ad app
/// chiusa (`background.dart`) e a mano dalla schermata.
library;

import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/model.dart' show ProviderError;
import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/remote.dart';
import 'package:kagami_archive/runner.dart';
import 'package:kagami_archive/tracking.dart';

import '../data/server_access.dart';
import '../l10n.dart';

/// Le serie che segue il telefono e, delle altre serie in corso della
/// libreria, tutte quelle che l'utente non ha smesso di seguire: come fa il
/// server quando controlla lui. La libreria è quella di Drive, se ce n'è la
/// cartella, altrimenti quella della cartella scelta. Niente, se le serie le
/// controlla il server ([CheckScope.toServer]). Con [only] solo quelle
/// serie: le ferme alla verifica, appena passata a mano.
Future<CheckReport> checkFromPhone(
  ArchiveFiles files,
  ArchiveEnvironment environment, {
  PageBrowser? browser,
  Set<String>? only,
  bool Function()? cancelled,
}) async {
  final report = CheckReport();
  final scope = await files.scope();
  if (scope.toServer) return report;
  ProviderHttp httpFor(Provider provider) => environment.httpFor(provider);
  final tracking = Tracking(files.ongoing);
  report.absorb(await tracking.check(
    files,
    httpFor,
    browser: browser,
    cancelled: cancelled,
    only: only,
    skip: scope.unfollowed,
  ));
  final drive = scope.driveFolder;
  final local = scope.localRoot;
  final target = drive != null
      ? ArchiveTarget(destination: ArchiveDestination.drive, folderId: drive)
      : local != null
          ? ArchiveTarget(destination: ArchiveDestination.phone, root: local)
          : null;
  if (target != null && !(cancelled?.call() ?? false)) {
    report.absorb(await checkLibrary(
      files: files,
      store: environment.storeFor(target),
      target: target,
      httpFor: httpFor,
      browser: browser,
      skip: {for (final entry in await tracking.load()) entry.key, ...scope.unfollowed},
      only: only,
      cancelled: cancelled,
    ));
  }
  await files.recordGated(report.gated, only: only);
  return report;
}

/// Una WebView invisibile e grande quanto lo schermo, dal Kotlin
/// (`PageBrowser.kt`): c'è anche ad app chiusa, dove una WebView di Flutter
/// non si può aprire. I cookie sono quelli di tutte le WebView dell'app, quindi
/// una verifica superata a mano vale anche qui finché Cloudflare la tiene.
class NativePageBrowser implements PageBrowser {
  const NativePageBrowser();

  static const MethodChannel _channel = MethodChannel('kagami/page-browser');

  @override
  Future<String?> seriesPage(String url, BrowserGate gate) async {
    try {
      return await _channel.invokeMethod<String>('seriesPage', {
        'url': url,
        'ready': gate.seriesReady,
        'timeoutMs': 45000,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

/// I siti di [gated], per nome, come li si scrive in un avviso.
String gatedSites(List<GatedSeries> gated) => {
      for (final entry in gated)
        (() {
          try {
            return selectProvider(entry.url).name;
          } on ProviderError {
            return Uri.tryParse(entry.url)?.host ?? entry.url;
          }
        })(),
    }.join(', ');

/// Il titolo e il testo della notifica delle serie ferme alla verifica.
({String title, String text}) gatedNotice(List<GatedSeries> gated) {
  final l10n = currentL10n();
  return (title: l10n.dataVerifyTitle(gatedSites(gated)), text: l10n.dataVerifyText(gated.length));
}

/// Le serie che il server di [url] ha trovato ferme alla verifica, chieste
/// ad app chiusa: il motore senza schermo non ha ancora acceso Firebase, e
/// il token dell'account passa da lì. Senza risposta, nessuna.
Future<List<GatedSeries>> gatedOnServer(String url) async {
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  } on Exception {
    return const [];
  }
  final client = ServerClient(ServerLink(Uri.parse(url)), const ServerAccess().idToken);
  try {
    final info = await client.info();
    return info.verify ? info.check.gated : const [];
  } on ServerException {
    return const [];
  } on IOException {
    return const [];
  } finally {
    client.close();
  }
}
