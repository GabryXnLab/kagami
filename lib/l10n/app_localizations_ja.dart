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
  String seriesCaughtUpMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '端末内の話は読み終えました。告知済みの$count話が未ダウンロードです。',
      one: '端末内の話は読み終えました。告知済みの1話が未ダウンロードです。',
    );
    return '$_temp0';
  }

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
      '対応サイトでタイトルを検索するか、作品のリンクを貼り付けてください。Kagamiがサイトから、メタデータ、表紙、全話の一覧とあわせてライブラリにダウンロードします。';

  @override
  String get archiveSearchHint => 'タイトルでマンガを検索';

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
  String archiveKnown(int archived, int total) {
    return 'すでにライブラリにあります: 全$total話中$archived話。ある話はスキップされます。';
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
  String get archiveChapterNumberHint => 'サイトと同じ話数';

  @override
  String archivePickedCount(int count) {
    return '$count話選択中';
  }

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
  String get archiveDownloadFrom => '選んだ話からダウンロード';

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
      'ここでダウンロードした連載中の作品は定期的に再確認され、新しい話だけが同じ保存先に追加されます。サーバーの作品はサーバーが追跡します。';

  @override
  String get archiveCheckDaily => '毎日確認';

  @override
  String get archiveCheckManual => '手動のみ';

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
  String archiveStartIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count話。',
      one: '1話。',
    );
    return '$_temp0すべてダウンロードするか、開始する話を選んでください。それより前の話はリーダーの一覧に残りますが、ページはありません。';
  }

  @override
  String get archiveStartNoMatch => 'この番号の話はありません。';

  @override
  String archiveStartFrom(String title, int remaining) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: '$remaining話',
      one: '1話',
    );
    return '「$title」以降: $_temp0。';
  }

  @override
  String get archiveStartNone => '話が選択されていません。すべてダウンロードできます。';

  @override
  String get archiveStartAll => 'すべてダウンロード';

  @override
  String get archiveStartHere => 'ここから';

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
  String get serverClear => '消去';

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
  String get serverOngoingTitle => 'サーバー上の連載中の作品';

  @override
  String serverOngoingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '追跡中: $count件',
      zero: 'まだありません',
    );
    return '$_temp0';
  }

  @override
  String get serverOngoingCheckOff => '確認はオフ';

  @override
  String serverOngoingCheckAt(String clock) {
    return '$clockに確認';
  }

  @override
  String serverOngoingSubtitle(String count, String check) {
    return '$count · $check。タップで今すぐ確認';
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
      'このコマンドをコンピューターのターミナルに貼り付けてください。Driveへの権限が含まれているので、誰にも送らないでください。';

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
      '端末にあるもの(例: reading/backupのデータのコピー)がDriveにアップロードされます。ライブラリのインデックスはサーバーのものが維持されます。';

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
  String get settingsAutoBackup => 'ライブラリへの自動コピー';

  @override
  String get settingsAutoBackupNote =>
      '1日1回reading/backup/に保存され、同期でマンガと一緒にDriveに送られます';

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
      'このビルドにはFirebaseがありません。データは端末内に残ります';

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
  String get settingsAccountSignOutNote => '最新の読書データを送信してからログアウトします';

  @override
  String get settingsAccountForget => 'コピーの保存をやめる';

  @override
  String get settingsAccountForgetNote => 'アカウントからデータを削除します。この端末のデータはそのまま残ります';

  @override
  String get settingsAccountErrorNote => 'この端末のデータには影響していません';

  @override
  String get settingsAccountForgetSheetTitle => 'アカウントからデータを削除しますか?';

  @override
  String get settingsAccountForgetExplain =>
      'あなた用に保存されているコピーが消え、ログアウトされます。この端末の状態、評価、履歴、コレクションはそのまま残りますが、ほかの端末では見られなくなります。';

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
  String get settingsBackupsTitle => 'ライブラリ内のコピー';

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
  String get homeUpdatesSubtitle => '同期済みでまだ読んでいない話';

  @override
  String homeLatestChapter(String number) {
    return '第$number話';
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
  String get shellTabCollections => 'コレクション';

  @override
  String get shellTabMore => 'その他';

  @override
  String get moreTitle => 'その他';

  @override
  String get moreSectionLibrary => 'ライブラリ';

  @override
  String get moreSectionReading => 'あなたの読書';

  @override
  String get moreSectionPrivacy => 'プライバシー';

  @override
  String get moreSectionApp => 'アプリ';

  @override
  String get moreDownload => 'マンガをダウンロード';

  @override
  String get moreDownloadSubtitle => 'タイトルを検索、またはリンクを貼り付け';

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
  String get moreSettings => '設定';

  @override
  String get moreSettingsSubtitle => '外観、ライブラリ、読書、バックアップ';

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
}
