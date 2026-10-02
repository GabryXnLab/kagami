// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get settingsLanguage => 'भाषा';

  @override
  String get settingsLanguageSystem => 'सिस्टम की तरह';

  @override
  String get seriesShelfNone => 'कोई स्थिति नहीं';

  @override
  String get seriesShelfPlanned => 'पढ़नी है';

  @override
  String get seriesShelfReading => 'पढ़ रहे हैं';

  @override
  String get seriesShelfPaused => 'रुकी हुई';

  @override
  String get seriesShelfCompleted => 'पूरी पढ़ी';

  @override
  String get seriesShelfDropped => 'छोड़ दी';

  @override
  String get seriesReleaseOngoing => 'जारी है';

  @override
  String get seriesReleaseCompleted => 'पूर्ण';

  @override
  String get seriesReleaseHiatus => 'अंतराल पर';

  @override
  String get seriesReleaseCancelled => 'बंद';

  @override
  String get seriesReleaseUnknown => 'स्थिति अज्ञात';

  @override
  String get seriesNotFound => 'सीरीज़ नहीं मिली।';

  @override
  String get seriesOfflineTitle => 'Drive पर अध्याय';

  @override
  String get seriesOfflineMessage =>
      'इंटरनेट के बिना इस सीरीज़ के अध्यायों की सूची नहीं दिखती। नेटवर्क आते ही यह अपने आप दिख जाएगी।';

  @override
  String get seriesNoIndexTitle => 'कोई इंडेक्स नहीं';

  @override
  String get seriesNoIndexMessage =>
      'इस सीरीज़ में index.json नहीं है: इसे लिखने वाले आर्काइवर से इंडेक्स फिर से बनवाने होंगे।';

  @override
  String get seriesNoChaptersTitle => 'कोई अध्याय नहीं';

  @override
  String get seriesNoChaptersMessage =>
      'चुनी गई खोज और फ़िल्टर से कोई अध्याय मेल नहीं खाता।';

  @override
  String seriesDownloadAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अध्याय डाउनलोड करें?',
      one: 'एक अध्याय डाउनलोड करें?',
    );
    return '$_temp0';
  }

  @override
  String get seriesDownloadAllMessage =>
      'जो सभी अध्याय अभी Drive से पढ़े जाते हैं, वे फ़ोन में आ जाएँगे और इंटरनेट के बिना भी पढ़े जा सकेंगे।';

  @override
  String get seriesDownload => 'डाउनलोड';

  @override
  String seriesCleanupRemote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पढ़े हुए अध्याय अब भी Drive पर हैं',
      one: 'एक पढ़ा हुआ अध्याय अब भी Drive पर है',
    );
    return '$_temp0';
  }

  @override
  String seriesCleanupLocal(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पढ़े हुए अध्याय $size लेते हैं',
      one: 'एक पढ़ा हुआ अध्याय $size लेता है',
    );
    return '$_temp0';
  }

  @override
  String seriesDownloadFailed(String error) {
    return 'डाउनलोड नहीं हो सका: $error। दोबारा कोशिश करें';
  }

  @override
  String get seriesDownloadWaiting =>
      'नेटवर्क का इंतज़ार: अपने आप फिर शुरू होगा। रद्द करें';

  @override
  String get seriesDownloadQueued => 'कतार में है। रद्द करें';

  @override
  String get seriesDownloadCancel => 'डाउनलोड रद्द करें';

  @override
  String get seriesPlaceLocal => 'फ़ोन पर';

  @override
  String get seriesPlaceDrive => 'Drive पर';

  @override
  String get seriesPlaceMixed => 'फ़ोन और Drive';

  @override
  String get seriesMuteTooltipOn => 'नए अध्यायों की सूचनाएँ म्यूट हैं';

  @override
  String get seriesMuteTooltipOff => 'नए अध्यायों की सूचनाएँ चालू हैं';

  @override
  String get seriesMuteUnmuted => 'नए अध्यायों की सूचनाएँ फिर चालू कर दी गईं।';

  @override
  String get seriesMuteMuted => 'नए अध्यायों की सूचनाएँ म्यूट कर दी गईं।';

  @override
  String seriesCaughtUpMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'फ़ोन में जो है, वह सब पढ़ लिया: $count घोषित अध्याय अभी नहीं हैं।',
      one: 'फ़ोन में जो है, वह सब पढ़ लिया: एक घोषित अध्याय अभी नहीं है।',
    );
    return '$_temp0';
  }

  @override
  String get seriesCaughtUpAll => 'पूरी पढ़ ली।';

  @override
  String get seriesResumeToContinue => 'आगे पढ़ें';

  @override
  String get seriesResumeToStart => 'शुरू करें';

  @override
  String get seriesResumeHalfway => 'बीच में छोड़ा';

  @override
  String seriesResumePage(int page, int total) {
    return 'पेज $page / $total';
  }

  @override
  String get seriesContinue => 'आगे पढ़ें';

  @override
  String get seriesStart => 'शुरू करें';

  @override
  String get seriesResume => 'फिर शुरू करें';

  @override
  String get seriesNextChapter => 'अगला अध्याय';

  @override
  String get seriesFigureChapters => 'अध्याय';

  @override
  String get seriesFigureRead => 'पढ़े';

  @override
  String get seriesFigureProgress => 'प्रगति';

  @override
  String get seriesFigureRating => 'रेटिंग';

  @override
  String get seriesMyShelf => 'मेरी शेल्फ़';

  @override
  String get seriesFavoriteOn => 'पसंदीदा';

  @override
  String get seriesFavoriteOff => 'पसंदीदा';

  @override
  String get seriesRatingButton => 'रेटिंग';

  @override
  String seriesRatingOutOfTen(int rating) {
    return '$rating/10';
  }

  @override
  String get seriesCollections => 'कलेक्शन';

  @override
  String get seriesNotes => 'नोट्स';

  @override
  String get seriesRatingSheetTitle => 'आप इसे क्या रेटिंग देंगे?';

  @override
  String get seriesNotesHint => 'कहाँ रुके थे, आपको कैसी लगी…';

  @override
  String get seriesSave => 'सहेजें';

  @override
  String get seriesRatingWord1 => 'बेकार';

  @override
  String get seriesRatingWord2 => 'खराब';

  @override
  String get seriesRatingWord3 => 'कमज़ोर';

  @override
  String get seriesRatingWord4 => 'साधारण';

  @override
  String get seriesRatingWord5 => 'ठीक-ठाक';

  @override
  String get seriesRatingWord6 => 'अच्छी-सी';

  @override
  String get seriesRatingWord7 => 'अच्छी';

  @override
  String get seriesRatingWord8 => 'बहुत अच्छी';

  @override
  String get seriesRatingWord9 => 'शानदार';

  @override
  String get seriesRatingWord10 => 'उत्कृष्ट कृति';

  @override
  String get seriesRatingNone => 'रेटिंग नहीं';

  @override
  String get seriesRatingHint => 'टैप करें या स्वाइप करें';

  @override
  String seriesRatingBefore(int rating) {
    return 'पहले: $rating';
  }

  @override
  String get seriesRatingRemove => 'हटाएँ';

  @override
  String get seriesRatingSave => 'रेटिंग सहेजें';

  @override
  String get seriesSynopsis => 'सारांश';

  @override
  String get seriesGenres => 'शैलियाँ';

  @override
  String get seriesTags => 'टैग';

  @override
  String get seriesCreators => 'रचनाकार';

  @override
  String seriesMoreTags(int count) {
    return '$count और';
  }

  @override
  String get seriesPaceToRead => 'पढ़नी बाकी';

  @override
  String seriesPaceCaption(int chapters, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      chapters,
      locale: localeName,
      other: '$chapters अध्याय',
      one: 'एक अध्याय',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages पेज',
      one: 'एक पेज',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get seriesPaceNext => 'अगला अध्याय';

  @override
  String get seriesPaceNextCaption => 'पिछले अध्यायों की गति के अनुसार';

  @override
  String seriesDurationMinutes(int count) {
    return '$count मिनट';
  }

  @override
  String seriesDurationHours(int count) {
    return '$count घंटे';
  }

  @override
  String seriesDurationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन',
      one: '1 दिन',
    );
    return '$_temp0';
  }

  @override
  String get seriesWhenLate => 'देरी से';

  @override
  String get seriesWhenExpected => 'अपेक्षित';

  @override
  String get seriesWhenToday => 'आज';

  @override
  String get seriesWhenTomorrow => 'कल';

  @override
  String seriesWhenInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन में',
      one: '1 दिन में',
    );
    return '$_temp0';
  }

  @override
  String seriesWhenInWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सप्ताह में',
      one: '1 सप्ताह में',
    );
    return '$_temp0';
  }

  @override
  String get seriesShowLess => 'कम दिखाएँ';

  @override
  String get seriesShowMore => 'पूरा पढ़ें';

  @override
  String get seriesChaptersTitle => 'अध्याय';

  @override
  String seriesChaptersOf(int total) {
    return 'कुल $total';
  }

  @override
  String get seriesSearchChapter => 'अध्याय खोजें…';

  @override
  String get seriesSortNewest => 'सबसे नया पहले';

  @override
  String get seriesSortOldest => 'सबसे पुराना पहले';

  @override
  String get seriesMarkAll => 'सभी चिह्नित करें';

  @override
  String get seriesDownloadFromDrive => 'Drive से डाउनलोड करें';

  @override
  String get seriesFreeSpace => 'जगह खाली करें';

  @override
  String get seriesFilterUnread => 'पढ़ने बाकी';

  @override
  String get seriesFilterDownloaded => 'डाउनलोड किए';

  @override
  String get seriesFilterAll => 'सभी';

  @override
  String seriesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चुने गए',
      one: '1 चुना गया',
    );
    return '$_temp0';
  }

  @override
  String get seriesMarkReadMany => 'पढ़ा हुआ चिह्नित करें';

  @override
  String get seriesMarkUnread => 'अनपढ़ा चिह्नित करें';

  @override
  String get seriesMarkRead => 'पढ़ा हुआ चिह्नित करें';

  @override
  String get seriesMarkReadThrough => 'यहाँ तक पढ़ा हुआ चिह्नित करें';

  @override
  String get seriesSimilar => 'मिलती-जुलती सीरीज़';

  @override
  String get seriesChapterNotDownloaded => 'डाउनलोड नहीं हुआ';

  @override
  String seriesChapterPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पेज',
      one: '1 पेज',
    );
    return '$_temp0';
  }

  @override
  String get seriesDownloadToPhone => 'फ़ोन में डाउनलोड करें';

  @override
  String get readerSeriesUnavailable => 'सीरीज़ उपलब्ध नहीं है।';

  @override
  String get readerNoPagesIndex =>
      'इस सीरीज़ में pages.json नहीं है: इसे लिखने वाले आर्काइवर से इंडेक्स फिर से बनवाने होंगे।';

  @override
  String get readerSeriesOffline =>
      'इंटरनेट के बिना यह सीरीज़ नहीं खुल सकती: इसके पेजों की सूची Drive पर है। नेटवर्क आते ही यह खुल जाएगी।';

  @override
  String get readerChapterNotOnPhone =>
      'यह अध्याय अभी फ़ोन में नहीं है। सिंक अधूरा हो सकता है: बाद में दोबारा कोशिश करें।';

  @override
  String get readerChapterNoPages => 'इस अध्याय में पढ़ने लायक पेज नहीं हैं।';

  @override
  String get readerPagesNotOnPhone =>
      'इस अध्याय के पेज अभी फ़ोन में नहीं हैं। इंडेक्स उनकी सूची देता है, पर फ़ाइलें नहीं आईं: उन्हें सिंक किया गया फ़ोल्डर लाएगा।';

  @override
  String get readerMarkEarlierTitle => 'पिछले अध्याय पढ़े हुए चिह्नित करें?';

  @override
  String readerMarkEarlierBody(int count, String chapter) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'आपने $chapter पूरा पढ़ लिया। पिछले $count अध्याय अब भी अनपढ़े दिख रहे हैं: अगर आप उन्हें कहीं और पढ़ चुके हैं, तो उन्हें एक साथ पढ़ा हुआ चिह्नित कर दें।',
      one:
          'आपने $chapter पूरा पढ़ लिया। पिछला अध्याय अब भी अनपढ़ा दिख रहा है: अगर आप उसे कहीं और पढ़ चुके हैं, तो उसे पढ़ा हुआ चिह्नित कर दें।',
    );
    return '$_temp0';
  }

  @override
  String readerMarkEarlierConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'सभी $count पढ़े हुए चिह्नित करें',
      one: 'पिछला पढ़ा हुआ चिह्नित करें',
    );
    return '$_temp0';
  }

  @override
  String get readerMarkEarlierDecline => 'अनपढ़े रहने दें';

  @override
  String readerBookmarkAdded(int page) {
    return 'पेज $page सहेजा गया';
  }

  @override
  String get readerChapters => 'अध्याय';

  @override
  String get readerBookmarks => 'सहेजे हुए पेज';

  @override
  String get readerNoBookmarks => 'कोई पेज सहेजा नहीं गया';

  @override
  String get readerNoBookmarksHint =>
      'बुकमार्क किसी एक पेज की जगह याद रखता है; अध्याय में आपकी जगह तो पढ़ाई दोबारा शुरू करने की सुविधा पहले से याद रखती है।';

  @override
  String readerBookmarkPage(int page) {
    return 'पेज $page';
  }

  @override
  String get readerBookmarkRemove => 'हटाएँ';

  @override
  String get readerToTop => 'ऊपर जाएँ';

  @override
  String get readerPageNotFromDrive => 'पेज Drive से नहीं आया';

  @override
  String get readerPageUnreadable => 'पेज पढ़ा नहीं जा सकता';

  @override
  String get readerPageNotSynced => 'पेज सिंक नहीं हुआ';

  @override
  String get readerPageNotDownloaded => 'पेज अभी डाउनलोड नहीं हुआ';

  @override
  String get readerPageOfflineHint =>
      'इंटरनेट नहीं है। नेटवर्क आते ही यह अपने आप आ जाएगा।';

  @override
  String get readerRetryNow => 'अभी दोबारा कोशिश करें';

  @override
  String get readerLastChapterOnPhone => 'फ़ोन में यही आख़िरी अध्याय है।';

  @override
  String get readerNextChapter => 'अगला अध्याय';

  @override
  String get readerContinue => 'आगे पढ़ें';

  @override
  String get readerBookmarkThisPage => 'यह पेज सहेजें';

  @override
  String get readerHowToRead => 'पढ़ने का तरीका';

  @override
  String get readerPreviousChapter => 'पिछला अध्याय';

  @override
  String get readerNextChapterTooltip => 'अगला अध्याय';

  @override
  String get readerSearchChapter => 'अध्याय खोजें…';

  @override
  String get readerNewestFirst => 'सबसे नया पहले';

  @override
  String get readerOldestFirst => 'सबसे पुराना पहले';

  @override
  String readerReadingNow(String current, int total) {
    return 'अभी पढ़ रहे हैं: $current / $total अध्याय';
  }

  @override
  String get readerMode => 'पढ़ने का मोड';

  @override
  String get readerModeStrip => 'पट्टी';

  @override
  String get readerModePage => 'पेज';

  @override
  String get readerDirection => 'पढ़ने की दिशा';

  @override
  String get readerDirectionLtr => 'बाएँ → दाएँ';

  @override
  String get readerDirectionRtl => 'दाएँ → बाएँ';

  @override
  String get readerFit => 'फ़िट';

  @override
  String get readerBackground => 'पृष्ठभूमि';

  @override
  String get readerBrightness => 'चमक';

  @override
  String get readerAutoScroll => 'ऑटो स्क्रोल';

  @override
  String get readerAutoScrollOff => 'बंद';

  @override
  String readerAutoScrollRate(int rate) {
    return '$rate पेज/मिनट';
  }

  @override
  String get readerShowPageNumber => 'पेज नंबर';

  @override
  String get readerShowProgress => 'प्रगति पट्टी';

  @override
  String get readerShowScrollTop => 'ऊपर जाने का बटन';

  @override
  String get readerKeepAwake => 'स्क्रीन चालू रखें';

  @override
  String get readerDoublePage => 'दो पेज साथ-साथ';

  @override
  String get readerLockRotation => 'रोटेशन लॉक करें';

  @override
  String get archiveTitle => 'मांगा डाउनलोड करें';

  @override
  String get archiveIntro =>
      'समर्थित साइटों पर शीर्षक खोजें, या किसी सीरीज़ का लिंक पेस्ट करें: Kagami उसे साइट से मेटाडेटा, कवर और अध्यायों की पूरी सूची के साथ लाइब्रेरी में डाउनलोड कर देता है।';

  @override
  String get archiveSearchHint => 'शीर्षक से मांगा खोजें';

  @override
  String get archiveClear => 'मिटाएँ';

  @override
  String get archivePaste => 'पेस्ट करें';

  @override
  String get archiveReading => 'सीरीज़ पढ़ी जा रही है…';

  @override
  String get archiveVerify => 'सीरीज़ जाँचें';

  @override
  String archiveSeriesSummary(String site, int count, String status) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अध्याय',
      one: '1 अध्याय',
    );
    return '$site · $_temp0 · $status';
  }

  @override
  String archiveKnown(int archived, int total) {
    return 'पहले से लाइब्रेरी में: $total में से $archived अध्याय। जो मौजूद हैं, उन्हें छोड़ दिया जाता है।';
  }

  @override
  String get archiveWhatSection => 'क्या डाउनलोड करना है';

  @override
  String get archiveModeAll => 'पूरी';

  @override
  String get archiveModeFrom => 'अध्याय से';

  @override
  String get archiveModePick => 'चुने हुए';

  @override
  String get archiveModeAllHint =>
      'सभी अध्याय। बाद में दोबारा करने पर सिर्फ़ नए या खराब अध्याय आते हैं।';

  @override
  String get archiveModeFromHint =>
      'चुने हुए अध्याय से आगे के सभी: पिछले अध्याय सीरीज़ की सूची में डाउनलोड न हुए के रूप में रहते हैं।';

  @override
  String get archiveModePickHint =>
      'सिर्फ़ वे अध्याय जिन्हें आपने छुआ। बाकी सूची में रहते हैं, डाउनलोड नहीं होते।';

  @override
  String get archiveChapterNumberHint => 'अध्याय का नंबर, जैसा साइट पर है';

  @override
  String archivePickedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चुने गए',
      one: '1 चुना गया',
    );
    return '$_temp0';
  }

  @override
  String get archiveSelectAll => 'सभी';

  @override
  String get archiveSelectNone => 'कोई नहीं';

  @override
  String get archiveWhereSection => 'कहाँ';

  @override
  String get archiveWhereServer => 'सर्वर';

  @override
  String get archiveWhereDrive => 'Drive';

  @override
  String get archiveWhereDriveAndPhone => 'Drive और फ़ोन';

  @override
  String get archiveWherePhone => 'फ़ोन';

  @override
  String get archiveWhereDriveHint =>
      'लाइब्रेरी के Drive फ़ोल्डर में। पेज फ़ोन से होकर गुज़रते हैं और Drive पर पहुँचते ही फ़ोन से हट जाते हैं: उन्हें स्ट्रीमिंग से पढ़ें, या बाद में डाउनलोड करें।';

  @override
  String get archiveWhereDriveAndPhoneHint =>
      'लाइब्रेरी के Drive फ़ोल्डर में, और अध्याय फ़ोन पर भी रहते हैं ताकि इंटरनेट के बिना पढ़े जा सकें।';

  @override
  String get archiveWherePhoneHint =>
      'फ़ोन में, मांगा फ़ोल्डर या ऐप की जगह में। Drive जोड़ने पर सीधे वहीं डाउनलोड किया जा सकता है।';

  @override
  String archiveServerHint(String name, String folder, String other) {
    String _temp0 = intl.Intl.selectLogic(other, {
      'other': ' ध्यान दें: यह वह फ़ोल्डर नहीं है जिसे ऐप पढ़ता है।',
      'same': '',
    });
    return 'इसे «$name» डाउनलोड करता है और Drive पर «$folder» में अपलोड करता है, फ़ोन बंद होने पर भी। जारी सीरीज़ को सर्वर ट्रैक करता है।$_temp0';
  }

  @override
  String get archiveDelaySection => 'अनुरोधों के बीच विराम';

  @override
  String get archiveDelayNone => 'कोई नहीं';

  @override
  String archiveDelaySeconds(String seconds) {
    return '$seconds सेकंड';
  }

  @override
  String get archiveDelayHint =>
      'साइटों को लगातार डाउनलोड करने वाले पसंद नहीं आते: छोटा विराम ब्लॉक होने से बचाता है।';

  @override
  String get archiveDownloadAll => 'पूरी सीरीज़ डाउनलोड करें';

  @override
  String get archiveDownloadFrom => 'चुने अध्याय से डाउनलोड करें';

  @override
  String archiveDownloadPicked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अध्याय डाउनलोड करें',
      one: '1 अध्याय डाउनलोड करें',
    );
    return '$_temp0';
  }

  @override
  String archiveNoResults(String site) {
    return '$site पर कोई नतीजा नहीं।';
  }

  @override
  String archiveChaptersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अध्याय',
      one: '1 अध्याय',
    );
    return '$_temp0';
  }

  @override
  String archiveVerifySite(String site) {
    return '$site की जाँच करें';
  }

  @override
  String get archiveVerifySiteHint =>
      'साइट जानना चाहती है कि आप इंसान हैं: टैप करने पर जाँच खुलती है, फिर वहीं खोज भी की जाती है';

  @override
  String get archiveStatusOngoing => 'जारी है';

  @override
  String get archiveStatusCompleted => 'पूर्ण';

  @override
  String get archiveStatusHiatus => 'अंतराल पर';

  @override
  String get archiveStatusCancelled => 'बंद';

  @override
  String get archiveStatusUnknown => 'स्थिति अज्ञात';

  @override
  String get archiveErrChallenge =>
      'साइट एक जाँच माँग रही है जो यहाँ से नहीं हो सकती।';

  @override
  String get archiveErrOffline => 'इंटरनेट नहीं है: साइट जवाब नहीं दे रही।';

  @override
  String get archiveErrVerifyIncomplete => 'साइट की जाँच पूरी नहीं हुई।';

  @override
  String archiveQueuedSnack(String title) {
    return '«$title» कतार में है। स्क्रीन बंद होने पर भी जारी रहेगा।';
  }

  @override
  String archiveQueuedServerSnack(String title, String server) {
    return '«$title» «$server» पर कतार में है। फ़ोन बंद भी हो सकता है।';
  }

  @override
  String get archiveServerFallbackName => 'सर्वर';

  @override
  String get archiveDownloads => 'डाउनलोड';

  @override
  String get archiveClearHistory => 'साफ़ करें';

  @override
  String get archiveQueueStopped => 'कतार रुकी है';

  @override
  String get archiveQueueResumeHint =>
      'अपने आप फिर शुरू होगी; टैप करने पर अभी शुरू हो जाएगी';

  @override
  String archiveJobAutomatic(String destination) {
    return 'नए अध्याय · $destination';
  }

  @override
  String archiveJobQueued(String destination) {
    return 'कतार में · $destination';
  }

  @override
  String get archiveRemoveFromQueue => 'कतार से हटाएँ';

  @override
  String archiveHistoryLine(String when, String message) {
    return '$when · $message';
  }

  @override
  String get archiveSites => 'समर्थित साइटें';

  @override
  String get archiveMoreSites =>
      'और साइटें आने वाली हैं: नए प्रोवाइडर का समर्थन आगामी अपडेट के साथ आएगा।';

  @override
  String archiveLinkCopied(String url) {
    return '$url क्लिपबोर्ड पर कॉपी हो गया।';
  }

  @override
  String get archiveTracked => 'जारी सीरीज़';

  @override
  String get archiveTrackedIntro =>
      'यहाँ से डाउनलोड की गई जारी सीरीज़ की दोबारा जाँच होती है: उसी जगह सिर्फ़ नए अध्याय आते हैं। सर्वर वाली सीरीज़ को सर्वर ट्रैक करता है।';

  @override
  String get archiveCheckDaily => 'रोज़ जाँच';

  @override
  String get archiveCheckManual => 'सिर्फ़ हाथ से';

  @override
  String archiveCheckAt(String time) {
    return '$time बजे, ऐप बंद होने पर भी';
  }

  @override
  String get archiveCheckTime => 'समय';

  @override
  String get archiveCheckTimeHelp => 'जाँच का समय';

  @override
  String get archiveWifiOnly => 'सिर्फ़ Wi-Fi पर';

  @override
  String get archiveWifiOnlyOn =>
      'ऐसे नेटवर्क का इंतज़ार करता है जिसका डेटा के हिसाब से पैसा न लगे';

  @override
  String get archiveWifiOnlyOff => 'मोबाइल डेटा पर भी';

  @override
  String get archiveCheckNow => 'अभी जाँचें';

  @override
  String get archiveNoTracked => 'अभी कोई सीरीज़ ट्रैक नहीं हो रही';

  @override
  String archiveTrackedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सीरीज़ ट्रैक हो रही हैं',
      one: '1 सीरीज़ ट्रैक हो रही है',
    );
    return '$_temp0';
  }

  @override
  String archiveTrackedLine(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अध्याय ज्ञात',
      one: '1 अध्याय ज्ञात',
    );
    return '$_temp0 · $destination';
  }

  @override
  String archiveTrackedLineChecked(int count, String destination, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अध्याय ज्ञात',
      one: '1 अध्याय ज्ञात',
    );
    return '$_temp0 · $destination · जाँच: $when';
  }

  @override
  String get archiveStopFollowing => 'ट्रैक करना बंद करें';

  @override
  String archiveCheckQueued(String names) {
    return '$names के नए अध्याय';
  }

  @override
  String archiveCheckRemoved(String names) {
    return '$names अब पूर्ण';
  }

  @override
  String archiveCheckFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count तक नहीं पहुँचा जा सका',
      one: '1 तक नहीं पहुँचा जा सका',
    );
    return '$_temp0';
  }

  @override
  String get archiveCheckSeparator => '; ';

  @override
  String archiveCheckReport(String parts) {
    return '$parts।';
  }

  @override
  String get archiveNoNewChapters => 'कोई नया अध्याय नहीं।';

  @override
  String get archiveNoConnection => 'इंटरनेट नहीं है।';

  @override
  String get archiveForgetTitle => 'ट्रैक करना बंद करें?';

  @override
  String archiveForgetBody(String title) {
    return '«$title» के नए अध्याय अब अपने आप नहीं आएँगे। जो डाउनलोड हो चुके हैं, वे रहेंगे।';
  }

  @override
  String get archiveCancel => 'रद्द करें';

  @override
  String get archiveForgetConfirm => 'बंद करें';

  @override
  String archiveStartIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अध्याय।',
      one: '1 अध्याय।',
    );
    return '$_temp0 सब डाउनलोड करें या चुनें कि किस अध्याय से शुरू करना है: पिछले अध्याय रीडर की सूची में बिना पेज के रहते हैं।';
  }

  @override
  String get archiveStartNoMatch => 'इस नंबर का कोई अध्याय नहीं है।';

  @override
  String archiveStartFrom(String title, int remaining) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: '$remaining अध्याय',
      one: '1 अध्याय',
    );
    return '«$title» से आगे: $_temp0।';
  }

  @override
  String get archiveStartNone =>
      'कोई अध्याय नहीं चुना: सब डाउनलोड किया जा सकता है।';

  @override
  String get archiveStartAll => 'सब डाउनलोड करें';

  @override
  String get archiveStartHere => 'यहाँ से';

  @override
  String get browserTitle => 'साइट की जाँच';

  @override
  String get browserPhoneOnly => 'जाँच सिर्फ़ फ़ोन से हो सकती है।';

  @override
  String get browserInstructionsChapters =>
      'साइट जानना चाहती है कि आप इंसान हैं। जाँच पूरी करें: जब अध्यायों की सूची दिखेगी, Kagami खुद पहचानकर वापस लौट जाएगा।';

  @override
  String get browserInstructionsSearch =>
      'साइट जानना चाहती है कि आप इंसान हैं। जाँच पूरी करें: जब साइट की खोज दिखेगी, Kagami खुद पहचानकर वापस लौट जाएगा।';

  @override
  String get browserSearchPhoneOnly =>
      'इस साइट पर खोज सिर्फ़ फ़ोन से हो सकती है।';

  @override
  String get browserSearchSuperseded => 'नई खोज ने इसकी जगह ले ली।';

  @override
  String get browserResponseTooLarge => 'जवाब बहुत बड़ा है।';

  @override
  String get serverTitle => 'सर्वर';

  @override
  String get serverClear => 'साफ़ करें';

  @override
  String get serverUnavailableNoSecret =>
      'इस ऐप बिल्ड से सर्वर नहीं जोड़ा जा सकता: इसे बनाने वाले ने वेब क्लाइंट का सीक्रेट (GOOGLE_SERVER_CLIENT_SECRET) नहीं दिया।';

  @override
  String get serverUnavailableAndroidOnly =>
      'सर्वर सिर्फ़ Android से जोड़ा जा सकता है।';

  @override
  String get serverSignInRequired =>
      'सर्वर इस्तेमाल करने के लिए Google से साइन इन करें।';

  @override
  String get serverNoConnection => 'इंटरनेट नहीं है।';

  @override
  String get serverMissingGoogleServices =>
      'google-services.json नहीं मिला: इस बिल्ड में Google क्लाइंट नहीं है।';

  @override
  String get serverDriveAccessDenied => 'Google ने Drive की अनुमति नहीं दी।';

  @override
  String get serverGoogleNotResponding =>
      'Google जवाब नहीं दे रहा: थोड़ी देर में दोबारा कोशिश करें।';

  @override
  String serverWhenToday(String clock) {
    return 'आज $clock बजे';
  }

  @override
  String serverWhenDate(String date, String clock) {
    return '$date, $clock बजे';
  }

  @override
  String serverProgressStats(int pages, String size, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: ' · $skipped पहले से ठीक',
      zero: '',
    );
    return '$pages नए पेज · $size$_temp0';
  }

  @override
  String get serverRemoveFromQueue => 'कतार से हटाएँ';

  @override
  String get serverNoFirebase =>
      'सर्वर आपके Google खाते से पहचानता है कि इसे कौन इस्तेमाल कर रहा है, जो ऐप के इस बिल्ड में नहीं है।';

  @override
  String get serverSignedOutIntro =>
      'हमेशा चालू रहने वाला कंप्यूटर फ़ोन की जगह आपके Drive पर डाउनलोड और अपलोड कर सकता है, और फ़ोन तब तक बंद भी रह सकता है। सर्वर आपको आपके Google खाते से पहचानता है।';

  @override
  String get serverSignIn => 'Google से साइन इन करें';

  @override
  String get serverSignInSubtitle =>
      'अपना सर्वर बनाने या किसी और का सर्वर इस्तेमाल करने के लिए';

  @override
  String serverInviteTitle(String sender, String serverName) {
    return '$sender ने आपको «$serverName» का एक्सेस दिया है';
  }

  @override
  String get serverInviteSubtitle =>
      'आपके Drive पर डाउनलोड करता है, फ़ोन बंद होने पर भी। जोड़ने के लिए टैप करें';

  @override
  String get serverIgnore => 'अनदेखा करें';

  @override
  String get serverLinkIntro =>
      'हमेशा चालू रहने वाला कंप्यूटर, आपका अपना या जिसने आपको एक्सेस दिया उसका, फ़ोन की जगह आपके Drive पर डाउनलोड और अपलोड कर सकता है, और फ़ोन तब तक बंद भी रह सकता है।';

  @override
  String get serverCreate => 'अपना सर्वर बनाएँ';

  @override
  String get serverCreateSubtitle =>
      'Docker वाले कंप्यूटर पर पेस्ट करने के लिए एक कमांड: कुछ सेट करना नहीं पड़ता';

  @override
  String get serverLinkTitle => 'सर्वर जोड़ें';

  @override
  String get serverLinkSubtitle =>
      'आपका अपना, जो पहले से चालू है, या जिसने आपको जोड़ा उसका';

  @override
  String get serverStateConnecting => 'जुड़ रहा है…';

  @override
  String get serverStateNoGrant => 'अभी आपके Drive की अनुमति नहीं है';

  @override
  String get serverStateNoFolder =>
      'अभी यह नहीं पता कि आपके Drive के किस फ़ोल्डर में लिखना है';

  @override
  String serverStateReady(String folder) {
    return 'तैयार · आपके Drive पर «$folder» में लिखता है';
  }

  @override
  String serverTileSubtitle(String address, String state) {
    return '$address · $state';
  }

  @override
  String serverTileSubtitleOwner(String address, String owner, String state) {
    return '$address · $owner का · $state';
  }

  @override
  String get serverPlainTitle => 'कनेक्शन एन्क्रिप्टेड नहीं है';

  @override
  String get serverPlainSubtitle =>
      'आपके खाते का टोकन रास्ते में पढ़ा जा सकता है: HTTPS चाहिए (Tailscale Funnel, एक रिवर्स प्रॉक्सी)';

  @override
  String get serverGrantTitle => 'सर्वर को अपना Drive दें';

  @override
  String get serverGrantSubtitle =>
      'यह उसी फ़ोल्डर में डाउनलोड करेगा जिसे ऐप पढ़ता है, फ़ोन बंद होने पर भी';

  @override
  String get serverUseAppFolder => 'ऐप का फ़ोल्डर इस्तेमाल करें';

  @override
  String serverUseAppFolderSubtitle(String serverFolder, String appFolder) {
    return 'सर्वर «$serverFolder» में लिखता है, ऐप «$appFolder» पढ़ता है';
  }

  @override
  String get serverUsersTitle => 'कौन इस्तेमाल कर सकता है';

  @override
  String get serverUsersOnlyYou =>
      'सिर्फ़ आप। जिसे चाहें उसका Google खाता जोड़ें';

  @override
  String serverUsersCount(int count) {
    return '$count खाते, आपको मिलाकर';
  }

  @override
  String get serverQueueWaiting => 'कतार इंतज़ार में है';

  @override
  String get serverQueueRestarts => 'सर्वर अपने आप फिर शुरू होगा';

  @override
  String get serverJobAutomatic => 'नए अध्याय · सर्वर पर';

  @override
  String get serverJobQueued => 'कतार में · सर्वर पर';

  @override
  String get serverOngoingTitle => 'सर्वर पर जारी सीरीज़';

  @override
  String serverOngoingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ट्रैक हो रही हैं',
      zero: 'अभी कोई नहीं',
    );
    return '$_temp0';
  }

  @override
  String get serverOngoingCheckOff => 'जाँच बंद';

  @override
  String serverOngoingCheckAt(String clock) {
    return 'जाँच $clock बजे';
  }

  @override
  String serverOngoingSubtitle(String count, String check) {
    return '$count · $check। अभी जाँचने के लिए टैप करें';
  }

  @override
  String serverSeriesKnown(int count) {
    return '$count अध्याय ज्ञात';
  }

  @override
  String serverSeriesKnownChecked(int count, String when) {
    return '$count अध्याय ज्ञात · जाँच: $when';
  }

  @override
  String get serverStopFollowing => 'ट्रैक करना बंद करें';

  @override
  String get serverInviteRemoveFailed =>
      'मैं निमंत्रण हटा नहीं सका: दोबारा कोशिश करें।';

  @override
  String get serverCheckingNow =>
      'सर्वर जाँच रहा है: नए अध्याय उसकी कतार में दिखेंगे।';

  @override
  String get serverPaste => 'पेस्ट करें';

  @override
  String get serverAddressExposed =>
      'ध्यान दें: सार्वजनिक पते पर बिना एन्क्रिप्शन के आपके खाते का टोकन रास्ते में पढ़ा जा सकता है। HTTPS (Tailscale Funnel, एक रिवर्स प्रॉक्सी) या Tailscale इस्तेमाल करें।';

  @override
  String get serverAddressSavedNote =>
      'पता बैकअप और खाते के साथ चलता है, Drive फ़ोल्डर की तरह।';

  @override
  String get serverAddressMissing =>
      'सर्वर का पता लिखें, जैसे http://192.168.1.20:8080।';

  @override
  String serverLinked(String name, String folder) {
    return '«$name» से जुड़ गया: आपके Drive पर «$folder» में डाउनलोड करता है।';
  }

  @override
  String serverLinkFromInvite(String sender, String serverName) {
    return '$sender ने आपको «$serverName» में जोड़ा है। इसे जोड़ने पर सर्वर आपके चुने मांगा आपके Drive पर आपकी लाइब्रेरी के फ़ोल्डर में डाउनलोड करेगा: Google आपसे उसे वहाँ लिखने की अनुमति देने को कहेगा। सर्वर चलाने वाला उस अनुमति का इस्तेमाल कर सकेगा।';
  }

  @override
  String serverLinkLinked(String account) {
    return 'सर्वर आपको $account के रूप में पहचानता है। अगर यह आपका नहीं है, तो इसे हटाने पर वह आपके Drive की अनुमति और आपकी कतार भी भूल जाता है।';
  }

  @override
  String get serverSignedInAccount => 'जिस खाते से आपने साइन इन किया है';

  @override
  String get serverLinkNew =>
      'सर्वर का पता लिखें: आपका अपना, या जिसने आपको जोड़ा उसने जो दिया। सर्वर आपको Google खाते से पहचानता है, और पहली बार आप उसे Drive पर अपनी लाइब्रेरी के फ़ोल्डर में लिखने की अनुमति देते हैं।';

  @override
  String get serverVerifying => 'जाँच रहा है…';

  @override
  String get serverVerifyAgain => 'फिर से जाँचें';

  @override
  String get serverVerifyAndLink => 'जाँचें और जोड़ें';

  @override
  String get serverUnlink => 'हटाएँ';

  @override
  String get serverDefaultNameOwn => 'मेरा Kagami Server';

  @override
  String serverDefaultNameOf(String name) {
    return '$name का सर्वर';
  }

  @override
  String get serverCommandCopied => 'कमांड कॉपी हो गई।';

  @override
  String get serverComputerAddressMissing =>
      'कंप्यूटर का पता लिखें, जैसे http://192.168.1.20:8080।';

  @override
  String serverNotOwner(String owner) {
    return 'वह सर्वर $owner का है: यह जुड़ा हुआ है, पर आपने इसे नहीं बनाया।';
  }

  @override
  String serverReady(String name) {
    return '«$name» तैयार है। «कौन इस्तेमाल कर सकता है» से जिसे चाहें जोड़ें।';
  }

  @override
  String get serverLibraryFolderFallback => 'लाइब्रेरी का फ़ोल्डर';

  @override
  String serverSetupIntro(String folder) {
    return 'एक ऐसा कंप्यूटर चाहिए जो चालू रहे — मिनी PC, NAS, Raspberry Pi, नेटवर्क में कोई सर्वर — जिसमें Docker हो। सर्वर मांगा डाउनलोड करके आपके Drive में «$folder» में अपलोड करता है, फ़ोन बंद होने पर भी।';
  }

  @override
  String serverPrepareIntro(String signIn, String folder) {
    String _temp0 = intl.Intl.selectLogic(signIn, {
      'yes': 'पहले Google से साइन इन करें, फिर ',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(folder, {
      'yes': 'Drive पर मांगा फ़ोल्डर चुनें, फिर ',
      'other': '',
    });
    return 'मैं एक कमांड तैयार करता हूँ जिसमें सब कुछ है: $_temp0${_temp1}Google आपसे सर्वर को आपके Drive पर लिखने की अनुमति देने को कहता है।';
  }

  @override
  String get serverPreparing => 'तैयार कर रहा है…';

  @override
  String get serverGenerate => 'कमांड बनाएँ';

  @override
  String get serverStep1 =>
      'कंप्यूटर पर Docker इंस्टॉल करें (docker.com), अगर पहले से नहीं है।';

  @override
  String get serverStep2 =>
      'ये कमांड उसके टर्मिनल में पेस्ट करें: पहली सर्वर चालू करती है, दूसरी उसे अपने आप अपडेट रखती है। इनमें आपके Drive की अनुमति है: इन्हें किसी को न भेजें।';

  @override
  String get serverCopyCommand => 'कमांड कॉपी करें';

  @override
  String get serverStep3 =>
      'यहाँ कंप्यूटर का पता लिखें: घर में लोकल नेटवर्क वाला; बाहर से, Tailscale में उसका नाम या वह HTTPS पता जिससे आप उसे उपलब्ध कराते हैं।';

  @override
  String get serverPortNote => 'सर्वर पोर्ट 8080 पर जवाब देता है।';

  @override
  String get serverUsersIntro =>
      'जिसे चाहें उसका Google खाता जोड़ें। उसके Kagami ऐप में निमंत्रण दिखेगा: सर्वर जोड़ने पर उसके डाउनलोड उसके Drive पर, उसकी अपनी कतार के साथ जाएँगे।';

  @override
  String get serverUserEmailInvalid =>
      'Google खाते का पता लिखें, जैसे naam@gmail.com।';

  @override
  String serverUserAdded(String email) {
    return '$email सर्वर इस्तेमाल कर सकता है: उसका ऐप उसे बता देगा।';
  }

  @override
  String serverRemoveTitle(String email) {
    return '$email को हटाएँ?';
  }

  @override
  String get serverRemoveBody =>
      'वह अब सर्वर इस्तेमाल नहीं कर सकेगा। उसकी कतार और उसके Drive की अनुमति मिट जाती है; जो पहले से उसके Drive पर है, वह रहता है।';

  @override
  String get serverCancel => 'रद्द करें';

  @override
  String get serverRemove => 'हटाएँ';

  @override
  String get serverAdd => 'जोड़ें';

  @override
  String get serverOwnerYou => 'आप, मालिक';

  @override
  String get serverConnected => 'सर्वर जोड़ लिया है';

  @override
  String get serverInvitedPending => 'आमंत्रित, अभी सर्वर नहीं जोड़ा';

  @override
  String get setupIntro =>
      'सिंक द्वारा फ़ोन में रखा गया मांगा फ़ोल्डर पढ़ता है, या वही लाइब्रेरी सीधे Google Drive से, उसे पूरा यहाँ लाए बिना।';

  @override
  String get setupAccessTitle => 'फ़ाइलों का एक्सेस';

  @override
  String get setupAccessBody =>
      'फ़ोल्डर ऐप की निजी जगह के बाहर है और उसमें हज़ारों इमेज हैं: Kagami को उन्हें सीधे पढ़ना पड़ता है। यह सिर्फ़ लाइब्रेरी के reading/ सबफ़ोल्डर में डेटा की कॉपियाँ लिखता है, और आप कहें तो Drive से डाउनलोड किए अध्याय।';

  @override
  String get setupGrantAccess => 'एक्सेस दें';

  @override
  String get setupFolderTitle => 'फ़ोल्डर';

  @override
  String get setupFolderBody =>
      'वह फ़ोल्डर चुनें जिसे FolderSync सिंक करता है: जिसमें library.json और हर सीरीज़ का एक सबफ़ोल्डर होता है।';

  @override
  String get setupChooseFolder => 'फ़ोल्डर चुनें';

  @override
  String get setupOr => 'या';

  @override
  String get setupDriveTitle => 'Google Drive';

  @override
  String get setupDriveBody =>
      'Google से साइन इन करें और Drive पर लाइब्रेरी का फ़ोल्डर चुनें: पेज पढ़ते समय आते रहते हैं, और जो अध्याय हमेशा पास रखने हैं, उन्हें एक टैप से डाउनलोड करें। फ़ोन की फ़ाइलों का एक्सेस ज़रूरी नहीं है।';

  @override
  String get setupReadFromDrive => 'Google Drive से पढ़ें';

  @override
  String get setupLibraryProblemTitle => 'लाइब्रेरी पढ़ी नहीं जा सकती';

  @override
  String get setupChangeFolder => 'फ़ोल्डर बदलें';

  @override
  String get driveFolderSheetTitle => 'Drive पर फ़ोल्डर';

  @override
  String get driveDestinationTitle => 'मांगा कहाँ सहेजूँ?';

  @override
  String get driveDestinationBody =>
      'फ़ोन में मांगा के लिए कोई फ़ोल्डर नहीं है। फ़ोल्डर में डाउनलोड किए अध्याय ऐप अनइंस्टॉल होने पर भी रहते हैं, और Kagami उन्हें पहले से मौजूद अध्यायों के साथ पढ़ता है। ऐप की जगह में किसी अनुमति की ज़रूरत नहीं, पर वे ऐप के साथ चले जाते हैं।';

  @override
  String get driveChooseFolder => 'फ़ोल्डर चुनें';

  @override
  String get driveInAppSpace => 'ऐप की जगह में';

  @override
  String get driveMyDrive => 'मेरा Drive';

  @override
  String get driveSharedWithMe => 'मेरे साथ शेयर किए गए';

  @override
  String get driveBack => 'वापस';

  @override
  String get driveNoResponse => 'Drive जवाब नहीं दे रहा';

  @override
  String get driveRetry => 'दोबारा कोशिश करें';

  @override
  String get driveIsLibrary => 'इसमें library.json है: यह एक लाइब्रेरी है';

  @override
  String get driveNotLibrary =>
      'इसमें library.json नहीं है: लाइब्रेरी वह फ़ोल्डर है जिसमें वह हो';

  @override
  String get driveUseFolder => 'यह फ़ोल्डर इस्तेमाल करें';

  @override
  String get driveNoFolders => 'यहाँ कोई फ़ोल्डर नहीं';

  @override
  String get driveNoticeAuthRequired =>
      'Kagami के पास अभी Google Drive पढ़ने की अनुमति नहीं है';

  @override
  String get driveAuthorize => 'अनुमति दें';

  @override
  String get driveSignIn => 'साइन इन करें';

  @override
  String get driveNoticeOffline =>
      'आप ऑफ़लाइन हैं: फ़ोन के अध्याय और Drive के पहले से डाउनलोड हुए पेज पढ़े जा सकते हैं। बाकी नेटवर्क आते ही अपने आप लौट आएगा';

  @override
  String driveNoticeError(String message) {
    return 'Drive: $message। फ़ोन में जो है, वह दिख रहा है';
  }

  @override
  String get syncSummaryOff => 'बंद';

  @override
  String get syncSummaryDownload => 'Drive से फ़ोन में';

  @override
  String get syncSummaryUpload => 'फ़ोन से Drive में';

  @override
  String get syncSummaryBoth => 'दोनों दिशाओं में';

  @override
  String syncSummaryManual(String direction) {
    return '$direction, हाथ से';
  }

  @override
  String syncSummaryDaily(String direction, String time) {
    return '$direction, रोज़ $time बजे';
  }

  @override
  String get syncTitle => 'सिंक';

  @override
  String get syncIntro =>
      'फ़ोन के मांगा फ़ोल्डर और Drive के फ़ोल्डर को एक जैसा रखता है, FolderSync के बिना। अगर आप इस फ़ोल्डर पर उसे अब भी चलाते हैं, तो उसे बंद कर दें: एक ही फ़ाइलों पर दो सिंक एक-दूसरे के रास्ते में आते हैं।';

  @override
  String get syncFolders => 'फ़ोल्डर';

  @override
  String get syncOnPhone => 'फ़ोन पर';

  @override
  String get syncNoFolderChosen => 'कोई फ़ोल्डर नहीं चुना';

  @override
  String get syncOnDrive => 'Drive पर';

  @override
  String get syncDriveNotConnected => 'Drive जुड़ा नहीं है';

  @override
  String get syncDirection => 'दिशा';

  @override
  String get syncDirectionOff => 'बंद';

  @override
  String get syncDirectionFromDrive => 'Drive से';

  @override
  String get syncDirectionToDrive => 'Drive पर';

  @override
  String get syncDirectionBoth => 'दोनों';

  @override
  String get syncDescOff =>
      'कुछ भी अपने आप नहीं चलता। Drive की लाइब्रेरी फिर भी पढ़ी जाती है, और «डाउनलोड» पहले की तरह काम करता है।';

  @override
  String get syncDescDownload =>
      'जो Drive पर आता है, वह फ़ोन में उतर आता है। फ़ोन से कुछ ऊपर नहीं जाता।';

  @override
  String get syncDescUpload =>
      'जो फ़ोन में है, वह Drive पर चढ़ता है — जैसे reading/backup में डेटा की कॉपियाँ। लाइब्रेरी के इंडेक्स सर्वर के ही रहते हैं।';

  @override
  String get syncDescBoth =>
      'जो एक तरफ़ बदलता है, वह दूसरी तरफ़ पहुँचता है; अगर दोनों तरफ़ बदला हो, तो जो ज़्यादा नया है वह जीतता है। लाइब्रेरी के इंडेक्स सिर्फ़ नीचे उतरते हैं: वे सर्वर के हैं।';

  @override
  String get syncDeletions => 'हटाना भी लागू करें';

  @override
  String get syncDeletionsDownload =>
      'Drive से जो गायब हो, उसे फ़ोन से हटाता है';

  @override
  String get syncDeletionsUpload =>
      'फ़ोन से जो आप हटाएँ, उसे Drive के ट्रैश में डालता है';

  @override
  String get syncDeletionsBoth =>
      'एक तरफ़ से दूसरी तरफ़; Drive से सिर्फ़ ट्रैश में';

  @override
  String get syncDeletionsOnNote =>
      '«जगह खाली करें» पढ़े हुए अध्याय अगले दौर में Drive से भी हटा देता है।';

  @override
  String get syncDeletionsOffNote =>
      'एक तरफ़ से हटाई फ़ाइल दूसरी तरफ़ रहती है और लौटती नहीं: «जगह खाली करें» फ़ोन खाली करता है और अध्याय Drive पर छोड़ देता है।';

  @override
  String get syncDaily => 'रोज़';

  @override
  String get syncScheduled => 'तय समय पर सिंक';

  @override
  String get syncManualOnly => 'सिर्फ़ हाथ से';

  @override
  String syncAtTime(String time) {
    return '$time बजे, ऐप बंद होने पर भी';
  }

  @override
  String get syncTime => 'समय';

  @override
  String get syncWifiOnly => 'सिर्फ़ Wi-Fi पर';

  @override
  String get syncWifiOnlyOn =>
      'ऐसे नेटवर्क का इंतज़ार करता है जिसका डेटा के हिसाब से पैसा न लगे';

  @override
  String get syncWifiOnlyOff => 'मोबाइल डेटा पर भी';

  @override
  String get syncScheduleNote =>
      'सही समय Android तय करता है: अगर चुने हुए समय पर इंटरनेट न हो, तो नेटवर्क आते ही दौर शुरू हो जाता है।';

  @override
  String get syncNow => 'अभी';

  @override
  String get syncTimePickerHelp => 'सिंक का समय';

  @override
  String get syncRunNow => 'अभी सिंक करें';

  @override
  String get syncRunNowReady =>
      'आप पढ़ते रह सकते हैं: कॉपियाँ अपने आप चलती रहती हैं';

  @override
  String get syncRunNowNotReady =>
      'फ़ोन का फ़ोल्डर और Drive का फ़ोल्डर, दोनों चाहिए';

  @override
  String get syncPhaseListing => 'Drive पर क्या है, देख रहा है…';

  @override
  String get syncPhaseComparing => 'फ़ोन से मिला रहा है…';

  @override
  String get syncPhaseNothing => 'कॉपी करने को कुछ नहीं';

  @override
  String syncPhaseFiles(int done, int total) {
    return 'फ़ाइल $done / $total';
  }

  @override
  String get syncStop => 'रोकें';

  @override
  String get syncNever => 'कभी सिंक नहीं हुआ';

  @override
  String get syncNeverNote =>
      'पहले से भरे फ़ोल्डर पर पहला दौर तेज़ होता है: एक जैसी फ़ाइलें आकार से पहचान ली जाती हैं';

  @override
  String syncLastScheduled(String date, String time) {
    return 'पिछला, तय समय पर: $date, $time बजे';
  }

  @override
  String syncLastManual(String date, String time) {
    return 'पिछला, हाथ से: $date, $time बजे';
  }

  @override
  String syncOutcomeDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count डाउनलोड हुईं',
      one: '$count डाउनलोड हुई',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeUploaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अपलोड हुईं',
      one: '$count अपलोड हुई',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeDeletedLocal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'फ़ोन से $count हटाई गईं',
      one: 'फ़ोन से $count हटाई गई',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeTrashed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Drive के ट्रैश में $count',
      one: 'Drive के ट्रैश में $count',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count असफल, दोबारा कोशिश होगी',
      one: '$count असफल, दोबारा कोशिश होगी',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeErrorSoFar(String error, String done) {
    return '$error। अब तक: $done';
  }

  @override
  String get syncOutcomeAligned => 'सब पहले से एक जैसा था';

  @override
  String get settingsTitle => 'सेटिंग';

  @override
  String get settingsAppearance => 'रूप';

  @override
  String get settingsThemeDark => 'गहरा';

  @override
  String get settingsThemeLight => 'हल्का';

  @override
  String get settingsThemeSystem => 'सिस्टम की तरह';

  @override
  String get settingsLibrary => 'लाइब्रेरी';

  @override
  String get settingsFolder => 'फ़ोल्डर';

  @override
  String get settingsNoFolder => 'कोई फ़ोल्डर नहीं चुना';

  @override
  String get settingsReloadIndexes => 'इंडेक्स फिर से पढ़ें';

  @override
  String get settingsReloadIndexesNote =>
      'तब करें जब सिंक अभी-अभी कुछ नया लाया हो';

  @override
  String get settingsIndexesReloaded => 'इंडेक्स फिर से पढ़े गए';

  @override
  String get settingsGoogleDrive => 'Google Drive';

  @override
  String get settingsReading => 'पढ़ना';

  @override
  String get settingsAccount => 'खाता';

  @override
  String get settingsData => 'डेटा';

  @override
  String get settingsAbout => 'जानकारी';

  @override
  String get settingsAutoBackup => 'लाइब्रेरी में अपने आप कॉपी';

  @override
  String get settingsAutoBackupNote =>
      'दिन में एक बार reading/backup/ में, जिसे सिंक मांगा के साथ Drive पर ले जाता है';

  @override
  String get settingsExport => 'डेटा एक्सपोर्ट करें';

  @override
  String get settingsExportNote =>
      'स्थिति, रेटिंग, इतिहास, कलेक्शन और बुकमार्क एक फ़ाइल में';

  @override
  String get settingsExportDialog => 'बैकअप कहाँ सहेजना है';

  @override
  String get settingsExportCancelled => 'एक्सपोर्ट रद्द किया गया';

  @override
  String get settingsExportSaved => 'बैकअप सहेजा गया';

  @override
  String get settingsImport => 'बैकअप से इंपोर्ट करें';

  @override
  String get settingsImportNote =>
      'कुछ बदलने से पहले बताता है कि उसमें क्या है';

  @override
  String get settingsImportDialog => 'Kagami का बैकअप चुनें';

  @override
  String get settingsImportInvalid => 'यह Kagami का बैकअप नहीं है';

  @override
  String get settingsImportSheetTitle => 'यह बैकअप इंपोर्ट करें?';

  @override
  String get settingsImportSeries => 'सीरीज़';

  @override
  String get settingsImportRead => 'पढ़े';

  @override
  String get settingsImportCollections => 'कलेक्शन';

  @override
  String settingsImportExplain(String date) {
    return 'बनाया गया: $date। मिलाएँ आपके पास जो है उसे रखता है और जोड़ता है: पढ़े हुए अध्याय जुड़ जाते हैं और बाकी में सबसे नया रिकॉर्ड जीतता है। बदलें इस डिवाइस का डेटा मिटा देता है।';
  }

  @override
  String get settingsImportExplainUnknownDate =>
      'बनाने की तारीख अज्ञात है। मिलाएँ आपके पास जो है उसे रखता है और जोड़ता है: पढ़े हुए अध्याय जुड़ जाते हैं और बाकी में सबसे नया रिकॉर्ड जीतता है। बदलें इस डिवाइस का डेटा मिटा देता है।';

  @override
  String get settingsImportMerge => 'मिलाएँ';

  @override
  String get settingsImportReplace => 'बदलें';

  @override
  String get settingsImportDone => 'डेटा इंपोर्ट हो गया';

  @override
  String get settingsImportFailed => 'इंपोर्ट नहीं हो सका';

  @override
  String get settingsWipe => 'निजी डेटा मिटाएँ';

  @override
  String get settingsWipeNote =>
      'स्थिति, रेटिंग, इतिहास और कलेक्शन। मांगा को नहीं छुआ जाता';

  @override
  String get settingsWipeSheetTitle => 'सारा निजी डेटा मिटा दें?';

  @override
  String get settingsWipeExplain =>
      'इस डिवाइस की स्थिति, रेटिंग, पसंदीदा, पढ़े हुए अध्याय, इतिहास, सेशन, कलेक्शन और बुकमार्क मिट जाएँगे। मांगा और लाइब्रेरी के इंडेक्स को नहीं छुआ जाता।\n\nअगर आपके पास बैकअप नहीं है, तो यह उसे बनाने का आख़िरी मौका है।';

  @override
  String get settingsWipeConfirm => 'सब मिटाएँ';

  @override
  String get settingsWipeDone => 'निजी डेटा मिटा दिया गया';

  @override
  String get settingsDriveConnect => 'Google Drive जोड़ें';

  @override
  String get settingsDriveConnectNote =>
      'लाइब्रेरी को पूरा फ़ोन में लाए बिना Drive से पढ़ता है, और सिर्फ़ वही डाउनलोड करता है जो आप चुनें';

  @override
  String get settingsDriveFolder => 'Drive पर फ़ोल्डर';

  @override
  String get settingsDriveSync => 'फ़ोल्डर का सिंक';

  @override
  String get settingsDriveDownloadsGo => 'डाउनलोड किए अध्याय जाते हैं';

  @override
  String settingsDriveDownloadsFolder(String path) {
    return 'लाइब्रेरी के फ़ोल्डर में: $path';
  }

  @override
  String get settingsDriveDownloadsApp =>
      'ऐप की जगह में: अनइंस्टॉल करने पर चले जाते हैं';

  @override
  String get settingsDriveDownloadsAsk => 'पहले डाउनलोड पर पूछा जाता है';

  @override
  String get settingsDriveCache => 'Drive से पढ़े पेज';

  @override
  String settingsDriveCacheNote(String used, String limit) {
    return '$used कैश में, ज़्यादा से ज़्यादा $limit। इंटरनेट के बिना दोबारा पढ़े जा सकते हैं';
  }

  @override
  String get settingsDriveCacheLimitTitle => 'पेजों के लिए जगह';

  @override
  String get settingsDriveClearCache => 'कैश खाली करें';

  @override
  String get settingsDriveClearCacheNote =>
      'डाउनलोड किए अध्यायों को नहीं छुआ जाता';

  @override
  String get settingsDriveDisconnect => 'Drive हटाएँ';

  @override
  String get settingsDriveDisconnectNote =>
      'लाइब्रेरी फिर फ़ोन का फ़ोल्डर बन जाती है। डाउनलोड किए अध्याय रहते हैं';

  @override
  String get settingsAccountUnavailable => 'यहाँ खाता उपलब्ध नहीं है';

  @override
  String get settingsAccountUnavailableNote =>
      'इस बिल्ड में Firebase नहीं है: डेटा वहीं रहता है जहाँ है, डिवाइस पर';

  @override
  String get settingsAccountSignIn => 'Google से साइन इन करें';

  @override
  String get settingsAccountSignInNote =>
      'रेटिंग, स्थिति, पढ़े हुए अध्याय, इतिहास और कलेक्शन फ़ोन की जगह खाते के साथ चलते हैं';

  @override
  String get settingsAccountSyncNow => 'अभी सिंक करें';

  @override
  String get settingsAccountNeverSynced => 'इस फ़ोन पर कभी सिंक नहीं हुआ';

  @override
  String settingsAccountLastSync(String date, String time) {
    return 'पिछली बार $date, $time बजे';
  }

  @override
  String get settingsAccountSignOut => 'साइन आउट';

  @override
  String get settingsAccountSignOutNote =>
      'आख़िरी पढ़ाई ऊपर भेजता है, फिर साइन आउट करता है';

  @override
  String get settingsAccountForget => 'कॉपी रखना बंद करें';

  @override
  String get settingsAccountForgetNote =>
      'खाते से डेटा मिटाता है। इस फ़ोन का डेटा वहीं रहता है जहाँ है';

  @override
  String get settingsAccountErrorNote => 'इस फ़ोन के डेटा को नहीं छुआ गया';

  @override
  String get settingsAccountForgetSheetTitle => 'खाते से डेटा मिटा दें?';

  @override
  String get settingsAccountForgetExplain =>
      'आपके लिए रखी गई कॉपी मिट जाती है और साइन इन बंद हो जाता है। इस फ़ोन की स्थिति, रेटिंग, इतिहास और कलेक्शन वहीं रहते हैं — पर किसी दूसरे फ़ोन पर नहीं दिखेंगे।';

  @override
  String get settingsAccountForgetConfirm => 'खाते से मिटाएँ';

  @override
  String get settingsReaderDirection => 'पेज मोड में दिशा';

  @override
  String get settingsReaderBackground => 'पृष्ठभूमि';

  @override
  String get settingsReaderKeepAwake => 'स्क्रीन चालू रखें';

  @override
  String get settingsReaderProgressBar => 'प्रगति पट्टी';

  @override
  String get settingsProbe => 'सहजता मापें';

  @override
  String get settingsProbeNote =>
      'रीडर में, ऊपर: धीमे और छूटे फ़्रेम, पट्टियाँ कहाँ से आती हैं, GC। संख्याओं पर टैप करने से वे शून्य हो जाती हैं';

  @override
  String get settingsProbeInfo1 =>
      'रीडर में ऊपर बाईं ओर संख्याओं का एक बॉक्स दिखाता है कि पढ़ना कितना सहज है। इससे समझ आता है कि स्क्रोल क्यों अटकता है: पढ़ने के तरीके में कुछ नहीं बदलता, और इसकी लागत बहुत कम है।';

  @override
  String get settingsProbeInfo2 =>
      'सबसे ज़रूरी संख्या «छूटे» है: पेज स्क्रोल होते समय जो फ़्रेम कम पड़ जाते हैं। हर एक हल्का-सा झटका है जो दिखता है। «देर से शुरू» और «धीमे» बताते हैं कि ऐप व्यस्त था या नहीं, «GC Android» बताता है कि सिस्टम मेमोरी खाली कर रहा था या नहीं।';

  @override
  String get settingsProbeInfo3 =>
      '«टाइल», «पूरे», «फ़ोन के» और «नेटिव» बताते हैं कि पेज का हर टुकड़ा कहाँ से आया: पहले तीन हल्के रास्ते हैं, आख़िरी उसी समय की गई कटाई है, जो भारी पड़ती है।';

  @override
  String get settingsProbeInfo4 =>
      'बॉक्स पर टैप करने से संख्याएँ शून्य हो जाती हैं, ताकि अध्याय के किसी ख़ास बिंदु से मापा जा सके। ऐप दोबारा खोलने पर माप अपने आप बंद हो जाता है।';

  @override
  String get settingsTexture => 'नेटिव पट्टियाँ टेक्सचर के रूप में';

  @override
  String get settingsTextureNote =>
      'प्रयोग: जो पेज अभी कटने बाकी हैं, वे इंटरफ़ेस से गुज़रे बिना GPU तक पहुँचते हैं। ऐप दोबारा खोलने पर बंद हो जाता है';

  @override
  String get settingsTextureInfo1 =>
      'वेबटून के बहुत ऊँचे पेज टुकड़ों में पढ़े जाते हैं। ज़्यादातर टुकड़े पहले से तैयार होते हैं: सर्वर पर आर्काइव द्वारा काटे हुए, या अध्याय पहली बार खोलने पर फ़ोन द्वारा। जब वे नहीं होते, तो Android का डिकोडर उसी समय उन्हें काटता है।';

  @override
  String get settingsTextureInfo2 =>
      'आम तौर पर उन टुकड़ों के पिक्सेल स्क्रीन पर पहुँचने से पहले ऐप से होकर गुज़रते हैं। इस विकल्प के साथ वे सीधे ग्राफ़िक्स चिप तक जाते हैं: स्क्रोल करते समय ऐप पर काम कम होता है, और स्क्रोल कम अटक सकता है। इमेज की क्वालिटी नहीं बदलती।';

  @override
  String get settingsTextureInfo3 =>
      'यह एक प्रयोग है: चित्र बनाने का नया तरीका, जो इस फ़ोन पर अभी जाँचा नहीं गया है। अगर आपको काले पेज, लकीरें या झिलमिलाहट दिखे, तो इसे बंद कर दें। अगर फ़ोन इसे सपोर्ट नहीं करता, तो ऐप अपने आप सामान्य तरीके पर लौट आता है।';

  @override
  String get settingsTextureInfo4 =>
      'जो अध्याय पहले से टाइल में कटे हैं, उन पर कुछ नहीं बदलता, क्योंकि वहाँ यह रास्ता इस्तेमाल नहीं होता। ऐप दोबारा खोलने पर यह अपने आप बंद हो जाता है।';

  @override
  String get settingsWhatItDoes => 'यह क्या करता है';

  @override
  String get settingsBackupsTitle => 'लाइब्रेरी में कॉपियाँ';

  @override
  String get settingsBackupsNone =>
      'अभी कोई कॉपी नहीं: पहली अगली बार ऐप खोलने पर बनेगी';

  @override
  String settingsBackupsLatest(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count कॉपियाँ, आख़िरी $name',
      one: '1 कॉपी, आख़िरी $name',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupNow => 'अभी कॉपी बनाएँ';

  @override
  String settingsBackupWritten(String path) {
    return 'कॉपी $path में लिखी गई';
  }

  @override
  String settingsVersion(String version, String build) {
    return 'वर्शन $version ($build)';
  }

  @override
  String get settingsTagline => 'लोकल MALF आर्काइव के लिए रीडर';

  @override
  String get librarySortUpdated => 'हाल में अपडेट हुईं';

  @override
  String get librarySortTitle => 'शीर्षक';

  @override
  String get librarySortProgress => 'प्रगति';

  @override
  String get librarySortAdded => 'हाल में जोड़ी गईं';

  @override
  String get librarySortLastRead => 'हाल में पढ़ी गईं';

  @override
  String get librarySortUnread => 'पढ़ने बाकी';

  @override
  String get librarySortRating => 'रेटिंग';

  @override
  String get librarySortChapters => 'अध्यायों की संख्या';

  @override
  String get librarySortShuffle => 'बेतरतीब';

  @override
  String get libraryDisplayComfortable => 'आरामदेह ग्रिड';

  @override
  String get libraryDisplayCompact => 'सघन ग्रिड';

  @override
  String get libraryDisplayList => 'सूची';

  @override
  String get libraryDisplayDetailed => 'विस्तृत सूची';

  @override
  String get libraryAutoReading => 'पढ़ रहे हैं';

  @override
  String get libraryAutoFresh => 'नया';

  @override
  String get libraryAutoFavorites => 'पसंदीदा';

  @override
  String get libraryAutoPlanned => 'शुरू करनी हैं';

  @override
  String get libraryAutoFinished => 'पूरी हुईं';

  @override
  String libraryRowChapters(int count) {
    return '$count अध्याय';
  }

  @override
  String libraryRowUnread(int count) {
    return '$count पढ़ने बाकी';
  }

  @override
  String get libraryNoMatchTitle => 'कोई मेल नहीं';

  @override
  String get libraryNoMatchMessage =>
      'चुनी गई खोज और फ़िल्टर से कोई सीरीज़ मेल नहीं खाती।';

  @override
  String get libraryEmptyTitle => 'लाइब्रेरी खाली है';

  @override
  String get libraryEmptyMessage =>
      'लाइब्रेरी में कोई सीरीज़ नहीं है। अगर होनी चाहिए, तो फ़ोल्डर का सिंक जाँचें।';

  @override
  String get libraryClearFilters => 'फ़िल्टर हटाएँ';

  @override
  String get libraryTitle => 'लाइब्रेरी';

  @override
  String get libraryCancelSelection => 'चयन रद्द करें';

  @override
  String librarySelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चुनी गईं',
      one: '1 चुनी गई',
    );
    return '$_temp0';
  }

  @override
  String libraryAllWithCount(int count) {
    return 'सभी ($count)';
  }

  @override
  String get libraryAll => 'सभी';

  @override
  String get libraryMarkAllRead => 'सब पढ़ा हुआ चिह्नित करें';

  @override
  String get libraryMarkAllUnread => 'सब अनपढ़ा चिह्नित करें';

  @override
  String get libraryStatus => 'स्थिति';

  @override
  String get libraryFavorites => 'पसंदीदा';

  @override
  String get libraryAddToCollection => 'कलेक्शन में जोड़ें';

  @override
  String libraryStatusOfSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सीरीज़ की स्थिति',
      one: '1 सीरीज़ की स्थिति',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सीरीज़ पढ़ी हुई चिह्नित की गईं',
      one: '1 सीरीज़ पढ़ी हुई चिह्नित की गई',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सीरीज़ फिर पढ़ने बाकी हो गईं',
      one: '1 सीरीज़ फिर पढ़ने बाकी हो गई',
    );
    return '$_temp0';
  }

  @override
  String get librarySearchHint => 'शीर्षक, लेखक, tag:…';

  @override
  String get libraryLayout => 'लेआउट';

  @override
  String get libraryFiltersAndSort => 'फ़िल्टर और क्रम';

  @override
  String get libraryReset => 'रीसेट';

  @override
  String get librarySortSection => 'क्रम';

  @override
  String get libraryShowOnly => 'सिर्फ़ दिखाएँ';

  @override
  String get libraryOnlyUnread => 'पढ़ने बाकी अध्यायों वाली';

  @override
  String get libraryOnlyStarted => 'शुरू की हुई';

  @override
  String get libraryOnlyNew => 'नए अध्यायों वाली';

  @override
  String get libraryOnlyFavorite => 'पसंदीदा';

  @override
  String get libraryMinRating => 'कम से कम रेटिंग';

  @override
  String get libraryRelease => 'प्रकाशन';

  @override
  String get libraryGenres => 'शैलियाँ';

  @override
  String get libraryTriHint => 'एक टैप से शामिल, दो टैप से बाहर';

  @override
  String get libraryTags => 'टैग';

  @override
  String get libraryAuthors => 'लेखक';

  @override
  String get homeEmptyTitle => 'लाइब्रेरी खाली है';

  @override
  String get homeEmptyMessage =>
      'देखने को कुछ नहीं: फ़ोल्डर में अभी कोई सीरीज़ नहीं है।';

  @override
  String get homeToStart => 'शुरू करनी हैं';

  @override
  String get homeSimilarTitle => 'आप जो पढ़ते हैं, उसी के आधार पर';

  @override
  String get homeSimilarSubtitle =>
      'अभी खोली नहीं गईं, आपकी पसंद की शैलियों वाली';

  @override
  String get homeRecentlyArrived => 'हाल में आईं';

  @override
  String get homeLeftHalfway => 'बीच में छोड़ी';

  @override
  String get homeLeftHalfwaySubtitle => 'रुकी हुई और छोड़ी हुई';

  @override
  String get homeCaughtUpTitle => 'आप अप-टू-डेट हैं';

  @override
  String get homeCaughtUpMessage =>
      'जो कुछ सिंक हुआ है, उस सबके साथ। अगला अध्याय फ़ोल्डर के साथ आएगा।';

  @override
  String get homeRandomSeries => 'कोई भी एक';

  @override
  String get homeReloadLibrary => 'लाइब्रेरी फिर से पढ़ें';

  @override
  String get homeGreetingNight => 'देर रात';

  @override
  String get homeGreetingMorning => 'सुप्रभात';

  @override
  String get homeGreetingAfternoon => 'नमस्कार';

  @override
  String get homeGreetingEvening => 'शुभ संध्या';

  @override
  String get homeStatRead => 'पढ़े';

  @override
  String get homeStatReadCaption => 'कुल अध्याय';

  @override
  String get homeStatUnread => 'पढ़ने बाकी';

  @override
  String get homeStatUnreadCaption => 'फ़ोन पर';

  @override
  String get homeStatStreak => 'लगातार';

  @override
  String homeStatStreakCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'दिन',
      one: 'दिन',
    );
    return '$_temp0';
  }

  @override
  String get homeResume => 'फिर शुरू करें';

  @override
  String get homeNextChapter => 'अगला अध्याय';

  @override
  String get homeRead => 'पढ़ें';

  @override
  String get homeUpdates => 'अपडेट';

  @override
  String get homeUpdatesSubtitle => 'सिंक हुए और अभी न पढ़े गए अध्याय';

  @override
  String homeLatestChapter(String number) {
    return 'अध्याय $number';
  }

  @override
  String get homeAgoToday => 'आज';

  @override
  String get homeAgoYesterday => 'कल';

  @override
  String homeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन पहले',
      one: '1 दिन पहले',
    );
    return '$_temp0';
  }

  @override
  String homeAgoWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सप्ताह पहले',
      one: '1 सप्ताह पहले',
    );
    return '$_temp0';
  }

  @override
  String homeAgoMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count महीने पहले',
      one: '1 महीने पहले',
    );
    return '$_temp0';
  }

  @override
  String homeAgoYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count साल पहले',
      one: '1 साल पहले',
    );
    return '$_temp0';
  }

  @override
  String get collectionsTitle => 'कलेक्शन';

  @override
  String get collectionsNew => 'नया';

  @override
  String get collectionsAutomatic => 'अपने आप बने';

  @override
  String get collectionsYours => 'आपके कलेक्शन';

  @override
  String get collectionsNoneTitle => 'कोई कलेक्शन नहीं';

  @override
  String get collectionsNoneMessage =>
      'ये अपने आप बढ़ती लाइब्रेरी को व्यवस्थित करने का तरीका हैं: एक सीरीज़ कई कलेक्शन में हो सकती है और क्रम आप तय करते हैं।';

  @override
  String collectionsSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सीरीज़',
      one: '1 सीरीज़',
    );
    return '$_temp0';
  }

  @override
  String get collectionsEdit => 'बदलें';

  @override
  String get collectionsRenameRecolor => 'नाम और रंग बदलें';

  @override
  String get collectionsDelete => 'कलेक्शन हटाएँ';

  @override
  String get collectionsNotFound => 'कलेक्शन नहीं मिला।';

  @override
  String get collectionsDone => 'हो गया';

  @override
  String get collectionsReorder => 'क्रम बदलें';

  @override
  String get collectionsEmptyTitle => 'कलेक्शन खाली है';

  @override
  String get collectionsEmptyMessage =>
      'सीरीज़ उसके विवरण पेज से जोड़ी जाती है, या लाइब्रेरी में किसी कवर को देर तक दबाकर।';

  @override
  String get collectionsRemoveFrom => 'कलेक्शन से हटाएँ';

  @override
  String get shellDataUnreadableTitle => 'ऐप का डेटा पढ़ा नहीं जा सकता';

  @override
  String get shellRetry => 'दोबारा कोशिश करें';

  @override
  String get shellTabHome => 'होम';

  @override
  String get shellTabLibrary => 'लाइब्रेरी';

  @override
  String get shellTabCollections => 'कलेक्शन';

  @override
  String get shellTabMore => 'और';

  @override
  String get moreTitle => 'और';

  @override
  String get moreSectionLibrary => 'लाइब्रेरी';

  @override
  String get moreSectionReading => 'आपका पढ़ना';

  @override
  String get moreSectionPrivacy => 'निजता';

  @override
  String get moreSectionApp => 'ऐप';

  @override
  String get moreDownload => 'मांगा डाउनलोड करें';

  @override
  String get moreDownloadSubtitle => 'शीर्षक खोजें या लिंक पेस्ट करें';

  @override
  String get moreHistory => 'इतिहास';

  @override
  String get moreHistorySubtitle => 'आपने क्या और कब पढ़ा';

  @override
  String get moreStatistics => 'आँकड़े';

  @override
  String get moreStatisticsSubtitle =>
      'कितना पढ़ते हैं, क्या पढ़ते हैं, कब पढ़ते हैं';

  @override
  String get moreIncognito => 'इन्कॉग्निटो में पढ़ना';

  @override
  String get moreIncognitoSubtitle =>
      'जगह, पूरे किए अध्याय और पढ़ने का समय दर्ज नहीं होता';

  @override
  String get moreSettings => 'सेटिंग';

  @override
  String get moreSettingsSubtitle => 'रूप, लाइब्रेरी, पढ़ना, बैकअप';

  @override
  String get historyTitle => 'इतिहास';

  @override
  String get historyIncognitoOn => 'इन्कॉग्निटो चालू';

  @override
  String get historyIncognitoOff => 'इन्कॉग्निटो में पढ़ें';

  @override
  String get historyClear => 'खाली करें';

  @override
  String get historyUnreadable => 'इतिहास पढ़ा नहीं जा सकता';

  @override
  String get historyEmptyTitle => 'अभी कुछ नहीं पढ़ा';

  @override
  String get historyEmptyMessage =>
      'हर पूरा किया अध्याय अपनी तारीख के साथ यहाँ दिखेगा।';

  @override
  String get historyClearTitle => 'इतिहास खाली करें?';

  @override
  String get historyClearMessage =>
      'पढ़ने की तारीखें और पढ़ने में बिताया समय मिट जाते हैं, और उनसे बने आँकड़े भी। अध्याय फिर पढ़ने बाकी हो जाते हैं।';

  @override
  String get historyIncognitoBanner =>
      'इन्कॉग्निटो में: जगह, पूरे किए अध्याय और पढ़ने का समय दर्ज नहीं किया जाता।';

  @override
  String get historyToday => 'आज';

  @override
  String get historyYesterday => 'कल';

  @override
  String get historyReread => 'फिर पढ़ें';

  @override
  String get historyRemove => 'इतिहास से हटाएँ';

  @override
  String get originLocal => 'फ़ोन पर';

  @override
  String get originDrive => 'Drive पर';

  @override
  String get originMixed => 'फ़ोन पर, और बाकी अध्याय Drive पर';

  @override
  String get coverNoChapters => 'कोई अध्याय डाउनलोड नहीं हुआ';

  @override
  String coverChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अध्याय',
    );
    return '$_temp0';
  }

  @override
  String coverChaptersUnread(int count, int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अध्याय',
    );
    return '$_temp0 · $unread पढ़ने बाकी';
  }

  @override
  String coverNewChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count नए अध्याय',
      one: '1 नया अध्याय',
    );
    return '$_temp0';
  }

  @override
  String coverUnread(int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '$unread अध्याय पढ़ने बाकी',
      one: '1 अध्याय पढ़ने बाकी',
    );
    return '$_temp0';
  }

  @override
  String coverUnreadFresh(int unread, int fresh) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '$unread अध्याय पढ़ने बाकी',
      one: '1 अध्याय पढ़ने बाकी',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fresh,
      locale: localeName,
      other: '$fresh नए',
      one: '1 नया',
    );
    return '$_temp0, जिनमें $_temp1';
  }

  @override
  String chartsDayNothing(String date) {
    return '$date: कुछ नहीं';
  }

  @override
  String chartsDayChapters(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अध्याय',
      one: '1 अध्याय',
    );
    return '$date: $_temp0';
  }

  @override
  String get kitClose => 'बंद करें';

  @override
  String get collectionSheetTitle => 'कलेक्शन';

  @override
  String collectionSheetTitleMany(int count) {
    return '$count सीरीज़ के कलेक्शन';
  }

  @override
  String get collectionSheetNew => 'नया';

  @override
  String get collectionSheetEmptyTitle => 'कोई कलेक्शन नहीं';

  @override
  String get collectionSheetEmptyMessage =>
      'ये अपने आप बढ़ती लाइब्रेरी को व्यवस्थित करने के लिए हैं।';

  @override
  String collectionSheetSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सीरीज़',
      one: '1 सीरीज़',
    );
    return '$_temp0';
  }

  @override
  String get collectionSheetCreateTitle => 'नया कलेक्शन';

  @override
  String get collectionSheetEditTitle => 'कलेक्शन बदलें';

  @override
  String get collectionSheetNameHint => 'नाम';

  @override
  String get collectionSheetColor => 'रंग';

  @override
  String get collectionSheetCreate => 'बनाएँ';

  @override
  String get collectionSheetSave => 'सहेजें';

  @override
  String get cleanupTitle => 'जगह खाली करें?';

  @override
  String get cleanupSyncBusy =>
      'सिंक चल रहा है: उसके खत्म होने पर दोबारा कोशिश करें';

  @override
  String cleanupNotAllDeleted(String error) {
    return 'सब कुछ मिटाया नहीं जा सका: $error';
  }

  @override
  String cleanupDriveError(String error) {
    return 'Drive: $error। जो पहले हट चुके हैं, वे हटे ही रहते हैं';
  }

  @override
  String cleanupFreed(String size) {
    return '$size खाली हुआ';
  }

  @override
  String get cleanupNeedsNetwork => 'Drive से हटाने के लिए इंटरनेट चाहिए';

  @override
  String cleanupIntroDrive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पढ़े हुए अध्याय अब भी Drive पर हैं।',
      one: 'एक पढ़ा हुआ अध्याय अब भी Drive पर है।',
    );
    return '$_temp0';
  }

  @override
  String cleanupIntroPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पढ़े हुए अध्याय अब भी फ़ोन में जगह घेर रहे हैं।',
      one: 'एक पढ़ा हुआ अध्याय अब भी फ़ोन में जगह घेर रहा है।',
    );
    return '$_temp0';
  }

  @override
  String get cleanupPhoneChapters => 'फ़ोन के अध्याय';

  @override
  String get cleanupDriveCache => 'Drive का कैश';

  @override
  String get cleanupDriveChapters => 'Drive के अध्याय';

  @override
  String cleanupApproxSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अध्याय',
      one: '1 अध्याय',
    );
    return '$_temp0 · लगभग $size';
  }

  @override
  String cleanupExactSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अध्याय',
      one: '1 अध्याय',
    );
    return '$_temp0 · $size';
  }

  @override
  String cleanupApproxSizeTrash(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अध्याय',
      one: '1 अध्याय',
    );
    return '$_temp0 · लगभग $size · ट्रैश में';
  }

  @override
  String get cleanupQuiet => 'इस सीरीज़ के लिए दोबारा न पूछें';

  @override
  String get cleanupWarnNotOnDrive =>
      'यह सीरीज़ Drive पर नहीं है: मिटाए गए अध्याय तब तक दोबारा नहीं पढ़े जा सकेंगे जब तक सिंक उन्हें वापस न ले आए।';

  @override
  String get cleanupWarnGoneEverywhere => 'वे न फ़ोन में रहेंगे, न Drive पर।';

  @override
  String get cleanupWarnStaysOnDrive =>
      'अध्याय Drive पर रहते हैं और वहीं से दोबारा पढ़े जा सकते हैं।';

  @override
  String get cleanupWarnTrash =>
      'Drive के ट्रैश से वे तीस दिन तक वापस मिल सकते हैं। सर्वर का इंडेक्स उन्हें अब भी गिनाता है: अगर सर्वर उन्हें दोबारा अपलोड करे, तो वे फिर Drive से पढ़े जा सकते हैं।';

  @override
  String get cleanupDelete => 'मिटाएँ';

  @override
  String get cleanupNotNow => 'अभी नहीं';

  @override
  String get cleanupSyncWarnExternal =>
      'अगर FolderSync फ़ोल्डर को दोनों दिशाओं में सिंक करता है, तो मिटाना Drive तक भी पहुँच सकता है; अगर वह सिर्फ़ डाउनलोड करता है, तो अगले दौर में अध्याय लौट सकते हैं।';

  @override
  String get cleanupSyncWarnOwn =>
      'सिंक इस चुनाव का सम्मान करता है: जो आप एक तरफ़ से हटाते हैं, वह दूसरी तरफ़ न लौटता है न मिटता है, हटाना लागू करने पर भी।';

  @override
  String get statsRangeMonth => '30 दिन';

  @override
  String get statsRangeQuarter => '3 महीने';

  @override
  String get statsRangeYear => 'एक साल';

  @override
  String get statsTitle => 'आँकड़े';

  @override
  String get statsUnavailable => 'आँकड़े निकाले नहीं जा सकते';

  @override
  String get statsChaptersRead => 'पढ़े अध्याय';

  @override
  String get statsSeriesInLibrary => 'लाइब्रेरी में सीरीज़';

  @override
  String statsMinutes(int count) {
    return '$count मिनट';
  }

  @override
  String statsHours(int count) {
    return '$count घंटे';
  }

  @override
  String get statsReadingTime => 'पढ़ने का समय';

  @override
  String get statsReadingTimeHint => 'पढ़ते समय मापा गया';

  @override
  String get statsPagesSeen => 'देखे गए पेज';

  @override
  String get statsStreak => 'लगातार दिन';

  @override
  String statsStreakRecord(int count) {
    return 'रिकॉर्ड: $count';
  }

  @override
  String get statsAverageRating => 'औसत रेटिंग';

  @override
  String statsRatedSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सीरीज़ को रेटिंग मिली',
      one: '1 सीरीज़ को रेटिंग मिली',
    );
    return '$_temp0';
  }

  @override
  String get statsChaptersOverTime => 'पढ़े अध्याय';

  @override
  String get statsPerWeek => 'प्रति सप्ताह';

  @override
  String get statsPerDay => 'प्रति दिन';

  @override
  String get statsActivityTitle => 'आप कब पढ़ते हैं';

  @override
  String get statsActivitySubtitle => 'हर दिन का एक चौकोर, पिछले छह महीनों के';

  @override
  String get statsShelfTitle => 'स्थिति के अनुसार लाइब्रेरी';

  @override
  String statsGenreOthers(int count) {
    return '$count और';
  }

  @override
  String get statsGenresTitle => 'आप जो शैलियाँ पढ़ते हैं';

  @override
  String get statsGenresSubtitle => 'आपकी शुरू की हुई सीरीज़ के आधार पर';

  @override
  String get statsRatingsTitle => 'आप कैसे रेटिंग देते हैं';

  @override
  String get statsRatingsSubtitle => 'हर रेटिंग पर कितनी सीरीज़';

  @override
  String get statsTopSeries => 'सबसे ज़्यादा पढ़ी सीरीज़';

  @override
  String get statsShapeTitle => 'लाइब्रेरी का स्वरूप';

  @override
  String get statsSyncedChapters => 'सिंक हुए अध्याय';

  @override
  String get statsStillUnread => 'अभी पढ़ने बाकी';

  @override
  String get statsOngoingSeries => 'जारी सीरीज़';

  @override
  String statsAnnouncedMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अध्याय घोषित पर डाउनलोड नहीं हुए',
      one: '1 अध्याय घोषित पर डाउनलोड नहीं हुआ',
    );
    return '$_temp0';
  }

  @override
  String get statsBytesOnPhone => 'फ़ोन में घेरी जगह';

  @override
  String get statsNoHistory =>
      'इस अवधि में कुछ नहीं पढ़ा गया। इतिहास उस समय से शुरू होता है जब से ऐप ने उसे दर्ज करना शुरू किया।';

  @override
  String get dataDriveNotLinked => 'Drive जुड़ा नहीं है';

  @override
  String get dataChapterNotOnDrive => 'अध्याय Drive पर नहीं मिला';

  @override
  String get dataChapterNoPagesOnDrive => 'अध्याय के पेज Drive पर नहीं हैं';

  @override
  String get dataPageNotOnDrive => 'पेज Drive पर नहीं मिला';

  @override
  String get dataPrefetchCancelled => 'पहले से लोड करना रद्द हुआ';

  @override
  String get dataDriveAccessDenied => 'Google ने Drive की अनुमति नहीं दी';

  @override
  String get dataDriveOfflineNeverOpened =>
      'इंटरनेट नहीं है, और Drive की लाइब्रेरी इस फ़ोन पर कभी खोली नहीं गई';

  @override
  String get dataDriveSignedOut =>
      'Drive की लाइब्रेरी पढ़ने के लिए Google से साइन इन करें';

  @override
  String get dataSyncMissingFolderOrDirection => 'फ़ोल्डर या दिशा नहीं चुनी गई';

  @override
  String get dataSyncFailed => 'सिंक नहीं हो सका';

  @override
  String get dataSyncFolderUnreadable => 'फ़ोन का फ़ोल्डर पढ़ा नहीं जा रहा';

  @override
  String get dataSyncBusy => 'एक सिंक पहले से चल रहा है';

  @override
  String get dataSyncCancelled => 'सिंक रोका गया';

  @override
  String get dataSyncDirectionDownload => 'Drive से';

  @override
  String get dataSyncDirectionUpload => 'Drive पर';

  @override
  String get dataSyncDirectionBoth => 'दोनों';

  @override
  String dataServerInviteTitle(String sender) {
    return '$sender ने आपको अपने सर्वर का एक्सेस दिया है';
  }

  @override
  String dataServerInviteText(String serverName) {
    return '«$serverName» जोड़ें और वह मांगा आपके Drive पर डाउनलोड करेगा, फ़ोन बंद होने पर भी।';
  }

  @override
  String get dataServerSignInRequired =>
      'सर्वर इस्तेमाल करने के लिए Google से साइन इन करें।';

  @override
  String get dataServerNotLinked => 'कोई सर्वर जुड़ा नहीं है।';

  @override
  String dataServerUserNotNotified(String email, String url) {
    return '$email सर्वर इस्तेमाल कर सकता है, पर मैं उसे सूचित नहीं कर सका: उसे यह पता खुद भेज दें: $url।';
  }

  @override
  String get dataPickLibraryFolderTitle => 'मांगा लाइब्रेरी का फ़ोल्डर चुनें';

  @override
  String get dataCloudSignInNotEnabled =>
      'इस प्रोजेक्ट में Google से साइन इन अभी चालू नहीं है';

  @override
  String get dataCloudNoConnection => 'इंटरनेट नहीं है';

  @override
  String get dataCloudNoSignIn => 'साइन इन नहीं है';

  @override
  String get dataCloudNoIdentityToken => 'Google ने पहचान टोकन नहीं दिया';

  @override
  String get dataCloudSignInFailed => 'साइन इन नहीं हो सका';

  @override
  String get dataCloudSignInInterrupted => 'साइन इन बीच में रुक गया';

  @override
  String get dataCloudGoogleNotConfigured =>
      'इस ऐप के लिए Google कॉन्फ़िगर नहीं है';

  @override
  String get dataCloudGoogleSignInFailed => 'Google से साइन इन नहीं हो सका';

  @override
  String dataNewChaptersNotification(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count नए अध्याय आए हैं',
      one: 'एक नया अध्याय आया है',
    );
    return '$_temp0';
  }

  @override
  String get dataArchivePhoneFolderMissing => 'फ़ोन का फ़ोल्डर नहीं चुना गया।';

  @override
  String get dataArchiveDriveFolderMissing => 'Drive का फ़ोल्डर नहीं चुना गया।';

  @override
  String dataChapterLabel(String number) {
    return 'अध्याय $number';
  }

  @override
  String get dataLibraryMissing =>
      'फ़ोल्डर मौजूद नहीं है या पढ़ा नहीं जा सकता।';

  @override
  String get dataLibraryNotIndexed =>
      'फ़ोल्डर में library.json नहीं है: लाइब्रेरी लिखने वाले आर्काइवर से इंडेक्स फिर से बनवाने होंगे।';

  @override
  String get dataLibraryUnreadable =>
      'library.json पढ़ा नहीं जा सकता या वह मान्य MALF इंडेक्स नहीं है।';

  @override
  String get dataLibraryUnsupported =>
      'library.json इस ऐप से नए फ़ॉर्मेट वर्शन का इस्तेमाल करता है।';

  @override
  String get dataReaderModeContinuous => 'लगातार';

  @override
  String get dataReaderModePaged => 'पेज-दर-पेज';

  @override
  String get dataReaderDirectionLtr => 'बाएँ → दाएँ';

  @override
  String get dataReaderDirectionRtl => 'दाएँ → बाएँ';

  @override
  String get dataReaderFitWidth => 'चौड़ाई';

  @override
  String get dataReaderFitHeight => 'ऊँचाई';

  @override
  String get dataReaderFitOriginal => 'मूल';

  @override
  String get dataReaderBackgroundBlack => 'काला';

  @override
  String get dataReaderBackgroundGrey => 'स्लेटी';

  @override
  String get dataReaderBackgroundWhite => 'सफ़ेद';

  @override
  String readerProbeFrames(String frames, String budget) {
    return 'फ़्रेम $frames · सीमा $budget ms';
  }

  @override
  String readerProbeSlow(
    String build,
    String buildMax,
    String raster,
    String rasterMax,
  ) {
    return 'धीमे UI $build (अधिकतम $buildMax ms) · GPU $raster (अधिकतम $rasterMax ms)';
  }

  @override
  String readerProbeLate(String late, String lateMax) {
    return 'देर से शुरू $late (अधिकतम $lateMax ms)';
  }

  @override
  String readerProbeScroll(String scroll, String missed, String gap) {
    return 'स्क्रोल में $scroll · छूटे $missed (अधिकतम अंतराल $gap ms)';
  }

  @override
  String readerProbeSources(
    String tiles,
    String whole,
    String phone,
    String phoneMade,
  ) {
    return 'टाइल $tiles · पूरे $whole · फ़ोन के $phone (बने $phoneMade)';
  }

  @override
  String readerProbeNative(String bands, String textures, String decodes) {
    return 'नेटिव $bands (टेक्सचर $textures) · डिकोड किए पेज $decodes';
  }

  @override
  String readerProbeDecode(
    String decode,
    String decodeMax,
    String arrival,
    String arrivalMax,
  ) {
    return 'डिकोड $decode ms (अधिकतम $decodeMax) · आगमन $arrival ms (अधिकतम $arrivalMax)';
  }

  @override
  String readerProbeMemory(
    String copy,
    String gc,
    String gcMs,
    String blocking,
    String blockingMs,
  ) {
    return 'कॉपी अधिकतम $copy ms · GC Android $gc ($gcMs ms) · ब्लॉकिंग $blocking ($blockingMs ms)';
  }

  @override
  String readerProbeWaits(String drive, String fallbacks) {
    return 'Drive से इंतज़ार $drive · Dart फ़ॉलबैक $fallbacks';
  }

  @override
  String readerProbeJumps(String corrections, String jumps, String jumped) {
    return 'सुधार $corrections · छलाँगें $jumps ($jumped px)';
  }

  @override
  String get serverCheckDaily => 'नए अध्यायों की रोज़ाना जाँच';

  @override
  String serverCheckDailyAt(String clock) {
    return 'हर दिन $clock बजे, सर्वर के समय से';
  }

  @override
  String get serverCheckDailyOff =>
      'बंद: नए अध्याय सिर्फ़ हाथ से डाउनलोड होते हैं';

  @override
  String get serverCheckLibrary => 'Drive पर पूरी लाइब्रेरी';

  @override
  String get serverCheckLibraryOn =>
      'सिर्फ़ सर्वर ही नहीं, फ़ोन या दूसरों से डाउनलोड की गई सीरीज़ भी';

  @override
  String get serverCheckLibraryOff =>
      'सिर्फ़ सर्वर से डाउनलोड की गई चालू सीरीज़';

  @override
  String serverCheckLast(String when, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सीरीज़ में नए अध्याय',
      one: '1 सीरीज़ में नए अध्याय',
      zero: 'कोई नया अध्याय नहीं',
    );
    return 'पिछली जाँच $when: $_temp0';
  }

  @override
  String get serverCheckTimeHelp => 'जाँच का समय';
}
