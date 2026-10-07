/// «Importa più link»: tanti link in una volta — le schede del browser, un
/// elenco, il JSON di un'automazione — e per ognuno una scheda, senza aprire
/// la pagina della serie né chiedere niente link per link.
///
/// Le righe e la strada di ognuna le decide `archive/bulk_import.dart`; qui
/// c'è il giro, una serie alla volta con una pausa fra l'una e l'altra per
/// rispetto dei siti. Una serie di un sito diventa una scheda in coda come
/// quella di «Solo la scheda» (`queueArchiveJob`), un sito sconosciuto una
/// scheda manuale (`saveManualCard`). Destinazione e permessi si chiedono una
/// volta sola, all'inizio.
///
/// I siti dietro Cloudflare si leggono da una WebView invisibile, che usa i
/// cookie di una verifica già superata: se la verifica chiede un tocco, la
/// riga aspetta, e superata su una riga le altre dello stesso sito ripartono.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/manual.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

import '../archive/bulk_import.dart';
import '../archive/device.dart';
import '../archive/manual_card.dart';
import '../format/reading.dart';
import '../l10n.dart';
import '../providers.dart';
import 'archive_flow.dart';
import 'archive_manual.dart';
import 'archive_series.dart';
import 'browser_check_page.dart';
import 'theme.dart';
import 'widgets/collection_sheet.dart' show askForCollection;
import 'widgets/kit.dart';

enum _State { waiting, running, saved, manual, known, failed, check }

class _Row {
  _Row(this.item);

  final ImportItem item;
  _State state = _State.waiting;

  /// Il titolo della serie, quando lo si sa.
  String? title;

  /// Il capitolo raggiunto, il titolo in libreria o il motivo dell'errore.
  String? detail;

  bool get done => switch (state) {
        _State.waiting || _State.running || _State.check => false,
        _ => true,
      };
}

const List<int> _pauses = [0, 2, 5, 10];

class ArchiveImportPage extends ConsumerStatefulWidget {
  const ArchiveImportPage({this.text, super.key});

  /// Il testo con cui si apre, già incollato: quello condiviso con l'app.
  final String? text;

  static Future<void> open(BuildContext context, {String? text}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ArchiveImportPage(text: text)));

  @override
  ConsumerState<ArchiveImportPage> createState() => _ArchiveImportPageState();
}

class _ArchiveImportPageState extends ConsumerState<ArchiveImportPage> {
  late final TextEditingController _text = TextEditingController(text: widget.text ?? '');
  late List<ImportItem> _items = parseImportText(_text.text);

  /// Le righe, da quando l'import è partito.
  List<_Row>? _rows;
  String? _collection;
  int _pause = 2;
  bool _running = false;
  bool _stopping = false;

  /// Il giro in corso, da aspettare prima di uscire: una riga a metà deve
  /// finire di scrivere coda e dati personali.
  Future<void>? _loop;
  bool _savedAny = false;

  ArchiveTarget? _siteTarget;
  ManualTarget? _manualTarget;

  /// Le serie scritte in questo import: la libreria non si rilegge a ogni
  /// riga, e due capitoli della stessa serie non devono farne due schede.
  final Set<String> _keys = {};

  /// Una WebView invisibile per ogni sito dietro una verifica del browser:
  /// deve stare nell'albero prima di caricare.
  final Map<String, BrowserFetcher> _fetchers = {
    if (BrowserFetcher.available)
      for (final provider in providers)
        if (provider.browser case final gate?) provider.id: BrowserFetcher(ready: gate.seriesReady),
  };

  @override
  void dispose() {
    _stopping = true;
    _manualTarget?.close();
    _text.dispose();
    super.dispose();
  }

