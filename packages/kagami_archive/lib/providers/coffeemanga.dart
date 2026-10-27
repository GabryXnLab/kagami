/// Coffee Manga: WordPress con il tema Madara rifatto, senza Cloudflare.
///
/// La pagina della serie non elenca i capitoli nell'HTML: li disegna uno
/// script da `mk-chapters-data`, un JSON con l'elenco intero (id, numero,
/// link e se è riservato ai VIP). Le tavole stanno nella pagina del
/// capitolo, con larghezza e altezza negli attributi.
///
/// L'identità della serie è l'id del post e non lo slug: il sito ne ha di
/// casuali (`/manga/ocveobera7alg81/`) accanto a quelli leggibili.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import '../http.dart';
import '../model.dart';
import '../providers.dart';
import 'kit.dart';

const Set<String> _siteHosts = {'coffeemanga.net', 'www.coffeemanga.net'};

final RegExp _seriesPath = RegExp(r'^/manga/([a-z0-9]+(?:-[a-z0-9]+)*)/?$');
final RegExp _chapterPath =
    RegExp(r'^/manga/([a-z0-9]+(?:-[a-z0-9]+)*)/([a-z0-9]+(?:-[a-z0-9]+)*)/?$');
final RegExp _decimal = RegExp(r'^\d+$');
final RegExp _number = RegExp(r'^\d+(?:\.\d+)?$');

/// Le righe di «Information», per nome.
const Map<String, String> _labels = {
  'status': 'status',
  'alternative': 'alternativeTitles',
  'author': 'authors',
  'authors': 'authors',
  'artist': 'artists',
  'artists': 'artists',
  'type': 'type',
  'release': 'publishedAt',
  'released': 'publishedAt',
};

String _text(dom.Element? element) =>
    (element?.text ?? '').split(RegExp(r'\s+')).where((part) => part.isNotEmpty).join(' ');

dom.Document _page(Uint8List body) => html.parse(utf8.decode(body, allowMalformed: true));

class CoffeeManga extends Provider {
  @override
  String get id => 'coffeemanga';

  @override
  String get name => 'Coffee Manga';

  @override
  String get home => 'https://coffeemanga.net';

  @override
  bool accepts(String url) => siteLink(url, hosts: _siteHosts, path: _seriesPath, plain: true);

  @override
  String? seriesOfChapter(String url) {
    final found = siteMatch(url, hosts: _siteHosts, path: _chapterPath);
    return found == null ? null : '$home/manga/${found[1]}/';
  }

  @override
  bool allowedHost(Uri uri) => _siteHosts.contains(uri.host);

  @override
  String canonical(String url) => '$home/manga/${_seriesPath.firstMatch(Uri.parse(url).path)![1]}/';

  @override
  Future<Series> fetchSeries(String url, ProviderHttp http) async {
    if (!accepts(url)) throw const ProviderError('Inserisci il link di una serie Coffee Manga.');
    final canonicalUrl = canonical(url);
    final document = _page((await http.get(canonicalUrl)).body);
    final data = document.getElementById('mk-chapters-data');
    final Map<String, Object?> listing;
    try {
      listing = jsonDecode(data?.text ?? '') as Map<String, Object?>;
    } on Object {
      throw const ProviderError('Serie Coffee Manga non trovata.');
    }
    final mangaId = listing['mangaId'];
    final raw = listing['items'];
    if (mangaId is! int || raw is! List) throw const ProviderError('Formato della pagina Coffee Manga cambiato.');
    final title = _text(document.querySelector('h1.htitle'));
    if (title.isEmpty) throw const ProviderError('Titolo Coffee Manga assente dalla pagina.');

    final prefix = Uri.parse(canonicalUrl).path;
    final chapters = <Chapter>[];
    for (final item in raw) {
      if (item is! Map<String, Object?> ||
          item['id'] is! int ||
          !isText(item['name']) ||
          !isText(item['url'])) {
        throw const ProviderError('Capitolo Coffee Manga incompleto.');
      }
      final chapterUrl = item['url'] as String;
      final target = siteMatch(chapterUrl, hosts: _siteHosts, path: _chapterPath);
      if (target == null || !Uri.parse(chapterUrl).path.startsWith(prefix)) {
        throw const ProviderError('Elenco capitoli Coffee Manga incoerente.');
      }
      // Un capitolo VIP non ha tavole per chi non paga: resta fuori finché
      // non si libera, e allora arriva come capitolo nuovo.
      if (item['st'] == 'locked') continue;
      final name = item['name'] as String;
      final number = item['num'];
      chapters.add(Chapter(
        '${item['id']}',
        name,
        number is String && _number.hasMatch(number) ? number : chapterNumber(name) ?? name,
        chapterUrl,
        withoutKeys(item, const {'ago', 'rd', 'rg', 'nw', 'lk'}),
      ));
    }
    if (chapters.isEmpty) throw const ProviderError('Nessun capitolo Coffee Manga disponibile.');
    final expected = int.tryParse(_text(document.querySelector('.mk-chapters .stitle .cnt')));
    if (expected != null && raw.length < expected) {
      throw ProviderError('Elenco incompleto: ${raw.length} capitoli su $expected.');
    }
    requireUniqueIds(chapters, 'Coffee Manga');

    final cover = document.querySelector('.hposter img')?.attributes['src'] ??
        document.querySelector('meta[property="og:image"]')?.attributes['content'];
    if (isText(cover)) validateUrl(cover!);
    return Series(
      provider: id,
      id: '$mangaId',
      title: title,
      url: canonicalUrl,
      coverUrl: isText(cover) ? cover : null,
      metadata: _metadata(document),
      // Il sito elenca dal più recente; `oldestFirst` lo riconosce dai
      // numeri, e regge anche se un giorno li desse nell'altro verso.
      chapters: oldestFirst(chapters.reversed.toList()),
    );
  }

