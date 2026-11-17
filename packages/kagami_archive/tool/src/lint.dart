/// Regole di robustezza delle definizioni dei siti (`site.dart lint`, `docs/siti.md`
/// §«Strategie che resistono»). Ogni regola ha un id stabile; un `error` ferma la build del catalogo.
library;

import 'dart:convert';

import 'package:kagami_archive/declarative.dart';

class LintIssue {
  const LintIssue(this.id, this.level, this.field, this.message);

  final String id;

  /// `error` o `warn`.
  final String level;
  final String field;
  final String message;

  bool get isError => level == 'error';

  Map<String, Object> toJson() => {'id': id, 'level': level, 'field': field, 'message': message};

  @override
  String toString() => '$level $id $field: $message';
}

/// [canaries] è il contenuto di `catalog/canaries.json` (`{"sites": {id: {...}}}`); se è null il
/// canarino non si controlla.
List<LintIssue> lintSite(Map def, {Map? canaries}) {
  final issues = <LintIssue>[];
  void add(String id, String level, String field, String message) => issues.add(LintIssue(id, level, field, message));

  // Ciò che l'app rifiuterebbe all'installazione si ferma qui, non dopo la pubblicazione.
  try {
    DeclarativeProvider.parse(jsonEncode(def));
  } on SiteDefinitionError catch (e) {
    add('install', 'error', 'root', e.message);
  }

  final series = def['series'];
  final chapter = def['chapter'];
  final search = def['search'];
  final chapters = series is Map ? series['chapters'] : null;

  // Campi critici con una sola fonte.
  void single(String field, Object? extractor, Object? block) {
    if (extractor == null) return;
    if (_hasAlternatives(extractor) || _hasFallback(block)) return;
    add('single-source', 'warn', field, 'una sola strategia: nessuna alternativa in first e nessun fallback di blocco');
  }

  if (series is Map) single('series.title', series['title'], series);
  if (chapters is Map) single('series.chapters.items', chapters['items'], chapters);
  if (chapter is Map && chapter['pages'] is Map) single('chapter.pages.items', (chapter['pages'] as Map)['items'], chapter);
  if (search is Map) single('search.items', search['items'], search);

  // Selettori fragili e segmenti volatili, ovunque nel file.
  _walk(def, 'root', (path, key, value) {
    if (key == 'css' && value is String) {
      final why = _fragileSelector(value);
      if (why != null) add('fragile-selector', 'warn', path, '«$value»: $why');
    }
    if (value is String) {
      for (final m in RegExp(r'_next/data/([^/?#]*)').allMatches(value)) {
        final seg = m.group(1)!;
        if (!seg.contains('{')) add('volatile-segment', 'error', path, '`_next/data/$seg` è scritto in chiaro: il buildId cambia a ogni pubblicazione, va letto da `__NEXT_DATA__` in una variabile');
      }
      for (final m in RegExp(r'[?&](v|ver|version|cv|build|buildId)=([^&#]*)').allMatches(value)) {
        if (!m.group(2)!.contains('{')) add('volatile-segment', 'error', path, 'il parametro di versione `${m.group(1)}=${m.group(2)}` è fisso: va da una variabile');
      }
    }
    if (key == 'query' && value is Map) {
      for (final e in value.entries) {
        if (_versionKeys.contains(e.key) && e.value is String && !(e.value as String).contains('{')) {
          add('volatile-segment', 'error', '$path.${e.key}', 'il parametro di versione `${e.key}` è fisso ("${e.value}"): va da una variabile');
        }
      }
    }
  });

  // json senza series.link.
  if (series is Map && series['json'] == true && series['link'] == null) {
    add('json-without-link', 'warn', 'series.link', '`json: true` senza `series.link`: il link della serie coinciderebbe con l\'indirizzo dell\'API');
  }

  // Tavole da un'API senza require d'identità.
  void identity(String path, Map block) {
    final fromApi = block['api'] != null || block['json'] == true;
    final req = block['require'];
    if (fromApi && !(req is List && req.isNotEmpty)) {
      add('chapter-identity', 'warn', '$path.require', 'le tavole vengono da un\'API ma manca un `require` sull\'id del capitolo: un\'identità sbagliata passerebbe in silenzio');
    }
  }

  if (chapter is Map) {
    identity('chapter', chapter);
    final fb = chapter['fallback'];
    if (fb is List) {
      for (var i = 0; i < fb.length; i++) {
        if (fb[i] is Map) identity('chapter.fallback[$i]', fb[i] as Map);
      }
    }
  }

  // Canarino.
  if (canaries != null) {
    final sites = canaries['sites'];
    final id = def['id'];
    if (!(sites is Map && sites[id] != null)) {
      add('missing-canary', 'warn', 'id', 'nessun canarino per «$id» in canaries.json');
    }
  }
  return issues;
}

String renderLint(List<LintIssue> issues) =>
    issues.isEmpty ? 'Nessuna segnalazione.\n' : '${issues.map((i) => i.toString()).join('\n')}\n';

String lintJson(List<LintIssue> issues) => '${const JsonEncoder.withIndent('  ').convert([for (final i in issues) i.toJson()])}\n';

const _versionKeys = {'v', 'ver', 'version', 'cv', 'build', 'buildId'};

bool _hasFallback(Object? block) => block is Map && block['fallback'] is List && (block['fallback'] as List).isNotEmpty;

bool _hasAlternatives(Object? e) => e is Map && e['first'] is List && (e['first'] as List).length >= 2;

void _walk(Object? node, String path, void Function(String path, String key, Object? value) visit) {
  if (node is Map) {
    for (final e in node.entries) {
      final p = path == 'root' ? '${e.key}' : '$path.${e.key}';
      visit(p, '${e.key}', e.value);
      _walk(e.value, p, visit);
    }
  } else if (node is List) {
    for (var i = 0; i < node.length; i++) {
      _walk(node[i], '$path[$i]', visit);
    }
  }
}

String? _fragileSelector(String css) {
  if (RegExp(r'\.css-[a-z0-9]{4,}', caseSensitive: false).hasMatch(css)) return 'classe con hash (css-…)';
  if (RegExp(r'\.sc-[A-Za-z0-9]{4,}').hasMatch(css)) return 'classe con hash (sc-…)';
  if (RegExp(r'\.[A-Za-z0-9-]+_[A-Za-z0-9-]+__[A-Za-z0-9_-]{4,}').hasMatch(css)) return 'classe di CSS module con hash';
  if (RegExp(r':nth-(child|of-type)\(').allMatches(css).length >= 2) return 'nth-child profondi';
  return null;
}
