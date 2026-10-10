/// Il percorso di «Scarica un manga», a pezzi riusabili: dal link alla serie
/// letta dal sito (con la verifica di Cloudflare, se serve), dalla serie alla
/// pagina in cui si sceglie cosa scaricarne e dove, dalla scelta alla coda
/// del telefono o del server.
///
/// Lo usa `archive_screen.dart`, e chi apre lo stesso percorso da un altro
/// posto — la scheda di una serie, l'import di tanti link — passa da qui,
/// così verifica, permessi e destinazioni restano uguali dappertutto.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/remote.dart';
import 'package:path/path.dart' as p;

import '../data/cloud.dart';
import '../data/drive.dart';
import '../format/malf.dart';
import '../format/reading.dart';
import '../archive/phone_check.dart';
import '../l10n.dart';
import '../providers.dart';
import 'archive_series.dart';
import 'browser_check_page.dart';
import 'drive_ui.dart';

/// La serie letta dal sito, con ciò che serve a scaricarla uguale dopo.
class InspectedSeries {
  const InspectedSeries(this.series, this.metadata, {this.pass, this.linkedChapter});

  final Series series;

  /// I metadati già normalizzati (`normalizeMetadata`), come li vuole la
  /// pagina della serie.
  final Map<String, Object?> metadata;

  /// La verifica di Cloudflare superata nella WebView, se è servita: il
  /// lavoro se ne porta dietro pagina, user agent e cookie.
  final BrowserPass? pass;

  /// Il capitolo del link, se era quello di un capitolo e la serie lo
  /// elenca: è il punto a cui l'utente è arrivato.
  final Chapter? linkedChapter;
}

/// La verifica del browser chiusa prima di arrivare alla pagina della serie.
class ArchiveVerifyIncomplete extends ProviderError {
  ArchiveVerifyIncomplete() : super(currentL10n().archiveErrVerifyIncomplete);
}

/// Il testo da mostrare per un errore di [inspectArchiveLink].
String archiveErrorText(ProviderError error) =>
    error is ProviderOffline ? currentL10n().archiveErrOffline : error.message;

/// Legge dal sito la serie di [url], il link di una serie o di un suo
/// capitolo (`resolveLink`); per un capitolo, la serie è quella a cui
/// appartiene e il capitolo sta in [InspectedSeries.linkedChapter].
///
/// Se il sito risponde con la verifica di Cloudflare e ne ha una
/// (`Provider.browser`), apre [BrowserCheckPage] e rilegge la serie con i
/// cookie e la pagina presi lì. Lancia [ProviderError]: [UnsupportedLink] per
/// un link che nessun sito riconosce, [ProviderOffline] senza rete,
/// [ArchiveVerifyIncomplete] se l'utente chiude la verifica; per il testo da
/// mostrare c'è [archiveErrorText].
///
/// Con [background] la pagina la apre quella WebView invisibile, senza
/// chiedere niente a nessuno: passa se la verifica è già stata superata (i
/// cookie delle WebView sono di tutta l'app) o si risolve da sola, altrimenti
/// lancia [CloudflareChallenge]. È per chi legge tante serie di fila.
Future<InspectedSeries> inspectArchiveLink(
  BuildContext context,
  String url, {
  BrowserFetcher? background,
}) async {
  final link = resolveLink(url);
  final provider = link.provider;
  final seriesUrl = link.seriesUrl;
  var http = SiteHttp(provider.allowedHost);
  try {
    Series series;
    BrowserPass? pass;
    try {
      series = await provider.fetchSeries(seriesUrl, http);
    } on CloudflareChallenge {
      final gate = provider.browser;
      if (gate == null || (background == null && !context.mounted)) rethrow;
      final canonical = provider.canonical(seriesUrl);
      pass = background != null
          ? await background.pass(canonical, gate.hosts)
          : await BrowserCheckPage.open(
              context,
              canonical,
              gate.hosts,
              ready: gate.seriesReady,
            );
      if (pass == null) throw ArchiveVerifyIncomplete();
      final cookies = pass.cookies;
      http.close();
      http = SiteHttp(
        provider.allowedHost,
        userAgent: pass.userAgent,
        cookies: (uri) => cookies[uri.host],
      );
      series = await provider.fetchSeries(seriesUrl, SnapshotHttp(http, canonical, pass.html));
    }
    return InspectedSeries(
      series,
      normalizeMetadata(series.metadata),
      pass: pass,
      linkedChapter: link.chapterUrl == null ? null : chapterOfLink(series, link.chapterUrl!),
    );
  } finally {
    http.close();
  }
}

