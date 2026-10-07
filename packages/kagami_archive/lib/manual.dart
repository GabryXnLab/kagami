/// Le schede manuali: serie che nessun sito di Kagami sa leggere, salvate a
/// mano con un titolo, al più un link e una copertina.
///
/// Stanno nella libreria come le altre — `series.json`, indici, riga di
/// libreria — con lo pseudo-provider [manualProvider] e zero capitoli. Non
/// è un `Provider` del registro: da lì non si scarica niente, quindi coda,
/// serie in corso e controllo della libreria le saltano.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;

import 'archiver.dart';
import 'http.dart';
import 'image_tools.dart';
import 'images.dart';
import 'indexes.dart';
import 'model.dart';
import 'names.dart';
import 'stores.dart';

/// Il provider delle schede manuali, nella chiave `manual:<id>`.
const String manualProvider = 'manual';

/// Il link nella forma con cui si confronta: schema e host minuscoli, senza
/// frammento e senza `/` finale, perché la stessa pagina copiata due volte
/// dal browser dia la stessa scheda.
String normalizeLink(String link) {
  final text = link.trim();
  final uri = Uri.tryParse(text);
  var normal = uri == null || !uri.hasScheme
      ? text
      : uri.replace(scheme: uri.scheme.toLowerCase(), host: uri.host.toLowerCase()).removeFragment().toString();
  while (normal.endsWith('/')) {
    normal = normal.substring(0, normal.length - 1);
  }
  return normal;
}

