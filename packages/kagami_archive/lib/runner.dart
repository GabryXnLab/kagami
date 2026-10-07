/// Il giro della coda e il controllo delle serie in corso.
///
/// Girano tutt'e due nel lavoro in primo piano (`ArchiveWorker.kt`): un
/// download di una serie intera sono ore e migliaia di richieste, e l'app in
/// secondo piano il sistema la congela. L'app mette in coda e guarda.
library;

import 'dart:async';
import 'dart:io';

import 'archiver.dart';
import 'drive.dart';
import 'http.dart';
import 'image_tools.dart';
import 'jobs.dart';
import 'model.dart';
import 'providers.dart';
import 'stores.dart';
import 'tracking.dart';

/// Cosa serve a un giro oltre ai file della coda: dove scrivere e come
/// parlare coi siti. Un'interfaccia perché i test li facciano in memoria.
class ArchiveEnvironment {
  const ArchiveEnvironment({
    required this.storeFor,
    required this.scratch,
    this.images = const NoImageTools(),
    this.httpFor = _siteHttp,
  });

  final ArchiveStore Function(ArchiveTarget target) storeFor;
  final Directory scratch;
  final ImageTools images;
  final ProviderHttp Function(Provider provider, {String? userAgent, Map<String, String> cookies}) httpFor;

  static ProviderHttp _siteHttp(Provider provider, {String? userAgent, Map<String, String> cookies = const {}}) =>
      SiteHttp(
        provider.allowedHost,
        userAgent: userAgent ?? defaultUserAgent,
        cookies: cookies.isEmpty ? null : (uri) => cookies[uri.host],
      );
}

/// Cosa fare dopo un giro.
enum RunEnd {
  /// La coda è vuota.
  done,

  /// Manca la rete, o Drive: il giro si riprende quando torna.
  retry,

  /// Fermato da chi lo ha avviato o dal sistema.
  stopped,
}

class ArchiveRunner {
  ArchiveRunner(this.files, this.environment, {this.cancelled, this.onStatus, this.onError});

  final ArchiveFiles files;
  final ArchiveEnvironment environment;
  final bool Function()? cancelled;

  /// Un guasto del codice, non del sito: nell'app va a Sentry.
  final Future<void> Function(Object error, StackTrace stack)? onError;

  /// A ogni cambiamento dell'avanzamento: la notifica del lavoro.
  final void Function(ArchiveStatus status)? onStatus;

  ArchiveStatus _status = const ArchiveStatus();
  DateTime _written = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _publish(ArchiveStatus status, {bool now = false}) async {
    _status = status;
    onStatus?.call(status);
    final at = DateTime.now();
    // L'avanzamento si scrive al più un paio di volte al secondo: una
    // tavola sono pochi millisecondi, e l'app lo rilegge a quel ritmo.
    if (!now && at.difference(_written) < const Duration(milliseconds: 400)) return;
    _written = at;
    final snapshot = _status;
    await (_writing = _writing.then((_) => files.writeStatus(snapshot)));
  }

  /// Le scritture dello stato una dopo l'altra, nell'ordine in cui arrivano.
  Future<void> _writing = Future.value();

  void _onEvent(ArchiveEvent event) {
    final status = switch (event) {
      SeriesStarted(:final title, :final total) => _status.copyWith(title: title, total: total),
      ChapterStarted(:final index, :final total, :final title) =>
        _status.copyWith(message: '$title ($index/$total)'),
      ChapterUploading(:final title, :final files) =>
        _status.copyWith(message: '$title: caricamento su Drive di $files file…'),
      ChapterFinished(:final title, :final error) => _status.copyWith(
          done: _status.done + 1,
          failed: _status.failed + (error == null ? 0 : 1),
          message: error == null ? null : 'Errore in $title: $error',
        ),
      PageSaved(:final saved, :final size) => _status.copyWith(
          pagesDownloaded: _status.pagesDownloaded + (saved ? 1 : 0),
          pagesSkipped: _status.pagesSkipped + (saved ? 0 : 1),
          bytes: _status.bytes + size,
        ),
    };
    unawaited(_publish(status, now: event is ChapterFinished || event is ChapterUploading));
  }

  Future<RunEnd> run() async {
    try {
      while (true) {
        if (cancelled?.call() ?? false) return RunEnd.stopped;
        final job = await files.next();
        if (job == null) return RunEnd.done;
        final end = await _one(job);
        if (end != null) return end;
      }
    } finally {
      await _publish(
        _status.state == ArchiveState.running ? _status.copyWith(state: ArchiveState.idle) : _status,
        now: true,
      );
    }
  }