  void _parse() => setState(() => _items = parseImportText(_text.text));

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _text.text = text;
    _parse();
  }

  ArchiveWhere get _where => manualWhere(ref) == ManualWhere.drive ? ArchiveWhere.drive : ArchiveWhere.phone;

  Future<void> _start() async {
    FocusScope.of(context).unfocus();
    final site = await archiveTargetFor(context, ref, _where.local!);
    if (site == null || !mounted) return;
    final manual = await openManualTarget(context, ref);
    if (manual == null || !mounted) {
      manual?.close();
      return;
    }
    _siteTarget = site;
    _manualTarget = manual;
    setState(() => _rows = [for (final item in _items) _Row(item)]);
    await _run();
  }

  /// Una riga alla volta finché ce n'è in attesa o finché non si ferma.
  /// Dopo una riga che ha parlato con un sito si aspetta [_pause]; una già
  /// presente non ha chiesto niente a nessuno, e la seguente parte subito.
  Future<void> _run() => _loop ??= _turn().whenComplete(() => _loop = null);

  Future<void> _turn() async {
    setState(() {
      _running = true;
      _stopping = false;
    });
    var rest = false;
    try {
      while (!_stopping) {
        final row = _rows!.where((row) => row.state == _State.waiting).firstOrNull;
        if (row == null) break;
        if (rest) {
          for (var waited = 0; waited < _pause * 4 && !_stopping; waited++) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }
          if (_stopping) break;
        }
        setState(() => row.state = _State.running);
        await _import(row);
        if (!mounted) return;
        setState(() {});
        rest = row.state != _State.known;
      }
    } finally {
      if (mounted) {
        setState(() => _running = false);
        if (_savedAny) reloadLibrary(ref);
      }
    }
  }

  Future<void> _import(_Row row) async {
    ImportRoute? route;
    try {
      final catalog = await ref.read(libraryCatalogProvider.future);
      final queued = {for (final job in ref.read(archiveProvider).jobs) normalizeLink(job.url)};
      route = routeImport(row.item, catalog.index, queued: queued);
      switch (route) {
        case ImportKnown(:final title):
          row
            ..state = _State.known
            ..title = title
            ..detail = title;
        case ImportSite(:final link):
          final provider = link.provider;
          final background = _fetchers[provider.id];
          // Senza WebView invisibile un sito protetto aprirebbe la verifica a
          // schermo: la si lascia alla fine, chiesta dall'utente.
          if (provider.needsBrowser && background == null) {
            row.state = _State.check;
            return;
          }
          if (!mounted) return;
          final inspected = await inspectArchiveLink(context, row.item.url, background: background);
          final known = entryForKey(catalog.index, inspected.series.key);
          if (known != null || _keys.contains(inspected.series.key)) {
            row
              ..state = _State.known
              ..title = known?.title ?? inspected.series.title
              ..detail = row.title;
            return;
          }
          await _saveSite(row, inspected);
        case ImportManual():
          await _saveManual(row);
      }
    } on CloudflareChallenge catch (error) {
      if (route is ImportSite && route.link.provider.needsBrowser) {
        row.state = _State.check;
      } else {
        _fail(row, error);
      }
    } on Object catch (error) {
      _fail(row, error);
    }
  }

  void _fail(_Row row, Object error) {
    row
      ..state = _State.failed
      ..detail = error is ProviderError ? archiveErrorText(error) : manualErrorText(error);
  }

  /// La scheda di una serie di un sito: in coda senza capitoli, e nei dati
  /// personali lo stato del JSON e, da un link di capitolo o dal capitolo
  /// dichiarato, il punto a cui si è arrivati.
  Future<void> _saveSite(_Row row, InspectedSeries inspected) async {
    final series = inspected.series;
    final item = row.item;
    final reached = reachedChapterIndex(
      series.chapters,
      linkedId: inspected.linkedChapter?.id,
      reachedNumber: item.chapter,
    );
    final chapter = reached >= 0 ? series.chapters[reached] : null;
    await queueArchiveJob(
      ref,
      inspected,
      ArchiveChoice.card(
        where: _where,
        card: ArchiveCard(
          status: item.status ?? ShelfStatus.none,
          rating: item.rating,
          notes: item.notes ?? '',
          reachedId: chapter?.id,
        ),
      ),
      _siteTarget!,
    );
    await _saved(series.key);
    row
      ..state = _State.saved
      ..title = series.title
      ..detail = chapter == null ? null : (chapter.number.isEmpty ? chapter.title : chapter.number);
  }

  /// Titolo e copertina dalla pagina, al meglio: il JSON ha la precedenza
  /// sul titolo, e senza nessuno dei due resta host e percorso.
  Future<void> _saveManual(_Row row) async {
    final item = row.item;
    final meta = await fetchPageMeta(item.url);
    final title = item.title ?? meta.title ?? fallbackTitle(item.url);
    final written = await saveManualCard(
      _manualTarget!.store,
      ref.read(readingProvider.notifier),
      ManualCard(
        title: title,
        link: item.url,
        coverUrl: meta.image,
        reached: item.chapter,
        status: item.manualStatus,
        rating: item.rating,
        notes: item.notes ?? '',
      ),
      scratch: Directory(p.join(ref.read(appDirectoriesProvider).cache, 'archive')),
      images: NativeImageTools.platform,
    );
    await _saved(written.key);
    row
      ..state = _State.manual
      ..title = title;
  }

  Future<void> _saved(String key) async {
    _keys.add(key);
    _savedAny = true;
    final collection = _collection;
    if (collection != null && ref.read(collectionsProvider).any((row) => row.id == collection)) {
      await ref.read(readingProvider.notifier).setSeriesInCollection(collection, key, true);
    }
  }

  void _retry(_Row row) {
    setState(() => row.state = _State.waiting);
    unawaited(_run());
  }

  /// La verifica a schermo per una riga; superata, i cookie valgono per
  /// tutte le WebView dell'app, e le altre righe dello stesso sito tornano in
  /// fila per la WebView invisibile.
  Future<void> _verify(_Row row) async {
    setState(() => row.state = _State.running);
    final provider = resolveLink(row.item.url).provider;
    try {
      final inspected = await inspectArchiveLink(context, row.item.url);
      final catalog = await ref.read(libraryCatalogProvider.future);
      final known = entryForKey(catalog.index, inspected.series.key);
      if (known != null || _keys.contains(inspected.series.key)) {
        row
          ..state = _State.known
          ..title = known?.title ?? inspected.series.title
          ..detail = row.title;
      } else {
        await _saveSite(row, inspected);
      }
      for (final other in _rows!) {
        if (other.state == _State.check && resolveLink(other.item.url).provider.id == provider.id) {
          other.state = _State.waiting;
        }
      }
    } on ArchiveVerifyIncomplete {
      row.state = _State.check;
    } on Object catch (error) {
      _fail(row, error);
    }
    if (!mounted) return;
    setState(() {});
    unawaited(_run());
  }

  Future<void> _chooseCollection() async {
    final l10n = context.l10n;
    final chosen = await showKagamiSheet<(String?,)>(
      context,
      title: l10n.archiveImportCollection,
      scrollable: true,
      action: Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () async {
            final before = {for (final row in ref.read(collectionsProvider)) row.id};
            await askForCollection(context, ref);
            final created = ref.read(collectionsProvider).where((row) => !before.contains(row.id)).firstOrNull;
            if (created != null && context.mounted) Navigator.of(context).pop((created.id,));
          },
          child: Text(l10n.collectionSheetNew),
        ),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
          children: [
            KTile(
              icon: LucideIcons.circleSlash,
              title: l10n.archiveImportCollectionNone,
              trailing: _collection == null ? const Icon(LucideIcons.check, size: 18) : null,
              onTap: () => Navigator.of(context).pop((null,)),
            ),
            for (final collection in ref.watch(collectionsProvider))
              KTile(
                icon: LucideIcons.bookmark,
                tint: collection.color == null ? null : Color(collection.color!),
                title: collection.name,
                trailing: _collection == collection.id ? const Icon(LucideIcons.check, size: 18) : null,
                onTap: () => Navigator.of(context).pop((collection.id,)),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) setState(() => _collection = chosen.$1);
  }

  Future<bool> _confirmLeave() async {
    final l10n = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.archiveImportLeaveTitle),
        content: Text(l10n.archiveImportLeaveBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.archiveCancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.archiveImportLeaveConfirm)),
        ],
      ),
    );
    return sure ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = _rows;
    return PopScope(
      canPop: !_running,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !await _confirmLeave() || !context.mounted) return;
        setState(() => _stopping = true);
        await _loop;
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.archiveImportTitle)),
        body: Stack(
          children: [
            for (final fetcher in _fetchers.values) Positioned.fill(child: fetcher.view()),
            ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: rows == null ? _setup() : _progress(rows),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _setup() {
    final l10n = context.l10n;
    final muted = context.tokens.muted;
    final collection = ref.watch(collectionsProvider).where((row) => row.id == _collection).firstOrNull;
    return [
      Text(l10n.archiveImportIntro, style: KagamiType.body(13, height: 1.5, color: muted)),
      const SizedBox(height: 16),
      TextField(
        controller: _text,
        minLines: 5,
        maxLines: 10,
        keyboardType: TextInputType.multiline,
        onChanged: (_) => _parse(),
        decoration: InputDecoration(
          hintText: l10n.archiveImportHint,
          suffixIcon: IconButton(
            tooltip: l10n.archivePaste,
            icon: const Icon(LucideIcons.clipboardPaste, size: 18),
            onPressed: _paste,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(l10n.archiveImportFound(_items.length), style: KagamiType.body(12.5, color: muted)),
      const SizedBox(height: 20),
      KGroup(
        children: [
          KTile(
            icon: LucideIcons.listPlus,
            title: l10n.archiveImportCollection,
            subtitle: collection?.name ?? l10n.archiveImportCollectionNone,
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: _chooseCollection,
          ),
        ],
      ),
      const SizedBox(height: 18),
      Text(l10n.archiveImportPause, style: KagamiType.title(14, color: context.colors.onSurface)),
      const SizedBox(height: 8),
      KSegmented(
        options: [for (final seconds in _pauses) l10n.archiveImportSeconds(seconds)],
        index: _pauses.indexOf(_pause),
        onChanged: (index) => setState(() => _pause = _pauses[index]),
      ),
      const SizedBox(height: 6),
      Text(l10n.archiveImportPauseHint, style: KagamiType.body(12.5, height: 1.4, color: muted)),
      const SizedBox(height: 16),
      Text(
        _where == ArchiveWhere.drive ? l10n.archiveImportWhereDrive : l10n.archiveImportWherePhone,
        style: KagamiType.body(12.5, height: 1.4, color: muted),
      ),
      const SizedBox(height: 12),
      KButton(
        label: l10n.archiveImportStart(_items.length),
        icon: LucideIcons.bookmarkPlus,
        expand: true,
        onPressed: _items.isEmpty ? null : _start,
      ),
    ];
  }

  List<Widget> _progress(List<_Row> rows) {
    final l10n = context.l10n;
    final muted = context.tokens.muted;
    int count(_State state) => rows.where((row) => row.state == state).length;
    final done = rows.where((row) => row.done).length;
    final checks = count(_State.check);
    final waiting = count(_State.waiting);
    final counters = [
      if (count(_State.saved) case final n when n > 0) l10n.archiveImportCountSaved(n),
      if (count(_State.manual) case final n when n > 0) l10n.archiveImportCountManual(n),
      if (count(_State.known) case final n when n > 0) l10n.archiveImportCountKnown(n),
      if (count(_State.failed) case final n when n > 0) l10n.archiveImportCountFailed(n),
      if (checks > 0) l10n.archiveImportCountCheck(checks),
    ];
    return [
      Text(
        l10n.archiveImportProgress(done, rows.length),
        style: KagamiType.title(15, color: context.colors.onSurface),
      ),
      const SizedBox(height: 8),
      KProgress(value: rows.isEmpty ? 0 : done / rows.length),
      if (counters.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(counters.join(' · '), style: KagamiType.body(12.5, color: muted)),
      ],
      const SizedBox(height: 14),
      if (_running)
        KGhostButton(
          label: l10n.archiveImportStop,
          icon: LucideIcons.squareStop,
          expand: true,
          onPressed: _stopping ? null : () => setState(() => _stopping = true),
        )
      else if (waiting > 0)
        KButton(
          label: l10n.archiveImportResume,
          icon: LucideIcons.play,
          expand: true,
          onPressed: _run,
        ),
      if (checks > 0) ...[
        const SizedBox(height: 12),
        Text(l10n.archiveImportCheckHint, style: KagamiType.body(12.5, height: 1.45, color: context.tokens.warning)),
      ],
      const SizedBox(height: 16),
      KGroup(children: [for (final row in rows) _tile(row)]),
    ];
  }

  Widget _tile(_Row row) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final (icon, tint, subtitle) = switch (row.state) {
      _State.waiting => (LucideIcons.clock, null, l10n.archiveImportWaiting),
      _State.running => (LucideIcons.loaderCircle, null, l10n.archiveImportRunning),
      _State.saved => (
          LucideIcons.bookmarkCheck,
          tokens.success,
          row.detail == null ? l10n.archiveImportSaved : l10n.archiveImportSavedReached(row.detail!),
        ),
      _State.manual => (LucideIcons.bookmarkPlus, tokens.success, l10n.archiveImportManual),
      _State.known => (
          LucideIcons.bookCheck,
          null,
          row.detail == null ? l10n.archiveImportQueued : l10n.archiveImportKnown(row.detail!),
        ),
      _State.failed => (LucideIcons.triangleAlert, tokens.danger, row.detail ?? ''),
      _State.check => (LucideIcons.shieldCheck, tokens.warning, l10n.archiveImportNeedsCheck),
    };
    final Widget? trailing = switch (row.state) {
      _State.running => const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      _State.failed => TextButton(onPressed: () => _retry(row), child: Text(l10n.archiveImportRetry)),
      _State.check => TextButton(onPressed: () => _verify(row), child: Text(l10n.archiveImportVerify)),
      _ => null,
    };
    return KTile(
      icon: icon,
      tint: tint,
      title: row.title ?? row.item.title ?? row.item.url,
      subtitle: subtitle,
      trailing: trailing,
    );
  }
}