/// L'id di una scheda manuale: dal link, se c'è, così lo stesso link non fa
/// due schede; altrimenti a caso.
String manualSeriesId([String? link]) {
  if (link != null && link.trim().isNotEmpty) {
    return sha256.convert(utf8.encode(normalizeLink(link))).toString().substring(0, 12);
  }
  final random = Random.secure();
  return [for (var i = 0; i < 6; i++) random.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
}

/// La chiave MALF della scheda manuale di [link].
String manualSeriesKey(String link) => '$manualProvider:${manualSeriesId(link)}';

/// Una scheda manuale scritta: la sua chiave, la cartella e la riga di
/// libreria.
typedef ManualSeries = ({String key, String folder, Map<String, Object?> row});

/// Scrive in [store] la scheda manuale [title]: `series.json` con zero
/// capitoli, indici e riga di libreria (su Drive una riga di
/// `library.json`, sul telefono `reading/downloads.json`).
///
/// [id] riscrive una scheda già fatta (serve a quelle senza link, il cui id
/// è a caso); senza, viene da [link]. La copertina è [cover] o, se manca,
/// [coverUrl] scaricata al meglio con [http] (o con un client per quel solo
/// host): una copertina che non arriva non ferma la scheda. Senza nessuna
/// delle due resta quella che la scheda aveva già. [metadata] sono metadati
/// nella forma grezza di un sito (`description`, `authors`, `status`, …).
Future<ManualSeries> writeManualSeries(
  ArchiveStore store, {
  required String title,
  required Directory scratch,
  String? link,
  String? id,
  Uint8List? cover,
  String? coverUrl,
  ProviderHttp? http,
  Map<String, Object?> metadata = const {},
  ImageTools images = const NoImageTools(),
}) async {
  final source = link == null || link.trim().isEmpty ? null : link.trim();
  final series = Series(
    provider: manualProvider,
    id: id ?? manualSeriesId(source),
    title: title,
    url: source ?? '',
    coverUrl: coverUrl,
    metadata: metadata,
    chapters: const [],
  );
  final folder = await store.existingFolder(series) ?? seriesFolderName(series);
  final files = <String, Uint8List>{};
  final body = cover ?? (coverUrl == null ? null : await _download(coverUrl, source, http));
  Object? coverRecord;
  if (body != null) {
    final extension = _extension(body);
    if (extension != null) {
      final size = imageSize(body);
      files['cover$extension'] = body;
      final thumbnail = await _thumbnail(body, scratch, images);
      if (thumbnail != null) files['cover.thumb.webp'] = thumbnail;
      coverRecord = {
        'file': 'cover$extension',
        'source': coverUrl,
        'size': body.length,
        'sha256': sha256.convert(body).toString(),
        'width': size?.$1,
        'height': size?.$2,
        'thumbnail': thumbnail == null ? null : 'cover.thumb.webp',
      };
    }
  }
  coverRecord ??= (await store.readJson(p.posix.join(folder, seriesManifestFile)))?['cover'];
  final manifest = <String, Object?>{
    'schemaVersion': archiveSchemaVersion,
    'metadataSchemaVersion': metadataSchemaVersion,
    'provider': manualProvider,
    'id': series.id,
    'title': title,
    'source': source,
    'fetchedAt': isoNow(),
    'metadata': normalizeMetadata(metadata),
    'cover': coverRecord,
    'chapters': const <Object?>[],
  };
  final built = buildSeriesIndex(manifest, const {})!;
  files[seriesManifestFile] = utf8.encode(prettyJson(manifest));
  files[seriesIndexName] = utf8.encode(prettyJson(built.index));
  files[pagesIndexName] = utf8.encode(prettyJson(built.pages));
  await store.writeSeriesFiles(folder, files);
  final row = summarize(folder, manifest, built.index);
  await store.writeLibraryRow(row);
  return (key: series.key, folder: folder, row: row);
}

String? _extension(Uint8List body) {
  try {
    return imageExtension(body);
  } on ProviderError {
    return null;
  }
}

Future<Uint8List?> _download(String url, String? referer, ProviderHttp? http) async {
  // Le copertine stanno spesso su un CDN, e il sito si presenta come referer.
  final hosts = {Uri.tryParse(url)?.host, if (referer != null) Uri.tryParse(referer)?.host};
  final client = http ?? SiteHttp((uri) => hosts.contains(uri.host), attempts: 2);
  try {
    final result = await client.get(url, limit: 30000000, referer: referer);
    return result.contentType.startsWith('image/') ? result.body : null;
  } on ProviderError {
    return null;
  } finally {
    if (http == null) (client as SiteHttp).close();
  }
}

Future<Uint8List?> _thumbnail(Uint8List cover, Directory scratch, ImageTools images) async {
  await scratch.create(recursive: true);
  final file = File(p.join(scratch.path, 'manual-cover-${DateTime.now().microsecondsSinceEpoch}'));
  await file.writeAsBytes(cover);
  try {
    return await images.thumbnail(file);
  } finally {
    await file.delete().catchError((_) => file);
  }
}

/// Titolo e copertina di una pagina, come li dichiara per le anteprime.
typedef PageMeta = ({String? title, String? image});

/// `og:title` (o, in mancanza, `<title>`) e `og:image` di [page], l'HTML
/// della pagina di [pageUrl]; l'immagine, se relativa, si risolve su [pageUrl].
PageMeta parsePageMeta(String page, String pageUrl) {
  final document = html.parse(page);
  String? property(String name) {
    for (final meta in document.querySelectorAll('meta')) {
      final key = meta.attributes['property'] ?? meta.attributes['name'];
      if (key?.toLowerCase() != name) continue;
      final value = meta.attributes['content']?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  final title = property('og:title') ?? document.querySelector('title')?.text.trim();
  final image = property('og:image');
  final base = Uri.tryParse(pageUrl);
  final resolved = image == null || base == null ? image : base.resolve(image).toString();
  return (
    title: title == null || title.isEmpty ? null : title.replaceAll(RegExp(r'\s+'), ' '),
    image: resolved,
  );
}

/// Legge al meglio la pagina di [link] per precompilare una scheda manuale:
/// un tempo breve, e ogni guasto — rete, HTTP, pagina che non è HTML — dà
/// una risposta vuota, perché la scheda si può compilare a mano.
///
/// Senza [http] usa un client limitato all'host del link, che con un sito
/// non registrato non ha un `Provider` che lo dichiari.
Future<PageMeta> fetchPageMeta(String link, {ProviderHttp? http, Duration timeout = const Duration(seconds: 12)}) async {
  const none = (title: null, image: null);
  final host = Uri.tryParse(link.trim())?.host;
  if (host == null || host.isEmpty) return none;
  final client = http ?? SiteHttp((uri) => uri.host == host, attempts: 1);
  try {
    final result = await client.get(link.trim(), limit: 1500000).timeout(timeout);
    if (!result.contentType.contains('html')) return none;
    return parsePageMeta(utf8.decode(result.body, allowMalformed: true), link.trim());
  } on Object {
    return none;
  } finally {
    if (http == null) (client as SiteHttp).close();
  }
}