  Map<String, Object?> _metadata(dom.Document document) {
    final metadata = <String, Object?>{
      'genres': [for (final chip in document.querySelectorAll('.hchips--genres a.chip')) _text(chip)],
      'tags': [for (final chip in document.querySelectorAll('.hchips--tags a.chip')) _text(chip)],
    };
    final synopsis = document.getElementById('syn');
    if (synopsis != null) metadata['description'] = htmlText(synopsis.innerHtml);
    for (final row in document.querySelectorAll('#sinfoGrid .sir')) {
      final label = _text(row.querySelector('.l')).toLowerCase().replaceAll(RegExp(r'\(s\)$'), '');
      final key = _labels[label];
      final value = _text(row.querySelector('.v'));
      if (key == null || value.isEmpty) continue;
      metadata[key] = switch (key) {
        // «Shard of Time / 시간이 머문 집»: i titoli li separa la barra con
        // gli spazi, che «1/24 Romance» non ha.
        'alternativeTitles' => value.split(' / '),
        'authors' || 'artists' => value.split(RegExp(r'\s*,\s*')),
        _ => value,
      };
    }
    final rating = _text(document.querySelector('.ratecard .rc-num'));
    if (rating.isNotEmpty) metadata['rating'] = rating;
    return metadata;
  }

  /// La pagina dei risultati della barra di ricerca del sito, con gli stessi
  /// parametri del suo modulo.
  @override
  Future<List<SearchResult>> search(String query, ProviderHttp http) async {
    final document = _page((await http.get(Uri.https('coffeemanga.net', '/', {
      's': query.trim(),
      'post_type': 'wp-manga',
    }).toString()))
        .body);
    final results = <SearchResult>[];
    for (final card in document.querySelectorAll('a.acard')) {
      final href = card.attributes['href'] ?? '';
      final title = (card.attributes['title'] ?? _text(card.querySelector('.ac-t'))).trim();
      if (!accepts(href) || title.isEmpty) continue;
      final cover = card.querySelector('img.ac-cover')?.attributes['src'];
      results.add(SearchResult(
        provider: id,
        title: title,
        url: canonical(href),
        coverUrl: isText(cover) && allows(cover!) ? cover : null,
        latestChapter: latestChapterNumber([for (final node in card.querySelectorAll('.ac-ch')) _text(node)]),
        releaseStatus: releaseStatus(_text(card.querySelector('.ac-status'))),
      ));
      if (results.length == searchLimit) break;
    }
    return results;
  }

  @override
  Future<ChapterContent> fetchPages(Chapter chapter, ProviderHttp http) async {
    final document = _page((await http.get(chapter.url)).body);
    final current = document.getElementById('wp-manga-current-chap')?.attributes['data-id'];
    if (current == null || !_decimal.hasMatch(current) || current != chapter.id) {
      throw ProviderError('Capitolo non corrispondente: ${chapter.title}.');
    }
    final pages = <Page>[];
    for (final image in document.querySelectorAll('.reading-content img.wp-manga-chapter-img')) {
      // Le prime tavole hanno `src`, le altre aspettano il caricamento pigro
      // in `data-src`.
      final url = (image.attributes['data-src'] ?? image.attributes['src'] ?? '').trim();
      if (url.isEmpty) throw ProviderError('Pagina non coerente: ${chapter.title}.');
      validateUrl(url);
      pages.add(Page(
        url,
        int.tryParse(image.attributes['width'] ?? ''),
        int.tryParse(image.attributes['height'] ?? ''),
      ));
    }
    if (pages.isEmpty) {
      if (document.querySelector('.wp-manga-chapter-permissions-msg') != null) {
        throw ProviderError('Capitolo riservato ai VIP di Coffee Manga: ${chapter.title}.');
      }
      throw ProviderError('Elenco immagini incompleto: ${chapter.title}.');
    }
    return ChapterContent(pages, const {});
  }
}