/// Fa passare all'utente la verifica che ha fermato il controllo di
/// [gated], e fa ripartire il controllo da quelle serie, da chi controlla.
///
/// Per ogni serie la pagina la prova prima la WebView invisibile: i cookie
/// sono di tutta l'app, quindi dopo la prima verifica passata a mano le
/// altre serie dello stesso sito di solito non la chiedono più. Quando la
/// chiede, si apre [BrowserCheckPage]; chiusa senza passarla, ci si ferma
/// lì e si controlla ciò che si è preso. Il telefono controlla da sé
/// ([ArchiveController.checkPages]); il server riceve le pagine
/// (`POST /v2/check/pages`), perché la verifica passata vale solo per
/// questo browser e questo indirizzo. Torna com'è andata, `null` se non si
/// è presa nessuna pagina. [onChecking] dice che le pagine ci sono e il
/// controllo comincia.
Future<({int checked, int queued, int gated})?> passVerification(
  BuildContext context,
  WidgetRef ref,
  List<GatedSeries> gated, {
  VoidCallback? onChecking,
}) async {
  final pages = <String, String>{};
  for (final entry in gated) {
    final Provider provider;
    try {
      provider = selectProvider(entry.url);
    } on ProviderError {
      continue;
    }
    final gate = provider.browser;
    if (gate == null) continue;
    final canonical = provider.canonical(entry.url);
    var html = await const NativePageBrowser().seriesPage(canonical, gate);
    if (html == null) {
      if (!context.mounted) break;
      final pass = await BrowserCheckPage.open(context, canonical, gate.hosts, ready: gate.seriesReady);
      if (pass == null) break;
      html = utf8.decode(pass.html);
    }
    pages[entry.url] = html;
  }
  if (pages.isEmpty) return null;
  onChecking?.call();
  final link = ref.read(serverLinkProvider).value;
  if (ref.read(archiveEngineProvider) == ArchiveEngine.server && link != null) {
    final client = ServerClient(link, ref.read(serverAccessProvider).idToken);
    try {
      final result = await client.checkPages(pages);
      return (checked: result.checked, queued: result.queued, gated: result.gated.length);
    } finally {
      client.close();
    }
  }
  final report = await ref.read(archiveProvider.notifier).checkPages(pages);
  return (checked: report.checked, queued: report.queued.length, gated: report.gated.length);
}

/// Dove può andare una serie adesso: Drive, se la libreria ne ha la
/// cartella, altrimenti il telefono. Se scarica il server
/// ([archiveEngineProvider]) c'è lui per primo, e la pagina della serie
/// offre solo lui: gli altri restano per le schede, che le scrive il
/// telefono.
List<ArchiveWhere> archiveDestinations(WidgetRef ref) {
  // La cartella può arrivare da un backup anche in una build senza
  // Firebase, dove Drive non si può aprire.
  final drive = cloudAvailable && ref.read(driveFolderProvider).value != null;
  return [
    if (ref.read(archiveEngineProvider) == ArchiveEngine.server) ArchiveWhere.server,
    ...drive ? const [ArchiveWhere.drive, ArchiveWhere.driveAndPhone] : const [ArchiveWhere.phone],
  ];
}

/// Cosa fa il server collegato con una serie, per la sua voce fra le
/// destinazioni.
String archiveServerHint(BuildContext context, WidgetRef ref) {
  final info = ref.read(remoteArchiveProvider).info;
  final folder = ref.read(driveFolderProvider).value;
  final other = folder != null && info?.folderId != folder.id;
  return context.l10n.archiveServerHint(
    info?.name ?? '',
    info?.folderName ?? info?.folderId ?? '',
    other ? 'other' : 'same',
  );
}