  /// Un lavoro della coda. `null` vuol dire «avanti col prossimo».
  Future<RunEnd?> _one(ArchiveJob job) async {
    _status = ArchiveStatus(
      state: ArchiveState.running,
      jobId: job.id,
      title: job.title,
      message: 'Lettura della serie…',
    );
    await _publish(_status, now: true);
    ProviderHttp? http;
    try {
      final provider = selectProvider(job.url);
      http = environment.httpFor(provider, userAgent: job.userAgent, cookies: job.cookies);
      var reader = http;
      final snapshot = job.snapshot;
      if (snapshot != null && provider.needsBrowser) {
        reader = SnapshotHttp(http, provider.canonical(job.url), await File(snapshot).readAsBytes());
      }
      final series = await provider.fetchSeries(job.url, reader);
      final store = environment.storeFor(job.target);
      final result = await Archiver(
        provider: provider,
        http: reader,
        store: store,
        scratch: environment.scratch,
        images: environment.images,
        delay: Duration(milliseconds: job.delayMs),
        onEvent: _onEvent,
        cancelled: cancelled,
      ).download(series, ids: job.ids, start: job.start);
      await Tracking(files.ongoing).record(
        series,
        job.target,
        settled: result.settled,
        metadata: result.metadata,
        ahead: job.ahead,
        card: job.cardOnly,
      );
      await _finish(job, ArchiveOutcome(
        title: series.title,
        ok: result.failed.isEmpty,
        message: _message(job, result),
        finishedAt: DateTime.now(),
        seriesKey: series.key,
        url: job.url,
        card: job.cardOnly,
      ));
      return null;
    } on ArchiveCancelled {
      await _publish(_status.copyWith(state: ArchiveState.idle, message: 'Interrotto'), now: true);
      return RunEnd.stopped;
    } on ProviderOffline {
      return _wait('In attesa della rete');
    } on DriveOffline {
      return _wait('In attesa della rete');
    } on CloudflareChallenge {
      await _finish(job, _failure(job, 'Il sito chiede di nuovo la verifica: apri il link '
          'da «Scarica un manga» e ripeti.'));
    } on DriveAuthRequired {
      await _finish(job, _failure(job, 'Serve il permesso di scrivere su Drive: '
          'aprilo da «Scarica un manga».'));
    } on ProviderError catch (error) {
      await _finish(job, _failure(job, '$error'));
    } on DriveException catch (error) {
      await _finish(job, _failure(job, '$error'));
    } on FileSystemException catch (error) {
      await _finish(job, _failure(job, error.message));
    } on Object catch (error, stack) {
      // Un guasto dell'app, non del sito: lo si dice e lo si segnala, e la
      // coda va avanti invece di fermarsi su quel lavoro.
      await onError?.call(error, stack);
      await _finish(job, _failure(job, 'Download interrotto da un errore dell\'app.'));
    } finally {
      if (http is SiteHttp) http.close();
    }
    return null;
  }

  Future<RunEnd> _wait(String message) async {
    await _publish(_status.copyWith(state: ArchiveState.waiting, message: message), now: true);
    return RunEnd.retry;
  }

  ArchiveOutcome _failure(ArchiveJob job, String message) => ArchiveOutcome(
        title: _status.title.isNotEmpty ? _status.title : job.title,
        ok: false,
        message: message,
        finishedAt: DateTime.now(),
        url: job.url,
        card: job.cardOnly,
      );

  Future<void> _finish(ArchiveJob job, ArchiveOutcome outcome) async {
    await files.remove(job.id);
    await files.remember(outcome);
    await _publish(_status.copyWith(message: outcome.message), now: true);
  }

  static String _message(ArchiveJob job, ArchiveResult result) {
    if (result.failed.isNotEmpty) {
      final failure = result.failed.first;
      final more = result.failed.length > 1 ? ' (e altri ${result.failed.length - 1})' : '';
      return '${failure.chapter}: ${failure.error}$more. Ripeti il download per ritentare.';
    }
    if (job.cardOnly) {
      final count = result.series.chapters.length;
      return count == 1
          ? 'Scheda salvata: 1 capitolo in elenco, non scaricato.'
          : 'Scheda salvata: $count capitoli in elenco, nessuno scaricato.';
    }
    if (job.start != null) {
      return 'Archiviati ${result.completed} capitoli dal capitolo scelto in poi; '
          'i precedenti restano in elenco, senza tavole.';
    }
    if (job.ids != null) {
      return result.completed == 1 ? 'Archiviato 1 capitolo.' : 'Archiviati ${result.completed} capitoli.';
    }
    return 'Serie archiviata completamente.';
  }
}
