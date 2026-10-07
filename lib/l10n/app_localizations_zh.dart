// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get seriesShelfNone => '无状态';

  @override
  String get seriesShelfPlanned => '想读';

  @override
  String get seriesShelfReading => '在读';

  @override
  String get seriesShelfPaused => '暂停';

  @override
  String get seriesShelfCompleted => '已读完';

  @override
  String get seriesShelfDropped => '已弃坑';

  @override
  String get seriesReleaseOngoing => '连载中';

  @override
  String get seriesReleaseCompleted => '已完结';

  @override
  String get seriesReleaseHiatus => '休刊中';

  @override
  String get seriesReleaseCancelled => '已中止';

  @override
  String get seriesReleaseUnknown => '状态未知';

  @override
  String get seriesNotFound => '未找到该作品。';

  @override
  String get seriesOfflineTitle => 'Drive 上的章节';

  @override
  String get seriesOfflineMessage => '没有网络时看不到这部作品的章节列表，网络恢复后会自动显示。';

  @override
  String get seriesNoIndexTitle => '没有索引';

  @override
  String get seriesNoIndexMessage => '这部作品没有 index.json：请用写入它的归档工具重新生成索引。';

  @override
  String get seriesNoChaptersTitle => '没有章节';

  @override
  String get seriesNoChaptersMessage => '没有章节符合当前的搜索和筛选条件。';

  @override
  String seriesDownloadAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '下载 $count 个章节？',
      one: '下载 1 个章节？',
    );
    return '$_temp0';
  }

  @override
  String get seriesDownloadAllMessage => '目前从 Drive 阅读的所有章节都会下载到手机，之后没有网络也能阅读。';

  @override
  String get seriesDownload => '下载';

  @override
  String seriesCleanupRemote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 个已读章节仍在 Drive 上',
      one: '有 1 个已读章节仍在 Drive 上',
    );
    return '$_temp0';
  }

  @override
  String seriesCleanupLocal(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个已读章节占用 $size',
      one: '1 个已读章节占用 $size',
    );
    return '$_temp0';
  }

  @override
  String seriesDownloadFailed(String error) {
    return '下载失败：$error。点按重试';
  }

  @override
  String get seriesDownloadWaiting => '等待网络，恢复后自动继续。点按取消';

  @override
  String get seriesDownloadQueued => '排队中。点按取消';

  @override
  String get seriesDownloadCancel => '取消下载';

  @override
  String get seriesPlaceLocal => '在手机上';

  @override
  String get seriesPlaceDrive => '在 Drive 上';

  @override
  String get seriesPlaceMixed => '手机和 Drive';

  @override
  String get seriesMuteTooltipOn => '新章节通知已静音';

  @override
  String get seriesMuteTooltipOff => '新章节通知已开启';

  @override
  String get seriesMuteUnmuted => '已重新开启新章节通知。';

  @override
  String get seriesMuteMuted => '已静音新章节通知。';

  @override
  String seriesCaughtUpMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '手机上已有的都读完了：还有 $count 个已公布的章节未下载。',
      one: '手机上已有的都读完了：还有 1 个已公布的章节未下载。',
    );
    return '$_temp0';
  }

  @override
  String get seriesCaughtUpAll => '已全部读完。';

  @override
  String get seriesResumeToContinue => '继续阅读';

  @override
  String get seriesResumeToStart => '开始阅读';

  @override
  String get seriesResumeHalfway => '读到一半';

  @override
  String seriesResumePage(int page, int total) {
    return '第 $page 页，共 $total 页';
  }

  @override
  String get seriesContinue => '继续';

  @override
  String get seriesStart => '开始';

  @override
  String get seriesResume => '接着读';

  @override
  String get seriesNextChapter => '下一章节';

  @override
  String get seriesFigureChapters => '章节';

  @override
  String get seriesFigureRead => '已读';

  @override
  String get seriesFigureProgress => '进度';

  @override
  String get seriesFigureRating => '评分';

  @override
  String get seriesMyShelf => '我的书架';

  @override
  String get seriesFavoriteOn => '已收藏';

  @override
  String get seriesFavoriteOff => '收藏';

  @override
  String get seriesRatingButton => '评分';

  @override
  String seriesRatingOutOfTen(int rating) {
    return '$rating/10';
  }

  @override
  String get seriesCollections => '合集';

  @override
  String get seriesNotes => '笔记';

  @override
  String get seriesRatingSheetTitle => '你打几分？';

  @override
  String get seriesNotesHint => '读到哪儿了，有什么想法……';

  @override
  String get seriesSave => '保存';

  @override
  String get seriesRatingWord1 => '极差';

  @override
  String get seriesRatingWord2 => '很差';

  @override
  String get seriesRatingWord3 => '较差';

  @override
  String get seriesRatingWord4 => '平庸';

  @override
  String get seriesRatingWord5 => '及格';

  @override
  String get seriesRatingWord6 => '还行';

  @override
  String get seriesRatingWord7 => '不错';

  @override
  String get seriesRatingWord8 => '很棒';

  @override
  String get seriesRatingWord9 => '优秀';

  @override
  String get seriesRatingWord10 => '神作';

  @override
  String get seriesRatingNone => '未评分';

  @override
  String get seriesRatingHint => '点按或滑动';

  @override
  String seriesRatingBefore(int rating) {
    return '之前：$rating';
  }

  @override
  String get seriesRatingRemove => '清除';

  @override
  String get seriesRatingSave => '保存评分';

  @override
  String get seriesSynopsis => '简介';

  @override
  String get seriesGenres => '类型';

  @override
  String get seriesTags => '标签';

  @override
  String get seriesCreators => '作者';

  @override
  String seriesMoreTags(int count) {
    return '另外 $count 个';
  }

  @override
  String get seriesPaceToRead => '待读';

  @override
  String seriesPaceCaption(int chapters, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      chapters,
      locale: localeName,
      other: '$chapters 个章节',
      one: '1 个章节',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages 页',
      one: '1 页',
    );
    return '$_temp0，$_temp1';
  }

  @override
  String get seriesPaceNext => '下一章节';

  @override
  String get seriesPaceNextCaption => '根据最近几章的更新节奏';

  @override
  String seriesDurationMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String seriesDurationHours(int count) {
    return '$count 小时';
  }

  @override
  String seriesDurationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天',
      one: '1 天',
    );
    return '$_temp0';
  }

  @override
  String get seriesWhenLate => '已延期';

  @override
  String get seriesWhenExpected => '应已更新';

  @override
  String get seriesWhenToday => '今天';

  @override
  String get seriesWhenTomorrow => '明天';

  @override
  String seriesWhenInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天后',
      one: '1 天后',
    );
    return '$_temp0';
  }

  @override
  String seriesWhenInWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 周后',
      one: '1 周后',
    );
    return '$_temp0';
  }

  @override
  String get seriesShowLess => '收起';

  @override
  String get seriesShowMore => '展开全文';

  @override
  String get seriesChaptersTitle => '章节';

  @override
  String seriesChaptersOf(int total) {
    return '共 $total 个';
  }

  @override
  String get seriesSearchChapter => '搜索章节…';

  @override
  String get seriesSortNewest => '从最新开始';

  @override
  String get seriesSortOldest => '从第一章开始';

  @override
  String get seriesMarkAll => '全部标记';

  @override
  String get seriesDownloadFromDrive => '从 Drive 下载';

  @override
  String get seriesFreeSpace => '释放空间';

  @override
  String get seriesFilterUnread => '未读';

  @override
  String get seriesFilterDownloaded => '已下载';

  @override
  String get seriesFilterAll => '全部';

  @override
  String seriesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选 $count 项',
      one: '已选 1 项',
    );
    return '$_temp0';
  }

  @override
  String get seriesMarkReadMany => '标为已读';

  @override
  String get seriesMarkUnread => '标为未读';

  @override
  String get seriesMarkRead => '标为已读';

  @override
  String get seriesMarkReadThrough => '标为已读至此';

  @override
  String get seriesSimilar => '类似作品';

  @override
  String get seriesChapterNotDownloaded => '未下载';

  @override
  String seriesChapterPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 页',
      one: '1 页',
    );
    return '$_temp0';
  }

  @override
  String get seriesDownloadToPhone => '下载到手机';

  @override
  String get readerSeriesUnavailable => '作品不可用。';

  @override
  String get readerNoPagesIndex => '这部作品没有 pages.json：请用写入它的归档工具重新生成索引。';

  @override
  String get readerSeriesOffline => '没有网络时无法打开这部作品：它的页面列表在 Drive 上。网络恢复后即可打开。';

  @override
  String get readerChapterNotOnPhone => '这个章节还不在手机上。同步可能只完成了一半，请稍后再试。';

  @override
  String get readerChapterNoPages => '这个章节没有可阅读的页面。';

  @override
  String get readerPagesNotOnPhone =>
      '这个章节的页面还不在手机上。索引里有记录，但文件还没到：需要由同步的文件夹把它们带过来。';

  @override
  String get readerMarkEarlierTitle => '把之前的章节标为已读？';

  @override
  String readerMarkEarlierBody(int count, String chapter) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '你读完了$chapter。之前的 $count 个章节仍显示为未读：如果你已在别处读过，可以把它们一并标为已读。',
      one: '你读完了$chapter。上一个章节仍显示为未读：如果你已在别处读过，可以把它标为已读。',
    );
    return '$_temp0';
  }

  @override
  String readerMarkEarlierConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '将这 $count 章全部标为已读',
      one: '将上一章标为已读',
    );
    return '$_temp0';
  }

  @override
  String get readerMarkEarlierDecline => '保持未读';

  @override
  String readerBookmarkAdded(int page) {
    return '已为第 $page 页添加书签';
  }

  @override
  String get readerChapters => '章节';

  @override
  String get readerBookmarks => '书签';

  @override
  String get readerNoBookmarks => '还没有书签';

  @override
  String get readerNoBookmarksHint => '书签会记住某一页的位置；章节的阅读位置则由续读功能自动记住。';

  @override
  String readerBookmarkPage(int page) {
    return '第 $page 页';
  }

  @override
  String get readerBookmarkRemove => '删除';

  @override
  String get readerToTop => '回到顶部';

  @override
  String get readerPageNotFromDrive => '页面未能从 Drive 取得';

  @override
  String get readerPageUnreadable => '页面无法读取';

  @override
  String get readerPageNotSynced => '页面尚未同步';

  @override
  String get readerPageNotDownloaded => '页面尚未下载';

  @override
  String get readerPageOfflineHint => '没有网络。网络恢复后会自动加载。';

  @override
  String get readerRetryNow => '立即重试';

  @override
  String get readerLastChapterOnPhone => '这是手机上的最后一个章节。';

  @override
  String get readerNextChapter => '下一章节';

  @override
  String get readerContinue => '继续';

  @override
  String get readerBookmarkThisPage => '为这一页添加书签';

  @override
  String get readerHowToRead => '阅读设置';

  @override
  String get readerPreviousChapter => '上一章节';

  @override
  String get readerNextChapterTooltip => '下一章节';

  @override
  String get readerSearchChapter => '搜索章节…';

  @override
  String get readerNewestFirst => '从最新开始';

  @override
  String get readerOldestFirst => '从第一章开始';

  @override
  String readerReadingNow(String current, int total) {
    return '正在阅读：第 $current 个，共 $total 个章节';
  }

  @override
  String get readerMode => '阅读模式';

  @override
  String get readerModeStrip => '连续阅读';

  @override
  String get readerModePage => '分页阅读';

  @override
  String get readerDirection => '阅读方向';

  @override
  String get readerDirectionLtr => '从左到右';

  @override
  String get readerDirectionRtl => '从右到左';

  @override
  String get readerFit => '适应方式';

  @override
  String get readerBackground => '背景';

  @override
  String get readerBrightness => '亮度';

  @override
  String get readerAutoScroll => '自动滚动';

  @override
  String get readerAutoScrollOff => '关闭';

  @override
  String readerAutoScrollRate(int rate) {
    return '$rate 页/分钟';
  }

  @override
  String get readerShowPageNumber => '页码';

  @override
  String get readerShowProgress => '进度条';

  @override
  String get readerShowScrollTop => '回到顶部按钮';

  @override
  String get readerKeepAwake => '保持屏幕常亮';

  @override
  String get readerDoublePage => '双页并排';

  @override
  String get readerLockRotation => '锁定屏幕旋转';

  @override
  String get archiveTitle => '下载漫画';

  @override
  String get archiveIntro =>
      '在支持的网站上按标题搜索，或粘贴作品或其某一章的链接：Kagami 会从网站把这部作品连同元数据、封面和完整的章节列表下载到书库中。也可以只保存它的卡片，不下载章节。';

  @override
  String get archiveSearchHint => '按标题搜索漫画';

  @override
  String get archiveFilterOngoing => '连载中';

  @override
  String get archiveFilterCompleted => '已完结';

  @override
  String get archiveFilterNotInLibrary => '不在书库中';

  @override
  String get archiveInLibrary => '已在书库中';

  @override
  String archiveResultsFiltered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个结果被筛选隐藏',
    );
    return '$_temp0';
  }

  @override
  String get archiveClear => '清除';

  @override
  String get archivePaste => '粘贴';

  @override
  String get archiveReading => '正在读取作品…';

  @override
  String get archiveVerify => '检查作品';

  @override
  String archiveSeriesSummary(String site, int count, String status) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个章节',
      one: '1 个章节',
    );
    return '$site · $_temp0 · $status';
  }

  @override
  String get archiveWhatSection => '下载内容';

  @override
  String get archiveModeAll => '全部';

  @override
  String get archiveModeFrom => '从某章起';

  @override
  String get archiveModePick => '自选';

  @override
  String get archiveModeAllHint => '全部章节。以后再下载一次，只会补上新增或损坏的章节。';

  @override
  String get archiveModeFromHint => '从所选章节起下载：之前的章节仍会留在作品的章节列表里，标为未下载。';

  @override
  String get archiveModePickHint => '只下载点选的章节。其余章节仍在列表里，标为未下载。';

  @override
  String get archiveChooseTitle => '下载什么';

  @override
  String get archiveModeAhead => '边读边下';

  @override
  String get archiveModeAllLine => '每一话，只下一次';

  @override
  String archiveModeAheadLine(int count) {
    return '先备好 $count 话，每读一话再下一话';
  }

  @override
  String get archiveModeFromLine => '从某一话到最新一话';

  @override
  String get archiveModePickLine => '只下你点选的';

  @override
  String archiveModeAheadHint(int count) {
    return '从所选的一话开始下载 $count 话。每读完一话就会下载新的一话，让你始终有 $count 话可读，直到系列结束；网站发布新话时也会这样送达。';
  }

  @override
  String get archiveModeAheadUnavailable => '这个网站无法使用：每次访问都要求浏览器验证，手机无法自行通过。';

  @override
  String get archiveModeAheadServer =>
      '已连接的服务器还不支持“边读边下”：新版本发布后一小时内会自动更新。在此之前，此模式由手机下载。';

  @override
  String get archiveChapterSearch => '按编号或标题搜索';

  @override
  String get archiveNewestFirst => '最新在前';

  @override
  String get archiveOldestFirst => '从第一话开始';

  @override
  String get archiveChooseStart => '点选要开始的一话。';

  @override
  String get archiveSelectMissing => '缺少的';

  @override
  String get archiveRangeHint => '长按某一话，可同时选中它与上次点选之间的所有话。';

  @override
  String get archivePickNone => '未选择任何话';

  @override
  String archiveSummaryChapters(int count, String where) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 话',
    );
    return '$_temp0 · $where';
  }

  @override
  String archiveSummaryAhead(int count, String where) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '先下 $count 话',
    );
    return '$_temp0，之后每读一话再下一话 · $where';
  }

  @override
  String archiveDownloadAhead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '下载 $count 话，之后边读边下',
    );
    return '$_temp0';
  }

  @override
  String archiveInLibraryCount(int archived, int total) {
    return '已在书库：$total 话中的 $archived 话';
  }

  @override
  String get archiveChapterInLibrary => '已在书库';

  @override
  String get archiveChapterStart => '从这里开始';

  @override
  String get archiveChapterLater => '阅读时送达';

  @override
  String get archiveAdvanced => '高级';

  @override
  String archiveAdvancedLine(String pause) {
    return '请求间隔：$pause';
  }

  @override
  String get archiveReopen => '选择要下载的内容';

  @override
  String get archiveSelectAll => '全选';

  @override
  String get archiveSelectNone => '全不选';

  @override
  String get archiveWhereSection => '保存位置';

  @override
  String get archiveWhereServer => '服务器';

  @override
  String get archiveWhereDrive => 'Drive';

  @override
  String get archiveWhereDriveAndPhone => 'Drive 和手机';

  @override
  String get archiveWherePhone => '手机';

  @override
  String get archiveWhereDriveHint =>
      '保存到书库的 Drive 文件夹。页面会先经过手机，Drive 收到后立即从手机上移除：可以在线阅读，也可以之后再下载。';

  @override
  String get archiveWhereDriveAndPhoneHint =>
      '保存到书库的 Drive 文件夹，章节同时保留在手机上，没有网络也能阅读。';

  @override
  String get archiveWherePhoneHint =>
      '保存在手机上的漫画文件夹或应用的专用空间。连接 Drive 后可以直接下载到那里。';

  @override
  String archiveServerHint(String name, String folder, String other) {
    String _temp0 = intl.Intl.selectLogic(other, {
      'other': ' 注意：这不是应用读取的文件夹。',
      'same': '',
    });
    return '由“$name”下载并上传到 Drive 的“$folder”，手机关机也不受影响。连载中的作品由服务器跟进。$_temp0';
  }

  @override
  String get archiveDelaySection => '请求间隔';

  @override
  String get archiveDelayNone => '无';

  @override
  String archiveDelaySeconds(String seconds) {
    return '$seconds 秒';
  }

  @override
  String get archiveDelayHint => '网站不喜欢连续高频下载：稍作停顿可以避免被封锁。';

  @override
  String get archiveDownloadAll => '下载整部作品';

  @override
  String archiveDownloadPicked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '下载 $count 个章节',
      one: '下载 1 个章节',
    );
    return '$_temp0';
  }

  @override
  String archiveNoResults(String site) {
    return '在 $site 上没有结果。';
  }

  @override
  String archiveChaptersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个章节',
      one: '1 个章节',
    );
    return '$_temp0';
  }

  @override
  String archiveVerifySite(String site) {
    return '验证 $site';
  }

  @override
  String get archiveVerifySiteHint => '网站需要确认你是真人：点按打开验证，然后在那里也搜索一下';

  @override
  String get archiveStatusOngoing => '连载中';

  @override
  String get archiveStatusCompleted => '已完结';

  @override
  String get archiveStatusHiatus => '休刊中';

  @override
  String get archiveStatusCancelled => '已中止';

  @override
  String get archiveStatusUnknown => '状态未知';

  @override
  String get archiveErrChallenge => '网站要求进行验证，无法在这里完成。';

  @override
  String get archiveErrOffline => '没有网络：网站无响应。';

  @override
  String get archiveErrVerifyIncomplete => '网站验证未完成。';

  @override
  String archiveQueuedSnack(String title) {
    return '“$title”已加入队列。关闭屏幕后也会继续。';
  }

  @override
  String archiveQueuedServerSnack(String title, String server) {
    return '“$title”已加入“$server”的队列。手机关机也没关系。';
  }

  @override
  String get archiveServerFallbackName => '服务器';

  @override
  String get archiveDownloads => '下载';

  @override
  String get archiveClearHistory => '清空';

  @override
  String get archiveQueueStopped => '队列已停止';

  @override
  String get archiveQueueResumeHint => '会自动继续；点按可立即开始';

  @override
  String archiveJobAutomatic(String destination) {
    return '新章节 · $destination';
  }

  @override
  String archiveJobQueued(String destination) {
    return '排队中 · $destination';
  }

  @override
  String get archiveRemoveFromQueue => '移出队列';

  @override
  String archiveHistoryLine(String when, String message) {
    return '$when · $message';
  }

  @override
  String get archiveRecent => '最近下载';

  @override
  String archiveRecentAll(int count) {
    return '全部（$count）';
  }

  @override
  String get archiveRecentFailed => '失败';

  @override
  String get archiveFollowedTitle => '关注的作品';

  @override
  String archiveFollowedProblems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个需处理',
    );
    return '$_temp0';
  }

  @override
  String archiveRecentLineRuns(String when, int runs, String message) {
    return '$when · $runs 次下载 · $message';
  }

  @override
  String get archiveRetry => '重试';

  @override
  String archiveJobAhead(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 话',
    );
    return '边读边下：$_temp0 · $destination';
  }

  @override
  String get archiveSites => '支持的网站';

  @override
  String get archiveMoreSites => '更多网站即将支持：新的来源会在后续更新中加入。';

  @override
  String archiveLinkCopied(String url) {
    return '已将 $url 复制到剪贴板。';
  }

  @override
  String get archiveTracked => '连载中的作品';

  @override
  String get archiveTrackedIntro =>
      '从这里下载的连载中作品会定期检查：只下载新章节，保存到同一位置。服务器上的作品由服务器跟进。';

  @override
  String get archiveCheckDaily => '每天检查';

  @override
  String get archiveCheckManual => '仅手动';

  @override
  String archiveCheckAt(String time) {
    return '每天 $time，应用关闭时也会检查';
  }

  @override
  String get archiveCheckTime => '时间';

  @override
  String get archiveCheckTimeHelp => '检查时间';

  @override
  String get archiveWifiOnly => '仅限 Wi-Fi';

  @override
  String get archiveWifiOnlyOn => '等待不按流量计费的网络';

  @override
  String get archiveWifiOnlyOff => '移动数据也可以';

  @override
  String get archiveCheckNow => '立即检查';

  @override
  String get archiveNoTracked => '暂时没有要跟进的作品';

  @override
  String archiveTrackedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '跟进 $count 部作品',
      one: '跟进 1 部作品',
    );
    return '$_temp0';
  }

  @override
  String archiveTrackedLine(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已知 $count 个章节',
      one: '已知 1 个章节',
    );
    return '$_temp0 · $destination';
  }

  @override
  String archiveTrackedLineChecked(int count, String destination, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已知 $count 个章节',
      one: '已知 1 个章节',
    );
    return '$_temp0 · $destination · $when检查过';
  }

  @override
  String archiveTrackedAhead(int count, String destination) {
    return '边读边下，备好 $count 话 · $destination';
  }

  @override
  String get archiveStopFollowing => '不再跟进';

  @override
  String archiveCheckQueued(String names) {
    return '$names有新章节';
  }

  @override
  String archiveCheckRemoved(String names) {
    return '$names现已完结';
  }

  @override
  String archiveCheckFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 部无法访问',
      one: '1 部无法访问',
    );
    return '$_temp0';
  }

  @override
  String get archiveCheckSeparator => '；';

  @override
  String archiveCheckReport(String parts) {
    return '$parts。';
  }

  @override
  String get archiveNoNewChapters => '没有新章节。';

  @override
  String get archiveNoConnection => '没有网络。';

  @override
  String get archiveForgetTitle => '不再跟进？';

  @override
  String archiveForgetBody(String title) {
    return '“$title”的新章节将不再自动下载。已下载的章节会保留。';
  }

  @override
  String get archiveCancel => '取消';

  @override
  String get archiveForgetConfirm => '不再跟进';

  @override
  String get archiveStartNoMatch => '没有这个编号的章节。';

  @override
  String get browserTitle => '网站验证';

  @override
  String get browserPhoneOnly => '验证只能在手机上进行。';

  @override
  String get browserInstructionsChapters =>
      '网站需要确认你是真人。请完成验证：章节列表出现后，Kagami 会自动发现并返回。';

  @override
  String get browserInstructionsSearch =>
      '网站需要确认你是真人。请完成验证：网站的搜索页出现后，Kagami 会自动发现并返回。';

  @override
  String get browserSearchPhoneOnly => '这个网站只能在手机上搜索。';

  @override
  String get browserSearchSuperseded => '已被更新的搜索取代。';

  @override
  String get browserResponseTooLarge => '响应内容过大。';

  @override
  String get serverTitle => '服务器';

  @override
  String get serverRecent => '服务器已下载';

  @override
  String get serverUnavailableNoSecret =>
      '这个版本的应用无法连接服务器：编译它的人没有提供 Web 客户端的密钥（GOOGLE_SERVER_CLIENT_SECRET）。';

  @override
  String get serverUnavailableAndroidOnly => '只有 Android 才能连接服务器。';

  @override
  String get serverSignInRequired => '请先登录 Google 再使用服务器。';

  @override
  String get serverNoConnection => '没有网络。';

  @override
  String get serverMissingGoogleServices =>
      '缺少 google-services.json：这个版本没有 Google 客户端。';

  @override
  String get serverDriveAccessDenied => 'Google 没有授予 Drive 访问权限。';

  @override
  String get serverGoogleNotResponding => 'Google 没有响应：请稍后再试。';

  @override
  String serverWhenToday(String clock) {
    return '今天 $clock';
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
      other: ' · 已跳过 $skipped 页',
      zero: '',
    );
    return '$pages 个新页面 · $size$_temp0';
  }

  @override
  String get serverRemoveFromQueue => '移出队列';

  @override
  String get serverNoFirebase => '服务器通过 Google 账号识别用户，而这个版本的应用没有账号功能。';

  @override
  String get serverSignedOutIntro =>
      '一台常开的电脑可以代替手机下载并上传到你的 Drive，手机可以随时关机。服务器通过你的 Google 账号识别你。';

  @override
  String get serverSignIn => '使用 Google 登录';

  @override
  String get serverSignInSubtitle => '用于创建你自己的服务器，或使用别人的服务器';

  @override
  String serverInviteTitle(String sender, String serverName) {
    return '$sender已授权你使用“$serverName”';
  }

  @override
  String get serverInviteSubtitle => '下载到你的 Drive，手机关机也行。点按以连接';

  @override
  String get serverIgnore => '忽略';

  @override
  String get serverLinkIntro =>
      '一台常开的电脑（你自己的，或授权你使用的人的）可以代替手机下载并上传到你的 Drive，手机可以随时关机。';

  @override
  String get serverCreate => '创建你的服务器';

  @override
  String get serverCreateSubtitle => '在装有 Docker 的电脑上粘贴一条命令：无需任何配置';

  @override
  String get serverLinkTitle => '连接服务器';

  @override
  String get serverLinkSubtitle => '你自己已在运行的服务器，或别人添加你使用的服务器';

  @override
  String get serverStateConnecting => '正在连接…';

  @override
  String get serverStateNoGrant => '还没有你的 Drive 权限';

  @override
  String get serverStateNoFolder => '还不知道该写入你 Drive 的哪个文件夹';

  @override
  String serverStateReady(String folder) {
    return '就绪 · 写入你 Drive 中的“$folder”';
  }

  @override
  String serverTileSubtitle(String address, String state) {
    return '$address · $state';
  }

  @override
  String serverTileSubtitleOwner(String address, String owner, String state) {
    return '$address · 属于 $owner · $state';
  }

  @override
  String get serverPlainTitle => '连接未加密';

  @override
  String get serverPlainSubtitle =>
      '你的账号令牌在传输中可被读取：需要 HTTPS（Tailscale Funnel、反向代理）';

  @override
  String get serverGrantTitle => '把你的 Drive 授权给服务器';

  @override
  String get serverGrantSubtitle => '它会下载到应用读取的文件夹，手机关机也行';

  @override
  String get serverUseAppFolder => '使用应用的文件夹';

  @override
  String serverUseAppFolderSubtitle(String serverFolder, String appFolder) {
    return '服务器写入“$serverFolder”，应用读取“$appFolder”';
  }

  @override
  String get serverUsersTitle => '谁可以使用';

  @override
  String get serverUsersOnlyYou => '只有你。可添加任何人的 Google 账号';

  @override
  String serverUsersCount(int count) {
    return '$count 个账号，包括你';
  }

  @override
  String get serverQueueWaiting => '队列等待中';

  @override
  String get serverQueueRestarts => '服务器会自动继续';

  @override
  String get serverJobAutomatic => '新章节 · 在服务器上';

  @override
  String get serverJobQueued => '排队中 · 在服务器上';

  @override
  String serverJobAhead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 话',
    );
    return '边读边下：$_temp0';
  }

  @override
  String serverSeriesAhead(int count) {
    return '边读边下，备好 $count 话：你阅读时由应用请求章节';
  }

  @override
  String serverSeriesKnown(int count) {
    return '已知 $count 个章节';
  }

  @override
  String serverSeriesKnownChecked(int count, String when) {
    return '已知 $count 个章节 · $when检查过';
  }

  @override
  String get serverStopFollowing => '不再跟进';

  @override
  String get serverInviteRemoveFailed => '无法移除邀请：请重试。';

  @override
  String get serverCheckingNow => '服务器正在检查：新章节会出现在它的队列中。';

  @override
  String get serverPaste => '粘贴';

  @override
  String get serverAddressExposed =>
      '注意：在公网地址上使用明文连接，你的账号令牌在传输中可被读取。请使用 HTTPS（Tailscale Funnel、反向代理）或 Tailscale。';

  @override
  String get serverAddressSavedNote => '地址会随备份和账号一起保存，与 Drive 文件夹一样。';

  @override
  String get serverAddressMissing => '请填写服务器地址，例如 http://192.168.1.20:8080。';

  @override
  String serverLinked(String name, String folder) {
    return '已连接到“$name”：下载到你 Drive 中的“$folder”。';
  }

  @override
  String serverLinkFromInvite(String sender, String serverName) {
    return '$sender已将你添加到“$serverName”。连接后，服务器会把你选择的漫画下载到你 Drive 中书库所在的文件夹：Google 会请你允许它写入。管理服务器的人可以使用这个权限。';
  }

  @override
  String serverLinkLinked(String account) {
    return '服务器将你识别为$account。如果它不是你的服务器，断开连接时它也会忘记你的 Drive 权限和你的队列。';
  }

  @override
  String get serverSignedInAccount => '你登录所用的账号';

  @override
  String get serverLinkNew =>
      '填写服务器地址：你自己的，或添加你的人提供的。服务器通过 Google 账号识别你，第一次使用时你需要授权它写入你 Drive 中书库所在的文件夹。';

  @override
  String get serverVerifying => '正在验证…';

  @override
  String get serverVerifyAgain => '重新验证';

  @override
  String get serverVerifyAndLink => '验证并连接';

  @override
  String get serverUnlink => '断开连接';

  @override
  String get serverDefaultNameOwn => '我的 Kagami Server';

  @override
  String serverDefaultNameOf(String name) {
    return '$name的服务器';
  }

  @override
  String get serverCommandCopied => '命令已复制。';

  @override
  String get serverComputerAddressMissing =>
      '请填写电脑的地址，例如 http://192.168.1.20:8080。';

  @override
  String serverNotOwner(String owner) {
    return '该服务器属于 $owner：已连接，但不是你创建的。';
  }

  @override
  String serverReady(String name) {
    return '“$name”已就绪。可在“谁可以使用”中添加其他人。';
  }

  @override
  String get serverLibraryFolderFallback => '书库文件夹';

  @override
  String serverSetupIntro(String folder) {
    return '需要一台保持开机的电脑（迷你主机、NAS、树莓派、联网服务器等），并装有 Docker。服务器会下载漫画并上传到你 Drive 中的“$folder”，手机关机也行。';
  }

  @override
  String serverPrepareIntro(String signIn, String folder) {
    String _temp0 = intl.Intl.selectLogic(signIn, {
      'yes': '先用 Google 登录，然后',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(folder, {
      'yes': '在 Drive 上选择漫画文件夹，然后',
      'other': '',
    });
    return '我会准备一条包含所有内容的命令：$_temp0${_temp1}Google 会请你允许服务器写入你的 Drive。';
  }

  @override
  String get serverPreparing => '正在准备…';

  @override
  String get serverGenerate => '生成命令';

  @override
  String get serverStep1 => '在电脑上安装 Docker（docker.com），如果还没有的话。';

  @override
  String get serverStep2 =>
      '把这些命令粘贴到电脑的终端中：第一条启动服务器，第二条让它自动保持最新。它们包含你的 Drive 权限：不要发给任何人。';

  @override
  String get serverCopyCommand => '复制命令';

  @override
  String get serverStep3 =>
      '在这里填写电脑的地址：在家里用局域网地址；在外面用它在 Tailscale 中的名称，或你对外开放的 HTTPS 地址。';

  @override
  String get serverPortNote => '服务器使用 8080 端口响应。';

  @override
  String get serverUsersIntro =>
      '添加任何人的 Google 账号。邀请会出现在对方的 Kagami 应用中：连接服务器后，他的下载会保存到他自己的 Drive，使用他自己的队列。';

  @override
  String get serverUserEmailInvalid => '请填写 Google 账号的地址，例如 name@gmail.com。';

  @override
  String serverUserAdded(String email) {
    return '$email可以使用服务器了：对方的应用会通知他。';
  }

  @override
  String serverRemoveTitle(String email) {
    return '移除 $email？';
  }

  @override
  String get serverRemoveBody =>
      '对方将无法再使用服务器。他的队列和 Drive 权限会被删除；已在他 Drive 上的内容会保留。';

  @override
  String get serverCancel => '取消';

  @override
  String get serverRemove => '移除';

  @override
  String get serverAdd => '添加';

  @override
  String get serverOwnerYou => '你，所有者';

  @override
  String get serverConnected => '已连接服务器';

  @override
  String get serverInvitedPending => '已邀请，尚未连接服务器';

  @override
  String get setupIntro =>
      '读取同步到手机上的漫画文件夹，或直接读取 Google Drive 上的同一个书库，无需把它全部下载到这里。';

  @override
  String get setupAccessTitle => '文件访问权限';

  @override
  String get setupAccessBody =>
      '这个文件夹不在应用的专用空间里，而且有数万张图片：Kagami 需要直接读取它们。它只会把数据副本写入书库的 reading/ 子文件夹，以及（如果你要求）从 Drive 下载的章节。';

  @override
  String get setupGrantAccess => '授予访问权限';

  @override
  String get setupFolderTitle => '文件夹';

  @override
  String get setupFolderBody =>
      '请选择 FolderSync 同步的文件夹：里面有 library.json，以及每部作品一个子文件夹。';

  @override
  String get setupChooseFolder => '选择文件夹';

  @override
  String get setupOr => '或';

  @override
  String get setupDriveTitle => 'Google Drive';

  @override
  String get setupDriveBody =>
      '用 Google 登录并选择 Drive 上的书库文件夹：页面会在阅读时加载，想随时备在手边的章节点一下即可下载。不需要访问手机上的文件。';

  @override
  String get setupReadFromDrive => '从 Google Drive 阅读';

  @override
  String get setupLibraryProblemTitle => '无法读取书库';

  @override
  String get setupChangeFolder => '更换文件夹';

  @override
  String get driveFolderSheetTitle => 'Drive 上的文件夹';

  @override
  String get driveDestinationTitle => '漫画保存在哪里？';

  @override
  String get driveDestinationBody =>
      '手机上还没有漫画文件夹。保存在文件夹里的话，即使卸载应用，下载的章节也会保留，Kagami 会把它们和已有的章节一起读取。保存在应用的专用空间则不需要任何权限，但卸载应用时会一并删除。';

  @override
  String get driveChooseFolder => '选择文件夹';

  @override
  String get driveInAppSpace => '保存在应用专用空间';

  @override
  String get driveMyDrive => '我的云端硬盘';

  @override
  String get driveSharedWithMe => '与我共享';

  @override
  String get driveBack => '返回';

  @override
  String get driveNoResponse => 'Drive 没有响应';

  @override
  String get driveRetry => '重试';

  @override
  String get driveIsLibrary => '包含 library.json：这是一个书库';

  @override
  String get driveNotLibrary => '不包含 library.json：书库是含有它的那个文件夹';

  @override
  String get driveUseFolder => '使用此文件夹';

  @override
  String get driveNoFolders => '这里没有文件夹';

  @override
  String get driveNoticeAuthRequired => 'Kagami 还没有读取 Google Drive 的权限';

  @override
  String get driveAuthorize => '授权';

  @override
  String get driveSignIn => '登录';

  @override
  String get driveNoticeOffline =>
      '你处于离线状态：可阅读手机上的章节和已下载的 Drive 页面。其余内容会在网络恢复后自动回来';

  @override
  String driveNoticeError(String message) {
    return 'Drive：$message。当前显示手机上已有的内容';
  }

  @override
  String get syncSummaryOff => '已关闭';

  @override
  String get syncSummaryDownload => '从 Drive 到手机';

  @override
  String get syncSummaryUpload => '从手机到 Drive';

  @override
  String get syncSummaryBoth => '双向';

  @override
  String syncSummaryManual(String direction) {
    return '$direction，手动';
  }

  @override
  String syncSummaryDaily(String direction, String time) {
    return '$direction，每天 $time';
  }

  @override
  String get syncTitle => '同步';

  @override
  String get syncIntro =>
      '让手机上的漫画文件夹和 Drive 上的保持一致，无需 FolderSync。如果你仍在这个文件夹上使用它，请把它关掉：两个同步工具处理同一批文件会互相干扰。';

  @override
  String get syncFolders => '文件夹';

  @override
  String get syncOnPhone => '手机上';

  @override
  String get syncNoFolderChosen => '未选择文件夹';

  @override
  String get syncOnDrive => 'Drive 上';

  @override
  String get syncDriveNotConnected => '未连接 Drive';

  @override
  String get syncDirection => '方向';

  @override
  String get syncDirectionOff => '关闭';

  @override
  String get syncDirectionFromDrive => '从 Drive';

  @override
  String get syncDirectionToDrive => '到 Drive';

  @override
  String get syncDirectionBoth => '双向';

  @override
  String get syncDescOff => '不会自动同步任何内容。Drive 上的书库仍可阅读，“下载”也照常使用。';

  @override
  String get syncDescDownload => 'Drive 上新增的内容会下载到手机。手机上的内容不会上传。';

  @override
  String get syncDescUpload =>
      '手机上的内容会上传到 Drive，例如 reading/backup 中的数据副本。书库索引仍以服务器的为准。';

  @override
  String get syncDescBoth =>
      '任何一边有变化，另一边都会同步；如果两边都有变化，以较新的为准。书库索引只会下载，不会上传：它们属于服务器。';

  @override
  String get syncDeletions => '同步删除操作';

  @override
  String get syncDeletionsDownload => 'Drive 上消失的内容会从手机上删除';

  @override
  String get syncDeletionsUpload => '从手机上删除的内容会移到 Drive 的回收站';

  @override
  String get syncDeletionsBoth => '双向同步删除；在 Drive 上只会移到回收站';

  @override
  String get syncDeletionsOnNote => '“释放空间”会在下一轮同步时，把已读章节也从 Drive 上删除。';

  @override
  String get syncDeletionsOffNote =>
      '一边删除的文件会保留在另一边，不会恢复：“释放空间”只清理手机，章节仍留在 Drive 上。';

  @override
  String get syncDaily => '每天';

  @override
  String get syncScheduled => '定时同步';

  @override
  String get syncManualOnly => '仅手动';

  @override
  String syncAtTime(String time) {
    return '每天 $time，应用关闭时也会同步';
  }

  @override
  String get syncTime => '时间';

  @override
  String get syncWifiOnly => '仅限 Wi-Fi';

  @override
  String get syncWifiOnlyOn => '等待不按流量计费的网络';

  @override
  String get syncWifiOnlyOff => '移动数据也可以';

  @override
  String get syncScheduleNote => '具体时间由 Android 决定：如果到点时没有网络，网络一恢复就会开始同步。';

  @override
  String get syncNow => '立即';

  @override
  String get syncTimePickerHelp => '同步时间';

  @override
  String get syncRunNow => '立即同步';

  @override
  String get syncRunNowReady => '可以继续阅读：复制会在后台进行';

  @override
  String get syncRunNowNotReady => '需要先设置手机文件夹和 Drive 文件夹';

  @override
  String get syncPhaseListing => '正在查看 Drive 上有什么…';

  @override
  String get syncPhaseComparing => '正在与手机比对…';

  @override
  String get syncPhaseNothing => '没有需要复制的内容';

  @override
  String syncPhaseFiles(int done, int total) {
    return '文件 $done/$total';
  }

  @override
  String get syncStop => '中止';

  @override
  String get syncNever => '从未同步';

  @override
  String get syncNeverNote => '对已有内容的文件夹，第一轮很快：相同的文件会按大小识别';

  @override
  String syncLastScheduled(String date, String time) {
    return '上次，定时：$date $time';
  }

  @override
  String syncLastManual(String date, String time) {
    return '上次，手动：$date $time';
  }

  @override
  String syncOutcomeDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已下载 $count 个',
      one: '已下载 $count 个',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeUploaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已上传 $count 个',
      one: '已上传 $count 个',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeDeletedLocal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '从手机删除 $count 个',
      one: '从手机删除 $count 个',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeTrashed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个已移到 Drive 回收站',
      one: '$count 个已移到 Drive 回收站',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个失败，将重试',
      one: '$count 个失败，将重试',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeErrorSoFar(String error, String done) {
    return '$error。到出错为止：$done';
  }

  @override
  String get syncOutcomeAligned => '两边本来就是一致的';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsLibrary => '书库';

  @override
  String get settingsFolder => '文件夹';

  @override
  String get settingsNoFolder => '未选择文件夹';

  @override
  String get settingsReloadIndexes => '重新读取索引';

  @override
  String get settingsReloadIndexesNote => '同步刚带来新内容时使用';

  @override
  String get settingsIndexesReloaded => '索引已重新读取';

  @override
  String get settingsGoogleDrive => 'Google Drive';

  @override
  String get settingsReading => '阅读';

  @override
  String get settingsAccount => '账号';

  @override
  String get settingsData => '数据';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsLibraryNote => '文件夹、索引和 Google Drive';

  @override
  String get settingsLibraryNoteLocal => '文件夹和索引';

  @override
  String get settingsReadingNote => '默认模式和阅读器测量';

  @override
  String get settingsAccountNote => 'Google 登录和同步';

  @override
  String get settingsDataNote => '备份、恢复和清除';

  @override
  String get settingsAutoBackup => '自动备份到书库';

  @override
  String get settingsAutoBackupNote =>
      '每天一次，保存到 reading/backup/，同步时会和漫画一起传到 Drive';

  @override
  String get settingsExport => '导出数据';

  @override
  String get settingsExportNote => '状态、评分、阅读历史、合集和书签导出为一个文件';

  @override
  String get settingsExportDialog => '选择备份的保存位置';

  @override
  String get settingsExportCancelled => '已取消导出';

  @override
  String get settingsExportSaved => '备份已保存';

  @override
  String get settingsImport => '从备份导入';

  @override
  String get settingsImportNote => '先告诉你里面有什么，再做任何改动';

  @override
  String get settingsImportDialog => '选择一个 Kagami 备份';

  @override
  String get settingsImportInvalid => '这不是 Kagami 的备份文件';

  @override
  String get settingsImportSheetTitle => '导入这个备份？';

  @override
  String get settingsImportSeries => '作品';

  @override
  String get settingsImportRead => '已读';

  @override
  String get settingsImportCollections => '合集';

  @override
  String settingsImportExplain(String date) {
    return '备份于 $date。“合并”会保留你现有的数据并加入新内容：已读章节会相加，其余以较新的记录为准。“替换”会清除这台设备上的数据。';
  }

  @override
  String get settingsImportExplainUnknownDate =>
      '备份日期未知。“合并”会保留你现有的数据并加入新内容：已读章节会相加，其余以较新的记录为准。“替换”会清除这台设备上的数据。';

  @override
  String get settingsImportMerge => '合并';

  @override
  String get settingsImportReplace => '替换';

  @override
  String get settingsImportDone => '数据已导入';

  @override
  String get settingsImportFailed => '导入失败';

  @override
  String get settingsWipe => '删除个人数据';

  @override
  String get settingsWipeNote => '状态、评分、阅读历史和合集。漫画不受影响';

  @override
  String get settingsWipeSheetTitle => '删除所有个人数据？';

  @override
  String get settingsWipeExplain =>
      '这台设备上的状态、评分、收藏、已读章节、阅读历史、阅读记录、合集和书签都会消失。漫画和书库索引不受影响。\n\n如果还没有备份，这是最后的机会。';

  @override
  String get settingsWipeConfirm => '全部删除';

  @override
  String get settingsWipeDone => '个人数据已删除';

  @override
  String get settingsDriveConnect => '连接 Google Drive';

  @override
  String get settingsDriveConnectNote => '直接从 Drive 读取书库，无需全部下载到手机，只下载你选择的内容';

  @override
  String get settingsDriveFolder => 'Drive 上的文件夹';

  @override
  String get settingsDriveSync => '文件夹同步';

  @override
  String get settingsDriveDownloadsGo => '下载的章节保存在';

  @override
  String settingsDriveDownloadsFolder(String path) {
    return '书库文件夹中：$path';
  }

  @override
  String get settingsDriveDownloadsApp => '应用专用空间：卸载应用时会一并删除';

  @override
  String get settingsDriveDownloadsAsk => '第一次下载时询问';

  @override
  String get settingsDriveCache => '从 Drive 读取的页面';

  @override
  String settingsDriveCacheNote(String used, String limit) {
    return '缓存 $used，上限 $limit。无网络时也能重新阅读';
  }

  @override
  String get settingsDriveCacheLimitTitle => '页面缓存空间';

  @override
  String get settingsDriveClearCache => '清空缓存';

  @override
  String get settingsDriveClearCacheNote => '已下载的章节不受影响';

  @override
  String get settingsDriveDisconnect => '断开 Drive';

  @override
  String get settingsDriveDisconnectNote => '书库将恢复为手机上的文件夹。已下载的章节会保留';

  @override
  String get settingsAccountUnavailable => '此处无法使用账号';

  @override
  String get settingsAccountUnavailableNote => '这个版本没有 Firebase：数据保留在设备上';

  @override
  String get settingsAccountSignIn => '使用 Google 登录';

  @override
  String get settingsAccountSignInNote => '评分、状态、已读章节、阅读历史和合集将跟随账号，而不是手机';

  @override
  String get settingsAccountSyncNow => '立即同步';

  @override
  String get settingsAccountNeverSynced => '这部手机从未同步过';

  @override
  String settingsAccountLastSync(String date, String time) {
    return '上次同步：$date $time';
  }

  @override
  String get settingsAccountSignOut => '退出登录';

  @override
  String get settingsAccountSignOutNote => '先上传最新的阅读记录，再退出登录';

  @override
  String get settingsAccountForget => '不再保留副本';

  @override
  String get settingsAccountForgetNote => '从账号中删除数据。这部手机上的数据保持不变';

  @override
  String get settingsAccountErrorNote => '这部手机上的数据没有受到影响';

  @override
  String get settingsAccountForgetSheetTitle => '从账号中删除数据？';

  @override
  String get settingsAccountForgetExplain =>
      '为你保存的副本会被删除，并退出登录。这部手机上的状态、评分、阅读历史和合集保持不变，但在其他手机上将不再看到。';

  @override
  String get settingsAccountForgetConfirm => '从账号中删除';

  @override
  String get settingsReaderDirection => '分页阅读方向';

  @override
  String get settingsReaderBackground => '背景';

  @override
  String get settingsReaderKeepAwake => '保持屏幕常亮';

  @override
  String get settingsReaderProgressBar => '进度条';

  @override
  String get settingsProbe => '测量流畅度';

  @override
  String get settingsProbeNote => '在阅读器顶部显示：慢帧和丢帧、条带的来源、GC。点按数字可清零';

  @override
  String get settingsProbeInfo1 =>
      '在阅读器左上角显示一个数字面板，反映阅读有多流畅。用来弄清滚动为什么卡顿：不会改变阅读方式，开销也极小。';

  @override
  String get settingsProbeInfo2 =>
      '最重要的数字是“丢帧”：页面滚动时缺失的帧。每一次都是肉眼可见的小卡顿。“启动延迟”和“慢帧”说明应用当时是否忙碌，“Android GC”说明系统是否正在释放内存。';

  @override
  String get settingsProbeInfo3 =>
      '“分块”“整页”“手机切图”和“原生”说明每一块页面图像来自哪里：前三种是轻量的途径，最后一种是即时裁切，开销最大。';

  @override
  String get settingsProbeInfo4 =>
      '点按面板会把数字清零，这样就可以从章节中的某个位置开始测量。重新打开应用后，测量会自动关闭。';

  @override
  String get settingsTexture => '原生条带作为纹理';

  @override
  String get settingsTextureNote => '试验功能：尚未切好的页面不经过界面，直接送到 GPU。重新打开应用后会自动关闭';

  @override
  String get settingsTextureInfo1 =>
      '条漫中特别长的页面是分块阅读的。大多数时候这些块都已备好：由服务器上的归档切好，或由手机在第一次打开章节时切好。没有备好时，则由 Android 的解码器即时裁切。';

  @override
  String get settingsTextureInfo2 =>
      '通常这些块的像素要先经过应用才能到达屏幕。开启此选项后，它们会直接送到显卡：滚动时应用的负担更小，卡顿也可能减少。图像质量不会改变。';

  @override
  String get settingsTextureInfo3 =>
      '这是试验功能：一种全新的绘制方式，尚未在这部手机上验证过。如果出现黑页、横线或闪烁，请关闭它。如果手机不支持，应用会自动回到常规方式。';

  @override
  String get settingsTextureInfo4 =>
      '对已经切成分块的章节没有任何影响，因为那里不会用到这条途径。重新打开应用后会自动关闭。';

  @override
  String get settingsWhatItDoes => '作用';

  @override
  String get settingsBackupsTitle => '书库中的副本';

  @override
  String get settingsBackupsNone => '还没有副本：第一份会在下次打开应用时生成';

  @override
  String settingsBackupsLatest(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 份副本，最新的是 $name',
      one: '1 份副本，最新的是 $name',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupNow => '立即备份';

  @override
  String settingsBackupWritten(String path) {
    return '副本已写入 $path';
  }

  @override
  String settingsVersion(String version, String build) {
    return '版本 $version（$build）';
  }

  @override
  String get settingsTagline => '本地 MALF 归档阅读器';

  @override
  String get librarySortUpdated => '最近更新';

  @override
  String get librarySortTitle => '标题';

  @override
  String get librarySortProgress => '进度';

  @override
  String get librarySortAdded => '最近添加';

  @override
  String get librarySortLastRead => '最近阅读';

  @override
  String get librarySortUnread => '待读';

  @override
  String get librarySortRating => '评分';

  @override
  String get librarySortChapters => '章节数';

  @override
  String get librarySortShuffle => '随机';

  @override
  String get libraryDisplayComfortable => '宽松网格';

  @override
  String get libraryDisplayCompact => '紧凑网格';

  @override
  String get libraryDisplayList => '列表';

  @override
  String get libraryDisplayDetailed => '详细列表';

  @override
  String get libraryAutoReading => '在读';

  @override
  String get libraryAutoFresh => '新作';

  @override
  String get libraryAutoFavorites => '收藏';

  @override
  String get libraryAutoPlanned => '未开始';

  @override
  String get libraryAutoFinished => '已读完';

  @override
  String libraryRowChapters(int count) {
    return '$count 章';
  }

  @override
  String libraryRowUnread(int count) {
    return '$count 章未读';
  }

  @override
  String get libraryNoMatchTitle => '没有匹配的作品';

  @override
  String get libraryNoMatchMessage => '没有作品符合当前的搜索和筛选条件。';

  @override
  String get libraryEmptyTitle => '书库是空的';

  @override
  String get libraryEmptyMessage => '书库里没有作品。如果应该有，请检查文件夹的同步情况。';

  @override
  String get libraryClearFilters => '清除筛选';

  @override
  String get libraryTitle => '书库';

  @override
  String get libraryCancelSelection => '取消选择';

  @override
  String librarySelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选 $count 部',
      one: '已选 1 部',
    );
    return '$_temp0';
  }

  @override
  String libraryAllWithCount(int count) {
    return '全部（$count）';
  }

  @override
  String get libraryAll => '全部';

  @override
  String get libraryMarkAllRead => '全部标为已读';

  @override
  String get libraryMarkAllUnread => '全部标为未读';

  @override
  String get libraryStatus => '状态';

  @override
  String get libraryFavorites => '收藏';

  @override
  String get libraryAddToCollection => '添加到合集';

  @override
  String libraryStatusOfSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 部作品的状态',
      one: '1 部作品的状态',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 部作品已标为已读',
      one: '1 部作品已标为已读',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 部作品已改回未读',
      one: '1 部作品已改回未读',
    );
    return '$_temp0';
  }

  @override
  String get librarySearchHint => '标题、作者、tag:…';

  @override
  String get libraryLayout => '布局';

  @override
  String get libraryFiltersAndSort => '筛选和排序';

  @override
  String get libraryReset => '重置';

  @override
  String get librarySortSection => '排序';

  @override
  String get libraryShowOnly => '仅显示';

  @override
  String get libraryOnlyUnread => '有未读章节';

  @override
  String get libraryOnlyStarted => '已开始';

  @override
  String get libraryOnlyNew => '有新章节';

  @override
  String get libraryOnlyFavorite => '已收藏';

  @override
  String get libraryMinRating => '评分至少';

  @override
  String get libraryRelease => '连载状态';

  @override
  String get libraryGenres => '类型';

  @override
  String get libraryTriHint => '点一下为包含，点两下为排除';

  @override
  String get libraryTags => '标签';

  @override
  String get libraryAuthors => '作者';

  @override
  String get homeEmptyTitle => '书库是空的';

  @override
  String get homeEmptyMessage => '没有可浏览的内容：文件夹里还没有任何作品。';

  @override
  String get homeToStart => '未开始';

  @override
  String get homeSimilarTitle => '你的口味';

  @override
  String get homeSimilarSubtitle => '还没打开过，类型合你的胃口';

  @override
  String get homeRecentlyArrived => '最近入库';

  @override
  String get homeLeftHalfway => '读到一半';

  @override
  String get homeLeftHalfwaySubtitle => '暂停和已弃坑的作品';

  @override
  String get homeCaughtUpTitle => '都追上了';

  @override
  String get homeCaughtUpMessage => '已同步的内容都读完了。下一章节会随文件夹一起到来。';

  @override
  String get homeRandomSeries => '随机一部';

  @override
  String get homeReloadLibrary => '重新读取书库';

  @override
  String get homeGreetingNight => '夜深了';

  @override
  String get homeGreetingMorning => '早上好';

  @override
  String get homeGreetingAfternoon => '下午好';

  @override
  String get homeGreetingEvening => '晚上好';

  @override
  String get homeStatRead => '已读';

  @override
  String get homeStatReadCaption => '个章节，累计';

  @override
  String get homeStatUnread => '待读';

  @override
  String get homeStatUnreadCaption => '手机上的章节';

  @override
  String get homeStatStreak => '连续阅读';

  @override
  String homeStatStreakCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '天',
    );
    return '$_temp0';
  }

  @override
  String get homeResume => '继续阅读';

  @override
  String get homeNextChapter => '下一章节';

  @override
  String get homeRead => '阅读';

  @override
  String get homeUpdates => '更新';

  @override
  String get homeUpdatesSubtitle => '已同步但还没读的章节';

  @override
  String homeLatestChapter(String number) {
    return '第 $number 话';
  }

  @override
  String homeSiteChapters(int count, String site) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$site 上新增 $count 章',
      one: '$site 上新增 1 章',
    );
    return '$_temp0';
  }

  @override
  String get homeAgoToday => '今天';

  @override
  String get homeAgoYesterday => '昨天';

  @override
  String homeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
      one: '1 天前',
    );
    return '$_temp0';
  }

  @override
  String homeAgoWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 周前',
      one: '1 周前',
    );
    return '$_temp0';
  }

  @override
  String homeAgoMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个月前',
      one: '1 个月前',
    );
    return '$_temp0';
  }

  @override
  String homeAgoYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 年前',
      one: '1 年前',
    );
    return '$_temp0';
  }

  @override
  String get collectionsTitle => '合集';

  @override
  String get collectionsNew => '新建';

  @override
  String get collectionsAutomatic => '自动合集';

  @override
  String get collectionsYours => '我的合集';

  @override
  String get collectionsNoneTitle => '还没有合集';

  @override
  String get collectionsNoneMessage => '合集能为自己不断变大的书库理出条理：一部作品可以放进多个合集，顺序由你决定。';

  @override
  String collectionsSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 部作品',
      one: '1 部作品',
    );
    return '$_temp0';
  }

  @override
  String get collectionsEdit => '编辑';

  @override
  String get collectionsRenameRecolor => '重命名并更改颜色';

  @override
  String get collectionsDelete => '删除合集';

  @override
  String get collectionsNotFound => '未找到该合集。';

  @override
  String get collectionsDone => '完成';

  @override
  String get collectionsReorder => '调整顺序';

  @override
  String get collectionsEmptyTitle => '合集是空的';

  @override
  String get collectionsEmptyMessage => '可以在作品详情页中添加，或在书库里长按封面添加。';

  @override
  String get collectionsRemoveFrom => '从合集中移除';

  @override
  String get shellDataUnreadableTitle => '无法读取应用数据';

  @override
  String get shellRetry => '重试';

  @override
  String get shellTabHome => '首页';

  @override
  String get shellTabLibrary => '书库';

  @override
  String get shellTabCollections => '合集';

  @override
  String get moreDownload => '下载漫画';

  @override
  String get moreDownloadSubtitle => '搜索标题或粘贴链接';

  @override
  String get moreHistory => '阅读历史';

  @override
  String get moreHistorySubtitle => '你读过什么、什么时候读的';

  @override
  String get moreStatistics => '统计';

  @override
  String get moreStatisticsSubtitle => '读了多少、读了什么、什么时候读';

  @override
  String get moreIncognito => '无痕阅读';

  @override
  String get moreIncognitoSubtitle => '不记录阅读位置、读完的章节和阅读时长';

  @override
  String get historyTitle => '阅读历史';

  @override
  String get historyIncognitoOn => '无痕模式已开启';

  @override
  String get historyIncognitoOff => '无痕阅读';

  @override
  String get historyClear => '清空';

  @override
  String get historyUnreadable => '无法读取阅读历史';

  @override
  String get historyEmptyTitle => '暂时还没有读过的内容';

  @override
  String get historyEmptyMessage => '每读完一个章节，就会连同日期出现在这里。';

  @override
  String get historyClearTitle => '清空阅读历史？';

  @override
  String get historyClearMessage => '阅读日期和阅读时长会消失，由此得出的统计也会一并消失。章节会恢复为未读。';

  @override
  String get historyIncognitoBanner => '无痕模式：不记录阅读位置、读完的章节和阅读时长。';

  @override
  String get historyToday => '今天';

  @override
  String get historyYesterday => '昨天';

  @override
  String get historyReread => '重读';

  @override
  String get historyRemove => '从阅读历史中移除';

  @override
  String get originLocal => '在手机上';

  @override
  String get originDrive => '在 Drive 上';

  @override
  String get originMixed => '在手机上，其余章节在 Drive 上';

  @override
  String get coverNoChapters => '没有已下载的章节';

  @override
  String coverChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 章',
    );
    return '$_temp0';
  }

  @override
  String coverChaptersUnread(int count, int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 章',
    );
    return '$_temp0 · $unread 章未读';
  }

  @override
  String coverNewChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个新章节',
      one: '1 个新章节',
    );
    return '$_temp0';
  }

  @override
  String coverUnread(int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '$unread 个章节未读',
      one: '1 个章节未读',
    );
    return '$_temp0';
  }

  @override
  String coverUnreadFresh(int unread, int fresh) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '$unread 个章节未读',
      one: '1 个章节未读',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fresh,
      locale: localeName,
      other: '$fresh 个是新的',
      one: '1 个是新的',
    );
    return '$_temp0，其中 $_temp1';
  }

  @override
  String chartsDayNothing(String date) {
    return '$date：没有阅读';
  }

  @override
  String chartsDayChapters(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个章节',
      one: '1 个章节',
    );
    return '$date：$_temp0';
  }

  @override
  String get kitClose => '关闭';

  @override
  String get collectionSheetTitle => '合集';

  @override
  String collectionSheetTitleMany(int count) {
    return '$count 部作品的合集';
  }

  @override
  String get collectionSheetNew => '新建';

  @override
  String get collectionSheetEmptyTitle => '还没有合集';

  @override
  String get collectionSheetEmptyMessage => '合集能为自己不断变大的书库理出条理。';

  @override
  String collectionSheetSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 部作品',
      one: '1 部作品',
    );
    return '$_temp0';
  }

  @override
  String get collectionSheetCreateTitle => '新建合集';

  @override
  String get collectionSheetEditTitle => '编辑合集';

  @override
  String get collectionSheetNameHint => '名称';

  @override
  String get collectionSheetColor => '颜色';

  @override
  String get collectionSheetCreate => '创建';

  @override
  String get collectionSheetSave => '保存';

  @override
  String get cleanupTitle => '释放空间？';

  @override
  String get cleanupSyncBusy => '正在同步：请在同步结束后重试';

  @override
  String cleanupNotAllDeleted(String error) {
    return '并非全部删除成功：$error';
  }

  @override
  String cleanupDriveError(String error) {
    return 'Drive：$error。已删除的不会恢复';
  }

  @override
  String cleanupFreed(String size) {
    return '已释放 $size';
  }

  @override
  String get cleanupNeedsNetwork => '从 Drive 删除需要网络';

  @override
  String removeSeriesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '删除 $count 个系列？',
      one: '删除这个系列？',
    );
    return '$_temp0';
  }

  @override
  String removeSeriesBody(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '这些系列将从书库中移除：手机上的章节会被删除，也不会再收到新章节。阅读进度会保留。',
      one: '“$title”将从书库中移除：手机上的章节会被删除，也不会再收到新章节。阅读进度会保留。',
    );
    return '$_temp0';
  }

  @override
  String get removeSeriesDrive => 'Drive 上的文件夹会移到回收站，三十天内可从那里恢复。';

  @override
  String get removeSeriesConfirm => '删除';

  @override
  String removeSeriesDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已删除 $count 个系列。',
      one: '已删除系列。',
    );
    return '$_temp0';
  }

  @override
  String removeSeriesFailed(String error) {
    return '无法全部删除：$error';
  }

  @override
  String get removeSeriesAction => '从书库删除';

  @override
  String cleanupIntroDrive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 个已读章节仍在 Drive 上。',
      one: '有 1 个已读章节仍在 Drive 上。',
    );
    return '$_temp0';
  }

  @override
  String cleanupIntroPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 个已读章节仍占用手机空间。',
      one: '有 1 个已读章节仍占用手机空间。',
    );
    return '$_temp0';
  }

  @override
  String get cleanupPhoneChapters => '手机上的章节';

  @override
  String get cleanupDriveCache => 'Drive 缓存';

  @override
  String get cleanupDriveChapters => 'Drive 上的章节';

  @override
  String cleanupApproxSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个章节',
      one: '1 个章节',
    );
    return '$_temp0 · 约 $size';
  }

  @override
  String cleanupExactSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个章节',
      one: '1 个章节',
    );
    return '$_temp0 · $size';
  }

  @override
  String cleanupApproxSizeTrash(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个章节',
      one: '1 个章节',
    );
    return '$_temp0 · 约 $size · 移入回收站';
  }

  @override
  String get cleanupQuiet => '不再为这部作品询问';

  @override
  String get cleanupWarnNotOnDrive => '这部作品不在 Drive 上：删除的章节在同步把它们带回来之前将无法重读。';

  @override
  String get cleanupWarnGoneEverywhere => '手机和 Drive 上都不会再保留。';

  @override
  String get cleanupWarnStaysOnDrive => '章节仍在 Drive 上，可以从那里重读。';

  @override
  String get cleanupWarnTrash =>
      '在 Drive 回收站中可以恢复三十天。服务器的索引仍会列出它们：如果服务器重新上传，就又能从 Drive 阅读了。';

  @override
  String get cleanupDelete => '删除';

  @override
  String get cleanupNotNow => '暂不';

  @override
  String get cleanupSyncWarnExternal =>
      '如果 FolderSync 对这个文件夹做双向同步，删除操作也可能传到 Drive；如果它只做下载，章节可能在下一轮同步时又回来。';

  @override
  String get cleanupSyncWarnOwn =>
      '同步会遵守这个选择：你在一边删除的内容，不会恢复，也不会在另一边消失，即使开启了同步删除。';

  @override
  String get statsRangeMonth => '30 天';

  @override
  String get statsRangeQuarter => '3 个月';

  @override
  String get statsRangeYear => '一年';

  @override
  String get statsTitle => '统计';

  @override
  String get statsUnavailable => '无法计算统计';

  @override
  String get statsChaptersRead => '已读章节';

  @override
  String get statsSeriesInLibrary => '书库中的作品';

  @override
  String statsMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String statsHours(int count) {
    return '$count 小时';
  }

  @override
  String get statsReadingTime => '阅读时长';

  @override
  String get statsReadingTimeHint => '阅读时实时计时';

  @override
  String get statsPagesSeen => '已看页数';

  @override
  String get statsStreak => '连续阅读天数';

  @override
  String statsStreakRecord(int count) {
    return '纪录：$count';
  }

  @override
  String get statsAverageRating => '平均评分';

  @override
  String statsRatedSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已评分 $count 部作品',
      one: '已评分 1 部作品',
    );
    return '$_temp0';
  }

  @override
  String get statsChaptersOverTime => '已读章节';

  @override
  String get statsPerWeek => '按周';

  @override
  String get statsPerDay => '按天';

  @override
  String get statsActivityTitle => '你的阅读时间';

  @override
  String get statsActivitySubtitle => '每天一格，最近六个月';

  @override
  String get statsShelfTitle => '按状态划分的书库';

  @override
  String statsGenreOthers(int count) {
    return '另外 $count 种';
  }

  @override
  String get statsGenresTitle => '你读的类型';

  @override
  String get statsGenresSubtitle => '统计你已开始阅读的作品';

  @override
  String get statsRatingsTitle => '你的评分分布';

  @override
  String get statsRatingsSubtitle => '每个分数对应多少部作品';

  @override
  String get statsTopSeries => '读得最多的作品';

  @override
  String get statsShapeTitle => '书库概况';

  @override
  String get statsSyncedChapters => '已同步章节';

  @override
  String get statsStillUnread => '仍未读';

  @override
  String get statsOngoingSeries => '连载中的作品';

  @override
  String statsAnnouncedMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个已公布但未下载的章节',
      one: '1 个已公布但未下载的章节',
    );
    return '$_temp0';
  }

  @override
  String get statsBytesOnPhone => '手机上占用';

  @override
  String get statsNoHistory => '这段时间没有阅读记录。阅读历史从应用开始记录的时候算起。';

  @override
  String get dataDriveNotLinked => '未连接 Drive';

  @override
  String get dataChapterNotOnDrive => '在 Drive 上找不到该章节';

  @override
  String get dataChapterNoPagesOnDrive => '该章节在 Drive 上没有页面';

  @override
  String get dataPageNotOnDrive => '在 Drive 上找不到该页面';

  @override
  String get dataPrefetchCancelled => '预加载已取消';

  @override
  String get dataDriveAccessDenied => 'Google 没有授予 Drive 访问权限';

  @override
  String get dataDriveOfflineNeverOpened => '没有网络，而且这部手机从未打开过 Drive 上的书库';

  @override
  String get dataDriveSignedOut => '请使用 Google 登录以读取 Drive 上的书库';

  @override
  String get dataSyncMissingFolderOrDirection => '缺少文件夹或同步方向';

  @override
  String get dataSyncFailed => '同步失败';

  @override
  String get dataSyncFolderUnreadable => '无法读取手机上的文件夹';

  @override
  String get dataSyncBusy => '已有同步正在进行';

  @override
  String get dataSyncCancelled => '同步已中止';

  @override
  String get dataSyncDirectionDownload => '从 Drive';

  @override
  String get dataSyncDirectionUpload => '到 Drive';

  @override
  String get dataSyncDirectionBoth => '双向';

  @override
  String dataServerInviteTitle(String sender) {
    return '$sender已授权你使用他的服务器';
  }

  @override
  String dataServerInviteText(String serverName) {
    return '连接“$serverName”后，它会把漫画下载到你的 Drive，手机关机也行。';
  }

  @override
  String get dataServerSignInRequired => '请先登录 Google 再使用服务器。';

  @override
  String get dataServerNotLinked => '没有连接服务器。';

  @override
  String dataServerUserNotNotified(String email, String url) {
    return '$email可以使用服务器，但我没能通知对方：请你自己把地址 $url 发给他。';
  }

  @override
  String get dataPickLibraryFolderTitle => '选择漫画书库文件夹';

  @override
  String get dataCloudSignInNotEnabled => '这个项目尚未启用 Google 登录';

  @override
  String get dataCloudNoConnection => '没有网络';

  @override
  String get dataCloudNoSignIn => '未登录';

  @override
  String get dataCloudNoIdentityToken => 'Google 没有提供身份令牌';

  @override
  String get dataCloudSignInFailed => '登录失败';

  @override
  String get dataCloudSignInInterrupted => '登录已中断';

  @override
  String get dataCloudGoogleNotConfigured => '这个应用尚未配置 Google 登录';

  @override
  String get dataCloudGoogleSignInFailed => 'Google 登录失败';

  @override
  String dataNewChaptersNotification(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 个新章节',
      one: '有 1 个新章节',
    );
    return '$_temp0';
  }

  @override
  String dataNewSiteChaptersNotification(int count, String site) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$site 上更新了 $count 个新章节',
      one: '$site 上更新了 1 个新章节',
    );
    return '$_temp0';
  }

  @override
  String get dataArchivePhoneFolderMissing => '缺少手机上的文件夹。';

  @override
  String get dataArchiveDriveFolderMissing => '缺少 Drive 文件夹。';

  @override
  String dataChapterLabel(String number) {
    return '第 $number 话';
  }

  @override
  String get dataLibraryMissing => '文件夹不存在或无法读取。';

  @override
  String get dataLibraryNotIndexed =>
      '文件夹中没有 library.json：请用写入这个书库的归档工具重新生成索引。';

  @override
  String get dataLibraryUnreadable => 'library.json 无法读取，或不是有效的 MALF 索引。';

  @override
  String get dataLibraryUnsupported => 'library.json 使用的格式版本比这个应用支持的更新。';

  @override
  String get dataReaderModeContinuous => '连续阅读';

  @override
  String get dataReaderModePaged => '分页阅读';

  @override
  String get dataReaderDirectionLtr => '从左到右';

  @override
  String get dataReaderDirectionRtl => '从右到左';

  @override
  String get dataReaderFitWidth => '适应宽度';

  @override
  String get dataReaderFitHeight => '适应高度';

  @override
  String get dataReaderFitOriginal => '原始大小';

  @override
  String get dataReaderBackgroundBlack => '黑色';

  @override
  String get dataReaderBackgroundGrey => '灰色';

  @override
  String get dataReaderBackgroundWhite => '白色';

  @override
  String readerProbeFrames(String frames, String budget) {
    return '帧数 $frames · 上限 $budget ms';
  }

  @override
  String readerProbeSlow(
    String build,
    String buildMax,
    String raster,
    String rasterMax,
  ) {
    return '慢帧 UI $build（最大 $buildMax ms）· GPU $raster（最大 $rasterMax ms）';
  }

  @override
  String readerProbeLate(String late, String lateMax) {
    return '启动延迟 $late（最大 $lateMax ms）';
  }

  @override
  String readerProbeScroll(String scroll, String missed, String gap) {
    return '滚动 $scroll · 丢帧 $missed（最大间隔 $gap ms）';
  }

  @override
  String readerProbeSources(
    String tiles,
    String whole,
    String phone,
    String phoneMade,
  ) {
    return '分块 $tiles · 整页 $whole · 手机切图 $phone（已切 $phoneMade）';
  }

  @override
  String readerProbeNative(String bands, String textures, String decodes) {
    return '原生 $bands（纹理 $textures）· 已解码页面 $decodes';
  }

  @override
  String readerProbeDecode(
    String decode,
    String decodeMax,
    String arrival,
    String arrivalMax,
  ) {
    return '解码 $decode ms（最大 $decodeMax）· 到达 $arrival ms（最大 $arrivalMax）';
  }

  @override
  String readerProbeMemory(
    String copy,
    String gc,
    String gcMs,
    String blocking,
    String blockingMs,
  ) {
    return '复制最大 $copy ms · Android GC $gc（$gcMs ms）· 阻塞 $blocking（$blockingMs ms）';
  }

  @override
  String readerProbeWaits(String drive, String fallbacks) {
    return '等待 Drive $drive · Dart 回退 $fallbacks';
  }

  @override
  String readerProbeJumps(String corrections, String jumps, String jumped) {
    return '校正 $corrections · 跳动 $jumps（$jumped px）';
  }

  @override
  String get serverCheckDaily => '每日检查新章节';

  @override
  String serverCheckDailyAt(String clock) {
    return '每天 $clock（服务器时间）';
  }

  @override
  String get serverCheckDailyOff => '已关闭：新章节只能手动下载';

  @override
  String get serverCheckLibrary => 'Drive 上的整个书库';

  @override
  String get serverCheckLibraryOn => '也包括手机或其他方式下载的系列，而不只是服务器下载的';

  @override
  String get serverCheckLibraryOff => '仅限服务器下载的连载中系列';

  @override
  String serverCheckLast(String when, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个系列有新章节',
      zero: '没有新章节',
    );
    return '上次检查 $when：$_temp0';
  }

  @override
  String get serverCheckTimeHelp => '检查时间';

  @override
  String get seriesRatingInviteTitle => '你给它打几分？';

  @override
  String get seriesRatingInviteBody => '评分用于筛选和排序书库，也会计入统计。';

  @override
  String get seriesRatingInviteRate => '评分';

  @override
  String get seriesRatingInviteIgnore => '忽略';

  @override
  String get seriesRatingInviteNever => '不再询问';

  @override
  String get settingsRatingInvite => '打开作品时提示评分';

  @override
  String get settingsRatingInviteNote => '没有评分的作品页面会显示评分提示';

  @override
  String get archiveModeCard => '仅卡片';

  @override
  String get archiveModeCardLine => '不下载章节：状态、评分和读到哪里';

  @override
  String get archiveModeCardHint =>
      '把作品保存到书库而不下载章节：封面、元数据、章节列表和网站链接。标出你读到哪里：那一章及之前的章节会记为已读。章节可以以后再下载。';

  @override
  String get archiveReachedSection => '读到了…';

  @override
  String get archiveReachedHint => '点按你读过的最后一章。';

  @override
  String get archiveReachedNone => '还没开始';

  @override
  String get archiveChapterReached => '读到这里';

  @override
  String get archiveCardServer => '卡片由手机保存：已连接的服务器只下载章节。';

  @override
  String get archiveCardNotesHint => '给自己的备注（可选）';

  @override
  String archiveSummaryCard(String where) {
    return '保存卡片，不下载章节 · $where';
  }

  @override
  String archiveSummaryCardReached(String number, String where) {
    return '保存已读到第 $number 章的卡片，不下载章节 · $where';
  }

  @override
  String get archiveSaveCard => '保存卡片';

  @override
  String archiveCardQueuedSnack(String title) {
    return '已保存《$title》的卡片：封面和章节列表稍后就到。';
  }

  @override
  String archiveCardProgress(String message) {
    return '卡片 · $message';
  }

  @override
  String archiveJobCard(String destination) {
    return '卡片 · $destination';
  }

  @override
  String archiveJobCardUpdate(String destination) {
    return '更新卡片 · $destination';
  }

  @override
  String archiveRecentCard(String when) {
    return '卡片 · $when';
  }

  @override
  String archiveCheckCards(String names) {
    return '$names 的卡片列出了新章节（未下载）';
  }

  @override
  String get seriesOpenSite => '在网站上打开';

  @override
  String get seriesRefreshCard => '更新卡片';

  @override
  String get seriesDownloadMore => '下载更多章节';

  @override
  String get seriesStartDownload => '开始下载';

  @override
  String get seriesStartDownloadMessage =>
      '这个系列只是一张卡片，章节在网站上。从上次读到的下一章开始下载，就能在这里阅读。';

  @override
  String get seriesDownloadFromSite => '从网站下载';

  @override
  String get seriesDownloadFromSiteQueued => '已排队（来自网站）';

  @override
  String get coverCardBadge => '卡片';

  @override
  String coverReached(String number) {
    return '读到第$number话';
  }

  @override
  String get libraryOnlyCards => '仅卡片';

  @override
  String get seriesReachedTitle => '读到';

  @override
  String get seriesReachedNone => '未开始';

  @override
  String seriesReachedChapter(String number) {
    return '第$number话';
  }

  @override
  String get seriesReachedSearch => '搜索章节';

  @override
  String get seriesReachedNumberHint => '章节号';

  @override
  String get seriesReachedNumberHelp => '按网站上的写法填写，例如 52。留空即清除。';

  @override
  String get seriesReachedBackTitle => '要往回退吗？';

  @override
  String seriesReachedBackMessage(String chapter) {
    return '“$chapter”之后的章节仍标记为已读：如需恢复为未读，请在章节列表中取消标记。';
  }

  @override
  String get seriesReachedBackConfirm => '移动';

  @override
  String get seriesCardEmptyTitle => '没有章节的卡片';

  @override
  String get seriesCardEmptyMessage => 'Kagami 不会从该网站下载，但卡片会保留状态、评分、备注和阅读进度。';

  @override
  String get seriesLinkSite => '关联到网站';

  @override
  String get seriesLinkTitle => '关联到网站';

  @override
  String get seriesLinkMessage =>
      '粘贴 Kagami 可以下载的网站上该系列的链接。状态、评分、笔记、收藏集和阅读进度会转到真正的系列，此卡片将被移除。';

  @override
  String get seriesLinkHint => '系列链接';

  @override
  String get seriesLinkContinue => '继续';

  @override
  String seriesLinkDone(String title) {
    return '「$title」已关联：任务完成后，该系列会出现在书库中。';
  }

  @override
  String get archiveManualAction => '无链接添加';

  @override
  String get archiveManualUnsupported =>
      'Kagami 无法从该网站下载:可以将其保存为带标题和链接的卡片,但无法下载章节。';

  @override
  String get archiveManualUnsupportedAction => '保存为卡片';

  @override
  String get archiveManualTitle => '手动卡片';

  @override
  String get archiveManualTitleHint => '标题';

  @override
  String get archiveManualTitleRequired => '请输入标题。';

  @override
  String get archiveManualLinkHint => '作品页面链接(可选)';

  @override
  String get archiveManualSupported => 'Kagami 可以读取该网站:走常规流程即可获得章节列表并下载。';

  @override
  String get archiveManualSupportedAction => '使用常规流程';

  @override
  String get archiveManualNoDownload => '该网站的章节无法下载:只保留链接,以及页面声明的标题和封面。';

  @override
  String get archiveManualReachedHint => '读到第几章(例如 52)';

  @override
  String get archiveManualWhereDrive => '卡片将保存到 Drive 的书库文件夹。';

  @override
  String get archiveManualWherePhone => '卡片将保存到手机。';

  @override
  String get archiveManualSave => '保存卡片';

  @override
  String archiveManualSaved(String title) {
    return '已保存「$title」的卡片。';
  }

  @override
  String archiveManualExists(String title) {
    return '该链接已在书库中:「$title」。';
  }

  @override
  String get archiveManualNeedsDrive => '将卡片保存到 Drive 需要写入权限。';

  @override
  String archiveManualFailed(String error) {
    return '无法保存卡片:$error';
  }

  @override
  String get archiveImportAction => '导入多个链接';

  @override
  String get archiveImportTitle => '导入多个链接';

  @override
  String get archiveImportIntro =>
      '粘贴链接：浏览器标签页、列表或 JSON 都可以。每部漫画都会成为书库中的卡片，不下载章节；如果是章节链接，则记为读到该章节。';

  @override
  String get archiveImportHint => '在此粘贴包含链接的文本…';

  @override
  String archiveImportFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '找到 $count 个链接',
      zero: '未找到链接',
    );
    return '$_temp0';
  }

  @override
  String get archiveImportWhereDrive => '卡片会保存到 Drive 的书库文件夹中。';

  @override
  String get archiveImportWherePhone => '卡片会保存在手机上。';

  @override
  String get archiveImportCollection => '添加到收藏集';

  @override
  String get archiveImportCollectionNone => '不加入收藏集';

  @override
  String get archiveImportPause => '链接之间的间隔';

  @override
  String get archiveImportPauseHint => '系列会逐个从网站读取：间隔越长，对网站的负担越小。';

  @override
  String archiveImportSeconds(int seconds) {
    return '$seconds 秒';
  }

  @override
  String archiveImportStart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '导入 $count 个链接',
    );
    return '$_temp0';
  }

  @override
  String get archiveImportStop => '停止';

  @override
  String get archiveImportResume => '继续';

  @override
  String get archiveImportWaiting => '等待中';

  @override
  String get archiveImportRunning => '进行中…';

  @override
  String get archiveImportSaved => '已保存为卡片';

  @override
  String archiveImportSavedReached(String chapter) {
    return '已保存为卡片 · 读到第 $chapter 话';
  }

  @override
  String get archiveImportManual => '手动卡片：Kagami 无法下载其章节';

  @override
  String archiveImportKnown(String title) {
    return '已在书库中：“$title”';
  }

  @override
  String get archiveImportQueued => '已在队列中';

  @override
  String get archiveImportNeedsCheck => '网站要求验证';

  @override
  String get archiveImportVerify => '验证';

  @override
  String get archiveImportRetry => '重试';

  @override
  String get archiveImportCheckHint =>
      '有些网站要求浏览器验证：点按其中一个并通过验证，同一网站的其他链接会自动重新开始。';

  @override
  String archiveImportProgress(int done, int total) {
    return '$done / $total';
  }

  @override
  String archiveImportCountSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张卡片',
    );
    return '$_temp0';
  }

  @override
  String archiveImportCountManual(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张手动卡片',
    );
    return '$_temp0';
  }

  @override
  String archiveImportCountKnown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个已存在',
    );
    return '$_temp0';
  }

  @override
  String archiveImportCountFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个错误',
    );
    return '$_temp0';
  }

  @override
  String archiveImportCountCheck(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个待验证',
    );
    return '$_temp0';
  }

  @override
  String get archiveImportLeaveTitle => '停止导入？';

  @override
  String get archiveImportLeaveBody => '已保存的卡片会保留；剩余的链接不会导入。';

  @override
  String get archiveImportLeaveConfirm => '停止并退出';

  @override
  String get shareNoLinks => '分享的文本中没有链接。';
}