/// Apre la pagina in cui si sceglie cosa scaricare di [inspected] e dove.
///
/// [where] e [delayMs] sono le ultime scelte, da ricordare fra una serie e
/// l'altra: chi chiama le tiene e le aggiorna con la scelta restituita. Una
/// [where] che oggi non c'è più lascia il posto alla prima destinazione.
///
/// [mode], [start] e [picked] precompilano la pagina; senza [mode] si apre
/// su «Dal capitolo» se il link era di un capitolo, altrimenti su «Tutta».
/// Senza [start] il capitolo di partenza lo propone la pagina, dopo l'ultimo
/// letto. [stateKey] dice da quale serie prendere ciò che la pagina precompila
/// (stato, voto, nota, punto di lettura), se non è quella di [inspected]. Restituisce `null` se l'utente torna indietro senza scegliere.
Future<ArchiveChoice?> chooseArchive(
  BuildContext context,
  WidgetRef ref,
  InspectedSeries inspected, {
  ArchiveWhere? where,
  int delayMs = 200,
  ArchiveMode? mode,
  String? start,
  Set<String> picked = const {},
  String? stateKey,
}) {
  final destinations = archiveDestinations(ref);
  return ArchiveSeriesPage.open(
    context,
    series: inspected.series,
    metadata: inspected.metadata,
    destinations: destinations,
    destination: destinations.contains(where) ? where! : destinations.first,
    delayMs: delayMs,
    serverHint: archiveServerHint(context, ref),
    serverAhead: ref.read(remoteArchiveProvider).info?.ahead ?? false,
    mode: mode ?? (inspected.linkedChapter != null ? ArchiveMode.from : ArchiveMode.all),
    start: start,
    picked: picked,
    linkedChapterId: inspected.linkedChapter?.id,
    stateKey: stateKey,
  );
}

/// Mette in coda [choice] per [inspected]: sul telefono chiede, se servono,
/// la cartella in cui tenere i capitoli e il permesso di scrivere su Drive,
/// e salva la pagina della verifica per il lavoro; al server manda il link
/// con le stesse scelte.
///
/// Una scheda ([ArchiveChoice.card]) va solo al telefono: appena è in coda
/// se ne scrive anche lo stato dell'utente ([saveArchiveCard]), così la
/// serie esiste nei dati personali prima che il lavoro finisca.
///
/// Gli errori li dice da sé con uno snackbar, e così la conferma. `true` se
/// il lavoro è in coda, `false` se l'utente ha rinunciato o è andata male.
Future<bool> enqueueArchive(
  BuildContext context,
  WidgetRef ref,
  InspectedSeries inspected,
  ArchiveChoice choice,
) async {
  final destination = choice.where.local;
  if (destination == null) return _sendToServer(context, ref, inspected, choice);
  final messenger = ScaffoldMessenger.of(context);
  final target = await archiveTargetFor(context, ref, destination);
  if (target == null) return false;
  await queueArchiveJob(ref, inspected, choice, target);
  final l10n = currentL10n();
  // Un lavoro senza capitoli è una scheda anche quando non porta uno stato
  // da scrivere: è l'aggiornamento di una già in libreria.
  final isCard = choice.card != null || (choice.ids?.isEmpty ?? false);
  messenger.showSnackBar(SnackBar(
    content: Text(isCard
        ? l10n.archiveCardQueuedSnack(inspected.series.title)
        : l10n.archiveQueuedSnack(inspected.series.title)),
  ));
  return true;
}

/// Dove scrive un lavoro del telefono verso [destination]: chiede, se
/// servono, la cartella in cui tenere i capitoli e il permesso di scrivere
/// su Drive. `null` se l'utente rinuncia o il permesso non arriva; l'errore
/// lo dice da sé con uno snackbar.
///
/// Chi mette in coda tante serie di fila (l'import di tanti link) lo chiede
/// una volta sola e passa il risultato a [queueArchiveJob].
Future<ArchiveTarget?> archiveTargetFor(
  BuildContext context,
  WidgetRef ref,
  ArchiveDestination destination,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final folder = ref.read(driveFolderProvider).value;
  String? root;
  var private = false;
  if (destination.keepsOnPhone) {
    root = await downloadDestination(context, ref);
    if (root == null) return null;
    private = root == ref.read(appDirectoriesProvider).privateLibrary;
  }
  if (destination.usesDrive) {
    // Caricare vuole il permesso di scrivere su Drive, che l'app chiede
    // solo quando serve.
    try {
      await ref.read(driveAuthProvider).authorize(write: true);
    } on DriveAuthRequired {
      return null;
    } on DriveException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return null;
    }
  }
  return ArchiveTarget(
    destination: destination,
    folderId: destination.usesDrive ? folder?.id : null,
    root: root,
    private: private,
  );
}

