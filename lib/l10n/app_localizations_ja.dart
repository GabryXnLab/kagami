// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsLanguageSystem => 'システムに合わせる';

  @override
  String get seriesShelfNone => '状態なし';

  @override
  String get seriesShelfPlanned => '読みたい';

  @override
  String get seriesShelfReading => '読書中';

  @override
  String get seriesShelfPaused => '一時停止';

  @override
  String get seriesShelfCompleted => '読了';

  @override
  String get seriesShelfDropped => '中断';

  @override
  String get seriesReleaseOngoing => '連載中';

  @override
  String get seriesReleaseCompleted => '完結';

  @override
  String get seriesReleaseHiatus => '休載中';

  @override
  String get seriesReleaseCancelled => '打ち切り';

  @override
  String get seriesReleaseUnknown => '状態不明';

  @override
  String get seriesNotFound => '作品が見つかりません。';

  @override
  String get seriesOfflineTitle => 'Drive上の話';

  @override
  String get seriesOfflineMessage =>
      'オフラインのため、この作品の話の一覧を表示できません。ネットワークに戻ると自動的に表示されます。';

  @override
  String get seriesNoIndexTitle => 'インデックスなし';

  @override
  String get seriesNoIndexMessage =>
      'この作品にはindex.jsonがありません。作成したアーカイバでインデックスを再生成してください。';

  @override
  String get seriesNoChaptersTitle => '話がありません';

  @override
  String get seriesNoChaptersMessage => '検索とフィルターに一致する話はありません。';

  @override
  String seriesDownloadAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話をダウンロードしますか?',
      one: '1話をダウンロードしますか?',
    );
    return '$_temp0';
  }

  @override
  String get seriesDownloadAllMessage =>
      '現在Driveから読んでいるすべての話が端末に保存され、オフラインでも読めるようになります。';

  @override
  String get seriesDownload => 'ダウンロード';

  @override
  String seriesCleanupRemote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '読了した$count話がまだDriveにあります',
      one: '読了した1話がまだDriveにあります',
    );
    return '$_temp0';
  }

  @override
  String seriesCleanupLocal(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '読了した$count話が$sizeを使用しています',
      one: '読了した1話が$sizeを使用しています',
    );
    return '$_temp0';
  }

  @override
  String seriesDownloadFailed(String error) {
    return 'ダウンロードに失敗しました: $error。再試行';
  }

  @override
  String get seriesDownloadWaiting => 'ネットワーク待ち: 自動で再開します。キャンセル';

  @override
  String get seriesDownloadQueued => '待機中。キャンセル';

  @override
  String get seriesDownloadCancel => 'ダウンロードをキャンセル';

  @override
  String get seriesPlaceLocal => '端末内';

  @override
  String get seriesPlaceDrive => 'Drive上';

  @override
  String get seriesPlaceMixed => '端末とDrive';

  @override
  String get seriesMuteTooltipOn => '新着話の通知はオフです';

  @override
  String get seriesMuteTooltipOff => '新着話の通知はオンです';

  @override
  String get seriesMuteUnmuted => '新着話の通知をオンにしました。';

  @override
  String get seriesMuteMuted => '新着話の通知をオフにしました。';

  @override
  String seriesWaitingChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ダウンロード済みの分はすべて読みました。未読の$count話がまだ届いていません。',
    );
    return '$_temp0';
  }

  @override
  String seriesWaitingQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ダウンロード済みの分はすべて読みました。未読は$count話、次の分はキューに入っています。',
    );
    return '$_temp0';
  }

  @override
  String get seriesFetchNext => '次の話をダウンロード';

  @override
  String get seriesCaughtUpAll => '全話読了。';

  @override
  String get seriesResumeToContinue => '続きから';

  @override
  String get seriesResumeToStart => '未開始';

  @override
  String get seriesResumeHalfway => '途中まで';

  @override
  String seriesResumePage(int page, int total) {
    return '$page/$totalページ';
  }

  @override
  String get seriesContinue => '続ける';

  @override
  String get seriesStart => '読み始める';

  @override
  String get seriesResume => '再開';

  @override
  String get seriesNextChapter => '次の話';

  @override
  String get seriesFigureChapters => '話数';

  @override
  String get seriesFigureRead => '既読';

  @override
  String get seriesFigureProgress => '進捗';

  @override
  String get seriesFigureRating => '評価';

  @override
  String get seriesMyShelf => 'マイ本棚';

  @override
  String get seriesFavoriteOn => 'お気に入り済み';

  @override
  String get seriesFavoriteOff => 'お気に入り';

  @override
  String get seriesRatingButton => '評価';

  @override
  String seriesRatingOutOfTen(int rating) {
    return '$rating/10';
  }

  @override
  String get seriesCollections => 'コレクション';

  @override
  String get seriesNotes => 'メモ';

  @override
  String get seriesRatingSheetTitle => '評価をつけましょう';

  @override
  String get seriesNotesHint => 'どこまで読んだか、感想など…';

  @override
  String get seriesSave => '保存';

  @override
  String get seriesRatingWord1 => '最悪';

  @override
  String get seriesRatingWord2 => '悪い';

  @override
  String get seriesRatingWord3 => 'いまいち';

  @override
  String get seriesRatingWord4 => '微妙';

  @override
  String get seriesRatingWord5 => '普通';

  @override
  String get seriesRatingWord6 => 'まあまあ';

  @override
  String get seriesRatingWord7 => '良い';

  @override
  String get seriesRatingWord8 => 'とても良い';

  @override
  String get seriesRatingWord9 => '素晴らしい';

  @override
  String get seriesRatingWord10 => '傑作';

  @override
  String get seriesRatingNone => '評価なし';

  @override
  String get seriesRatingHint => 'タップまたはスライド';

  @override
  String seriesRatingBefore(int rating) {
    return '変更前: $rating';
  }

  @override
  String get seriesRatingRemove => '削除';

  @override
  String get seriesRatingSave => '評価を保存';

  @override
  String get seriesSynopsis => 'あらすじ';

  @override
  String get seriesGenres => 'ジャンル';

  @override
  String get seriesTags => 'タグ';

  @override
  String get seriesCreators => '作者';

  @override
  String seriesMoreTags(int count) {
    return 'ほか$count件';
  }

  @override
  String get seriesPaceToRead => '読了までの目安';

  @override
  String seriesPaceCaption(int chapters, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      chapters,
      locale: localeName,
      other: '$chapters話',
      one: '1話',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pagesページ',
      one: '1ページ',
    );
    return '$_temp0、$_temp1';
  }

  @override
  String get seriesPaceNext => '次の話';

  @override
  String get seriesPaceNextCaption => '直近の更新ペースから推定';

  @override
  String seriesDurationMinutes(int count) {
    return '$count分';
  }

  @override
  String seriesDurationHours(int count) {
    return '$count時間';
  }

  @override
  String seriesDurationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日',
      one: '1日',
    );
    return '$_temp0';
  }

  @override
  String get seriesWhenLate => '遅延中';

  @override
  String get seriesWhenExpected => 'まもなく';

  @override
  String get seriesWhenToday => '今日';

  @override
  String get seriesWhenTomorrow => '明日';

  @override
  String seriesWhenInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日後',
      one: '1日後',
    );
    return '$_temp0';
  }

  @override
  String seriesWhenInWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count週間後',
      one: '1週間後',
    );
    return '$_temp0';
  }

  @override
  String get seriesShowLess => '閉じる';

  @override
  String get seriesShowMore => '続きを読む';

  @override
  String get seriesChaptersTitle => '話';

  @override
  String seriesChaptersOf(int total) {
    return '全$total話';
  }

  @override
  String get seriesSearchChapter => '話を検索…';

  @override
  String get seriesSortNewest => '新しい順';

  @override
  String get seriesSortOldest => '古い順';

  @override
  String get seriesMarkAll => 'すべて既読/未読にする';

  @override
  String get seriesDownloadFromDrive => 'Driveからダウンロード';

  @override
  String get seriesFreeSpace => '容量を空ける';

  @override
  String get seriesFilterUnread => '未読';

  @override
  String get seriesFilterDownloaded => 'ダウンロード済み';

  @override
  String get seriesFilterAll => 'すべて';

  @override
  String seriesSelectedCount(int count) {
    return '$count件選択中';
  }

  @override
  String get seriesMarkReadMany => '既読にする';

  @override
  String get seriesMarkUnread => '未読にする';

  @override
  String get seriesMarkRead => '既読にする';

  @override
  String get seriesMarkReadThrough => 'ここまで既読にする';

  @override
  String get seriesSimilar => '似た作品';

  @override
  String get seriesChapterNotDownloaded => '未ダウンロード';

  @override
  String get seriesChapterUnlisted => 'サイトから削除済み';

  @override
  String seriesChapterPages(int count) {
    return '$countページ';
  }

  @override
  String get seriesDownloadToPhone => '端末にダウンロード';

  @override
  String get readerSeriesUnavailable => '作品を開けません。';

  @override
  String get readerNoPagesIndex =>
      'この作品にはpages.jsonがありません。作成したアーカイバでインデックスを再生成してください。';

  @override
  String get readerSeriesOffline =>
      'オフラインのため、この作品を開けません。ページの一覧はDriveにあります。ネットワークに戻ると開けます。';

  @override
  String get readerChapterNotOnPhone =>
      'この話はまだ端末にありません。同期が途中の可能性があります。しばらくしてからもう一度お試しください。';

  @override
  String get readerChapterNoPages => 'この話には読めるページがありません。';

  @override
  String get readerPagesNotOnPhone =>
      'この話のページはまだ端末にありません。インデックスには載っていますが、ファイルがありません。同期フォルダから取り込む必要があります。';

  @override
  String get readerMarkEarlierTitle => '前の話を既読にしますか?';

  @override
  String readerMarkEarlierBody(int count, String chapter) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$chapterを読み終えました。前の$count話がまだ未読になっています。ほかの場所で読んだ場合は、まとめて既読にしてください。',
      one: '$chapterを読み終えました。前の1話がまだ未読になっています。ほかの場所で読んだ場合は、既読にしてください。',
    );
    return '$_temp0';
  }

  @override
  String readerMarkEarlierConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話すべてを既読にする',
      one: '前の話を既読にする',
    );
    return '$_temp0';
  }

  @override
  String get readerMarkEarlierDecline => '未読のままにする';

  @override
  String readerBookmarkAdded(int page) {
    return '$pageページを保存しました';
  }

  @override
  String get readerChapters => '話';

  @override
  String get readerBookmarks => '保存したページ';

  @override
  String get readerNoBookmarks => '保存したページはありません';

  @override
  String get readerNoBookmarksHint =>
      'しおりはページの位置を記録します。話の読みかけの位置は、再開機能がすでに覚えています。';

  @override
  String readerBookmarkPage(int page) {
    return '$pageページ';
  }

  @override
  String get readerBookmarkRemove => '削除';

  @override
  String get readerToTop => '先頭へ戻る';

  @override
  String get readerPageNotFromDrive => 'Driveからページを取得できませんでした';

  @override
  String get readerPageUnreadable => 'ページを読み込めません';

  @override
  String get readerPageNotSynced => 'ページが未同期です';

  @override
  String get readerPageNotDownloaded => 'ページは未ダウンロードです';

  @override
  String get readerPageOfflineHint => 'オフラインです。ネットワークに戻ると自動で取得します。';

  @override
  String get readerRetryNow => '今すぐ再試行';

  @override
  String get readerLastChapterOnPhone => '端末にある最後の話です。';

  @override
  String get readerNextChapter => '次の話';

  @override
  String get readerContinue => '続ける';

  @override
  String get readerBookmarkThisPage => 'このページを保存';

  @override
  String get readerHowToRead => '読み方';

  @override
  String get readerPreviousChapter => '前の話';

  @override
  String get readerNextChapterTooltip => '次の話';

  @override
  String get readerSearchChapter => '話を検索…';

  @override
  String get readerNewestFirst => '新しい順';

  @override
  String get readerOldestFirst => '古い順';

  @override
  String readerReadingNow(String current, int total) {
    return '読書中: $current / 全$total話';
  }

  @override
  String get readerMode => '読書モード';

  @override
  String get readerModeStrip => '連続スクロール';

  @override
  String get readerModePage => 'ページ送り';

  @override
  String get readerDirection => '読む方向';

  @override
  String get readerDirectionLtr => '左 → 右';

  @override
  String get readerDirectionRtl => '右 → 左';

  @override
  String get readerFit => '表示サイズ';

  @override
  String get readerBackground => '背景';

  @override
  String get readerBrightness => '明るさ';

  @override
  String get readerAutoScroll => '自動スクロール';

  @override
  String get readerAutoScrollOff => 'オフ';

  @override
  String readerAutoScrollRate(int rate) {
    return '$rateページ/分';
  }

  @override
  String get readerShowPageNumber => 'ページ番号';

  @override
  String get readerShowProgress => '進捗バー';

  @override
  String get readerShowScrollTop => '先頭へ戻るボタン';

  @override
  String get readerKeepAwake => '画面を点灯したままにする';

  @override
  String get readerDoublePage => '見開き表示';

  @override
  String get readerLockRotation => '画面の回転を固定';

  @override
  String get archiveTitle => 'マンガをダウンロード';

  @override
  String get archiveIntro =>
      '対応サイトでタイトルを検索するか、作品またはその話のリンクを貼り付けてください。Kagamiがサイトから、メタデータ、表紙、全話の一覧とあわせてライブラリにダウンロードします。話をダウンロードせず、カードだけを保存することもできます。';

  @override
  String get archiveSearchHint => 'タイトルでマンガを検索';

  @override
  String get archiveFilterOngoing => '連載中';

  @override
  String get archiveFilterCompleted => '完結';

  @override
  String get archiveFilterNotInLibrary => 'ライブラリにない';

  @override
  String get archiveInLibrary => 'ライブラリにあり';

  @override
  String archiveResultsFiltered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件の結果がフィルターで非表示',
    );
    return '$_temp0';
  }

  @override
  String get archiveClear => 'クリア';

  @override
  String get archivePaste => '貼り付け';

  @override
  String get archiveReading => '作品を読み込み中…';

  @override
  String get archiveVerify => '作品を確認';

  @override
  String archiveSeriesSummary(String site, int count, String status) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話',
      one: '1話',
    );
    return '$site · $_temp0 · $status';
  }

  @override
  String get archiveWhatSection => 'ダウンロードする範囲';

  @override
  String get archiveModeAll => '全話';

  @override
  String get archiveModeFrom => '指定話から';

  @override
  String get archiveModePick => '選択';

  @override
  String get archiveModeAllHint => 'すべての話。あとでもう一度実行すると、新しい話と破損した話だけが追加されます。';

  @override
  String get archiveModeFromHint =>
      '選んだ話以降をダウンロードします。それより前の話は作品の一覧に残り、未ダウンロードと表示されます。';

  @override
  String get archiveModePickHint =>
      'タップした話だけをダウンロードします。ほかの話は一覧に未ダウンロードのまま残ります。';

  @override
  String get archiveChooseTitle => 'ダウンロードする内容';

  @override
  String get archiveModeAhead => '読みながら';

  @override
  String get archiveModeAllLine => 'すべての話を一度だけ';

  @override
  String archiveModeAheadLine(int count) {
    return '$count話を用意し、読むたびに1話ずつ';
  }

  @override
  String get archiveModeFromLine => '選んだ話から最新話まで';

  @override
  String get archiveModePickLine => 'タップした話だけ';

  @override
  String archiveModeAheadHint(int count) {
    return '選んだ話から$count話をダウンロードします。1話読むたびに新しい話が届き、シリーズの最後までいつでも$count話読めます。サイトに新しい話が出たときも同じように届きます。';
  }

  @override
  String get archiveModeAheadUnavailable =>
      'このサイトでは使えません。毎回ブラウザの確認を求められ、スマホだけでは通過できません。';

  @override
  String get archiveModeAheadServer =>
      '接続中のサーバーはまだ「読みながら」に対応していません。新しいバージョンが出ると1時間以内に自動で更新されます。';

  @override
  String get archiveChapterSearch => '番号やタイトルで検索';

  @override
  String get archiveNewestFirst => '新しい順';

  @override
  String get archiveOldestFirst => '最初から';

  @override
  String get archiveChooseStart => '開始する話をタップしてください。';

  @override
  String get archiveSelectMissing => '足りない話';

  @override
  String get archiveRangeHint => '話を長押しすると、最後にタップした話との間をまとめて選べます。';

  @override
  String get archivePickNone => '話が選ばれていません';

  @override
  String archiveSummaryChapters(int count, String where) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話',
    );
    return '$_temp0 · $where';
  }

  @override
  String archiveSummaryAhead(int count, String where) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'まず$count話',
    );
    return '$_temp0、その後は読むたびに1話 · $where';
  }

  @override
  String archiveDownloadAhead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話をダウンロードして読みながら続ける',
    );
    return '$_temp0';
  }

  @override
  String archiveInLibraryCount(int archived, int total) {
    return 'ライブラリ内: $total話中$archived話';
  }

  @override
  String get archiveChapterInLibrary => 'ライブラリにあり';

  @override
  String get archiveChapterStart => 'ここから開始';

  @override
  String get archiveChapterLater => '読むと届きます';

  @override
  String get archiveAdvanced => '詳細設定';

  @override
  String archiveAdvancedLine(String pause) {
    return 'リクエストの間隔: $pause';
  }

  @override
  String get archiveReopen => 'ダウンロードする内容を選ぶ';

  @override
  String get archiveSelectAll => 'すべて';

  @override
  String get archiveSelectNone => 'なし';

  @override
  String get archiveWhereSection => '保存先';

  @override
  String get archiveWhereServer => 'サーバー';

  @override
  String get archiveWhereDrive => 'Drive';

  @override
  String get archiveWhereDriveAndPhone => 'Driveと端末';

  @override
  String get archiveWherePhone => '端末';

  @override
  String get archiveWhereDriveHint =>
      'ライブラリのDriveフォルダに保存します。ページは端末を経由し、Driveに保存された時点で端末から消えます。ストリーミングで読むか、あとでダウンロードできます。';

  @override
  String get archiveWhereDriveAndPhoneHint =>
      'ライブラリのDriveフォルダに保存し、話は端末にも残るので、オフラインでも読めます。';

  @override
  String get archiveWherePhoneHint =>
      '端末のマンガフォルダまたはアプリの領域に保存します。Driveを連携すると、Driveに直接ダウンロードできます。';

  @override
  String archiveServerHint(String name, String folder, String other) {
    String _temp0 = intl.Intl.selectLogic(other, {
      'other': ' 注意: アプリが読み込むフォルダとは異なります。',
      'same': '',
    });
    return '「$name」がダウンロードし、端末の電源が切れていてもDriveの「$folder」にアップロードします。連載中の作品はサーバーが追跡します。$_temp0';
  }

  @override
  String get archiveDelaySection => 'リクエストの間隔';

  @override
  String get archiveDelayNone => 'なし';

  @override
  String archiveDelaySeconds(String seconds) {
    return '$seconds秒';
  }

  @override
  String get archiveDelayHint => 'サイトは連続ダウンロードを好みません。短い間隔を空けると、ブロックされにくくなります。';

  @override
  String get archiveDownloadAll => '作品全体をダウンロード';

  @override
  String archiveDownloadPicked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話をダウンロード',
      one: '1話をダウンロード',
    );
    return '$_temp0';
  }

  @override
  String get archiveResults => '検索結果';

  @override
  String archiveNoResults(String site) {
    return '$siteでは見つかりませんでした。';
  }

  @override
  String archiveChaptersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話',
      one: '1話',
    );
    return '$_temp0';
  }

  @override
  String archiveLatestChapter(String number) {
    return '最新: 第$number話';
  }

  @override
  String archiveVerifySite(String site) {
    return '$siteを認証';
  }

  @override
  String get archiveVerifySiteHint =>
      'サイトが人間かどうかを確認しようとしています。タップすると認証を開き、その後そこでも検索します';

  @override
  String get archiveStatusOngoing => '連載中';

  @override
  String get archiveStatusCompleted => '完結';

  @override
  String get archiveStatusHiatus => '休載中';

  @override
  String get archiveStatusCancelled => '打ち切り';

  @override
  String get archiveStatusUnknown => '状態不明';

  @override
  String get archiveErrChallenge => 'サイトが認証を求めていますが、ここでは実行できません。';

  @override
  String get archiveErrOffline => '接続がありません。サイトが応答しません。';

  @override
  String get archiveErrVerifyIncomplete => 'サイトの認証が完了しませんでした。';

  @override
  String archiveQueuedSnack(String title) {
    return '「$title」を待機列に追加しました。画面を消しても続行します。';
  }

  @override
  String archiveQueuedServerSnack(String title, String server) {
    return '「$title」を「$server」の待機列に追加しました。端末の電源を切っても大丈夫です。';
  }

  @override
  String get archiveServerFallbackName => 'サーバー';

  @override
  String get archiveDownloads => 'ダウンロード';

  @override
  String get archiveClearHistory => '消去';

  @override
  String get archiveQueueStopped => 'キュー停止中';

  @override
  String get archiveQueueResumeHint => '自動で再開します。タップすると今すぐ開始します';

  @override
  String archiveJobAutomatic(String destination) {
    return '新着話 · $destination';
  }

  @override
  String archiveJobQueued(String destination) {
    return '待機中 · $destination';
  }

  @override
  String get archiveRemoveFromQueue => 'キューから削除';

  @override
  String archiveHistoryLine(String when, String message) {
    return '$when · $message';
  }

  @override
  String get archiveRecent => '最近ダウンロードしたシリーズ';

  @override
  String archiveRecentAll(int count) {
    return 'すべて（$count）';
  }

  @override
  String get archiveRecentFailed => '失敗';

  @override
  String get archiveFollowedTitle => 'フォロー中の作品';

  @override
  String archiveFollowedProblems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '要対応: $count件',
    );
    return '$_temp0';
  }

  @override
  String archiveRecentLineRuns(String when, int runs, String message) {
    return '$when · $runs回 · $message';
  }

  @override
  String get archiveRetry => '再試行';

  @override
  String archiveJobAhead(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話',
    );
    return '読みながら: $_temp0 · $destination';
  }

  @override
  String get archiveSites => '対応サイト';

  @override
  String get archiveMoreSites => 'ほかのサイトも準備中です。新しいプロバイダへの対応は今後のアップデートで追加されます。';

  @override
  String archiveLinkCopied(String url) {
    return '$urlをクリップボードにコピーしました。';
  }

  @override
  String get archiveTracked => '連載中の作品';

  @override
  String get archiveTrackedIntro =>
      'ライブラリ内の連載中のシリーズは、ここからダウンロードしたものもそれ以外も、フォローをやめたものを除いて毎日チェックされ、新しい話だけが届きます。サイトからもう一度ダウンロードすると、再びフォローされます。';

  @override
  String get archiveTrackedByServer =>
      'フォロー中のシリーズは、設定(「ダウンロードとチェックの担当」)で選んだとおりサーバーがチェックします。スマホがフォローしていたシリーズは、スマホに戻すまで止まったままです。';

  @override
  String get archiveCheckDaily => '毎日確認';

  @override
  String archiveCheckAt(String time) {
    return '$timeに実行(アプリを閉じていても)';
  }

  @override
  String get archiveCheckTime => '時刻';

  @override
  String get archiveCheckTimeHelp => '確認する時刻';

  @override
  String get archiveWifiOnly => 'Wi-Fiのみ';

  @override
  String get archiveWifiOnlyOn => '従量課金でないネットワークを待ちます';

  @override
  String get archiveWifiOnlyOff => 'モバイルデータでも実行します';

  @override
  String get archiveCheckNow => '今すぐ確認';

  @override
  String get archiveRepair => 'アーカイブ済みシリーズを修復';

  @override
  String get archiveRepairHint => '各シリーズをサイトから読み直し、タイトル、表紙、話数を修正します';

  @override
  String get archiveRepairAll => 'ライブラリ全体';

  @override
  String archiveRepairSite(String site) {
    return '$site のシリーズのみ';
  }

  @override
  String get archiveRepairSeries => 'シリーズを修復';

  @override
  String archiveRepairRunning(int done, int total, String title) {
    return '修復中 $done/$total: $title';
  }

  @override
  String get archiveRepairQueued => 'サーバーで修復を開始しました。結果は履歴に表示されます。';

  @override
  String archiveRepairFinished(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のシリーズを修復しました。',
      zero: '修復するシリーズはありません。',
    );
    return '$_temp0';
  }

  @override
  String get archiveRepairNoLibrary =>
      '修復するライブラリがありません。Drive またはスマートフォンのフォルダを選んでください。';

  @override
  String get archiveRepairNoServer => 'サーバーはまだシリーズの修復に対応していません。更新が必要です。';

  @override
  String archiveRepairFailed(String error) {
    return '修復に失敗しました: $error';
  }

  @override
  String get archiveRepairPagesDone => 'シリーズを修復しました。';

  @override
  String get archiveRepairPagesNone => 'サーバーはライブラリでこのシリーズを見つけられませんでした。';

  @override
  String get archiveRepairNoVerification => '認証を通過できなかったため、シリーズは修復されませんでした。';

  @override
  String get archiveRepairBusy =>
      'スマートフォンはすでに修復中またはダウンロード中です。しばらくしてからもう一度お試しください。';

  @override
  String archiveRepairRecovered(String site) {
    return '$site が再び動作しています。このサイトのシリーズを修復しましょう';
  }

  @override
  String get archiveRepairRecoveredAction => '修復';

  @override
  String get archiveRepairDismiss => '無視';

  @override
  String get archiveRepairNothing => '修復するものはありません';

  @override
  String get archiveRepairAdopted => '新しいキーを採用';

  @override
  String get archiveRepairRetitled => 'タイトルを更新';

  @override
  String get archiveRepairCover => '表紙を更新';

  @override
  String archiveRepairAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '新しい話 $count 件',
    );
    return '$_temp0';
  }

  @override
  String archiveRepairUnlisted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '一覧から消えた話 $count 件',
    );
    return '$_temp0';
  }

  @override
  String archiveRepairError(String error) {
    return '修復できませんでした: $error';
  }

  @override
  String get archiveNoTracked => '追跡中の作品はまだありません';

  @override
  String archiveTrackedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '追跡中の作品: $count件',
      one: '追跡中の作品: 1件',
    );
    return '$_temp0';
  }

  @override
  String archiveTrackedLine(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話',
      one: '1話',
    );
    return '既知$_temp0 · $destination';
  }

  @override
  String archiveTrackedLineChecked(int count, String destination, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話',
      one: '1話',
    );
    return '既知$_temp0 · $destination · $whenに確認';
  }

  @override
  String archiveTrackedAhead(int count, String destination) {
    return '読みながら、$count話を用意 · $destination';
  }

  @override
  String get archiveStopFollowing => '追跡をやめる';

  @override
  String archiveCheckQueued(String names) {
    return '$namesの新着話';
  }

  @override
  String archiveCheckRemoved(String names) {
    return '$namesは完結しました';
  }

  @override
  String archiveCheckFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件は取得できませんでした',
      one: '1件は取得できませんでした',
    );
    return '$_temp0';
  }

  @override
  String get archiveCheckSeparator => '、';

  @override
  String archiveCheckReport(String parts) {
    return '$parts。';
  }

  @override
  String get archiveNoNewChapters => '新しい話はありません。';

  @override
  String get archiveNoConnection => '接続がありません。';

  @override
  String get archiveForgetTitle => '追跡をやめますか?';

  @override
  String archiveForgetBody(String title) {
    return '「$title」の新着話は自動では届かなくなります。ダウンロード済みの話は残ります。';
  }

  @override
  String get archiveCancel => 'キャンセル';

  @override
  String get archiveForgetConfirm => 'やめる';

  @override
  String get archiveStartNoMatch => 'この番号の話はありません。';

  @override
  String get browserTitle => 'サイトの認証';

  @override
  String get browserPhoneOnly => '認証は端末からのみ行えます。';

  @override
  String get browserInstructionsChapters =>
      'サイトが人間かどうかを確認しようとしています。認証を完了してください。話の一覧が表示されると、Kagamiが自動で検知して戻ります。';

  @override
  String get browserInstructionsSearch =>
      'サイトが人間かどうかを確認しようとしています。認証を完了してください。サイトの検索が表示されると、Kagamiが自動で検知して戻ります。';

  @override
  String get browserSearchPhoneOnly => 'このサイトの検索は端末からのみ行えます。';

  @override
  String get browserSearchSuperseded => '新しい検索に置き換えられました。';

  @override
  String get browserResponseTooLarge => '応答が大きすぎます。';

  @override
  String get serverTitle => 'サーバー';

  @override
  String get serverRecent => 'サーバーでダウンロード済み';

  @override
  String get serverUnavailableNoSecret =>
      'このビルドのアプリではサーバーを連携できません。ビルドした人がWebクライアントのシークレット(GOOGLE_SERVER_CLIENT_SECRET)を指定していません。';

  @override
  String get serverUnavailableAndroidOnly => 'サーバーの連携はAndroidでのみ行えます。';

  @override
  String get serverSignInRequired => 'サーバーを使うにはGoogleでログインしてください。';

  @override
  String get serverNoConnection => '接続がありません。';

  @override
  String get serverMissingGoogleServices =>
      'google-services.jsonがありません。このビルドにはGoogleのクライアントが含まれていません。';

  @override
  String get serverDriveAccessDenied => 'GoogleがDriveへのアクセスを許可しませんでした。';

  @override
  String get serverGoogleNotResponding => 'Googleが応答しません。しばらくしてからもう一度お試しください。';

  @override
  String serverWhenToday(String clock) {
    return '今日$clock';
  }

  @override
  String serverWhenDate(String date, String clock) {
    return '$date $clock';
  }

  @override
  String serverProgressStats(int pages, String size, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: ' · $skippedページは取得済み',
      zero: '',
    );
    return '新規$pagesページ · $size$_temp0';
  }

  @override
  String get serverRemoveFromQueue => 'キューから削除';

  @override
  String get serverNoFirebase =>
      'サーバーはGoogleアカウントで利用者を識別しますが、このビルドのアプリにはアカウント機能がありません。';

  @override
  String get serverSignedOutIntro =>
      '常時起動しているコンピューターが、端末の代わりにあなたのDriveへダウンロードやアップロードを行います。その間、端末の電源は切っても構いません。サーバーはGoogleアカウントであなたを識別します。';

  @override
  String get serverSignIn => 'Googleでログイン';

  @override
  String get serverSignInSubtitle => '自分のサーバーを作成する、または他の人のサーバーを使うため';

  @override
  String serverInviteTitle(String sender, String serverName) {
    return '$senderさんが「$serverName」へのアクセスを許可しました';
  }

  @override
  String get serverInviteSubtitle => '端末の電源が切れていても、あなたのDriveにダウンロードします。タップして連携';

  @override
  String get serverIgnore => '無視';

  @override
  String get serverLinkIntro =>
      '常時起動しているコンピューター(自分のもの、またはアクセスを許可してくれた人のもの)が、端末の代わりにあなたのDriveへダウンロードやアップロードを行います。その間、端末の電源は切っても構いません。';

  @override
  String get serverCreate => '自分のサーバーを作成';

  @override
  String get serverCreateSubtitle => 'Dockerのあるコンピューターに貼り付けるコマンドだけ。設定は不要です';

  @override
  String get serverLinkTitle => 'サーバーを連携';

  @override
  String get serverLinkSubtitle => '起動済みの自分のサーバー、または追加してくれた人のサーバー';

  @override
  String get serverStateConnecting => '接続中…';

  @override
  String get serverStateNoGrant => 'あなたのDriveへの権限がまだありません';

  @override
  String get serverStateNoFolder => 'あなたのDriveのどのフォルダに書き込むかまだ分かりません';

  @override
  String serverStateReady(String folder) {
    return '準備完了 · あなたのDriveの「$folder」に書き込みます';
  }

  @override
  String serverTileSubtitle(String address, String state) {
    return '$address · $state';
  }

  @override
  String serverTileSubtitleOwner(String address, String owner, String state) {
    return '$address · $ownerのサーバー · $state';
  }

  @override
  String get serverPlainTitle => '接続が暗号化されていません';

  @override
  String get serverPlainSubtitle =>
      'アカウントのトークンが通信経路で読み取られるおそれがあります。HTTPS(Tailscale Funnel、リバースプロキシ)が必要です';

  @override
  String get serverGrantTitle => 'Driveをサーバーに許可';

  @override
  String get serverGrantSubtitle => '端末の電源が切れていても、アプリが読み込むフォルダにダウンロードします';

  @override
  String get serverUseAppFolder => 'アプリのフォルダを使う';

  @override
  String serverUseAppFolderSubtitle(String serverFolder, String appFolder) {
    return 'サーバーは「$serverFolder」に書き込み、アプリは「$appFolder」を読み込みます';
  }

  @override
  String get serverUsersTitle => '利用できる人';

  @override
  String get serverUsersOnlyYou => 'あなただけです。追加したい人のGoogleアカウントを追加してください';

  @override
  String serverUsersCount(int count) {
    return '$countアカウント(あなたを含む)';
  }

  @override
  String get serverQueueWaiting => 'キュー待機中';

  @override
  String get serverQueueRestarts => 'サーバーが自動で再開します';

  @override
  String get serverJobAutomatic => '新着話 · サーバー上';

  @override
  String get serverJobQueued => '待機中 · サーバー上';

  @override
  String serverJobAhead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話',
    );
    return '読みながら: $_temp0';
  }

  @override
  String serverSeriesAhead(int count) {
    return '読みながら、$count話を用意: 読んでいる間にアプリが話を頼みます';
  }

  @override
  String serverSeriesKnown(int count) {
    return '既知$count話';
  }

  @override
  String serverSeriesKnownChecked(int count, String when) {
    return '既知$count話 · $whenに確認';
  }

  @override
  String get serverStopFollowing => '追跡をやめる';

  @override
  String get serverInviteRemoveFailed => '招待を削除できませんでした。もう一度お試しください。';

  @override
  String get serverCheckingNow => 'サーバーが確認中です。新着話はサーバーのキューに表示されます。';

  @override
  String get serverPaste => '貼り付け';

  @override
  String get serverAddressExposed =>
      '注意: 公開アドレスで暗号化されていないと、アカウントのトークンが通信経路で読み取られるおそれがあります。HTTPS(Tailscale Funnel、リバースプロキシ)またはTailscaleを使ってください。';

  @override
  String get serverDriveForeignTitle => 'このサーバーに Drive を渡しますか?';

  @override
  String get serverDriveForeignBody =>
      'このサーバーはあなたのものではありません。運営者は、ライブラリのフォルダだけでなく Drive 全体で読み取り・書き込み・削除ができるようになります。信頼できる場合のみ続けてください。';

  @override
  String get serverDriveForeignConfirm => '許可する';

  @override
  String get serverDriveNeedsHttps =>
      '公開アドレスの暗号化されていない (http://) サーバーには Drive の権限を送りません。通信中に読み取られるおそれがあります。https:// のアドレスか、Tailscale のようなプライベートネットワークを使ってください。';

  @override
  String get serverAddressSavedNote =>
      'アドレスはDriveのフォルダと同じく、バックアップとアカウントで引き継がれます。';

  @override
  String get serverAddressMissing =>
      'サーバーのアドレスを入力してください(例: http://192.168.1.20:8080)。';

  @override
  String serverLinked(String name, String folder) {
    return '「$name」に連携しました。あなたのDriveの「$folder」にダウンロードします。';
  }

  @override
  String serverLinkFromInvite(String sender, String serverName) {
    return '$senderさんがあなたを「$serverName」に追加しました。連携すると、サーバーは選んだマンガを、あなたのDriveにあるライブラリのフォルダにダウンロードします。Googleから、そこへの書き込みを許可するよう求められます。サーバーの管理者はこの権限を使用できます。';
  }

  @override
  String serverLinkLinked(String account) {
    return 'サーバーはあなたを$accountとして識別しています。自分のサーバーでない場合、連携を解除すると、あなたのDriveへの権限とキューも削除されます。';
  }

  @override
  String get serverSignedInAccount => 'ログイン中のアカウント';

  @override
  String get serverLinkNew =>
      'サーバーのアドレスを入力してください(自分のもの、または追加してくれた人から教えてもらったもの)。サーバーはGoogleアカウントであなたを識別し、初回はDriveのライブラリのフォルダへの書き込みを許可します。';

  @override
  String get serverVerifying => '確認中…';

  @override
  String get serverVerifyAgain => 'もう一度確認';

  @override
  String get serverVerifyAndLink => '確認して連携';

  @override
  String get serverUnlink => '連携を解除';

  @override
  String get serverDefaultNameOwn => '自分のKagami Server';

  @override
  String serverDefaultNameOf(String name) {
    return '$nameのサーバー';
  }

  @override
  String get serverCommandCopied => 'コマンドをコピーしました。';

  @override
  String get serverComputerAddressMissing =>
      'コンピューターのアドレスを入力してください(例: http://192.168.1.20:8080)。';

  @override
  String serverNotOwner(String owner) {
    return 'このサーバーは$ownerさんのものです。連携していますが、あなたが作成したものではありません。';
  }

  @override
  String serverReady(String name) {
    return '「$name」の準備ができました。「利用できる人」から追加したい人を追加してください。';
  }

  @override
  String get serverLibraryFolderFallback => 'ライブラリのフォルダ';

  @override
  String serverSetupIntro(String folder) {
    return '常時起動しているコンピューター(ミニPC、NAS、Raspberry Pi、ネットワーク上のサーバー)とDockerが必要です。サーバーがマンガをダウンロードして、端末の電源が切れていても、あなたのDriveの「$folder」にアップロードします。';
  }

  @override
  String serverPrepareIntro(String signIn, String folder) {
    String _temp0 = intl.Intl.selectLogic(signIn, {
      'yes': 'まずGoogleでログインし、次に',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(folder, {
      'yes': 'Driveのマンガフォルダを選び、次に',
      'other': '',
    });
    return 'すべてを含むコマンドを用意します。$_temp0$_temp1サーバーがあなたのDriveに書き込むことをGoogleが確認します。';
  }

  @override
  String get serverPreparing => '準備中…';

  @override
  String get serverGenerate => 'コマンドを生成';

  @override
  String get serverStep1 => 'まだなければ、コンピューターにDockerをインストールしてください(docker.com)。';

  @override
  String get serverStep2 =>
      'これらのコマンドをコンピューターのターミナルに貼り付けてください。1つ目がサーバーを起動し、2つ目がサーバーを自動で最新に保ちます。Driveへの権限が含まれているので、誰にも送らないでください。';

  @override
  String get serverCopyCommand => 'コマンドをコピー';

  @override
  String get serverStep3 =>
      'ここにコンピューターのアドレスを入力してください。自宅ではローカルネットワークのアドレス、外出先ではTailscale上の名前、または公開しているHTTPSのアドレスです。';

  @override
  String get serverPortNote => 'サーバーはポート8080で応答します。';

  @override
  String get serverUsersIntro =>
      '追加したい人のGoogleアカウントを追加してください。その人のKagamiアプリに招待が表示されます。サーバーを連携すると、その人のダウンロードは、その人のキューで、その人のDriveに保存されます。';

  @override
  String get serverUserEmailInvalid =>
      'Googleアカウントのアドレスを入力してください(例: name@gmail.com)。';

  @override
  String serverUserAdded(String email) {
    return '$emailがサーバーを利用できるようになりました。本人のアプリでお知らせします。';
  }

  @override
  String serverRemoveTitle(String email) {
    return '$emailを削除しますか?';
  }

  @override
  String get serverRemoveBody =>
      'サーバーを利用できなくなります。その人のキューとDriveへの権限は削除されます。すでにその人のDriveにあるものは残ります。';

  @override
  String get serverCancel => 'キャンセル';

  @override
  String get serverRemove => '削除';

  @override
  String get serverAdd => '追加';

  @override
  String get serverOwnerYou => 'あなた(所有者)';

  @override
  String get serverConnected => 'サーバーを連携済み';

  @override
  String get serverInvitedPending => '招待済み、まだサーバーを連携していません';

  @override
  String get setupIntro =>
      '同期によって端末に置かれたマンガフォルダ、または同じライブラリをGoogle Driveから直接読み込みます。すべてを端末に取り込む必要はありません。';

  @override
  String get setupAccessTitle => 'ファイルへのアクセス';

  @override
  String get setupAccessBody =>
      'このフォルダはアプリの専用領域の外にあり、数万枚の画像が入っています。Kagamiはそれらを直接読み込む必要があります。書き込むのは、ライブラリのreading/サブフォルダにあるデータのコピーと、ご希望の場合にDriveからダウンロードする話だけです。';

  @override
  String get setupGrantAccess => 'アクセスを許可';

  @override
  String get setupFolderTitle => 'フォルダ';

  @override
  String get setupFolderBody =>
      'FolderSyncで同期しているフォルダ、つまりlibrary.jsonと作品ごとのサブフォルダが入っているフォルダを選んでください。';

  @override
  String get setupChooseFolder => 'フォルダを選ぶ';

  @override
  String get setupOr => 'または';

  @override
  String get setupDriveTitle => 'Google Drive';

  @override
  String get setupDriveBody =>
      'Googleでログインし、Drive上のライブラリのフォルダを選びます。ページは読みながら取得され、いつでも読みたい話はワンタップでダウンロードできます。端末のファイルへのアクセスは不要です。';

  @override
  String get setupReadFromDrive => 'Google Driveから読む';

  @override
  String get setupLibraryProblemTitle => 'ライブラリを読み込めません';

  @override
  String get setupChangeFolder => 'フォルダを変更';

  @override
  String get driveFolderSheetTitle => 'Drive上のフォルダ';

  @override
  String get driveDestinationTitle => 'マンガの保存先は?';

  @override
  String get driveDestinationBody =>
      '端末にマンガ用のフォルダがありません。フォルダに保存すると、アプリをアンインストールしてもダウンロードした話が残り、Kagamiは既存の話と一緒に読み込みます。アプリの領域なら権限は不要ですが、アプリと一緒に消えます。';

  @override
  String get driveChooseFolder => 'フォルダを選ぶ';

  @override
  String get driveInAppSpace => 'アプリの領域';

  @override
  String get driveMyDrive => 'マイドライブ';

  @override
  String get driveSharedWithMe => '共有アイテム';

  @override
  String get driveBack => '戻る';

  @override
  String get driveNoResponse => 'Driveが応答しません';

  @override
  String get driveRetry => '再試行';

  @override
  String get driveIsLibrary => 'library.jsonがあります。ライブラリです';

  @override
  String get driveNotLibrary => 'library.jsonがありません。ライブラリはそれがあるフォルダです';

  @override
  String get driveUseFolder => 'このフォルダを使う';

  @override
  String get driveNoFolders => 'ここにフォルダはありません';

  @override
  String get driveNoticeAuthRequired => 'KagamiにはまだGoogle Driveを読み込む権限がありません';

  @override
  String get driveAuthorize => '許可';

  @override
  String get driveSignIn => 'ログイン';

  @override
  String get driveNoticeOffline =>
      'オフラインです。端末にある話と、ダウンロード済みのDriveのページは読めます。残りはネットワークに戻ると自動で復旧します';

  @override
  String driveNoticeError(String message) {
    return 'Drive: $message。端末にあるものを表示しています';
  }

  @override
  String get syncSummaryOff => 'オフ';

  @override
  String get syncSummaryDownload => 'Driveから端末へ';

  @override
  String get syncSummaryUpload => '端末からDriveへ';

  @override
  String get syncSummaryBoth => '双方向';

  @override
  String syncSummaryManual(String direction) {
    return '$direction、手動';
  }

  @override
  String syncSummaryDaily(String direction, String time) {
    return '$direction、毎日$time';
  }

  @override
  String get syncTitle => '同期';

  @override
  String get syncIntro =>
      '端末のマンガフォルダとDriveのフォルダを、FolderSyncなしで同じ状態に保ちます。このフォルダでまだFolderSyncを使っている場合は停止してください。同じファイルに対して2つの同期を動かすと干渉します。';

  @override
  String get syncFolders => 'フォルダ';

  @override
  String get syncOnPhone => '端末';

  @override
  String get syncNoFolderChosen => 'フォルダが選択されていません';

  @override
  String get syncOnDrive => 'Drive';

  @override
  String get syncDriveNotConnected => 'Driveが連携されていません';

  @override
  String get syncDirection => '方向';

  @override
  String get syncDirectionOff => 'オフ';

  @override
  String get syncDirectionFromDrive => 'Driveから';

  @override
  String get syncDirectionToDrive => 'Driveへ';

  @override
  String get syncDirectionBoth => '双方向';

  @override
  String get syncDescOff =>
      '自動では何も移動しません。Driveのライブラリは引き続き読めて、「ダウンロード」もこれまでどおり使えます。';

  @override
  String get syncDescDownload => 'Driveに追加されたものが端末に届きます。端末からは何もアップロードされません。';

  @override
  String get syncDescUpload =>
      '端末にあるものがDriveにアップロードされます。ライブラリのインデックスはサーバーのものが維持されます。';

  @override
  String get syncDescBoth =>
      '片方で変更されたものがもう片方に反映されます。両方で変更された場合は新しいほうが優先されます。ライブラリのインデックスはダウンロードのみです。サーバーのものだからです。';

  @override
  String get syncDeletions => '削除を反映';

  @override
  String get syncDeletionsDownload => 'Driveから消えたものを端末から削除します';

  @override
  String get syncDeletionsUpload => '端末から削除したものをDriveのゴミ箱に移します';

  @override
  String get syncDeletionsBoth => '双方に反映。Drive側はゴミ箱へ移動のみ';

  @override
  String get syncDeletionsOnNote => '「容量を空ける」で削除した既読の話は、次回の同期でDriveからも削除されます。';

  @override
  String get syncDeletionsOffNote =>
      '片方で削除したファイルはもう片方に残り、戻ってきません。「容量を空ける」は端末の容量を空け、話はDriveに残します。';

  @override
  String get syncDaily => '毎日';

  @override
  String get syncScheduled => 'スケジュール同期';

  @override
  String get syncManualOnly => '手動のみ';

  @override
  String syncAtTime(String time) {
    return '$timeに実行(アプリを閉じていても)';
  }

  @override
  String get syncTime => '時刻';

  @override
  String get syncWifiOnly => 'Wi-Fiのみ';

  @override
  String get syncWifiOnlyOn => '従量課金でないネットワークを待ちます';

  @override
  String get syncWifiOnlyOff => 'モバイルデータでも実行します';

  @override
  String get syncScheduleNote =>
      '正確なタイミングはAndroidが決めます。設定した時刻にネットワークがない場合は、接続が戻り次第開始します。';

  @override
  String get syncNow => '今すぐ';

  @override
  String get syncTimePickerHelp => '同期する時刻';

  @override
  String get syncRunNow => '今すぐ同期';

  @override
  String get syncRunNowReady => '読書は続けられます。コピーはバックグラウンドで進みます';

  @override
  String get syncRunNowNotReady => '端末のフォルダとDriveのフォルダが必要です';

  @override
  String get syncPhaseListing => 'Driveの内容を確認中…';

  @override
  String get syncPhaseComparing => '端末と比較中…';

  @override
  String get syncPhaseNothing => 'コピーするものはありません';

  @override
  String syncPhaseFiles(int done, int total) {
    return 'ファイル $done / $total';
  }

  @override
  String get syncStop => '中止';

  @override
  String get syncNever => '未同期';

  @override
  String get syncNeverNote => 'すでにファイルがあるフォルダでも、初回は速く終わります。同じファイルはサイズで判別されます';

  @override
  String syncLastScheduled(String date, String time) {
    return '前回(スケジュール): $date $time';
  }

  @override
  String syncLastManual(String date, String time) {
    return '前回(手動): $date $time';
  }

  @override
  String syncOutcomeDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件ダウンロード',
      one: '$count件ダウンロード',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeUploaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件アップロード',
      one: '$count件アップロード',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeDeletedLocal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '端末から$count件削除',
      one: '端末から$count件削除',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeTrashed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Driveのゴミ箱に$count件',
      one: 'Driveのゴミ箱に$count件',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件失敗、再試行します',
      one: '$count件失敗、再試行します',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeErrorSoFar(String error, String done) {
    return '$error。ここまでの結果: $done';
  }

  @override
  String get syncOutcomeAligned => 'すべて同期済みでした';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsAppearance => '外観';

  @override
  String get settingsThemeDark => 'ダーク';

  @override
  String get settingsThemeLight => 'ライト';

  @override
  String get settingsThemeSystem => 'システムに合わせる';

  @override
  String get settingsLibrary => 'ライブラリ';

  @override
  String get settingsFolder => 'フォルダ';

  @override
  String get settingsNoFolder => 'フォルダが選択されていません';

  @override
  String get settingsReloadIndexes => 'インデックスを再読み込み';

  @override
  String get settingsReloadIndexesNote => '同期で新しいものが届いた直後に実行してください';

  @override
  String get settingsIndexesReloaded => 'インデックスを再読み込みしました';

  @override
  String get settingsGoogleDrive => 'Google Drive';

  @override
  String get settingsReading => '読書';

  @override
  String get settingsAccount => 'アカウント';

  @override
  String get settingsData => 'データ';

  @override
  String get settingsAbout => 'アプリについて';

  @override
  String get settingsTheme => 'テーマ';

  @override
  String get settingsLibraryNote => 'フォルダ、インデックス、Google ドライブ';

  @override
  String get settingsLibraryNoteLocal => 'フォルダとインデックス';

  @override
  String get settingsReadingNote => '既定のモードとリーダーの計測';

  @override
  String get settingsAccountNote => 'Google ログインと同期';

  @override
  String get settingsDataNote => 'バックアップ、復元、消去';

  @override
  String get settingsAutoBackup => 'この端末への自動コピー';

  @override
  String get settingsAutoBackupNote =>
      '1日1回、この端末のアプリ専用の領域に保存されます。ほかの場所に残すには、アカウントまたは「エクスポート」を使ってください';

  @override
  String get settingsExport => 'データを書き出す';

  @override
  String get settingsExportNote => '状態、評価、履歴、コレクション、しおりを1つのファイルに';

  @override
  String get settingsExportDialog => 'バックアップの保存先';

  @override
  String get settingsExportCancelled => '書き出しをキャンセルしました';

  @override
  String get settingsExportSaved => 'バックアップを保存しました';

  @override
  String get settingsImport => 'バックアップから読み込む';

  @override
  String get settingsImportNote => '何も変更する前に、内容を確認できます';

  @override
  String get settingsImportDialog => 'Kagamiのバックアップを選択';

  @override
  String get settingsImportInvalid => 'Kagamiのバックアップではありません';

  @override
  String get settingsImportSheetTitle => 'このバックアップを読み込みますか?';

  @override
  String get settingsImportSeries => '作品';

  @override
  String get settingsImportRead => '既読';

  @override
  String get settingsImportCollections => 'コレクション';

  @override
  String settingsImportExplain(String date) {
    return '$dateに作成。「統合」は現在のデータを残して追加します。既読の話は合算され、それ以外は新しいレコードが優先されます。「置き換え」はこの端末のデータを消去します。';
  }

  @override
  String get settingsImportExplainUnknownDate =>
      '作成日不明。「統合」は現在のデータを残して追加します。既読の話は合算され、それ以外は新しいレコードが優先されます。「置き換え」はこの端末のデータを消去します。';

  @override
  String get settingsImportMerge => '統合';

  @override
  String get settingsImportReplace => '置き換え';

  @override
  String get settingsImportDone => 'データを読み込みました';

  @override
  String get settingsImportFailed => '読み込みに失敗しました';

  @override
  String get settingsWipe => '個人データを削除';

  @override
  String get settingsWipeNote => '状態、評価、履歴、コレクション。マンガには影響しません';

  @override
  String get settingsWipeSheetTitle => 'すべての個人データを削除しますか?';

  @override
  String get settingsWipeExplain =>
      'この端末の状態、評価、お気に入り、既読の話、履歴、読書セッション、コレクション、しおりが消えます。マンガとライブラリのインデックスには影響しません。\n\nバックアップがない場合は、今が最後のチャンスです。';

  @override
  String get settingsWipeConfirm => 'すべて削除';

  @override
  String get settingsWipeDone => '個人データを削除しました';

  @override
  String get settingsDriveConnect => 'Google Driveを連携';

  @override
  String get settingsDriveConnectNote =>
      'ライブラリを端末にすべて取り込まずにDriveから読み込み、選んだものだけをダウンロードします';

  @override
  String get settingsDriveFolder => 'Drive上のフォルダ';

  @override
  String get settingsDriveSync => 'フォルダの同期';

  @override
  String get settingsDriveDownloadsGo => 'ダウンロードした話の保存先';

  @override
  String settingsDriveDownloadsFolder(String path) {
    return 'ライブラリのフォルダ: $path';
  }

  @override
  String get settingsDriveDownloadsApp => 'アプリの領域(アンインストールすると消えます)';

  @override
  String get settingsDriveDownloadsAsk => '最初のダウンロード時に確認します';

  @override
  String get settingsDriveCache => 'Driveから読み込んだページ';

  @override
  String settingsDriveCacheNote(String used, String limit) {
    return 'キャッシュ$used、上限$limit。ネットワークなしで読み返せます';
  }

  @override
  String get settingsDriveCacheLimitTitle => 'ページ用の容量';

  @override
  String get settingsDriveClearCache => 'キャッシュを消去';

  @override
  String get settingsDriveClearCacheNote => 'ダウンロード済みの話には影響しません';

  @override
  String get settingsDriveDisconnect => 'Driveの連携を解除';

  @override
  String get settingsDriveDisconnectNote =>
      'ライブラリは端末のフォルダに戻ります。ダウンロード済みの話は残ります';

  @override
  String get settingsAccountUnavailable => 'ここではアカウントを利用できません';

  @override
  String get settingsAccountUnavailableNote =>
      'このビルドにはバックエンドがありません。データは端末内に残ります';

  @override
  String get settingsAccountSignIn => 'Googleでログイン';

  @override
  String get settingsAccountSignInNote =>
      '評価、状態、既読の話、履歴、コレクションが端末ではなくアカウントに紐づきます';

  @override
  String get settingsAccountSyncNow => '今すぐ同期';

  @override
  String get settingsAccountNeverSynced => 'この端末ではまだ同期していません';

  @override
  String settingsAccountLastSync(String date, String time) {
    return '前回: $date $time';
  }

  @override
  String get settingsAccountSignOut => 'ログアウト';

  @override
  String get settingsAccountSignOutNote =>
      '最新の読書データを送信してからログアウトします。端末はアカウントなしで使っていたときのデータに戻ります';

  @override
  String get settingsAccountSessionLostNote =>
      'セッションの有効期限が切れました。同期するにはもう一度ログインしてください。ログアウトするとアカウントなしで使っていたときのデータに戻ります';

  @override
  String get settingsAccountForget => 'コピーの保存をやめる';

  @override
  String get settingsAccountForgetNote =>
      'アカウントからデータを削除し、アカウントなしの利用に戻ります。アカウントのデータはこの端末の専用ファイルに残り、再ログインするまで表示されません';

  @override
  String get settingsAccountErrorNote => 'この端末のデータには影響していません';

  @override
  String get settingsAccountForgetSheetTitle => 'アカウントからデータを削除しますか?';

  @override
  String get settingsAccountForgetExplain =>
      'あなた用に保存されているコピーが消え、ログアウトされます。端末はアカウントなしの利用のデータに戻ります。アカウントの状態、評価、履歴、コレクションはこの端末の専用ファイルに残りますが、同じアカウントで再ログインするまで表示されません（ほかの端末では見られなくなります）。';

  @override
  String get settingsAccountForgetConfirm => 'アカウントから削除';

  @override
  String get settingsReaderDirection => 'ページ送りの方向';

  @override
  String get settingsReaderBackground => '背景';

  @override
  String get settingsReaderKeepAwake => '画面を点灯したままにする';

  @override
  String get settingsReaderProgressBar => '進捗バー';

  @override
  String get settingsProbe => '滑らかさを計測';

  @override
  String get settingsProbeNote =>
      'リーダーの上部に、遅いフレーム、欠けたフレーム、帯の取得元、GCを表示します。数値をタップするとリセットされます';

  @override
  String get settingsProbeInfo1 =>
      'リーダーの左上に、読書の滑らかさに関する数値の枠を表示します。スクロールがカクつく原因を調べるためのものです。読み方は変わらず、負荷もごくわずかです。';

  @override
  String get settingsProbeInfo2 =>
      '最も重要な数値は「欠け」です。ページのスクロール中に表示されなかったフレームの数で、1つひとつが目に見える小さなカクつきになります。「遅延開始」と「遅い」はアプリが処理で忙しかったかどうかを、「Android GC」はシステムがメモリを解放していたかどうかを示します。';

  @override
  String get settingsProbeInfo3 =>
      '「タイル」「全体」「端末製」「ネイティブ」は、ページの各部分がどこから届いたかを示します。最初の3つは軽い経路で、最後のネイティブはその場で切り出すため負荷がかかります。';

  @override
  String get settingsProbeInfo4 =>
      '枠をタップすると数値がリセットされ、話の特定の位置から計測できます。アプリを開き直すと計測は自動でオフになります。';

  @override
  String get settingsTexture => 'ネイティブの帯をテクスチャにする';

  @override
  String get settingsTextureNote =>
      '実験: まだ切り出していないページを、UIを経由せずにGPUへ渡します。アプリを開き直すとオフになります';

  @override
  String get settingsTextureInfo1 =>
      'ウェブトゥーンの非常に縦長のページは、分割して読み込まれます。分割済みの部分はほとんどの場合すでに用意されています。サーバー上のアーカイブで切り出されたものか、話を初めて開いたときに端末が切り出したものです。用意されていない場合は、Androidのデコーダーがその場で切り出します。';

  @override
  String get settingsTextureInfo2 =>
      '通常、これらの部分のピクセルはアプリを経由してから画面に届きます。このオプションをオンにすると、グラフィックスチップに直接渡されます。スクロール中のアプリの負荷が減り、カクつきが少なくなる可能性があります。画質は変わりません。';

  @override
  String get settingsTextureInfo3 =>
      'これは実験です。新しい描画方法で、この端末ではまだ検証されていません。黒いページ、線、ちらつきが出た場合はオフにしてください。端末が対応していない場合は、アプリが自動で通常の方法に戻ります。';

  @override
  String get settingsTextureInfo4 =>
      'すでにタイルに分割されている話には影響しません。その場合はこの経路を使わないためです。アプリを開き直すと自動でオフになります。';

  @override
  String get settingsWhatItDoes => '説明';

  @override
  String get settingsBackupsTitle => 'この端末のコピー';

  @override
  String get settingsBackupsNone => 'まだコピーはありません。最初のコピーは次回アプリを開いたときに作成されます';

  @override
  String settingsBackupsLatest(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'コピー$count件、最新: $name',
      one: 'コピー1件、最新: $name',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupNow => '今すぐコピーを作成';

  @override
  String settingsBackupWritten(String path) {
    return 'コピーを$pathに保存しました';
  }

  @override
  String settingsVersion(String version, String build) {
    return 'バージョン$version($build)';
  }

  @override
  String get settingsTagline => 'ローカルのMALFアーカイブ用リーダー';

  @override
  String get librarySortUpdated => '最近更新';

  @override
  String get librarySortTitle => 'タイトル';

  @override
  String get librarySortProgress => '進捗';

  @override
  String get librarySortAdded => '最近追加';

  @override
  String get librarySortLastRead => '最近読んだ';

  @override
  String get librarySortUnread => '未読';

  @override
  String get librarySortRating => '評価';

  @override
  String get librarySortChapters => '話数';

  @override
  String get librarySortShuffle => 'ランダム';

  @override
  String get libraryDisplayComfortable => 'ゆったりグリッド';

  @override
  String get libraryDisplayCompact => 'コンパクトグリッド';

  @override
  String get libraryDisplayList => 'リスト';

  @override
  String get libraryDisplayDetailed => '詳細リスト';

  @override
  String get libraryAutoReading => '読書中';

  @override
  String get libraryAutoFresh => '新着';

  @override
  String get libraryAutoFavorites => 'お気に入り';

  @override
  String get libraryAutoPlanned => '未開始';

  @override
  String get libraryAutoFinished => '読了';

  @override
  String libraryRowChapters(int count) {
    return '$count話';
  }

  @override
  String libraryRowUnread(int count) {
    return '未読$count話';
  }

  @override
  String get libraryNoMatchTitle => '該当なし';

  @override
  String get libraryNoMatchMessage => '検索とフィルターに一致する作品はありません。';

  @override
  String get libraryEmptyTitle => 'ライブラリは空です';

  @override
  String get libraryEmptyMessage => 'ライブラリに作品がありません。あるはずの場合は、フォルダの同期を確認してください。';

  @override
  String get libraryClearFilters => 'フィルターを解除';

  @override
  String get libraryTitle => 'ライブラリ';

  @override
  String get libraryCancelSelection => '選択を解除';

  @override
  String librarySelectedCount(int count) {
    return '$count件選択中';
  }

  @override
  String libraryAllWithCount(int count) {
    return 'すべて($count)';
  }

  @override
  String get libraryAll => 'すべて';

  @override
  String get libraryMarkAllRead => 'すべて既読にする';

  @override
  String get libraryMarkAllUnread => 'すべて未読にする';

  @override
  String get libraryStatus => '状態';

  @override
  String get libraryFavorites => 'お気に入り';

  @override
  String get libraryAddToCollection => 'コレクションに追加';

  @override
  String libraryStatusOfSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count作品の状態',
      one: '1作品の状態',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count作品を既読にしました',
      one: '1作品を既読にしました',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count作品を未読に戻しました',
      one: '1作品を未読に戻しました',
    );
    return '$_temp0';
  }

  @override
  String get librarySearchHint => 'タイトル、作者、tag:…';

  @override
  String get libraryLayout => '表示形式';

  @override
  String get libraryFiltersAndSort => 'フィルターと並べ替え';

  @override
  String get libraryReset => 'リセット';

  @override
  String get librarySortSection => '並べ替え';

  @override
  String get libraryShowOnly => '絞り込み';

  @override
  String get libraryOnlyUnread => '未読の話あり';

  @override
  String get libraryOnlyStarted => '読み始めた';

  @override
  String get libraryOnlyNew => '新着話あり';

  @override
  String get libraryOnlyFavorite => 'お気に入り';

  @override
  String get libraryMinRating => '評価が次以上';

  @override
  String get libraryRelease => '連載状況';

  @override
  String get libraryGenres => 'ジャンル';

  @override
  String get libraryTriHint => '1回タップで含める、2回タップで除外';

  @override
  String get libraryTags => 'タグ';

  @override
  String get libraryAuthors => '作者';

  @override
  String get homeEmptyTitle => 'ライブラリは空です';

  @override
  String get homeEmptyMessage => '表示するものがありません。フォルダにはまだ作品がありません。';

  @override
  String get homeToStart => '未開始';

  @override
  String get homeSimilarTitle => 'あなたの好みから';

  @override
  String get homeSimilarSubtitle => 'まだ開いていない、好きなジャンルの作品';

  @override
  String get homeRecentlyArrived => '最近追加';

  @override
  String get homeLeftHalfway => '途中で止まっている作品';

  @override
  String get homeLeftHalfwaySubtitle => '一時停止と中断';

  @override
  String get homeCaughtUpTitle => '追いつきました';

  @override
  String get homeCaughtUpMessage => '同期済みの話はすべて読み終えました。次の話はフォルダと一緒に届きます。';

  @override
  String get homeRandomSeries => 'ランダムに1作品';

  @override
  String get homeReloadLibrary => 'ライブラリを再読み込み';

  @override
  String get homeGreetingNight => '夜更け';

  @override
  String get homeGreetingMorning => 'おはようございます';

  @override
  String get homeGreetingAfternoon => 'こんにちは';

  @override
  String get homeGreetingEvening => 'こんばんは';

  @override
  String get homeStatRead => '既読';

  @override
  String get homeStatReadCaption => '累計の話数';

  @override
  String get homeStatUnread => '未読';

  @override
  String get homeStatUnreadCaption => '端末内';

  @override
  String get homeStatStreak => '連続';

  @override
  String homeStatStreakCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '日',
    );
    return '$_temp0';
  }

  @override
  String get homeResume => '続きから';

  @override
  String get homeNextChapter => '次の話';

  @override
  String get homeRead => '読む';

  @override
  String get homeUpdates => '更新';

  @override
  String get homeUpdatesSubtitle => '最後に読んだ話以降の新しい話';

  @override
  String homeLatestChapter(String number) {
    return '第$number話';
  }

  @override
  String homeSiteChapters(int count, String site) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$siteで新着$count話',
      one: '$siteで新着1話',
    );
    return '$_temp0';
  }

  @override
  String get homeAgoToday => '今日';

  @override
  String get homeAgoYesterday => '昨日';

  @override
  String homeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日前',
      one: '1日前',
    );
    return '$_temp0';
  }

  @override
  String homeAgoWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count週間前',
      one: '1週間前',
    );
    return '$_temp0';
  }

  @override
  String homeAgoMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countか月前',
      one: '1か月前',
    );
    return '$_temp0';
  }

  @override
  String homeAgoYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count年前',
      one: '1年前',
    );
    return '$_temp0';
  }

  @override
  String get collectionsTitle => 'コレクション';

  @override
  String get collectionsNew => '新規';

  @override
  String get collectionsAutomatic => '自動';

  @override
  String get collectionsYours => 'マイコレクション';

  @override
  String get collectionsNoneTitle => 'コレクションがありません';

  @override
  String get collectionsNoneMessage =>
      '自然に増えていくライブラリを整理するための機能です。1つの作品を複数のコレクションに入れられ、順番も自由に決められます。';

  @override
  String collectionsSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count作品',
      one: '1作品',
    );
    return '$_temp0';
  }

  @override
  String get collectionsEdit => '編集';

  @override
  String get collectionsRenameRecolor => '名前と色を変更';

  @override
  String get collectionsDelete => 'コレクションを削除';

  @override
  String get collectionsNotFound => 'コレクションが見つかりません。';

  @override
  String get collectionsDone => '完了';

  @override
  String get collectionsReorder => '並べ替え';

  @override
  String get collectionsEmptyTitle => 'コレクションは空です';

  @override
  String get collectionsEmptyMessage => '作品の詳細ページから、またはライブラリで表紙を長押しして追加できます。';

  @override
  String get collectionsRemoveFrom => 'コレクションから外す';

  @override
  String get shellDataUnreadableTitle => 'アプリのデータを読み込めません';

  @override
  String get shellRetry => '再試行';

  @override
  String get shellTabHome => 'ホーム';

  @override
  String get shellTabLibrary => 'ライブラリ';

  @override
  String get moreDownload => 'マンガをダウンロード';

  @override
  String get moreDownloadSubtitle => 'タイトルを検索、またはリンクを貼り付け';

  @override
  String get settingsEngine => 'ダウンロードとチェックの担当';

  @override
  String get settingsEngineServer => 'サーバー';

  @override
  String get settingsEnginePhone => 'スマホ';

  @override
  String get settingsEngineServerNote =>
      '新しいシリーズ、「読みながら」、フォロー中のシリーズのチェック:すべてサーバーで。スマホが Drive にダウンロードしたシリーズもサーバーが見ます';

  @override
  String get settingsEnginePhoneNote =>
      '新しいシリーズ、「読みながら」、フォロー中のシリーズのチェック:すべてスマホで。サーバーは接続されたままですが、何もチェックしません';

  @override
  String get settingsEngineNoServer =>
      'すべてスマホで。サーバーに任せるには「マンガをダウンロード」から接続してください';

  @override
  String get moreHistory => '履歴';

  @override
  String get moreHistorySubtitle => '何をいつ読んだか';

  @override
  String get moreStatistics => '統計';

  @override
  String get moreStatisticsSubtitle => '読書量、読んだ作品、時間帯';

  @override
  String get moreIncognito => 'シークレット読書';

  @override
  String get moreIncognitoSubtitle => '位置、読了した話、読書時間を記録しません';

  @override
  String get historyTitle => '履歴';

  @override
  String get historyIncognitoOn => 'シークレット中';

  @override
  String get historyIncognitoOff => 'シークレットで読む';

  @override
  String get historyClear => '消去';

  @override
  String get historyUnreadable => '履歴を読み込めません';

  @override
  String get historyEmptyTitle => 'まだ何も読んでいません';

  @override
  String get historyEmptyMessage => '読み終えた話が、日付とともにここに表示されます。';

  @override
  String get historyClearTitle => '履歴を消去しますか?';

  @override
  String get historyClearMessage => '読んだ日付と読書時間が消え、それをもとにした統計も消えます。話は未読に戻ります。';

  @override
  String get historyIncognitoBanner => 'シークレット中: 位置、読了した話、読書時間は記録されません。';

  @override
  String get historyToday => '今日';

  @override
  String get historyYesterday => '昨日';

  @override
  String get historyReread => '読み返す';

  @override
  String get historyRemove => '履歴から削除';

  @override
  String get originLocal => '端末内';

  @override
  String get originDrive => 'Drive上';

  @override
  String get originMixed => '端末内、一部の話はDrive上';

  @override
  String get coverNoChapters => 'ダウンロード済みの話なし';

  @override
  String coverChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話',
    );
    return '$_temp0';
  }

  @override
  String coverChaptersUnread(int count, int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話',
    );
    return '$_temp0 · 未読$unread話';
  }

  @override
  String coverNewChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '新着$count話',
      one: '新着1話',
    );
    return '$_temp0';
  }

  @override
  String coverUnread(int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '未読$unread話',
      one: '未読1話',
    );
    return '$_temp0';
  }

  @override
  String coverUnreadFresh(int unread, int fresh) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '未読$unread話',
      one: '未読1話',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fresh,
      locale: localeName,
      other: '新着$fresh話',
      one: '新着1話',
    );
    return '$_temp0、うち$_temp1';
  }

  @override
  String chartsDayNothing(String date) {
    return '$date: なし';
  }

  @override
  String chartsDayChapters(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話',
      one: '1話',
    );
    return '$date: $_temp0';
  }

  @override
  String get kitClose => '閉じる';

  @override
  String get collectionSheetTitle => 'コレクション';

  @override
  String collectionSheetTitleMany(int count) {
    return '$count作品のコレクション';
  }

  @override
  String get collectionSheetNew => '新規';

  @override
  String get collectionSheetEmptyTitle => 'コレクションがありません';

  @override
  String get collectionSheetEmptyMessage => '自然に増えていくライブラリを整理するための機能です。';

  @override
  String collectionSheetSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count作品',
      one: '1作品',
    );
    return '$_temp0';
  }

  @override
  String get collectionSheetCreateTitle => '新しいコレクション';

  @override
  String get collectionSheetEditTitle => 'コレクションを編集';

  @override
  String get collectionSheetNameHint => '名前';

  @override
  String get collectionSheetColor => '色';

  @override
  String get collectionSheetCreate => '作成';

  @override
  String get collectionSheetSave => '保存';

  @override
  String get cleanupTitle => '容量を空けますか?';

  @override
  String get cleanupSyncBusy => '同期中です。終了してからもう一度お試しください';

  @override
  String cleanupNotAllDeleted(String error) {
    return 'すべては削除できませんでした: $error';
  }

  @override
  String cleanupDriveError(String error) {
    return 'Drive: $error。すでに削除したものは削除されたままです';
  }

  @override
  String cleanupFreed(String size) {
    return '$sizeを空けました';
  }

  @override
  String get cleanupNeedsNetwork => 'Driveから削除するにはネットワークが必要です';

  @override
  String removeSeriesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のシリーズを削除しますか?',
      one: 'シリーズを削除しますか?',
    );
    return '$_temp0';
  }

  @override
  String removeSeriesBody(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ライブラリから削除します。スマホ上の話は消去され、新しい話も届かなくなります。読書の進み具合は残ります。',
      one: '「$title」をライブラリから削除します。スマホ上の話は消去され、新しい話も届かなくなります。読書の進み具合は残ります。',
    );
    return '$_temp0';
  }

  @override
  String get removeSeriesDrive => 'Drive のフォルダはゴミ箱に移動し、30日間はそこから復元できます。';

  @override
  String get removeSeriesDriveNotOwned =>
      'Drive 上のシリーズは残ります。ライブラリのフォルダがあなたのアカウントの所有ではないか、Drive がまだ確認していないためです。Kagami は所有している場所でのみ削除します。';

  @override
  String get removeSeriesConfirm => '削除';

  @override
  String removeSeriesDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のシリーズを削除しました。',
      one: 'シリーズを削除しました。',
    );
    return '$_temp0';
  }

  @override
  String removeSeriesFailed(String error) {
    return 'すべてを削除できませんでした: $error';
  }

  @override
  String get removeSeriesAction => 'ライブラリから削除';

  @override
  String cleanupIntroDrive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '読了した$count話がまだDriveにあります。',
      one: '読了した1話がまだDriveにあります。',
    );
    return '$_temp0';
  }

  @override
  String cleanupIntroPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '読了した$count話が端末の容量を使っています。',
      one: '読了した1話が端末の容量を使っています。',
    );
    return '$_temp0';
  }

  @override
  String get cleanupPhoneChapters => '端末内の話';

  @override
  String get cleanupDriveCache => 'Driveのキャッシュ';

  @override
  String get cleanupDriveChapters => 'Drive上の話';

  @override
  String cleanupApproxSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話',
      one: '1話',
    );
    return '$_temp0 · 約$size';
  }

  @override
  String cleanupExactSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話',
      one: '1話',
    );
    return '$_temp0 · $size';
  }

  @override
  String cleanupApproxSizeTrash(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話',
      one: '1話',
    );
    return '$_temp0 · 約$size · ゴミ箱へ';
  }

  @override
  String get cleanupQuiet => 'この作品では今後確認しない';

  @override
  String get cleanupWarnNotOnDrive =>
      'この作品はDriveにありません。削除した話は、同期で戻ってくるまで読み返せません。';

  @override
  String get cleanupWarnGoneEverywhere => '端末にもDriveにも残りません。';

  @override
  String get cleanupWarnStaysOnDrive => '話はDriveに残り、そこから読み返せます。';

  @override
  String get cleanupWarnTrash =>
      'Driveのゴミ箱から30日間は復元できます。サーバーのインデックスにはまだ載っているため、サーバーが再アップロードすると、Driveからまた読めるようになります。';

  @override
  String get cleanupDelete => '削除';

  @override
  String get cleanupNotNow => '今はしない';

  @override
  String get cleanupSyncWarnExternal =>
      'FolderSyncがフォルダを双方向に同期している場合、削除はDriveにも反映されることがあります。ダウンロードのみの場合は、次回の同期で話が戻ることがあります。';

  @override
  String get cleanupSyncWarnOwn =>
      '同期はこの選択を尊重します。削除の反映をオンにしていても、片方で削除したものはもう片方で復活も削除もされません。';

  @override
  String get statsRangeMonth => '30日';

  @override
  String get statsRangeQuarter => '3か月';

  @override
  String get statsRangeYear => '1年';

  @override
  String get statsTitle => '統計';

  @override
  String get statsUnavailable => '統計を計算できません';

  @override
  String get statsChaptersRead => '既読の話';

  @override
  String get statsSeriesInLibrary => 'ライブラリの作品';

  @override
  String statsMinutes(int count) {
    return '$count分';
  }

  @override
  String statsHours(int count) {
    return '$count時間';
  }

  @override
  String get statsReadingTime => '読書時間';

  @override
  String get statsReadingTimeHint => '読書中に計測';

  @override
  String get statsPagesSeen => '見たページ';

  @override
  String get statsStreak => '連続日数';

  @override
  String statsStreakRecord(int count) {
    return '最高記録: $count';
  }

  @override
  String get statsAverageRating => '平均評価';

  @override
  String statsRatedSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '評価した作品: $count件',
      one: '評価した作品: 1件',
    );
    return '$_temp0';
  }

  @override
  String get statsChaptersOverTime => '既読の話';

  @override
  String get statsPerWeek => '週ごと';

  @override
  String get statsPerDay => '日ごと';

  @override
  String get statsActivityTitle => '読む時期';

  @override
  String get statsActivitySubtitle => '1日1マス、過去6か月';

  @override
  String get statsShelfTitle => '状態別のライブラリ';

  @override
  String statsGenreOthers(int count) {
    return 'ほか$count件';
  }

  @override
  String get statsGenresTitle => '読んでいるジャンル';

  @override
  String get statsGenresSubtitle => '読み始めた作品が対象';

  @override
  String get statsRatingsTitle => '評価の分布';

  @override
  String get statsRatingsSubtitle => '評価ごとの作品数';

  @override
  String get statsTopSeries => 'よく読んだ作品';

  @override
  String get statsShapeTitle => 'ライブラリの内訳';

  @override
  String get statsSyncedChapters => '同期済みの話';

  @override
  String get statsStillUnread => '未読';

  @override
  String get statsOngoingSeries => '連載中の作品';

  @override
  String statsAnnouncedMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '告知済みで未ダウンロード: $count話',
      one: '告知済みで未ダウンロード: 1話',
    );
    return '$_temp0';
  }

  @override
  String get statsBytesOnPhone => '端末での使用量';

  @override
  String get statsNoHistory => 'この期間に読んだものはありません。履歴は、アプリが記録を始めた時点から始まります。';

  @override
  String get dataDriveNotLinked => 'Driveが連携されていません';

  @override
  String get dataChapterNotOnDrive => 'Driveで話が見つかりません';

  @override
  String get dataChapterNoPagesOnDrive => 'この話にはDrive上にページがありません';

  @override
  String get dataPageNotOnDrive => 'Driveでページが見つかりません';

  @override
  String get dataPrefetchCancelled => '先読みをキャンセルしました';

  @override
  String get dataDriveAccessDenied => 'GoogleがDriveへのアクセスを許可しませんでした';

  @override
  String get dataDriveOfflineNeverOpened =>
      'オフラインで、Drive上のライブラリはこの端末で一度も開いたことがありません';

  @override
  String get dataDriveSignedOut => 'Drive上のライブラリを読み込むには、Googleでログインしてください';

  @override
  String get dataSyncMissingFolderOrDirection => 'フォルダまたは方向が未設定です';

  @override
  String get dataSyncFailed => '同期に失敗しました';

  @override
  String get dataSyncFolderUnreadable => '端末のフォルダを読み込めません';

  @override
  String get dataSyncBusy => 'すでに同期中です';

  @override
  String get dataSyncCancelled => '同期を中止しました';

  @override
  String get dataSyncDirectionDownload => 'Driveから';

  @override
  String get dataSyncDirectionUpload => 'Driveへ';

  @override
  String get dataSyncDirectionBoth => '双方向';

  @override
  String dataServerInviteTitle(String sender) {
    return '$senderさんが自分のサーバーへのアクセスを許可しました';
  }

  @override
  String dataServerInviteText(String serverName) {
    return '「$serverName」を連携すると、端末の電源が切れていても、マンガがあなたのDriveにダウンロードされます。';
  }

  @override
  String get dataServerSignInRequired => 'サーバーを使うにはGoogleでログインしてください。';

  @override
  String get dataServerNotLinked => '連携しているサーバーがありません。';

  @override
  String dataServerUserNotNotified(String email, String url) {
    return '$emailはサーバーを利用できますが、通知できませんでした。アドレス$urlを直接送ってください。';
  }

  @override
  String get dataPickLibraryFolderTitle => 'マンガライブラリのフォルダを選択';

  @override
  String get dataCloudSignInNotEnabled => 'このプロジェクトではGoogleログインがまだ有効になっていません';

  @override
  String get dataCloudNoConnection => '接続がありません';

  @override
  String get dataCloudNoSignIn => 'ログインしていません';

  @override
  String get dataCloudNoIdentityToken => 'GoogleからIDトークンが返されませんでした';

  @override
  String get dataCloudSignInFailed => 'ログインに失敗しました';

  @override
  String get dataCloudSignInInterrupted => 'ログインが中断されました';

  @override
  String get dataCloudGoogleNotConfigured => 'このアプリはGoogle用に設定されていません';

  @override
  String get dataCloudGoogleSignInFailed => 'Googleログインに失敗しました';

  @override
  String get dataCloudBackendUnavailable => 'このビルドのバックエンドではこの機能を利用できません';

  @override
  String get dataCloudTooLarge =>
      '個人データがバックエンドの上限 16 MiB を超えています。この端末には残りますが、同期されません';

  @override
  String dataNewChaptersNotification(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '新しい話が$count話届きました',
      one: '新しい話が1話届きました',
    );
    return '$_temp0';
  }

  @override
  String dataNewSiteChaptersNotification(int count, String site) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$siteで新しい話が$count話公開されました',
      one: '$siteで新しい話が1話公開されました',
    );
    return '$_temp0';
  }

  @override
  String get dataArchivePhoneFolderMissing => '端末のフォルダが未設定です。';

  @override
  String get dataArchiveDriveFolderMissing => 'Driveのフォルダが未設定です。';

  @override
  String dataChapterLabel(String number) {
    return '第$number話';
  }

  @override
  String get dataLibraryMissing => 'フォルダが存在しないか、読み込めません。';

  @override
  String get dataLibraryNotIndexed =>
      'フォルダにlibrary.jsonがありません。ライブラリを作成したアーカイバでインデックスを再生成してください。';

  @override
  String get dataLibraryUnreadable =>
      'library.jsonを読み込めないか、有効なMALFインデックスではありません。';

  @override
  String get dataLibraryUnsupported => 'library.jsonは、このアプリより新しいバージョンの形式です。';

  @override
  String get dataReaderModeContinuous => '連続スクロール';

  @override
  String get dataReaderModePaged => 'ページ送り';

  @override
  String get dataReaderDirectionLtr => '左 → 右';

  @override
  String get dataReaderDirectionRtl => '右 → 左';

  @override
  String get dataReaderFitWidth => '幅に合わせる';

  @override
  String get dataReaderFitHeight => '高さに合わせる';

  @override
  String get dataReaderFitOriginal => '原寸';

  @override
  String get dataReaderBackgroundBlack => '黒';

  @override
  String get dataReaderBackgroundGrey => 'グレー';

  @override
  String get dataReaderBackgroundWhite => '白';

  @override
  String readerProbeFrames(String frames, String budget) {
    return 'フレーム $frames · 上限 $budget ms';
  }

  @override
  String readerProbeSlow(
    String build,
    String buildMax,
    String raster,
    String rasterMax,
  ) {
    return '遅い UI $build (最大 $buildMax ms) · GPU $raster (最大 $rasterMax ms)';
  }

  @override
  String readerProbeLate(String late, String lateMax) {
    return '遅延開始 $late (最大 $lateMax ms)';
  }

  @override
  String readerProbeScroll(String scroll, String missed, String gap) {
    return 'スクロール $scroll · 欠け $missed (最大間隔 $gap ms)';
  }

  @override
  String readerProbeSources(
    String tiles,
    String whole,
    String phone,
    String phoneMade,
  ) {
    return 'タイル $tiles · 全体 $whole · 端末製 $phone (作成 $phoneMade)';
  }

  @override
  String readerProbeNative(String bands, String textures, String decodes) {
    return 'ネイティブ $bands (テクスチャ $textures) · デコード済みページ $decodes';
  }

  @override
  String readerProbeDecode(
    String decode,
    String decodeMax,
    String arrival,
    String arrivalMax,
  ) {
    return 'デコード $decode ms (最大 $decodeMax) · 到着 $arrival ms (最大 $arrivalMax)';
  }

  @override
  String readerProbeMemory(
    String copy,
    String gc,
    String gcMs,
    String blocking,
    String blockingMs,
  ) {
    return 'コピー最大 $copy ms · Android GC $gc ($gcMs ms) · ブロック $blocking ($blockingMs ms)';
  }

  @override
  String readerProbeWaits(String drive, String fallbacks) {
    return 'Drive待ち $drive · Dartフォールバック $fallbacks';
  }

  @override
  String readerProbeJumps(String corrections, String jumps, String jumped) {
    return '補正 $corrections · ジャンプ $jumps ($jumped px)';
  }

  @override
  String get serverCheckDaily => '新しい話の毎日のチェック';

  @override
  String serverCheckDailyAt(String clock) {
    return '毎日 $clock(サーバーの時刻)';
  }

  @override
  String get serverCheckDailyOff => 'オフ:新しい話は手動でのみダウンロードされます';

  @override
  String get serverCheckByPhone => 'オフ:設定で選んだとおり、フォロー中のシリーズはスマホがチェックします';

  @override
  String serverCheckLast(String when, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '新しい話があるシリーズ $count 件',
      zero: '新しい話はありません',
    );
    return '前回のチェック $when:$_temp0';
  }

  @override
  String get serverCheckTimeHelp => 'チェックの時刻';

  @override
  String get seriesRatingInviteTitle => '何点をつけますか？';

  @override
  String get seriesRatingInviteBody => '評価はライブラリの絞り込みと並べ替えに使われ、統計にも反映されます。';

  @override
  String get seriesRatingInviteRate => '評価する';

  @override
  String get seriesRatingInviteIgnore => '今回は無視';

  @override
  String get seriesRatingInviteNever => '今後は表示しない';

  @override
  String get settingsRatingInvite => 'シリーズを開いたときに評価をうながす';

  @override
  String get settingsRatingInviteNote => '評価のないシリーズのページに、評価をうながすカードを表示します';

  @override
  String get archiveModeCard => 'カードのみ';

  @override
  String get archiveModeCardLine => '話はなし：状態、評価、どこまで読んだか';

  @override
  String get archiveModeCardHint =>
      '話をダウンロードせずに作品をライブラリに保存します：表紙、メタデータ、話の一覧、サイトへのリンク。どこまで読んだかを選ぶと、その話と前の話が既読になります。話はあとからダウンロードできます。';

  @override
  String get archiveReachedSection => 'ここまで読んだ…';

  @override
  String get archiveReachedHint => '最後に読んだ話をタップしてください。';

  @override
  String get archiveReachedNone => 'まだ読んでいない';

  @override
  String get archiveChapterReached => 'ここまで読んだ';

  @override
  String get archiveCardServer => 'カードはスマートフォンが保存します。接続したサーバーは話のダウンロードだけを行います。';

  @override
  String get archiveCardNotesHint => '自分用のメモ（任意）';

  @override
  String archiveSummaryCard(String where) {
    return 'カードを保存、話はダウンロードしません · $where';
  }

  @override
  String archiveSummaryCardReached(String number, String where) {
    return '$number話まで既読のカードを保存、話はダウンロードしません · $where';
  }

  @override
  String get archiveSaveCard => 'カードを保存';

  @override
  String archiveCardQueuedSnack(String title) {
    return '「$title」のカードを保存しました。表紙と話の一覧はまもなく届きます。';
  }

  @override
  String archiveCardProgress(String message) {
    return 'カード · $message';
  }

  @override
  String archiveJobCard(String destination) {
    return 'カード · $destination';
  }

  @override
  String archiveJobCardUpdate(String destination) {
    return 'カードの更新 · $destination';
  }

  @override
  String archiveRecentCard(String when) {
    return 'カード · $when';
  }

  @override
  String archiveCheckCards(String names) {
    return '$names のカードに新しい話を一覧へ追加（ダウンロードなし）';
  }

  @override
  String get seriesOpenSite => 'サイトで開く';

  @override
  String get seriesRefreshCard => 'カードを更新';

  @override
  String get seriesDownloadMore => 'ほかの章をダウンロード';

  @override
  String get seriesStartDownload => 'ダウンロードを始める';

  @override
  String get seriesStartDownloadMessage =>
      'このシリーズはカードだけで、章はサイトにあります。最後に読んだ章の次からダウンロードして、ここで読めます。';

  @override
  String get seriesDownloadFromSite => 'サイトからダウンロード';

  @override
  String get seriesDownloadFromSiteQueued => 'サイトから待機中';

  @override
  String get coverCardBadge => 'カード';

  @override
  String coverReached(String number) {
    return '第$number話まで読了';
  }

  @override
  String get libraryOnlyCards => 'カードのみ';

  @override
  String get seriesReachedTitle => '読んだところ';

  @override
  String get seriesReachedNone => '未読';

  @override
  String seriesReachedChapter(String number) {
    return '第$number話';
  }

  @override
  String get seriesReachedSearch => '話を検索';

  @override
  String get seriesReachedNumberHint => '話数';

  @override
  String get seriesReachedNumberHelp => 'サイトでの表記どおりに入力します（例: 52）。空欄で解除します。';

  @override
  String get seriesReachedBackTitle => '戻しますか？';

  @override
  String seriesReachedBackMessage(String chapter) {
    return '「$chapter」より後の話は既読のままです。未読に戻すには、話の一覧で既読を外してください。';
  }

  @override
  String get seriesReachedBackConfirm => '移動';

  @override
  String get seriesCardEmptyTitle => '話のないカード';

  @override
  String get seriesCardEmptyMessage =>
      'Kagami はこのサイトからはダウンロードしませんが、カードにはステータス、評価、メモ、読んだ位置が残ります。';

  @override
  String get seriesLinkSite => 'サイトにリンク';

  @override
  String get seriesLinkTitle => 'サイトにリンク';

  @override
  String get seriesLinkMessage =>
      'Kagami がダウンロードできるサイトのシリーズのリンクを貼り付けてください。ステータス、評価、メモ、コレクション、読書位置は本物のシリーズに引き継がれ、このカードは削除されます。';

  @override
  String get seriesLinkHint => 'シリーズのリンク';

  @override
  String get seriesLinkContinue => '続ける';

  @override
  String seriesLinkDone(String title) {
    return '「$title」をリンクしました。ジョブが終わるとライブラリに表示されます。';
  }

  @override
  String get seriesSwitchProvider => 'プロバイダーを変更';

  @override
  String get seriesSwitchMessage =>
      'シリーズを再ダウンロードするプロバイダーを選んでください。章、ページ、メタデータはそこから再ダウンロードされ、今のコピーは削除されます（Drive ではゴミ箱へ）。ステータス、評価、メモ、コレクション、既読の章、読書位置は章ごとに新しいシリーズへ移ります。';

  @override
  String get seriesSwitchOther => 'タップして別のものを選択';

  @override
  String seriesSwitchSearching(String title, String site) {
    return '$site で「$title」を探しています…';
  }

  @override
  String seriesSwitchNotFound(String title, String site) {
    return '$site で「$title」が見つかりませんでした。別のタイトルかもしれません。下で検索して正しいものを選んでください。';
  }

  @override
  String seriesSwitchSearchHint(String site) {
    return '$site で検索';
  }

  @override
  String seriesSwitchDone(String title, String site) {
    return '「$title」は $site から取得するようになりました。ジョブが終わるとライブラリに表示されます。';
  }

  @override
  String seriesSwitchMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '既読の章のうち $count 章は新しいサイトになく、履歴にだけ残ります。',
    );
    return '$_temp0';
  }

  @override
  String get archiveManualAction => 'リンクなしで追加';

  @override
  String get archiveManualUnsupported =>
      'Kagamiはこのサイトからダウンロードできません。タイトルとリンクを付けたカードとして保存できますが、チャプターはダウンロードできません。';

  @override
  String get archiveManualUnsupportedAction => 'カードとして保存';

  @override
  String get archiveManualTitle => '手動カード';

  @override
  String get archiveManualTitleHint => 'タイトル';

  @override
  String get archiveManualTitleRequired => 'タイトルを入力してください。';

  @override
  String get archiveManualLinkHint => '作品ページへのリンク(任意)';

  @override
  String get archiveManualSupported =>
      'Kagamiはこのサイトを読み取れます。通常の方法ならチャプター一覧が得られ、ダウンロードもできます。';

  @override
  String get archiveManualSupportedAction => '通常の方法を使う';

  @override
  String get archiveManualNoDownload =>
      'このサイトのチャプターはダウンロードできません。リンクのほか、ページが示していればタイトルと表紙が残ります。';

  @override
  String get archiveManualReachedHint => '読んだところまで(例: 52)';

  @override
  String get archiveManualWhereDrive => 'カードはDriveのライブラリフォルダに保存されます。';

  @override
  String get archiveManualWherePhone => 'カードは端末に保存されます。';

  @override
  String get archiveManualSave => 'カードを保存';

  @override
  String archiveManualSaved(String title) {
    return '「$title」のカードを保存しました。';
  }

  @override
  String archiveManualExists(String title) {
    return 'このリンクはすでにライブラリにあります:「$title」。';
  }

  @override
  String get archiveManualNeedsDrive => 'Driveにカードを保存するには書き込み権限が必要です。';

  @override
  String archiveManualFailed(String error) {
    return 'カードを保存できませんでした: $error';
  }

  @override
  String get archiveImportAction => '複数のリンクを取り込む';

  @override
  String get archiveImportTitle => '複数のリンクを取り込む';

  @override
  String get archiveImportIntro =>
      'リンクを貼り付けてください。ブラウザのタブ、一覧、JSON のどれでも構いません。各マンガは章をダウンロードせずにライブラリのカードになります。章のリンクなら、その章まで読んだことになります。';

  @override
  String get archiveImportHint => 'リンクを含むテキストをここに貼り付け…';

  @override
  String archiveImportFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のリンクが見つかりました',
      zero: 'リンクが見つかりません',
    );
    return '$_temp0';
  }

  @override
  String get archiveImportWhereDrive => 'カードは Drive のライブラリフォルダに保存されます。';

  @override
  String get archiveImportWherePhone => 'カードは端末に保存されます。';

  @override
  String get archiveImportCollection => 'コレクションに追加';

  @override
  String get archiveImportCollectionNone => 'コレクションなし';

  @override
  String get archiveImportPause => 'リンク間の待ち時間';

  @override
  String get archiveImportPauseHint =>
      'シリーズはサイトから 1 件ずつ読み込みます。待ち時間を長くするとサイトへの負担が減ります。';

  @override
  String archiveImportSeconds(int seconds) {
    return '$seconds 秒';
  }

  @override
  String archiveImportStart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のリンクを取り込む',
    );
    return '$_temp0';
  }

  @override
  String get archiveImportStop => '停止';

  @override
  String get archiveImportResume => '続ける';

  @override
  String get archiveImportWaiting => '待機中';

  @override
  String get archiveImportRunning => '処理中…';

  @override
  String get archiveImportSaved => 'カードとして保存しました';

  @override
  String archiveImportSavedReached(String chapter) {
    return 'カードとして保存 · $chapter 話まで読了';
  }

  @override
  String get archiveImportManual => '手動カード：Kagami はこの章をダウンロードできません';

  @override
  String archiveImportKnown(String title) {
    return 'ライブラリに登録済み：「$title」';
  }

  @override
  String get archiveImportQueued => 'キューに登録済み';

  @override
  String get archiveImportNeedsCheck => 'サイトが確認を求めています';

  @override
  String get archiveImportVerify => '確認';

  @override
  String get archiveImportRetry => '再試行';

  @override
  String get archiveImportCheckHint =>
      'ブラウザでの確認を求めるサイトがあります。1 件をタップして確認を済ませると、同じサイトの他のリンクは自動で再開します。';

  @override
  String archiveImportProgress(int done, int total) {
    return '$total 件中 $done 件';
  }

  @override
  String archiveImportCountSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'カード $count 件',
    );
    return '$_temp0';
  }

  @override
  String archiveImportCountManual(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '手動 $count 件',
    );
    return '$_temp0';
  }

  @override
  String archiveImportCountKnown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '登録済み $count 件',
    );
    return '$_temp0';
  }

  @override
  String archiveImportCountFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'エラー $count 件',
    );
    return '$_temp0';
  }

  @override
  String archiveImportCountCheck(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '要確認 $count 件',
    );
    return '$_temp0';
  }

  @override
  String get archiveImportLeaveTitle => '取り込みを停止しますか？';

  @override
  String get archiveImportLeaveBody => '保存済みのカードは残ります。残りのリンクは取り込まれません。';

  @override
  String get archiveImportLeaveConfirm => '停止して戻る';

  @override
  String get shareNoLinks => '共有されたテキストにリンクがありません。';

  @override
  String dataVerifyTitle(String sites) {
    return '$sites が確認を求めています';
  }

  @override
  String dataVerifyText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'チェックで $count 件のシリーズを読み込めませんでした。タップして確認を済ませてください。',
    );
    return '$_temp0';
  }

  @override
  String archiveGatedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のシリーズが確認待ちです',
    );
    return '$_temp0';
  }

  @override
  String archiveGatedBody(String sites) {
    return '$sites が「Verify you are human」のチェックを求めていますが、自動チェックはこれを行いません。ご自身で確認すると、これらのシリーズからチェックが再開します。';
  }

  @override
  String get archiveGatedAction => '確認する';

  @override
  String get archiveGatedNothing => '確認が完了しませんでした。シリーズは待機中のままです。';

  @override
  String get archiveGatedChecking => '確認が完了しました。シリーズをチェックしています…';

  @override
  String archiveCheckQueuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のシリーズに新しい話',
    );
    return '$_temp0';
  }

  @override
  String get settingsAutoCleanup => '自動クリーンアップ';

  @override
  String get settingsAutoCleanupRead => '既読の章を削除';

  @override
  String get settingsAutoCleanupReadNote =>
      '端末と Drive（ゴミ箱へ）から自動で削除します。読書位置と既読の記録は残ります';

  @override
  String get settingsAutoCleanupSharedRead =>
      '共有から読んだ章も既読です。あなたの Drive にあるコピーも削除されます。';

  @override
  String get settingsAutoCleanupIdle => '放置したシリーズの章を削除';

  @override
  String settingsAutoCleanupIdleNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日',
    );
    return '$_temp0読まれていないシリーズは、未読の章も削除します';
  }

  @override
  String get settingsAutoCleanupPause => '放置したシリーズを一時停止';

  @override
  String settingsAutoCleanupPauseNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日',
    );
    return '$_temp0読まれていない「読書中」のシリーズは「一時停止」になります';
  }

  @override
  String get settingsAutoCleanupIdleAfter => '放置とみなす期間';

  @override
  String settingsAutoCleanupDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日',
    );
    return '$_temp0';
  }

  @override
  String get settingsAutoCleanupPhoneOnly =>
      'Drive への書き込みが許可されていないため、章は端末からのみ削除されます';

  @override
  String homeUpdatesMore(int count) {
    return 'もっと見る（$count）';
  }

  @override
  String get homeUpdatesLess => '表示を減らす';

  @override
  String get settingsHomeUpdates => 'ホームの更新';

  @override
  String get settingsHomeUpdatesShown => '表示する作品数';

  @override
  String get settingsHomeUpdatesShownNote => '残りは「もっと見る」で表示されます';

  @override
  String settingsHomeUpdatesSeries(int count) {
    return '$count作品';
  }

  @override
  String get settingsHomeUpdatesMaxPending => '新しい話の上限';

  @override
  String get settingsHomeUpdatesMaxPendingNote =>
      '最後に読んだ話以降に読む話がこれより多い作品は更新に含めません';

  @override
  String settingsHomeUpdatesChapters(int count) {
    return '$count話';
  }

  @override
  String get collectionPropsTitle => 'コレクションのプロパティ';

  @override
  String get collectionPropsEntry => 'プロパティ';

  @override
  String get collectionsHasProps => '有効なプロパティあり';

  @override
  String get collectionPropsAutoTitle => '自動追加';

  @override
  String get collectionPropsAutoNote => 'すべてのルールに合う作品は自動で入ります。手動で外した作品は戻りません。';

  @override
  String get collectionPropsTypes => '種類';

  @override
  String get collectionPropsTags => 'ジャンルとタグ(すべて必須)';

  @override
  String get collectionPropsTagSearch => 'タグを検索';

  @override
  String get collectionPropsShelf => '読書の状態';

  @override
  String get collectionPropsRelease => '連載状況';

  @override
  String get collectionPropsProviders => 'サイト';

  @override
  String get collectionPropsMinRating => '最低評価';

  @override
  String get collectionPropsFavorite => 'お気に入りのみ';

  @override
  String get collectionPropsTraitsTitle => 'コレクション内のすべての作品に適用';

  @override
  String get collectionPropsMuted => '新着を通知しない';

  @override
  String get collectionTraitHidden => '非表示';

  @override
  String get collectionTraitHiddenHint => '通知なし。シリーズはコレクションを開いたときだけ表示されます';

  @override
  String get collectionPropsKeepChapters => '自動クリーンアップから除外';

  @override
  String get collectionPropsNoAutoPause => '自動一時停止から除外';

  @override
  String get collectionPropsNoRatingInvite => '評価を求めない';

  @override
  String get collectionPropsApply => '適用';

  @override
  String get settingsReadAhead => '読みながらダウンロード';

  @override
  String get settingsReadAheadWindow => '準備しておく話数';

  @override
  String get settingsReadAheadWindowNote =>
      '読みながらダウンロードするすべての作品で、読んでいる話の先にダウンロード済みで置いておく話数';

  @override
  String archiveSiteBroken(String site) {
    return 'サイト $site が動作していません。サイトが変更されたため、Kagami の更新が必要です。';
  }

  @override
  String get elsewhereTitle => '他のサイトで';

  @override
  String get elsewhereChecking => '他のサイトでシリーズを探しています…';

  @override
  String elsewhereChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 話',
    );
    return '$_temp0';
  }

  @override
  String elsewhereLatest(String chapter) {
    return '最新：第$chapter話';
  }

  @override
  String elsewhereLatestAt(String chapter, String date) {
    return '最新：第$chapter話、$date';
  }

  @override
  String elsewhereAhead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 話先行',
    );
    return '$_temp0';
  }

  @override
  String elsewhereBehind(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 話遅れ',
    );
    return '$_temp0';
  }

  @override
  String get elsewhereSame => '同じ話数';

  @override
  String get elsewhereMissing => 'ここにはありません';

  @override
  String get elsewhereBroken => 'サイトが動作していません';

  @override
  String get elsewhereGated => 'ブラウザ認証が必要です';

  @override
  String get elsewhereError => '応答がありませんでした';

  @override
  String get elsewhereSwitch => 'このサイトに切り替える';

  @override
  String get elsewhereSiteAction => '他のサイトで読める場所';

  @override
  String elsewhereSiteTitle(String site) {
    return '$site のシリーズ';
  }

  @override
  String get elsewhereSiteEmpty => 'このサイトのシリーズはライブラリにありません。';

  @override
  String get elsewhereSiteUnknown => 'まだ他のサイトで探していません';

  @override
  String get elsewhereSiteNowhere => '他のサイトには見つかりません';

  @override
  String get elsewhereSiteOffline =>
      '見つかっている分だけを表示します。Kagami Server を接続すると、すべてのシリーズを検索します。';

  @override
  String get sitesTitle => 'サイト';

  @override
  String get sitesEntrySubtitle => '内蔵のサイトと追加したサイト';

  @override
  String get sitesBuiltInSection => 'アプリ内蔵';

  @override
  String get sitesAddedSection => '追加済み';

  @override
  String get sitesNoneAdded => '追加したサイトはありません。';

  @override
  String get sitesNoLibrary =>
      'ライブラリとして Drive またはスマートフォンのフォルダが必要です。サイトはそこに保存されます。';

  @override
  String sitesVersion(int version) {
    return 'バージョン $version';
  }

  @override
  String sitesReplaces(String name) {
    return '$name を置き換えます';
  }

  @override
  String get sitesBroken => 'ファイルが壊れています';

  @override
  String get sitesUpdateNow => '今すぐ更新';

  @override
  String get sitesUpdated => 'サイトを更新しました。';

  @override
  String get sitesUpToDate => '新しい情報はありません。サイトは最新です。';

  @override
  String get sitesRemove => '削除';

  @override
  String sitesRemoveTitle(String name) {
    return '$name を削除しますか?';
  }

  @override
  String get sitesRemoveBody => 'このサイトの作品はライブラリに残りますが、サイトが戻るまで更新されません。';

  @override
  String get sitesAdd => 'サイトを追加';

  @override
  String get sitesAddHint => 'ファイルのリンクまたは貼り付けたテキスト';

  @override
  String get sitesAddCheck => '確認';

  @override
  String get sitesInvalid => 'ファイルが無効です';

  @override
  String get sitesFetchFailed => 'ファイルをダウンロードできませんでした';

  @override
  String get sitesPreviewHosts => 'ページの取得先';

  @override
  String get sitesTryTitle => 'インストール前に試す(任意)';

  @override
  String get sitesTryHint => '検索語または作品のリンク';

  @override
  String get sitesTry => '試す';

  @override
  String sitesTrySeries(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 話',
      one: '1 話',
    );
    return '$title：$_temp0';
  }

  @override
  String sitesTryResults(int count, String first) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件、最初:$first',
      one: '1 件:$first',
      zero: '結果なし',
    );
    return '$_temp0';
  }

  @override
  String get sitesTryFailed => '試行に失敗しました';

  @override
  String sitesFault(String phase, String field) {
    return '段階: $phase · フィールド: $field';
  }

  @override
  String sitesFaultPhase(String phase) {
    return '段階: $phase';
  }

  @override
  String get sitesInstall => 'インストール';

  @override
  String sitesInstalled(String name) {
    return '$name をインストールしました。';
  }

  @override
  String get seriesKindManga => 'マンガ';

  @override
  String get seriesKindManhwa => 'マンファ（韓国）';

  @override
  String get seriesKindManhua => 'マンファ（中国）';

  @override
  String get seriesKindOther => 'その他';

  @override
  String get collectionPropsBinding => '厳格に適用';

  @override
  String get collectionPropsBindingNote => '手動で追加する場合も、条件に合う作品だけがコレクションに入れます。';

  @override
  String collectionBindingWillRemove(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '条件に合わない$count作品がコレクションから外れます',
    );
    return '$_temp0';
  }

  @override
  String collectionBindingRefused(String title, String collection) {
    return '「$title」は「$collection」の条件に合いません';
  }

  @override
  String collectionBindingRefusedMany(int count, String collection) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count作品が「$collection」の条件に合いません',
    );
    return '$_temp0';
  }

  @override
  String get collectionBindingLockTip => '厳格なコレクション';

  @override
  String get accessDurationWeek => '1週間';

  @override
  String get accessDurationMonth => '1か月';

  @override
  String get accessDurationQuarter => '3か月';

  @override
  String get accessDurationYear => '1年';

  @override
  String get accessDurationNever => '無期限';

  @override
  String serverUserExpires(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateStringに期限切れ';
  }

  @override
  String get serverUserExpired => '期限切れ';

  @override
  String get serverUserRenew => '更新';

  @override
  String serverUserRenewTitle(String email) {
    return '$emailのアクセスを更新';
  }

  @override
  String serverMyAccessExpires(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'アクセスは$dateStringに期限切れになります';
  }

  @override
  String get serverAccessExpired => 'アクセスの期限が切れました。サーバーの管理者に更新を依頼してください';

  @override
  String dataServerExpiryTitle(String serverName) {
    return '「$serverName」へのアクセスがまもなく期限切れになります';
  }

  @override
  String dataServerExpiryText(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateStringに期限切れ: サーバーの管理者に更新を依頼してください。';
  }

  @override
  String get driveShareTitle => 'ライブラリを読める人';

  @override
  String get driveShareEntryNote => 'Drive上のフォルダを見られる人と期限';

  @override
  String driveShareIntro(String folder) {
    return '共有したい人のGoogleアカウントを追加してください。選んだ期間、Drive上のフォルダ「$folder」を読み取り専用で読めます。';
  }

  @override
  String get driveShareConsentTitle => 'Driveの権限がもう1つ必要です';

  @override
  String driveShareConsentBody(String folder) {
    return '追加した人は、ライブラリだけでなくフォルダ「$folder」のすべてのファイルを見られます。共有を管理するため、Googleが追加の権限を求めます。 フォルダ内にある読書データのコピーはDriveのゴミ箱に移動します。';
  }

  @override
  String get driveShareConsentContinue => '続ける';

  @override
  String get driveShareAdd => '共有';

  @override
  String driveShareInFolder(String name) {
    return 'フォルダ「$name」';
  }

  @override
  String get driveShareFromDrive => 'Driveから共有';

  @override
  String get driveShareRemoveBody => 'この人はフォルダを読めなくなります。';

  @override
  String get driveShareLinkAccess =>
      'リンクを知っている人やドメインでもこのフォルダを読めます。Driveで管理してください。';

  @override
  String get driveShareDriveSilent => 'Driveから応答がありませんでした。一覧が不完全な可能性があります。';

  @override
  String get driveSharePersonalFound =>
      'フォルダに読書データのコピー（reading/backup、state.json、collections.json）があります。フォルダを読める人はそれを見られます。';

  @override
  String get driveSharePersonalRemove => '削除';

  @override
  String get driveSharePersonalUnchecked => 'フォルダに読書データのコピーが残っているか確認できませんでした。';

  @override
  String get driveShareUnavailable => 'このバックエンドにはライブラリの共有機能がありません。';

  @override
  String driveShareLoadFailed(String message) {
    return 'アクセスできる人を読み込めません: $message';
  }

  @override
  String get driveShareNobody => '今は誰もいません。';

  @override
  String driveShareAdded(String email) {
    return '$emailがライブラリを読めます。';
  }

  @override
  String get driveShareOffline => '接続がありません。何も変わっていません。';

  @override
  String driveShareFailed(String message) {
    return '失敗しました: $message';
  }

  @override
  String get driveShareSelf => 'ご自身のアドレスです。';

  @override
  String get driveReceivedTitle => '共有されたライブラリ';

  @override
  String get driveReceivedEntryNote => '他の人のライブラリへの招待とアクセス';

  @override
  String driveReceivedInvite(String owner, String folder) {
    return '$owner さんがライブラリ「$folder」への読み取り専用アクセスを共有しました。';
  }

  @override
  String get driveReceivedAccept => '承諾';

  @override
  String get driveReceivedDecline => '辞退';

  @override
  String get driveReceivedRemove => '削除';

  @override
  String driveReceivedUntil(String owner, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$owner · $dateString まで';
  }

  @override
  String driveReceivedNoLimit(String owner) {
    return '$owner · 期限なし';
  }

  @override
  String driveReceivedExpiredRow(String owner) {
    return '$owner · アクセス期限切れ';
  }

  @override
  String get driveReceivedEmpty => '現在、共有されているライブラリはありません。';

  @override
  String driveReceivedNotificationTitle(String owner) {
    return '$owner さんがライブラリを共有しました';
  }

  @override
  String driveReceivedNotificationText(String folder) {
    return 'Kagami を開いて「$folder」を承諾してください。';
  }

  @override
  String driveNoticeSharedExpired(String name) {
    return '$name さんのライブラリへのアクセスは期限切れです。';
  }

  @override
  String driveNoticeSharedUnavailable(String name) {
    return '$name さんのライブラリが応答しません。共有が解除された可能性があります。';
  }

  @override
  String get driveNoticeSourcesUnreadable => '共有ライブラリを読み込めませんでした。';

  @override
  String get driveReceivedManage => '管理';

  @override
  String get sourcesTitle => 'ソース';

  @override
  String get sourcesEntryNote => '読み込み順と追加ライブラリ';

  @override
  String get sourcesHelp =>
      'すべてのソースのシリーズは1つのライブラリにまとめられます。同じシリーズが複数にある場合は先頭のソースが優先されます。';

  @override
  String get sourcesBuiltInFolder => 'スマートフォンのフォルダ';

  @override
  String get sourcesBuiltInApp => 'アプリ内ストレージ';

  @override
  String get sourcesBuiltInDrive => 'Google Drive';

  @override
  String get sourcesKindWebdav => 'WebDAV / NAS';

  @override
  String get sourcesKindSmb => 'SMB';

  @override
  String get sourcesComingSoon => '近日対応';

  @override
  String get sourcesStateReady => '利用可能';

  @override
  String get sourcesStateOffline => 'オフライン';

  @override
  String get sourcesStateNeedsAuth => '再接続が必要';

  @override
  String sourcesStateExpired(String date) {
    return '$date に期限切れ';
  }

  @override
  String get sourcesStateMissing => 'フォルダが見つかりません';

  @override
  String get sourcesStateOtherAccount => '別のアカウントのもの';

  @override
  String get sourcesReadOnlyBadge => '読み取り専用';

  @override
  String sourcesOwner(String owner) {
    return '$owner が共有';
  }

  @override
  String get sourcesAdd => 'ソースを追加';

  @override
  String get sourcesWebdavFolderHint => 'ライブラリのフォルダ（例: /manga）';

  @override
  String get sourcesWebdavUserHint => 'ユーザー';

  @override
  String get sourcesWebdavPasswordHint => 'パスワード';

  @override
  String get sourcesWebdavNameHint => '名前（任意、例: 自宅NAS）';

  @override
  String get sourcesSmbHostHint => 'コンピューターのアドレス（例: 192.168.1.10）';

  @override
  String get sourcesSmbShareHint => '共有名（例: manga）';

  @override
  String get sourcesSmbUserHint => 'ユーザー（空欄 = ゲスト）';

  @override
  String get sourcesSmbDomainHint => 'ドメイン（任意）';

  @override
  String get sourcesSmbSealLabel => '暗号化（SMB 3）';

  @override
  String get sourcesSmbSealNote =>
      '自宅ネットワークの外では暗号化が必要です。コンピューターが SMB 3 に対応している必要があります。';

  @override
  String get sourcesSmbPlainWarning =>
      '暗号化なしではパスワードとファイルが平文で流れます。自宅ネットワーク内でのみ使えます。';

  @override
  String get sourcesHttpPrivateWarning =>
      'プライベートネットワーク上の暗号化されていないHTTPアドレスです。ユーザー名とパスワードは平文で送られます。自宅のWi-Fiでのみ使ってください。';

  @override
  String get sourcesHttpPublicWarning =>
      '安全でない公開HTTPアドレスです。パスワードがインターネット上で平文で送られます。ローカルネットワーク外ではhttps://を使ってください。';

  @override
  String get sourcesProbeButton => '接続をテスト';

  @override
  String get sourcesProbing => 'テスト中…';

  @override
  String sourcesProbeSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '接続できました: $count 件のシリーズが見つかりました。',
    );
    return '$_temp0';
  }

  @override
  String get sourcesProbeAuthFailed => '認証が拒否されました。ユーザーとパスワードを確認してください。';

  @override
  String get sourcesProbeUnreachable => '接続できません。アドレスとネットワークを確認してください。';

  @override
  String get sourcesProbeNoLibrary => 'ここにライブラリはありません。フォルダにlibrary.jsonがありません。';

  @override
  String get sourcesSave => '保存';

  @override
  String get sourcesPasswordRewriteHint => 'パスワードを再入力（空欄: 変更しない）';

  @override
  String get sourcesSecretNote => 'パスワードはこの端末にだけ残り、バックアップやアカウントには含まれません。';

  @override
  String get sourcesRemove => 'ソースを削除';

  @override
  String get sourcesRemoveSubtitle => '設定・パスワード・キャッシュを削除します。読書の進捗は残ります。';

  @override
  String sourcesRemoveConfirmTitle(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get sourcesRemoveConfirmBody =>
      'この端末から設定・パスワード・キャッシュを削除します。読書の進捗・評価・履歴は残ります。';

  @override
  String get sourcesDismiss => '外す';

  @override
  String get socialTitle => 'コミュニティ';

  @override
  String get socialSubtitleOff => 'オフ：あなたの情報は外に出ません';

  @override
  String get socialSubtitleOn => 'プロフィール、ランキング、読書メモ';

  @override
  String get socialOffIntro =>
      'コミュニティはオフです。端末から何も送信されず、アプリもネットワークに何も問い合わせません。オンにした場合に他の読者が見るカードを、そのまま下に表示します。';

  @override
  String get socialNameLabel => 'ニックネーム';

  @override
  String get socialNameHint => '2〜24文字（メールアドレスは使えません）';

  @override
  String get socialBioLabel => '自己紹介（任意）';

  @override
  String get socialAudienceSection => 'プロフィールと投稿を見られる人';

  @override
  String get socialAudienceEveryone => '全員';

  @override
  String get socialAudienceFollowing => 'フォロー中';

  @override
  String get socialAudienceMutual => '相互フォロー';

  @override
  String get socialAudienceEveryoneNote =>
      'このバックエンドでコミュニティをオンにしている人なら誰でも、プロフィール・投稿・順位を見られます。';

  @override
  String get socialAudienceFollowingNote =>
      'あなたが先にフォローした人だけが、プロフィール・投稿・順位を見られます。';

  @override
  String get socialAudienceMutualNote =>
      'あなたがフォローし、相手もフォローし返している人だけが見られます。相手には、フォローし返せるようにニックネームが届きます。';

  @override
  String get socialSwitchesSection => '数値とジャンル以外に表示するもの';

  @override
  String get socialShowPhoto => 'アカウントの写真を表示';

  @override
  String get socialShowSeries => 'よく読む作品名を表示';

  @override
  String get socialShowActivity => '直近14日間の活動を表示';

  @override
  String get socialPreviewSection => '公開される内容のプレビュー';

  @override
  String get socialPreviewHiddenExcluded => '非表示の作品は除外';

  @override
  String socialPreviewLocked(String what) {
    return '$what：非公開';
  }

  @override
  String get socialPreviewPhoto => '写真';

  @override
  String get socialPreviewSeries => '作品名';

  @override
  String get socialPreviewActivity => '活動';

  @override
  String get socialWipeWarning =>
      'コミュニティをオフにすると、公開したプロフィール・投稿・コメント・いいね・フォロー・メッセージ（他の人の会話内も）がすべて削除されます。ブロックは残ります。';

  @override
  String get socialTurnOn => 'コミュニティをオンにする';

  @override
  String get socialTurnOff => 'コミュニティをオフにしてすべて削除';

  @override
  String get socialTabBoards => 'ランキング';

  @override
  String get socialTabFeed => 'フィード';

  @override
  String get socialTabPeople => 'ユーザー';

  @override
  String get socialBoardWeek => '週';

  @override
  String get socialBoardMonth => '月';

  @override
  String get socialBoardAllTime => '通算';

  @override
  String get socialBoardStreak => '連続日数';

  @override
  String get socialYouBadge => 'あなた';

  @override
  String socialChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話',
    );
    return '$_temp0';
  }

  @override
  String socialStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日',
    );
    return '$_temp0';
  }

  @override
  String get socialBoardEmpty => 'まだ誰もランキングにいません';

  @override
  String get socialFeedEmptyTitle => 'まだ投稿はありません';

  @override
  String get socialFeedEmptyMessage => '読者のメモ、レビュー、おすすめがここに表示されます。';

  @override
  String get socialPostKindNote => 'メモ';

  @override
  String get socialPostKindReview => 'レビュー';

  @override
  String get socialPostKindRecommendation => 'おすすめ';

  @override
  String socialSpoilerUpTo(String chapter) {
    return '第$chapter話までのネタバレあり';
  }

  @override
  String get socialSpoilerGeneric => 'ネタバレあり';

  @override
  String get socialSpoilerReveal => 'タップして表示';

  @override
  String get socialFlaggedTitle => '複数の読者が報告した内容';

  @override
  String socialFlaggedReveal(String author) {
    return '$author · タップして表示';
  }

  @override
  String get socialSearchPeopleHint => 'ニックネームで検索…';

  @override
  String get socialSearchNoEmailNotice =>
      'ここにメールアドレスはありません。読者が付けたニックネームで検索してください。';

  @override
  String get socialPeopleFollowingSection => 'フォロー中';

  @override
  String get socialPeopleEmpty => 'まだ誰もフォローしていません。ニックネームで検索するか、ランキングから開いてください。';

  @override
  String get socialSearchNone => '該当するユーザーはいません';

  @override
  String socialAffinityLabel(int percent) {
    return '相性 $percent%';
  }

  @override
  String get socialInCommonSection => '共通';

  @override
  String socialInCommonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '共通の作品 $count 件',
    );
    return '$_temp0';
  }

  @override
  String get socialFollow => 'フォロー';

  @override
  String get socialFollowBack => 'フォローし返す';

  @override
  String get socialFollowing => 'フォロー中';

  @override
  String get socialMutual => '相互';

  @override
  String get socialUnavailableTitle => 'このバックエンドにはコミュニティがありません';

  @override
  String get socialUnavailableBody =>
      'アカウントが接続しているサーバーにはコミュニティ用のテーブルがありません。アプリのほかの機能は通常どおり使えます。';

  @override
  String get socialNeedsAccount => 'コミュニティにはアカウントが必要です。設定からサインインしてください。';

  @override
  String get socialRefusedSnack => '操作を完了できませんでした。';

  @override
  String get socialLoadError => '今はコミュニティを読み込めません。';

  @override
  String get socialRetry => '再試行';

  @override
  String get socialProfileUnavailable => 'プロフィールを表示できません';

  @override
  String get socialProfilePrivate => '非公開のプロフィール';

  @override
  String get socialProfileGenres => 'ジャンル';

  @override
  String get socialProfileActivity => '直近14日間';

  @override
  String get socialProfileSeriesTitles => 'よく読む作品';

  @override
  String get socialStatChapters => '話数';

  @override
  String get socialStatSeries => '作品';

  @override
  String get socialStatStreak => '連続日数';

  @override
  String get socialWrite => '書く';

  @override
  String get socialComposeTitle => '新しい投稿';

  @override
  String get socialComposeBodyHint => 'どう思いましたか？';

  @override
  String get socialComposeSeries => 'シリーズ';

  @override
  String get socialComposeNoSeries => 'シリーズなし';

  @override
  String get socialComposeRating => '評価';

  @override
  String get socialComposeSpoiler => 'ネタバレを含む';

  @override
  String get socialComposeSpoilerChapter => '何話まで（任意）';

  @override
  String get socialComposePublish => '投稿する';

  @override
  String get socialRefusalEmpty => '投稿する前に何か書いてください。';

  @override
  String get socialRefusalTooLong => '文章が長すぎます。';

  @override
  String get socialRefusalHiddenSeries => 'このシリーズは非表示です。コミュニティでは名前を出せません。';

  @override
  String get socialRefusalNeedsSeries => 'レビューやおすすめにはシリーズが必要です。選んでください。';

  @override
  String get socialRefusalNeedsRating => '1〜10で評価を選んでください。';

  @override
  String socialCommentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'コメント $count 件',
      zero: 'コメントする',
    );
    return '$_temp0';
  }

  @override
  String get socialCommentsTitle => 'コメント';

  @override
  String get socialCommentsEmpty => 'まだコメントはありません';

  @override
  String get socialCommentHint => 'コメントを書く…';

  @override
  String socialReplyHint(String author) {
    return '$author さんに返信…';
  }

  @override
  String get socialReply => '返信';

  @override
  String get socialCancelReply => '返信をやめる';

  @override
  String get socialSend => '送信';

  @override
  String get socialLike => 'いいね';

  @override
  String get socialMoreActions => 'その他の操作';

  @override
  String get socialMute => 'ミュート';

  @override
  String get socialUnmute => 'ミュートを解除';

  @override
  String get socialFollowersSection => 'フォロワー';

  @override
  String get socialMutedNote => 'ミュート中：この人の投稿とコメントはここに表示されません。';

  @override
  String get socialRemovePost => '投稿を削除';

  @override
  String get socialRemovePostConfirm =>
      '投稿はコメントといいねと一緒に消えます。投稿は編集できないので、必要なら書き直してください。';

  @override
  String get socialRemoveComment => '削除';

  @override
  String get socialUnknownReader => '読者';

  @override
  String get socialSeriesPostsTitle => 'コミュニティで';

  @override
  String get socialSeriesPostsEmpty => 'まだ誰も話題にしていません';

  @override
  String get socialSeriesTalk => 'コミュニティで話す';

  @override
  String socialBlockPerson(String name) {
    return '$nameをブロック';
  }

  @override
  String get socialBlockAction => 'ブロック';

  @override
  String get socialBlockConfirm =>
      'お互いのプロフィール、投稿、コメントは表示されなくなり、メッセージも送れなくなります。2人の間のフォロー関係は解除されます。相手には通知されません。';

  @override
  String get socialBlockedSnack => 'ブロックしました。';

  @override
  String get socialReport => '報告';

  @override
  String get socialReportIntro => 'なぜ報告しますか？報告された人には知らされず、報告には本文のコピーが添えられます。';

  @override
  String get socialReportReasonSpam => 'スパムまたは宣伝';

  @override
  String get socialReportReasonHarassment => '嫌がらせまたはしつこい行為';

  @override
  String get socialReportReasonSpoiler => '警告のないネタバレ';

  @override
  String get socialReportReasonInappropriate => '不適切な内容';

  @override
  String get socialReportReasonOther => 'その他';

  @override
  String get socialReportNoteHint => 'メモ（任意）';

  @override
  String get socialReportSend => '送信';

  @override
  String get socialReportSent => '報告を送信しました。';

  @override
  String get messagesTitle => 'メッセージ';

  @override
  String get messagesWrite => 'メッセージを送る';

  @override
  String get messagesEmpty => '会話はまだありません。相手のプロフィールからメッセージを送ってみましょう。';

  @override
  String get messagesThreadEmpty => 'まだメッセージはありません。';

  @override
  String get messagesHint => 'メッセージを入力';

  @override
  String get messagesSend => '送信';

  @override
  String get messagesUnknownPerson => 'ある読者';

  @override
  String get messagesDeleteTitle => 'メッセージを削除しますか？';

  @override
  String get messagesDeleteBody => '二人の画面から消えます。';

  @override
  String get messagesDeleteAction => '削除';

  @override
  String messagesExtensionMine(String folder) {
    return '「$folder」の期限延長をリクエストしました。';
  }

  @override
  String messagesExtensionTheirs(String name, String folder) {
    return '$nameさんが「$folder」の期限延長を希望しています。';
  }

  @override
  String get messagesRenew => '更新';

  @override
  String messagesRenewed(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '共有を$dateStringまで更新しました。';
  }

  @override
  String get messagesAskMore => '期限延長をリクエスト';

  @override
  String get messagesAskSent => 'リクエストを送信しました。';

  @override
  String get privacyTitle => 'プライバシーとコミュニティ';

  @override
  String get privacyEntryNote => 'コミュニティ、プロフィールの公開範囲、メッセージ、ブロックした人';

  @override
  String get privacyOffNote =>
      'コミュニティがオフの間、端末から何も送信されません。以下の設定はオンにした時から有効になります。';

  @override
  String get privacyNeedsName =>
      'コミュニティをオンにするにはニックネームとアカウントが必要です。開く画面でニックネームを決めてください。';

  @override
  String get privacyMessagesSection => 'メッセージを送れる人';

  @override
  String get privacyMessagesNobody => '誰も送れない';

  @override
  String get privacyBlockedSection => 'ブロックした人';

  @override
  String get privacyBlockedEmpty => 'ブロックしている人はいません。';

  @override
  String get privacyBlockedPerson => 'ブロックした人';

  @override
  String get privacyUnblock => 'ブロック解除';

  @override
  String messageNotificationTitle(String sender) {
    return '$senderさんからの新着メッセージ';
  }

  @override
  String driveExpiryNoticeTitle(String owner) {
    return '$owner さんのライブラリがまもなく期限切れになります';
  }

  @override
  String driveExpiryNoticeText(String folder, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '「$folder」は $dateString に期限切れになります。Kagami を開いて延長を依頼してください。';
  }

  @override
  String get settingsBackupFolder => 'コピーの保存フォルダ';

  @override
  String settingsBackupFolderChosen(String path) {
    return 'アプリ内の保存場所に加えて、自動コピーを $path にも保存します';
  }

  @override
  String get settingsBackupFolderNone => 'なし：コピーはアプリ内にのみ保存されます';

  @override
  String get settingsBackupFolderRefused =>
      'このフォルダはライブラリのソース内にあります。ライブラリは共有され、コピーには個人データが含まれます。別のフォルダを選んでください。';

  @override
  String get driveShareDownloadOption => 'ダウンロードも許可';

  @override
  String get driveShareDownloadNote =>
      'これはアプリ間の取り決めであり、保護ではありません。フォルダにアクセスできる人は、Drive、ウェブサイト、別のアプリからファイルをダウンロードできます。受け取る側のKagamiは、ここで許可した場合のみダウンロードします。';

  @override
  String get driveShareRowDownload => 'ダウンロード可';

  @override
  String get driveShareRowStreaming => 'ストリーミングのみ';

  @override
  String get driveShareDownloadAllow => 'ダウンロードを許可';

  @override
  String get driveShareDownloadDeny => 'ストリーミングのみ';

  @override
  String get driveShareDownloadUnavailable =>
      'このバックエンドはまだダウンロード許可に対応していません。共有はストリーミングのみのままです。';

  @override
  String get driveReceivedCanDownload => '閲覧とダウンロードが可能';

  @override
  String get driveReceivedStreamOnly => 'ストリーミングでの閲覧のみ';

  @override
  String get seriesArchiveOwn => '自分のDriveにアーカイブ';

  @override
  String get seriesArchiveOwnSiteMissing =>
      'このシリーズのサイトが必要です。設定 → サイトからインストールしてください。他人のライブラリのサイトは自動ではインストールされません。';

  @override
  String get seriesBringData => '自分のデータをここに移す';

  @override
  String get seriesBringDataPick => 'どのシリーズから？';

  @override
  String get seriesBringDataEmpty => '移せるあなたのデータを持つシリーズがライブラリにありません。';

  @override
  String seriesBringDataBody(String from, String to, int matched) {
    String _temp0 = intl.Intl.pluralLogic(
      matched,
      locale: localeName,
      other: '同じ番号の既読話 # 件',
    );
    return '「$from」→「$to」。状態、評価、メモ、コレクションが移動先のシリーズに移り、$_temp0も一緒に移ります。既存のデータと統合され、既読はまとめられ、それ以外は新しい方が優先されます。「$from」はデータなしでライブラリに残ります。';
  }

  @override
  String seriesBringDataLost(int lost) {
    String _temp0 = intl.Intl.pluralLogic(
      lost,
      locale: localeName,
      other: '同じ番号の話がない既読話が # 件あります。移されず、位置・履歴・ブックマークは失われます。',
    );
    return '$_temp0';
  }

  @override
  String get seriesBringDataConfirm => 'データを移す';

  @override
  String seriesBringDataDone(String title) {
    return '「$title」にデータを移しました。';
  }

  @override
  String get seriesBringDataNoChapters =>
      'いま二つのシリーズのどちらかの話を読み込めません。少ししてからもう一度お試しください。';

  @override
  String sitesUnconfirmed(String name) {
    return '確認するまで $name のままです';
  }

  @override
  String sitesConfirmReplace(String name) {
    return '$name を置き換える';
  }

  @override
  String get serverLinkTrust =>
      'このサーバーの管理者はあなたの Drive に書き込めます。Google が求める許可は管理者の手に残ります。信頼できるサーバーだけを連携してください。';

  @override
  String get serverErrorUpdateServer =>
      'このサーバーは更新が必要です。チケットに対応するまで、あなたのログイン情報は送られません。';

  @override
  String get serverErrorTicketsUnavailable =>
      'バックエンドはサーバー用のチケットを発行しません。他の人のサーバーにはログイン情報を送りません。';

  @override
  String get serverErrorImpostor =>
      'このサーバーは、別のアドレスで連携済みのサーバーだと名乗っています。何も送りません。';

  @override
  String get serverErrorOtherServer => 'このアドレスでは別のサーバーが応答しています。連携し直してください。';

  @override
  String get serverErrorNotOwner =>
      'この Drive フォルダはあなたのものではありません。サーバーは何もゴミ箱へ移しません。';

  @override
  String get sitesOriginBuiltIn => '内蔵';

  @override
  String get sitesOriginCatalog => 'カタログ';

  @override
  String get sitesOriginUser => '自分のサイト';

  @override
  String get sitesCatalogBroken => '故障中';

  @override
  String sitesCatalogBrokenWith(String message) {
    return '故障中: $message';
  }

  @override
  String get sitesNeedsNewer => 'Kagami を新しいバージョンに更新する必要があります';

  @override
  String get sitesCatalogSection => 'サイトカタログ';

  @override
  String get sitesCatalogUse => 'カタログを使う';

  @override
  String get sitesCatalogOff => 'オフ: 内蔵サイトと自分のサイトだけが有効になり、アプリはこのための通信を行いません。';

  @override
  String sitesCatalogIssue(int serial, String date) {
    return '第 $serial 版（$date）';
  }

  @override
  String sitesCatalogChecked(String when) {
    return '最終確認: $when';
  }
}
