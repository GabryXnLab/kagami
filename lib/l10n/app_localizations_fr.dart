// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSystem => 'Comme le système';

  @override
  String get seriesShelfNone => 'Aucun statut';

  @override
  String get seriesShelfPlanned => 'À lire';

  @override
  String get seriesShelfReading => 'En cours de lecture';

  @override
  String get seriesShelfPaused => 'En pause';

  @override
  String get seriesShelfCompleted => 'Terminée';

  @override
  String get seriesShelfDropped => 'Abandonnée';

  @override
  String get seriesReleaseOngoing => 'En cours';

  @override
  String get seriesReleaseCompleted => 'Terminée';

  @override
  String get seriesReleaseHiatus => 'En pause';

  @override
  String get seriesReleaseCancelled => 'Interrompue';

  @override
  String get seriesReleaseUnknown => 'Statut inconnu';

  @override
  String get seriesNotFound => 'Série introuvable.';

  @override
  String get seriesOfflineTitle => 'Chapitres sur Drive';

  @override
  String get seriesOfflineMessage =>
      'Sans connexion, la liste des chapitres de cette série est indisponible. Elle apparaîtra d\'elle-même dès que le réseau reviendra.';

  @override
  String get seriesNoIndexTitle => 'Aucun index';

  @override
  String get seriesNoIndexMessage =>
      'Cette série n\'a pas d\'index.json : il faut régénérer les index avec l\'archiveur qui l\'a écrite.';

  @override
  String get seriesNoChaptersTitle => 'Aucun chapitre';

  @override
  String get seriesNoChaptersMessage =>
      'Aucun chapitre ne correspond à la recherche et aux filtres choisis.';

  @override
  String seriesDownloadAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Télécharger $count chapitres ?',
      one: 'Télécharger un chapitre ?',
    );
    return '$_temp0';
  }

  @override
  String get seriesDownloadAllMessage =>
      'Tous les chapitres que tu lis actuellement depuis Drive seront copiés sur le téléphone, et tu pourras les lire aussi sans réseau.';

  @override
  String get seriesDownload => 'Télécharger';

  @override
  String seriesCleanupRemote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres lus sont encore sur Drive',
      one: 'Un chapitre lu est encore sur Drive',
    );
    return '$_temp0';
  }

  @override
  String seriesCleanupLocal(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres lus occupent $size',
      one: 'Un chapitre lu occupe $size',
    );
    return '$_temp0';
  }

  @override
  String seriesDownloadFailed(String error) {
    return 'Échec du téléchargement : $error. Réessaie';
  }

  @override
  String get seriesDownloadWaiting =>
      'En attente du réseau : reprise automatique. Annuler';

  @override
  String get seriesDownloadQueued => 'En file d\'attente. Annuler';

  @override
  String get seriesDownloadCancel => 'Annuler le téléchargement';

  @override
  String get seriesPlaceLocal => 'Sur le téléphone';

  @override
  String get seriesPlaceDrive => 'Sur Drive';

  @override
  String get seriesPlaceMixed => 'Téléphone et Drive';

  @override
  String get seriesMuteTooltipOn =>
      'Notifications des nouveaux chapitres désactivées';

  @override
  String get seriesMuteTooltipOff =>
      'Notifications des nouveaux chapitres activées';

  @override
  String get seriesMuteUnmuted =>
      'Notifications des nouveaux chapitres réactivées.';

  @override
  String get seriesMuteMuted =>
      'Notifications des nouveaux chapitres désactivées.';

  @override
  String seriesCaughtUpMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'À jour avec ce qui est sur le téléphone : il manque $count chapitres annoncés.',
      one: 'À jour avec ce qui est sur le téléphone : il manque un chapitre annoncé.',
    );
    return '$_temp0';
  }

  @override
  String get seriesCaughtUpAll => 'Tout est lu.';

  @override
  String get seriesResumeToContinue => 'À CONTINUER';

  @override
  String get seriesResumeToStart => 'À COMMENCER';

  @override
  String get seriesResumeHalfway => 'LAISSÉ EN ROUTE';

  @override
  String seriesResumePage(int page, int total) {
    return 'page $page sur $total';
  }

  @override
  String get seriesContinue => 'Continuer';

  @override
  String get seriesStart => 'Commencer';

  @override
  String get seriesResume => 'Reprendre';

  @override
  String get seriesNextChapter => 'Chapitre suivant';

  @override
  String get seriesFigureChapters => 'Chapitres';

  @override
  String get seriesFigureRead => 'Lus';

  @override
  String get seriesFigureProgress => 'Progression';

  @override
  String get seriesFigureRating => 'Note';

  @override
  String get seriesMyShelf => 'Mon étagère';

  @override
  String get seriesFavoriteOn => 'Favorite';

  @override
  String get seriesFavoriteOff => 'Favoris';

  @override
  String get seriesRatingButton => 'Note';

  @override
  String seriesRatingOutOfTen(int rating) {
    return '$rating/10';
  }

  @override
  String get seriesCollections => 'Collections';

  @override
  String get seriesNotes => 'Notes';

  @override
  String get seriesRatingSheetTitle => 'Quelle note lui donnes-tu ?';

  @override
  String get seriesNotesHint => 'Où tu en étais, ce que tu en penses…';

  @override
  String get seriesSave => 'Enregistrer';

  @override
  String get seriesRatingWord1 => 'Nul';

  @override
  String get seriesRatingWord2 => 'Mauvais';

  @override
  String get seriesRatingWord3 => 'Faible';

  @override
  String get seriesRatingWord4 => 'Médiocre';

  @override
  String get seriesRatingWord5 => 'Passable';

  @override
  String get seriesRatingWord6 => 'Correct';

  @override
  String get seriesRatingWord7 => 'Bien';

  @override
  String get seriesRatingWord8 => 'Très bien';

  @override
  String get seriesRatingWord9 => 'Excellent';

  @override
  String get seriesRatingWord10 => 'Chef-d\'œuvre';

  @override
  String get seriesRatingNone => 'Sans note';

  @override
  String get seriesRatingHint => 'Touche ou fais glisser';

  @override
  String seriesRatingBefore(int rating) {
    return 'Avant : $rating';
  }

  @override
  String get seriesRatingRemove => 'Retirer';

  @override
  String get seriesRatingSave => 'Enregistrer la note';

  @override
  String get seriesSynopsis => 'Synopsis';

  @override
  String get seriesGenres => 'Genres';

  @override
  String get seriesTags => 'Tags';

  @override
  String get seriesCreators => 'Qui l\'a faite';

  @override
  String seriesMoreTags(int count) {
    return '$count de plus';
  }

  @override
  String get seriesPaceToRead => 'À lire';

  @override
  String seriesPaceCaption(int chapters, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      chapters,
      locale: localeName,
      other: '$chapters chapitres',
      one: 'un chapitre',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages planches',
      one: 'une planche',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get seriesPaceNext => 'Prochain chapitre';

  @override
  String get seriesPaceNextCaption => 'd\'après le rythme des derniers';

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
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String get seriesWhenLate => 'en retard';

  @override
  String get seriesWhenExpected => 'attendu';

  @override
  String get seriesWhenToday => 'aujourd\'hui';

  @override
  String get seriesWhenTomorrow => 'demain';

  @override
  String seriesWhenInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans $count jours',
      one: 'dans 1 jour',
    );
    return '$_temp0';
  }

  @override
  String seriesWhenInWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans $count semaines',
      one: 'dans 1 semaine',
    );
    return '$_temp0';
  }

  @override
  String get seriesShowLess => 'Réduire';

  @override
  String get seriesShowMore => 'Tout lire';

  @override
  String get seriesChaptersTitle => 'Chapitres';

  @override
  String seriesChaptersOf(int total) {
    return 'sur $total';
  }

  @override
  String get seriesSearchChapter => 'Chercher un chapitre…';

  @override
  String get seriesSortNewest => 'Du plus récent';

  @override
  String get seriesSortOldest => 'Du premier';

  @override
  String get seriesMarkAll => 'Tout marquer';

  @override
  String get seriesDownloadFromDrive => 'Télécharger depuis Drive';

  @override
  String get seriesFreeSpace => 'Libérer de l\'espace';

  @override
  String get seriesFilterUnread => 'À lire';

  @override
  String get seriesFilterDownloaded => 'Téléchargés';

  @override
  String get seriesFilterAll => 'Tous';

  @override
  String seriesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnés',
      one: '1 sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get seriesMarkReadMany => 'Marquer comme lus';

  @override
  String get seriesMarkUnread => 'Marquer comme à lire';

  @override
  String get seriesMarkRead => 'Marquer comme lu';

  @override
  String get seriesMarkReadThrough => 'Marquer comme lu jusqu\'ici';

  @override
  String get seriesSimilar => 'Dans le même genre';

  @override
  String get seriesChapterNotDownloaded => 'Non téléchargé';

  @override
  String seriesChapterPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count planches',
      one: '1 planche',
    );
    return '$_temp0';
  }

  @override
  String get seriesDownloadToPhone => 'Télécharger sur le téléphone';

  @override
  String get readerSeriesUnavailable => 'Série indisponible.';

  @override
  String get readerNoPagesIndex =>
      'Cette série n\'a pas de pages.json : il faut régénérer les index avec l\'archiveur qui l\'a écrite.';

  @override
  String get readerSeriesOffline =>
      'Sans connexion, impossible d\'ouvrir cette série : la liste de ses planches est sur Drive. Elle s\'ouvrira dès que le réseau reviendra.';

  @override
  String get readerChapterNotOnPhone =>
      'Ce chapitre n\'est pas encore sur le téléphone. La synchronisation est peut-être à moitié faite : réessaie plus tard.';

  @override
  String get readerChapterNoPages => 'Le chapitre n\'a aucune page lisible.';

  @override
  String get readerPagesNotOnPhone =>
      'Les planches de ce chapitre ne sont pas encore sur le téléphone. L\'index les annonce, mais pas les fichiers : c\'est au dossier synchronisé de les apporter.';

  @override
  String get readerMarkEarlierTitle => 'Marquer les précédents comme lus ?';

  @override
  String readerMarkEarlierBody(int count, String chapter) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Tu as terminé $chapter. Les $count chapitres précédents sont encore à lire : si tu les as déjà lus ailleurs, marque-les tous comme lus.',
      one:
          'Tu as terminé $chapter. Le chapitre précédent est encore à lire : si tu l\'as déjà lu ailleurs, marque-le comme lu.',
    );
    return '$_temp0';
  }

  @override
  String readerMarkEarlierConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Marquer les $count comme lus',
      one: 'Marquer le précédent comme lu',
    );
    return '$_temp0';
  }

  @override
  String get readerMarkEarlierDecline => 'Les laisser à lire';

  @override
  String readerBookmarkAdded(int page) {
    return 'Page $page mise de côté';
  }

  @override
  String get readerChapters => 'Chapitres';

  @override
  String get readerBookmarks => 'Pages mises de côté';

  @override
  String get readerNoBookmarks => 'Aucune page de côté';

  @override
  String get readerNoBookmarksHint =>
      'Le marque-page retient l\'endroit d\'une planche ; celui du chapitre, c\'est déjà la reprise qui le retient.';

  @override
  String readerBookmarkPage(int page) {
    return 'page $page';
  }

  @override
  String get readerBookmarkRemove => 'Retirer';

  @override
  String get readerToTop => 'Remonter en haut';

  @override
  String get readerPageNotFromDrive => 'Planche non reçue de Drive';

  @override
  String get readerPageUnreadable => 'Planche illisible';

  @override
  String get readerPageNotSynced => 'Planche non synchronisée';

  @override
  String get readerPageNotDownloaded => 'Planche pas encore téléchargée';

  @override
  String get readerPageOfflineHint =>
      'Pas de connexion. Elle arrivera d\'elle-même dès que le réseau reviendra.';

  @override
  String get readerRetryNow => 'Réessayer';

  @override
  String get readerLastChapterOnPhone =>
      'C\'est le dernier chapitre présent sur le téléphone.';

  @override
  String get readerNextChapter => 'Chapitre suivant';

  @override
  String get readerContinue => 'Continuer';

  @override
  String get readerBookmarkThisPage => 'Mettre cette page de côté';

  @override
  String get readerHowToRead => 'Comment lire';

  @override
  String get readerPreviousChapter => 'Chapitre précédent';

  @override
  String get readerNextChapterTooltip => 'Chapitre suivant';

  @override
  String get readerSearchChapter => 'Chercher un chapitre…';

  @override
  String get readerNewestFirst => 'Du plus récent';

  @override
  String get readerOldestFirst => 'Du premier';

  @override
  String readerReadingNow(String current, int total) {
    return 'En lecture : $current / $total chapitres';
  }

  @override
  String get readerMode => 'Mode de lecture';

  @override
  String get readerModeStrip => 'Bande';

  @override
  String get readerModePage => 'Page';

  @override
  String get readerDirection => 'Sens de lecture';

  @override
  String get readerDirectionLtr => 'Gauche → droite';

  @override
  String get readerDirectionRtl => 'Droite → gauche';

  @override
  String get readerFit => 'Ajustement';

  @override
  String get readerBackground => 'Arrière-plan';

  @override
  String get readerBrightness => 'Luminosité';

  @override
  String get readerAutoScroll => 'Défilement automatique';

  @override
  String get readerAutoScrollOff => 'désactivé';

  @override
  String readerAutoScrollRate(int rate) {
    return '$rate planches/min';
  }

  @override
  String get readerShowPageNumber => 'Numéro de page';

  @override
  String get readerShowProgress => 'Barre de progression';

  @override
  String get readerShowScrollTop => 'Bouton pour remonter en haut';

  @override
  String get readerKeepAwake => 'Garder l\'écran allumé';

  @override
  String get readerDoublePage => 'Deux planches côte à côte';

  @override
  String get readerLockRotation => 'Verrouiller la rotation';

  @override
  String get archiveTitle => 'Télécharger un manga';

  @override
  String get archiveIntro =>
      'Cherche un titre sur les sites pris en charge, ou colle le lien d\'une série : Kagami la télécharge depuis le site, avec ses métadonnées, sa couverture et la liste complète des chapitres, dans la bibliothèque.';

  @override
  String get archiveSearchHint => 'Chercher un manga par titre';

  @override
  String get archiveClear => 'Effacer';

  @override
  String get archivePaste => 'Coller';

  @override
  String get archiveReading => 'Lecture de la série…';

  @override
  String get archiveVerify => 'Vérifier la série';

  @override
  String archiveSeriesSummary(String site, int count, String status) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres',
      one: '1 chapitre',
    );
    return '$site · $_temp0 · $status';
  }

  @override
  String get archiveWhatSection => 'Quoi télécharger';

  @override
  String get archiveModeAll => 'Toute';

  @override
  String get archiveModeFrom => 'Dès le chapitre';

  @override
  String get archiveModePick => 'Sélection';

  @override
  String get archiveModeAllHint =>
      'Tous les chapitres. Si tu recommences plus tard, seuls les nouveaux ou les abîmés arrivent.';

  @override
  String get archiveModeFromHint =>
      'À partir du chapitre choisi : les précédents restent dans la liste de la série, marqués comme non téléchargés.';

  @override
  String get archiveModePickHint =>
      'Seulement les chapitres que tu touches. Les autres restent dans la liste, non téléchargés.';

  @override
  String get archiveChooseTitle => 'Quoi télécharger';

  @override
  String get archiveModeAhead => 'Au fil de la lecture';

  @override
  String get archiveModeAllLine => 'Chaque chapitre, une seule fois';

  @override
  String archiveModeAheadLine(int count) {
    return '$count prêts, puis un par chapitre lu';
  }

  @override
  String get archiveModeFromLine => 'D\'un chapitre jusqu\'au dernier';

  @override
  String get archiveModePickLine => 'Seulement ceux que vous touchez';

  @override
  String archiveModeAheadHint(int count) {
    return 'Télécharge $count chapitres à partir de celui choisi. Chaque chapitre lu en apporte un nouveau, pour en avoir toujours $count à lire, jusqu\'à la fin de la série ; quand le site en publie d\'autres, ils arrivent de la même façon.';
  }

  @override
  String get archiveModeAheadUnavailable =>
      'Impossible avec ce site : il demande la vérification du navigateur à chaque visite, et le téléphone ne peut pas la passer seul.';

  @override
  String get archiveModeAheadServer =>
      'Le serveur lié ne sait pas encore télécharger au fil de la lecture : il se met à jour seul dans l\'heure qui suit une nouvelle version. En attendant, ce mode télécharge depuis le téléphone.';

  @override
  String get archiveChapterSearch => 'Rechercher par numéro ou titre';

  @override
  String get archiveNewestFirst => 'Plus récents d\'abord';

  @override
  String get archiveOldestFirst => 'Depuis le premier';

  @override
  String get archiveChooseStart => 'Touchez le chapitre de départ.';

  @override
  String get archiveSelectMissing => 'Ceux qui manquent';

  @override
  String get archiveRangeHint =>
      'Appuyez longuement sur un chapitre pour prendre aussi tous ceux entre lui et le dernier touché.';

  @override
  String get archivePickNone => 'Aucun chapitre choisi';

  @override
  String archiveSummaryChapters(int count, String where) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres',
      one: '1 chapitre',
    );
    return '$_temp0 · $where';
  }

  @override
  String archiveSummaryAhead(int count, String where) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres tout de suite',
      one: '1 chapitre tout de suite',
    );
    return '$_temp0, puis un par chapitre lu · $where';
  }

  @override
  String archiveDownloadAhead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Télécharger $count chapitres, puis au fil de la lecture',
      one: 'Télécharger 1 chapitre, puis au fil de la lecture',
    );
    return '$_temp0';
  }

  @override
  String archiveInLibraryCount(int archived, int total) {
    return 'Dans la bibliothèque : $archived sur $total';
  }

  @override
  String get archiveChapterInLibrary => 'dans la bibliothèque';

  @override
  String get archiveChapterStart => 'on commence ici';

  @override
  String get archiveChapterLater => 'arrivera en lisant';

  @override
  String get archiveAdvanced => 'Avancé';

  @override
  String archiveAdvancedLine(String pause) {
    return 'Pause entre les requêtes : $pause';
  }

  @override
  String get archiveReopen => 'Choisir quoi télécharger';

  @override
  String get archiveSelectAll => 'Tous';

  @override
  String get archiveSelectNone => 'Aucun';

  @override
  String get archiveWhereSection => 'Où';

  @override
  String get archiveWhereServer => 'Serveur';

  @override
  String get archiveWhereDrive => 'Drive';

  @override
  String get archiveWhereDriveAndPhone => 'Drive et téléphone';

  @override
  String get archiveWherePhone => 'Téléphone';

  @override
  String get archiveWhereDriveHint =>
      'Dans le dossier Drive de la bibliothèque. Les planches passent par le téléphone et repartent dès que Drive les a : tu les lis en streaming, ou tu les télécharges ensuite.';

  @override
  String get archiveWhereDriveAndPhoneHint =>
      'Dans le dossier Drive de la bibliothèque, et les chapitres restent aussi sur le téléphone pour les lire sans réseau.';

  @override
  String get archiveWherePhoneHint =>
      'Sur le téléphone, dans le dossier des mangas ou dans l\'espace de l\'appli. En connectant Drive, tu peux télécharger directement là-bas.';

  @override
  String archiveServerHint(String name, String folder, String other) {
    String _temp0 = intl.Intl.selectLogic(other, {
      'other': ' Attention : ce n\'est pas le dossier que lit l\'appli.',
      'same': '',
    });
    return '« $name » la télécharge et la charge dans « $folder » sur Drive, même téléphone éteint. Le serveur suit les séries en cours.$_temp0';
  }

  @override
  String get archiveDelaySection => 'Pause entre les requêtes';

  @override
  String get archiveDelayNone => 'Aucune';

  @override
  String archiveDelaySeconds(String seconds) {
    return '$seconds s';
  }

  @override
  String get archiveDelayHint =>
      'Les sites n\'aiment pas les téléchargements en rafale : une courte pause évite de se faire bloquer.';

  @override
  String get archiveDownloadAll => 'Télécharger toute la série';

  @override
  String archiveDownloadPicked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Télécharger $count chapitres',
      one: 'Télécharger 1 chapitre',
    );
    return '$_temp0';
  }

  @override
  String archiveNoResults(String site) {
    return 'Aucun résultat sur $site.';
  }

  @override
  String archiveChaptersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres',
      one: '1 chapitre',
    );
    return '$_temp0';
  }

  @override
  String archiveVerifySite(String site) {
    return 'Vérifier $site';
  }

  @override
  String get archiveVerifySiteHint =>
      'Le site veut s\'assurer que tu es une personne : touche pour ouvrir la vérification, puis cherche là aussi';

  @override
  String get archiveStatusOngoing => 'en cours';

  @override
  String get archiveStatusCompleted => 'terminée';

  @override
  String get archiveStatusHiatus => 'en pause';

  @override
  String get archiveStatusCancelled => 'interrompue';

  @override
  String get archiveStatusUnknown => 'statut inconnu';

  @override
  String get archiveErrChallenge =>
      'Le site demande une vérification impossible à faire d\'ici.';

  @override
  String get archiveErrOffline => 'Pas de connexion : le site ne répond pas.';

  @override
  String get archiveErrVerifyIncomplete =>
      'La vérification du site n\'a pas été terminée.';

  @override
  String archiveQueuedSnack(String title) {
    return '« $title » est en file d\'attente. Le téléchargement continue même écran éteint.';
  }

  @override
  String archiveQueuedServerSnack(String title, String server) {
    return '« $title » est en file d\'attente sur « $server ». Le téléphone peut même s\'éteindre.';
  }

  @override
  String get archiveServerFallbackName => 'serveur';

  @override
  String get archiveDownloads => 'Téléchargements';

  @override
  String get archiveClearHistory => 'Nettoyer';

  @override
  String get archiveQueueStopped => 'File à l\'arrêt';

  @override
  String get archiveQueueResumeHint =>
      'Elle repart d\'elle-même ; touche pour la lancer maintenant';

  @override
  String archiveJobAutomatic(String destination) {
    return 'Nouveaux chapitres · $destination';
  }

  @override
  String archiveJobQueued(String destination) {
    return 'En file d\'attente · $destination';
  }

  @override
  String get archiveRemoveFromQueue => 'Retirer de la file';

  @override
  String archiveHistoryLine(String when, String message) {
    return '$when · $message';
  }

  @override
  String get archiveRecent => 'Téléchargées récemment';

  @override
  String archiveRecentLineRuns(String when, int runs, String message) {
    return '$when · $runs téléchargements · $message';
  }

  @override
  String get archiveRetry => 'Réessayer';

  @override
  String archiveJobAhead(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres',
      one: '1 chapitre',
    );
    return 'Au fil de la lecture : $_temp0 · $destination';
  }

  @override
  String get archiveSites => 'Sites pris en charge';

  @override
  String get archiveMoreSites =>
      'D\'autres sites arrivent : la prise en charge de nouveaux fournisseurs viendra avec les prochaines mises à jour.';

  @override
  String archiveLinkCopied(String url) {
    return '$url copié dans le presse-papiers.';
  }

  @override
  String get archiveTracked => 'Séries en cours';

  @override
  String get archiveTrackedIntro =>
      'Les séries en cours téléchargées d\'ici sont revérifiées : seuls les nouveaux chapitres arrivent, dans la même destination. Celles du serveur sont suivies par le serveur.';

  @override
  String get archiveCheckDaily => 'Vérification quotidienne';

  @override
  String get archiveCheckManual => 'À la main seulement';

  @override
  String archiveCheckAt(String time) {
    return 'À $time, même appli fermée';
  }

  @override
  String get archiveCheckTime => 'Heure';

  @override
  String get archiveCheckTimeHelp => 'Heure de la vérification';

  @override
  String get archiveWifiOnly => 'Wi-Fi uniquement';

  @override
  String get archiveWifiOnlyOn =>
      'Attend un réseau qui n\'est pas facturé à la consommation';

  @override
  String get archiveWifiOnlyOff => 'Aussi avec les données mobiles';

  @override
  String get archiveCheckNow => 'Vérifier maintenant';

  @override
  String get archiveNoTracked => 'Aucune série à suivre pour l\'instant';

  @override
  String archiveTrackedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries à suivre',
      one: '1 série à suivre',
    );
    return '$_temp0';
  }

  @override
  String archiveTrackedLine(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres connus',
      one: '1 chapitre connu',
    );
    return '$_temp0 · $destination';
  }

  @override
  String archiveTrackedLineChecked(int count, String destination, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres connus',
      one: '1 chapitre connu',
    );
    return '$_temp0 · $destination · vérifiée $when';
  }

  @override
  String archiveTrackedAhead(int count, String destination) {
    return 'Au fil de la lecture, $count prêts à lire · $destination';
  }

  @override
  String get archiveStopFollowing => 'Ne plus la suivre';

  @override
  String archiveCheckQueued(String names) {
    return 'nouveaux chapitres pour $names';
  }

  @override
  String archiveCheckRemoved(String names) {
    return '$names maintenant terminée';
  }

  @override
  String archiveCheckFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inaccessibles',
      one: '1 inaccessible',
    );
    return '$_temp0';
  }

  @override
  String get archiveCheckSeparator => ' ; ';

  @override
  String archiveCheckReport(String parts) {
    return '$parts.';
  }

  @override
  String get archiveNoNewChapters => 'Aucun nouveau chapitre.';

  @override
  String get archiveNoConnection => 'Pas de connexion.';

  @override
  String get archiveForgetTitle => 'Ne plus la suivre ?';

  @override
  String archiveForgetBody(String title) {
    return 'Les nouveaux chapitres de « $title » n\'arriveront plus d\'eux-mêmes. Ceux déjà téléchargés restent.';
  }

  @override
  String get archiveCancel => 'Annuler';

  @override
  String get archiveForgetConfirm => 'Arrêter';

  @override
  String get archiveStartNoMatch => 'Aucun chapitre avec ce numéro.';

  @override
  String get browserTitle => 'Vérification du site';

  @override
  String get browserPhoneOnly =>
      'La vérification se fait uniquement depuis le téléphone.';

  @override
  String get browserInstructionsChapters =>
      'Le site veut s\'assurer que tu es une personne. Termine la vérification : quand la liste des chapitres apparaît, Kagami s\'en aperçoit et revient en arrière automatiquement.';

  @override
  String get browserInstructionsSearch =>
      'Le site veut s\'assurer que tu es une personne. Termine la vérification : quand la recherche du site apparaît, Kagami s\'en aperçoit et revient en arrière automatiquement.';

  @override
  String get browserSearchPhoneOnly =>
      'Sur ce site, on ne peut chercher que depuis le téléphone.';

  @override
  String get browserSearchSuperseded =>
      'Remplacée par une recherche plus récente.';

  @override
  String get browserResponseTooLarge => 'Réponse trop volumineuse.';

  @override
  String get serverTitle => 'Serveur';

  @override
  String get serverClear => 'Nettoyer';

  @override
  String get serverUnavailableNoSecret =>
      'Cette version de l\'appli ne peut pas connecter de serveur : la personne qui l\'a compilée n\'a pas indiqué le secret du client Web (GOOGLE_SERVER_CLIENT_SECRET).';

  @override
  String get serverUnavailableAndroidOnly =>
      'On ne peut connecter un serveur que depuis Android.';

  @override
  String get serverSignInRequired =>
      'Connecte-toi avec Google pour utiliser le serveur.';

  @override
  String get serverNoConnection => 'Pas de connexion.';

  @override
  String get serverMissingGoogleServices =>
      'google-services.json est absent : cette version n\'a pas le client Google.';

  @override
  String get serverDriveAccessDenied =>
      'Google n\'a pas accordé l\'accès à Drive.';

  @override
  String get serverGoogleNotResponding =>
      'Google ne répond pas : réessaie dans un instant.';

  @override
  String serverWhenToday(String clock) {
    return 'aujourd\'hui à $clock';
  }

  @override
  String serverWhenDate(String date, String clock) {
    return '$date à $clock';
  }

  @override
  String serverProgressStats(int pages, String size, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: ' · $skipped déjà en place',
      zero: '',
    );
    return '$pages nouvelles planches · $size$_temp0';
  }

  @override
  String get serverRemoveFromQueue => 'Retirer de la file';

  @override
  String get serverNoFirebase =>
      'Le serveur reconnaît ses utilisateurs grâce au compte Google, qui n\'existe pas dans cette version de l\'appli.';

  @override
  String get serverSignedOutIntro =>
      'Un ordinateur toujours allumé peut télécharger et charger sur ton Drive à la place du téléphone, qui peut pendant ce temps s\'éteindre. Le serveur te reconnaît grâce à ton compte Google.';

  @override
  String get serverSignIn => 'Se connecter avec Google';

  @override
  String get serverSignInSubtitle =>
      'Pour créer ton serveur ou utiliser celui de quelqu\'un d\'autre';

  @override
  String serverInviteTitle(String sender, String serverName) {
    return '$sender t\'a donné accès à « $serverName »';
  }

  @override
  String get serverInviteSubtitle =>
      'Télécharge sur ton Drive, même téléphone éteint. Touche pour le connecter';

  @override
  String get serverIgnore => 'Ignorer';

  @override
  String get serverLinkIntro =>
      'Un ordinateur toujours allumé — le tien ou celui de la personne qui t\'a donné accès — peut télécharger et charger sur ton Drive à la place du téléphone, qui peut pendant ce temps s\'éteindre.';

  @override
  String get serverCreate => 'Crée ton serveur';

  @override
  String get serverCreateSubtitle =>
      'Une commande à coller sur un ordinateur avec Docker : rien à configurer';

  @override
  String get serverLinkTitle => 'Connecter un serveur';

  @override
  String get serverLinkSubtitle =>
      'Le tien, déjà allumé, ou celui de la personne qui t\'a ajouté';

  @override
  String get serverStateConnecting => 'Connexion…';

  @override
  String get serverStateNoGrant =>
      'N\'a pas encore l\'autorisation d\'accéder à ton Drive';

  @override
  String get serverStateNoFolder =>
      'Ne sait pas encore dans quel dossier de ton Drive écrire';

  @override
  String serverStateReady(String folder) {
    return 'Prêt · écrit dans « $folder » sur ton Drive';
  }

  @override
  String serverTileSubtitle(String address, String state) {
    return '$address · $state';
  }

  @override
  String serverTileSubtitleOwner(String address, String owner, String state) {
    return '$address · de $owner · $state';
  }

  @override
  String get serverPlainTitle => 'La connexion n\'est pas chiffrée';

  @override
  String get serverPlainSubtitle =>
      'Le jeton de ton compte circule en clair : il faut du HTTPS (Tailscale Funnel, un reverse proxy)';

  @override
  String get serverGrantTitle => 'Donne ton Drive au serveur';

  @override
  String get serverGrantSubtitle =>
      'Il téléchargera dans le dossier que lit l\'appli, même téléphone éteint';

  @override
  String get serverUseAppFolder => 'Utiliser le dossier de l\'appli';

  @override
  String serverUseAppFolderSubtitle(String serverFolder, String appFolder) {
    return 'Le serveur écrit dans « $serverFolder », l\'appli lit « $appFolder »';
  }

  @override
  String get serverUsersTitle => 'Qui peut l\'utiliser';

  @override
  String get serverUsersOnlyYou =>
      'Toi seul. Ajoute le compte Google de qui tu veux';

  @override
  String serverUsersCount(int count) {
    return '$count comptes, toi compris';
  }

  @override
  String get serverQueueWaiting => 'File en attente';

  @override
  String get serverQueueRestarts => 'Le serveur repart tout seul';

  @override
  String get serverJobAutomatic => 'Nouveaux chapitres · sur le serveur';

  @override
  String get serverJobQueued => 'En file d\'attente · sur le serveur';

  @override
  String serverJobAhead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres',
      one: '1 chapitre',
    );
    return 'Au fil de la lecture : $_temp0';
  }

  @override
  String serverSeriesAhead(int count) {
    return 'Au fil de la lecture, $count prêts à lire : l\'app demande les chapitres pendant que vous lisez';
  }

  @override
  String get serverOngoingTitle => 'Séries en cours sur le serveur';

  @override
  String serverOngoingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count à suivre',
      zero: 'Aucune pour l\'instant',
    );
    return '$_temp0';
  }

  @override
  String get serverOngoingCheckOff => 'vérification désactivée';

  @override
  String serverOngoingCheckAt(String clock) {
    return 'vérification à $clock';
  }

  @override
  String serverOngoingSubtitle(String count, String check) {
    return '$count · $check. Touche pour vérifier maintenant';
  }

  @override
  String serverSeriesKnown(int count) {
    return '$count chapitres connus';
  }

  @override
  String serverSeriesKnownChecked(int count, String when) {
    return '$count chapitres connus · vérifiée $when';
  }

  @override
  String get serverStopFollowing => 'Ne plus la suivre';

  @override
  String get serverInviteRemoveFailed =>
      'Impossible de retirer l\'invitation : réessaie.';

  @override
  String get serverCheckingNow =>
      'Le serveur vérifie : les nouveaux chapitres apparaissent dans sa file.';

  @override
  String get serverPaste => 'Coller';

  @override
  String get serverAddressExposed =>
      'Attention : en clair sur une adresse publique, le jeton de ton compte circule à la vue de tous. Utilise HTTPS (Tailscale Funnel, un reverse proxy) ou Tailscale.';

  @override
  String get serverAddressSavedNote =>
      'L\'adresse voyage avec la sauvegarde et avec le compte, comme le dossier de Drive.';

  @override
  String get serverAddressMissing =>
      'Saisis l\'adresse du serveur, par exemple http://192.168.1.20:8080.';

  @override
  String serverLinked(String name, String folder) {
    return 'Connecté à « $name » : il télécharge dans « $folder » sur ton Drive.';
  }

  @override
  String serverLinkFromInvite(String sender, String serverName) {
    return '$sender t\'a ajouté à « $serverName ». Une fois connecté, le serveur téléchargera les mangas que tu choisis dans le dossier de ta bibliothèque sur ton Drive : Google te demandera de l\'autoriser à y écrire. La personne qui gère le serveur pourra utiliser cette autorisation.';
  }

  @override
  String serverLinkLinked(String account) {
    return 'Le serveur te reconnaît en tant que $account. Si tu le déconnectes et qu\'il n\'est pas à toi, il oublie aussi l\'autorisation sur ton Drive et ta file.';
  }

  @override
  String get serverSignedInAccount => 'le compte avec lequel tu t\'es connecté';

  @override
  String get serverLinkNew =>
      'Saisis l\'adresse du serveur : le tien, ou celui que t\'a donné la personne qui t\'a ajouté. Le serveur te reconnaît grâce au compte Google, et la première fois tu lui donnes l\'autorisation d\'écrire dans le dossier de ta bibliothèque sur Drive.';

  @override
  String get serverVerifying => 'Vérification…';

  @override
  String get serverVerifyAgain => 'Vérifier à nouveau';

  @override
  String get serverVerifyAndLink => 'Vérifier et connecter';

  @override
  String get serverUnlink => 'Déconnecter';

  @override
  String get serverDefaultNameOwn => 'Mon Kagami Server';

  @override
  String serverDefaultNameOf(String name) {
    return 'Le serveur de $name';
  }

  @override
  String get serverCommandCopied => 'Commande copiée.';

  @override
  String get serverComputerAddressMissing =>
      'Saisis l\'adresse de l\'ordinateur, par exemple http://192.168.1.20:8080.';

  @override
  String serverNotOwner(String owner) {
    return 'Ce serveur est celui de $owner : il est connecté, mais tu ne l\'as pas créé.';
  }

  @override
  String serverReady(String name) {
    return '« $name » est prêt. Ajoute qui tu veux depuis « Qui peut l\'utiliser ».';
  }

  @override
  String get serverLibraryFolderFallback => 'le dossier de la bibliothèque';

  @override
  String serverSetupIntro(String folder) {
    return 'Il te faut un ordinateur qui reste allumé — un mini PC, un NAS, un Raspberry Pi, un serveur en ligne — avec Docker. Le serveur télécharge les mangas et les charge sur ton Drive, dans « $folder », même téléphone éteint.';
  }

  @override
  String serverPrepareIntro(String signIn, String folder) {
    String _temp0 = intl.Intl.selectLogic(signIn, {
      'yes': 'd\'abord tu te connectes avec Google, puis ',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(folder, {
      'yes': 'tu choisis le dossier des mangas sur Drive, puis ',
      'other': '',
    });
    return 'Je prépare une commande qui contient tout : $_temp0${_temp1}Google te demande d\'autoriser le serveur à écrire sur ton Drive.';
  }

  @override
  String get serverPreparing => 'Préparation…';

  @override
  String get serverGenerate => 'Générer la commande';

  @override
  String get serverStep1 =>
      'Installe Docker sur l\'ordinateur (docker.com), s\'il n\'y est pas déjà.';

  @override
  String get serverStep2 =>
      'Colle ces commandes dans son terminal : la première démarre le serveur, la seconde le tient à jour toute seule. Elles contiennent l\'autorisation d\'accéder à ton Drive : ne les envoie à personne.';

  @override
  String get serverCopyCommand => 'Copier la commande';

  @override
  String get serverStep3 =>
      'Saisis ici l\'adresse de l\'ordinateur : à la maison, celle du réseau local ; à l\'extérieur, son nom dans Tailscale ou l\'adresse HTTPS par laquelle tu l\'exposes.';

  @override
  String get serverPortNote => 'Le serveur répond sur le port 8080.';

  @override
  String get serverUsersIntro =>
      'Ajoute le compte Google de qui tu veux. L\'invitation apparaîtra dans son appli Kagami : une fois le serveur connecté, ses téléchargements iront sur son Drive, avec sa propre file.';

  @override
  String get serverUserEmailInvalid =>
      'Saisis l\'adresse du compte Google, par exemple nom@gmail.com.';

  @override
  String serverUserAdded(String email) {
    return '$email peut utiliser le serveur : son appli le lui indique.';
  }

  @override
  String serverRemoveTitle(String email) {
    return 'Retirer $email ?';
  }

  @override
  String get serverRemoveBody =>
      'Cette personne ne pourra plus utiliser le serveur. Sa file et l\'autorisation d\'accéder à son Drive sont supprimées ; ce qui est déjà sur son Drive reste.';

  @override
  String get serverCancel => 'Annuler';

  @override
  String get serverRemove => 'Retirer';

  @override
  String get serverAdd => 'Ajouter';

  @override
  String get serverOwnerYou => 'Toi, le propriétaire';

  @override
  String get serverConnected => 'A connecté le serveur';

  @override
  String get serverInvitedPending =>
      'Invité, n\'a pas encore connecté le serveur';

  @override
  String get setupIntro =>
      'Lit le dossier des mangas que la synchronisation dépose sur le téléphone, ou la même bibliothèque directement depuis Google Drive, sans tout rapatrier ici.';

  @override
  String get setupAccessTitle => 'Accès aux fichiers';

  @override
  String get setupAccessBody =>
      'Le dossier se trouve hors de l\'espace privé de l\'appli et contient des dizaines de milliers d\'images : Kagami a besoin de les lire directement. Il n\'écrit que les copies des données dans le sous-dossier reading/ de la bibliothèque et, si tu le demandes, les chapitres que tu télécharges depuis Drive.';

  @override
  String get setupGrantAccess => 'Accorder l\'accès';

  @override
  String get setupFolderTitle => 'Le dossier';

  @override
  String get setupFolderBody =>
      'Indique le dossier synchronisé par FolderSync : celui qui contient library.json et un sous-dossier par série.';

  @override
  String get setupChooseFolder => 'Choisir le dossier';

  @override
  String get setupOr => 'ou';

  @override
  String get setupDriveTitle => 'Google Drive';

  @override
  String get setupDriveBody =>
      'Tu te connectes avec Google et tu choisis le dossier de la bibliothèque sur Drive : les planches arrivent pendant la lecture, et les chapitres que tu veux toujours avoir sous la main se téléchargent d\'une touche. L\'accès aux fichiers du téléphone n\'est pas nécessaire.';

  @override
  String get setupReadFromDrive => 'Lire depuis Google Drive';

  @override
  String get setupLibraryProblemTitle => 'Bibliothèque illisible';

  @override
  String get setupChangeFolder => 'Changer de dossier';

  @override
  String get driveFolderSheetTitle => 'Dossier sur Drive';

  @override
  String get driveDestinationTitle => 'Où enregistrer les mangas ?';

  @override
  String get driveDestinationBody =>
      'Il n\'y a pas de dossier pour les mangas sur le téléphone. Dans un dossier, les chapitres téléchargés restent même si l\'appli est désinstallée, et Kagami les lit avec ceux qui s\'y trouvent déjà. Dans l\'espace de l\'appli, aucune autorisation n\'est nécessaire, mais ils disparaissent avec elle.';

  @override
  String get driveChooseFolder => 'Choisir un dossier';

  @override
  String get driveInAppSpace => 'Dans l\'espace de l\'appli';

  @override
  String get driveMyDrive => 'Mon Drive';

  @override
  String get driveSharedWithMe => 'Partagés avec moi';

  @override
  String get driveBack => 'Retour';

  @override
  String get driveNoResponse => 'Drive ne répond pas';

  @override
  String get driveRetry => 'Réessayer';

  @override
  String get driveIsLibrary =>
      'Contient library.json : c\'est une bibliothèque';

  @override
  String get driveNotLibrary =>
      'Ne contient pas library.json : la bibliothèque est le dossier qui le contient';

  @override
  String get driveUseFolder => 'Utiliser ce dossier';

  @override
  String get driveNoFolders => 'Aucun dossier ici';

  @override
  String get driveNoticeAuthRequired =>
      'Kagami n\'a pas encore l\'autorisation de lire Google Drive';

  @override
  String get driveAuthorize => 'Autoriser';

  @override
  String get driveSignIn => 'Se connecter';

  @override
  String get driveNoticeOffline =>
      'Tu es hors ligne : tu peux lire les chapitres sur le téléphone et les planches de Drive déjà téléchargées. Le reste reviendra tout seul avec le réseau';

  @override
  String driveNoticeError(String message) {
    return 'Drive : $message. Tu vois ce qui est sur le téléphone';
  }

  @override
  String get syncSummaryOff => 'Désactivée';

  @override
  String get syncSummaryDownload => 'De Drive vers le téléphone';

  @override
  String get syncSummaryUpload => 'Du téléphone vers Drive';

  @override
  String get syncSummaryBoth => 'Dans les deux sens';

  @override
  String syncSummaryManual(String direction) {
    return '$direction, à la main';
  }

  @override
  String syncSummaryDaily(String direction, String time) {
    return '$direction, tous les jours à $time';
  }

  @override
  String get syncTitle => 'Synchronisation';

  @override
  String get syncIntro =>
      'Garde identiques le dossier des mangas sur le téléphone et celui sur Drive, sans FolderSync. Si tu l\'utilises encore sur ce dossier, désactive-le : deux synchronisations sur les mêmes fichiers se marchent sur les pieds.';

  @override
  String get syncFolders => 'Dossiers';

  @override
  String get syncOnPhone => 'Sur le téléphone';

  @override
  String get syncNoFolderChosen => 'Aucun dossier choisi';

  @override
  String get syncOnDrive => 'Sur Drive';

  @override
  String get syncDriveNotConnected => 'Drive n\'est pas connecté';

  @override
  String get syncDirection => 'Sens';

  @override
  String get syncDirectionOff => 'Désactivée';

  @override
  String get syncDirectionFromDrive => 'Depuis Drive';

  @override
  String get syncDirectionToDrive => 'Vers Drive';

  @override
  String get syncDirectionBoth => 'Les deux';

  @override
  String get syncDescOff =>
      'Rien ne bouge tout seul. La bibliothèque de Drive se lit quand même, et « Télécharger » fonctionne comme d\'habitude.';

  @override
  String get syncDescDownload =>
      'Ce qui arrive sur Drive descend sur le téléphone. Rien ne monte depuis le téléphone.';

  @override
  String get syncDescUpload =>
      'Ce qui est sur le téléphone monte sur Drive — par exemple les copies des données dans reading/backup. Les index de la bibliothèque restent ceux du serveur.';

  @override
  String get syncDescBoth =>
      'Ce qui change d\'un côté arrive de l\'autre ; si ça a changé des deux côtés, le plus récent l\'emporte. Les index de la bibliothèque ne font que descendre : ils sont ceux du serveur.';

  @override
  String get syncDeletions => 'Propager les suppressions';

  @override
  String get syncDeletionsDownload =>
      'Retire du téléphone ce qui disparaît de Drive';

  @override
  String get syncDeletionsUpload =>
      'Met dans la corbeille de Drive ce que tu retires du téléphone';

  @override
  String get syncDeletionsBoth =>
      'D\'un côté à l\'autre ; depuis Drive, seulement dans la corbeille';

  @override
  String get syncDeletionsOnNote =>
      '« Libérer de l\'espace » retire aussi les chapitres lus de Drive, au prochain passage.';

  @override
  String get syncDeletionsOffNote =>
      'Un fichier retiré d\'un côté reste de l\'autre et ne revient pas : « Libérer de l\'espace » libère le téléphone et laisse les chapitres sur Drive.';

  @override
  String get syncDaily => 'Tous les jours';

  @override
  String get syncScheduled => 'Synchronisation programmée';

  @override
  String get syncManualOnly => 'À la main seulement';

  @override
  String syncAtTime(String time) {
    return 'À $time, même appli fermée';
  }

  @override
  String get syncTime => 'Heure';

  @override
  String get syncWifiOnly => 'Wi-Fi uniquement';

  @override
  String get syncWifiOnlyOn =>
      'Attend un réseau qui n\'est pas facturé à la consommation';

  @override
  String get syncWifiOnlyOff => 'Aussi avec les données mobiles';

  @override
  String get syncScheduleNote =>
      'Android choisit le moment exact : si le réseau manque à l\'heure choisie, le passage démarre dès son retour.';

  @override
  String get syncNow => 'Maintenant';

  @override
  String get syncTimePickerHelp => 'Heure de la synchronisation';

  @override
  String get syncRunNow => 'Synchroniser maintenant';

  @override
  String get syncRunNowReady =>
      'Tu peux continuer à lire : les copies avancent toutes seules';

  @override
  String get syncRunNowNotReady =>
      'Il faut le dossier du téléphone et celui de Drive';

  @override
  String get syncPhaseListing => 'Je regarde ce qu\'il y a sur Drive…';

  @override
  String get syncPhaseComparing => 'Comparaison avec le téléphone…';

  @override
  String get syncPhaseNothing => 'Rien à copier';

  @override
  String syncPhaseFiles(int done, int total) {
    return 'Fichier $done sur $total';
  }

  @override
  String get syncStop => 'Interrompre';

  @override
  String get syncNever => 'Jamais synchronisée';

  @override
  String get syncNeverNote =>
      'Le premier passage sur un dossier déjà plein est rapide : les fichiers identiques se reconnaissent à leur taille';

  @override
  String syncLastScheduled(String date, String time) {
    return 'Dernière, programmée : $date à $time';
  }

  @override
  String syncLastManual(String date, String time) {
    return 'Dernière, à la main : $date à $time';
  }

  @override
  String syncOutcomeDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count téléchargés',
      one: '$count téléchargé',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeUploaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chargés',
      one: '$count chargé',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeDeletedLocal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count retirés du téléphone',
      one: '$count retiré du téléphone',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeTrashed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dans la corbeille de Drive',
      one: '$count dans la corbeille de Drive',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count en échec, nouvel essai prévu',
      one: '$count en échec, nouvel essai prévu',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeErrorSoFar(String error, String done) {
    return '$error. Jusque-là : $done';
  }

  @override
  String get syncOutcomeAligned => 'Tout était déjà aligné';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeSystem => 'Comme le système';

  @override
  String get settingsLibrary => 'Bibliothèque';

  @override
  String get settingsFolder => 'Dossier';

  @override
  String get settingsNoFolder => 'Aucun dossier choisi';

  @override
  String get settingsReloadIndexes => 'Relire les index';

  @override
  String get settingsReloadIndexesNote =>
      'À faire quand la synchronisation vient d\'apporter du nouveau';

  @override
  String get settingsIndexesReloaded => 'Index relus';

  @override
  String get settingsGoogleDrive => 'Google Drive';

  @override
  String get settingsReading => 'Lecture';

  @override
  String get settingsAccount => 'Compte';

  @override
  String get settingsData => 'Données';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsLibraryNote => 'Dossier, index et Google Drive';

  @override
  String get settingsLibraryNoteLocal => 'Dossier et index';

  @override
  String get settingsReadingNote => 'Mode par défaut et mesures du lecteur';

  @override
  String get settingsAccountNote => 'Connexion Google et synchronisation';

  @override
  String get settingsDataNote => 'Sauvegardes, restauration et effacement';

  @override
  String get settingsAutoBackup => 'Copie automatique dans la bibliothèque';

  @override
  String get settingsAutoBackupNote =>
      'Une fois par jour dans reading/backup/, que la synchronisation envoie sur Drive avec les mangas';

  @override
  String get settingsExport => 'Exporter les données';

  @override
  String get settingsExportNote =>
      'Statuts, notes, historique, collections et marque-pages dans un fichier';

  @override
  String get settingsExportDialog => 'Où enregistrer la sauvegarde';

  @override
  String get settingsExportCancelled => 'Exportation annulée';

  @override
  String get settingsExportSaved => 'Sauvegarde enregistrée';

  @override
  String get settingsImport => 'Importer depuis une sauvegarde';

  @override
  String get settingsImportNote =>
      'Indique ce qu\'elle contient avant de toucher à quoi que ce soit';

  @override
  String get settingsImportDialog => 'Choisis une sauvegarde de Kagami';

  @override
  String get settingsImportInvalid => 'Ce n\'est pas une sauvegarde de Kagami';

  @override
  String get settingsImportSheetTitle => 'Importer cette sauvegarde ?';

  @override
  String get settingsImportSeries => 'Séries';

  @override
  String get settingsImportRead => 'Lus';

  @override
  String get settingsImportCollections => 'Collections';

  @override
  String settingsImportExplain(String date) {
    return 'Faite le $date. Fusionner garde ce que tu as déjà et ajoute : les chapitres lus s\'additionnent et, pour le reste, l\'enregistrement le plus récent l\'emporte. Remplacer efface les données de cet appareil.';
  }

  @override
  String get settingsImportExplainUnknownDate =>
      'Faite à une date inconnue. Fusionner garde ce que tu as déjà et ajoute : les chapitres lus s\'additionnent et, pour le reste, l\'enregistrement le plus récent l\'emporte. Remplacer efface les données de cet appareil.';

  @override
  String get settingsImportMerge => 'Fusionner';

  @override
  String get settingsImportReplace => 'Remplacer';

  @override
  String get settingsImportDone => 'Données importées';

  @override
  String get settingsImportFailed => 'Échec de l\'importation';

  @override
  String get settingsWipe => 'Supprimer les données personnelles';

  @override
  String get settingsWipeNote =>
      'Statuts, notes, historique et collections. Les mangas ne sont pas touchés';

  @override
  String get settingsWipeSheetTitle =>
      'Supprimer toutes les données personnelles ?';

  @override
  String get settingsWipeExplain =>
      'Les statuts, notes, favoris, chapitres lus, historique, sessions, collections et marque-pages de cet appareil disparaissent. Les mangas et les index de la bibliothèque ne sont pas touchés.\n\nSi tu n\'as pas de sauvegarde, c\'est la dernière occasion d\'en faire une.';

  @override
  String get settingsWipeConfirm => 'Tout supprimer';

  @override
  String get settingsWipeDone => 'Données personnelles supprimées';

  @override
  String get settingsDriveConnect => 'Connecter Google Drive';

  @override
  String get settingsDriveConnectNote =>
      'Lit la bibliothèque depuis Drive sans tout rapatrier sur le téléphone, et ne télécharge que ce que tu choisis';

  @override
  String get settingsDriveFolder => 'Dossier sur Drive';

  @override
  String get settingsDriveSync => 'Synchronisation du dossier';

  @override
  String get settingsDriveDownloadsGo => 'Les chapitres téléchargés vont';

  @override
  String settingsDriveDownloadsFolder(String path) {
    return 'Dans le dossier de la bibliothèque : $path';
  }

  @override
  String get settingsDriveDownloadsApp =>
      'Dans l\'espace de l\'appli : ils disparaissent si tu la désinstalles';

  @override
  String get settingsDriveDownloadsAsk =>
      'La question sera posée au premier téléchargement';

  @override
  String get settingsDriveCache => 'Planches lues depuis Drive';

  @override
  String settingsDriveCacheNote(String used, String limit) {
    return '$used en cache, $limit au maximum. Elles se relisent sans réseau';
  }

  @override
  String get settingsDriveCacheLimitTitle => 'Espace pour les planches';

  @override
  String get settingsDriveClearCache => 'Vider le cache';

  @override
  String get settingsDriveClearCacheNote =>
      'Les chapitres téléchargés ne sont pas touchés';

  @override
  String get settingsDriveDisconnect => 'Déconnecter Drive';

  @override
  String get settingsDriveDisconnectNote =>
      'La bibliothèque redevient le dossier du téléphone. Les chapitres téléchargés restent';

  @override
  String get settingsAccountUnavailable => 'Compte indisponible ici';

  @override
  String get settingsAccountUnavailableNote =>
      'Cette version n\'a pas Firebase : les données restent où elles sont, sur l\'appareil';

  @override
  String get settingsAccountSignIn => 'Se connecter avec Google';

  @override
  String get settingsAccountSignInNote =>
      'Notes, statuts, chapitres lus, historique et collections suivent le compte plutôt que le téléphone';

  @override
  String get settingsAccountSyncNow => 'Synchroniser maintenant';

  @override
  String get settingsAccountNeverSynced =>
      'Jamais synchronisé sur ce téléphone';

  @override
  String settingsAccountLastSync(String date, String time) {
    return 'Dernière fois le $date à $time';
  }

  @override
  String get settingsAccountSignOut => 'Se déconnecter';

  @override
  String get settingsAccountSignOutNote =>
      'Envoie la dernière lecture, puis ferme la session';

  @override
  String get settingsAccountForget => 'Ne plus en garder de copie';

  @override
  String get settingsAccountForgetNote =>
      'Supprime les données du compte. Celles de ce téléphone restent où elles sont';

  @override
  String get settingsAccountErrorNote =>
      'Les données de ce téléphone n\'ont pas été touchées';

  @override
  String get settingsAccountForgetSheetTitle =>
      'Supprimer les données du compte ?';

  @override
  String get settingsAccountForgetExplain =>
      'La copie conservée pour toi disparaît, et la session se ferme. Les statuts, notes, historique et collections de ce téléphone restent où ils sont — mais tu ne les verras plus depuis un autre téléphone.';

  @override
  String get settingsAccountForgetConfirm => 'Supprimer du compte';

  @override
  String get settingsReaderDirection => 'Sens en mode paginé';

  @override
  String get settingsReaderBackground => 'Arrière-plan';

  @override
  String get settingsReaderKeepAwake => 'Garder l\'écran allumé';

  @override
  String get settingsReaderProgressBar => 'Barre de progression';

  @override
  String get settingsProbe => 'Mesurer la fluidité';

  @override
  String get settingsProbeNote =>
      'Dans le lecteur, en haut : images lentes et sautées, origine des bandes, GC. Une touche sur les chiffres les remet à zéro';

  @override
  String get settingsProbeInfo1 =>
      'Affiche dans le lecteur, en haut à gauche, un encadré de chiffres sur la fluidité de la lecture. Il sert à comprendre pourquoi le défilement saccade : il ne change rien à la façon de lire, et coûte très peu.';

  @override
  String get settingsProbeInfo2 =>
      'Le chiffre qui compte le plus est « sautées » : les images qui manquent pendant que la page défile. Chacune est une petite saccade visible. « Démarrées en retard » et « Lentes » indiquent si l\'appli était occupée, « GC Android » si le système était en train de libérer de la mémoire.';

  @override
  String get settingsProbeInfo3 =>
      '« Tuiles », « entières », « du téléphone » et « natives » indiquent d\'où est venu chaque morceau de planche : les trois premières sont les voies légères, la dernière est le découpage fait à la volée, qui est celui qui pèse.';

  @override
  String get settingsProbeInfo4 =>
      'Une touche sur l\'encadré remet les chiffres à zéro, pour mesurer à partir d\'un point précis du chapitre. En rouvrant l\'appli, la mesure s\'éteint d\'elle-même.';

  @override
  String get settingsTexture => 'Bandes natives en texture';

  @override
  String get settingsTextureNote =>
      'Essai : les planches encore à découper arrivent au GPU sans passer par l\'interface. S\'éteint en rouvrant l\'appli';

  @override
  String get settingsTextureInfo1 =>
      'Les planches très hautes d\'un webtoon se lisent par morceaux. Presque toujours, les morceaux sont déjà prêts : découpés par l\'archive sur le serveur, ou par le téléphone la première fois qu\'on ouvre le chapitre. Quand ils ne le sont pas, c\'est le décodeur d\'Android qui les découpe à la volée.';

  @override
  String get settingsTextureInfo2 =>
      'Normalement, les pixels de ces morceaux passent par l\'appli avant d\'arriver à l\'écran. Avec cette option, ils vont directement à la carte graphique : l\'appli a moins de travail pendant le défilement, et le défilement peut saccader moins. La qualité de l\'image ne change pas.';

  @override
  String get settingsTextureInfo3 =>
      'C\'est un essai : c\'est une nouvelle façon de dessiner, pas encore vérifiée sur ce téléphone. Si tu vois des planches noires, des lignes ou des scintillements, désactive-la. Si le téléphone ne la prend pas en charge, l\'appli revient toute seule au mode normal.';

  @override
  String get settingsTextureInfo4 =>
      'Sur les chapitres déjà découpés en tuiles, rien ne change, car cette voie n\'y est pas utilisée. En rouvrant l\'appli, elle s\'éteint d\'elle-même.';

  @override
  String get settingsWhatItDoes => 'À quoi ça sert';

  @override
  String get settingsBackupsTitle => 'Copies dans la bibliothèque';

  @override
  String get settingsBackupsNone =>
      'Aucune copie pour l\'instant : la première se fera à la prochaine ouverture';

  @override
  String settingsBackupsLatest(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copies, la dernière $name',
      one: '1 copie, la dernière $name',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupNow => 'Faire une copie maintenant';

  @override
  String settingsBackupWritten(String path) {
    return 'Copie écrite dans $path';
  }

  @override
  String settingsVersion(String version, String build) {
    return 'version $version ($build)';
  }

  @override
  String get settingsTagline => 'lecteur d\'archives MALF locales';

  @override
  String get librarySortUpdated => 'Mises à jour récemment';

  @override
  String get librarySortTitle => 'Titre';

  @override
  String get librarySortProgress => 'Progression';

  @override
  String get librarySortAdded => 'Ajoutées récemment';

  @override
  String get librarySortLastRead => 'Lues récemment';

  @override
  String get librarySortUnread => 'À lire';

  @override
  String get librarySortRating => 'Note';

  @override
  String get librarySortChapters => 'Nombre de chapitres';

  @override
  String get librarySortShuffle => 'Au hasard';

  @override
  String get libraryDisplayComfortable => 'Grille aérée';

  @override
  String get libraryDisplayCompact => 'Grille serrée';

  @override
  String get libraryDisplayList => 'Liste';

  @override
  String get libraryDisplayDetailed => 'Liste détaillée';

  @override
  String get libraryAutoReading => 'En cours de lecture';

  @override
  String get libraryAutoFresh => 'Nouveautés';

  @override
  String get libraryAutoFavorites => 'Favoris';

  @override
  String get libraryAutoPlanned => 'À commencer';

  @override
  String get libraryAutoFinished => 'Terminées';

  @override
  String libraryRowChapters(int count) {
    return '$count chap.';
  }

  @override
  String libraryRowUnread(int count) {
    return '$count à lire';
  }

  @override
  String get libraryNoMatchTitle => 'Aucun résultat';

  @override
  String get libraryNoMatchMessage =>
      'Aucune série ne correspond à la recherche et aux filtres choisis.';

  @override
  String get libraryEmptyTitle => 'Bibliothèque vide';

  @override
  String get libraryEmptyMessage =>
      'La bibliothèque ne contient aucune série. Si elle devrait en contenir, vérifie la synchronisation du dossier.';

  @override
  String get libraryClearFilters => 'Réinitialiser les filtres';

  @override
  String get libraryTitle => 'Bibliothèque';

  @override
  String get libraryCancelSelection => 'Annuler la sélection';

  @override
  String librarySelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnées',
      one: '1 sélectionnée',
    );
    return '$_temp0';
  }

  @override
  String libraryAllWithCount(int count) {
    return 'Toutes ($count)';
  }

  @override
  String get libraryAll => 'Toutes';

  @override
  String get libraryMarkAllRead => 'Tout marquer comme lu';

  @override
  String get libraryMarkAllUnread => 'Tout marquer comme à lire';

  @override
  String get libraryStatus => 'Statut';

  @override
  String get libraryFavorites => 'Favoris';

  @override
  String get libraryAddToCollection => 'Ajouter à une collection';

  @override
  String libraryStatusOfSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Statut de $count séries',
      one: 'Statut de 1 série',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries marquées comme lues',
      one: '1 série marquée comme lue',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries remises à lire',
      one: '1 série remise à lire',
    );
    return '$_temp0';
  }

  @override
  String get librarySearchHint => 'Titre, auteur, tag:…';

  @override
  String get libraryLayout => 'Affichage';

  @override
  String get libraryFiltersAndSort => 'Filtres et tri';

  @override
  String get libraryReset => 'Réinitialiser';

  @override
  String get librarySortSection => 'Trier';

  @override
  String get libraryShowOnly => 'Afficher seulement';

  @override
  String get libraryOnlyUnread => 'Avec des chapitres à lire';

  @override
  String get libraryOnlyStarted => 'Commencées';

  @override
  String get libraryOnlyNew => 'Avec de nouveaux chapitres';

  @override
  String get libraryOnlyFavorite => 'Favorites';

  @override
  String get libraryMinRating => 'Note minimale';

  @override
  String get libraryRelease => 'Publication';

  @override
  String get libraryGenres => 'Genres';

  @override
  String get libraryTriHint => 'Une touche l\'exige, deux l\'excluent';

  @override
  String get libraryTags => 'Tags';

  @override
  String get libraryAuthors => 'Auteurs';

  @override
  String get homeEmptyTitle => 'Bibliothèque vide';

  @override
  String get homeEmptyMessage =>
      'Rien à parcourir : le dossier ne contient encore aucune série.';

  @override
  String get homeToStart => 'À commencer';

  @override
  String get homeSimilarTitle => 'Pourquoi tu lis ce que tu lis';

  @override
  String get homeSimilarSubtitle =>
      'Pas encore ouvertes, avec les genres qui te parlent';

  @override
  String get homeRecentlyArrived => 'Arrivées récemment';

  @override
  String get homeLeftHalfway => 'Laissées en route';

  @override
  String get homeLeftHalfwaySubtitle => 'En pause et abandonnées';

  @override
  String get homeCaughtUpTitle => 'Tu es à jour';

  @override
  String get homeCaughtUpMessage =>
      'Avec tout ce qui est synchronisé. Le prochain chapitre arrivera avec le dossier.';

  @override
  String get homeRandomSeries => 'Une au hasard';

  @override
  String get homeReloadLibrary => 'Relire la bibliothèque';

  @override
  String get homeGreetingNight => 'En pleine nuit';

  @override
  String get homeGreetingMorning => 'Bonjour';

  @override
  String get homeGreetingAfternoon => 'Bon après-midi';

  @override
  String get homeGreetingEvening => 'Bonsoir';

  @override
  String get homeStatRead => 'Lus';

  @override
  String get homeStatReadCaption => 'chapitres au total';

  @override
  String get homeStatUnread => 'À lire';

  @override
  String get homeStatUnreadCaption => 'sur le téléphone';

  @override
  String get homeStatStreak => 'D\'affilée';

  @override
  String homeStatStreakCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'jours',
      one: 'jour',
    );
    return '$_temp0';
  }

  @override
  String get homeResume => 'Reprendre';

  @override
  String get homeNextChapter => 'Chapitre suivant';

  @override
  String get homeRead => 'Lire';

  @override
  String get homeUpdates => 'Mises à jour';

  @override
  String get homeUpdatesSubtitle => 'Chapitres synchronisés et pas encore lus';

  @override
  String homeLatestChapter(String number) {
    return 'chap. $number';
  }

  @override
  String get homeAgoToday => 'aujourd\'hui';

  @override
  String get homeAgoYesterday => 'hier';

  @override
  String homeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String homeAgoWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count semaines',
      one: 'il y a 1 semaine',
    );
    return '$_temp0';
  }

  @override
  String homeAgoMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count mois',
      one: 'il y a 1 mois',
    );
    return '$_temp0';
  }

  @override
  String homeAgoYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count ans',
      one: 'il y a 1 an',
    );
    return '$_temp0';
  }

  @override
  String get collectionsTitle => 'Collections';

  @override
  String get collectionsNew => 'Nouvelle';

  @override
  String get collectionsAutomatic => 'Automatiques';

  @override
  String get collectionsYours => 'Tes collections';

  @override
  String get collectionsNoneTitle => 'Aucune collection';

  @override
  String get collectionsNoneMessage =>
      'Elles servent à structurer une bibliothèque qui grandit toute seule : une série peut figurer dans plusieurs collections et tu choisis l\'ordre.';

  @override
  String collectionsSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries',
      one: '1 série',
    );
    return '$_temp0';
  }

  @override
  String get collectionsEdit => 'Modifier';

  @override
  String get collectionsRenameRecolor => 'Renommer et changer la couleur';

  @override
  String get collectionsDelete => 'Supprimer la collection';

  @override
  String get collectionsNotFound => 'Collection introuvable.';

  @override
  String get collectionsDone => 'Terminé';

  @override
  String get collectionsReorder => 'Réorganiser';

  @override
  String get collectionsEmptyTitle => 'Collection vide';

  @override
  String get collectionsEmptyMessage =>
      'Tu ajoutes une série depuis sa fiche, ou en appuyant longuement sur une couverture dans la bibliothèque.';

  @override
  String get collectionsRemoveFrom => 'Retirer de la collection';

  @override
  String get shellDataUnreadableTitle => 'Données de l\'appli illisibles';

  @override
  String get shellRetry => 'Réessayer';

  @override
  String get shellTabHome => 'Accueil';

  @override
  String get shellTabLibrary => 'Bibliothèque';

  @override
  String get shellTabCollections => 'Collections';

  @override
  String get moreDownload => 'Télécharger un manga';

  @override
  String get moreDownloadSubtitle => 'Cherche un titre ou colle un lien';

  @override
  String get moreHistory => 'Historique';

  @override
  String get moreHistorySubtitle => 'Ce que tu as lu et quand';

  @override
  String get moreStatistics => 'Statistiques';

  @override
  String get moreStatisticsSubtitle => 'Combien tu lis, ce que tu lis, quand';

  @override
  String get moreIncognito => 'Lecture en incognito';

  @override
  String get moreIncognitoSubtitle =>
      'N\'enregistre ni la position, ni les chapitres terminés, ni le temps de lecture';

  @override
  String get historyTitle => 'Historique';

  @override
  String get historyIncognitoOn => 'Incognito activé';

  @override
  String get historyIncognitoOff => 'Lire en incognito';

  @override
  String get historyClear => 'Vider';

  @override
  String get historyUnreadable => 'Historique illisible';

  @override
  String get historyEmptyTitle => 'Rien de lu pour l\'instant';

  @override
  String get historyEmptyMessage =>
      'Chaque chapitre terminé apparaîtra ici avec sa date.';

  @override
  String get historyClearTitle => 'Vider l\'historique ?';

  @override
  String get historyClearMessage =>
      'Les dates de lecture et le temps passé à lire disparaissent, et avec eux les statistiques qui en découlent. Les chapitres redeviennent à lire.';

  @override
  String get historyIncognitoBanner =>
      'En incognito : la position, les chapitres terminés et le temps de lecture ne sont pas enregistrés.';

  @override
  String get historyToday => 'Aujourd\'hui';

  @override
  String get historyYesterday => 'Hier';

  @override
  String get historyReread => 'Relire';

  @override
  String get historyRemove => 'Retirer de l\'historique';

  @override
  String get originLocal => 'Sur le téléphone';

  @override
  String get originDrive => 'Sur Drive';

  @override
  String get originMixed =>
      'Sur le téléphone, et d\'autres chapitres sur Drive';

  @override
  String get coverNoChapters => 'Aucun chapitre téléchargé';

  @override
  String coverChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chap.',
    );
    return '$_temp0';
  }

  @override
  String coverChaptersUnread(int count, int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chap.',
    );
    return '$_temp0 · $unread à lire';
  }

  @override
  String coverNewChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux chapitres',
      one: '1 nouveau chapitre',
    );
    return '$_temp0';
  }

  @override
  String coverUnread(int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '$unread chapitres à lire',
      one: '1 chapitre à lire',
    );
    return '$_temp0';
  }

  @override
  String coverUnreadFresh(int unread, int fresh) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '$unread chapitres à lire',
      one: '1 chapitre à lire',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fresh,
      locale: localeName,
      other: '$fresh nouveaux',
      one: '1 nouveau',
    );
    return '$_temp0, dont $_temp1';
  }

  @override
  String chartsDayNothing(String date) {
    return '$date : rien';
  }

  @override
  String chartsDayChapters(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres',
      one: '1 chapitre',
    );
    return '$date : $_temp0';
  }

  @override
  String get kitClose => 'Fermer';

  @override
  String get collectionSheetTitle => 'Collections';

  @override
  String collectionSheetTitleMany(int count) {
    return 'Collections de $count séries';
  }

  @override
  String get collectionSheetNew => 'Nouvelle';

  @override
  String get collectionSheetEmptyTitle => 'Aucune collection';

  @override
  String get collectionSheetEmptyMessage =>
      'Elles servent à structurer une bibliothèque qui grandit toute seule.';

  @override
  String collectionSheetSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries',
      one: '1 série',
    );
    return '$_temp0';
  }

  @override
  String get collectionSheetCreateTitle => 'Nouvelle collection';

  @override
  String get collectionSheetEditTitle => 'Modifier la collection';

  @override
  String get collectionSheetNameHint => 'Nom';

  @override
  String get collectionSheetColor => 'Couleur';

  @override
  String get collectionSheetCreate => 'Créer';

  @override
  String get collectionSheetSave => 'Enregistrer';

  @override
  String get cleanupTitle => 'Libérer de l\'espace ?';

  @override
  String get cleanupSyncBusy =>
      'Une synchronisation est en cours : réessaie quand elle sera terminée';

  @override
  String cleanupNotAllDeleted(String error) {
    return 'Tout n\'a pas été supprimé : $error';
  }

  @override
  String cleanupDriveError(String error) {
    return 'Drive : $error. Ce qui a déjà été retiré reste retiré';
  }

  @override
  String cleanupFreed(String size) {
    return '$size libérés';
  }

  @override
  String get cleanupNeedsNetwork =>
      'Il faut du réseau pour retirer des chapitres de Drive';

  @override
  String removeSeriesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer $count séries ?',
      one: 'Supprimer la série ?',
    );
    return '$_temp0';
  }

  @override
  String removeSeriesBody(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Elles quittent la bibliothèque : leurs chapitres sur le téléphone sont effacés et aucun nouveau n\'arrivera. La progression de lecture reste.',
      one:
          '« $title » quitte la bibliothèque : ses chapitres sur le téléphone sont effacés et aucun nouveau n\'arrivera. La progression de lecture reste.',
    );
    return '$_temp0';
  }

  @override
  String get removeSeriesDrive =>
      'Sur Drive, le dossier va dans la corbeille : vous pouvez l\'y récupérer pendant trente jours.';

  @override
  String get removeSeriesConfirm => 'Supprimer';

  @override
  String removeSeriesDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries supprimées.',
      one: 'Série supprimée.',
    );
    return '$_temp0';
  }

  @override
  String removeSeriesFailed(String error) {
    return 'Impossible de tout supprimer : $error';
  }

  @override
  String get removeSeriesAction => 'Supprimer de la bibliothèque';

  @override
  String cleanupIntroDrive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres déjà lus sont encore sur Drive.',
      one: 'Un chapitre déjà lu est encore sur Drive.',
    );
    return '$_temp0';
  }

  @override
  String cleanupIntroPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count chapitres déjà lus occupent encore de l\'espace sur le téléphone.',
      one: 'Un chapitre déjà lu occupe encore de l\'espace sur le téléphone.',
    );
    return '$_temp0';
  }

  @override
  String get cleanupPhoneChapters => 'Chapitres sur le téléphone';

  @override
  String get cleanupDriveCache => 'Cache de Drive';

  @override
  String get cleanupDriveChapters => 'Chapitres sur Drive';

  @override
  String cleanupApproxSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres',
      one: '1 chapitre',
    );
    return '$_temp0 · environ $size';
  }

  @override
  String cleanupExactSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres',
      one: '1 chapitre',
    );
    return '$_temp0 · $size';
  }

  @override
  String cleanupApproxSizeTrash(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres',
      one: '1 chapitre',
    );
    return '$_temp0 · environ $size · dans la corbeille';
  }

  @override
  String get cleanupQuiet => 'Ne plus demander pour cette série';

  @override
  String get cleanupWarnNotOnDrive =>
      'Cette série n\'est pas sur Drive : les chapitres supprimés ne pourront plus être relus tant que la synchronisation ne les aura pas rapportés.';

  @override
  String get cleanupWarnGoneEverywhere =>
      'Ils ne resteront ni sur le téléphone ni sur Drive.';

  @override
  String get cleanupWarnStaysOnDrive =>
      'Les chapitres restent sur Drive et se relisent depuis là.';

  @override
  String get cleanupWarnTrash =>
      'Tu peux les récupérer depuis la corbeille de Drive pendant trente jours. L\'index du serveur les liste encore : si le serveur les recharge, ils redeviennent lisibles depuis Drive.';

  @override
  String get cleanupDelete => 'Supprimer';

  @override
  String get cleanupNotNow => 'Pas maintenant';

  @override
  String get cleanupSyncWarnExternal =>
      'Si FolderSync synchronise le dossier dans les deux sens, la suppression peut aussi arriver sur Drive ; s\'il ne fait que télécharger, les chapitres peuvent revenir au passage suivant.';

  @override
  String get cleanupSyncWarnOwn =>
      'La synchronisation respecte ce choix : ce que tu retires d\'un côté ne revient pas et ne disparaît pas de l\'autre, même avec les suppressions propagées.';

  @override
  String get statsRangeMonth => '30 jours';

  @override
  String get statsRangeQuarter => '3 mois';

  @override
  String get statsRangeYear => 'Un an';

  @override
  String get statsTitle => 'Statistiques';

  @override
  String get statsUnavailable => 'Statistiques impossibles à calculer';

  @override
  String get statsChaptersRead => 'chapitres lus';

  @override
  String get statsSeriesInLibrary => 'séries dans la bibliothèque';

  @override
  String statsMinutes(int count) {
    return '$count min';
  }

  @override
  String statsHours(int count) {
    return '$count h';
  }

  @override
  String get statsReadingTime => 'temps de lecture';

  @override
  String get statsReadingTimeHint => 'mesuré pendant que tu lis';

  @override
  String get statsPagesSeen => 'planches vues';

  @override
  String get statsStreak => 'jours d\'affilée';

  @override
  String statsStreakRecord(int count) {
    return 'record : $count';
  }

  @override
  String get statsAverageRating => 'note moyenne';

  @override
  String statsRatedSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries notées',
      one: '1 série notée',
    );
    return '$_temp0';
  }

  @override
  String get statsChaptersOverTime => 'Chapitres lus';

  @override
  String get statsPerWeek => 'par semaine';

  @override
  String get statsPerDay => 'par jour';

  @override
  String get statsActivityTitle => 'Quand tu lis';

  @override
  String get statsActivitySubtitle =>
      'un carré par jour, sur les six derniers mois';

  @override
  String get statsShelfTitle => 'La bibliothèque par statut';

  @override
  String statsGenreOthers(int count) {
    return '$count autres';
  }

  @override
  String get statsGenresTitle => 'Genres que tu lis';

  @override
  String get statsGenresSubtitle => 'sur les séries que tu as commencées';

  @override
  String get statsRatingsTitle => 'Comment tu notes';

  @override
  String get statsRatingsSubtitle => 'combien de séries pour chaque note';

  @override
  String get statsTopSeries => 'Séries les plus lues';

  @override
  String get statsShapeTitle => 'Comment est faite la bibliothèque';

  @override
  String get statsSyncedChapters => 'chapitres synchronisés';

  @override
  String get statsStillUnread => 'encore à lire';

  @override
  String get statsOngoingSeries => 'séries en cours';

  @override
  String statsAnnouncedMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapitres annoncés et non téléchargés',
      one: '1 chapitre annoncé et non téléchargé',
    );
    return '$_temp0';
  }

  @override
  String get statsBytesOnPhone => 'occupés sur le téléphone';

  @override
  String get statsNoHistory =>
      'Rien de lu sur cette période. L\'historique part du moment où l\'appli a commencé à l\'enregistrer.';

  @override
  String get dataDriveNotLinked => 'Drive n\'est pas connecté';

  @override
  String get dataChapterNotOnDrive => 'Chapitre introuvable sur Drive';

  @override
  String get dataChapterNoPagesOnDrive =>
      'Le chapitre n\'a aucune planche sur Drive';

  @override
  String get dataPageNotOnDrive => 'Planche introuvable sur Drive';

  @override
  String get dataPrefetchCancelled => 'Préchargement annulé';

  @override
  String get dataDriveAccessDenied =>
      'Google n\'a pas accordé l\'accès à Drive';

  @override
  String get dataDriveOfflineNeverOpened =>
      'Pas de connexion, et la bibliothèque sur Drive n\'a jamais été ouverte sur ce téléphone';

  @override
  String get dataDriveSignedOut =>
      'Connecte-toi avec Google pour lire la bibliothèque sur Drive';

  @override
  String get dataSyncMissingFolderOrDirection =>
      'Il manque le dossier ou le sens';

  @override
  String get dataSyncFailed => 'Échec de la synchronisation';

  @override
  String get dataSyncFolderUnreadable =>
      'Le dossier du téléphone est illisible';

  @override
  String get dataSyncBusy => 'Une synchronisation est déjà en cours';

  @override
  String get dataSyncCancelled => 'Synchronisation interrompue';

  @override
  String get dataSyncDirectionDownload => 'Depuis Drive';

  @override
  String get dataSyncDirectionUpload => 'Vers Drive';

  @override
  String get dataSyncDirectionBoth => 'Les deux';

  @override
  String dataServerInviteTitle(String sender) {
    return '$sender t\'a donné accès à son serveur';
  }

  @override
  String dataServerInviteText(String serverName) {
    return 'Connecte « $serverName » et il téléchargera les mangas sur ton Drive, même téléphone éteint.';
  }

  @override
  String get dataServerSignInRequired =>
      'Connecte-toi avec Google pour utiliser le serveur.';

  @override
  String get dataServerNotLinked => 'Aucun serveur connecté.';

  @override
  String dataServerUserNotNotified(String email, String url) {
    return '$email peut utiliser le serveur, mais je n\'ai pas pu le prévenir : envoie-lui toi-même l\'adresse $url.';
  }

  @override
  String get dataPickLibraryFolderTitle =>
      'Choisis le dossier de la bibliothèque de mangas';

  @override
  String get dataCloudSignInNotEnabled =>
      'La connexion avec Google n\'est pas encore activée sur ce projet';

  @override
  String get dataCloudNoConnection => 'Pas de connexion';

  @override
  String get dataCloudNoSignIn => 'Aucune connexion';

  @override
  String get dataCloudNoIdentityToken =>
      'Google n\'a pas fourni de jeton d\'identité';

  @override
  String get dataCloudSignInFailed => 'Échec de la connexion';

  @override
  String get dataCloudSignInInterrupted => 'Connexion interrompue';

  @override
  String get dataCloudGoogleNotConfigured =>
      'Google n\'est pas configuré pour cette appli';

  @override
  String get dataCloudGoogleSignInFailed => 'Échec de la connexion avec Google';

  @override
  String dataNewChaptersNotification(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux chapitres sont arrivés',
      one: 'Un nouveau chapitre est arrivé',
    );
    return '$_temp0';
  }

  @override
  String get dataArchivePhoneFolderMissing =>
      'Il manque le dossier du téléphone.';

  @override
  String get dataArchiveDriveFolderMissing => 'Il manque le dossier de Drive.';

  @override
  String dataChapterLabel(String number) {
    return 'Chapitre $number';
  }

  @override
  String get dataLibraryMissing => 'Le dossier n\'existe pas ou est illisible.';

  @override
  String get dataLibraryNotIndexed =>
      'Le dossier ne contient pas library.json : il faut régénérer les index avec l\'archiveur qui a écrit la bibliothèque.';

  @override
  String get dataLibraryUnreadable =>
      'library.json est illisible ou n\'est pas un index MALF valide.';

  @override
  String get dataLibraryUnsupported =>
      'library.json utilise une version du format plus récente que cette appli.';

  @override
  String get dataReaderModeContinuous => 'Continue';

  @override
  String get dataReaderModePaged => 'Paginée';

  @override
  String get dataReaderDirectionLtr => 'Gauche → droite';

  @override
  String get dataReaderDirectionRtl => 'Droite → gauche';

  @override
  String get dataReaderFitWidth => 'Largeur';

  @override
  String get dataReaderFitHeight => 'Hauteur';

  @override
  String get dataReaderFitOriginal => 'Original';

  @override
  String get dataReaderBackgroundBlack => 'Noir';

  @override
  String get dataReaderBackgroundGrey => 'Gris';

  @override
  String get dataReaderBackgroundWhite => 'Blanc';

  @override
  String readerProbeFrames(String frames, String budget) {
    return 'Images $frames · limite $budget ms';
  }

  @override
  String readerProbeSlow(
    String build,
    String buildMax,
    String raster,
    String rasterMax,
  ) {
    return 'Lentes UI $build (max $buildMax ms) · GPU $raster (max $rasterMax ms)';
  }

  @override
  String readerProbeLate(String late, String lateMax) {
    return 'Démarrées en retard $late (max $lateMax ms)';
  }

  @override
  String readerProbeScroll(String scroll, String missed, String gap) {
    return 'Défilement $scroll · sautées $missed (trou max $gap ms)';
  }

  @override
  String readerProbeSources(
    String tiles,
    String whole,
    String phone,
    String phoneMade,
  ) {
    return 'Tuiles $tiles · entières $whole · du téléphone $phone (faites $phoneMade)';
  }

  @override
  String readerProbeNative(String bands, String textures, String decodes) {
    return 'Natives $bands (texture $textures) · planches décodées $decodes';
  }

  @override
  String readerProbeDecode(
    String decode,
    String decodeMax,
    String arrival,
    String arrivalMax,
  ) {
    return 'Décodage $decode ms (max $decodeMax) · arrivée $arrival ms (max $arrivalMax)';
  }

  @override
  String readerProbeMemory(
    String copy,
    String gc,
    String gcMs,
    String blocking,
    String blockingMs,
  ) {
    return 'Copie max $copy ms · GC Android $gc ($gcMs ms) · bloquants $blocking ($blockingMs ms)';
  }

  @override
  String readerProbeWaits(String drive, String fallbacks) {
    return 'Attentes de Drive $drive · repli Dart $fallbacks';
  }

  @override
  String readerProbeJumps(String corrections, String jumps, String jumped) {
    return 'Corrections $corrections · sauts $jumps ($jumped px)';
  }

  @override
  String get serverCheckDaily =>
      'Vérification quotidienne des nouveaux chapitres';

  @override
  String serverCheckDailyAt(String clock) {
    return 'Chaque jour à $clock, heure du serveur';
  }

  @override
  String get serverCheckDailyOff =>
      'Désactivé : les nouveaux chapitres ne se téléchargent qu\'à la main';

  @override
  String get serverCheckLibrary => 'Toute la bibliothèque sur Drive';

  @override
  String get serverCheckLibraryOn =>
      'Aussi les séries téléchargées par le téléphone ou par d\'autres, pas seulement par le serveur';

  @override
  String get serverCheckLibraryOff =>
      'Seulement les séries en cours téléchargées par le serveur';

  @override
  String serverCheckLast(String when, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries avec de nouveaux chapitres',
      one: '1 série avec de nouveaux chapitres',
      zero: 'aucun nouveau chapitre',
    );
    return 'Dernière vérification $when : $_temp0';
  }

  @override
  String get serverCheckTimeHelp => 'Heure de la vérification';
}
