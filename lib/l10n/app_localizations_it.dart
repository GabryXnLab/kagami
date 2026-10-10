// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get settingsLanguage => 'Lingua';

  @override
  String get settingsLanguageSystem => 'Come il sistema';

  @override
  String get seriesShelfNone => 'Nessuno stato';

  @override
  String get seriesShelfPlanned => 'Da leggere';

  @override
  String get seriesShelfReading => 'In lettura';

  @override
  String get seriesShelfPaused => 'In pausa';

  @override
  String get seriesShelfCompleted => 'Finito';

  @override
  String get seriesShelfDropped => 'Abbandonato';

  @override
  String get seriesReleaseOngoing => 'In corso';

  @override
  String get seriesReleaseCompleted => 'Conclusa';

  @override
  String get seriesReleaseHiatus => 'In pausa';

  @override
  String get seriesReleaseCancelled => 'Interrotta';

  @override
  String get seriesReleaseUnknown => 'Stato ignoto';

  @override
  String get seriesNotFound => 'Serie non trovata.';

  @override
  String get seriesOfflineTitle => 'Capitoli su Drive';

  @override
  String get seriesOfflineMessage =>
      'Senza connessione non si vede l\'elenco dei capitoli di questa serie. Compare da solo appena torna la rete.';

  @override
  String get seriesNoIndexTitle => 'Nessun indice';

  @override
  String get seriesNoIndexMessage =>
      'Questa serie non ha un index.json: vanno rigenerati gli indici con l\'archiviatore che l\'ha scritta.';

  @override
  String get seriesNoChaptersTitle => 'Nessun capitolo';

  @override
  String get seriesNoChaptersMessage =>
      'Nessuno passa la ricerca e i filtri scelti.';

  @override
  String seriesDownloadAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Scaricare $count capitoli?',
      one: 'Scaricare un capitolo?',
    );
    return '$_temp0';
  }

  @override
  String get seriesDownloadAllMessage =>
      'Tutti i capitoli che ora si leggono da Drive finiscono sul telefono, e da lì si leggono anche senza rete.';

  @override
  String get seriesDownload => 'Scarica';

  @override
  String seriesCleanupRemote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli letti sono ancora su Drive',
      one: 'Un capitolo letto è ancora su Drive',
    );
    return '$_temp0';
  }

  @override
  String seriesCleanupLocal(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli letti occupano $size',
      one: 'Un capitolo letto occupa $size',
    );
    return '$_temp0';
  }

  @override
  String seriesDownloadFailed(String error) {
    return 'Download non riuscito: $error. Riprova';
  }

  @override
  String get seriesDownloadWaiting =>
      'In attesa della rete: riparte da solo. Annulla';

  @override
  String get seriesDownloadQueued => 'In coda. Annulla';

  @override
  String get seriesDownloadCancel => 'Annulla il download';

  @override
  String get seriesPlaceLocal => 'Sul telefono';

  @override
  String get seriesPlaceDrive => 'Su Drive';

  @override
  String get seriesPlaceMixed => 'Telefono e Drive';

  @override
  String get seriesMuteTooltipOn => 'Notifiche dei capitoli nuovi silenziate';

  @override
  String get seriesMuteTooltipOff => 'Notifiche dei capitoli nuovi attive';

  @override
  String get seriesMuteUnmuted => 'Notifiche dei capitoli nuovi riattivate.';

  @override
  String get seriesMuteMuted => 'Notifiche dei capitoli nuovi silenziate.';

  @override
  String seriesCaughtUpMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'In pari con quello che c\'è sul telefono: mancano $count capitoli annunciati.',
      one: 'In pari con quello che c\'è sul telefono: manca un capitolo annunciato.',
    );
    return '$_temp0';
  }

  @override
  String get seriesCaughtUpAll => 'Letta tutta.';

  @override
  String get seriesResumeToContinue => 'DA CONTINUARE';

  @override
  String get seriesResumeToStart => 'DA INIZIARE';

  @override
  String get seriesResumeHalfway => 'LASCIATO A METÀ';

  @override
  String seriesResumePage(int page, int total) {
    return 'pagina $page di $total';
  }

  @override
  String get seriesContinue => 'Continua';

  @override
  String get seriesStart => 'Inizia';

  @override
  String get seriesResume => 'Riprendi';

  @override
  String get seriesNextChapter => 'Capitolo successivo';

  @override
  String get seriesFigureChapters => 'Capitoli';

  @override
  String get seriesFigureRead => 'Letti';

  @override
  String get seriesFigureProgress => 'Avanzamento';

  @override
  String get seriesFigureRating => 'Voto';

  @override
  String get seriesMyShelf => 'Il mio scaffale';

  @override
  String get seriesFavoriteOn => 'Preferita';

  @override
  String get seriesFavoriteOff => 'Preferiti';

  @override
  String get seriesRatingButton => 'Voto';

  @override
  String seriesRatingOutOfTen(int rating) {
    return '$rating/10';
  }

  @override
  String get seriesCollections => 'Raccolte';

  @override
  String get seriesNotes => 'Note';

  @override
  String get seriesRatingSheetTitle => 'Che voto le dai?';

  @override
  String get seriesNotesHint => 'Dove eri rimasto, cosa ne pensi…';

  @override
  String get seriesSave => 'Salva';

  @override
  String get seriesRatingWord1 => 'Pessimo';

  @override
  String get seriesRatingWord2 => 'Brutto';

  @override
  String get seriesRatingWord3 => 'Scarso';

  @override
  String get seriesRatingWord4 => 'Mediocre';

  @override
  String get seriesRatingWord5 => 'Sufficiente';

  @override
  String get seriesRatingWord6 => 'Discreto';

  @override
  String get seriesRatingWord7 => 'Buono';

  @override
  String get seriesRatingWord8 => 'Ottimo';

  @override
  String get seriesRatingWord9 => 'Eccellente';

  @override
  String get seriesRatingWord10 => 'Capolavoro';

  @override
  String get seriesRatingNone => 'Senza voto';

  @override
  String get seriesRatingHint => 'Tocca o scorri';

  @override
  String seriesRatingBefore(int rating) {
    return 'Prima: $rating';
  }

  @override
  String get seriesRatingRemove => 'Togli';

  @override
  String get seriesRatingSave => 'Salva il voto';

  @override
  String get seriesSynopsis => 'Sinossi';

  @override
  String get seriesGenres => 'Generi';

  @override
  String get seriesTags => 'Tag';

  @override
  String get seriesCreators => 'Chi l\'ha fatta';

  @override
  String seriesMoreTags(int count) {
    return 'Altri $count';
  }

  @override
  String get seriesPaceToRead => 'Da leggere';

  @override
  String seriesPaceCaption(int chapters, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      chapters,
      locale: localeName,
      other: '$chapters capitoli',
      one: 'un capitolo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages tavole',
      one: 'una tavola',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get seriesPaceNext => 'Prossimo capitolo';

  @override
  String get seriesPaceNextCaption => 'dalla cadenza degli ultimi';

  @override
  String seriesDurationMinutes(int count) {
    return '$count min';
  }

  @override
  String seriesDurationHours(int count) {
    return '$count h';
  }

  @override
  String seriesDurationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni',
      one: '1 giorno',
    );
    return '$_temp0';
  }

  @override
  String get seriesWhenLate => 'in ritardo';

  @override
  String get seriesWhenExpected => 'atteso';

  @override
  String get seriesWhenToday => 'oggi';

  @override
  String get seriesWhenTomorrow => 'domani';

  @override
  String seriesWhenInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fra $count giorni',
      one: 'fra 1 giorno',
    );
    return '$_temp0';
  }

  @override
  String seriesWhenInWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fra $count settimane',
      one: 'fra 1 settimana',
    );
    return '$_temp0';
  }

  @override
  String get seriesShowLess => 'Riduci';

  @override
  String get seriesShowMore => 'Leggi tutto';

  @override
  String get seriesChaptersTitle => 'Capitoli';

  @override
  String seriesChaptersOf(int total) {
    return 'su $total';
  }

  @override
  String get seriesSearchChapter => 'Cerca capitolo…';

  @override
  String get seriesSortNewest => 'Dal più recente';

  @override
  String get seriesSortOldest => 'Dal primo';

  @override
  String get seriesMarkAll => 'Segna tutti';

  @override
  String get seriesDownloadFromDrive => 'Scarica da Drive';

  @override
  String get seriesFreeSpace => 'Libera spazio';

  @override
  String get seriesFilterUnread => 'Da leggere';

  @override
  String get seriesFilterDownloaded => 'Scaricati';

  @override
  String get seriesFilterAll => 'Tutti';

  @override
  String seriesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selezionati',
      one: '1 selezionato',
    );
    return '$_temp0';
  }

  @override
  String get seriesMarkReadMany => 'Segna letti';

  @override
  String get seriesMarkUnread => 'Segna da leggere';

  @override
  String get seriesMarkRead => 'Segna letto';

  @override
  String get seriesMarkReadThrough => 'Segna letto fino a qui';

  @override
  String get seriesSimilar => 'Altre così';

  @override
  String get seriesChapterNotDownloaded => 'Non scaricato';

  @override
  String seriesChapterPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tavole',
      one: '1 tavola',
    );
    return '$_temp0';
  }

  @override
  String get seriesDownloadToPhone => 'Scarica sul telefono';

  @override
  String get readerSeriesUnavailable => 'Serie non disponibile.';

  @override
  String get readerNoPagesIndex =>
      'Questa serie non ha un pages.json: vanno rigenerati gli indici con l\'archiviatore che l\'ha scritta.';

  @override
  String get readerSeriesOffline =>
      'Senza connessione non si può aprire questa serie: l\'elenco delle sue tavole è su Drive. Si apre appena torna la rete.';

  @override
  String get readerChapterNotOnPhone =>
      'Questo capitolo non è ancora sul telefono. La sincronizzazione può essere a metà: riprovare più tardi.';

  @override
  String get readerChapterNoPages => 'Il capitolo non ha pagine leggibili.';

  @override
  String get readerPagesNotOnPhone =>
      'Le tavole di questo capitolo non sono ancora sul telefono. L\'indice le annuncia, i file no: è la cartella sincronizzata a doverli portare.';

  @override
  String get readerMarkEarlierTitle => 'Segnare letti i precedenti?';

  @override
  String readerMarkEarlierBody(int count, String chapter) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Hai finito $chapter. I $count capitoli precedenti risultano ancora da leggere: se li hai già letti altrove, segnali letti tutti insieme.',
      one:
          'Hai finito $chapter. Il capitolo precedente risulta ancora da leggere: se l\'hai già letto altrove, segnalo letto.',
    );
    return '$_temp0';
  }

  @override
  String readerMarkEarlierConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Segna letti tutti i $count',
      one: 'Segna letto il precedente',
    );
    return '$_temp0';
  }

  @override
  String get readerMarkEarlierDecline => 'Lasciali da leggere';

  @override
  String readerBookmarkAdded(int page) {
    return 'Pagina $page messa da parte';
  }

  @override
  String get readerChapters => 'Capitoli';

  @override
  String get readerBookmarks => 'Pagine messe da parte';

  @override
  String get readerNoBookmarks => 'Nessuna pagina da parte';

  @override
  String get readerNoBookmarksHint =>
      'Il segnalibro tiene il punto di una tavola; quello del capitolo lo tiene già la ripresa.';

  @override
  String readerBookmarkPage(int page) {
    return 'pagina $page';
  }

  @override
  String get readerBookmarkRemove => 'Togli';

  @override
  String get readerToTop => 'Torna in cima';

  @override
  String get readerPageNotFromDrive => 'Tavola non arrivata da Drive';

  @override
  String get readerPageUnreadable => 'Tavola illeggibile';

  @override
  String get readerPageNotSynced => 'Tavola non sincronizzata';

  @override
  String get readerPageNotDownloaded => 'Tavola non ancora scaricata';

  @override
  String get readerPageOfflineHint =>
      'Senza connessione. Arriva da sola appena torna la rete.';

  @override
  String get readerRetryNow => 'Riprova ora';

  @override
  String get readerLastChapterOnPhone =>
      'È l\'ultimo capitolo che c\'è sul telefono.';

  @override
  String get readerNextChapter => 'Capitolo seguente';

  @override
  String get readerContinue => 'Continua';

  @override
  String get readerBookmarkThisPage => 'Metti da parte questa pagina';

  @override
  String get readerHowToRead => 'Come si legge';

  @override
  String get readerPreviousChapter => 'Capitolo precedente';

  @override
  String get readerNextChapterTooltip => 'Capitolo successivo';

  @override
  String get readerSearchChapter => 'Cerca capitolo…';

  @override
  String get readerNewestFirst => 'Dal più recente';

  @override
  String get readerOldestFirst => 'Dal primo';

  @override
  String readerReadingNow(String current, int total) {
    return 'In lettura: $current / $total capitoli';
  }

  @override
  String get readerMode => 'Modalità di lettura';

  @override
  String get readerModeStrip => 'Striscia';

  @override
  String get readerModePage => 'Pagina';

  @override
  String get readerDirection => 'Verso di lettura';

  @override
  String get readerDirectionLtr => 'Sinistra → destra';

  @override
  String get readerDirectionRtl => 'Destra → sinistra';

  @override
  String get readerFit => 'Adattamento';

  @override
  String get readerBackground => 'Sfondo';

  @override
  String get readerBrightness => 'Luminosità';

  @override
  String get readerAutoScroll => 'Scorrimento automatico';

  @override
  String get readerAutoScrollOff => 'spento';

  @override
  String readerAutoScrollRate(int rate) {
    return '$rate tavole/min';
  }

  @override
  String get readerShowPageNumber => 'Numero di pagina';

  @override
  String get readerShowProgress => 'Barra di avanzamento';

  @override
  String get readerShowScrollTop => 'Pulsante per tornare in cima';

  @override
  String get readerKeepAwake => 'Tieni acceso lo schermo';

  @override
  String get readerDoublePage => 'Due tavole affiancate';

  @override
  String get readerLockRotation => 'Blocca la rotazione';

  @override
  String get archiveTitle => 'Scarica un manga';

  @override
  String get archiveIntro =>
      'Cerca un titolo sui siti supportati, o incolla il link di una serie o di un suo capitolo: Kagami la scarica dal sito, con metadati, copertina e l\'elenco completo dei capitoli, nella libreria. O ne salva solo la scheda, senza capitoli.';

  @override
  String get archiveSearchHint => 'Cerca un manga per titolo';

  @override
  String get archiveFilterOngoing => 'In corso';

  @override
  String get archiveFilterCompleted => 'Concluse';

  @override
  String get archiveFilterNotInLibrary => 'Non in libreria';

  @override
  String get archiveInLibrary => 'In libreria';

  @override
  String archiveResultsFiltered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count risultati, nascosti dai filtri',
      one: '1 risultato, nascosto dai filtri',
    );
    return '$_temp0';
  }

  @override
  String get archiveClear => 'Cancella';

  @override
  String get archivePaste => 'Incolla';

  @override
  String get archiveReading => 'Lettura della serie…';

  @override
  String get archiveVerify => 'Verifica serie';

  @override
  String archiveSeriesSummary(String site, int count, String status) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli',
      one: '1 capitolo',
    );
    return '$site · $_temp0 · $status';
  }

  @override
  String get archiveWhatSection => 'Cosa scaricare';

  @override
  String get archiveModeAll => 'Tutta';

  @override
  String get archiveModeFrom => 'Dal capitolo';

  @override
  String get archiveModePick => 'Scelti';

  @override
  String get archiveModeAllHint =>
      'Tutti i capitoli. Rifarlo più avanti porta solo quelli nuovi o rovinati.';

  @override
  String get archiveModeFromHint =>
      'Dal capitolo scelto in poi: i precedenti restano nell\'elenco della serie, segnati come non scaricati.';

  @override
  String get archiveModePickHint =>
      'Solo i capitoli toccati. Gli altri restano nell\'elenco, non scaricati.';

  @override
  String get archiveChooseTitle => 'Cosa scaricare';

  @override
  String get archiveModeAhead => 'Man mano';

  @override
  String get archiveModeAllLine => 'Ogni capitolo, una volta sola';

  @override
  String archiveModeAheadLine(int count) {
    return '$count pronti, poi uno per ogni capitolo letto';
  }

  @override
  String get archiveModeFromLine => 'Da un capitolo fino all\'ultimo';

  @override
  String get archiveModePickLine => 'Solo quelli che tocchi';

  @override
  String archiveModeAheadHint(int count) {
    return 'Dal capitolo scelto ne scarica $count. Ogni capitolo letto ne porta uno nuovo, così ne hai sempre $count da leggere, fino alla fine della serie; quando il sito ne pubblica altri arrivano allo stesso modo.';
  }

  @override
  String get archiveModeAheadUnavailable =>
      'Man mano non si può con questo sito: vuole la verifica del browser a ogni lettura, e da solo il telefono non la supera.';

  @override
  String get archiveModeAheadServer =>
      'Il server collegato non sa ancora scaricare man mano: si aggiorna da solo entro un\'ora dall\'uscita di una versione nuova.';

  @override
  String get archiveChapterSearch => 'Cerca per numero o titolo';

  @override
  String get archiveNewestFirst => 'Dal più recente';

  @override
  String get archiveOldestFirst => 'Dal primo';

  @override
  String get archiveChooseStart => 'Tocca il capitolo da cui partire.';

  @override
  String get archiveSelectMissing => 'Quelli che mancano';

  @override
  String get archiveRangeHint =>
      'Tieni premuto un capitolo per prendere anche tutti quelli fra lui e l\'ultimo toccato.';

  @override
  String get archivePickNone => 'Nessun capitolo scelto';

  @override
  String archiveSummaryChapters(int count, String where) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli',
      one: '1 capitolo',
    );
    return '$_temp0 · $where';
  }

  @override
  String archiveSummaryAhead(int count, String where) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli subito',
      one: '1 capitolo subito',
    );
    return '$_temp0, poi uno per ogni capitolo letto · $where';
  }

  @override
  String archiveDownloadAhead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Scarica $count capitoli e poi man mano',
      one: 'Scarica 1 capitolo e poi man mano',
    );
    return '$_temp0';
  }

  @override
  String archiveInLibraryCount(int archived, int total) {
    return 'In libreria: $archived di $total';
  }

  @override
  String get archiveChapterInLibrary => 'in libreria';

  @override
  String get archiveChapterStart => 'si parte da qui';

  @override
  String get archiveChapterLater => 'arriverà leggendo';

  @override
  String get archiveAdvanced => 'Avanzate';

  @override
  String archiveAdvancedLine(String pause) {
    return 'Pausa fra le richieste: $pause';
  }

  @override
  String get archiveReopen => 'Scegli cosa scaricare';

  @override
  String get archiveSelectAll => 'Tutti';

  @override
  String get archiveSelectNone => 'Nessuno';

  @override
  String get archiveWhereSection => 'Dove';

  @override
  String get archiveWhereServer => 'Server';

  @override
  String get archiveWhereDrive => 'Drive';

  @override
  String get archiveWhereDriveAndPhone => 'Drive e telefono';

  @override
  String get archiveWherePhone => 'Telefono';

  @override
  String get archiveWhereDriveHint =>
      'Nella cartella di Drive della libreria. Le tavole passano dal telefono e se ne vanno appena Drive le ha: si leggono in streaming, o si scaricano dopo.';

  @override
  String get archiveWhereDriveAndPhoneHint =>
      'Nella cartella di Drive della libreria, e i capitoli restano anche sul telefono per leggerli senza rete.';

  @override
  String get archiveWherePhoneHint =>
      'Sul telefono, nella cartella dei manga o nello spazio dell\'app. Collegando Drive si può scaricare direttamente là.';

  @override
  String archiveServerHint(String name, String folder, String other) {
    String _temp0 = intl.Intl.selectLogic(other, {
      'other': ' Attenzione: non è la cartella che legge l\'app.',
      'same': '',
    });
    return 'Lo scarica «$name» e lo carica in «$folder» su Drive, anche a telefono spento. Le serie in corso le segue il server.$_temp0';
  }

  @override
  String get archiveDelaySection => 'Pausa fra le richieste';

  @override
  String get archiveDelayNone => 'Niente';

  @override
  String archiveDelaySeconds(String seconds) {
    return '$seconds s';
  }

  @override
  String get archiveDelayHint =>
      'I siti non amano chi scarica a raffica: una pausa breve evita di farsi bloccare.';

  @override
  String get archiveDownloadAll => 'Scarica tutta la serie';

  @override
  String archiveDownloadPicked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Scarica $count capitoli',
      one: 'Scarica 1 capitolo',
    );
    return '$_temp0';
  }

  @override
  String archiveNoResults(String site) {
    return 'Nessun risultato su $site.';
  }

  @override
  String archiveChaptersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli',
      one: '1 capitolo',
    );
    return '$_temp0';
  }

  @override
  String archiveVerifySite(String site) {
    return 'Verifica $site';
  }

  @override
  String get archiveVerifySiteHint =>
      'Il sito vuole sapere che sei una persona: toccando si apre la verifica, poi si cerca anche lì';

  @override
  String get archiveStatusOngoing => 'in corso';

  @override
  String get archiveStatusCompleted => 'conclusa';

  @override
  String get archiveStatusHiatus => 'in pausa';

  @override
  String get archiveStatusCancelled => 'interrotta';

  @override
  String get archiveStatusUnknown => 'stato ignoto';

  @override
  String get archiveErrChallenge =>
      'Il sito chiede una verifica che da qui non si può fare.';

  @override
  String get archiveErrOffline => 'Nessuna connessione: il sito non risponde.';

  @override
  String get archiveErrVerifyIncomplete =>
      'La verifica del sito non è stata completata.';

  @override
  String archiveQueuedSnack(String title) {
    return '«$title» è in coda. Continua anche a schermo spento.';
  }

  @override
  String archiveQueuedServerSnack(String title, String server) {
    return '«$title» è in coda su «$server». Il telefono può anche spegnersi.';
  }

  @override
  String get archiveServerFallbackName => 'server';

  @override
  String get archiveDownloads => 'Download';

  @override
  String get archiveClearHistory => 'Pulisci';

  @override
  String get archiveQueueStopped => 'Coda ferma';

  @override
  String get archiveQueueResumeHint =>
      'Riparte da sola; toccando la fai partire adesso';

  @override
  String archiveJobAutomatic(String destination) {
    return 'Capitoli nuovi · $destination';
  }

  @override
  String archiveJobQueued(String destination) {
    return 'In coda · $destination';
  }

  @override
  String get archiveRemoveFromQueue => 'Togli dalla coda';

  @override
  String archiveHistoryLine(String when, String message) {
    return '$when · $message';
  }

  @override
  String get archiveRecent => 'Scaricate di recente';

  @override
  String archiveRecentAll(int count) {
    return 'Tutte ($count)';
  }

  @override
  String get archiveRecentFailed => 'Non riuscito';

  @override
  String get archiveFollowedTitle => 'Serie seguite';

  @override
  String archiveFollowedProblems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count da sistemare',
      one: '1 da sistemare',
    );
    return '$_temp0';
  }

  @override
  String archiveRecentLineRuns(String when, int runs, String message) {
    return '$when · $runs download · $message';
  }

  @override
  String get archiveRetry => 'Riprova';

  @override
  String archiveJobAhead(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli',
      one: '1 capitolo',
    );
    return 'Man mano: $_temp0 · $destination';
  }

  @override
  String get archiveSites => 'Siti supportati';

  @override
  String get archiveMoreSites =>
      'Altri siti sono in arrivo: il supporto per nuovi provider arriverà con i prossimi aggiornamenti.';

  @override
  String archiveLinkCopied(String url) {
    return '$url copiato negli appunti.';
  }

  @override
  String get archiveTracked => 'Serie in corso';

  @override
  String get archiveTrackedIntro =>
      'Ogni giorno si ricontrollano tutte le serie in corso della libreria, scaricate da qui o da altri, tranne quelle che hai smesso di seguire: arrivano solo i capitoli nuovi. Riscaricarne una dal sito la fa seguire di nuovo.';

  @override
  String get archiveTrackedByServer =>
      'Le serie seguite le controlla il server, come scelto nelle Impostazioni («Chi scarica e controlla»). Quelle che seguiva il telefono restano ferme finché non torni al telefono.';

  @override
  String get archiveCheckDaily => 'Controllo ogni giorno';

  @override
  String archiveCheckAt(String time) {
    return 'Alle $time, anche ad app chiusa';
  }

  @override
  String get archiveCheckTime => 'Ora';

  @override
  String get archiveCheckTimeHelp => 'Ora del controllo';

  @override
  String get archiveWifiOnly => 'Solo con Wi-Fi';

  @override
  String get archiveWifiOnlyOn => 'Aspetta una rete che non si paga a consumo';

  @override
  String get archiveWifiOnlyOff => 'Anche con i dati mobili';

  @override
  String get archiveCheckNow => 'Controlla adesso';

  @override
  String get archiveNoTracked => 'Nessuna serie da seguire, per ora';

  @override
  String archiveTrackedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serie da seguire',
      one: '1 serie da seguire',
    );
    return '$_temp0';
  }

  @override
  String archiveTrackedLine(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli noti',
      one: '1 capitolo noto',
    );
    return '$_temp0 · $destination';
  }

  @override
  String archiveTrackedLineChecked(int count, String destination, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli noti',
      one: '1 capitolo noto',
    );
    return '$_temp0 · $destination · controllata $when';
  }

  @override
  String archiveTrackedAhead(int count, String destination) {
    return 'Man mano, $count da leggere pronti · $destination';
  }

  @override
  String get archiveStopFollowing => 'Smetti di seguirla';

  @override
  String archiveCheckQueued(String names) {
    return 'capitoli nuovi per $names';
  }

  @override
  String archiveCheckRemoved(String names) {
    return '$names ora conclusa';
  }

  @override
  String archiveCheckFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count non raggiunte',
      one: '1 non raggiunta',
    );
    return '$_temp0';
  }

  @override
  String get archiveCheckSeparator => '; ';

  @override
  String archiveCheckReport(String parts) {
    return '$parts.';
  }

  @override
  String get archiveNoNewChapters => 'Nessun capitolo nuovo.';

  @override
  String get archiveNoConnection => 'Nessuna connessione.';

  @override
  String get archiveForgetTitle => 'Smettere di seguirla?';

  @override
  String archiveForgetBody(String title) {
    return 'I capitoli nuovi di «$title» non arriveranno più da soli. Quelli già scaricati restano.';
  }

  @override
  String get archiveCancel => 'Annulla';

  @override
  String get archiveForgetConfirm => 'Smetti';

  @override
  String get archiveStartNoMatch => 'Nessun capitolo con questo numero.';

  @override
  String get browserTitle => 'Verifica del sito';

  @override
  String get browserPhoneOnly => 'La verifica si fa solo dal telefono.';

  @override
  String get browserInstructionsChapters =>
      'Il sito vuole sapere che sei una persona. Completa la verifica: quando compare l\'elenco dei capitoli, Kagami se ne accorge e torna indietro da sola.';

  @override
  String get browserInstructionsSearch =>
      'Il sito vuole sapere che sei una persona. Completa la verifica: quando compare la ricerca del sito, Kagami se ne accorge e torna indietro da sola.';

  @override
  String get browserSearchPhoneOnly =>
      'Su questo sito si cerca solo dal telefono.';

  @override
  String get browserSearchSuperseded => 'Superata da una ricerca più recente.';

  @override
  String get browserResponseTooLarge => 'Risposta troppo grande.';

  @override
  String get serverTitle => 'Server';

  @override
  String get serverRecent => 'Scaricate dal server';

  @override
  String get serverUnavailableNoSecret =>
      'Questa build dell\'app non può collegare server: chi l\'ha compilata non ha indicato il segreto del client Web (GOOGLE_SERVER_CLIENT_SECRET).';

  @override
  String get serverUnavailableAndroidOnly =>
      'Collegare un server si può solo da Android.';

  @override
  String get serverSignInRequired =>
      'Fai l\'accesso con Google per usare il server.';

  @override
  String get serverNoConnection => 'Nessuna connessione.';

  @override
  String get serverMissingGoogleServices =>
      'Manca google-services.json: questa build non ha il client di Google.';

  @override
  String get serverDriveAccessDenied =>
      'Google non ha concesso l\'accesso a Drive.';

  @override
  String get serverGoogleNotResponding =>
      'Google non risponde: riprova fra poco.';

  @override
  String serverWhenToday(String clock) {
    return 'oggi alle $clock';
  }

  @override
  String serverWhenDate(String date, String clock) {
    return '$date alle $clock';
  }

  @override
  String serverProgressStats(int pages, String size, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: ' · $skipped già a posto',
      zero: '',
    );
    return '$pages tavole nuove · $size$_temp0';
  }

  @override
  String get serverRemoveFromQueue => 'Togli dalla coda';

  @override
  String get serverNoFirebase =>
      'Il server riconosce chi lo usa dall\'account Google, che in questa build dell\'app non c\'è.';

  @override
  String get serverSignedOutIntro =>
      'Un computer sempre acceso può scaricare e caricare sul tuo Drive al posto del telefono, che intanto può anche spegnersi. Il server ti riconosce dal tuo account Google.';

  @override
  String get serverSignIn => 'Accedi con Google';

  @override
  String get serverSignInSubtitle =>
      'Per creare il tuo server o usare quello di qualcun altro';

  @override
  String serverInviteTitle(String sender, String serverName) {
    return '$sender ti ha dato accesso a «$serverName»';
  }

  @override
  String get serverInviteSubtitle =>
      'Scarica sul tuo Drive, anche a telefono spento. Tocca per collegarlo';

  @override
  String get serverIgnore => 'Ignora';

  @override
  String get serverLinkIntro =>
      'Un computer sempre acceso — il tuo o quello di chi ti ha dato accesso — può scaricare e caricare sul tuo Drive al posto del telefono, che intanto può anche spegnersi.';

  @override
  String get serverCreate => 'Crea il tuo server';

  @override
  String get serverCreateSubtitle =>
      'Un comando da incollare su un computer con Docker: niente da configurare';

  @override
  String get serverLinkTitle => 'Collega un server';

  @override
  String get serverLinkSubtitle =>
      'Il tuo, già acceso, o quello di chi ti ha aggiunto';

  @override
  String get serverStateConnecting => 'Collegamento…';

  @override
  String get serverStateNoGrant => 'Non ha ancora il permesso del tuo Drive';

  @override
  String get serverStateNoFolder =>
      'Non sa ancora in quale cartella del tuo Drive scrivere';

  @override
  String serverStateReady(String folder) {
    return 'Pronto · scrive in «$folder» sul tuo Drive';
  }

  @override
  String serverTileSubtitle(String address, String state) {
    return '$address · $state';
  }

  @override
  String serverTileSubtitleOwner(String address, String owner, String state) {
    return '$address · di $owner · $state';
  }

  @override
  String get serverPlainTitle => 'La connessione è in chiaro';

  @override
  String get serverPlainSubtitle =>
      'Il token del tuo account si legge per strada: serve HTTPS (Tailscale Funnel, un reverse proxy)';

  @override
  String get serverGrantTitle => 'Dai il tuo Drive al server';

  @override
  String get serverGrantSubtitle =>
      'Scaricherà nella cartella che legge l\'app, anche a telefono spento';

  @override
  String get serverUseAppFolder => 'Usa la cartella dell\'app';

  @override
  String serverUseAppFolderSubtitle(String serverFolder, String appFolder) {
    return 'Il server scrive in «$serverFolder», l\'app legge «$appFolder»';
  }

  @override
  String get serverUsersTitle => 'Chi può usarlo';

  @override
  String get serverUsersOnlyYou =>
      'Solo tu. Aggiungi l\'account Google di chi vuoi';

  @override
  String serverUsersCount(int count) {
    return '$count account, te compreso';
  }

  @override
  String get serverQueueWaiting => 'Coda in attesa';

  @override
  String get serverQueueRestarts => 'Il server riparte da solo';

  @override
  String get serverJobAutomatic => 'Capitoli nuovi · sul server';

  @override
  String get serverJobQueued => 'In coda · sul server';

  @override
  String serverJobAhead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli',
      one: '1 capitolo',
    );
    return 'Man mano: $_temp0';
  }

  @override
  String serverSeriesAhead(int count) {
    return 'Man mano, $count da leggere pronti: i capitoli li chiede l\'app mentre leggi';
  }

  @override
  String serverSeriesKnown(int count) {
    return '$count capitoli noti';
  }

  @override
  String serverSeriesKnownChecked(int count, String when) {
    return '$count capitoli noti · controllata $when';
  }

  @override
  String get serverStopFollowing => 'Smetti di seguirla';

  @override
  String get serverInviteRemoveFailed =>
      'Non sono riuscito a togliere l\'invito: riprova.';

  @override
  String get serverCheckingNow =>
      'Il server sta controllando: i capitoli nuovi compaiono nella sua coda.';

  @override
  String get serverPaste => 'Incolla';

  @override
  String get serverAddressExposed =>
      'Attenzione: in chiaro su un indirizzo pubblico il token del tuo account si legge per strada. Usa HTTPS (Tailscale Funnel, un reverse proxy) o Tailscale.';

  @override
  String get serverAddressSavedNote =>
      'L\'indirizzo viaggia col backup e con l\'account, come la cartella di Drive.';

  @override
  String get serverAddressMissing =>
      'Scrivi l\'indirizzo del server, per esempio http://192.168.1.20:8080.';

  @override
  String serverLinked(String name, String folder) {
    return 'Collegato a «$name»: scarica in «$folder» sul tuo Drive.';
  }

  @override
  String serverLinkFromInvite(String sender, String serverName) {
    return '$sender ti ha aggiunto a «$serverName». Collegandolo, il server scaricherà i manga che scegli nella cartella della tua libreria sul tuo Drive: Google ti chiederà di permettergli di scriverci. Chi gestisce il server potrà usare quel permesso.';
  }

  @override
  String serverLinkLinked(String account) {
    return 'Il server ti riconosce come $account. Scollegandolo, se non è tuo, dimentica anche il permesso sul tuo Drive e la tua coda.';
  }

  @override
  String get serverSignedInAccount => 'l\'account con cui hai fatto l\'accesso';

  @override
  String get serverLinkNew =>
      'Scrivi l\'indirizzo del server: il tuo, o quello che ti ha dato chi ti ha aggiunto. Il server ti riconosce dall\'account Google, e la prima volta gli dai il permesso di scrivere nella cartella della tua libreria su Drive.';

  @override
  String get serverVerifying => 'Verifica…';

  @override
  String get serverVerifyAgain => 'Verifica di nuovo';

  @override
  String get serverVerifyAndLink => 'Verifica e collega';

  @override
  String get serverUnlink => 'Scollega';

  @override
  String get serverDefaultNameOwn => 'Il mio Kagami Server';

  @override
  String serverDefaultNameOf(String name) {
    return 'Il server di $name';
  }

  @override
  String get serverCommandCopied => 'Comando copiato.';

  @override
  String get serverComputerAddressMissing =>
      'Scrivi l\'indirizzo del computer, per esempio http://192.168.1.20:8080.';

  @override
  String serverNotOwner(String owner) {
    return 'Quel server è di $owner: è collegato, ma non l\'hai creato tu.';
  }

  @override
  String serverReady(String name) {
    return '«$name» è pronto. Aggiungi chi vuoi da «Chi può usarlo».';
  }

  @override
  String get serverLibraryFolderFallback => 'la cartella della libreria';

  @override
  String serverSetupIntro(String folder) {
    return 'Serve un computer che resti acceso — un mini PC, un NAS, un Raspberry Pi, un server in rete — con Docker. Il server scarica i manga e li carica sul tuo Drive, in «$folder», anche a telefono spento.';
  }

  @override
  String serverPrepareIntro(String signIn, String folder) {
    String _temp0 = intl.Intl.selectLogic(signIn, {
      'yes': 'prima fai l\'accesso con Google, poi ',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(folder, {
      'yes': 'scegli la cartella dei manga su Drive, poi ',
      'other': '',
    });
    return 'Preparo un comando che contiene tutto: $_temp0${_temp1}Google ti chiede di permettere al server di scrivere sul tuo Drive.';
  }

  @override
  String get serverPreparing => 'Preparo…';

  @override
  String get serverGenerate => 'Genera il comando';

  @override
  String get serverStep1 =>
      'Installa Docker sul computer (docker.com), se non c\'è già.';

  @override
  String get serverStep2 =>
      'Incolla questi comandi nel suo terminale: il primo accende il server, il secondo lo tiene aggiornato da solo. Contengono il permesso sul tuo Drive: non mandarli a nessuno.';

  @override
  String get serverCopyCommand => 'Copia il comando';

  @override
  String get serverStep3 =>
      'Scrivi qui l\'indirizzo del computer: in casa quello della rete locale; da fuori, il suo nome in Tailscale o l\'indirizzo HTTPS con cui lo esponi.';

  @override
  String get serverPortNote => 'Il server risponde sulla porta 8080.';

  @override
  String get serverUsersIntro =>
      'Aggiungi l\'account Google di chi vuoi. Nella sua app di Kagami comparirà l\'invito: collegando il server, i suoi download andranno sul suo Drive, con la sua coda.';

  @override
  String get serverUserEmailInvalid =>
      'Scrivi l\'indirizzo dell\'account Google, per esempio nome@gmail.com.';

  @override
  String serverUserAdded(String email) {
    return '$email può usare il server: glielo dice la sua app.';
  }

  @override
  String serverRemoveTitle(String email) {
    return 'Togliere $email?';
  }

  @override
  String get serverRemoveBody =>
      'Non potrà più usare il server. La sua coda e il permesso sul suo Drive si cancellano; ciò che è già sul suo Drive resta.';

  @override
  String get serverCancel => 'Annulla';

  @override
  String get serverRemove => 'Togli';

  @override
  String get serverAdd => 'Aggiungi';

  @override
  String get serverOwnerYou => 'Tu, il proprietario';

  @override
  String get serverConnected => 'Ha collegato il server';

  @override
  String get serverInvitedPending =>
      'Invitato, non ha ancora collegato il server';

  @override
  String get setupIntro =>
      'Legge la cartella dei manga che la sincronizzazione deposita sul telefono, oppure la stessa libreria direttamente da Google Drive, senza portarla tutta qui.';

  @override
  String get setupAccessTitle => 'Accesso ai file';

  @override
  String get setupAccessBody =>
      'La cartella sta fuori dallo spazio privato dell\'app, e contiene decine di migliaia di immagini: Kagami ha bisogno di leggerle direttamente. Scrive soltanto le copie dei dati nella sottocartella reading/ della libreria e, se lo chiedi, i capitoli che scarichi da Drive.';

  @override
  String get setupGrantAccess => 'Concedi accesso';

  @override
  String get setupFolderTitle => 'La cartella';

  @override
  String get setupFolderBody =>
      'Indica la cartella sincronizzata da FolderSync: quella che contiene library.json e una sottocartella per serie.';

  @override
  String get setupChooseFolder => 'Scegli la cartella';

  @override
  String get setupOr => 'oppure';

  @override
  String get setupDriveTitle => 'Google Drive';

  @override
  String get setupDriveBody =>
      'Si accede con Google e si sceglie la cartella della libreria su Drive: le tavole arrivano mentre si legge, e i capitoli che si vogliono avere sempre a portata si scaricano con un tocco. Non serve l\'accesso ai file del telefono.';

  @override
  String get setupReadFromDrive => 'Leggi da Google Drive';

  @override
  String get setupLibraryProblemTitle => 'Libreria non leggibile';

  @override
  String get setupChangeFolder => 'Cambia cartella';

  @override
  String get driveFolderSheetTitle => 'Cartella su Drive';

  @override
  String get driveDestinationTitle => 'Dove salvo i manga?';

  @override
  String get driveDestinationBody =>
      'Non c\'è una cartella per i manga sul telefono. In una cartella i capitoli scaricati restano anche se l\'app si disinstalla, e Kagami li legge insieme a quelli che ci sono già. Nello spazio dell\'app non serve nessun permesso, ma se ne vanno con lei.';

  @override
  String get driveChooseFolder => 'Scegli una cartella';

  @override
  String get driveInAppSpace => 'Nello spazio dell\'app';

  @override
  String get driveMyDrive => 'Il mio Drive';

  @override
  String get driveSharedWithMe => 'Condivisi con me';

  @override
  String get driveBack => 'Indietro';

  @override
  String get driveNoResponse => 'Drive non risponde';

  @override
  String get driveRetry => 'Riprova';

  @override
  String get driveIsLibrary => 'Contiene library.json: è una libreria';

  @override
  String get driveNotLibrary =>
      'Non contiene library.json: la libreria è la cartella che lo ha';

  @override
  String get driveUseFolder => 'Usa questa cartella';

  @override
  String get driveNoFolders => 'Nessuna cartella qui';

  @override
  String get driveNoticeAuthRequired =>
      'Kagami non ha ancora il permesso di leggere Google Drive';

  @override
  String get driveAuthorize => 'Autorizza';

  @override
  String get driveSignIn => 'Accedi';

  @override
  String get driveNoticeOffline =>
      'Sei offline: si leggono i capitoli sul telefono e le tavole di Drive già scaricate. Il resto torna da solo con la rete';

  @override
  String driveNoticeError(String message) {
    return 'Drive: $message. Si vede quello che c\'è sul telefono';
  }

  @override
  String get syncSummaryOff => 'Spenta';

  @override
  String get syncSummaryDownload => 'Da Drive al telefono';

  @override
  String get syncSummaryUpload => 'Dal telefono a Drive';

  @override
  String get syncSummaryBoth => 'In entrambe le direzioni';

  @override
  String syncSummaryManual(String direction) {
    return '$direction, a mano';
  }

  @override
  String syncSummaryDaily(String direction, String time) {
    return '$direction, ogni giorno alle $time';
  }

  @override
  String get syncTitle => 'Sincronizzazione';

  @override
  String get syncIntro =>
      'Tiene uguali la cartella dei manga sul telefono e quella su Drive, senza FolderSync. Se lo usi ancora su questa cartella, spegnilo: due sincronizzazioni sugli stessi file si pestano i piedi.';

  @override
  String get syncFolders => 'Cartelle';

  @override
  String get syncOnPhone => 'Sul telefono';

  @override
  String get syncNoFolderChosen => 'Nessuna cartella scelta';

  @override
  String get syncOnDrive => 'Su Drive';

  @override
  String get syncDriveNotConnected => 'Drive non è collegato';

  @override
  String get syncDirection => 'Direzione';

  @override
  String get syncDirectionOff => 'Spenta';

  @override
  String get syncDirectionFromDrive => 'Da Drive';

  @override
  String get syncDirectionToDrive => 'Verso Drive';

  @override
  String get syncDirectionBoth => 'Entrambe';

  @override
  String get syncDescOff =>
      'Niente si muove da solo. La libreria di Drive si legge lo stesso, e «Scarica» funziona come sempre.';

  @override
  String get syncDescDownload =>
      'Quello che arriva su Drive scende sul telefono. Dal telefono non sale niente.';

  @override
  String get syncDescUpload =>
      'Quello che c\'è sul telefono sale su Drive — per esempio le copie dei dati in reading/backup. Gli indici della libreria restano quelli del server.';

  @override
  String get syncDescBoth =>
      'Quello che cambia da una parte arriva dall\'altra; se è cambiato da tutt\'e due, vince il più recente. Gli indici della libreria scendono e basta: sono del server.';

  @override
  String get syncDeletions => 'Propaga le cancellazioni';

  @override
  String get syncDeletionsDownload =>
      'Toglie dal telefono ciò che sparisce da Drive';

  @override
  String get syncDeletionsUpload =>
      'Sposta nel cestino di Drive ciò che togli dal telefono';

  @override
  String get syncDeletionsBoth =>
      'Da una parte all\'altra; da Drive solo nel cestino';

  @override
  String get syncDeletionsOnNote =>
      '«Libera spazio» toglie i capitoli letti anche da Drive, al giro seguente.';

  @override
  String get syncDeletionsOffNote =>
      'Un file tolto da una parte resta dall\'altra e non torna indietro: «Libera spazio» libera il telefono e lascia i capitoli su Drive.';

  @override
  String get syncDaily => 'Ogni giorno';

  @override
  String get syncScheduled => 'Sincronizzazione programmata';

  @override
  String get syncManualOnly => 'Solo a mano';

  @override
  String syncAtTime(String time) {
    return 'Alle $time, anche ad app chiusa';
  }

  @override
  String get syncTime => 'Ora';

  @override
  String get syncWifiOnly => 'Solo con Wi-Fi';

  @override
  String get syncWifiOnlyOn => 'Aspetta una rete che non si paga a consumo';

  @override
  String get syncWifiOnlyOff => 'Anche con i dati mobili';

  @override
  String get syncScheduleNote =>
      'Android decide il momento esatto: se all\'ora scelta manca la rete, il giro parte appena torna.';

  @override
  String get syncNow => 'Adesso';

  @override
  String get syncTimePickerHelp => 'Ora della sincronizzazione';

  @override
  String get syncRunNow => 'Sincronizza adesso';

  @override
  String get syncRunNowReady =>
      'Si può continuare a leggere: le copie vanno avanti da sole';

  @override
  String get syncRunNowNotReady =>
      'Servono la cartella del telefono e quella di Drive';

  @override
  String get syncPhaseListing => 'Guardo cosa c\'è su Drive…';

  @override
  String get syncPhaseComparing => 'Confronto con il telefono…';

  @override
  String get syncPhaseNothing => 'Niente da copiare';

  @override
  String syncPhaseFiles(int done, int total) {
    return 'File $done di $total';
  }

  @override
  String get syncStop => 'Interrompi';

  @override
  String get syncNever => 'Mai sincronizzata';

  @override
  String get syncNeverNote =>
      'Il primo giro su una cartella già piena è veloce: i file uguali si riconoscono dalla misura';

  @override
  String syncLastScheduled(String date, String time) {
    return 'Ultima, programmata: $date alle $time';
  }

  @override
  String syncLastManual(String date, String time) {
    return 'Ultima, a mano: $date alle $time';
  }

  @override
  String syncOutcomeDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scaricati',
      one: '$count scaricati',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeUploaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count caricati',
      one: '$count caricati',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeDeletedLocal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tolti dal telefono',
      one: '$count tolti dal telefono',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeTrashed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nel cestino di Drive',
      one: '$count nel cestino di Drive',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count non riusciti, si riprovano',
      one: '$count non riusciti, si riprovano',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeErrorSoFar(String error, String done) {
    return '$error. Fin lì: $done';
  }

  @override
  String get syncOutcomeAligned => 'Era già tutto allineato';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsAppearance => 'Aspetto';

  @override
  String get settingsThemeDark => 'Scuro';

  @override
  String get settingsThemeLight => 'Chiaro';

  @override
  String get settingsThemeSystem => 'Come il sistema';

  @override
  String get settingsLibrary => 'Libreria';

  @override
  String get settingsFolder => 'Cartella';

  @override
  String get settingsNoFolder => 'Nessuna cartella scelta';

  @override
  String get settingsReloadIndexes => 'Rileggi gli indici';

  @override
  String get settingsReloadIndexesNote =>
      'Da fare quando la sincronizzazione ha appena portato roba nuova';

  @override
  String get settingsIndexesReloaded => 'Indici riletti';

  @override
  String get settingsGoogleDrive => 'Google Drive';

  @override
  String get settingsReading => 'Lettura';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsData => 'Dati';

  @override
  String get settingsAbout => 'Informazioni';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsLibraryNote => 'Cartella, indici e Google Drive';

  @override
  String get settingsLibraryNoteLocal => 'Cartella e indici';

  @override
  String get settingsReadingNote => 'Modalità predefinita e misure del lettore';

  @override
  String get settingsAccountNote => 'Accesso con Google e sincronizzazione';

  @override
  String get settingsDataNote => 'Backup, ripristino e cancellazione';

  @override
  String get settingsAutoBackup => 'Copia automatica nella libreria';

  @override
  String get settingsAutoBackupNote =>
      'Una volta al giorno in reading/backup/, che la sincronizzazione porta su Drive insieme ai manga';

  @override
  String get settingsExport => 'Esporta i dati';

  @override
  String get settingsExportNote =>
      'Stato, voti, cronologia, raccolte e segnalibri in un file';

  @override
  String get settingsExportDialog => 'Dove salvare il backup';

  @override
  String get settingsExportCancelled => 'Esportazione annullata';

  @override
  String get settingsExportSaved => 'Backup salvato';

  @override
  String get settingsImport => 'Importa da un backup';

  @override
  String get settingsImportNote => 'Dice cosa contiene prima di toccare niente';

  @override
  String get settingsImportDialog => 'Scegli un backup di Kagami';

  @override
  String get settingsImportInvalid => 'Non è un backup di Kagami';

  @override
  String get settingsImportSheetTitle => 'Importare questo backup?';

  @override
  String get settingsImportSeries => 'Serie';

  @override
  String get settingsImportRead => 'Letti';

  @override
  String get settingsImportCollections => 'Raccolte';

  @override
  String settingsImportExplain(String date) {
    return 'Fatto il $date. Fondere tiene quello che hai già e aggiunge: i capitoli letti si sommano e per il resto vince il record più recente. Sostituire cancella i dati di questo dispositivo.';
  }

  @override
  String get settingsImportExplainUnknownDate =>
      'Fatto in una data ignota. Fondere tiene quello che hai già e aggiunge: i capitoli letti si sommano e per il resto vince il record più recente. Sostituire cancella i dati di questo dispositivo.';

  @override
  String get settingsImportMerge => 'Fondi';

  @override
  String get settingsImportReplace => 'Sostituisci';

  @override
  String get settingsImportDone => 'Dati importati';

  @override
  String get settingsImportFailed => 'Importazione non riuscita';

  @override
  String get settingsWipe => 'Elimina i dati personali';

  @override
  String get settingsWipeNote =>
      'Stato, voti, cronologia e raccolte. I manga non si toccano';

  @override
  String get settingsWipeSheetTitle => 'Eliminare tutti i dati personali?';

  @override
  String get settingsWipeExplain =>
      'Spariscono stato, voti, preferiti, capitoli letti, cronologia, sessioni, raccolte e segnalibri di questo dispositivo. I manga e gli indici della libreria non vengono toccati.\n\nSe non hai un backup, questa è l\'ultima occasione per farlo.';

  @override
  String get settingsWipeConfirm => 'Elimina tutto';

  @override
  String get settingsWipeDone => 'Dati personali eliminati';

  @override
  String get settingsDriveConnect => 'Collega Google Drive';

  @override
  String get settingsDriveConnectNote =>
      'Legge la libreria da Drive senza portarla tutta sul telefono, e scarica solo ciò che si sceglie';

  @override
  String get settingsDriveFolder => 'Cartella su Drive';

  @override
  String get settingsDriveSync => 'Sincronizzazione della cartella';

  @override
  String get settingsDriveDownloadsGo => 'I capitoli scaricati vanno';

  @override
  String settingsDriveDownloadsFolder(String path) {
    return 'Nella cartella della libreria: $path';
  }

  @override
  String get settingsDriveDownloadsApp =>
      'Nello spazio dell\'app: se ne vanno disinstallandola';

  @override
  String get settingsDriveDownloadsAsk => 'Si chiede al primo download';

  @override
  String get settingsDriveCache => 'Tavole lette da Drive';

  @override
  String settingsDriveCacheNote(String used, String limit) {
    return '$used in cache, al massimo $limit. Si rileggono senza rete';
  }

  @override
  String get settingsDriveCacheLimitTitle => 'Spazio per le tavole';

  @override
  String get settingsDriveClearCache => 'Svuota la cache';

  @override
  String get settingsDriveClearCacheNote =>
      'I capitoli scaricati non si toccano';

  @override
  String get settingsDriveDisconnect => 'Scollega Drive';

  @override
  String get settingsDriveDisconnectNote =>
      'La libreria torna a essere la cartella del telefono. I capitoli scaricati restano';

  @override
  String get settingsAccountUnavailable => 'Account non disponibile qui';

  @override
  String get settingsAccountUnavailableNote =>
      'Questa build non ha Firebase: i dati restano dove sono, sul dispositivo';

  @override
  String get settingsAccountSignIn => 'Accedi con Google';

  @override
  String get settingsAccountSignInNote =>
      'Voti, stato, capitoli letti, cronologia e raccolte seguono l\'account invece del telefono';

  @override
  String get settingsAccountSyncNow => 'Sincronizza adesso';

  @override
  String get settingsAccountNeverSynced =>
      'Mai sincronizzato su questo telefono';

  @override
  String settingsAccountLastSync(String date, String time) {
    return 'L\'ultima volta il $date alle $time';
  }

  @override
  String get settingsAccountSignOut => 'Esci';

  @override
  String get settingsAccountSignOutNote =>
      'Manda su l\'ultima lettura, poi chiude la sessione';

  @override
  String get settingsAccountForget => 'Smetti di tenerne copia';

  @override
  String get settingsAccountForgetNote =>
      'Cancella i dati dall\'account. Quelli di questo telefono restano dove sono';

  @override
  String get settingsAccountErrorNote =>
      'I dati di questo telefono non sono stati toccati';

  @override
  String get settingsAccountForgetSheetTitle =>
      'Cancellare i dati dall\'account?';

  @override
  String get settingsAccountForgetExplain =>
      'Sparisce la copia tenuta per te, e l\'accesso si chiude. Stato, voti, cronologia e raccolte di questo telefono restano dove sono — ma da un altro telefono non si vedranno più.';

  @override
  String get settingsAccountForgetConfirm => 'Cancella dall\'account';

  @override
  String get settingsReaderDirection => 'Direzione in paginata';

  @override
  String get settingsReaderBackground => 'Sfondo';

  @override
  String get settingsReaderKeepAwake => 'Tieni acceso lo schermo';

  @override
  String get settingsReaderProgressBar => 'Barra di avanzamento';

  @override
  String get settingsProbe => 'Misura la fluidità';

  @override
  String get settingsProbeNote =>
      'Nel lettore, in alto: fotogrammi lenti e saltati, da dove arrivano le fasce, GC. Un tocco sui numeri li azzera';

  @override
  String get settingsProbeInfo1 =>
      'Mostra nel lettore, in alto a sinistra, un riquadro di numeri su quanto è fluida la lettura. Serve a capire perché lo scorrimento scatta: non cambia niente di come si legge, e costa pochissimo.';

  @override
  String get settingsProbeInfo2 =>
      'Il numero che conta di più è «saltati»: i fotogrammi che mancano mentre la pagina scorre. Ognuno è un piccolo scatto che si vede. «Partiti tardi» e «Lenti» dicono se l\'app era occupata, «GC Android» se il sistema stava liberando memoria.';

  @override
  String get settingsProbeInfo3 =>
      '«Tessere», «intere», «del telefono» e «native» dicono da dove è arrivato ogni pezzo di tavola: le prime tre sono le vie leggere, l\'ultima è il ritaglio fatto al momento, che è quella che pesa.';

  @override
  String get settingsProbeInfo4 =>
      'Un tocco sul riquadro azzera i numeri, così si misura da un punto preciso del capitolo. Riaprendo l\'app la misura si spegne da sola.';

  @override
  String get settingsTexture => 'Fasce native come texture';

  @override
  String get settingsTextureNote =>
      'Prova: le tavole ancora da tagliare arrivano alla GPU senza passare dall\'interfaccia. Si spegne riaprendo l\'app';

  @override
  String get settingsTextureInfo1 =>
      'Le tavole molto alte di un webtoon si leggono a pezzi. Quasi sempre i pezzi sono già pronti: tagliati dall\'archivio sul server, o dal telefono la prima volta che si apre il capitolo. Quando non lo sono, li ritaglia al momento il decodificatore di Android.';

  @override
  String get settingsTextureInfo2 =>
      'Normalmente i pixel di quei pezzi passano dall\'app prima di arrivare allo schermo. Con questa opzione vanno direttamente alla scheda grafica: l\'app ha meno lavoro mentre si scorre, e lo scorrimento può scattare meno. La qualità dell\'immagine non cambia.';

  @override
  String get settingsTextureInfo3 =>
      'È una prova: è un modo di disegnare nuovo, non ancora verificato su questo telefono. Se vedi tavole nere, righe o sfarfallii, spegnila. Se il telefono non lo supporta, l\'app torna da sola al modo normale.';

  @override
  String get settingsTextureInfo4 =>
      'Sui capitoli già tagliati in tessere non cambia niente, perché lì questa strada non si usa. Riaprendo l\'app si spegne da sola.';

  @override
  String get settingsWhatItDoes => 'Cosa fa';

  @override
  String get settingsBackupsTitle => 'Copie nella libreria';

  @override
  String get settingsBackupsNone =>
      'Nessuna copia ancora: la prima si fa alla prossima apertura';

  @override
  String settingsBackupsLatest(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copie, l\'ultima $name',
      one: '1 copia, l\'ultima $name',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupNow => 'Fai una copia adesso';

  @override
  String settingsBackupWritten(String path) {
    return 'Copia scritta in $path';
  }

  @override
  String settingsVersion(String version, String build) {
    return 'versione $version ($build)';
  }

  @override
  String get settingsTagline => 'lettore per archivi MALF locali';

  @override
  String get librarySortUpdated => 'Aggiornate di recente';

  @override
  String get librarySortTitle => 'Titolo';

  @override
  String get librarySortProgress => 'Avanzamento';

  @override
  String get librarySortAdded => 'Aggiunte di recente';

  @override
  String get librarySortLastRead => 'Lette di recente';

  @override
  String get librarySortUnread => 'Da leggere';

  @override
  String get librarySortRating => 'Voto';

  @override
  String get librarySortChapters => 'Numero di capitoli';

  @override
  String get librarySortShuffle => 'A caso';

  @override
  String get libraryDisplayComfortable => 'Griglia comoda';

  @override
  String get libraryDisplayCompact => 'Griglia fitta';

  @override
  String get libraryDisplayList => 'Elenco';

  @override
  String get libraryDisplayDetailed => 'Elenco dettagliato';

  @override
  String get libraryAutoReading => 'In lettura';

  @override
  String get libraryAutoFresh => 'Novità';

  @override
  String get libraryAutoFavorites => 'Preferiti';

  @override
  String get libraryAutoPlanned => 'Da iniziare';

  @override
  String get libraryAutoFinished => 'Finiti';

  @override
  String libraryRowChapters(int count) {
    return '$count cap.';
  }

  @override
  String libraryRowUnread(int count) {
    return '$count da leggere';
  }

  @override
  String get libraryNoMatchTitle => 'Nessuna corrispondenza';

  @override
  String get libraryNoMatchMessage =>
      'Nessuna serie passa la ricerca e i filtri scelti.';

  @override
  String get libraryEmptyTitle => 'Libreria vuota';

  @override
  String get libraryEmptyMessage =>
      'La libreria non contiene serie. Se dovrebbe, controllare la sincronizzazione della cartella.';

  @override
  String get libraryClearFilters => 'Azzera i filtri';

  @override
  String get libraryTitle => 'Libreria';

  @override
  String get libraryCancelSelection => 'Annulla selezione';

  @override
  String librarySelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selezionate',
      one: '1 selezionata',
    );
    return '$_temp0';
  }

  @override
  String libraryAllWithCount(int count) {
    return 'Tutte ($count)';
  }

  @override
  String get libraryAll => 'Tutte';

  @override
  String get libraryMarkAllRead => 'Segna tutto letto';

  @override
  String get libraryMarkAllUnread => 'Segna tutto da leggere';

  @override
  String get libraryStatus => 'Stato';

  @override
  String get libraryFavorites => 'Preferiti';

  @override
  String get libraryAddToCollection => 'Aggiungi a una raccolta';

  @override
  String libraryStatusOfSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Stato di $count serie',
      one: 'Stato di 1 serie',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serie segnate come lette',
      one: '1 serie segnata come letta',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serie tornate da leggere',
      one: '1 serie tornata da leggere',
    );
    return '$_temp0';
  }

  @override
  String get librarySearchHint => 'Titolo, autore, tag:…';

  @override
  String get libraryLayout => 'Disposizione';

  @override
  String get libraryFiltersAndSort => 'Filtri e ordinamento';

  @override
  String get libraryReset => 'Azzera';

  @override
  String get librarySortSection => 'Ordina';

  @override
  String get libraryShowOnly => 'Mostra solo';

  @override
  String get libraryOnlyUnread => 'Con capitoli da leggere';

  @override
  String get libraryOnlyStarted => 'Iniziate';

  @override
  String get libraryOnlyNew => 'Con capitoli nuovi';

  @override
  String get libraryOnlyFavorite => 'Preferite';

  @override
  String get libraryMinRating => 'Voto almeno';

  @override
  String get libraryRelease => 'Pubblicazione';

  @override
  String get libraryGenres => 'Generi';

  @override
  String get libraryTriHint => 'Un tocco richiede, due escludono';

  @override
  String get libraryTags => 'Tag';

  @override
  String get libraryAuthors => 'Autori';

  @override
  String get homeEmptyTitle => 'Libreria vuota';

  @override
  String get homeEmptyMessage =>
      'Niente da sfogliare: la cartella non contiene ancora nessuna serie.';

  @override
  String get homeToStart => 'Da iniziare';

  @override
  String get homeSimilarTitle => 'Perché leggi quello che leggi';

  @override
  String get homeSimilarSubtitle =>
      'Non ancora aperte, con i generi che ti tornano';

  @override
  String get homeRecentlyArrived => 'Arrivate di recente';

  @override
  String get homeLeftHalfway => 'Lasciate a metà';

  @override
  String get homeLeftHalfwaySubtitle => 'In pausa e abbandonate';

  @override
  String get homeCaughtUpTitle => 'Sei in pari';

  @override
  String get homeCaughtUpMessage =>
      'Con tutto quello che è sincronizzato. Il prossimo capitolo arriverà con la cartella.';

  @override
  String get homeRandomSeries => 'Una a caso';

  @override
  String get homeReloadLibrary => 'Rileggi la libreria';

  @override
  String get homeGreetingNight => 'Notte fonda';

  @override
  String get homeGreetingMorning => 'Buongiorno';

  @override
  String get homeGreetingAfternoon => 'Buon pomeriggio';

  @override
  String get homeGreetingEvening => 'Buonasera';

  @override
  String get homeStatRead => 'Letti';

  @override
  String get homeStatReadCaption => 'capitoli in tutto';

  @override
  String get homeStatUnread => 'Da leggere';

  @override
  String get homeStatUnreadCaption => 'sul telefono';

  @override
  String get homeStatStreak => 'Di fila';

  @override
  String homeStatStreakCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'giorni',
      one: 'giorno',
    );
    return '$_temp0';
  }

  @override
  String get homeResume => 'Riprendi';

  @override
  String get homeNextChapter => 'Capitolo successivo';

  @override
  String get homeRead => 'Leggi';

  @override
  String get homeUpdates => 'Aggiornamenti';

  @override
  String get homeUpdatesSubtitle => 'Capitoli sincronizzati e non ancora letti';

  @override
  String homeLatestChapter(String number) {
    return 'cap. $number';
  }

  @override
  String homeSiteChapters(int count, String site) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuovi su $site',
      one: '1 nuovo su $site',
    );
    return '$_temp0';
  }

  @override
  String get homeAgoToday => 'oggi';

  @override
  String get homeAgoYesterday => 'ieri';

  @override
  String homeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni fa',
      one: '1 giorno fa',
    );
    return '$_temp0';
  }

  @override
  String homeAgoWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count settimane fa',
      one: '1 settimana fa',
    );
    return '$_temp0';
  }

  @override
  String homeAgoMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesi fa',
      one: '1 mese fa',
    );
    return '$_temp0';
  }

  @override
  String homeAgoYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anni fa',
      one: '1 anno fa',
    );
    return '$_temp0';
  }

  @override
  String get collectionsTitle => 'Raccolte';

  @override
  String get collectionsNew => 'Nuova';

  @override
  String get collectionsAutomatic => 'Automatiche';

  @override
  String get collectionsYours => 'Le tue raccolte';

  @override
  String get collectionsNoneTitle => 'Nessuna raccolta';

  @override
  String get collectionsNoneMessage =>
      'Sono il modo per dare struttura a una libreria che cresce da sola: una serie può stare in più raccolte e l\'ordine lo scegli tu.';

  @override
  String collectionsSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serie',
      one: '1 serie',
    );
    return '$_temp0';
  }

  @override
  String get collectionsEdit => 'Modifica';

  @override
  String get collectionsRenameRecolor => 'Rinomina e cambia colore';

  @override
  String get collectionsDelete => 'Elimina la raccolta';

  @override
  String get collectionsNotFound => 'Raccolta non trovata.';

  @override
  String get collectionsDone => 'Fine';

  @override
  String get collectionsReorder => 'Riordina';

  @override
  String get collectionsEmptyTitle => 'Raccolta vuota';

  @override
  String get collectionsEmptyMessage =>
      'Si aggiunge una serie dalla sua scheda, o tenendo premuta una copertina nella libreria.';

  @override
  String get collectionsRemoveFrom => 'Togli dalla raccolta';

  @override
  String get shellDataUnreadableTitle => 'Dati dell\'app non leggibili';

  @override
  String get shellRetry => 'Riprova';

  @override
  String get shellTabHome => 'Home';

  @override
  String get shellTabLibrary => 'Libreria';

  @override
  String get shellTabCollections => 'Raccolte';

  @override
  String get moreDownload => 'Scarica un manga';

  @override
  String get moreDownloadSubtitle => 'Cerca un titolo o incolla un link';

  @override
  String get settingsEngine => 'Chi scarica e controlla';

  @override
  String get settingsEngineServer => 'Il server';

  @override
  String get settingsEnginePhone => 'Il telefono';

  @override
  String get settingsEngineServerNote =>
      'Serie nuove, man mano e controllo delle serie seguite: tutto sul server, che guarda anche le serie scaricate dal telefono su Drive';

  @override
  String get settingsEnginePhoneNote =>
      'Serie nuove, man mano e controllo delle serie seguite: tutto sul telefono. Il server resta collegato, ma non controlla niente';

  @override
  String get settingsEngineNoServer =>
      'Tutto sul telefono. Per affidarlo a un server, collegalo da «Scarica un manga»';

  @override
  String get moreHistory => 'Cronologia';

  @override
  String get moreHistorySubtitle => 'Cosa hai letto e quando';

  @override
  String get moreStatistics => 'Statistiche';

  @override
  String get moreStatisticsSubtitle => 'Quanto leggi, cosa leggi, quando';

  @override
  String get moreIncognito => 'Lettura in incognito';

  @override
  String get moreIncognitoSubtitle =>
      'Non registra posizione, capitoli finiti né tempo di lettura';

  @override
  String get historyTitle => 'Cronologia';

  @override
  String get historyIncognitoOn => 'Incognito attivo';

  @override
  String get historyIncognitoOff => 'Leggi in incognito';

  @override
  String get historyClear => 'Svuota';

  @override
  String get historyUnreadable => 'Cronologia non leggibile';

  @override
  String get historyEmptyTitle => 'Niente di letto, per ora';

  @override
  String get historyEmptyMessage =>
      'Ogni capitolo finito comparirà qui con la sua data.';

  @override
  String get historyClearTitle => 'Svuotare la cronologia?';

  @override
  String get historyClearMessage =>
      'Le date di lettura e il tempo passato a leggere spariscono, e con loro le statistiche che ne derivano. I capitoli tornano da leggere.';

  @override
  String get historyIncognitoBanner =>
      'In incognito: posizione, capitoli finiti e tempo di lettura non vengono registrati.';

  @override
  String get historyToday => 'Oggi';

  @override
  String get historyYesterday => 'Ieri';

  @override
  String get historyReread => 'Rileggi';

  @override
  String get historyRemove => 'Togli dalla cronologia';

  @override
  String get originLocal => 'Sul telefono';

  @override
  String get originDrive => 'Su Drive';

  @override
  String get originMixed => 'Sul telefono, e altri capitoli su Drive';

  @override
  String get coverNoChapters => 'Nessun capitolo scaricato';

  @override
  String coverChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cap.',
    );
    return '$_temp0';
  }

  @override
  String coverChaptersUnread(int count, int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cap.',
    );
    return '$_temp0 · $unread da leggere';
  }

  @override
  String coverNewChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli nuovi',
      one: '1 capitolo nuovo',
    );
    return '$_temp0';
  }

  @override
  String coverUnread(int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '$unread capitoli da leggere',
      one: '1 capitolo da leggere',
    );
    return '$_temp0';
  }

  @override
  String coverUnreadFresh(int unread, int fresh) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '$unread capitoli da leggere',
      one: '1 capitolo da leggere',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fresh,
      locale: localeName,
      other: '$fresh nuovi',
      one: '1 nuovo',
    );
    return '$_temp0, di cui $_temp1';
  }

  @override
  String chartsDayNothing(String date) {
    return '$date: niente';
  }

  @override
  String chartsDayChapters(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli',
      one: '1 capitolo',
    );
    return '$date: $_temp0';
  }

  @override
  String get kitClose => 'Chiudi';

  @override
  String get collectionSheetTitle => 'Raccolte';

  @override
  String collectionSheetTitleMany(int count) {
    return 'Raccolte di $count serie';
  }

  @override
  String get collectionSheetNew => 'Nuova';

  @override
  String get collectionSheetEmptyTitle => 'Nessuna raccolta';

  @override
  String get collectionSheetEmptyMessage =>
      'Servono a dare struttura a una libreria che cresce da sola.';

  @override
  String collectionSheetSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serie',
      one: '1 serie',
    );
    return '$_temp0';
  }

  @override
  String get collectionSheetCreateTitle => 'Nuova raccolta';

  @override
  String get collectionSheetEditTitle => 'Modifica raccolta';

  @override
  String get collectionSheetNameHint => 'Nome';

  @override
  String get collectionSheetColor => 'Colore';

  @override
  String get collectionSheetCreate => 'Crea';

  @override
  String get collectionSheetSave => 'Salva';

  @override
  String get cleanupTitle => 'Liberare spazio?';

  @override
  String get cleanupSyncBusy =>
      'Una sincronizzazione è in corso: riprova quando finisce';

  @override
  String cleanupNotAllDeleted(String error) {
    return 'Non tutto è stato cancellato: $error';
  }

  @override
  String cleanupDriveError(String error) {
    return 'Drive: $error. Quelli già tolti restano tolti';
  }

  @override
  String cleanupFreed(String size) {
    return 'Liberati $size';
  }

  @override
  String get cleanupNeedsNetwork => 'Per togliere da Drive serve la rete';

  @override
  String removeSeriesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eliminare $count serie?',
      one: 'Eliminare la serie?',
    );
    return '$_temp0';
  }

  @override
  String removeSeriesBody(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Spariscono dalla libreria: i capitoli sul telefono si cancellano e non ne arrivano più di nuovi. Lo stato di lettura resta.',
      one:
          '«$title» sparisce dalla libreria: i capitoli sul telefono si cancellano e non ne arrivano più di nuovi. Lo stato di lettura resta.',
    );
    return '$_temp0';
  }

  @override
  String get removeSeriesDrive =>
      'Su Drive la cartella va nel cestino: per trenta giorni si recupera da lì.';

  @override
  String get removeSeriesConfirm => 'Elimina';

  @override
  String removeSeriesDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serie eliminate.',
      one: 'Serie eliminata.',
    );
    return '$_temp0';
  }

  @override
  String removeSeriesFailed(String error) {
    return 'Non è stato possibile eliminare tutto: $error';
  }

  @override
  String get removeSeriesAction => 'Elimina dalla libreria';

  @override
  String cleanupIntroDrive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli già letti sono ancora su Drive.',
      one: 'Un capitolo già letto è ancora su Drive.',
    );
    return '$_temp0';
  }

  @override
  String cleanupIntroPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli già letti occupano ancora spazio sul telefono.',
      one: 'Un capitolo già letto occupa ancora spazio sul telefono.',
    );
    return '$_temp0';
  }

  @override
  String get cleanupPhoneChapters => 'Capitoli sul telefono';

  @override
  String get cleanupDriveCache => 'Cache di Drive';

  @override
  String get cleanupDriveChapters => 'Capitoli su Drive';

  @override
  String cleanupApproxSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli',
      one: '1 capitolo',
    );
    return '$_temp0 · circa $size';
  }

  @override
  String cleanupExactSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli',
      one: '1 capitolo',
    );
    return '$_temp0 · $size';
  }

  @override
  String cleanupApproxSizeTrash(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli',
      one: '1 capitolo',
    );
    return '$_temp0 · circa $size · nel cestino';
  }

  @override
  String get cleanupQuiet => 'Non chiedere più per questa serie';

  @override
  String get cleanupWarnNotOnDrive =>
      'Questa serie non è su Drive: i capitoli cancellati non si potranno rileggere finché la sincronizzazione non li riporta.';

  @override
  String get cleanupWarnGoneEverywhere =>
      'Non resteranno né sul telefono né su Drive.';

  @override
  String get cleanupWarnStaysOnDrive =>
      'I capitoli restano su Drive e si rileggono da lì.';

  @override
  String get cleanupWarnTrash =>
      'Dal cestino di Drive si recuperano per trenta giorni. L\'indice del server li elenca ancora: se il server li ricarica, tornano a leggersi da Drive.';

  @override
  String get cleanupDelete => 'Elimina';

  @override
  String get cleanupNotNow => 'Non ora';

  @override
  String get cleanupSyncWarnExternal =>
      'Se FolderSync sincronizza la cartella in entrambe le direzioni, la cancellazione può arrivare anche su Drive; se scarica soltanto, i capitoli possono tornare al giro seguente.';

  @override
  String get cleanupSyncWarnOwn =>
      'La sincronizzazione rispetta questa scelta: quello che togli da una parte non torna e non sparisce dall\'altra, anche con le cancellazioni propagate.';

  @override
  String get statsRangeMonth => '30 giorni';

  @override
  String get statsRangeQuarter => '3 mesi';

  @override
  String get statsRangeYear => 'Un anno';

  @override
  String get statsTitle => 'Statistiche';

  @override
  String get statsUnavailable => 'Statistiche non calcolabili';

  @override
  String get statsChaptersRead => 'capitoli letti';

  @override
  String get statsSeriesInLibrary => 'serie in libreria';

  @override
  String statsMinutes(int count) {
    return '$count min';
  }

  @override
  String statsHours(int count) {
    return '$count h';
  }

  @override
  String get statsReadingTime => 'tempo di lettura';

  @override
  String get statsReadingTimeHint => 'misurato mentre leggi';

  @override
  String get statsPagesSeen => 'tavole viste';

  @override
  String get statsStreak => 'giorni di fila';

  @override
  String statsStreakRecord(int count) {
    return 'record: $count';
  }

  @override
  String get statsAverageRating => 'voto medio';

  @override
  String statsRatedSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serie votate',
      one: '1 serie votata',
    );
    return '$_temp0';
  }

  @override
  String get statsChaptersOverTime => 'Capitoli letti';

  @override
  String get statsPerWeek => 'per settimana';

  @override
  String get statsPerDay => 'per giorno';

  @override
  String get statsActivityTitle => 'Quando leggi';

  @override
  String get statsActivitySubtitle =>
      'un quadratino per giorno, negli ultimi sei mesi';

  @override
  String get statsShelfTitle => 'La libreria per stato';

  @override
  String statsGenreOthers(int count) {
    return 'Altri $count';
  }

  @override
  String get statsGenresTitle => 'Generi che leggi';

  @override
  String get statsGenresSubtitle => 'sulle serie che hai iniziato';

  @override
  String get statsRatingsTitle => 'Come voti';

  @override
  String get statsRatingsSubtitle => 'quante serie per ogni voto';

  @override
  String get statsTopSeries => 'Serie più lette';

  @override
  String get statsShapeTitle => 'Com\'è fatta la libreria';

  @override
  String get statsSyncedChapters => 'capitoli sincronizzati';

  @override
  String get statsStillUnread => 'ancora da leggere';

  @override
  String get statsOngoingSeries => 'serie in corso';

  @override
  String statsAnnouncedMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capitoli annunciati e non scaricati',
      one: '1 capitolo annunciato e non scaricato',
    );
    return '$_temp0';
  }

  @override
  String get statsBytesOnPhone => 'occupati sul telefono';

  @override
  String get statsNoHistory =>
      'Niente di letto in questo periodo. La cronologia parte da quando l\'app ha cominciato a registrarla.';

  @override
  String get dataDriveNotLinked => 'Drive non è collegato';

  @override
  String get dataChapterNotOnDrive => 'Capitolo non trovato su Drive';

  @override
  String get dataChapterNoPagesOnDrive => 'Il capitolo non ha tavole su Drive';

  @override
  String get dataPageNotOnDrive => 'Tavola non trovata su Drive';

  @override
  String get dataPrefetchCancelled => 'Precarico annullato';

  @override
  String get dataDriveAccessDenied =>
      'Google non ha concesso l\'accesso a Drive';

  @override
  String get dataDriveOfflineNeverOpened =>
      'Senza connessione, e la libreria su Drive non è mai stata aperta su questo telefono';

  @override
  String get dataDriveSignedOut =>
      'Accedi con Google per leggere la libreria su Drive';

  @override
  String get dataSyncMissingFolderOrDirection =>
      'Manca la cartella o la direzione';

  @override
  String get dataSyncFailed => 'Sincronizzazione non riuscita';

  @override
  String get dataSyncFolderUnreadable =>
      'La cartella del telefono non si legge';

  @override
  String get dataSyncBusy => 'Una sincronizzazione è già in corso';

  @override
  String get dataSyncCancelled => 'Sincronizzazione interrotta';

  @override
  String get dataSyncDirectionDownload => 'Da Drive';

  @override
  String get dataSyncDirectionUpload => 'Verso Drive';

  @override
  String get dataSyncDirectionBoth => 'Entrambe';

  @override
  String dataServerInviteTitle(String sender) {
    return '$sender ti ha dato accesso al suo server';
  }

  @override
  String dataServerInviteText(String serverName) {
    return 'Collega «$serverName» e scaricherà i manga sul tuo Drive, anche a telefono spento.';
  }

  @override
  String get dataServerSignInRequired =>
      'Fai l\'accesso con Google per usare il server.';

  @override
  String get dataServerNotLinked => 'Nessun server collegato.';

  @override
  String dataServerUserNotNotified(String email, String url) {
    return '$email può usare il server, ma non sono riuscito ad avvisarlo: mandagli tu l\'indirizzo $url.';
  }

  @override
  String get dataPickLibraryFolderTitle =>
      'Scegli la cartella della libreria manga';

  @override
  String get dataCloudSignInNotEnabled =>
      'L\'accesso con Google non è ancora attivo su questo progetto';

  @override
  String get dataCloudNoConnection => 'Nessuna connessione';

  @override
  String get dataCloudNoSignIn => 'Nessun accesso';

  @override
  String get dataCloudNoIdentityToken =>
      'Google non ha dato un token di identità';

  @override
  String get dataCloudSignInFailed => 'Accesso non riuscito';

  @override
  String get dataCloudSignInInterrupted => 'Accesso interrotto';

  @override
  String get dataCloudGoogleNotConfigured =>
      'Google non è configurato per questa app';

  @override
  String get dataCloudGoogleSignInFailed => 'Accesso con Google non riuscito';

  @override
  String dataNewChaptersNotification(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sono arrivati $count capitoli nuovi',
      one: 'È arrivato un capitolo nuovo',
    );
    return '$_temp0';
  }

  @override
  String dataNewSiteChaptersNotification(int count, String site) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sono usciti $count capitoli nuovi su $site',
      one: 'È uscito un capitolo nuovo su $site',
    );
    return '$_temp0';
  }

  @override
  String get dataArchivePhoneFolderMissing => 'Manca la cartella del telefono.';

  @override
  String get dataArchiveDriveFolderMissing => 'Manca la cartella di Drive.';

  @override
  String dataChapterLabel(String number) {
    return 'Capitolo $number';
  }

  @override
  String get dataLibraryMissing => 'La cartella non esiste o non è leggibile.';

  @override
  String get dataLibraryNotIndexed =>
      'La cartella non contiene library.json: vanno rigenerati gli indici con l\'archiviatore che ha scritto la libreria.';

  @override
  String get dataLibraryUnreadable =>
      'library.json non è leggibile o non è un indice MALF valido.';

  @override
  String get dataLibraryUnsupported =>
      'library.json usa una versione del formato più recente di questa app.';

  @override
  String get dataReaderModeContinuous => 'Continua';

  @override
  String get dataReaderModePaged => 'Paginata';

  @override
  String get dataReaderDirectionLtr => 'Sinistra → destra';

  @override
  String get dataReaderDirectionRtl => 'Destra → sinistra';

  @override
  String get dataReaderFitWidth => 'Larghezza';

  @override
  String get dataReaderFitHeight => 'Altezza';

  @override
  String get dataReaderFitOriginal => 'Originale';

  @override
  String get dataReaderBackgroundBlack => 'Nero';

  @override
  String get dataReaderBackgroundGrey => 'Grigio';

  @override
  String get dataReaderBackgroundWhite => 'Bianco';

  @override
  String readerProbeFrames(String frames, String budget) {
    return 'Fotogrammi $frames · limite $budget ms';
  }

  @override
  String readerProbeSlow(
    String build,
    String buildMax,
    String raster,
    String rasterMax,
  ) {
    return 'Lenti UI $build (max $buildMax ms) · GPU $raster (max $rasterMax ms)';
  }

  @override
  String readerProbeLate(String late, String lateMax) {
    return 'Partiti tardi $late (max $lateMax ms)';
  }

  @override
  String readerProbeScroll(String scroll, String missed, String gap) {
    return 'Scorrendo $scroll · saltati $missed (buco max $gap ms)';
  }

  @override
  String readerProbeSources(
    String tiles,
    String whole,
    String phone,
    String phoneMade,
  ) {
    return 'Tessere $tiles · intere $whole · del telefono $phone (fatte $phoneMade)';
  }

  @override
  String readerProbeNative(String bands, String textures, String decodes) {
    return 'Native $bands (texture $textures) · tavole decodificate $decodes';
  }

  @override
  String readerProbeDecode(
    String decode,
    String decodeMax,
    String arrival,
    String arrivalMax,
  ) {
    return 'Decodifica $decode ms (max $decodeMax) · arrivo $arrival ms (max $arrivalMax)';
  }

  @override
  String readerProbeMemory(
    String copy,
    String gc,
    String gcMs,
    String blocking,
    String blockingMs,
  ) {
    return 'Copia max $copy ms · GC Android $gc ($gcMs ms) · bloccanti $blocking ($blockingMs ms)';
  }

  @override
  String readerProbeWaits(String drive, String fallbacks) {
    return 'Attese da Drive $drive · ripieghi Dart $fallbacks';
  }

  @override
  String readerProbeJumps(String corrections, String jumps, String jumped) {
    return 'Correzioni $corrections · salti $jumps ($jumped px)';
  }

  @override
  String get serverCheckDaily => 'Controllo giornaliero dei capitoli nuovi';

  @override
  String serverCheckDailyAt(String clock) {
    return 'Ogni giorno alle $clock, ora del server';
  }

  @override
  String get serverCheckDailyOff =>
      'Spento: i capitoli nuovi si scaricano solo a mano';

  @override
  String get serverCheckByPhone =>
      'Spento: le serie seguite le controlla il telefono, come scelto nelle Impostazioni';

  @override
  String serverCheckLast(String when, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serie con capitoli nuovi',
      one: '1 serie con capitoli nuovi',
      zero: 'nessun capitolo nuovo',
    );
    return 'Ultimo controllo $when: $_temp0';
  }

  @override
  String get serverCheckTimeHelp => 'Ora del controllo';

  @override
  String get seriesRatingInviteTitle => 'Che voto gli dai?';

  @override
  String get seriesRatingInviteBody =>
      'Il voto serve a filtrare e ordinare la libreria e conta nelle statistiche.';

  @override
  String get seriesRatingInviteRate => 'Vota';

  @override
  String get seriesRatingInviteIgnore => 'Ignora';

  @override
  String get seriesRatingInviteNever => 'Non chiedere più';

  @override
  String get settingsRatingInvite => 'Chiedi un voto aprendo una serie';

  @override
  String get settingsRatingInviteNote =>
      'Nella scheda delle serie senza voto compare un invito a votare';

  @override
  String get archiveModeCard => 'Solo la scheda';

  @override
  String get archiveModeCardLine =>
      'Nessun capitolo: stato, voto e a che punto sei';

  @override
  String get archiveModeCardHint =>
      'Salva la serie nella libreria senza scaricare capitoli: copertina, metadati, l\'elenco dei capitoli e il link al sito. Indica fin dove sei arrivato: quel capitolo e i precedenti risultano letti. I capitoli si possono scaricare più avanti.';

  @override
  String get archiveReachedSection => 'Arrivato fino al…';

  @override
  String get archiveReachedHint => 'Tocca l\'ultimo capitolo che hai letto.';

  @override
  String get archiveReachedNone => 'Non ho iniziato';

  @override
  String get archiveChapterReached => 'arrivato qui';

  @override
  String get archiveCardServer =>
      'Le schede le salva il telefono: il server collegato scarica solo capitoli.';

  @override
  String get archiveCardNotesHint => 'Una nota per te (facoltativa)';

  @override
  String archiveSummaryCard(String where) {
    return 'Salva la scheda, nessun capitolo scaricato · $where';
  }

  @override
  String archiveSummaryCardReached(String number, String where) {
    return 'Salva la scheda letta fino al $number, nessun capitolo scaricato · $where';
  }

  @override
  String get archiveSaveCard => 'Salva la scheda';

  @override
  String archiveCardQueuedSnack(String title) {
    return 'Scheda di «$title» salvata: copertina ed elenco dei capitoli arrivano fra poco.';
  }

  @override
  String archiveCardProgress(String message) {
    return 'Scheda · $message';
  }

  @override
  String archiveJobCard(String destination) {
    return 'Scheda · $destination';
  }

  @override
  String archiveJobCardUpdate(String destination) {
    return 'Aggiornamento della scheda · $destination';
  }

  @override
  String archiveRecentCard(String when) {
    return 'Scheda · $when';
  }

  @override
  String archiveCheckCards(String names) {
    return 'capitoli nuovi in elenco, non scaricati, per le schede di $names';
  }

  @override
  String get seriesOpenSite => 'Apri sul sito';

  @override
  String get seriesRefreshCard => 'Aggiorna scheda';

  @override
  String get seriesDownloadMore => 'Scarica altri capitoli';

  @override
  String get seriesStartDownload => 'Inizia a scaricare';

  @override
  String get seriesStartDownloadMessage =>
      'Questa serie è solo una scheda: i capitoli sono sul sito. Scaricali per leggerli qui, a partire da quello dopo l\'ultimo letto.';

  @override
  String get seriesDownloadFromSite => 'Scarica dal sito';

  @override
  String get seriesDownloadFromSiteQueued => 'In coda dal sito';

  @override
  String get coverCardBadge => 'Scheda';

  @override
  String coverReached(String number) {
    return 'Arrivato al cap. $number';
  }

  @override
  String get libraryOnlyCards => 'Solo schede';

  @override
  String get seriesReachedTitle => 'Arrivato a';

  @override
  String get seriesReachedNone => 'Non iniziato';

  @override
  String seriesReachedChapter(String number) {
    return 'Cap. $number';
  }

  @override
  String get seriesReachedSearch => 'Cerca un capitolo';

  @override
  String get seriesReachedNumberHint => 'Numero del capitolo';

  @override
  String get seriesReachedNumberHelp =>
      'Come lo scrive il sito, per esempio 52. Vuoto per toglierlo.';

  @override
  String get seriesReachedBackTitle => 'Tornare indietro?';

  @override
  String seriesReachedBackMessage(String chapter) {
    return 'I capitoli dopo «$chapter» restano segnati come letti: per rimetterli da leggere toglili dall\'elenco dei capitoli.';
  }

  @override
  String get seriesReachedBackConfirm => 'Sposta';

  @override
  String get seriesCardEmptyTitle => 'Scheda senza capitoli';

  @override
  String get seriesCardEmptyMessage =>
      'Kagami non scarica da questo sito, ma la scheda tiene stato, voto, nota e punto di lettura.';

  @override
  String get seriesLinkSite => 'Collega a un sito';

  @override
  String get seriesLinkTitle => 'Collega a un sito';

  @override
  String get seriesLinkMessage =>
      'Incolla il link della serie su un sito da cui Kagami sa scaricare. Stato, voto, nota, raccolte e punto di lettura passano alla serie vera, e questa scheda si toglie.';

  @override
  String get seriesLinkHint => 'Link della serie';

  @override
  String get seriesLinkContinue => 'Continua';

  @override
  String seriesLinkDone(String title) {
    return '«$title» collegata: la serie comparirà in libreria quando il lavoro sarà finito.';
  }

  @override
  String get archiveManualAction => 'Aggiungi senza link';

  @override
  String get archiveManualUnsupported =>
      'Kagami non sa scaricare da questo sito: puoi salvarlo come scheda con titolo e link, ma i capitoli non si potranno scaricare.';

  @override
  String get archiveManualUnsupportedAction => 'Salva come scheda';

  @override
  String get archiveManualTitle => 'Scheda manuale';

  @override
  String get archiveManualTitleHint => 'Titolo';

  @override
  String get archiveManualTitleRequired => 'Scrivi un titolo.';

  @override
  String get archiveManualLinkHint =>
      'Link alla pagina della serie (facoltativo)';

  @override
  String get archiveManualSupported =>
      'Questo sito Kagami lo sa leggere: col percorso normale hai l\'elenco dei capitoli e puoi scaricarli.';

  @override
  String get archiveManualSupportedAction => 'Usa il percorso normale';

  @override
  String get archiveManualNoDownload =>
      'Di questo sito i capitoli non si potranno scaricare: resta il link, e titolo e copertina se la pagina li dichiara.';

  @override
  String get archiveManualReachedHint => 'Arrivato al capitolo (es. 52)';

  @override
  String get archiveManualWhereDrive =>
      'La scheda si salva su Drive, nella cartella della libreria.';

  @override
  String get archiveManualWherePhone => 'La scheda si salva sul telefono.';

  @override
  String get archiveManualSave => 'Salva la scheda';

  @override
  String archiveManualSaved(String title) {
    return 'Scheda di «$title» salvata.';
  }

  @override
  String archiveManualExists(String title) {
    return 'Questo link è già in libreria: «$title».';
  }

  @override
  String get archiveManualNeedsDrive =>
      'Per salvare la scheda su Drive serve il permesso di scrivere.';

  @override
  String archiveManualFailed(String error) {
    return 'Non sono riuscito a salvare la scheda: $error';
  }

  @override
  String get archiveImportAction => 'Importa più link';

  @override
  String get archiveImportTitle => 'Importa più link';

  @override
  String get archiveImportIntro =>
      'Incolla dei link: le schede del browser, un elenco, un JSON. Ogni manga diventa una scheda in libreria, senza scaricare capitoli; dal link di un capitolo, arrivato a quel capitolo.';

  @override
  String get archiveImportHint => 'Incolla qui il testo con i link…';

  @override
  String archiveImportFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count link trovati',
      one: 'Un link trovato',
      zero: 'Nessun link trovato',
    );
    return '$_temp0';
  }

  @override
  String get archiveImportWhereDrive =>
      'Le schede si salvano su Drive, nella cartella della libreria.';

  @override
  String get archiveImportWherePhone => 'Le schede si salvano sul telefono.';

  @override
  String get archiveImportCollection => 'Aggiungi a una raccolta';

  @override
  String get archiveImportCollectionNone => 'Nessuna raccolta';

  @override
  String get archiveImportPause => 'Pausa fra un link e l\'altro';

  @override
  String get archiveImportPauseHint =>
      'Le serie si leggono dal sito una alla volta: una pausa più lunga pesa meno sui siti.';

  @override
  String archiveImportSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String archiveImportStart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importa $count link',
      one: 'Importa un link',
    );
    return '$_temp0';
  }

  @override
  String get archiveImportStop => 'Ferma';

  @override
  String get archiveImportResume => 'Continua';

  @override
  String get archiveImportWaiting => 'In attesa';

  @override
  String get archiveImportRunning => 'In corso…';

  @override
  String get archiveImportSaved => 'Salvata come scheda';

  @override
  String archiveImportSavedReached(String chapter) {
    return 'Salvata come scheda · arrivato al $chapter';
  }

  @override
  String get archiveImportManual =>
      'Scheda manuale: Kagami non potrà scaricarne i capitoli';

  @override
  String archiveImportKnown(String title) {
    return 'Già in libreria: «$title»';
  }

  @override
  String get archiveImportQueued => 'Già in coda';

  @override
  String get archiveImportNeedsCheck => 'Il sito chiede una verifica';

  @override
  String get archiveImportVerify => 'Verifica';

  @override
  String get archiveImportRetry => 'Riprova';

  @override
  String get archiveImportCheckHint =>
      'Alcuni siti chiedono una verifica del browser: toccane uno e superala, gli altri link dello stesso sito ripartono da soli.';

  @override
  String archiveImportProgress(int done, int total) {
    return '$done di $total';
  }

  @override
  String archiveImportCountSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count schede',
      one: '1 scheda',
    );
    return '$_temp0';
  }

  @override
  String archiveImportCountManual(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count manuali',
      one: '1 manuale',
    );
    return '$_temp0';
  }

  @override
  String archiveImportCountKnown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count già presenti',
      one: '1 già presente',
    );
    return '$_temp0';
  }

  @override
  String archiveImportCountFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count errori',
      one: '1 errore',
    );
    return '$_temp0';
  }

  @override
  String archiveImportCountCheck(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count da verificare',
      one: '1 da verificare',
    );
    return '$_temp0';
  }

  @override
  String get archiveImportLeaveTitle => 'Fermare l\'import?';

  @override
  String get archiveImportLeaveBody =>
      'Le schede già salvate restano; i link che mancano non si importano.';

  @override
  String get archiveImportLeaveConfirm => 'Ferma ed esci';

  @override
  String get shareNoLinks => 'Nel testo condiviso non c\'è nessun link.';

  @override
  String dataVerifyTitle(String sites) {
    return '$sites chiede la verifica';
  }

  @override
  String dataVerifyText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Il controllo non ha potuto leggere $count serie. Tocca per passare la verifica.',
      one: 'Il controllo non ha potuto leggere una serie. Tocca per passare la verifica.',
    );
    return '$_temp0';
  }

  @override
  String archiveGatedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serie aspettano la verifica',
      one: 'Una serie aspetta la verifica',
    );
    return '$_temp0';
  }

  @override
  String archiveGatedBody(String sites) {
    return '$sites chiede di spuntare «Verify you are human», e il controllo automatico non lo fa. Passala tu: il controllo riparte da queste serie.';
  }

  @override
  String get archiveGatedAction => 'Verifica';

  @override
  String get archiveGatedNothing =>
      'La verifica non è stata passata: le serie restano in attesa.';

  @override
  String get archiveGatedChecking => 'Verifica passata, controllo le serie…';

  @override
  String archiveCheckQueuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'capitoli nuovi per $count serie',
      one: 'capitoli nuovi per una serie',
    );
    return '$_temp0';
  }
}
