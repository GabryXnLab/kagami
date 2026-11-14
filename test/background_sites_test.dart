// Il giro ad app chiusa gira in un isolate senza l'app: i siti degli utenti li
// installa lui, dalla libreria che usa.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/archive/background.dart';
import 'package:kagami/src/data/site_replacements.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/runner.dart';
import 'package:kagami_archive/stores.dart';

import 'user_sites_test.dart' show siteJson;

void main() {
  late Directory dir;
  late Directory library;
  late ArchiveFiles files;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('background_sites_');
    library = Directory('${dir.path}/library')..createSync();
    files = ArchiveFiles('${dir.path}/support');
    installUserProviders(const []);
  });

  tearDown(() {
    installUserProviders(const []);
    dir.deleteSync(recursive: true);
  });

  ArchiveEnvironment environment({bool failing = false}) => ArchiveEnvironment(
        scratch: Directory('${dir.path}/scratch'),
        storeFor: (target) => failing ? throw const FileSystemException('non si apre') : LocalStore(target.root!),
      );

  void writeSite(String id) {
    File('${library.path}/providers/$id.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(siteJson(id)));
  }

  test('installa i siti della libreria del giro: le loro serie hanno chi le lavora', () async {
    writeSite('examplescans');
    await files.writeScope(CheckScope(localRoot: library.path));
    expect(providerById('examplescans'), isNull);

    await installUserSitesForRun(files, environment());

    final site = providerById('examplescans');
    expect(site, isNotNull);
    expect(site!.builtIn, isFalse);
    expect(providers.any((provider) => provider.id == 'examplescans'), isTrue);
  });

  test('una lettura fallita non ferma il giro e lascia gli inclusi', () async {
    writeSite('examplescans');
    await files.writeScope(CheckScope(localRoot: library.path));

    await installUserSitesForRun(files, environment(failing: true));

    expect(providerById('examplescans'), isNull);
    expect(providers, isNotEmpty);
  });

  test('senza libreria non installa nulla', () async {
    await installUserSitesForRun(files, environment());
    expect(providers.every((provider) => provider.builtIn), isTrue);
  });

  test('il giro ad app chiusa non sostituisce un sito incluso senza conferma (T10)', () async {
    writeSite('coffeemanga');
    await files.writeScope(CheckScope(localRoot: library.path));

    await installUserSitesForRun(files, environment());
    expect(providerById('coffeemanga')!.builtIn, isTrue);

    final site = DeclarativeProvider.fromJson(siteJson('coffeemanga'));
    await SiteReplacements(File('${files.directory.path}/site-replacements.json')).confirm(site);
    await installUserSitesForRun(files, environment());
    expect(providerById('coffeemanga')!.builtIn, isFalse);
  });
}
