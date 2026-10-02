// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'Same as system';

  @override
  String get seriesShelfNone => 'No status';

  @override
  String get seriesShelfPlanned => 'Plan to read';

  @override
  String get seriesShelfReading => 'Reading';

  @override
  String get seriesShelfPaused => 'On hold';

  @override
  String get seriesShelfCompleted => 'Completed';

  @override
  String get seriesShelfDropped => 'Dropped';

  @override
  String get seriesReleaseOngoing => 'Ongoing';

  @override
  String get seriesReleaseCompleted => 'Finished';

  @override
  String get seriesReleaseHiatus => 'On hiatus';

  @override
  String get seriesReleaseCancelled => 'Cancelled';

  @override
  String get seriesReleaseUnknown => 'Status unknown';

  @override
  String get seriesNotFound => 'Series not found.';

  @override
  String get seriesOfflineTitle => 'Chapters on Drive';

  @override
  String get seriesOfflineMessage =>
      'Without a connection, the chapter list for this series can\'t be shown. It will appear on its own as soon as the network is back.';

  @override
  String get seriesNoIndexTitle => 'No index';

  @override
  String get seriesNoIndexMessage =>
      'This series has no index.json: regenerate the indexes with the archiver that wrote it.';

  @override
  String get seriesNoChaptersTitle => 'No chapters';

  @override
  String get seriesNoChaptersMessage =>
      'No chapter matches your search and filters.';

  @override
  String seriesDownloadAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Download $count chapters?',
      one: 'Download 1 chapter?',
    );
    return '$_temp0';
  }

  @override
  String get seriesDownloadAllMessage =>
      'All the chapters you now read from Drive will be saved to your phone, so you can read them without a connection too.';

  @override
  String get seriesDownload => 'Download';

  @override
  String seriesCleanupRemote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count read chapters are still on Drive',
      one: '1 read chapter is still on Drive',
    );
    return '$_temp0';
  }

  @override
  String seriesCleanupLocal(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count read chapters take up $size',
      one: '1 read chapter takes up $size',
    );
    return '$_temp0';
  }

  @override
  String seriesDownloadFailed(String error) {
    return 'Download failed: $error. Retry';
  }

  @override
  String get seriesDownloadWaiting =>
      'Waiting for the network: it will resume on its own. Cancel';

  @override
  String get seriesDownloadQueued => 'Queued. Cancel';

  @override
  String get seriesDownloadCancel => 'Cancel download';

  @override
  String get seriesPlaceLocal => 'On phone';

  @override
  String get seriesPlaceDrive => 'On Drive';

  @override
  String get seriesPlaceMixed => 'Phone and Drive';

  @override
  String get seriesMuteTooltipOn => 'New chapter notifications muted';

  @override
  String get seriesMuteTooltipOff => 'New chapter notifications on';

  @override
  String get seriesMuteUnmuted => 'New chapter notifications turned back on.';

  @override
  String get seriesMuteMuted => 'New chapter notifications muted.';

  @override
  String seriesCaughtUpMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Caught up with what\'s on your phone: $count announced chapters are missing.',
      one: 'Caught up with what\'s on your phone: 1 announced chapter is missing.',
    );
    return '$_temp0';
  }

  @override
  String get seriesCaughtUpAll => 'All read.';

  @override
  String get seriesResumeToContinue => 'KEEP READING';

  @override
  String get seriesResumeToStart => 'NOT STARTED';

  @override
  String get seriesResumeHalfway => 'LEFT HALFWAY';

  @override
  String seriesResumePage(int page, int total) {
    return 'page $page of $total';
  }

  @override
  String get seriesContinue => 'Continue';

  @override
  String get seriesStart => 'Start';

  @override
  String get seriesResume => 'Resume';

  @override
  String get seriesNextChapter => 'Next chapter';

  @override
  String get seriesFigureChapters => 'Chapters';

  @override
  String get seriesFigureRead => 'Read';

  @override
  String get seriesFigureProgress => 'Progress';

  @override
  String get seriesFigureRating => 'Rating';

  @override
  String get seriesMyShelf => 'My shelf';

  @override
  String get seriesFavoriteOn => 'Favorite';

  @override
  String get seriesFavoriteOff => 'Favorites';

  @override
  String get seriesRatingButton => 'Rating';

  @override
  String seriesRatingOutOfTen(int rating) {
    return '$rating/10';
  }

  @override
  String get seriesCollections => 'Collections';

  @override
  String get seriesNotes => 'Notes';

  @override
  String get seriesRatingSheetTitle => 'How would you rate it?';

  @override
  String get seriesNotesHint => 'Where you left off, what you think…';

  @override
  String get seriesSave => 'Save';

  @override
  String get seriesRatingWord1 => 'Terrible';

  @override
  String get seriesRatingWord2 => 'Bad';

  @override
  String get seriesRatingWord3 => 'Poor';

  @override
  String get seriesRatingWord4 => 'Mediocre';

  @override
  String get seriesRatingWord5 => 'Fair';

  @override
  String get seriesRatingWord6 => 'Decent';

  @override
  String get seriesRatingWord7 => 'Good';

  @override
  String get seriesRatingWord8 => 'Great';

  @override
  String get seriesRatingWord9 => 'Excellent';

  @override
  String get seriesRatingWord10 => 'Masterpiece';

  @override
  String get seriesRatingNone => 'No rating';

  @override
  String get seriesRatingHint => 'Tap or swipe';

  @override
  String seriesRatingBefore(int rating) {
    return 'Before: $rating';
  }

  @override
  String get seriesRatingRemove => 'Remove';

  @override
  String get seriesRatingSave => 'Save rating';

  @override
  String get seriesSynopsis => 'Synopsis';

  @override
  String get seriesGenres => 'Genres';

  @override
  String get seriesTags => 'Tags';

  @override
  String get seriesCreators => 'Creators';

  @override
  String seriesMoreTags(int count) {
    return '$count more';
  }

  @override
  String get seriesPaceToRead => 'To read';

  @override
  String seriesPaceCaption(int chapters, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      chapters,
      locale: localeName,
      other: '$chapters chapters',
      one: '1 chapter',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages pages',
      one: '1 page',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get seriesPaceNext => 'Next chapter';

  @override
  String get seriesPaceNextCaption => 'based on the last releases';

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
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get seriesWhenLate => 'late';

  @override
  String get seriesWhenExpected => 'expected';

  @override
  String get seriesWhenToday => 'today';

  @override
  String get seriesWhenTomorrow => 'tomorrow';

  @override
  String seriesWhenInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count days',
      one: 'in 1 day',
    );
    return '$_temp0';
  }

  @override
  String seriesWhenInWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count weeks',
      one: 'in 1 week',
    );
    return '$_temp0';
  }

  @override
  String get seriesShowLess => 'Show less';

  @override
  String get seriesShowMore => 'Read more';

  @override
  String get seriesChaptersTitle => 'Chapters';

  @override
  String seriesChaptersOf(int total) {
    return 'of $total';
  }

  @override
  String get seriesSearchChapter => 'Search chapters…';

  @override
  String get seriesSortNewest => 'Newest first';

  @override
  String get seriesSortOldest => 'Oldest first';

  @override
  String get seriesMarkAll => 'Mark all';

  @override
  String get seriesDownloadFromDrive => 'Download from Drive';

  @override
  String get seriesFreeSpace => 'Free up space';

  @override
  String get seriesFilterUnread => 'Unread';

  @override
  String get seriesFilterDownloaded => 'Downloaded';

  @override
  String get seriesFilterAll => 'All';

  @override
  String seriesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get seriesMarkReadMany => 'Mark as read';

  @override
  String get seriesMarkUnread => 'Mark as unread';

  @override
  String get seriesMarkRead => 'Mark as read';

  @override
  String get seriesMarkReadThrough => 'Mark read up to here';

  @override
  String get seriesSimilar => 'More like this';

  @override
  String get seriesChapterNotDownloaded => 'Not downloaded';

  @override
  String seriesChapterPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get seriesDownloadToPhone => 'Download to phone';

  @override
  String get readerSeriesUnavailable => 'Series not available.';

  @override
  String get readerNoPagesIndex =>
      'This series has no pages.json: regenerate the indexes with the archiver that wrote it.';

  @override
  String get readerSeriesOffline =>
      'Without a connection, this series can\'t be opened: its page list is on Drive. It will open as soon as the network is back.';

  @override
  String get readerChapterNotOnPhone =>
      'This chapter isn\'t on your phone yet. Syncing may be only partly done: try again later.';

  @override
  String get readerChapterNoPages => 'This chapter has no readable pages.';

  @override
  String get readerPagesNotOnPhone =>
      'The pages of this chapter aren\'t on your phone yet. The index lists them, but the files haven\'t arrived: the synced folder has to bring them.';

  @override
  String get readerMarkEarlierTitle => 'Mark earlier chapters as read?';

  @override
  String readerMarkEarlierBody(int count, String chapter) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'You finished $chapter. The $count previous chapters still show as unread: if you\'ve already read them elsewhere, mark them all as read at once.',
      one:
          'You finished $chapter. The previous chapter still shows as unread: if you\'ve already read it elsewhere, mark it as read.',
    );
    return '$_temp0';
  }

  @override
  String readerMarkEarlierConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mark all $count as read',
      one: 'Mark previous as read',
    );
    return '$_temp0';
  }

  @override
  String get readerMarkEarlierDecline => 'Leave them unread';

  @override
  String readerBookmarkAdded(int page) {
    return 'Page $page bookmarked';
  }

  @override
  String get readerChapters => 'Chapters';

  @override
  String get readerBookmarks => 'Bookmarks';

  @override
  String get readerNoBookmarks => 'No bookmarks';

  @override
  String get readerNoBookmarksHint =>
      'A bookmark keeps your place on a page; your place in the chapter is already remembered by resume.';

  @override
  String readerBookmarkPage(int page) {
    return 'page $page';
  }

  @override
  String get readerBookmarkRemove => 'Remove';

  @override
  String get readerToTop => 'Back to top';

  @override
  String get readerPageNotFromDrive => 'Page didn\'t arrive from Drive';

  @override
  String get readerPageUnreadable => 'Page can\'t be read';

  @override
  String get readerPageNotSynced => 'Page not synced';

  @override
  String get readerPageNotDownloaded => 'Page not downloaded yet';

  @override
  String get readerPageOfflineHint =>
      'No connection. It will arrive on its own as soon as the network is back.';

  @override
  String get readerRetryNow => 'Retry now';

  @override
  String get readerLastChapterOnPhone =>
      'This is the last chapter on your phone.';

  @override
  String get readerNextChapter => 'Next chapter';

  @override
  String get readerContinue => 'Continue';

  @override
  String get readerBookmarkThisPage => 'Bookmark this page';

  @override
  String get readerHowToRead => 'Reading options';

  @override
  String get readerPreviousChapter => 'Previous chapter';

  @override
  String get readerNextChapterTooltip => 'Next chapter';

  @override
  String get readerSearchChapter => 'Search chapters…';

  @override
  String get readerNewestFirst => 'Newest first';

  @override
  String get readerOldestFirst => 'Oldest first';

  @override
  String readerReadingNow(String current, int total) {
    return 'Reading: $current / $total chapters';
  }

  @override
  String get readerMode => 'Reading mode';

  @override
  String get readerModeStrip => 'Continuous';

  @override
  String get readerModePage => 'Paged';

  @override
  String get readerDirection => 'Reading direction';

  @override
  String get readerDirectionLtr => 'Left → right';

  @override
  String get readerDirectionRtl => 'Right → left';

  @override
  String get readerFit => 'Fit';

  @override
  String get readerBackground => 'Background';

  @override
  String get readerBrightness => 'Brightness';

  @override
  String get readerAutoScroll => 'Auto-scroll';

  @override
  String get readerAutoScrollOff => 'off';

  @override
  String readerAutoScrollRate(int rate) {
    return '$rate pages/min';
  }

  @override
  String get readerShowPageNumber => 'Page number';

  @override
  String get readerShowProgress => 'Progress bar';

  @override
  String get readerShowScrollTop => 'Back-to-top button';

  @override
  String get readerKeepAwake => 'Keep screen on';

  @override
  String get readerDoublePage => 'Two pages side by side';

  @override
  String get readerLockRotation => 'Lock rotation';

  @override
  String get archiveTitle => 'Download a manga';

  @override
  String get archiveIntro =>
      'Search for a title on the supported sites, or paste a series link: Kagami downloads the series from the site into your library, with metadata, cover and the full chapter list.';

  @override
  String get archiveSearchHint => 'Search for a manga by title';

  @override
  String get archiveClear => 'Clear';

  @override
  String get archivePaste => 'Paste';

  @override
  String get archiveReading => 'Reading the series…';

  @override
  String get archiveVerify => 'Check series';

  @override
  String archiveSeriesSummary(String site, int count, String status) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$site · $_temp0 · $status';
  }

  @override
  String archiveKnown(int archived, int total) {
    return 'Already in your library: $archived of $total chapters. Existing ones are skipped.';
  }

  @override
  String get archiveWhatSection => 'What to download';

  @override
  String get archiveModeAll => 'All';

  @override
  String get archiveModeFrom => 'From chapter';

  @override
  String get archiveModePick => 'Picked';

  @override
  String get archiveModeAllHint =>
      'All chapters. Doing it again later only brings new or damaged ones.';

  @override
  String get archiveModeFromHint =>
      'From the chosen chapter onward: earlier ones stay in the series list, marked as not downloaded.';

  @override
  String get archiveModePickHint =>
      'Only the chapters you tap. The others stay in the list, not downloaded.';

  @override
  String get archiveChapterNumberHint => 'Chapter number, as on the site';

  @override
  String archivePickedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count picked',
      one: '1 picked',
    );
    return '$_temp0';
  }

  @override
  String get archiveSelectAll => 'All';

  @override
  String get archiveSelectNone => 'None';

  @override
  String get archiveWhereSection => 'Where';

  @override
  String get archiveWhereServer => 'Server';

  @override
  String get archiveWhereDrive => 'Drive';

  @override
  String get archiveWhereDriveAndPhone => 'Drive and phone';

  @override
  String get archiveWherePhone => 'Phone';

  @override
  String get archiveWhereDriveHint =>
      'In the library folder on Drive. Pages pass through your phone and leave as soon as Drive has them: you can stream them, or download them later.';

  @override
  String get archiveWhereDriveAndPhoneHint =>
      'In the library folder on Drive, and the chapters also stay on your phone so you can read them without a connection.';

  @override
  String get archiveWherePhoneHint =>
      'On your phone, in the manga folder or in the app\'s space. If you connect Drive, you can download straight there.';

  @override
  String archiveServerHint(String name, String folder, String other) {
    String _temp0 = intl.Intl.selectLogic(other, {
      'other': ' Note: this isn\'t the folder the app reads.',
      'same': '',
    });
    return '\"$name\" downloads it and uploads it to \"$folder\" on Drive, even when your phone is off. The server follows ongoing series.$_temp0';
  }

  @override
  String get archiveDelaySection => 'Pause between requests';

  @override
  String get archiveDelayNone => 'None';

  @override
  String archiveDelaySeconds(String seconds) {
    return '$seconds s';
  }

  @override
  String get archiveDelayHint =>
      'Sites don\'t like bulk downloads: a short pause helps you avoid getting blocked.';

  @override
  String get archiveDownloadAll => 'Download the whole series';

  @override
  String get archiveDownloadFrom => 'Download from the chosen chapter';

  @override
  String archiveDownloadPicked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Download $count chapters',
      one: 'Download 1 chapter',
    );
    return '$_temp0';
  }

  @override
  String archiveNoResults(String site) {
    return 'No results on $site.';
  }

  @override
  String archiveChaptersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$_temp0';
  }

  @override
  String archiveVerifySite(String site) {
    return 'Verify $site';
  }

  @override
  String get archiveVerifySiteHint =>
      'The site wants to know you\'re a person: tap to open the check, then search there too';

  @override
  String get archiveStatusOngoing => 'ongoing';

  @override
  String get archiveStatusCompleted => 'finished';

  @override
  String get archiveStatusHiatus => 'on hiatus';

  @override
  String get archiveStatusCancelled => 'cancelled';

  @override
  String get archiveStatusUnknown => 'status unknown';

  @override
  String get archiveErrChallenge =>
      'The site asks for a check that can\'t be done from here.';

  @override
  String get archiveErrOffline => 'No connection: the site isn\'t responding.';

  @override
  String get archiveErrVerifyIncomplete => 'The site check wasn\'t completed.';

  @override
  String archiveQueuedSnack(String title) {
    return '\"$title\" is queued. It keeps going even with the screen off.';
  }

  @override
  String archiveQueuedServerSnack(String title, String server) {
    return '\"$title\" is queued on \"$server\". Your phone can even be turned off.';
  }

  @override
  String get archiveServerFallbackName => 'server';

  @override
  String get archiveDownloads => 'Downloads';

  @override
  String get archiveClearHistory => 'Clear';

  @override
  String get archiveQueueStopped => 'Queue stopped';

  @override
  String get archiveQueueResumeHint =>
      'It restarts on its own; tap to start it now';

  @override
  String archiveJobAutomatic(String destination) {
    return 'New chapters · $destination';
  }

  @override
  String archiveJobQueued(String destination) {
    return 'Queued · $destination';
  }

  @override
  String get archiveRemoveFromQueue => 'Remove from queue';

  @override
  String archiveHistoryLine(String when, String message) {
    return '$when · $message';
  }

  @override
  String get archiveSites => 'Supported sites';

  @override
  String get archiveMoreSites =>
      'More sites are coming: support for new providers will arrive with future updates.';

  @override
  String archiveLinkCopied(String url) {
    return '$url copied to the clipboard.';
  }

  @override
  String get archiveTracked => 'Ongoing series';

  @override
  String get archiveTrackedIntro =>
      'Ongoing series downloaded from here are checked again: only new chapters arrive, in the same destination. Those on the server are followed by the server.';

  @override
  String get archiveCheckDaily => 'Check every day';

  @override
  String get archiveCheckManual => 'Manual only';

  @override
  String archiveCheckAt(String time) {
    return 'At $time, even when the app is closed';
  }

  @override
  String get archiveCheckTime => 'Time';

  @override
  String get archiveCheckTimeHelp => 'Check time';

  @override
  String get archiveWifiOnly => 'Wi-Fi only';

  @override
  String get archiveWifiOnlyOn => 'Waits for a network that isn\'t metered';

  @override
  String get archiveWifiOnlyOff => 'Mobile data too';

  @override
  String get archiveCheckNow => 'Check now';

  @override
  String get archiveNoTracked => 'No series being followed, for now';

  @override
  String archiveTrackedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series followed',
      one: '1 series followed',
    );
    return '$_temp0';
  }

  @override
  String archiveTrackedLine(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count known chapters',
      one: '1 known chapter',
    );
    return '$_temp0 · $destination';
  }

  @override
  String archiveTrackedLineChecked(int count, String destination, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count known chapters',
      one: '1 known chapter',
    );
    return '$_temp0 · $destination · checked $when';
  }

  @override
  String get archiveStopFollowing => 'Stop following';

  @override
  String archiveCheckQueued(String names) {
    return 'new chapters for $names';
  }

  @override
  String archiveCheckRemoved(String names) {
    return '$names now finished';
  }

  @override
  String archiveCheckFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unreachable',
      one: '1 unreachable',
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
  String get archiveNoNewChapters => 'No new chapters.';

  @override
  String get archiveNoConnection => 'No connection.';

  @override
  String get archiveForgetTitle => 'Stop following?';

  @override
  String archiveForgetBody(String title) {
    return 'New chapters of \"$title\" will no longer arrive on their own. Chapters already downloaded stay.';
  }

  @override
  String get archiveCancel => 'Cancel';

  @override
  String get archiveForgetConfirm => 'Stop';

  @override
  String archiveStartIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters.',
      one: '1 chapter.',
    );
    return '$_temp0 Download everything or choose which chapter to start from: earlier ones stay in the reader\'s list, without pages.';
  }

  @override
  String get archiveStartNoMatch => 'No chapter with this number.';

  @override
  String archiveStartFrom(String title, int remaining) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: '$remaining chapters',
      one: '1 chapter',
    );
    return 'From \"$title\" onward: $_temp0.';
  }

  @override
  String get archiveStartNone =>
      'No chapter chosen: you can download everything.';

  @override
  String get archiveStartAll => 'Download all';

  @override
  String get archiveStartHere => 'From here';

  @override
  String get browserTitle => 'Site check';

  @override
  String get browserPhoneOnly => 'The check can only be done from the phone.';

  @override
  String get browserInstructionsChapters =>
      'The site wants to know you\'re a person. Complete the check: when the chapter list appears, Kagami notices and goes back on its own.';

  @override
  String get browserInstructionsSearch =>
      'The site wants to know you\'re a person. Complete the check: when the site\'s search appears, Kagami notices and goes back on its own.';

  @override
  String get browserSearchPhoneOnly =>
      'This site can only be searched from the phone.';

  @override
  String get browserSearchSuperseded => 'Replaced by a more recent search.';

  @override
  String get browserResponseTooLarge => 'Response too large.';

  @override
  String get serverTitle => 'Server';

  @override
  String get serverClear => 'Clear';

  @override
  String get serverUnavailableNoSecret =>
      'This build of the app can\'t link servers: whoever compiled it didn\'t provide the Web client secret (GOOGLE_SERVER_CLIENT_SECRET).';

  @override
  String get serverUnavailableAndroidOnly =>
      'Servers can only be linked from Android.';

  @override
  String get serverSignInRequired => 'Sign in with Google to use the server.';

  @override
  String get serverNoConnection => 'No connection.';

  @override
  String get serverMissingGoogleServices =>
      'google-services.json is missing: this build has no Google client.';

  @override
  String get serverDriveAccessDenied => 'Google didn\'t grant access to Drive.';

  @override
  String get serverGoogleNotResponding =>
      'Google isn\'t responding: try again shortly.';

  @override
  String serverWhenToday(String clock) {
    return 'today at $clock';
  }

  @override
  String serverWhenDate(String date, String clock) {
    return '$date at $clock';
  }

  @override
  String serverProgressStats(int pages, String size, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: ' · $skipped already in place',
      zero: '',
    );
    return '$pages new pages · $size$_temp0';
  }

  @override
  String get serverRemoveFromQueue => 'Remove from queue';

  @override
  String get serverNoFirebase =>
      'The server recognizes its users by their Google account, which this build of the app doesn\'t have.';

  @override
  String get serverSignedOutIntro =>
      'A computer that\'s always on can download and upload to your Drive in place of your phone, which can even be turned off in the meantime. The server recognizes you by your Google account.';

  @override
  String get serverSignIn => 'Sign in with Google';

  @override
  String get serverSignInSubtitle =>
      'To create your own server or use someone else\'s';

  @override
  String serverInviteTitle(String sender, String serverName) {
    return '$sender gave you access to \"$serverName\"';
  }

  @override
  String get serverInviteSubtitle =>
      'Downloads to your Drive, even with your phone off. Tap to link it';

  @override
  String get serverIgnore => 'Ignore';

  @override
  String get serverLinkIntro =>
      'A computer that\'s always on, yours or one belonging to someone who gave you access, can download and upload to your Drive in place of your phone, which can even be turned off in the meantime.';

  @override
  String get serverCreate => 'Create your server';

  @override
  String get serverCreateSubtitle =>
      'A command to paste on a computer with Docker: nothing to configure';

  @override
  String get serverLinkTitle => 'Link a server';

  @override
  String get serverLinkSubtitle =>
      'Your own, already running, or one belonging to someone who added you';

  @override
  String get serverStateConnecting => 'Connecting…';

  @override
  String get serverStateNoGrant =>
      'Doesn\'t have permission for your Drive yet';

  @override
  String get serverStateNoFolder =>
      'Doesn\'t know yet which folder on your Drive to write to';

  @override
  String serverStateReady(String folder) {
    return 'Ready · writes to \"$folder\" on your Drive';
  }

  @override
  String serverTileSubtitle(String address, String state) {
    return '$address · $state';
  }

  @override
  String serverTileSubtitleOwner(String address, String owner, String state) {
    return '$address · $owner\'s · $state';
  }

  @override
  String get serverPlainTitle => 'The connection is unencrypted';

  @override
  String get serverPlainSubtitle =>
      'Your account token can be read in transit: you need HTTPS (Tailscale Funnel, a reverse proxy)';

  @override
  String get serverGrantTitle => 'Give the server your Drive';

  @override
  String get serverGrantSubtitle =>
      'It will download to the folder the app reads, even with your phone off';

  @override
  String get serverUseAppFolder => 'Use the app\'s folder';

  @override
  String serverUseAppFolderSubtitle(String serverFolder, String appFolder) {
    return 'The server writes to \"$serverFolder\", the app reads \"$appFolder\"';
  }

  @override
  String get serverUsersTitle => 'Who can use it';

  @override
  String get serverUsersOnlyYou => 'Only you. Add anyone\'s Google account';

  @override
  String serverUsersCount(int count) {
    return '$count accounts, including you';
  }

  @override
  String get serverQueueWaiting => 'Queue waiting';

  @override
  String get serverQueueRestarts => 'The server restarts on its own';

  @override
  String get serverJobAutomatic => 'New chapters · on the server';

  @override
  String get serverJobQueued => 'Queued · on the server';

  @override
  String get serverOngoingTitle => 'Ongoing series on the server';

  @override
  String serverOngoingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count followed',
      zero: 'None for now',
    );
    return '$_temp0';
  }

  @override
  String get serverOngoingCheckOff => 'check off';

  @override
  String serverOngoingCheckAt(String clock) {
    return 'check at $clock';
  }

  @override
  String serverOngoingSubtitle(String count, String check) {
    return '$count · $check. Tap to check now';
  }

  @override
  String serverSeriesKnown(int count) {
    return '$count known chapters';
  }

  @override
  String serverSeriesKnownChecked(int count, String when) {
    return '$count known chapters · checked $when';
  }

  @override
  String get serverStopFollowing => 'Stop following';

  @override
  String get serverInviteRemoveFailed =>
      'Couldn\'t remove the invitation: try again.';

  @override
  String get serverCheckingNow =>
      'The server is checking: new chapters will show up in its queue.';

  @override
  String get serverPaste => 'Paste';

  @override
  String get serverAddressExposed =>
      'Warning: over an unencrypted connection to a public address, your account token can be read in transit. Use HTTPS (Tailscale Funnel, a reverse proxy) or Tailscale.';

  @override
  String get serverAddressSavedNote =>
      'The address travels with your backup and your account, like the Drive folder.';

  @override
  String get serverAddressMissing =>
      'Enter the server\'s address, for example http://192.168.1.20:8080.';

  @override
  String serverLinked(String name, String folder) {
    return 'Linked to \"$name\": it downloads to \"$folder\" on your Drive.';
  }

  @override
  String serverLinkFromInvite(String sender, String serverName) {
    return '$sender added you to \"$serverName\". Once linked, the server will download the manga you choose into your library folder on your Drive: Google will ask you to let it write there. Whoever runs the server will be able to use that permission.';
  }

  @override
  String serverLinkLinked(String account) {
    return 'The server recognizes you as $account. If it isn\'t yours, unlinking it also makes it forget the permission for your Drive and your queue.';
  }

  @override
  String get serverSignedInAccount => 'the account you signed in with';

  @override
  String get serverLinkNew =>
      'Enter the server\'s address: your own, or the one given to you by whoever added you. The server recognizes you by your Google account, and the first time you give it permission to write to your library folder on Drive.';

  @override
  String get serverVerifying => 'Checking…';

  @override
  String get serverVerifyAgain => 'Check again';

  @override
  String get serverVerifyAndLink => 'Check and link';

  @override
  String get serverUnlink => 'Unlink';

  @override
  String get serverDefaultNameOwn => 'My Kagami Server';

  @override
  String serverDefaultNameOf(String name) {
    return '$name\'s server';
  }

  @override
  String get serverCommandCopied => 'Command copied.';

  @override
  String get serverComputerAddressMissing =>
      'Enter the computer\'s address, for example http://192.168.1.20:8080.';

  @override
  String serverNotOwner(String owner) {
    return 'That server belongs to $owner: it\'s linked, but you didn\'t create it.';
  }

  @override
  String serverReady(String name) {
    return '\"$name\" is ready. Add anyone you like from \"Who can use it\".';
  }

  @override
  String get serverLibraryFolderFallback => 'the library folder';

  @override
  String serverSetupIntro(String folder) {
    return 'You need a computer that stays on, such as a mini PC, a NAS, a Raspberry Pi or a networked server, with Docker. The server downloads manga and uploads them to your Drive, in \"$folder\", even with your phone off.';
  }

  @override
  String serverPrepareIntro(String signIn, String folder) {
    String _temp0 = intl.Intl.selectLogic(signIn, {
      'yes': 'first sign in with Google, then ',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(folder, {
      'yes': 'choose the manga folder on Drive, then ',
      'other': '',
    });
    return 'I\'ll prepare a command that contains everything: $_temp0${_temp1}Google asks you to allow the server to write to your Drive.';
  }

  @override
  String get serverPreparing => 'Preparing…';

  @override
  String get serverGenerate => 'Generate the command';

  @override
  String get serverStep1 =>
      'Install Docker on the computer (docker.com), if it isn\'t there already.';

  @override
  String get serverStep2 =>
      'Paste these commands into its terminal: the first starts the server, the second keeps it up to date on its own. They contain the permission for your Drive: don\'t send them to anyone.';

  @override
  String get serverCopyCommand => 'Copy the command';

  @override
  String get serverStep3 =>
      'Enter the computer\'s address here: at home, its local network address; from outside, its Tailscale name or the HTTPS address you expose it on.';

  @override
  String get serverPortNote => 'The server responds on port 8080.';

  @override
  String get serverUsersIntro =>
      'Add anyone\'s Google account. The invitation will appear in their Kagami app: once they link the server, their downloads will go to their own Drive, with their own queue.';

  @override
  String get serverUserEmailInvalid =>
      'Enter the Google account address, for example name@gmail.com.';

  @override
  String serverUserAdded(String email) {
    return '$email can use the server: their app will tell them.';
  }

  @override
  String serverRemoveTitle(String email) {
    return 'Remove $email?';
  }

  @override
  String get serverRemoveBody =>
      'They won\'t be able to use the server anymore. Their queue and the permission for their Drive are deleted; what\'s already on their Drive stays.';

  @override
  String get serverCancel => 'Cancel';

  @override
  String get serverRemove => 'Remove';

  @override
  String get serverAdd => 'Add';

  @override
  String get serverOwnerYou => 'You, the owner';

  @override
  String get serverConnected => 'Has linked the server';

  @override
  String get serverInvitedPending => 'Invited, hasn\'t linked the server yet';

  @override
  String get setupIntro =>
      'Reads the manga folder that syncing places on your phone, or the same library straight from Google Drive, without bringing all of it here.';

  @override
  String get setupAccessTitle => 'File access';

  @override
  String get setupAccessBody =>
      'The folder is outside the app\'s private space and holds tens of thousands of images: Kagami needs to read them directly. It only writes copies of your data in the library\'s reading/ subfolder and, if you ask, the chapters you download from Drive.';

  @override
  String get setupGrantAccess => 'Grant access';

  @override
  String get setupFolderTitle => 'The folder';

  @override
  String get setupFolderBody =>
      'Choose the folder synced by FolderSync: the one that contains library.json and one subfolder per series.';

  @override
  String get setupChooseFolder => 'Choose folder';

  @override
  String get setupOr => 'or';

  @override
  String get setupDriveTitle => 'Google Drive';

  @override
  String get setupDriveBody =>
      'Sign in with Google and choose the library folder on Drive: pages arrive as you read, and the chapters you want always at hand can be downloaded with a tap. No access to your phone\'s files is needed.';

  @override
  String get setupReadFromDrive => 'Read from Google Drive';

  @override
  String get setupLibraryProblemTitle => 'Library can\'t be read';

  @override
  String get setupChangeFolder => 'Change folder';

  @override
  String get driveFolderSheetTitle => 'Folder on Drive';

  @override
  String get driveDestinationTitle => 'Where should I save manga?';

  @override
  String get driveDestinationBody =>
      'There\'s no manga folder on your phone. In a folder, downloaded chapters stay even if the app is uninstalled, and Kagami reads them together with the ones already there. In the app\'s space no permission is needed, but they go away with the app.';

  @override
  String get driveChooseFolder => 'Choose a folder';

  @override
  String get driveInAppSpace => 'In the app\'s space';

  @override
  String get driveMyDrive => 'My Drive';

  @override
  String get driveSharedWithMe => 'Shared with me';

  @override
  String get driveBack => 'Back';

  @override
  String get driveNoResponse => 'Drive isn\'t responding';

  @override
  String get driveRetry => 'Retry';

  @override
  String get driveIsLibrary => 'Contains library.json: it\'s a library';

  @override
  String get driveNotLibrary =>
      'Doesn\'t contain library.json: the library is the folder that has it';

  @override
  String get driveUseFolder => 'Use this folder';

  @override
  String get driveNoFolders => 'No folders here';

  @override
  String get driveNoticeAuthRequired =>
      'Kagami doesn\'t have permission to read Google Drive yet';

  @override
  String get driveAuthorize => 'Authorize';

  @override
  String get driveSignIn => 'Sign in';

  @override
  String get driveNoticeOffline =>
      'You\'re offline: you can read the chapters on your phone and the Drive pages already downloaded. The rest comes back on its own when the network does';

  @override
  String driveNoticeError(String message) {
    return 'Drive: $message. Showing what\'s on your phone';
  }

  @override
  String get syncSummaryOff => 'Off';

  @override
  String get syncSummaryDownload => 'Drive to phone';

  @override
  String get syncSummaryUpload => 'Phone to Drive';

  @override
  String get syncSummaryBoth => 'Both directions';

  @override
  String syncSummaryManual(String direction) {
    return '$direction, manual';
  }

  @override
  String syncSummaryDaily(String direction, String time) {
    return '$direction, every day at $time';
  }

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncIntro =>
      'Keeps the manga folder on your phone and the one on Drive identical, without FolderSync. If you still use it on this folder, turn it off: two syncs on the same files get in each other\'s way.';

  @override
  String get syncFolders => 'Folders';

  @override
  String get syncOnPhone => 'On phone';

  @override
  String get syncNoFolderChosen => 'No folder chosen';

  @override
  String get syncOnDrive => 'On Drive';

  @override
  String get syncDriveNotConnected => 'Drive isn\'t connected';

  @override
  String get syncDirection => 'Direction';

  @override
  String get syncDirectionOff => 'Off';

  @override
  String get syncDirectionFromDrive => 'From Drive';

  @override
  String get syncDirectionToDrive => 'To Drive';

  @override
  String get syncDirectionBoth => 'Both';

  @override
  String get syncDescOff =>
      'Nothing moves on its own. The Drive library can still be read, and \"Download\" works as usual.';

  @override
  String get syncDescDownload =>
      'What arrives on Drive comes down to your phone. Nothing goes up from your phone.';

  @override
  String get syncDescUpload =>
      'What\'s on your phone goes up to Drive, for example the data copies in reading/backup. Library indexes stay the server\'s.';

  @override
  String get syncDescBoth =>
      'What changes on one side arrives on the other; if both changed, the most recent wins. Library indexes only come down: they belong to the server.';

  @override
  String get syncDeletions => 'Propagate deletions';

  @override
  String get syncDeletionsDownload =>
      'Removes from your phone what disappears from Drive';

  @override
  String get syncDeletionsUpload =>
      'Moves to Drive\'s trash what you remove from your phone';

  @override
  String get syncDeletionsBoth =>
      'From one side to the other; from Drive only to the trash';

  @override
  String get syncDeletionsOnNote =>
      '\"Free up space\" also removes read chapters from Drive, on the next run.';

  @override
  String get syncDeletionsOffNote =>
      'A file removed on one side stays on the other and doesn\'t come back: \"Free up space\" frees your phone and leaves the chapters on Drive.';

  @override
  String get syncDaily => 'Every day';

  @override
  String get syncScheduled => 'Scheduled sync';

  @override
  String get syncManualOnly => 'Manual only';

  @override
  String syncAtTime(String time) {
    return 'At $time, even when the app is closed';
  }

  @override
  String get syncTime => 'Time';

  @override
  String get syncWifiOnly => 'Wi-Fi only';

  @override
  String get syncWifiOnlyOn => 'Waits for a network that isn\'t metered';

  @override
  String get syncWifiOnlyOff => 'Mobile data too';

  @override
  String get syncScheduleNote =>
      'Android decides the exact moment: if there\'s no network at the chosen time, the run starts as soon as it\'s back.';

  @override
  String get syncNow => 'Now';

  @override
  String get syncTimePickerHelp => 'Sync time';

  @override
  String get syncRunNow => 'Sync now';

  @override
  String get syncRunNowReady =>
      'You can keep reading: copying carries on by itself';

  @override
  String get syncRunNowNotReady =>
      'The phone folder and the Drive folder are both needed';

  @override
  String get syncPhaseListing => 'Checking what\'s on Drive…';

  @override
  String get syncPhaseComparing => 'Comparing with the phone…';

  @override
  String get syncPhaseNothing => 'Nothing to copy';

  @override
  String syncPhaseFiles(int done, int total) {
    return 'File $done of $total';
  }

  @override
  String get syncStop => 'Stop';

  @override
  String get syncNever => 'Never synced';

  @override
  String get syncNeverNote =>
      'The first run on an already full folder is quick: identical files are recognized by their size';

  @override
  String syncLastScheduled(String date, String time) {
    return 'Last, scheduled: $date at $time';
  }

  @override
  String syncLastManual(String date, String time) {
    return 'Last, manual: $date at $time';
  }

  @override
  String syncOutcomeDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloaded',
      one: '$count downloaded',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeUploaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uploaded',
      one: '$count uploaded',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeDeletedLocal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count removed from phone',
      one: '$count removed from phone',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeTrashed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count in Drive\'s trash',
      one: '$count in Drive\'s trash',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count failed, will retry',
      one: '$count failed, will retry',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeErrorSoFar(String error, String done) {
    return '$error. So far: $done';
  }

  @override
  String get syncOutcomeAligned => 'Everything was already in sync';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeSystem => 'Same as system';

  @override
  String get settingsLibrary => 'Library';

  @override
  String get settingsFolder => 'Folder';

  @override
  String get settingsNoFolder => 'No folder chosen';

  @override
  String get settingsReloadIndexes => 'Reload indexes';

  @override
  String get settingsReloadIndexesNote =>
      'Do this when syncing has just brought new stuff';

  @override
  String get settingsIndexesReloaded => 'Indexes reloaded';

  @override
  String get settingsGoogleDrive => 'Google Drive';

  @override
  String get settingsReading => 'Reading';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAutoBackup => 'Automatic copy in the library';

  @override
  String get settingsAutoBackupNote =>
      'Once a day in reading/backup/, which syncing carries to Drive along with the manga';

  @override
  String get settingsExport => 'Export data';

  @override
  String get settingsExportNote =>
      'Status, ratings, history, collections and bookmarks in one file';

  @override
  String get settingsExportDialog => 'Where to save the backup';

  @override
  String get settingsExportCancelled => 'Export cancelled';

  @override
  String get settingsExportSaved => 'Backup saved';

  @override
  String get settingsImport => 'Import from a backup';

  @override
  String get settingsImportNote =>
      'Shows what it contains before touching anything';

  @override
  String get settingsImportDialog => 'Choose a Kagami backup';

  @override
  String get settingsImportInvalid => 'Not a Kagami backup';

  @override
  String get settingsImportSheetTitle => 'Import this backup?';

  @override
  String get settingsImportSeries => 'Series';

  @override
  String get settingsImportRead => 'Read';

  @override
  String get settingsImportCollections => 'Collections';

  @override
  String settingsImportExplain(String date) {
    return 'Made on $date. Merge keeps what you already have and adds to it: read chapters are combined and for everything else the most recent record wins. Replace deletes the data on this device.';
  }

  @override
  String get settingsImportExplainUnknownDate =>
      'Made on an unknown date. Merge keeps what you already have and adds to it: read chapters are combined and for everything else the most recent record wins. Replace deletes the data on this device.';

  @override
  String get settingsImportMerge => 'Merge';

  @override
  String get settingsImportReplace => 'Replace';

  @override
  String get settingsImportDone => 'Data imported';

  @override
  String get settingsImportFailed => 'Import failed';

  @override
  String get settingsWipe => 'Delete personal data';

  @override
  String get settingsWipeNote =>
      'Status, ratings, history and collections. Your manga aren\'t touched';

  @override
  String get settingsWipeSheetTitle => 'Delete all personal data?';

  @override
  String get settingsWipeExplain =>
      'Status, ratings, favorites, read chapters, history, sessions, collections and bookmarks on this device will disappear. Your manga and the library indexes aren\'t touched.\n\nIf you don\'t have a backup, this is your last chance to make one.';

  @override
  String get settingsWipeConfirm => 'Delete everything';

  @override
  String get settingsWipeDone => 'Personal data deleted';

  @override
  String get settingsDriveConnect => 'Connect Google Drive';

  @override
  String get settingsDriveConnectNote =>
      'Reads the library from Drive without bringing all of it to your phone, and downloads only what you choose';

  @override
  String get settingsDriveFolder => 'Folder on Drive';

  @override
  String get settingsDriveSync => 'Folder sync';

  @override
  String get settingsDriveDownloadsGo => 'Downloaded chapters go';

  @override
  String settingsDriveDownloadsFolder(String path) {
    return 'In the library folder: $path';
  }

  @override
  String get settingsDriveDownloadsApp =>
      'In the app\'s space: they\'re lost if you uninstall it';

  @override
  String get settingsDriveDownloadsAsk => 'Asked at the first download';

  @override
  String get settingsDriveCache => 'Pages read from Drive';

  @override
  String settingsDriveCacheNote(String used, String limit) {
    return '$used cached, up to $limit. They can be reread without a network';
  }

  @override
  String get settingsDriveCacheLimitTitle => 'Space for pages';

  @override
  String get settingsDriveClearCache => 'Clear the cache';

  @override
  String get settingsDriveClearCacheNote =>
      'Downloaded chapters aren\'t touched';

  @override
  String get settingsDriveDisconnect => 'Disconnect Drive';

  @override
  String get settingsDriveDisconnectNote =>
      'The library goes back to being the phone folder. Downloaded chapters stay';

  @override
  String get settingsAccountUnavailable => 'Account not available here';

  @override
  String get settingsAccountUnavailableNote =>
      'This build doesn\'t have Firebase: your data stays where it is, on the device';

  @override
  String get settingsAccountSignIn => 'Sign in with Google';

  @override
  String get settingsAccountSignInNote =>
      'Ratings, status, read chapters, history and collections follow your account instead of your phone';

  @override
  String get settingsAccountSyncNow => 'Sync now';

  @override
  String get settingsAccountNeverSynced => 'Never synced on this phone';

  @override
  String settingsAccountLastSync(String date, String time) {
    return 'Last time on $date at $time';
  }

  @override
  String get settingsAccountSignOut => 'Sign out';

  @override
  String get settingsAccountSignOutNote =>
      'Uploads your latest reading, then signs out';

  @override
  String get settingsAccountForget => 'Stop keeping a copy';

  @override
  String get settingsAccountForgetNote =>
      'Deletes the data from your account. The data on this phone stays where it is';

  @override
  String get settingsAccountErrorNote =>
      'The data on this phone wasn\'t touched';

  @override
  String get settingsAccountForgetSheetTitle =>
      'Delete the data from your account?';

  @override
  String get settingsAccountForgetExplain =>
      'The copy kept for you disappears, and you\'re signed out. Status, ratings, history and collections on this phone stay where they are, but another phone won\'t see them anymore.';

  @override
  String get settingsAccountForgetConfirm => 'Delete from account';

  @override
  String get settingsReaderDirection => 'Direction in paged mode';

  @override
  String get settingsReaderBackground => 'Background';

  @override
  String get settingsReaderKeepAwake => 'Keep screen on';

  @override
  String get settingsReaderProgressBar => 'Progress bar';

  @override
  String get settingsProbe => 'Measure smoothness';

  @override
  String get settingsProbeNote =>
      'In the reader, at the top: slow and dropped frames, where the strips come from, GC. Tap the numbers to reset them';

  @override
  String get settingsProbeInfo1 =>
      'Shows a box of numbers at the top left of the reader about how smooth reading is. It helps figure out why scrolling stutters: it doesn\'t change anything about how you read, and it costs almost nothing.';

  @override
  String get settingsProbeInfo2 =>
      'The most important number is \"dropped\": the frames that go missing while the page scrolls. Each one is a small visible stutter. \"Started late\" and \"Slow\" tell you whether the app was busy, \"Android GC\" whether the system was freeing memory.';

  @override
  String get settingsProbeInfo3 =>
      '\"Tiles\", \"whole\", \"from phone\" and \"Native\" tell you where each piece of a page came from: the first three are the light routes, the last is the crop made on the spot, which is the heavy one.';

  @override
  String get settingsProbeInfo4 =>
      'Tapping the box resets the numbers, so you can measure from a precise point in the chapter. When you reopen the app, measuring turns itself off.';

  @override
  String get settingsTexture => 'Native strips as textures';

  @override
  String get settingsTextureNote =>
      'Experimental: pages still to be cut reach the GPU without going through the interface. Turns off when you reopen the app';

  @override
  String get settingsTextureInfo1 =>
      'Very tall webtoon pages are read in pieces. Almost always the pieces are already prepared: cut by the archiver on the server, or by the phone the first time the chapter is opened. When they aren\'t, Android\'s decoder crops them on the spot.';

  @override
  String get settingsTextureInfo2 =>
      'Normally the pixels of those pieces pass through the app before reaching the screen. With this option they go straight to the graphics card: the app has less work while you scroll, and scrolling may stutter less. Image quality doesn\'t change.';

  @override
  String get settingsTextureInfo3 =>
      'It\'s an experiment: a new way of drawing, not yet verified on this phone. If you see black pages, lines or flickering, turn it off. If your phone doesn\'t support it, the app goes back to the normal way by itself.';

  @override
  String get settingsTextureInfo4 =>
      'Nothing changes on chapters already cut into tiles, because this route isn\'t used there. It turns itself off when you reopen the app.';

  @override
  String get settingsWhatItDoes => 'What it does';

  @override
  String get settingsBackupsTitle => 'Copies in the library';

  @override
  String get settingsBackupsNone =>
      'No copies yet: the first is made the next time you open the app';

  @override
  String settingsBackupsLatest(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copies, the latest $name',
      one: '1 copy, the latest $name',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupNow => 'Make a copy now';

  @override
  String settingsBackupWritten(String path) {
    return 'Copy written to $path';
  }

  @override
  String settingsVersion(String version, String build) {
    return 'version $version ($build)';
  }

  @override
  String get settingsTagline => 'reader for local MALF archives';

  @override
  String get librarySortUpdated => 'Recently updated';

  @override
  String get librarySortTitle => 'Title';

  @override
  String get librarySortProgress => 'Progress';

  @override
  String get librarySortAdded => 'Recently added';

  @override
  String get librarySortLastRead => 'Recently read';

  @override
  String get librarySortUnread => 'Unread';

  @override
  String get librarySortRating => 'Rating';

  @override
  String get librarySortChapters => 'Number of chapters';

  @override
  String get librarySortShuffle => 'Random';

  @override
  String get libraryDisplayComfortable => 'Comfortable grid';

  @override
  String get libraryDisplayCompact => 'Compact grid';

  @override
  String get libraryDisplayList => 'List';

  @override
  String get libraryDisplayDetailed => 'Detailed list';

  @override
  String get libraryAutoReading => 'Reading';

  @override
  String get libraryAutoFresh => 'What\'s new';

  @override
  String get libraryAutoFavorites => 'Favorites';

  @override
  String get libraryAutoPlanned => 'Not started';

  @override
  String get libraryAutoFinished => 'Finished';

  @override
  String libraryRowChapters(int count) {
    return '$count ch.';
  }

  @override
  String libraryRowUnread(int count) {
    return '$count unread';
  }

  @override
  String get libraryNoMatchTitle => 'No matches';

  @override
  String get libraryNoMatchMessage =>
      'No series matches your search and filters.';

  @override
  String get libraryEmptyTitle => 'Empty library';

  @override
  String get libraryEmptyMessage =>
      'The library contains no series. If it should, check the folder sync.';

  @override
  String get libraryClearFilters => 'Clear filters';

  @override
  String get libraryTitle => 'Library';

  @override
  String get libraryCancelSelection => 'Cancel selection';

  @override
  String librarySelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String libraryAllWithCount(int count) {
    return 'All ($count)';
  }

  @override
  String get libraryAll => 'All';

  @override
  String get libraryMarkAllRead => 'Mark all as read';

  @override
  String get libraryMarkAllUnread => 'Mark all as unread';

  @override
  String get libraryStatus => 'Status';

  @override
  String get libraryFavorites => 'Favorites';

  @override
  String get libraryAddToCollection => 'Add to a collection';

  @override
  String libraryStatusOfSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Status of $count series',
      one: 'Status of 1 series',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series marked as read',
      one: '1 series marked as read',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series marked as unread',
      one: '1 series marked as unread',
    );
    return '$_temp0';
  }

  @override
  String get librarySearchHint => 'Title, author, tag:…';

  @override
  String get libraryLayout => 'Layout';

  @override
  String get libraryFiltersAndSort => 'Filters and sorting';

  @override
  String get libraryReset => 'Reset';

  @override
  String get librarySortSection => 'Sort';

  @override
  String get libraryShowOnly => 'Show only';

  @override
  String get libraryOnlyUnread => 'With unread chapters';

  @override
  String get libraryOnlyStarted => 'Started';

  @override
  String get libraryOnlyNew => 'With new chapters';

  @override
  String get libraryOnlyFavorite => 'Favorites';

  @override
  String get libraryMinRating => 'Rating at least';

  @override
  String get libraryRelease => 'Release status';

  @override
  String get libraryGenres => 'Genres';

  @override
  String get libraryTriHint => 'One tap includes, two exclude';

  @override
  String get libraryTags => 'Tags';

  @override
  String get libraryAuthors => 'Authors';

  @override
  String get homeEmptyTitle => 'Empty library';

  @override
  String get homeEmptyMessage =>
      'Nothing to browse: the folder doesn\'t contain any series yet.';

  @override
  String get homeToStart => 'Not started';

  @override
  String get homeSimilarTitle => 'Because of what you read';

  @override
  String get homeSimilarSubtitle => 'Not opened yet, with genres you like';

  @override
  String get homeRecentlyArrived => 'Recently arrived';

  @override
  String get homeLeftHalfway => 'Left halfway';

  @override
  String get homeLeftHalfwaySubtitle => 'On hold and dropped';

  @override
  String get homeCaughtUpTitle => 'You\'re all caught up';

  @override
  String get homeCaughtUpMessage =>
      'With everything that\'s synced. The next chapter will arrive with the folder.';

  @override
  String get homeRandomSeries => 'Random series';

  @override
  String get homeReloadLibrary => 'Reload the library';

  @override
  String get homeGreetingNight => 'Late night';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeStatRead => 'Read';

  @override
  String get homeStatReadCaption => 'chapters in total';

  @override
  String get homeStatUnread => 'Unread';

  @override
  String get homeStatUnreadCaption => 'on the phone';

  @override
  String get homeStatStreak => 'Streak';

  @override
  String homeStatStreakCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return '$_temp0';
  }

  @override
  String get homeResume => 'Resume';

  @override
  String get homeNextChapter => 'Next chapter';

  @override
  String get homeRead => 'Read';

  @override
  String get homeUpdates => 'Updates';

  @override
  String get homeUpdatesSubtitle => 'Synced chapters not yet read';

  @override
  String homeLatestChapter(String number) {
    return 'ch. $number';
  }

  @override
  String get homeAgoToday => 'today';

  @override
  String get homeAgoYesterday => 'yesterday';

  @override
  String homeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String homeAgoWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks ago',
      one: '1 week ago',
    );
    return '$_temp0';
  }

  @override
  String homeAgoMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String homeAgoYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }

  @override
  String get collectionsTitle => 'Collections';

  @override
  String get collectionsNew => 'New';

  @override
  String get collectionsAutomatic => 'Automatic';

  @override
  String get collectionsYours => 'Your collections';

  @override
  String get collectionsNoneTitle => 'No collections';

  @override
  String get collectionsNoneMessage =>
      'They\'re a way to give structure to a library that grows on its own: a series can be in several collections and you choose the order.';

  @override
  String collectionsSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series',
      one: '1 series',
    );
    return '$_temp0';
  }

  @override
  String get collectionsEdit => 'Edit';

  @override
  String get collectionsRenameRecolor => 'Rename and change color';

  @override
  String get collectionsDelete => 'Delete collection';

  @override
  String get collectionsNotFound => 'Collection not found.';

  @override
  String get collectionsDone => 'Done';

  @override
  String get collectionsReorder => 'Reorder';

  @override
  String get collectionsEmptyTitle => 'Empty collection';

  @override
  String get collectionsEmptyMessage =>
      'Add a series from its page, or by long-pressing a cover in the library.';

  @override
  String get collectionsRemoveFrom => 'Remove from collection';

  @override
  String get shellDataUnreadableTitle => 'App data can\'t be read';

  @override
  String get shellRetry => 'Retry';

  @override
  String get shellTabHome => 'Home';

  @override
  String get shellTabLibrary => 'Library';

  @override
  String get shellTabCollections => 'Collections';

  @override
  String get shellTabMore => 'More';

  @override
  String get moreTitle => 'More';

  @override
  String get moreSectionLibrary => 'Library';

  @override
  String get moreSectionReading => 'Your reading';

  @override
  String get moreSectionPrivacy => 'Privacy';

  @override
  String get moreSectionApp => 'App';

  @override
  String get moreDownload => 'Download a manga';

  @override
  String get moreDownloadSubtitle => 'Search for a title or paste a link';

  @override
  String get moreHistory => 'History';

  @override
  String get moreHistorySubtitle => 'What you read and when';

  @override
  String get moreStatistics => 'Statistics';

  @override
  String get moreStatisticsSubtitle => 'How much you read, what you read, when';

  @override
  String get moreIncognito => 'Incognito reading';

  @override
  String get moreIncognitoSubtitle =>
      'Doesn\'t record position, finished chapters or reading time';

  @override
  String get moreSettings => 'Settings';

  @override
  String get moreSettingsSubtitle => 'Appearance, library, reading, backup';

  @override
  String get historyTitle => 'History';

  @override
  String get historyIncognitoOn => 'Incognito on';

  @override
  String get historyIncognitoOff => 'Read incognito';

  @override
  String get historyClear => 'Clear';

  @override
  String get historyUnreadable => 'History can\'t be read';

  @override
  String get historyEmptyTitle => 'Nothing read, for now';

  @override
  String get historyEmptyMessage =>
      'Every finished chapter will appear here with its date.';

  @override
  String get historyClearTitle => 'Clear history?';

  @override
  String get historyClearMessage =>
      'Reading dates and time spent reading disappear, and so do the statistics based on them. Chapters go back to unread.';

  @override
  String get historyIncognitoBanner =>
      'Incognito: position, finished chapters and reading time aren\'t recorded.';

  @override
  String get historyToday => 'Today';

  @override
  String get historyYesterday => 'Yesterday';

  @override
  String get historyReread => 'Read again';

  @override
  String get historyRemove => 'Remove from history';

  @override
  String get originLocal => 'On phone';

  @override
  String get originDrive => 'On Drive';

  @override
  String get originMixed => 'On phone, and other chapters on Drive';

  @override
  String get coverNoChapters => 'No chapters downloaded';

  @override
  String coverChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ch.',
    );
    return '$_temp0';
  }

  @override
  String coverChaptersUnread(int count, int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ch.',
    );
    return '$_temp0 · $unread unread';
  }

  @override
  String coverNewChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new chapters',
      one: '1 new chapter',
    );
    return '$_temp0';
  }

  @override
  String coverUnread(int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '$unread unread chapters',
      one: '1 unread chapter',
    );
    return '$_temp0';
  }

  @override
  String coverUnreadFresh(int unread, int fresh) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '$unread unread chapters',
      one: '1 unread chapter',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fresh,
      locale: localeName,
      other: '$fresh of them new',
      one: '1 of them new',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String chartsDayNothing(String date) {
    return '$date: nothing';
  }

  @override
  String chartsDayChapters(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$date: $_temp0';
  }

  @override
  String get kitClose => 'Close';

  @override
  String get collectionSheetTitle => 'Collections';

  @override
  String collectionSheetTitleMany(int count) {
    return 'Collections of $count series';
  }

  @override
  String get collectionSheetNew => 'New';

  @override
  String get collectionSheetEmptyTitle => 'No collections';

  @override
  String get collectionSheetEmptyMessage =>
      'They give structure to a library that grows on its own.';

  @override
  String collectionSheetSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series',
      one: '1 series',
    );
    return '$_temp0';
  }

  @override
  String get collectionSheetCreateTitle => 'New collection';

  @override
  String get collectionSheetEditTitle => 'Edit collection';

  @override
  String get collectionSheetNameHint => 'Name';

  @override
  String get collectionSheetColor => 'Color';

  @override
  String get collectionSheetCreate => 'Create';

  @override
  String get collectionSheetSave => 'Save';

  @override
  String get cleanupTitle => 'Free up space?';

  @override
  String get cleanupSyncBusy =>
      'A sync is in progress: try again when it finishes';

  @override
  String cleanupNotAllDeleted(String error) {
    return 'Not everything was deleted: $error';
  }

  @override
  String cleanupDriveError(String error) {
    return 'Drive: $error. The ones already removed stay removed';
  }

  @override
  String cleanupFreed(String size) {
    return 'Freed $size';
  }

  @override
  String get cleanupNeedsNetwork => 'You need a network to remove from Drive';

  @override
  String cleanupIntroDrive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters you\'ve already read are still on Drive.',
      one: '1 chapter you\'ve already read is still on Drive.',
    );
    return '$_temp0';
  }

  @override
  String cleanupIntroPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count chapters you\'ve already read still take up space on your phone.',
      one: '1 chapter you\'ve already read still takes up space on your phone.',
    );
    return '$_temp0';
  }

  @override
  String get cleanupPhoneChapters => 'Chapters on phone';

  @override
  String get cleanupDriveCache => 'Drive cache';

  @override
  String get cleanupDriveChapters => 'Chapters on Drive';

  @override
  String cleanupApproxSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$_temp0 · about $size';
  }

  @override
  String cleanupExactSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$_temp0 · $size';
  }

  @override
  String cleanupApproxSizeTrash(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$_temp0 · about $size · to the trash';
  }

  @override
  String get cleanupQuiet => 'Don\'t ask again for this series';

  @override
  String get cleanupWarnNotOnDrive =>
      'This series isn\'t on Drive: deleted chapters can\'t be read again until syncing brings them back.';

  @override
  String get cleanupWarnGoneEverywhere =>
      'They won\'t remain on your phone or on Drive.';

  @override
  String get cleanupWarnStaysOnDrive =>
      'The chapters stay on Drive and can be read again from there.';

  @override
  String get cleanupWarnTrash =>
      'They can be recovered from Drive\'s trash for 30 days. The server\'s index still lists them: if the server uploads them again, they can be read from Drive again.';

  @override
  String get cleanupDelete => 'Delete';

  @override
  String get cleanupNotNow => 'Not now';

  @override
  String get cleanupSyncWarnExternal =>
      'If FolderSync syncs the folder in both directions, the deletion may reach Drive too; if it only downloads, the chapters may come back on the next run.';

  @override
  String get cleanupSyncWarnOwn =>
      'Syncing respects this choice: what you remove on one side doesn\'t come back and doesn\'t disappear from the other, even with deletions propagated.';

  @override
  String get statsRangeMonth => '30 days';

  @override
  String get statsRangeQuarter => '3 months';

  @override
  String get statsRangeYear => '1 year';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statsUnavailable => 'Statistics can\'t be calculated';

  @override
  String get statsChaptersRead => 'chapters read';

  @override
  String get statsSeriesInLibrary => 'series in library';

  @override
  String statsMinutes(int count) {
    return '$count min';
  }

  @override
  String statsHours(int count) {
    return '$count h';
  }

  @override
  String get statsReadingTime => 'reading time';

  @override
  String get statsReadingTimeHint => 'measured while you read';

  @override
  String get statsPagesSeen => 'pages seen';

  @override
  String get statsStreak => 'days in a row';

  @override
  String statsStreakRecord(int count) {
    return 'record: $count';
  }

  @override
  String get statsAverageRating => 'average rating';

  @override
  String statsRatedSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series rated',
      one: '1 series rated',
    );
    return '$_temp0';
  }

  @override
  String get statsChaptersOverTime => 'Chapters read';

  @override
  String get statsPerWeek => 'per week';

  @override
  String get statsPerDay => 'per day';

  @override
  String get statsActivityTitle => 'When you read';

  @override
  String get statsActivitySubtitle =>
      'one square per day, over the last six months';

  @override
  String get statsShelfTitle => 'Library by status';

  @override
  String statsGenreOthers(int count) {
    return '$count others';
  }

  @override
  String get statsGenresTitle => 'Genres you read';

  @override
  String get statsGenresSubtitle => 'across the series you\'ve started';

  @override
  String get statsRatingsTitle => 'How you rate';

  @override
  String get statsRatingsSubtitle => 'how many series for each rating';

  @override
  String get statsTopSeries => 'Most read series';

  @override
  String get statsShapeTitle => 'What the library looks like';

  @override
  String get statsSyncedChapters => 'synced chapters';

  @override
  String get statsStillUnread => 'still unread';

  @override
  String get statsOngoingSeries => 'ongoing series';

  @override
  String statsAnnouncedMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters announced but not downloaded',
      one: '1 chapter announced but not downloaded',
    );
    return '$_temp0';
  }

  @override
  String get statsBytesOnPhone => 'taken up on the phone';

  @override
  String get statsNoHistory =>
      'Nothing read in this period. History starts from when the app began recording it.';

  @override
  String get dataDriveNotLinked => 'Drive isn\'t linked';

  @override
  String get dataChapterNotOnDrive => 'Chapter not found on Drive';

  @override
  String get dataChapterNoPagesOnDrive => 'The chapter has no pages on Drive';

  @override
  String get dataPageNotOnDrive => 'Page not found on Drive';

  @override
  String get dataPrefetchCancelled => 'Prefetch cancelled';

  @override
  String get dataDriveAccessDenied => 'Google didn\'t grant access to Drive';

  @override
  String get dataDriveOfflineNeverOpened =>
      'No connection, and the library on Drive has never been opened on this phone';

  @override
  String get dataDriveSignedOut =>
      'Sign in with Google to read the library on Drive';

  @override
  String get dataSyncMissingFolderOrDirection =>
      'The folder or the direction is missing';

  @override
  String get dataSyncFailed => 'Sync failed';

  @override
  String get dataSyncFolderUnreadable => 'The phone folder can\'t be read';

  @override
  String get dataSyncBusy => 'A sync is already in progress';

  @override
  String get dataSyncCancelled => 'Sync stopped';

  @override
  String get dataSyncDirectionDownload => 'From Drive';

  @override
  String get dataSyncDirectionUpload => 'To Drive';

  @override
  String get dataSyncDirectionBoth => 'Both';

  @override
  String dataServerInviteTitle(String sender) {
    return '$sender gave you access to their server';
  }

  @override
  String dataServerInviteText(String serverName) {
    return 'Link \"$serverName\" and it will download manga to your Drive, even with your phone off.';
  }

  @override
  String get dataServerSignInRequired =>
      'Sign in with Google to use the server.';

  @override
  String get dataServerNotLinked => 'No server linked.';

  @override
  String dataServerUserNotNotified(String email, String url) {
    return '$email can use the server, but I couldn\'t notify them: send them the address $url yourself.';
  }

  @override
  String get dataPickLibraryFolderTitle => 'Choose the manga library folder';

  @override
  String get dataCloudSignInNotEnabled =>
      'Google sign-in isn\'t enabled on this project yet';

  @override
  String get dataCloudNoConnection => 'No connection';

  @override
  String get dataCloudNoSignIn => 'Not signed in';

  @override
  String get dataCloudNoIdentityToken =>
      'Google didn\'t provide an identity token';

  @override
  String get dataCloudSignInFailed => 'Sign-in failed';

  @override
  String get dataCloudSignInInterrupted => 'Sign-in interrupted';

  @override
  String get dataCloudGoogleNotConfigured =>
      'Google isn\'t configured for this app';

  @override
  String get dataCloudGoogleSignInFailed => 'Google sign-in failed';

  @override
  String dataNewChaptersNotification(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new chapters have arrived',
      one: '1 new chapter has arrived',
    );
    return '$_temp0';
  }

  @override
  String get dataArchivePhoneFolderMissing => 'The phone folder is missing.';

  @override
  String get dataArchiveDriveFolderMissing => 'The Drive folder is missing.';

  @override
  String dataChapterLabel(String number) {
    return 'Chapter $number';
  }

  @override
  String get dataLibraryMissing =>
      'The folder doesn\'t exist or can\'t be read.';

  @override
  String get dataLibraryNotIndexed =>
      'The folder doesn\'t contain library.json: regenerate the indexes with the archiver that wrote the library.';

  @override
  String get dataLibraryUnreadable =>
      'library.json can\'t be read or isn\'t a valid MALF index.';

  @override
  String get dataLibraryUnsupported =>
      'library.json uses a newer version of the format than this app supports.';

  @override
  String get dataReaderModeContinuous => 'Continuous';

  @override
  String get dataReaderModePaged => 'Paged';

  @override
  String get dataReaderDirectionLtr => 'Left → right';

  @override
  String get dataReaderDirectionRtl => 'Right → left';

  @override
  String get dataReaderFitWidth => 'Width';

  @override
  String get dataReaderFitHeight => 'Height';

  @override
  String get dataReaderFitOriginal => 'Original';

  @override
  String get dataReaderBackgroundBlack => 'Black';

  @override
  String get dataReaderBackgroundGrey => 'Gray';

  @override
  String get dataReaderBackgroundWhite => 'White';

  @override
  String readerProbeFrames(String frames, String budget) {
    return 'Frames $frames · limit $budget ms';
  }

  @override
  String readerProbeSlow(
    String build,
    String buildMax,
    String raster,
    String rasterMax,
  ) {
    return 'Slow UI $build (max $buildMax ms) · GPU $raster (max $rasterMax ms)';
  }

  @override
  String readerProbeLate(String late, String lateMax) {
    return 'Started late $late (max $lateMax ms)';
  }

  @override
  String readerProbeScroll(String scroll, String missed, String gap) {
    return 'Scrolling $scroll · dropped $missed (max gap $gap ms)';
  }

  @override
  String readerProbeSources(
    String tiles,
    String whole,
    String phone,
    String phoneMade,
  ) {
    return 'Tiles $tiles · whole $whole · from phone $phone (made $phoneMade)';
  }

  @override
  String readerProbeNative(String bands, String textures, String decodes) {
    return 'Native $bands (texture $textures) · pages decoded $decodes';
  }

  @override
  String readerProbeDecode(
    String decode,
    String decodeMax,
    String arrival,
    String arrivalMax,
  ) {
    return 'Decode $decode ms (max $decodeMax) · arrival $arrival ms (max $arrivalMax)';
  }

  @override
  String readerProbeMemory(
    String copy,
    String gc,
    String gcMs,
    String blocking,
    String blockingMs,
  ) {
    return 'Copy max $copy ms · Android GC $gc ($gcMs ms) · blocking $blocking ($blockingMs ms)';
  }

  @override
  String readerProbeWaits(String drive, String fallbacks) {
    return 'Drive waits $drive · Dart fallbacks $fallbacks';
  }

  @override
  String readerProbeJumps(String corrections, String jumps, String jumped) {
    return 'Corrections $corrections · jumps $jumps ($jumped px)';
  }

  @override
  String get serverCheckDaily => 'Daily check for new chapters';

  @override
  String serverCheckDailyAt(String clock) {
    return 'Every day at $clock, server time';
  }

  @override
  String get serverCheckDailyOff =>
      'Off: new chapters are only downloaded by hand';

  @override
  String get serverCheckLibrary => 'The whole library on Drive';

  @override
  String get serverCheckLibraryOn =>
      'Also series downloaded by the phone or by others, not just by the server';

  @override
  String get serverCheckLibraryOff =>
      'Only ongoing series downloaded by the server';

  @override
  String serverCheckLast(String when, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series with new chapters',
      one: '1 series with new chapters',
      zero: 'no new chapters',
    );
    return 'Last check $when: $_temp0';
  }

  @override
  String get serverCheckTimeHelp => 'Check time';
}