/// Mette in coda del telefono [choice] per [inspected] verso [target], in
/// silenzio: salva la pagina della verifica per il lavoro e, per una
/// scheda, ne scrive lo stato dell'utente ([saveArchiveCard]).
Future<void> queueArchiveJob(
  WidgetRef ref,
  InspectedSeries inspected,
  ArchiveChoice choice,
  ArchiveTarget target,
) async {
  final files = ref.read(archiveFilesProvider);
  final id = '${DateTime.now().microsecondsSinceEpoch}';
  String? snapshot;
  final pass = inspected.pass;
  if (pass != null) {
    final file = File(p.join(files.snapshots.path, '$id.html'));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(pass.html);
    snapshot = file.path;
  }
  await ref.read(archiveProvider.notifier).enqueue(ArchiveJob(
        id: id,
        url: inspected.series.url,
        title: inspected.series.title,
        target: target,
        start: choice.start,
        ids: choice.ids,
        delayMs: choice.delayMs,
        snapshot: snapshot,
        userAgent: pass?.userAgent,
        cookies: pass?.cookies ?? const {},
        ahead: choice.ahead,
      ));
  // Chi la riscarica la vuole seguire di nuovo.
  await ref.read(unfollowedProvider.notifier).follow(inspected.series.key);
  final card = choice.card;
  if (card != null) await saveArchiveCard(ref, inspected.series, card);
}

/// Scrive nei dati personali la scheda di [series]: stato, voto, nota,
/// preferito e, con [ArchiveCard.reachedId], i capitoli fino a quello segnati
/// letti come stimati.
Future<void> saveArchiveCard(WidgetRef ref, Series series, ArchiveCard card) async {
  final reading = ref.read(readingProvider.notifier);
  final key = series.key;
  // Prima il punto di lettura, che porta da sé lo stato a «in lettura»:
  // uno stato scelto a mano nella scheda deve restare quello.
  await reading.setReachedThrough(key, chapterEntriesOf(series), card.reachedId);
  await reading.saveCard(
    key,
    status: card.status == ShelfStatus.none ? null : card.status,
    notes: card.notes,
    favorite: card.favorite,
  );
  await reading.setRating(key, card.rating);
}

/// I capitoli del sito come voci d'indice MALF, nessuno archiviato: quelle
/// che vuole `Reading.setReachedThrough` per una serie non ancora in
/// libreria.
List<ChapterEntry> chapterEntriesOf(Series series) => [
      for (final (index, chapter) in series.chapters.indexed)
        ChapterEntry(
          id: chapter.id,
          order: index,
          archived: false,
          complete: false,
          pageCount: 0,
          bytes: 0,
          number: chapter.number.isEmpty ? null : chapter.number,
          title: chapter.title,
        ),
    ];

/// Al server va il link con le stesse scelte; la pagina della serie solo se
/// è servita la verifica del browser, perché il server non ne ha uno.
Future<bool> _sendToServer(
  BuildContext context,
  WidgetRef ref,
  InspectedSeries inspected,
  ArchiveChoice choice,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final name = ref.read(remoteArchiveProvider).info?.name ?? currentL10n().archiveServerFallbackName;
  try {
    await ref.read(remoteArchiveProvider.notifier).enqueue(
          url: inspected.series.url,
          title: inspected.series.title,
          start: choice.start,
          ids: choice.ids,
          delayMs: choice.delayMs,
          ahead: choice.ahead,
          snapshot: inspected.pass == null ? null : utf8.decode(inspected.pass!.html, allowMalformed: true),
        );
  } on ServerException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    return false;
  }
  await ref.read(unfollowedProvider.notifier).follow(inspected.series.key);
  messenger.showSnackBar(SnackBar(
    content: Text(currentL10n().archiveQueuedServerSnack(inspected.series.title, name)),
  ));
  return true;
}

const MethodChannel _links = MethodChannel('kagami/links');

/// Apre [url] nel browser; dove non c'è modo di aprirlo (la build Linux), il
/// link finisce negli appunti.
Future<void> openInBrowser(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (await _links.invokeMethod<bool>('open', url) ?? false) return;
  } on MissingPluginException {
    // Si ripiega sugli appunti.
  }
  await Clipboard.setData(ClipboardData(text: url));
  messenger.showSnackBar(SnackBar(content: Text(currentL10n().archiveLinkCopied(url))));
}
