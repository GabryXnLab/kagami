// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLanguageSystem => 'مثل النظام';

  @override
  String get seriesShelfNone => 'بلا حالة';

  @override
  String get seriesShelfPlanned => 'للقراءة';

  @override
  String get seriesShelfReading => 'قيد القراءة';

  @override
  String get seriesShelfPaused => 'متوقفة مؤقتًا';

  @override
  String get seriesShelfCompleted => 'مكتملة';

  @override
  String get seriesShelfDropped => 'متروكة';

  @override
  String get seriesReleaseOngoing => 'مستمرة';

  @override
  String get seriesReleaseCompleted => 'منتهية';

  @override
  String get seriesReleaseHiatus => 'متوقفة مؤقتًا';

  @override
  String get seriesReleaseCancelled => 'ملغاة';

  @override
  String get seriesReleaseUnknown => 'حالة غير معروفة';

  @override
  String get seriesNotFound => 'السلسلة غير موجودة.';

  @override
  String get seriesOfflineTitle => 'فصول على Drive';

  @override
  String get seriesOfflineMessage =>
      'بدون اتصال لا تظهر قائمة فصول هذه السلسلة. ستظهر تلقائيًا فور عودة الشبكة.';

  @override
  String get seriesNoIndexTitle => 'لا يوجد فهرس';

  @override
  String get seriesNoIndexMessage =>
      'هذه السلسلة لا تحتوي على index.json: يجب إعادة إنشاء الفهارس بواسطة المؤرشِف الذي كتبها.';

  @override
  String get seriesNoChaptersTitle => 'لا توجد فصول';

  @override
  String get seriesNoChaptersMessage =>
      'لا يوجد فصل يطابق البحث والمرشحات المختارة.';

  @override
  String seriesDownloadAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تنزيل $count فصل؟',
      many: 'تنزيل $count فصلًا؟',
      few: 'تنزيل $count فصول؟',
      two: 'تنزيل فصلين؟',
      one: 'تنزيل فصل واحد؟',
    );
    return '$_temp0';
  }

  @override
  String get seriesDownloadAllMessage =>
      'كل الفصول التي تُقرأ الآن من Drive ستُحفظ على الهاتف، ومن ثَمّ يمكن قراءتها حتى بدون شبكة.';

  @override
  String get seriesDownload => 'تنزيل';

  @override
  String seriesCleanupRemote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل مقروء ما زالت على Drive',
      many: '$count فصلًا مقروءًا ما زالت على Drive',
      few: '$count فصول مقروءة ما زالت على Drive',
      two: 'فصلان مقروءان ما زالا على Drive',
      one: 'فصل واحد مقروء ما زال على Drive',
    );
    return '$_temp0';
  }

  @override
  String seriesCleanupLocal(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل مقروء تشغل $size',
      many: '$count فصلًا مقروءًا تشغل $size',
      few: '$count فصول مقروءة تشغل $size',
      two: 'فصلان مقروءان يشغلان $size',
      one: 'فصل واحد مقروء يشغل $size',
    );
    return '$_temp0';
  }

  @override
  String seriesDownloadFailed(String error) {
    return 'فشل التنزيل: $error. أعد المحاولة';
  }

  @override
  String get seriesDownloadWaiting => 'بانتظار الشبكة: سيستأنف تلقائيًا. إلغاء';

  @override
  String get seriesDownloadQueued => 'في قائمة الانتظار. إلغاء';

  @override
  String get seriesDownloadCancel => 'إلغاء التنزيل';

  @override
  String get seriesPlaceLocal => 'على الهاتف';

  @override
  String get seriesPlaceDrive => 'على Drive';

  @override
  String get seriesPlaceMixed => 'الهاتف وDrive';

  @override
  String get seriesMuteTooltipOn => 'إشعارات الفصول الجديدة مكتومة';

  @override
  String get seriesMuteTooltipOff => 'إشعارات الفصول الجديدة مفعّلة';

  @override
  String get seriesMuteUnmuted => 'أُعيد تفعيل إشعارات الفصول الجديدة.';

  @override
  String get seriesMuteMuted => 'كُتمت إشعارات الفصول الجديدة.';

  @override
  String seriesCaughtUpMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أنت على اطلاع بكل ما على الهاتف: ينقص $count فصل معلن.',
      many: 'أنت على اطلاع بكل ما على الهاتف: ينقص $count فصلًا معلنًا.',
      few: 'أنت على اطلاع بكل ما على الهاتف: تنقص $count فصول معلنة.',
      two: 'أنت على اطلاع بكل ما على الهاتف: ينقص فصلان معلنان.',
      one: 'أنت على اطلاع بكل ما على الهاتف: ينقص فصل واحد معلن.',
    );
    return '$_temp0';
  }

  @override
  String get seriesCaughtUpAll => 'قرأتها كلها.';

  @override
  String get seriesResumeToContinue => 'للمتابعة';

  @override
  String get seriesResumeToStart => 'للبدء';

  @override
  String get seriesResumeHalfway => 'توقفت في المنتصف';

  @override
  String seriesResumePage(int page, int total) {
    return 'الصفحة $page من $total';
  }

  @override
  String get seriesContinue => 'متابعة';

  @override
  String get seriesStart => 'ابدأ';

  @override
  String get seriesResume => 'استئناف';

  @override
  String get seriesNextChapter => 'الفصل التالي';

  @override
  String get seriesFigureChapters => 'الفصول';

  @override
  String get seriesFigureRead => 'المقروءة';

  @override
  String get seriesFigureProgress => 'التقدم';

  @override
  String get seriesFigureRating => 'التقييم';

  @override
  String get seriesMyShelf => 'رفّي';

  @override
  String get seriesFavoriteOn => 'مفضلة';

  @override
  String get seriesFavoriteOff => 'المفضلة';

  @override
  String get seriesRatingButton => 'التقييم';

  @override
  String seriesRatingOutOfTen(int rating) {
    return '$rating/10';
  }

  @override
  String get seriesCollections => 'المجموعات';

  @override
  String get seriesNotes => 'ملاحظات';

  @override
  String get seriesRatingSheetTitle => 'كم تقيّمها؟';

  @override
  String get seriesNotesHint => 'أين توقفت، وما رأيك فيها…';

  @override
  String get seriesSave => 'حفظ';

  @override
  String get seriesRatingWord1 => 'سيئة جدًا';

  @override
  String get seriesRatingWord2 => 'سيئة';

  @override
  String get seriesRatingWord3 => 'ضعيفة';

  @override
  String get seriesRatingWord4 => 'متواضعة';

  @override
  String get seriesRatingWord5 => 'مقبولة';

  @override
  String get seriesRatingWord6 => 'لا بأس بها';

  @override
  String get seriesRatingWord7 => 'جيدة';

  @override
  String get seriesRatingWord8 => 'جيدة جدًا';

  @override
  String get seriesRatingWord9 => 'ممتازة';

  @override
  String get seriesRatingWord10 => 'تحفة';

  @override
  String get seriesRatingNone => 'بلا تقييم';

  @override
  String get seriesRatingHint => 'المس أو اسحب';

  @override
  String seriesRatingBefore(int rating) {
    return 'قبل: $rating';
  }

  @override
  String get seriesRatingRemove => 'إزالة';

  @override
  String get seriesRatingSave => 'حفظ التقييم';

  @override
  String get seriesSynopsis => 'الملخص';

  @override
  String get seriesGenres => 'الأنواع';

  @override
  String get seriesTags => 'الوسوم';

  @override
  String get seriesCreators => 'صنّاعها';

  @override
  String seriesMoreTags(int count) {
    return '$count أخرى';
  }

  @override
  String get seriesPaceToRead => 'للقراءة';

  @override
  String seriesPaceCaption(int chapters, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      chapters,
      locale: localeName,
      other: '$chapters فصل',
      many: '$chapters فصلًا',
      few: '$chapters فصول',
      two: 'فصلان',
      one: 'فصل واحد',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages لوحة',
      many: '$pages لوحة',
      few: '$pages لوحات',
      two: 'لوحتان',
      one: 'لوحة واحدة',
    );
    return '$_temp0، $_temp1';
  }

  @override
  String get seriesPaceNext => 'الفصل القادم';

  @override
  String get seriesPaceNextCaption => 'بحسب وتيرة الفصول الأخيرة';

  @override
  String seriesDurationMinutes(int count) {
    return '$count د';
  }

  @override
  String seriesDurationHours(int count) {
    return '$count س';
  }

  @override
  String seriesDurationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get seriesWhenLate => 'متأخر';

  @override
  String get seriesWhenExpected => 'متوقع';

  @override
  String get seriesWhenToday => 'اليوم';

  @override
  String get seriesWhenTomorrow => 'غدًا';

  @override
  String seriesWhenInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بعد $count يوم',
      many: 'بعد $count يومًا',
      few: 'بعد $count أيام',
      two: 'بعد يومين',
      one: 'بعد يوم',
    );
    return '$_temp0';
  }

  @override
  String seriesWhenInWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بعد $count أسبوع',
      many: 'بعد $count أسبوعًا',
      few: 'بعد $count أسابيع',
      two: 'بعد أسبوعين',
      one: 'بعد أسبوع',
    );
    return '$_temp0';
  }

  @override
  String get seriesShowLess => 'تقليص';

  @override
  String get seriesShowMore => 'قراءة المزيد';

  @override
  String get seriesChaptersTitle => 'الفصول';

  @override
  String seriesChaptersOf(int total) {
    return 'من $total';
  }

  @override
  String get seriesSearchChapter => 'ابحث عن فصل…';

  @override
  String get seriesSortNewest => 'من الأحدث';

  @override
  String get seriesSortOldest => 'من الأول';

  @override
  String get seriesMarkAll => 'تحديد الكل';

  @override
  String get seriesDownloadFromDrive => 'تنزيل من Drive';

  @override
  String get seriesFreeSpace => 'تحرير المساحة';

  @override
  String get seriesFilterUnread => 'للقراءة';

  @override
  String get seriesFilterDownloaded => 'المنزَّلة';

  @override
  String get seriesFilterAll => 'الكل';

  @override
  String seriesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محدد',
      many: '$count محددًا',
      few: '$count محددة',
      two: 'محددان',
      one: 'محدد واحد',
    );
    return '$_temp0';
  }

  @override
  String get seriesMarkReadMany => 'تحديد كمقروءة';

  @override
  String get seriesMarkUnread => 'تحديد كغير مقروء';

  @override
  String get seriesMarkRead => 'تحديد كمقروء';

  @override
  String get seriesMarkReadThrough => 'تحديد كمقروء حتى هنا';

  @override
  String get seriesSimilar => 'سلاسل مشابهة';

  @override
  String get seriesChapterNotDownloaded => 'غير منزَّل';

  @override
  String seriesChapterPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count لوحة',
      many: '$count لوحة',
      few: '$count لوحات',
      two: 'لوحتان',
      one: 'لوحة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get seriesDownloadToPhone => 'تنزيل على الهاتف';

  @override
  String get readerSeriesUnavailable => 'السلسلة غير متاحة.';

  @override
  String get readerNoPagesIndex =>
      'هذه السلسلة لا تحتوي على pages.json: يجب إعادة إنشاء الفهارس بواسطة المؤرشِف الذي كتبها.';

  @override
  String get readerSeriesOffline =>
      'بدون اتصال لا يمكن فتح هذه السلسلة: قائمة لوحاتها على Drive. ستُفتح فور عودة الشبكة.';

  @override
  String get readerChapterNotOnPhone =>
      'هذا الفصل ليس على الهاتف بعد. قد تكون المزامنة غير مكتملة: أعد المحاولة لاحقًا.';

  @override
  String get readerChapterNoPages => 'الفصل لا يحتوي على صفحات قابلة للقراءة.';

  @override
  String get readerPagesNotOnPhone =>
      'لوحات هذا الفصل ليست على الهاتف بعد. الفهرس يعلن عنها لكن الملفات لم تصل: على المجلد المتزامن أن يجلبها.';

  @override
  String get readerMarkEarlierTitle => 'تحديد الفصول السابقة كمقروءة؟';

  @override
  String readerMarkEarlierBody(int count, String chapter) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'أنهيت $chapter. الفصول السابقة وعددها $count ما زالت غير مقروءة: إن كنت قد قرأتها في مكان آخر، فحددها كمقروءة كلها معًا.',
      many:
          'أنهيت $chapter. الفصول السابقة وعددها $count ما زالت غير مقروءة: إن كنت قد قرأتها في مكان آخر، فحددها كمقروءة كلها معًا.',
      few:
          'أنهيت $chapter. الفصول السابقة وعددها $count ما زالت غير مقروءة: إن كنت قد قرأتها في مكان آخر، فحددها كمقروءة كلها معًا.',
      two:
          'أنهيت $chapter. الفصلان السابقان ما زالا غير مقروءين: إن كنت قد قرأتهما في مكان آخر، فحددهما كمقروءين معًا.',
      one:
          'أنهيت $chapter. الفصل السابق ما زال غير مقروء: إن كنت قد قرأته في مكان آخر، فحدده كمقروء.',
    );
    return '$_temp0';
  }

  @override
  String readerMarkEarlierConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تحديد الفصول الـ$count كمقروءة',
      many: 'تحديد الفصول الـ$count كمقروءة',
      few: 'تحديد الفصول الـ$count كمقروءة',
      two: 'تحديد الفصلين كمقروءين',
      one: 'تحديد السابق كمقروء',
    );
    return '$_temp0';
  }

  @override
  String get readerMarkEarlierDecline => 'اتركها للقراءة';

  @override
  String readerBookmarkAdded(int page) {
    return 'حُفظت الصفحة $page';
  }

  @override
  String get readerChapters => 'الفصول';

  @override
  String get readerBookmarks => 'الصفحات المحفوظة';

  @override
  String get readerNoBookmarks => 'لا توجد صفحات محفوظة';

  @override
  String get readerNoBookmarksHint =>
      'العلامة تحفظ موضع لوحة بعينها؛ أما موضع الفصل فتحفظه ميزة الاستئناف تلقائيًا.';

  @override
  String readerBookmarkPage(int page) {
    return 'الصفحة $page';
  }

  @override
  String get readerBookmarkRemove => 'إزالة';

  @override
  String get readerToTop => 'العودة إلى الأعلى';

  @override
  String get readerPageNotFromDrive => 'لم تصل اللوحة من Drive';

  @override
  String get readerPageUnreadable => 'لوحة غير قابلة للقراءة';

  @override
  String get readerPageNotSynced => 'لوحة غير متزامنة';

  @override
  String get readerPageNotDownloaded => 'لم تُنزَّل اللوحة بعد';

  @override
  String get readerPageOfflineHint =>
      'لا يوجد اتصال. ستصل تلقائيًا فور عودة الشبكة.';

  @override
  String get readerRetryNow => 'أعد المحاولة الآن';

  @override
  String get readerLastChapterOnPhone => 'هذا آخر فصل موجود على الهاتف.';

  @override
  String get readerNextChapter => 'الفصل التالي';

  @override
  String get readerContinue => 'متابعة';

  @override
  String get readerBookmarkThisPage => 'حفظ هذه الصفحة';

  @override
  String get readerHowToRead => 'طريقة القراءة';

  @override
  String get readerPreviousChapter => 'الفصل السابق';

  @override
  String get readerNextChapterTooltip => 'الفصل التالي';

  @override
  String get readerSearchChapter => 'ابحث عن فصل…';

  @override
  String get readerNewestFirst => 'من الأحدث';

  @override
  String get readerOldestFirst => 'من الأول';

  @override
  String readerReadingNow(String current, int total) {
    return 'قيد القراءة: $current / $total من الفصول';
  }

  @override
  String get readerMode => 'وضع القراءة';

  @override
  String get readerModeStrip => 'شريط';

  @override
  String get readerModePage => 'صفحة';

  @override
  String get readerDirection => 'اتجاه القراءة';

  @override
  String get readerDirectionLtr => 'يسار ← يمين';

  @override
  String get readerDirectionRtl => 'يمين ← يسار';

  @override
  String get readerFit => 'الملاءمة';

  @override
  String get readerBackground => 'الخلفية';

  @override
  String get readerBrightness => 'السطوع';

  @override
  String get readerAutoScroll => 'التمرير التلقائي';

  @override
  String get readerAutoScrollOff => 'متوقف';

  @override
  String readerAutoScrollRate(int rate) {
    return '$rate لوحة/د';
  }

  @override
  String get readerShowPageNumber => 'رقم الصفحة';

  @override
  String get readerShowProgress => 'شريط التقدم';

  @override
  String get readerShowScrollTop => 'زر العودة إلى الأعلى';

  @override
  String get readerKeepAwake => 'إبقاء الشاشة مضاءة';

  @override
  String get readerDoublePage => 'لوحتان متجاورتان';

  @override
  String get readerLockRotation => 'قفل التدوير';

  @override
  String get archiveTitle => 'تنزيل مانغا';

  @override
  String get archiveIntro =>
      'ابحث عن عنوان في المواقع المدعومة، أو الصق رابط سلسلة: ينزّلها Kagami من الموقع إلى المكتبة مع بياناتها الوصفية وغلافها وقائمة فصولها الكاملة.';

  @override
  String get archiveSearchHint => 'ابحث عن مانغا بالعنوان';

  @override
  String get archiveClear => 'مسح';

  @override
  String get archivePaste => 'لصق';

  @override
  String get archiveReading => 'جارٍ قراءة السلسلة…';

  @override
  String get archiveVerify => 'التحقق من السلسلة';

  @override
  String archiveSeriesSummary(String site, int count, String status) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل',
      many: '$count فصلًا',
      few: '$count فصول',
      two: 'فصلان',
      one: 'فصل واحد',
    );
    return '$site · $_temp0 · $status';
  }

  @override
  String archiveKnown(int archived, int total) {
    return 'موجودة في المكتبة: $archived من $total فصل. الفصول الموجودة تُتخطى.';
  }

  @override
  String get archiveWhatSection => 'ما الذي يُنزَّل';

  @override
  String get archiveModeAll => 'كلها';

  @override
  String get archiveModeFrom => 'من فصل';

  @override
  String get archiveModePick => 'مختارة';

  @override
  String get archiveModeAllHint =>
      'كل الفصول. إعادة التنزيل لاحقًا تجلب الجديدة أو التالفة فقط.';

  @override
  String get archiveModeFromHint =>
      'من الفصل المختار فصاعدًا: السابقة تبقى في قائمة السلسلة محددة كغير منزَّلة.';

  @override
  String get archiveModePickHint =>
      'الفصول التي تلمسها فقط. الباقي يبقى في القائمة غير منزَّل.';

  @override
  String get archiveChapterNumberHint => 'رقم الفصل كما في الموقع';

  @override
  String archivePickedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مختار',
      many: '$count مختارًا',
      few: '$count مختارة',
      two: 'اثنان مختاران',
      one: 'واحد مختار',
    );
    return '$_temp0';
  }

  @override
  String get archiveSelectAll => 'الكل';

  @override
  String get archiveSelectNone => 'لا شيء';

  @override
  String get archiveWhereSection => 'الوجهة';

  @override
  String get archiveWhereServer => 'الخادم';

  @override
  String get archiveWhereDrive => 'Drive';

  @override
  String get archiveWhereDriveAndPhone => 'Drive والهاتف';

  @override
  String get archiveWherePhone => 'الهاتف';

  @override
  String get archiveWhereDriveHint =>
      'في مجلد المكتبة على Drive. تمر اللوحات عبر الهاتف وتُحذف منه فور استلام Drive لها: تُقرأ بالبث، أو تُنزَّل لاحقًا.';

  @override
  String get archiveWhereDriveAndPhoneHint =>
      'في مجلد المكتبة على Drive، وتبقى الفصول أيضًا على الهاتف لقراءتها بدون شبكة.';

  @override
  String get archiveWherePhoneHint =>
      'على الهاتف، في مجلد المانغا أو في مساحة التطبيق. عند ربط Drive يمكن التنزيل إليه مباشرة.';

  @override
  String archiveServerHint(String name, String folder, String other) {
    String _temp0 = intl.Intl.selectLogic(other, {
      'other': ' تنبيه: ليس هذا المجلد الذي يقرأه التطبيق.',
      'same': '',
    });
    return 'ينزّلها «$name» ويرفعها إلى «$folder» على Drive، حتى والهاتف مغلق. السلاسل المستمرة يتابعها الخادم.$_temp0';
  }

  @override
  String get archiveDelaySection => 'فاصل بين الطلبات';

  @override
  String get archiveDelayNone => 'بلا فاصل';

  @override
  String archiveDelaySeconds(String seconds) {
    return '$seconds ث';
  }

  @override
  String get archiveDelayHint =>
      'المواقع لا تحب التنزيل المتتابع السريع: فاصل قصير يجنّبك الحظر.';

  @override
  String get archiveDownloadAll => 'تنزيل السلسلة كاملة';

  @override
  String get archiveDownloadFrom => 'تنزيل من الفصل المختار';

  @override
  String archiveDownloadPicked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تنزيل $count فصل',
      many: 'تنزيل $count فصلًا',
      few: 'تنزيل $count فصول',
      two: 'تنزيل فصلين',
      one: 'تنزيل فصل واحد',
    );
    return '$_temp0';
  }

  @override
  String archiveNoResults(String site) {
    return 'لا توجد نتائج في $site.';
  }

  @override
  String archiveChaptersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل',
      many: '$count فصلًا',
      few: '$count فصول',
      two: 'فصلان',
      one: 'فصل واحد',
    );
    return '$_temp0';
  }

  @override
  String archiveVerifySite(String site) {
    return 'التحقق من $site';
  }

  @override
  String get archiveVerifySiteHint =>
      'يريد الموقع التأكد أنك إنسان: المس لفتح التحقق، ثم يُبحث هناك أيضًا';

  @override
  String get archiveStatusOngoing => 'مستمرة';

  @override
  String get archiveStatusCompleted => 'منتهية';

  @override
  String get archiveStatusHiatus => 'متوقفة مؤقتًا';

  @override
  String get archiveStatusCancelled => 'ملغاة';

  @override
  String get archiveStatusUnknown => 'حالة غير معروفة';

  @override
  String get archiveErrChallenge => 'يطلب الموقع تحققًا لا يمكن إجراؤه من هنا.';

  @override
  String get archiveErrOffline => 'لا يوجد اتصال: الموقع لا يستجيب.';

  @override
  String get archiveErrVerifyIncomplete => 'لم يكتمل التحقق من الموقع.';

  @override
  String archiveQueuedSnack(String title) {
    return '«$title» في قائمة الانتظار. ويستمر حتى والشاشة مطفأة.';
  }

  @override
  String archiveQueuedServerSnack(String title, String server) {
    return '«$title» في قائمة الانتظار على «$server». يمكن للهاتف أن ينطفئ.';
  }

  @override
  String get archiveServerFallbackName => 'الخادم';

  @override
  String get archiveDownloads => 'التنزيلات';

  @override
  String get archiveClearHistory => 'تنظيف';

  @override
  String get archiveQueueStopped => 'قائمة الانتظار متوقفة';

  @override
  String get archiveQueueResumeHint => 'تستأنف تلقائيًا؛ المسها لتبدأ الآن';

  @override
  String archiveJobAutomatic(String destination) {
    return 'فصول جديدة · $destination';
  }

  @override
  String archiveJobQueued(String destination) {
    return 'في قائمة الانتظار · $destination';
  }

  @override
  String get archiveRemoveFromQueue => 'إزالة من قائمة الانتظار';

  @override
  String archiveHistoryLine(String when, String message) {
    return '$when · $message';
  }

  @override
  String get archiveSites => 'المواقع المدعومة';

  @override
  String get archiveMoreSites =>
      'مواقع أخرى قادمة: سيصل دعم مزوّدين جدد مع التحديثات القادمة.';

  @override
  String archiveLinkCopied(String url) {
    return 'نُسخ $url إلى الحافظة.';
  }

  @override
  String get archiveTracked => 'سلاسل مستمرة';

  @override
  String get archiveTrackedIntro =>
      'السلاسل المستمرة المنزَّلة من هنا تُفحص من جديد: تصل الفصول الجديدة فقط، إلى الوجهة نفسها. أما سلاسل الخادم فيتابعها الخادم.';

  @override
  String get archiveCheckDaily => 'فحص كل يوم';

  @override
  String get archiveCheckManual => 'يدويًا فقط';

  @override
  String archiveCheckAt(String time) {
    return 'عند $time، حتى والتطبيق مغلق';
  }

  @override
  String get archiveCheckTime => 'الوقت';

  @override
  String get archiveCheckTimeHelp => 'وقت الفحص';

  @override
  String get archiveWifiOnly => 'عبر Wi-Fi فقط';

  @override
  String get archiveWifiOnlyOn => 'ينتظر شبكة لا تُحاسَب بحسب الاستهلاك';

  @override
  String get archiveWifiOnlyOff => 'حتى مع بيانات الجوال';

  @override
  String get archiveCheckNow => 'افحص الآن';

  @override
  String get archiveNoTracked => 'لا توجد سلاسل للمتابعة حاليًا';

  @override
  String archiveTrackedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سلسلة للمتابعة',
      many: '$count سلسلة للمتابعة',
      few: '$count سلاسل للمتابعة',
      two: 'سلسلتان للمتابعة',
      one: 'سلسلة واحدة للمتابعة',
    );
    return '$_temp0';
  }

  @override
  String archiveTrackedLine(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل معروف',
      many: '$count فصلًا معروفًا',
      few: '$count فصول معروفة',
      two: 'فصلان معروفان',
      one: 'فصل واحد معروف',
    );
    return '$_temp0 · $destination';
  }

  @override
  String archiveTrackedLineChecked(int count, String destination, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل معروف',
      many: '$count فصلًا معروفًا',
      few: '$count فصول معروفة',
      two: 'فصلان معروفان',
      one: 'فصل واحد معروف',
    );
    return '$_temp0 · $destination · فُحصت $when';
  }

  @override
  String get archiveStopFollowing => 'إيقاف المتابعة';

  @override
  String archiveCheckQueued(String names) {
    return 'فصول جديدة لـ$names';
  }

  @override
  String archiveCheckRemoved(String names) {
    return '$names منتهية الآن';
  }

  @override
  String archiveCheckFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تعذّر الوصول إلى $count منها',
      many: 'تعذّر الوصول إلى $count منها',
      few: 'تعذّر الوصول إلى $count منها',
      two: 'تعذّر الوصول إلى اثنتين',
      one: 'تعذّر الوصول إلى واحدة',
    );
    return '$_temp0';
  }

  @override
  String get archiveCheckSeparator => '؛ ';

  @override
  String archiveCheckReport(String parts) {
    return '$parts.';
  }

  @override
  String get archiveNoNewChapters => 'لا توجد فصول جديدة.';

  @override
  String get archiveNoConnection => 'لا يوجد اتصال.';

  @override
  String get archiveForgetTitle => 'إيقاف المتابعة؟';

  @override
  String archiveForgetBody(String title) {
    return 'لن تصل فصول «$title» الجديدة تلقائيًا بعد الآن. أما المنزَّلة فتبقى.';
  }

  @override
  String get archiveCancel => 'إلغاء';

  @override
  String get archiveForgetConfirm => 'إيقاف';

  @override
  String archiveStartIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل.',
      many: '$count فصلًا.',
      few: '$count فصول.',
      two: 'فصلان.',
      one: 'فصل واحد.',
    );
    return '$_temp0 نزّل الكل أو اختر الفصل الذي تبدأ منه: السابقة تبقى في القائمة داخل القارئ، بلا لوحات.';
  }

  @override
  String get archiveStartNoMatch => 'لا يوجد فصل بهذا الرقم.';

  @override
  String archiveStartFrom(String title, int remaining) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: '$remaining فصل',
      many: '$remaining فصلًا',
      few: '$remaining فصول',
      two: 'فصلان',
      one: 'فصل واحد',
    );
    return 'من «$title» فصاعدًا: $_temp0.';
  }

  @override
  String get archiveStartNone => 'لم يُختر أي فصل: يمكن تنزيل الكل.';

  @override
  String get archiveStartAll => 'تنزيل الكل';

  @override
  String get archiveStartHere => 'من هنا';

  @override
  String get browserTitle => 'التحقق من الموقع';

  @override
  String get browserPhoneOnly => 'التحقق ممكن من الهاتف فقط.';

  @override
  String get browserInstructionsChapters =>
      'يريد الموقع التأكد أنك إنسان. أكمل التحقق: عندما تظهر قائمة الفصول، يلاحظ Kagami ذلك ويعود تلقائيًا.';

  @override
  String get browserInstructionsSearch =>
      'يريد الموقع التأكد أنك إنسان. أكمل التحقق: عندما يظهر بحث الموقع، يلاحظ Kagami ذلك ويعود تلقائيًا.';

  @override
  String get browserSearchPhoneOnly =>
      'البحث في هذا الموقع ممكن من الهاتف فقط.';

  @override
  String get browserSearchSuperseded => 'حلّ محلها بحث أحدث.';

  @override
  String get browserResponseTooLarge => 'الاستجابة كبيرة جدًا.';

  @override
  String get serverTitle => 'الخادم';

  @override
  String get serverClear => 'تنظيف';

  @override
  String get serverUnavailableNoSecret =>
      'لا يمكن لهذه النسخة من التطبيق ربط خوادم: من بناها لم يحدد سرّ عميل الويب (GOOGLE_SERVER_CLIENT_SECRET).';

  @override
  String get serverUnavailableAndroidOnly => 'ربط خادم ممكن من Android فقط.';

  @override
  String get serverSignInRequired =>
      'سجّل الدخول بحساب Google لاستخدام الخادم.';

  @override
  String get serverNoConnection => 'لا يوجد اتصال.';

  @override
  String get serverMissingGoogleServices =>
      'الملف google-services.json مفقود: هذه النسخة لا تحتوي على عميل Google.';

  @override
  String get serverDriveAccessDenied =>
      'لم تمنح Google صلاحية الوصول إلى Drive.';

  @override
  String get serverGoogleNotResponding =>
      'Google لا تستجيب: أعد المحاولة بعد قليل.';

  @override
  String serverWhenToday(String clock) {
    return 'اليوم عند $clock';
  }

  @override
  String serverWhenDate(String date, String clock) {
    return '$date عند $clock';
  }

  @override
  String serverProgressStats(int pages, String size, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: ' · $skipped سليمة مسبقًا',
      zero: '',
    );
    return '$pages لوحة جديدة · $size$_temp0';
  }

  @override
  String get serverRemoveFromQueue => 'إزالة من قائمة الانتظار';

  @override
  String get serverNoFirebase =>
      'يتعرف الخادم على مستخدميه من حساب Google، وهو غير موجود في هذه النسخة من التطبيق.';

  @override
  String get serverSignedOutIntro =>
      'يمكن لحاسوب يعمل دائمًا أن ينزّل ويرفع إلى Drive الخاص بك بدلًا من الهاتف، الذي يمكنه أن ينطفئ في الأثناء. يتعرف عليك الخادم من حساب Google الخاص بك.';

  @override
  String get serverSignIn => 'تسجيل الدخول بحساب Google';

  @override
  String get serverSignInSubtitle => 'لإنشاء خادمك أو استخدام خادم شخص آخر';

  @override
  String serverInviteTitle(String sender, String serverName) {
    return 'منحك $sender حق الوصول إلى «$serverName»';
  }

  @override
  String get serverInviteSubtitle =>
      'ينزّل إلى Drive الخاص بك، حتى والهاتف مغلق. المس للربط';

  @override
  String get serverIgnore => 'تجاهل';

  @override
  String get serverLinkIntro =>
      'يمكن لحاسوب يعمل دائمًا، حاسوبك أو حاسوب من منحك الوصول، أن ينزّل ويرفع إلى Drive الخاص بك بدلًا من الهاتف، الذي يمكنه أن ينطفئ في الأثناء.';

  @override
  String get serverCreate => 'أنشئ خادمك';

  @override
  String get serverCreateSubtitle =>
      'أمر تلصقه على حاسوب عليه Docker: لا شيء يحتاج إلى إعداد';

  @override
  String get serverLinkTitle => 'ربط خادم';

  @override
  String get serverLinkSubtitle => 'خادمك العامل، أو خادم من أضافك';

  @override
  String get serverStateConnecting => 'جارٍ الربط…';

  @override
  String get serverStateNoGrant => 'لم يحصل بعد على صلاحية Drive الخاص بك';

  @override
  String get serverStateNoFolder =>
      'لا يعرف بعد في أي مجلد من Drive الخاص بك يكتب';

  @override
  String serverStateReady(String folder) {
    return 'جاهز · يكتب في «$folder» على Drive الخاص بك';
  }

  @override
  String serverTileSubtitle(String address, String state) {
    return '$address · $state';
  }

  @override
  String serverTileSubtitleOwner(String address, String owner, String state) {
    return '$address · لدى $owner · $state';
  }

  @override
  String get serverPlainTitle => 'الاتصال غير مشفّر';

  @override
  String get serverPlainSubtitle =>
      'يمكن قراءة رمز حسابك أثناء انتقاله: يلزم HTTPS (Tailscale Funnel، أو وكيل عكسي)';

  @override
  String get serverGrantTitle => 'امنح الخادم Drive الخاص بك';

  @override
  String get serverGrantSubtitle =>
      'سينزّل في المجلد الذي يقرأه التطبيق، حتى والهاتف مغلق';

  @override
  String get serverUseAppFolder => 'استخدام مجلد التطبيق';

  @override
  String serverUseAppFolderSubtitle(String serverFolder, String appFolder) {
    return 'الخادم يكتب في «$serverFolder» والتطبيق يقرأ «$appFolder»';
  }

  @override
  String get serverUsersTitle => 'من يمكنه استخدامه';

  @override
  String get serverUsersOnlyYou => 'أنت فقط. أضف حساب Google لمن تريد';

  @override
  String serverUsersCount(int count) {
    return 'عدد الحسابات: $count، بما فيها حسابك';
  }

  @override
  String get serverQueueWaiting => 'قائمة الانتظار في الانتظار';

  @override
  String get serverQueueRestarts => 'يستأنف الخادم تلقائيًا';

  @override
  String get serverJobAutomatic => 'فصول جديدة · على الخادم';

  @override
  String get serverJobQueued => 'في قائمة الانتظار · على الخادم';

  @override
  String get serverOngoingTitle => 'سلاسل مستمرة على الخادم';

  @override
  String serverOngoingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count للمتابعة',
      zero: 'لا شيء حاليًا',
    );
    return '$_temp0';
  }

  @override
  String get serverOngoingCheckOff => 'الفحص متوقف';

  @override
  String serverOngoingCheckAt(String clock) {
    return 'الفحص عند $clock';
  }

  @override
  String serverOngoingSubtitle(String count, String check) {
    return '$count · $check. المس للفحص الآن';
  }

  @override
  String serverSeriesKnown(int count) {
    return 'الفصول المعروفة: $count';
  }

  @override
  String serverSeriesKnownChecked(int count, String when) {
    return 'الفصول المعروفة: $count · فُحصت $when';
  }

  @override
  String get serverStopFollowing => 'إيقاف المتابعة';

  @override
  String get serverInviteRemoveFailed => 'تعذّرت إزالة الدعوة: أعد المحاولة.';

  @override
  String get serverCheckingNow =>
      'الخادم يفحص الآن: الفصول الجديدة تظهر في قائمة انتظاره.';

  @override
  String get serverPaste => 'لصق';

  @override
  String get serverAddressExposed =>
      'تنبيه: على عنوان عام وبدون تشفير يمكن قراءة رمز حسابك أثناء انتقاله. استخدم HTTPS (Tailscale Funnel، أو وكيلًا عكسيًا) أو Tailscale.';

  @override
  String get serverAddressSavedNote =>
      'ينتقل العنوان مع النسخة الاحتياطية ومع الحساب، مثل مجلد Drive.';

  @override
  String get serverAddressMissing =>
      'اكتب عنوان الخادم، مثل http://192.168.1.20:8080.';

  @override
  String serverLinked(String name, String folder) {
    return 'رُبط بـ«$name»: ينزّل في «$folder» على Drive الخاص بك.';
  }

  @override
  String serverLinkFromInvite(String sender, String serverName) {
    return 'أضافك $sender إلى «$serverName». عند الربط، سينزّل الخادم المانغا التي تختارها في مجلد مكتبتك على Drive الخاص بك: ستطلب منك Google السماح له بالكتابة فيه. وسيتمكن من يدير الخادم من استخدام هذه الصلاحية.';
  }

  @override
  String serverLinkLinked(String account) {
    return 'يتعرف عليك الخادم بوصفك $account. عند فك الربط، إن لم يكن خادمك، ينسى أيضًا صلاحية Drive الخاص بك وقائمة انتظارك.';
  }

  @override
  String get serverSignedInAccount => 'الحساب الذي سجّلت الدخول به';

  @override
  String get serverLinkNew =>
      'اكتب عنوان الخادم: خادمك، أو الذي أعطاك إياه من أضافك. يتعرف عليك الخادم من حساب Google، وفي المرة الأولى تمنحه صلاحية الكتابة في مجلد مكتبتك على Drive.';

  @override
  String get serverVerifying => 'جارٍ التحقق…';

  @override
  String get serverVerifyAgain => 'تحقق مرة أخرى';

  @override
  String get serverVerifyAndLink => 'تحقق واربط';

  @override
  String get serverUnlink => 'فك الربط';

  @override
  String get serverDefaultNameOwn => 'خادم Kagami الخاص بي';

  @override
  String serverDefaultNameOf(String name) {
    return 'خادم $name';
  }

  @override
  String get serverCommandCopied => 'نُسخ الأمر.';

  @override
  String get serverComputerAddressMissing =>
      'اكتب عنوان الحاسوب، مثل http://192.168.1.20:8080.';

  @override
  String serverNotOwner(String owner) {
    return 'هذا الخادم يخص $owner: هو مربوط، لكنك لم تنشئه.';
  }

  @override
  String serverReady(String name) {
    return '«$name» جاهز. أضف من تريد من «من يمكنه استخدامه».';
  }

  @override
  String get serverLibraryFolderFallback => 'مجلد المكتبة';

  @override
  String serverSetupIntro(String folder) {
    return 'يلزم حاسوب يبقى يعمل، مثل حاسوب مصغّر أو NAS أو Raspberry Pi أو خادم في الشبكة، وعليه Docker. ينزّل الخادم المانغا ويرفعها إلى Drive الخاص بك، في «$folder»، حتى والهاتف مغلق.';
  }

  @override
  String serverPrepareIntro(String signIn, String folder) {
    String _temp0 = intl.Intl.selectLogic(signIn, {
      'yes': 'سجّل الدخول أولًا بحساب Google، ثم ',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(folder, {
      'yes': 'اختر مجلد المانغا على Drive، ثم ',
      'other': '',
    });
    return 'سأُعدّ أمرًا يحتوي على كل شيء: $_temp0$_temp1ستطلب منك Google السماح للخادم بالكتابة على Drive الخاص بك.';
  }

  @override
  String get serverPreparing => 'جارٍ الإعداد…';

  @override
  String get serverGenerate => 'إنشاء الأمر';

  @override
  String get serverStep1 =>
      'ثبّت Docker على الحاسوب (docker.com) إن لم يكن موجودًا.';

  @override
  String get serverStep2 =>
      'الصق هذه الأوامر في طرفيته: الأول يشغّل الخادم، والثاني يبقيه محدّثًا تلقائيًا. تحتوي على صلاحية Drive الخاص بك: لا ترسلها لأحد.';

  @override
  String get serverCopyCommand => 'نسخ الأمر';

  @override
  String get serverStep3 =>
      'اكتب هنا عنوان الحاسوب: في المنزل عنوان الشبكة المحلية؛ ومن الخارج اسمه في Tailscale أو عنوان HTTPS الذي تعرضه به.';

  @override
  String get serverPortNote => 'يستجيب الخادم على المنفذ 8080.';

  @override
  String get serverUsersIntro =>
      'أضف حساب Google لمن تريد. ستظهر الدعوة في تطبيق Kagami لديه: عند ربط الخادم، ستذهب تنزيلاته إلى Drive الخاص به، بقائمة انتظاره الخاصة.';

  @override
  String get serverUserEmailInvalid =>
      'اكتب عنوان حساب Google، مثل name@gmail.com.';

  @override
  String serverUserAdded(String email) {
    return 'يمكن لـ$email استخدام الخادم: يُخبره تطبيقه بذلك.';
  }

  @override
  String serverRemoveTitle(String email) {
    return 'إزالة $email؟';
  }

  @override
  String get serverRemoveBody =>
      'لن يتمكن من استخدام الخادم بعد الآن. تُحذف قائمة انتظاره وصلاحية Drive الخاص به؛ وما هو موجود على Drive الخاص به يبقى.';

  @override
  String get serverCancel => 'إلغاء';

  @override
  String get serverRemove => 'إزالة';

  @override
  String get serverAdd => 'إضافة';

  @override
  String get serverOwnerYou => 'أنت، المالك';

  @override
  String get serverConnected => 'ربط الخادم';

  @override
  String get serverInvitedPending => 'مدعو، لم يربط الخادم بعد';

  @override
  String get setupIntro =>
      'يقرأ مجلد المانغا الذي تضعه المزامنة على الهاتف، أو المكتبة نفسها مباشرة من Google Drive، دون جلبها كلها إلى هنا.';

  @override
  String get setupAccessTitle => 'الوصول إلى الملفات';

  @override
  String get setupAccessBody =>
      'المجلد خارج المساحة الخاصة بالتطبيق، ويحتوي على عشرات الآلاف من الصور: يحتاج Kagami إلى قراءتها مباشرة. ولا يكتب إلا نسخ البيانات في المجلد الفرعي reading/ من المكتبة، وإن طلبت، الفصول التي تنزّلها من Drive.';

  @override
  String get setupGrantAccess => 'منح الوصول';

  @override
  String get setupFolderTitle => 'المجلد';

  @override
  String get setupFolderBody =>
      'حدّد المجلد الذي تزامنه FolderSync: الذي يحتوي على library.json ومجلد فرعي لكل سلسلة.';

  @override
  String get setupChooseFolder => 'اختر المجلد';

  @override
  String get setupOr => 'أو';

  @override
  String get setupDriveTitle => 'Google Drive';

  @override
  String get setupDriveBody =>
      'تسجّل الدخول بحساب Google وتختار مجلد المكتبة على Drive: تصل اللوحات أثناء القراءة، والفصول التي تريدها دائمًا في متناولك تُنزَّل بلمسة. لا حاجة إلى الوصول إلى ملفات الهاتف.';

  @override
  String get setupReadFromDrive => 'القراءة من Google Drive';

  @override
  String get setupLibraryProblemTitle => 'المكتبة غير قابلة للقراءة';

  @override
  String get setupChangeFolder => 'تغيير المجلد';

  @override
  String get driveFolderSheetTitle => 'مجلد على Drive';

  @override
  String get driveDestinationTitle => 'أين أحفظ المانغا؟';

  @override
  String get driveDestinationBody =>
      'لا يوجد مجلد للمانغا على الهاتف. في المجلد تبقى الفصول المنزَّلة حتى لو حُذف التطبيق، ويقرؤها Kagami مع الموجودة أصلًا. أما في مساحة التطبيق فلا حاجة إلى أي صلاحية، لكنها تذهب معه.';

  @override
  String get driveChooseFolder => 'اختر مجلدًا';

  @override
  String get driveInAppSpace => 'في مساحة التطبيق';

  @override
  String get driveMyDrive => 'Drive الخاص بي';

  @override
  String get driveSharedWithMe => 'مشاركة معي';

  @override
  String get driveBack => 'رجوع';

  @override
  String get driveNoResponse => 'Drive لا يستجيب';

  @override
  String get driveRetry => 'أعد المحاولة';

  @override
  String get driveIsLibrary => 'يحتوي على library.json: إنه مكتبة';

  @override
  String get driveNotLibrary =>
      'لا يحتوي على library.json: المكتبة هي المجلد الذي يحتوي عليه';

  @override
  String get driveUseFolder => 'استخدام هذا المجلد';

  @override
  String get driveNoFolders => 'لا توجد مجلدات هنا';

  @override
  String get driveNoticeAuthRequired =>
      'لا يملك Kagami بعد صلاحية قراءة Google Drive';

  @override
  String get driveAuthorize => 'تفويض';

  @override
  String get driveSignIn => 'تسجيل الدخول';

  @override
  String get driveNoticeOffline =>
      'أنت غير متصل: تُقرأ الفصول الموجودة على الهاتف ولوحات Drive المنزَّلة سابقًا. والباقي يعود تلقائيًا مع الشبكة';

  @override
  String driveNoticeError(String message) {
    return 'Drive: $message. يظهر ما هو موجود على الهاتف';
  }

  @override
  String get syncSummaryOff => 'متوقفة';

  @override
  String get syncSummaryDownload => 'من Drive إلى الهاتف';

  @override
  String get syncSummaryUpload => 'من الهاتف إلى Drive';

  @override
  String get syncSummaryBoth => 'في الاتجاهين';

  @override
  String syncSummaryManual(String direction) {
    return '$direction، يدويًا';
  }

  @override
  String syncSummaryDaily(String direction, String time) {
    return '$direction، كل يوم عند $time';
  }

  @override
  String get syncTitle => 'المزامنة';

  @override
  String get syncIntro =>
      'تُبقي مجلد المانغا على الهاتف ومجلد Drive متطابقين، دون FolderSync. إن كنت ما زلت تستخدمه على هذا المجلد، فأوقفه: مزامنتان على الملفات نفسها تتعارضان.';

  @override
  String get syncFolders => 'المجلدات';

  @override
  String get syncOnPhone => 'على الهاتف';

  @override
  String get syncNoFolderChosen => 'لم يُختر أي مجلد';

  @override
  String get syncOnDrive => 'على Drive';

  @override
  String get syncDriveNotConnected => 'Drive غير مربوط';

  @override
  String get syncDirection => 'الاتجاه';

  @override
  String get syncDirectionOff => 'متوقفة';

  @override
  String get syncDirectionFromDrive => 'من Drive';

  @override
  String get syncDirectionToDrive => 'إلى Drive';

  @override
  String get syncDirectionBoth => 'الاثنان';

  @override
  String get syncDescOff =>
      'لا يتحرك شيء تلقائيًا. مكتبة Drive تُقرأ كالمعتاد، و«تنزيل» يعمل كما دائمًا.';

  @override
  String get syncDescDownload =>
      'ما يصل إلى Drive ينزل إلى الهاتف. ولا يصعد شيء من الهاتف.';

  @override
  String get syncDescUpload =>
      'ما هو على الهاتف يصعد إلى Drive، مثل نسخ البيانات في reading/backup. أما فهارس المكتبة فتبقى كما هي من الخادم.';

  @override
  String get syncDescBoth =>
      'ما يتغير في طرف يصل إلى الآخر؛ وإن تغيّر في الطرفين يفوز الأحدث. فهارس المكتبة تنزل فقط: فهي من الخادم.';

  @override
  String get syncDeletions => 'نشر عمليات الحذف';

  @override
  String get syncDeletionsDownload => 'يحذف من الهاتف ما يختفي من Drive';

  @override
  String get syncDeletionsUpload => 'ينقل إلى سلة Drive ما تحذفه من الهاتف';

  @override
  String get syncDeletionsBoth => 'من طرف إلى آخر؛ ومن Drive إلى السلة فقط';

  @override
  String get syncDeletionsOnNote =>
      '«تحرير المساحة» يحذف الفصول المقروءة من Drive أيضًا، في الجولة التالية.';

  @override
  String get syncDeletionsOffNote =>
      'الملف المحذوف من طرف يبقى في الآخر ولا يعود: «تحرير المساحة» يُخلي الهاتف ويترك الفصول على Drive.';

  @override
  String get syncDaily => 'كل يوم';

  @override
  String get syncScheduled => 'مزامنة مجدولة';

  @override
  String get syncManualOnly => 'يدويًا فقط';

  @override
  String syncAtTime(String time) {
    return 'عند $time، حتى والتطبيق مغلق';
  }

  @override
  String get syncTime => 'الوقت';

  @override
  String get syncWifiOnly => 'عبر Wi-Fi فقط';

  @override
  String get syncWifiOnlyOn => 'ينتظر شبكة لا تُحاسَب بحسب الاستهلاك';

  @override
  String get syncWifiOnlyOff => 'حتى مع بيانات الجوال';

  @override
  String get syncScheduleNote =>
      'يحدد Android اللحظة الدقيقة: إن لم تتوفر شبكة في الوقت المختار، تبدأ الجولة فور عودتها.';

  @override
  String get syncNow => 'الآن';

  @override
  String get syncTimePickerHelp => 'وقت المزامنة';

  @override
  String get syncRunNow => 'زامن الآن';

  @override
  String get syncRunNowReady => 'يمكنك متابعة القراءة: النسخ يستمر تلقائيًا';

  @override
  String get syncRunNowNotReady => 'يلزم مجلد الهاتف ومجلد Drive';

  @override
  String get syncPhaseListing => 'أنظر ما الموجود على Drive…';

  @override
  String get syncPhaseComparing => 'أقارن مع الهاتف…';

  @override
  String get syncPhaseNothing => 'لا شيء للنسخ';

  @override
  String syncPhaseFiles(int done, int total) {
    return 'الملف $done من $total';
  }

  @override
  String get syncStop => 'إيقاف';

  @override
  String get syncNever => 'لم تُجرَ مزامنة قط';

  @override
  String get syncNeverNote =>
      'الجولة الأولى على مجلد ممتلئ سريعة: الملفات المتطابقة تُعرف من حجمها';

  @override
  String syncLastScheduled(String date, String time) {
    return 'الأخيرة، مجدولة: $date عند $time';
  }

  @override
  String syncLastManual(String date, String time) {
    return 'الأخيرة، يدوية: $date عند $time';
  }

  @override
  String syncOutcomeDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منزَّل: $count',
      one: 'منزَّل: $count',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeUploaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مرفوع: $count',
      one: 'مرفوع: $count',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeDeletedLocal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'محذوف من الهاتف: $count',
      one: 'محذوف من الهاتف: $count',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeTrashed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'في سلة Drive: $count',
      one: 'في سلة Drive: $count',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فشل: $count، ستُعاد المحاولة',
      one: 'فشل: $count، ستُعاد المحاولة',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeErrorSoFar(String error, String done) {
    return '$error. حتى تلك اللحظة: $done';
  }

  @override
  String get syncOutcomeAligned => 'كان كل شيء متطابقًا أصلًا';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsThemeDark => 'داكن';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeSystem => 'مثل النظام';

  @override
  String get settingsLibrary => 'المكتبة';

  @override
  String get settingsFolder => 'المجلد';

  @override
  String get settingsNoFolder => 'لم يُختر أي مجلد';

  @override
  String get settingsReloadIndexes => 'إعادة قراءة الفهارس';

  @override
  String get settingsReloadIndexesNote =>
      'افعل ذلك عندما تجلب المزامنة مواد جديدة للتو';

  @override
  String get settingsIndexesReloaded => 'أُعيدت قراءة الفهارس';

  @override
  String get settingsGoogleDrive => 'Google Drive';

  @override
  String get settingsReading => 'القراءة';

  @override
  String get settingsAccount => 'الحساب';

  @override
  String get settingsData => 'البيانات';

  @override
  String get settingsAbout => 'حول';

  @override
  String get settingsTheme => 'السمة';

  @override
  String get settingsLibraryNote => 'المجلد والفهارس وGoogle Drive';

  @override
  String get settingsLibraryNoteLocal => 'المجلد والفهارس';

  @override
  String get settingsReadingNote => 'الوضع الافتراضي وقياسات القارئ';

  @override
  String get settingsAccountNote => 'تسجيل الدخول بحساب Google والمزامنة';

  @override
  String get settingsDataNote => 'النسخ الاحتياطي والاستعادة والحذف';

  @override
  String get settingsAutoBackup => 'نسخ تلقائي في المكتبة';

  @override
  String get settingsAutoBackupNote =>
      'مرة في اليوم في reading/backup/، وتنقله المزامنة إلى Drive مع المانغا';

  @override
  String get settingsExport => 'تصدير البيانات';

  @override
  String get settingsExportNote =>
      'الحالة والتقييمات والسجل والمجموعات والعلامات في ملف واحد';

  @override
  String get settingsExportDialog => 'أين تحفظ النسخة الاحتياطية';

  @override
  String get settingsExportCancelled => 'أُلغي التصدير';

  @override
  String get settingsExportSaved => 'حُفظت النسخة الاحتياطية';

  @override
  String get settingsImport => 'استيراد من نسخة احتياطية';

  @override
  String get settingsImportNote => 'يعرض ما تحتويه قبل أن يمس أي شيء';

  @override
  String get settingsImportDialog => 'اختر نسخة Kagami احتياطية';

  @override
  String get settingsImportInvalid => 'هذه ليست نسخة Kagami احتياطية';

  @override
  String get settingsImportSheetTitle => 'استيراد هذه النسخة الاحتياطية؟';

  @override
  String get settingsImportSeries => 'السلاسل';

  @override
  String get settingsImportRead => 'المقروءة';

  @override
  String get settingsImportCollections => 'المجموعات';

  @override
  String settingsImportExplain(String date) {
    return 'أُنشئت في $date. «دمج» يُبقي ما لديك ويضيف إليه: الفصول المقروءة تُجمع، وفي الباقي يفوز السجل الأحدث. «استبدال» يحذف بيانات هذا الجهاز.';
  }

  @override
  String get settingsImportExplainUnknownDate =>
      'أُنشئت في تاريخ غير معروف. «دمج» يُبقي ما لديك ويضيف إليه: الفصول المقروءة تُجمع، وفي الباقي يفوز السجل الأحدث. «استبدال» يحذف بيانات هذا الجهاز.';

  @override
  String get settingsImportMerge => 'دمج';

  @override
  String get settingsImportReplace => 'استبدال';

  @override
  String get settingsImportDone => 'تم استيراد البيانات';

  @override
  String get settingsImportFailed => 'فشل الاستيراد';

  @override
  String get settingsWipe => 'حذف البيانات الشخصية';

  @override
  String get settingsWipeNote =>
      'الحالة والتقييمات والسجل والمجموعات. المانغا لا تُمس';

  @override
  String get settingsWipeSheetTitle => 'حذف كل البيانات الشخصية؟';

  @override
  String get settingsWipeExplain =>
      'ستختفي حالة السلاسل والتقييمات والمفضلة والفصول المقروءة والسجل والجلسات والمجموعات والعلامات على هذا الجهاز. لا تُمس المانغا ولا فهارس المكتبة.\n\nإن لم تكن لديك نسخة احتياطية، فهذه آخر فرصة لإنشائها.';

  @override
  String get settingsWipeConfirm => 'حذف الكل';

  @override
  String get settingsWipeDone => 'حُذفت البيانات الشخصية';

  @override
  String get settingsDriveConnect => 'ربط Google Drive';

  @override
  String get settingsDriveConnectNote =>
      'يقرأ المكتبة من Drive دون جلبها كلها إلى الهاتف، وينزّل ما تختاره فقط';

  @override
  String get settingsDriveFolder => 'مجلد على Drive';

  @override
  String get settingsDriveSync => 'مزامنة المجلد';

  @override
  String get settingsDriveDownloadsGo => 'وجهة الفصول المنزَّلة';

  @override
  String settingsDriveDownloadsFolder(String path) {
    return 'في مجلد المكتبة: $path';
  }

  @override
  String get settingsDriveDownloadsApp => 'في مساحة التطبيق: تُحذف عند حذفه';

  @override
  String get settingsDriveDownloadsAsk => 'يُسأل عند أول تنزيل';

  @override
  String get settingsDriveCache => 'لوحات مقروءة من Drive';

  @override
  String settingsDriveCacheNote(String used, String limit) {
    return '$used في الذاكرة المؤقتة، بحد أقصى $limit. تُقرأ من جديد بدون شبكة';
  }

  @override
  String get settingsDriveCacheLimitTitle => 'مساحة اللوحات';

  @override
  String get settingsDriveClearCache => 'إفراغ الذاكرة المؤقتة';

  @override
  String get settingsDriveClearCacheNote => 'الفصول المنزَّلة لا تُمس';

  @override
  String get settingsDriveDisconnect => 'فك ربط Drive';

  @override
  String get settingsDriveDisconnectNote =>
      'تعود المكتبة إلى مجلد الهاتف. الفصول المنزَّلة تبقى';

  @override
  String get settingsAccountUnavailable => 'الحساب غير متاح هنا';

  @override
  String get settingsAccountUnavailableNote =>
      'هذه النسخة بلا Firebase: تبقى البيانات حيث هي، على الجهاز';

  @override
  String get settingsAccountSignIn => 'تسجيل الدخول بحساب Google';

  @override
  String get settingsAccountSignInNote =>
      'التقييمات والحالة والفصول المقروءة والسجل والمجموعات تتبع الحساب بدل الهاتف';

  @override
  String get settingsAccountSyncNow => 'زامن الآن';

  @override
  String get settingsAccountNeverSynced => 'لم تُجرَ مزامنة على هذا الهاتف قط';

  @override
  String settingsAccountLastSync(String date, String time) {
    return 'آخر مرة في $date عند $time';
  }

  @override
  String get settingsAccountSignOut => 'تسجيل الخروج';

  @override
  String get settingsAccountSignOutNote => 'يرفع آخر قراءة، ثم ينهي الجلسة';

  @override
  String get settingsAccountForget => 'التوقف عن حفظ نسخة';

  @override
  String get settingsAccountForgetNote =>
      'يحذف البيانات من الحساب. وما على هذا الهاتف يبقى حيث هو';

  @override
  String get settingsAccountErrorNote => 'لم تُمس بيانات هذا الهاتف';

  @override
  String get settingsAccountForgetSheetTitle => 'حذف البيانات من الحساب؟';

  @override
  String get settingsAccountForgetExplain =>
      'تختفي النسخة المحفوظة لك، ويُغلق تسجيل الدخول. حالة السلاسل والتقييمات والسجل والمجموعات على هذا الهاتف تبقى حيث هي، لكنها لن تظهر بعد الآن على هاتف آخر.';

  @override
  String get settingsAccountForgetConfirm => 'حذف من الحساب';

  @override
  String get settingsReaderDirection => 'الاتجاه في القراءة بالصفحات';

  @override
  String get settingsReaderBackground => 'الخلفية';

  @override
  String get settingsReaderKeepAwake => 'إبقاء الشاشة مضاءة';

  @override
  String get settingsReaderProgressBar => 'شريط التقدم';

  @override
  String get settingsProbe => 'قياس السلاسة';

  @override
  String get settingsProbeNote =>
      'في القارئ، في الأعلى: الإطارات البطيئة والمتخطاة، ومصدر الشرائح، وGC. لمسة على الأرقام تصفّرها';

  @override
  String get settingsProbeInfo1 =>
      'يعرض في القارئ، أعلى اليسار، مربعًا من الأرقام عن مدى سلاسة القراءة. يفيد في معرفة سبب تقطّع التمرير: لا يغيّر شيئًا في طريقة القراءة، وتكلفته ضئيلة جدًا.';

  @override
  String get settingsProbeInfo2 =>
      'أهم رقم هو «المتخطاة»: الإطارات الناقصة أثناء تمرير الصفحة. كل واحد منها تقطّع صغير يُرى. «المتأخرة» و«البطيئة» تبيّنان إن كان التطبيق مشغولًا، و«GC Android» إن كان النظام يُخلي الذاكرة.';

  @override
  String get settingsProbeInfo3 =>
      '«القطع» و«الكاملة» و«من الهاتف» و«الأصلية» تبيّن من أين وصل كل جزء من اللوحة: الثلاثة الأولى هي الطرق الخفيفة، والأخيرة هي القص الفوري، وهي التي تُثقل.';

  @override
  String get settingsProbeInfo4 =>
      'لمسة على المربع تصفّر الأرقام، لتقيس من نقطة محددة في الفصل. عند إعادة فتح التطبيق يتوقف القياس تلقائيًا.';

  @override
  String get settingsTexture => 'الشرائح الأصلية كنسيج';

  @override
  String get settingsTextureNote =>
      'تجريبي: اللوحات التي لم تُقطع بعد تصل إلى وحدة الرسوميات دون المرور بالواجهة. يتوقف عند إعادة فتح التطبيق';

  @override
  String get settingsTextureInfo1 =>
      'اللوحات الطويلة جدًا في الويبتون تُقرأ على شكل قطع. في الغالب تكون القطع جاهزة: قطعها الأرشيف على الخادم، أو الهاتف عند أول فتح للفصل. وعندما لا تكون جاهزة، يقصها مفكّك الترميز في Android في اللحظة نفسها.';

  @override
  String get settingsTextureInfo2 =>
      'عادةً تمر بكسلات هذه القطع عبر التطبيق قبل أن تصل إلى الشاشة. مع هذا الخيار تذهب مباشرة إلى بطاقة الرسوميات: يقل عمل التطبيق أثناء التمرير، وقد يقل التقطّع. جودة الصورة لا تتغير.';

  @override
  String get settingsTextureInfo3 =>
      'هذا تجريبي: طريقة رسم جديدة لم تُختبر بعد على هذا الهاتف. إن رأيت لوحات سوداء أو خطوطًا أو وميضًا، فأوقفه. وإن لم يدعمه الهاتف، يعود التطبيق تلقائيًا إلى الطريقة العادية.';

  @override
  String get settingsTextureInfo4 =>
      'في الفصول المقطّعة مسبقًا إلى قطع لا يتغير شيء، لأن هذا المسار لا يُستخدم فيها. عند إعادة فتح التطبيق يتوقف تلقائيًا.';

  @override
  String get settingsWhatItDoes => 'ما وظيفته';

  @override
  String get settingsBackupsTitle => 'نسخ في المكتبة';

  @override
  String get settingsBackupsNone =>
      'لا توجد نسخ بعد: تُنشأ الأولى عند الفتح القادم';

  @override
  String settingsBackupsLatest(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نسخة، الأخيرة $name',
      many: '$count نسخة، الأخيرة $name',
      few: '$count نسخ، الأخيرة $name',
      two: 'نسختان، الأخيرة $name',
      one: 'نسخة واحدة، الأخيرة $name',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupNow => 'إنشاء نسخة الآن';

  @override
  String settingsBackupWritten(String path) {
    return 'كُتبت النسخة في $path';
  }

  @override
  String settingsVersion(String version, String build) {
    return 'الإصدار $version ($build)';
  }

  @override
  String get settingsTagline => 'قارئ لأرشيفات MALF المحلية';

  @override
  String get librarySortUpdated => 'المحدَّثة مؤخرًا';

  @override
  String get librarySortTitle => 'العنوان';

  @override
  String get librarySortProgress => 'التقدم';

  @override
  String get librarySortAdded => 'المضافة مؤخرًا';

  @override
  String get librarySortLastRead => 'المقروءة مؤخرًا';

  @override
  String get librarySortUnread => 'للقراءة';

  @override
  String get librarySortRating => 'التقييم';

  @override
  String get librarySortChapters => 'عدد الفصول';

  @override
  String get librarySortShuffle => 'عشوائي';

  @override
  String get libraryDisplayComfortable => 'شبكة مريحة';

  @override
  String get libraryDisplayCompact => 'شبكة مضغوطة';

  @override
  String get libraryDisplayList => 'قائمة';

  @override
  String get libraryDisplayDetailed => 'قائمة مفصّلة';

  @override
  String get libraryAutoReading => 'قيد القراءة';

  @override
  String get libraryAutoFresh => 'الجديد';

  @override
  String get libraryAutoFavorites => 'المفضلة';

  @override
  String get libraryAutoPlanned => 'للبدء';

  @override
  String get libraryAutoFinished => 'المكتملة';

  @override
  String libraryRowChapters(int count) {
    return '$count فصل';
  }

  @override
  String libraryRowUnread(int count) {
    return '$count للقراءة';
  }

  @override
  String get libraryNoMatchTitle => 'لا توجد نتائج مطابقة';

  @override
  String get libraryNoMatchMessage =>
      'لا توجد سلسلة تطابق البحث والمرشحات المختارة.';

  @override
  String get libraryEmptyTitle => 'المكتبة فارغة';

  @override
  String get libraryEmptyMessage =>
      'المكتبة لا تحتوي على سلاسل. إن كان يُفترض أن تحتوي، فتحقق من مزامنة المجلد.';

  @override
  String get libraryClearFilters => 'تصفير المرشحات';

  @override
  String get libraryTitle => 'المكتبة';

  @override
  String get libraryCancelSelection => 'إلغاء التحديد';

  @override
  String librarySelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محددة',
      many: '$count محددة',
      few: '$count محددة',
      two: 'محددتان',
      one: 'محددة واحدة',
    );
    return '$_temp0';
  }

  @override
  String libraryAllWithCount(int count) {
    return 'الكل ($count)';
  }

  @override
  String get libraryAll => 'الكل';

  @override
  String get libraryMarkAllRead => 'تحديد الكل كمقروء';

  @override
  String get libraryMarkAllUnread => 'تحديد الكل كغير مقروء';

  @override
  String get libraryStatus => 'الحالة';

  @override
  String get libraryFavorites => 'المفضلة';

  @override
  String get libraryAddToCollection => 'إضافة إلى مجموعة';

  @override
  String libraryStatusOfSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حالة $count سلسلة',
      many: 'حالة $count سلسلة',
      few: 'حالة $count سلاسل',
      two: 'حالة سلسلتين',
      one: 'حالة سلسلة واحدة',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حُددت $count سلسلة كمقروءة',
      many: 'حُددت $count سلسلة كمقروءة',
      few: 'حُددت $count سلاسل كمقروءة',
      two: 'حُددت سلسلتان كمقروءتين',
      one: 'حُددت سلسلة واحدة كمقروءة',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عادت $count سلسلة إلى القراءة',
      many: 'عادت $count سلسلة إلى القراءة',
      few: 'عادت $count سلاسل إلى القراءة',
      two: 'عادت سلسلتان إلى القراءة',
      one: 'عادت سلسلة واحدة إلى القراءة',
    );
    return '$_temp0';
  }

  @override
  String get librarySearchHint => 'العنوان، المؤلف، tag:…';

  @override
  String get libraryLayout => 'التخطيط';

  @override
  String get libraryFiltersAndSort => 'المرشحات والترتيب';

  @override
  String get libraryReset => 'تصفير';

  @override
  String get librarySortSection => 'الترتيب';

  @override
  String get libraryShowOnly => 'عرض فقط';

  @override
  String get libraryOnlyUnread => 'بفصول للقراءة';

  @override
  String get libraryOnlyStarted => 'المبدوءة';

  @override
  String get libraryOnlyNew => 'بفصول جديدة';

  @override
  String get libraryOnlyFavorite => 'المفضلة';

  @override
  String get libraryMinRating => 'التقييم على الأقل';

  @override
  String get libraryRelease => 'النشر';

  @override
  String get libraryGenres => 'الأنواع';

  @override
  String get libraryTriHint => 'لمسة تطلب، ولمستان تستبعدان';

  @override
  String get libraryTags => 'الوسوم';

  @override
  String get libraryAuthors => 'المؤلفون';

  @override
  String get homeEmptyTitle => 'المكتبة فارغة';

  @override
  String get homeEmptyMessage =>
      'لا شيء للتصفح: المجلد لا يحتوي على أي سلسلة بعد.';

  @override
  String get homeToStart => 'للبدء';

  @override
  String get homeSimilarTitle => 'لماذا تقرأ ما تقرأ';

  @override
  String get homeSimilarSubtitle => 'لم تُفتح بعد، بأنواع تناسبك';

  @override
  String get homeRecentlyArrived => 'وصلت مؤخرًا';

  @override
  String get homeLeftHalfway => 'تُركت في المنتصف';

  @override
  String get homeLeftHalfwaySubtitle => 'المتوقفة مؤقتًا والمتروكة';

  @override
  String get homeCaughtUpTitle => 'أنت على اطلاع';

  @override
  String get homeCaughtUpMessage =>
      'بكل ما تمت مزامنته. الفصل القادم سيصل مع المجلد.';

  @override
  String get homeRandomSeries => 'سلسلة عشوائية';

  @override
  String get homeReloadLibrary => 'إعادة قراءة المكتبة';

  @override
  String get homeGreetingNight => 'منتصف الليل';

  @override
  String get homeGreetingMorning => 'صباح الخير';

  @override
  String get homeGreetingAfternoon => 'طاب يومك';

  @override
  String get homeGreetingEvening => 'مساء الخير';

  @override
  String get homeStatRead => 'المقروءة';

  @override
  String get homeStatReadCaption => 'فصل في المجموع';

  @override
  String get homeStatUnread => 'للقراءة';

  @override
  String get homeStatUnreadCaption => 'على الهاتف';

  @override
  String get homeStatStreak => 'على التوالي';

  @override
  String homeStatStreakCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يوم',
      many: 'يومًا',
      few: 'أيام',
      two: 'يومان',
      one: 'يوم',
    );
    return '$_temp0';
  }

  @override
  String get homeResume => 'استئناف';

  @override
  String get homeNextChapter => 'الفصل التالي';

  @override
  String get homeRead => 'اقرأ';

  @override
  String get homeUpdates => 'التحديثات';

  @override
  String get homeUpdatesSubtitle => 'فصول متزامنة ولم تُقرأ بعد';

  @override
  String homeLatestChapter(String number) {
    return 'فصل $number';
  }

  @override
  String get homeAgoToday => 'اليوم';

  @override
  String get homeAgoYesterday => 'أمس';

  @override
  String homeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count يوم',
      many: 'منذ $count يومًا',
      few: 'منذ $count أيام',
      two: 'منذ يومين',
      one: 'منذ يوم',
    );
    return '$_temp0';
  }

  @override
  String homeAgoWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count أسبوع',
      many: 'منذ $count أسبوعًا',
      few: 'منذ $count أسابيع',
      two: 'منذ أسبوعين',
      one: 'منذ أسبوع',
    );
    return '$_temp0';
  }

  @override
  String homeAgoMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count شهر',
      many: 'منذ $count شهرًا',
      few: 'منذ $count أشهر',
      two: 'منذ شهرين',
      one: 'منذ شهر',
    );
    return '$_temp0';
  }

  @override
  String homeAgoYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count سنة',
      many: 'منذ $count سنة',
      few: 'منذ $count سنوات',
      two: 'منذ سنتين',
      one: 'منذ سنة',
    );
    return '$_temp0';
  }

  @override
  String get collectionsTitle => 'المجموعات';

  @override
  String get collectionsNew => 'جديدة';

  @override
  String get collectionsAutomatic => 'تلقائية';

  @override
  String get collectionsYours => 'مجموعاتك';

  @override
  String get collectionsNoneTitle => 'لا توجد مجموعات';

  @override
  String get collectionsNoneMessage =>
      'هي وسيلة لتنظيم مكتبة تكبر من تلقاء نفسها: يمكن لسلسلة أن تكون في أكثر من مجموعة، والترتيب تختاره أنت.';

  @override
  String collectionsSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سلسلة',
      many: '$count سلسلة',
      few: '$count سلاسل',
      two: 'سلسلتان',
      one: 'سلسلة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get collectionsEdit => 'تعديل';

  @override
  String get collectionsRenameRecolor => 'إعادة التسمية وتغيير اللون';

  @override
  String get collectionsDelete => 'حذف المجموعة';

  @override
  String get collectionsNotFound => 'المجموعة غير موجودة.';

  @override
  String get collectionsDone => 'تم';

  @override
  String get collectionsReorder => 'إعادة الترتيب';

  @override
  String get collectionsEmptyTitle => 'المجموعة فارغة';

  @override
  String get collectionsEmptyMessage =>
      'تُضاف سلسلة من صفحتها، أو بالضغط مطولًا على غلاف في المكتبة.';

  @override
  String get collectionsRemoveFrom => 'إزالة من المجموعة';

  @override
  String get shellDataUnreadableTitle => 'بيانات التطبيق غير قابلة للقراءة';

  @override
  String get shellRetry => 'أعد المحاولة';

  @override
  String get shellTabHome => 'الرئيسية';

  @override
  String get shellTabLibrary => 'المكتبة';

  @override
  String get shellTabCollections => 'المجموعات';

  @override
  String get moreDownload => 'تنزيل مانغا';

  @override
  String get moreDownloadSubtitle => 'ابحث عن عنوان أو الصق رابطًا';

  @override
  String get moreHistory => 'السجل';

  @override
  String get moreHistorySubtitle => 'ما قرأته ومتى';

  @override
  String get moreStatistics => 'الإحصاءات';

  @override
  String get moreStatisticsSubtitle => 'كم تقرأ، وماذا تقرأ، ومتى';

  @override
  String get moreIncognito => 'القراءة المتخفية';

  @override
  String get moreIncognitoSubtitle =>
      'لا يسجل الموضع ولا الفصول المنتهية ولا وقت القراءة';

  @override
  String get historyTitle => 'السجل';

  @override
  String get historyIncognitoOn => 'التخفي مفعّل';

  @override
  String get historyIncognitoOff => 'القراءة المتخفية';

  @override
  String get historyClear => 'إفراغ';

  @override
  String get historyUnreadable => 'السجل غير قابل للقراءة';

  @override
  String get historyEmptyTitle => 'لا شيء مقروء حتى الآن';

  @override
  String get historyEmptyMessage => 'كل فصل تنهيه سيظهر هنا مع تاريخه.';

  @override
  String get historyClearTitle => 'إفراغ السجل؟';

  @override
  String get historyClearMessage =>
      'تختفي تواريخ القراءة والوقت المقضي في القراءة، ومعها الإحصاءات الناتجة عنها. وتعود الفصول إلى حالة «للقراءة».';

  @override
  String get historyIncognitoBanner =>
      'في وضع التخفي: لا يُسجَّل الموضع ولا الفصول المنتهية ولا وقت القراءة.';

  @override
  String get historyToday => 'اليوم';

  @override
  String get historyYesterday => 'أمس';

  @override
  String get historyReread => 'إعادة القراءة';

  @override
  String get historyRemove => 'إزالة من السجل';

  @override
  String get originLocal => 'على الهاتف';

  @override
  String get originDrive => 'على Drive';

  @override
  String get originMixed => 'على الهاتف، وفصول أخرى على Drive';

  @override
  String get coverNoChapters => 'لا توجد فصول منزَّلة';

  @override
  String coverChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل',
    );
    return '$_temp0';
  }

  @override
  String coverChaptersUnread(int count, int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل',
    );
    return '$_temp0 · $unread للقراءة';
  }

  @override
  String coverNewChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل جديد',
      many: '$count فصلًا جديدًا',
      few: '$count فصول جديدة',
      two: 'فصلان جديدان',
      one: 'فصل جديد واحد',
    );
    return '$_temp0';
  }

  @override
  String coverUnread(int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '$unread فصل للقراءة',
      many: '$unread فصلًا للقراءة',
      few: '$unread فصول للقراءة',
      two: 'فصلان للقراءة',
      one: 'فصل واحد للقراءة',
    );
    return '$_temp0';
  }

  @override
  String coverUnreadFresh(int unread, int fresh) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '$unread فصل للقراءة',
      many: '$unread فصلًا للقراءة',
      few: '$unread فصول للقراءة',
      two: 'فصلان للقراءة',
      one: 'فصل واحد للقراءة',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fresh,
      locale: localeName,
      other: '$fresh جديد',
      many: '$fresh جديدًا',
      few: '$fresh جديدة',
      two: 'اثنان جديدان',
      one: 'واحد جديد',
    );
    return '$_temp0، منها $_temp1';
  }

  @override
  String chartsDayNothing(String date) {
    return '$date: لا شيء';
  }

  @override
  String chartsDayChapters(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل',
      many: '$count فصلًا',
      few: '$count فصول',
      two: 'فصلان',
      one: 'فصل واحد',
    );
    return '$date: $_temp0';
  }

  @override
  String get kitClose => 'إغلاق';

  @override
  String get collectionSheetTitle => 'المجموعات';

  @override
  String collectionSheetTitleMany(int count) {
    return 'مجموعات $count سلسلة';
  }

  @override
  String get collectionSheetNew => 'جديدة';

  @override
  String get collectionSheetEmptyTitle => 'لا توجد مجموعات';

  @override
  String get collectionSheetEmptyMessage =>
      'تُستخدم لتنظيم مكتبة تكبر من تلقاء نفسها.';

  @override
  String collectionSheetSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سلسلة',
      many: '$count سلسلة',
      few: '$count سلاسل',
      two: 'سلسلتان',
      one: 'سلسلة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get collectionSheetCreateTitle => 'مجموعة جديدة';

  @override
  String get collectionSheetEditTitle => 'تعديل المجموعة';

  @override
  String get collectionSheetNameHint => 'الاسم';

  @override
  String get collectionSheetColor => 'اللون';

  @override
  String get collectionSheetCreate => 'إنشاء';

  @override
  String get collectionSheetSave => 'حفظ';

  @override
  String get cleanupTitle => 'تحرير المساحة؟';

  @override
  String get cleanupSyncBusy => 'مزامنة قيد التنفيذ: أعد المحاولة عند انتهائها';

  @override
  String cleanupNotAllDeleted(String error) {
    return 'لم يُحذف كل شيء: $error';
  }

  @override
  String cleanupDriveError(String error) {
    return 'Drive: $error. ما حُذف سابقًا يبقى محذوفًا';
  }

  @override
  String cleanupFreed(String size) {
    return 'تم تحرير $size';
  }

  @override
  String get cleanupNeedsNetwork => 'الحذف من Drive يتطلب شبكة';

  @override
  String cleanupIntroDrive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل مقروء ما زالت على Drive.',
      many: '$count فصلًا مقروءًا ما زالت على Drive.',
      few: '$count فصول مقروءة ما زالت على Drive.',
      two: 'فصلان مقروءان ما زالا على Drive.',
      one: 'فصل واحد مقروء ما زال على Drive.',
    );
    return '$_temp0';
  }

  @override
  String cleanupIntroPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل مقروء ما زالت تشغل مساحة على الهاتف.',
      many: '$count فصلًا مقروءًا ما زالت تشغل مساحة على الهاتف.',
      few: '$count فصول مقروءة ما زالت تشغل مساحة على الهاتف.',
      two: 'فصلان مقروءان ما زالا يشغلان مساحة على الهاتف.',
      one: 'فصل واحد مقروء ما زال يشغل مساحة على الهاتف.',
    );
    return '$_temp0';
  }

  @override
  String get cleanupPhoneChapters => 'فصول على الهاتف';

  @override
  String get cleanupDriveCache => 'ذاكرة Drive المؤقتة';

  @override
  String get cleanupDriveChapters => 'فصول على Drive';

  @override
  String cleanupApproxSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل',
      many: '$count فصلًا',
      few: '$count فصول',
      two: 'فصلان',
      one: 'فصل واحد',
    );
    return '$_temp0 · نحو $size';
  }

  @override
  String cleanupExactSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل',
      many: '$count فصلًا',
      few: '$count فصول',
      two: 'فصلان',
      one: 'فصل واحد',
    );
    return '$_temp0 · $size';
  }

  @override
  String cleanupApproxSizeTrash(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل',
      many: '$count فصلًا',
      few: '$count فصول',
      two: 'فصلان',
      one: 'فصل واحد',
    );
    return '$_temp0 · نحو $size · في السلة';
  }

  @override
  String get cleanupQuiet => 'عدم السؤال مجددًا عن هذه السلسلة';

  @override
  String get cleanupWarnNotOnDrive =>
      'هذه السلسلة ليست على Drive: الفصول المحذوفة لن يمكن قراءتها مجددًا حتى تعيدها المزامنة.';

  @override
  String get cleanupWarnGoneEverywhere =>
      'لن تبقى لا على الهاتف ولا على Drive.';

  @override
  String get cleanupWarnStaysOnDrive => 'الفصول تبقى على Drive وتُقرأ منه.';

  @override
  String get cleanupWarnTrash =>
      'يمكن استردادها من سلة Drive خلال ثلاثين يومًا. فهرس الخادم ما زال يسردها: إن أعاد الخادم رفعها، عادت تُقرأ من Drive.';

  @override
  String get cleanupDelete => 'حذف';

  @override
  String get cleanupNotNow => 'ليس الآن';

  @override
  String get cleanupSyncWarnExternal =>
      'إن كانت FolderSync تزامن المجلد في الاتجاهين، فقد يصل الحذف إلى Drive أيضًا؛ وإن كانت تنزّل فقط، فقد تعود الفصول في الجولة التالية.';

  @override
  String get cleanupSyncWarnOwn =>
      'المزامنة تحترم هذا الاختيار: ما تحذفه من طرف لا يعود ولا يختفي من الطرف الآخر، حتى مع نشر عمليات الحذف.';

  @override
  String get statsRangeMonth => '30 يومًا';

  @override
  String get statsRangeQuarter => '3 أشهر';

  @override
  String get statsRangeYear => 'سنة';

  @override
  String get statsTitle => 'الإحصاءات';

  @override
  String get statsUnavailable => 'تعذّر حساب الإحصاءات';

  @override
  String get statsChaptersRead => 'فصل مقروء';

  @override
  String get statsSeriesInLibrary => 'سلسلة في المكتبة';

  @override
  String statsMinutes(int count) {
    return '$count د';
  }

  @override
  String statsHours(int count) {
    return '$count س';
  }

  @override
  String get statsReadingTime => 'وقت القراءة';

  @override
  String get statsReadingTimeHint => 'يُقاس أثناء القراءة';

  @override
  String get statsPagesSeen => 'لوحة شوهدت';

  @override
  String get statsStreak => 'يوم متتالٍ';

  @override
  String statsStreakRecord(int count) {
    return 'الرقم القياسي: $count';
  }

  @override
  String get statsAverageRating => 'متوسط التقييم';

  @override
  String statsRatedSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سلسلة مقيَّمة',
      many: '$count سلسلة مقيَّمة',
      few: '$count سلاسل مقيَّمة',
      two: 'سلسلتان مقيَّمتان',
      one: 'سلسلة واحدة مقيَّمة',
    );
    return '$_temp0';
  }

  @override
  String get statsChaptersOverTime => 'الفصول المقروءة';

  @override
  String get statsPerWeek => 'في الأسبوع';

  @override
  String get statsPerDay => 'في اليوم';

  @override
  String get statsActivityTitle => 'متى تقرأ';

  @override
  String get statsActivitySubtitle => 'مربع لكل يوم، في آخر ستة أشهر';

  @override
  String get statsShelfTitle => 'المكتبة بحسب الحالة';

  @override
  String statsGenreOthers(int count) {
    return '$count أخرى';
  }

  @override
  String get statsGenresTitle => 'الأنواع التي تقرؤها';

  @override
  String get statsGenresSubtitle => 'من السلاسل التي بدأتها';

  @override
  String get statsRatingsTitle => 'كيف تقيّم';

  @override
  String get statsRatingsSubtitle => 'عدد السلاسل لكل تقييم';

  @override
  String get statsTopSeries => 'السلاسل الأكثر قراءة';

  @override
  String get statsShapeTitle => 'كيف تبدو المكتبة';

  @override
  String get statsSyncedChapters => 'فصل متزامن';

  @override
  String get statsStillUnread => 'ما زال للقراءة';

  @override
  String get statsOngoingSeries => 'سلسلة مستمرة';

  @override
  String statsAnnouncedMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فصل معلن وغير منزَّل',
      many: '$count فصلًا معلنًا وغير منزَّل',
      few: '$count فصول معلنة وغير منزَّلة',
      two: 'فصلان معلنان وغير منزَّلين',
      one: 'فصل واحد معلن وغير منزَّل',
    );
    return '$_temp0';
  }

  @override
  String get statsBytesOnPhone => 'مشغولة على الهاتف';

  @override
  String get statsNoHistory =>
      'لا شيء مقروء في هذه الفترة. يبدأ السجل من اللحظة التي بدأ فيها التطبيق بتسجيله.';

  @override
  String get dataDriveNotLinked => 'Drive غير مربوط';

  @override
  String get dataChapterNotOnDrive => 'الفصل غير موجود على Drive';

  @override
  String get dataChapterNoPagesOnDrive => 'الفصل بلا لوحات على Drive';

  @override
  String get dataPageNotOnDrive => 'اللوحة غير موجودة على Drive';

  @override
  String get dataPrefetchCancelled => 'أُلغي التحميل المسبق';

  @override
  String get dataDriveAccessDenied => 'لم تمنح Google صلاحية الوصول إلى Drive';

  @override
  String get dataDriveOfflineNeverOpened =>
      'لا يوجد اتصال، ولم تُفتح مكتبة Drive على هذا الهاتف من قبل';

  @override
  String get dataDriveSignedOut =>
      'سجّل الدخول بحساب Google لقراءة المكتبة على Drive';

  @override
  String get dataSyncMissingFolderOrDirection => 'المجلد أو الاتجاه مفقود';

  @override
  String get dataSyncFailed => 'فشلت المزامنة';

  @override
  String get dataSyncFolderUnreadable => 'تعذّرت قراءة مجلد الهاتف';

  @override
  String get dataSyncBusy => 'مزامنة قيد التنفيذ بالفعل';

  @override
  String get dataSyncCancelled => 'أُوقفت المزامنة';

  @override
  String get dataSyncDirectionDownload => 'من Drive';

  @override
  String get dataSyncDirectionUpload => 'إلى Drive';

  @override
  String get dataSyncDirectionBoth => 'الاثنان';

  @override
  String dataServerInviteTitle(String sender) {
    return 'منحك $sender حق الوصول إلى خادمه';
  }

  @override
  String dataServerInviteText(String serverName) {
    return 'اربط «$serverName» وسينزّل المانغا إلى Drive الخاص بك، حتى والهاتف مغلق.';
  }

  @override
  String get dataServerSignInRequired =>
      'سجّل الدخول بحساب Google لاستخدام الخادم.';

  @override
  String get dataServerNotLinked => 'لا يوجد خادم مربوط.';

  @override
  String dataServerUserNotNotified(String email, String url) {
    return 'يمكن لـ$email استخدام الخادم، لكن تعذّر إخباره: أرسل له العنوان $url بنفسك.';
  }

  @override
  String get dataPickLibraryFolderTitle => 'اختر مجلد مكتبة المانغا';

  @override
  String get dataCloudSignInNotEnabled =>
      'تسجيل الدخول بحساب Google غير مفعّل بعد في هذا المشروع';

  @override
  String get dataCloudNoConnection => 'لا يوجد اتصال';

  @override
  String get dataCloudNoSignIn => 'لم يتم تسجيل الدخول';

  @override
  String get dataCloudNoIdentityToken => 'لم تُعطِ Google رمز هوية';

  @override
  String get dataCloudSignInFailed => 'فشل تسجيل الدخول';

  @override
  String get dataCloudSignInInterrupted => 'انقطع تسجيل الدخول';

  @override
  String get dataCloudGoogleNotConfigured => 'Google غير مهيّأة لهذا التطبيق';

  @override
  String get dataCloudGoogleSignInFailed => 'فشل تسجيل الدخول بحساب Google';

  @override
  String dataNewChaptersNotification(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'وصل $count فصل جديد',
      many: 'وصل $count فصلًا جديدًا',
      few: 'وصلت $count فصول جديدة',
      two: 'وصل فصلان جديدان',
      one: 'وصل فصل جديد',
    );
    return '$_temp0';
  }

  @override
  String get dataArchivePhoneFolderMissing => 'مجلد الهاتف مفقود.';

  @override
  String get dataArchiveDriveFolderMissing => 'مجلد Drive مفقود.';

  @override
  String dataChapterLabel(String number) {
    return 'الفصل $number';
  }

  @override
  String get dataLibraryMissing => 'المجلد غير موجود أو غير قابل للقراءة.';

  @override
  String get dataLibraryNotIndexed =>
      'المجلد لا يحتوي على library.json: يجب إعادة إنشاء الفهارس بواسطة المؤرشِف الذي كتب المكتبة.';

  @override
  String get dataLibraryUnreadable =>
      'library.json غير قابل للقراءة أو ليس فهرس MALF صالحًا.';

  @override
  String get dataLibraryUnsupported =>
      'library.json يستخدم إصدارًا من الصيغة أحدث من هذا التطبيق.';

  @override
  String get dataReaderModeContinuous => 'متواصلة';

  @override
  String get dataReaderModePaged => 'بالصفحات';

  @override
  String get dataReaderDirectionLtr => 'يسار ← يمين';

  @override
  String get dataReaderDirectionRtl => 'يمين ← يسار';

  @override
  String get dataReaderFitWidth => 'العرض';

  @override
  String get dataReaderFitHeight => 'الارتفاع';

  @override
  String get dataReaderFitOriginal => 'الأصلي';

  @override
  String get dataReaderBackgroundBlack => 'أسود';

  @override
  String get dataReaderBackgroundGrey => 'رمادي';

  @override
  String get dataReaderBackgroundWhite => 'أبيض';

  @override
  String readerProbeFrames(String frames, String budget) {
    return 'الإطارات $frames · الحد $budget ms';
  }

  @override
  String readerProbeSlow(
    String build,
    String buildMax,
    String raster,
    String rasterMax,
  ) {
    return 'البطيئة UI $build (الأقصى $buildMax ms) · GPU $raster (الأقصى $rasterMax ms)';
  }

  @override
  String readerProbeLate(String late, String lateMax) {
    return 'المتأخرة $late (الأقصى $lateMax ms)';
  }

  @override
  String readerProbeScroll(String scroll, String missed, String gap) {
    return 'أثناء التمرير $scroll · المتخطاة $missed (أكبر فجوة $gap ms)';
  }

  @override
  String readerProbeSources(
    String tiles,
    String whole,
    String phone,
    String phoneMade,
  ) {
    return 'القطع $tiles · الكاملة $whole · من الهاتف $phone (المنجزة $phoneMade)';
  }

  @override
  String readerProbeNative(String bands, String textures, String decodes) {
    return 'الأصلية $bands (نسيج $textures) · لوحات مفكوكة $decodes';
  }

  @override
  String readerProbeDecode(
    String decode,
    String decodeMax,
    String arrival,
    String arrivalMax,
  ) {
    return 'فك الترميز $decode ms (الأقصى $decodeMax) · الوصول $arrival ms (الأقصى $arrivalMax)';
  }

  @override
  String readerProbeMemory(
    String copy,
    String gc,
    String gcMs,
    String blocking,
    String blockingMs,
  ) {
    return 'أقصى نسخ $copy ms · GC Android $gc ($gcMs ms) · الحاجبة $blocking ($blockingMs ms)';
  }

  @override
  String readerProbeWaits(String drive, String fallbacks) {
    return 'انتظارات Drive $drive · بدائل Dart $fallbacks';
  }

  @override
  String readerProbeJumps(String corrections, String jumps, String jumped) {
    return 'التصحيحات $corrections · القفزات $jumps ($jumped px)';
  }

  @override
  String get serverCheckDaily => 'فحص يومي للفصول الجديدة';

  @override
  String serverCheckDailyAt(String clock) {
    return 'كل يوم عند $clock بتوقيت الخادم';
  }

  @override
  String get serverCheckDailyOff =>
      'متوقف: لا تُنزَّل الفصول الجديدة إلا يدويًا';

  @override
  String get serverCheckLibrary => 'المكتبة كاملة على Drive';

  @override
  String get serverCheckLibraryOn =>
      'وكذلك السلاسل التي نزّلها الهاتف أو غيره، لا الخادم وحده';

  @override
  String get serverCheckLibraryOff => 'السلاسل الجارية التي نزّلها الخادم فقط';

  @override
  String serverCheckLast(String when, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سلاسل بفصول جديدة',
      one: 'سلسلة واحدة بفصول جديدة',
      zero: 'لا فصول جديدة',
    );
    return 'آخر فحص $when: $_temp0';
  }

  @override
  String get serverCheckTimeHelp => 'وقت الفحص';
}
