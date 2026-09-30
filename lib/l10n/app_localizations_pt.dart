// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Igual ao sistema';

  @override
  String get seriesShelfNone => 'Sem status';

  @override
  String get seriesShelfPlanned => 'Para ler';

  @override
  String get seriesShelfReading => 'Lendo';

  @override
  String get seriesShelfPaused => 'Em pausa';

  @override
  String get seriesShelfCompleted => 'Concluída';

  @override
  String get seriesShelfDropped => 'Abandonada';

  @override
  String get seriesReleaseOngoing => 'Em andamento';

  @override
  String get seriesReleaseCompleted => 'Finalizada';

  @override
  String get seriesReleaseHiatus => 'Em hiato';

  @override
  String get seriesReleaseCancelled => 'Cancelada';

  @override
  String get seriesReleaseUnknown => 'Status desconhecido';

  @override
  String get seriesNotFound => 'Série não encontrada.';

  @override
  String get seriesOfflineTitle => 'Capítulos no Drive';

  @override
  String get seriesOfflineMessage =>
      'Sem conexão, a lista de capítulos desta série não aparece. Ela surge sozinha assim que a rede voltar.';

  @override
  String get seriesNoIndexTitle => 'Sem índice';

  @override
  String get seriesNoIndexMessage =>
      'Esta série não tem um index.json: é preciso gerar os índices de novo com o arquivador que a escreveu.';

  @override
  String get seriesNoChaptersTitle => 'Nenhum capítulo';

  @override
  String get seriesNoChaptersMessage =>
      'Nenhum capítulo corresponde à busca e aos filtros escolhidos.';

  @override
  String seriesDownloadAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Baixar $count capítulos?',
      one: 'Baixar um capítulo?',
    );
    return '$_temp0';
  }

  @override
  String get seriesDownloadAllMessage =>
      'Todos os capítulos que agora são lidos pelo Drive vão para o celular, e de lá você os lê também sem rede.';

  @override
  String get seriesDownload => 'Baixar';

  @override
  String seriesCleanupRemote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos lidos ainda estão no Drive',
      one: 'Um capítulo lido ainda está no Drive',
    );
    return '$_temp0';
  }

  @override
  String seriesCleanupLocal(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos lidos ocupam $size',
      one: 'Um capítulo lido ocupa $size',
    );
    return '$_temp0';
  }

  @override
  String seriesDownloadFailed(String error) {
    return 'Falha no download: $error. Tente de novo';
  }

  @override
  String get seriesDownloadWaiting =>
      'Aguardando a rede: recomeça sozinho. Cancelar';

  @override
  String get seriesDownloadQueued => 'Na fila. Cancelar';

  @override
  String get seriesDownloadCancel => 'Cancelar o download';

  @override
  String get seriesPlaceLocal => 'No celular';

  @override
  String get seriesPlaceDrive => 'No Drive';

  @override
  String get seriesPlaceMixed => 'Celular e Drive';

  @override
  String get seriesMuteTooltipOn =>
      'Notificações de capítulos novos silenciadas';

  @override
  String get seriesMuteTooltipOff => 'Notificações de capítulos novos ativas';

  @override
  String get seriesMuteUnmuted => 'Notificações de capítulos novos reativadas.';

  @override
  String get seriesMuteMuted => 'Notificações de capítulos novos silenciadas.';

  @override
  String seriesCaughtUpMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Em dia com o que está no celular: faltam $count capítulos anunciados.',
      one: 'Em dia com o que está no celular: falta um capítulo anunciado.',
    );
    return '$_temp0';
  }

  @override
  String get seriesCaughtUpAll => 'Lida por inteiro.';

  @override
  String get seriesResumeToContinue => 'PARA CONTINUAR';

  @override
  String get seriesResumeToStart => 'PARA COMEÇAR';

  @override
  String get seriesResumeHalfway => 'DEIXADO NO MEIO';

  @override
  String seriesResumePage(int page, int total) {
    return 'página $page de $total';
  }

  @override
  String get seriesContinue => 'Continuar';

  @override
  String get seriesStart => 'Começar';

  @override
  String get seriesResume => 'Retomar';

  @override
  String get seriesNextChapter => 'Próximo capítulo';

  @override
  String get seriesFigureChapters => 'Capítulos';

  @override
  String get seriesFigureRead => 'Lidos';

  @override
  String get seriesFigureProgress => 'Progresso';

  @override
  String get seriesFigureRating => 'Nota';

  @override
  String get seriesMyShelf => 'Minha estante';

  @override
  String get seriesFavoriteOn => 'Favorita';

  @override
  String get seriesFavoriteOff => 'Favoritos';

  @override
  String get seriesRatingButton => 'Nota';

  @override
  String seriesRatingOutOfTen(int rating) {
    return '$rating/10';
  }

  @override
  String get seriesCollections => 'Coleções';

  @override
  String get seriesNotes => 'Notas';

  @override
  String get seriesRatingSheetTitle => 'Que nota você dá?';

  @override
  String get seriesNotesHint => 'Onde você parou, o que achou…';

  @override
  String get seriesSave => 'Salvar';

  @override
  String get seriesRatingWord1 => 'Péssimo';

  @override
  String get seriesRatingWord2 => 'Ruim';

  @override
  String get seriesRatingWord3 => 'Fraco';

  @override
  String get seriesRatingWord4 => 'Medíocre';

  @override
  String get seriesRatingWord5 => 'Regular';

  @override
  String get seriesRatingWord6 => 'Razoável';

  @override
  String get seriesRatingWord7 => 'Bom';

  @override
  String get seriesRatingWord8 => 'Ótimo';

  @override
  String get seriesRatingWord9 => 'Excelente';

  @override
  String get seriesRatingWord10 => 'Obra-prima';

  @override
  String get seriesRatingNone => 'Sem nota';

  @override
  String get seriesRatingHint => 'Toque ou deslize';

  @override
  String seriesRatingBefore(int rating) {
    return 'Antes: $rating';
  }

  @override
  String get seriesRatingRemove => 'Remover';

  @override
  String get seriesRatingSave => 'Salvar a nota';

  @override
  String get seriesSynopsis => 'Sinopse';

  @override
  String get seriesGenres => 'Gêneros';

  @override
  String get seriesTags => 'Tags';

  @override
  String get seriesCreators => 'Quem fez';

  @override
  String seriesMoreTags(int count) {
    return 'Mais $count';
  }

  @override
  String get seriesPaceToRead => 'Para ler';

  @override
  String seriesPaceCaption(int chapters, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      chapters,
      locale: localeName,
      other: '$chapters capítulos',
      one: 'um capítulo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages páginas',
      one: 'uma página',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get seriesPaceNext => 'Próximo capítulo';

  @override
  String get seriesPaceNextCaption => 'pelo ritmo dos últimos';

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
      other: '$count dias',
      one: '1 dia',
    );
    return '$_temp0';
  }

  @override
  String get seriesWhenLate => 'atrasado';

  @override
  String get seriesWhenExpected => 'esperado';

  @override
  String get seriesWhenToday => 'hoje';

  @override
  String get seriesWhenTomorrow => 'amanhã';

  @override
  String seriesWhenInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'em $count dias',
      one: 'em 1 dia',
    );
    return '$_temp0';
  }

  @override
  String seriesWhenInWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'em $count semanas',
      one: 'em 1 semana',
    );
    return '$_temp0';
  }

  @override
  String get seriesShowLess => 'Reduzir';

  @override
  String get seriesShowMore => 'Ler tudo';

  @override
  String get seriesChaptersTitle => 'Capítulos';

  @override
  String seriesChaptersOf(int total) {
    return 'de $total';
  }

  @override
  String get seriesSearchChapter => 'Buscar capítulo…';

  @override
  String get seriesSortNewest => 'Do mais recente';

  @override
  String get seriesSortOldest => 'Do primeiro';

  @override
  String get seriesMarkAll => 'Marcar todos';

  @override
  String get seriesDownloadFromDrive => 'Baixar do Drive';

  @override
  String get seriesFreeSpace => 'Liberar espaço';

  @override
  String get seriesFilterUnread => 'Para ler';

  @override
  String get seriesFilterDownloaded => 'Baixados';

  @override
  String get seriesFilterAll => 'Todos';

  @override
  String seriesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionados',
      one: '1 selecionado',
    );
    return '$_temp0';
  }

  @override
  String get seriesMarkReadMany => 'Marcar como lidos';

  @override
  String get seriesMarkUnread => 'Marcar para ler';

  @override
  String get seriesMarkRead => 'Marcar como lido';

  @override
  String get seriesMarkReadThrough => 'Marcar como lido até aqui';

  @override
  String get seriesSimilar => 'Parecidas';

  @override
  String get seriesChapterNotDownloaded => 'Não baixado';

  @override
  String seriesChapterPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count páginas',
      one: '1 página',
    );
    return '$_temp0';
  }

  @override
  String get seriesDownloadToPhone => 'Baixar no celular';

  @override
  String get readerSeriesUnavailable => 'Série indisponível.';

  @override
  String get readerNoPagesIndex =>
      'Esta série não tem um pages.json: é preciso gerar os índices de novo com o arquivador que a escreveu.';

  @override
  String get readerSeriesOffline =>
      'Sem conexão não é possível abrir esta série: a lista das páginas está no Drive. Ela abre assim que a rede voltar.';

  @override
  String get readerChapterNotOnPhone =>
      'Este capítulo ainda não está no celular. A sincronização pode estar pela metade: tente de novo mais tarde.';

  @override
  String get readerChapterNoPages => 'O capítulo não tem páginas legíveis.';

  @override
  String get readerPagesNotOnPhone =>
      'As páginas deste capítulo ainda não estão no celular. O índice as anuncia, mas os arquivos não: é a pasta sincronizada que precisa trazê-los.';

  @override
  String get readerMarkEarlierTitle => 'Marcar os anteriores como lidos?';

  @override
  String readerMarkEarlierBody(int count, String chapter) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Você terminou $chapter. Os $count capítulos anteriores ainda constam como não lidos: se você já os leu em outro lugar, marque todos como lidos de uma vez.',
      one:
          'Você terminou $chapter. O capítulo anterior ainda consta como não lido: se você já o leu em outro lugar, marque-o como lido.',
    );
    return '$_temp0';
  }

  @override
  String readerMarkEarlierConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Marcar os $count como lidos',
      one: 'Marcar o anterior como lido',
    );
    return '$_temp0';
  }

  @override
  String get readerMarkEarlierDecline => 'Deixar para ler';

  @override
  String readerBookmarkAdded(int page) {
    return 'Página $page guardada';
  }

  @override
  String get readerChapters => 'Capítulos';

  @override
  String get readerBookmarks => 'Páginas guardadas';

  @override
  String get readerNoBookmarks => 'Nenhuma página guardada';

  @override
  String get readerNoBookmarksHint =>
      'O marcador guarda o ponto de uma página; o do capítulo já fica guardado pela retomada.';

  @override
  String readerBookmarkPage(int page) {
    return 'página $page';
  }

  @override
  String get readerBookmarkRemove => 'Remover';

  @override
  String get readerToTop => 'Voltar ao topo';

  @override
  String get readerPageNotFromDrive => 'Página não veio do Drive';

  @override
  String get readerPageUnreadable => 'Página ilegível';

  @override
  String get readerPageNotSynced => 'Página não sincronizada';

  @override
  String get readerPageNotDownloaded => 'Página ainda não baixada';

  @override
  String get readerPageOfflineHint =>
      'Sem conexão. Ela chega sozinha assim que a rede voltar.';

  @override
  String get readerRetryNow => 'Tentar agora';

  @override
  String get readerLastChapterOnPhone =>
      'É o último capítulo que está no celular.';

  @override
  String get readerNextChapter => 'Capítulo seguinte';

  @override
  String get readerContinue => 'Continuar';

  @override
  String get readerBookmarkThisPage => 'Guardar esta página';

  @override
  String get readerHowToRead => 'Como ler';

  @override
  String get readerPreviousChapter => 'Capítulo anterior';

  @override
  String get readerNextChapterTooltip => 'Próximo capítulo';

  @override
  String get readerSearchChapter => 'Buscar capítulo…';

  @override
  String get readerNewestFirst => 'Do mais recente';

  @override
  String get readerOldestFirst => 'Do primeiro';

  @override
  String readerReadingNow(String current, int total) {
    return 'Lendo: $current / $total capítulos';
  }

  @override
  String get readerMode => 'Modo de leitura';

  @override
  String get readerModeStrip => 'Tira';

  @override
  String get readerModePage => 'Página';

  @override
  String get readerDirection => 'Sentido de leitura';

  @override
  String get readerDirectionLtr => 'Esquerda → direita';

  @override
  String get readerDirectionRtl => 'Direita → esquerda';

  @override
  String get readerFit => 'Ajuste';

  @override
  String get readerBackground => 'Fundo';

  @override
  String get readerBrightness => 'Brilho';

  @override
  String get readerAutoScroll => 'Rolagem automática';

  @override
  String get readerAutoScrollOff => 'desligada';

  @override
  String readerAutoScrollRate(int rate) {
    return '$rate páginas/min';
  }

  @override
  String get readerShowPageNumber => 'Número da página';

  @override
  String get readerShowProgress => 'Barra de progresso';

  @override
  String get readerShowScrollTop => 'Botão para voltar ao topo';

  @override
  String get readerKeepAwake => 'Manter a tela ligada';

  @override
  String get readerDoublePage => 'Duas páginas lado a lado';

  @override
  String get readerLockRotation => 'Bloquear a rotação';

  @override
  String get archiveTitle => 'Baixar um mangá';

  @override
  String get archiveIntro =>
      'Busque um título nos sites compatíveis ou cole o link de uma série: o Kagami a baixa do site para a biblioteca, com metadados, capa e a lista completa de capítulos.';

  @override
  String get archiveSearchHint => 'Buscar um mangá pelo título';

  @override
  String get archiveClear => 'Limpar';

  @override
  String get archivePaste => 'Colar';

  @override
  String get archiveReading => 'Lendo a série…';

  @override
  String get archiveVerify => 'Verificar série';

  @override
  String archiveSeriesSummary(String site, int count, String status) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos',
      one: '1 capítulo',
    );
    return '$site · $_temp0 · $status';
  }

  @override
  String archiveKnown(int archived, int total) {
    return 'Já na biblioteca: $archived de $total capítulos. Os que já estão são ignorados.';
  }

  @override
  String get archiveWhatSection => 'O que baixar';

  @override
  String get archiveModeAll => 'Toda';

  @override
  String get archiveModeFrom => 'A partir do capítulo';

  @override
  String get archiveModePick => 'Escolhidos';

  @override
  String get archiveModeAllHint =>
      'Todos os capítulos. Se repetir mais tarde, vêm só os novos ou os danificados.';

  @override
  String get archiveModeFromHint =>
      'Do capítulo escolhido em diante: os anteriores ficam na lista da série, marcados como não baixados.';

  @override
  String get archiveModePickHint =>
      'Só os capítulos tocados. Os outros ficam na lista, não baixados.';

  @override
  String get archiveChapterNumberHint => 'Número do capítulo, como no site';

  @override
  String archivePickedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count escolhidos',
      one: '1 escolhido',
    );
    return '$_temp0';
  }

  @override
  String get archiveSelectAll => 'Todos';

  @override
  String get archiveSelectNone => 'Nenhum';

  @override
  String get archiveWhereSection => 'Onde';

  @override
  String get archiveWhereServer => 'Servidor';

  @override
  String get archiveWhereDrive => 'Drive';

  @override
  String get archiveWhereDriveAndPhone => 'Drive e celular';

  @override
  String get archiveWherePhone => 'Celular';

  @override
  String get archiveWhereDriveHint =>
      'Na pasta do Drive da biblioteca. As páginas passam pelo celular e saem assim que o Drive as recebe: você lê em streaming ou baixa depois.';

  @override
  String get archiveWhereDriveAndPhoneHint =>
      'Na pasta do Drive da biblioteca, e os capítulos ficam também no celular para ler sem rede.';

  @override
  String get archiveWherePhoneHint =>
      'No celular, na pasta dos mangás ou no espaço do app. Conectando o Drive, dá para baixar direto para lá.';

  @override
  String archiveServerHint(String name, String folder, String other) {
    String _temp0 = intl.Intl.selectLogic(other, {
      'other': ' Atenção: não é a pasta que o app lê.',
      'same': '',
    });
    return 'O servidor «$name» o baixa e o envia para «$folder» no Drive, mesmo com o celular desligado. As séries em andamento são acompanhadas pelo servidor.$_temp0';
  }

  @override
  String get archiveDelaySection => 'Pausa entre as requisições';

  @override
  String get archiveDelayNone => 'Nenhuma';

  @override
  String archiveDelaySeconds(String seconds) {
    return '$seconds s';
  }

  @override
  String get archiveDelayHint =>
      'Os sites não gostam de quem baixa em rajada: uma pausa curta evita ser bloqueado.';

  @override
  String get archiveDownloadAll => 'Baixar a série toda';

  @override
  String get archiveDownloadFrom => 'Baixar a partir do capítulo escolhido';

  @override
  String archiveDownloadPicked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Baixar $count capítulos',
      one: 'Baixar 1 capítulo',
    );
    return '$_temp0';
  }

  @override
  String archiveNoResults(String site) {
    return 'Nenhum resultado em $site.';
  }

  @override
  String archiveChaptersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos',
      one: '1 capítulo',
    );
    return '$_temp0';
  }

  @override
  String archiveVerifySite(String site) {
    return 'Verificar $site';
  }

  @override
  String get archiveVerifySiteHint =>
      'O site quer saber se você é uma pessoa: ao tocar, a verificação abre e depois a busca é feita lá também';

  @override
  String get archiveStatusOngoing => 'em andamento';

  @override
  String get archiveStatusCompleted => 'finalizada';

  @override
  String get archiveStatusHiatus => 'em hiato';

  @override
  String get archiveStatusCancelled => 'cancelada';

  @override
  String get archiveStatusUnknown => 'status desconhecido';

  @override
  String get archiveErrChallenge =>
      'O site exige uma verificação que não dá para fazer por aqui.';

  @override
  String get archiveErrOffline => 'Sem conexão: o site não responde.';

  @override
  String get archiveErrVerifyIncomplete =>
      'A verificação do site não foi concluída.';

  @override
  String archiveQueuedSnack(String title) {
    return '«$title» está na fila. Continua mesmo com a tela desligada.';
  }

  @override
  String archiveQueuedServerSnack(String title, String server) {
    return '«$title» está na fila em «$server». O celular pode até desligar.';
  }

  @override
  String get archiveServerFallbackName => 'servidor';

  @override
  String get archiveDownloads => 'Downloads';

  @override
  String get archiveClearHistory => 'Limpar';

  @override
  String get archiveQueueStopped => 'Fila parada';

  @override
  String get archiveQueueResumeHint =>
      'Recomeça sozinha; ao tocar, você a inicia agora';

  @override
  String archiveJobAutomatic(String destination) {
    return 'Capítulos novos · $destination';
  }

  @override
  String archiveJobQueued(String destination) {
    return 'Na fila · $destination';
  }

  @override
  String get archiveRemoveFromQueue => 'Tirar da fila';

  @override
  String archiveHistoryLine(String when, String message) {
    return '$when · $message';
  }

  @override
  String get archiveSites => 'Sites compatíveis';

  @override
  String get archiveMoreSites =>
      'Outros sites estão chegando: o suporte a novos provedores virá nas próximas atualizações.';

  @override
  String archiveLinkCopied(String url) {
    return '$url copiado para a área de transferência.';
  }

  @override
  String get archiveTracked => 'Séries em andamento';

  @override
  String get archiveTrackedIntro =>
      'As séries em andamento baixadas por aqui são verificadas de novo: chegam só os capítulos novos, no mesmo destino. As do servidor são acompanhadas pelo servidor.';

  @override
  String get archiveCheckDaily => 'Verificação diária';

  @override
  String get archiveCheckManual => 'Só manualmente';

  @override
  String archiveCheckAt(String time) {
    return 'Às $time, mesmo com o app fechado';
  }

  @override
  String get archiveCheckTime => 'Horário';

  @override
  String get archiveCheckTimeHelp => 'Horário da verificação';

  @override
  String get archiveWifiOnly => 'Só com Wi-Fi';

  @override
  String get archiveWifiOnlyOn =>
      'Espera uma rede que não seja cobrada por consumo';

  @override
  String get archiveWifiOnlyOff => 'Também com dados móveis';

  @override
  String get archiveCheckNow => 'Verificar agora';

  @override
  String get archiveNoTracked => 'Nenhuma série para acompanhar, por enquanto';

  @override
  String archiveTrackedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries para acompanhar',
      one: '1 série para acompanhar',
    );
    return '$_temp0';
  }

  @override
  String archiveTrackedLine(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos conhecidos',
      one: '1 capítulo conhecido',
    );
    return '$_temp0 · $destination';
  }

  @override
  String archiveTrackedLineChecked(int count, String destination, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos conhecidos',
      one: '1 capítulo conhecido',
    );
    return '$_temp0 · $destination · verificada $when';
  }

  @override
  String get archiveStopFollowing => 'Deixar de acompanhar';

  @override
  String archiveCheckQueued(String names) {
    return 'capítulos novos para $names';
  }

  @override
  String archiveCheckRemoved(String names) {
    return '$names agora finalizada';
  }

  @override
  String archiveCheckFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count não alcançadas',
      one: '1 não alcançada',
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
  String get archiveNoNewChapters => 'Nenhum capítulo novo.';

  @override
  String get archiveNoConnection => 'Sem conexão.';

  @override
  String get archiveForgetTitle => 'Deixar de acompanhar?';

  @override
  String archiveForgetBody(String title) {
    return 'Os capítulos novos de «$title» não chegarão mais sozinhos. Os já baixados permanecem.';
  }

  @override
  String get archiveCancel => 'Cancelar';

  @override
  String get archiveForgetConfirm => 'Deixar';

  @override
  String archiveStartIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos.',
      one: '1 capítulo.',
    );
    return '$_temp0 Baixe tudo ou escolha a partir de qual capítulo começar: os anteriores ficam na lista do leitor, sem páginas.';
  }

  @override
  String get archiveStartNoMatch => 'Nenhum capítulo com este número.';

  @override
  String archiveStartFrom(String title, int remaining) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: '$remaining capítulos',
      one: '1 capítulo',
    );
    return 'De «$title» em diante: $_temp0.';
  }

  @override
  String get archiveStartNone =>
      'Nenhum capítulo escolhido: dá para baixar tudo.';

  @override
  String get archiveStartAll => 'Baixar tudo';

  @override
  String get archiveStartHere => 'A partir daqui';

  @override
  String get browserTitle => 'Verificação do site';

  @override
  String get browserPhoneOnly => 'A verificação só é feita pelo celular.';

  @override
  String get browserInstructionsChapters =>
      'O site quer saber se você é uma pessoa. Conclua a verificação: quando a lista de capítulos aparecer, o Kagami percebe e volta sozinho.';

  @override
  String get browserInstructionsSearch =>
      'O site quer saber se você é uma pessoa. Conclua a verificação: quando a busca do site aparecer, o Kagami percebe e volta sozinho.';

  @override
  String get browserSearchPhoneOnly => 'Neste site só se busca pelo celular.';

  @override
  String get browserSearchSuperseded =>
      'Substituída por uma busca mais recente.';

  @override
  String get browserResponseTooLarge => 'Resposta grande demais.';

  @override
  String get serverTitle => 'Servidor';

  @override
  String get serverClear => 'Limpar';

  @override
  String get serverUnavailableNoSecret =>
      'Esta versão do app não pode conectar servidores: quem a compilou não informou o segredo do cliente Web (GOOGLE_SERVER_CLIENT_SECRET).';

  @override
  String get serverUnavailableAndroidOnly =>
      'Só é possível conectar um servidor pelo Android.';

  @override
  String get serverSignInRequired => 'Entre com o Google para usar o servidor.';

  @override
  String get serverNoConnection => 'Sem conexão.';

  @override
  String get serverMissingGoogleServices =>
      'Falta o google-services.json: esta versão não tem o cliente do Google.';

  @override
  String get serverDriveAccessDenied =>
      'O Google não concedeu acesso ao Drive.';

  @override
  String get serverGoogleNotResponding =>
      'O Google não responde: tente de novo daqui a pouco.';

  @override
  String serverWhenToday(String clock) {
    return 'hoje às $clock';
  }

  @override
  String serverWhenDate(String date, String clock) {
    return '$date às $clock';
  }

  @override
  String serverProgressStats(int pages, String size, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: ' · $skipped já em ordem',
      zero: '',
    );
    return '$pages páginas novas · $size$_temp0';
  }

  @override
  String get serverRemoveFromQueue => 'Tirar da fila';

  @override
  String get serverNoFirebase =>
      'O servidor reconhece quem o usa pela conta Google, que não existe nesta versão do app.';

  @override
  String get serverSignedOutIntro =>
      'Um computador sempre ligado pode baixar e enviar para o seu Drive no lugar do celular, que enquanto isso pode até desligar. O servidor reconhece você pela sua conta Google.';

  @override
  String get serverSignIn => 'Entrar com o Google';

  @override
  String get serverSignInSubtitle =>
      'Para criar o seu servidor ou usar o de outra pessoa';

  @override
  String serverInviteTitle(String sender, String serverName) {
    return '$sender deu a você acesso a «$serverName»';
  }

  @override
  String get serverInviteSubtitle =>
      'Baixa no seu Drive, mesmo com o celular desligado. Toque para conectar';

  @override
  String get serverIgnore => 'Ignorar';

  @override
  String get serverLinkIntro =>
      'Um computador sempre ligado — o seu ou o de quem deu acesso a você — pode baixar e enviar para o seu Drive no lugar do celular, que enquanto isso pode até desligar.';

  @override
  String get serverCreate => 'Criar o seu servidor';

  @override
  String get serverCreateSubtitle =>
      'Um comando para colar em um computador com Docker: nada para configurar';

  @override
  String get serverLinkTitle => 'Conectar um servidor';

  @override
  String get serverLinkSubtitle =>
      'O seu, já ligado, ou o de quem adicionou você';

  @override
  String get serverStateConnecting => 'Conectando…';

  @override
  String get serverStateNoGrant => 'Ainda não tem a permissão do seu Drive';

  @override
  String get serverStateNoFolder =>
      'Ainda não sabe em qual pasta do seu Drive escrever';

  @override
  String serverStateReady(String folder) {
    return 'Pronto · escreve em «$folder» no seu Drive';
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
  String get serverPlainTitle => 'A conexão não é criptografada';

  @override
  String get serverPlainSubtitle =>
      'O token da sua conta pode ser lido no caminho: é preciso HTTPS (Tailscale Funnel, um reverse proxy)';

  @override
  String get serverGrantTitle => 'Dê o seu Drive ao servidor';

  @override
  String get serverGrantSubtitle =>
      'Ele vai baixar na pasta que o app lê, mesmo com o celular desligado';

  @override
  String get serverUseAppFolder => 'Usar a pasta do app';

  @override
  String serverUseAppFolderSubtitle(String serverFolder, String appFolder) {
    return 'O servidor escreve em «$serverFolder», o app lê «$appFolder»';
  }

  @override
  String get serverUsersTitle => 'Quem pode usar';

  @override
  String get serverUsersOnlyYou =>
      'Só você. Adicione a conta Google de quem quiser';

  @override
  String serverUsersCount(int count) {
    return '$count contas, incluindo a sua';
  }

  @override
  String get serverQueueWaiting => 'Fila em espera';

  @override
  String get serverQueueRestarts => 'O servidor recomeça sozinho';

  @override
  String get serverJobAutomatic => 'Capítulos novos · no servidor';

  @override
  String get serverJobQueued => 'Na fila · no servidor';

  @override
  String get serverOngoingTitle => 'Séries em andamento no servidor';

  @override
  String serverOngoingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count para acompanhar',
      zero: 'Nenhuma, por enquanto',
    );
    return '$_temp0';
  }

  @override
  String get serverOngoingCheckOff => 'verificação desligada';

  @override
  String serverOngoingCheckAt(String clock) {
    return 'verificação às $clock';
  }

  @override
  String serverOngoingSubtitle(String count, String check) {
    return '$count · $check. Toque para verificar agora';
  }

  @override
  String serverSeriesKnown(int count) {
    return '$count capítulos conhecidos';
  }

  @override
  String serverSeriesKnownChecked(int count, String when) {
    return '$count capítulos conhecidos · verificada $when';
  }

  @override
  String get serverStopFollowing => 'Deixar de acompanhar';

  @override
  String get serverInviteRemoveFailed =>
      'Não consegui remover o convite: tente de novo.';

  @override
  String get serverCheckingNow =>
      'O servidor está verificando: os capítulos novos aparecem na fila dele.';

  @override
  String get serverPaste => 'Colar';

  @override
  String get serverAddressExposed =>
      'Atenção: sem criptografia em um endereço público, o token da sua conta pode ser lido no caminho. Use HTTPS (Tailscale Funnel, um reverse proxy) ou Tailscale.';

  @override
  String get serverAddressSavedNote =>
      'O endereço viaja com o backup e com a conta, como a pasta do Drive.';

  @override
  String get serverAddressMissing =>
      'Digite o endereço do servidor, por exemplo http://192.168.1.20:8080.';

  @override
  String serverLinked(String name, String folder) {
    return 'Conectado a «$name»: baixa em «$folder» no seu Drive.';
  }

  @override
  String serverLinkFromInvite(String sender, String serverName) {
    return '$sender adicionou você a «$serverName». Ao conectá-lo, o servidor vai baixar os mangás que você escolher na pasta da sua biblioteca no seu Drive: o Google vai pedir para você permitir que ele escreva lá. Quem administra o servidor poderá usar essa permissão.';
  }

  @override
  String serverLinkLinked(String account) {
    return 'O servidor reconhece você como $account. Ao desconectá-lo, se não for seu, ele esquece também a permissão do seu Drive e a sua fila.';
  }

  @override
  String get serverSignedInAccount => 'a conta com que você entrou';

  @override
  String get serverLinkNew =>
      'Digite o endereço do servidor: o seu ou o que foi passado por quem adicionou você. O servidor reconhece você pela conta Google e, na primeira vez, você dá a ele a permissão de escrever na pasta da sua biblioteca no Drive.';

  @override
  String get serverVerifying => 'Verificando…';

  @override
  String get serverVerifyAgain => 'Verificar de novo';

  @override
  String get serverVerifyAndLink => 'Verificar e conectar';

  @override
  String get serverUnlink => 'Desconectar';

  @override
  String get serverDefaultNameOwn => 'Meu Kagami Server';

  @override
  String serverDefaultNameOf(String name) {
    return 'Servidor de $name';
  }

  @override
  String get serverCommandCopied => 'Comando copiado.';

  @override
  String get serverComputerAddressMissing =>
      'Digite o endereço do computador, por exemplo http://192.168.1.20:8080.';

  @override
  String serverNotOwner(String owner) {
    return 'Esse servidor é de $owner: está conectado, mas não foi você que o criou.';
  }

  @override
  String serverReady(String name) {
    return '«$name» está pronto. Adicione quem quiser em «Quem pode usar».';
  }

  @override
  String get serverLibraryFolderFallback => 'a pasta da biblioteca';

  @override
  String serverSetupIntro(String folder) {
    return 'É preciso um computador que fique ligado — um mini PC, um NAS, um Raspberry Pi, um servidor na rede — com Docker. O servidor baixa os mangás e os envia para o seu Drive, em «$folder», mesmo com o celular desligado.';
  }

  @override
  String serverPrepareIntro(String signIn, String folder) {
    String _temp0 = intl.Intl.selectLogic(signIn, {
      'yes': 'primeiro você entra com o Google, depois ',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(folder, {
      'yes': 'escolhe a pasta dos mangás no Drive, depois ',
      'other': '',
    });
    return 'Preparo um comando que contém tudo: $_temp0${_temp1}o Google pede que você permita ao servidor escrever no seu Drive.';
  }

  @override
  String get serverPreparing => 'Preparando…';

  @override
  String get serverGenerate => 'Gerar o comando';

  @override
  String get serverStep1 =>
      'Instale o Docker no computador (docker.com), se ainda não tiver.';

  @override
  String get serverStep2 =>
      'Cole este comando no terminal dele. Ele contém a permissão do seu Drive: não envie a ninguém.';

  @override
  String get serverCopyCommand => 'Copiar o comando';

  @override
  String get serverStep3 =>
      'Digite aqui o endereço do computador: em casa, o da rede local; de fora, o nome dele no Tailscale ou o endereço HTTPS com que você o expõe.';

  @override
  String get serverPortNote => 'O servidor responde na porta 8080.';

  @override
  String get serverUsersIntro =>
      'Adicione a conta Google de quem quiser. No app Kagami da pessoa vai aparecer o convite: ao conectar o servidor, os downloads dela irão para o Drive dela, com a fila dela.';

  @override
  String get serverUserEmailInvalid =>
      'Digite o endereço da conta Google, por exemplo nome@gmail.com.';

  @override
  String serverUserAdded(String email) {
    return '$email pode usar o servidor: o app da pessoa avisa.';
  }

  @override
  String serverRemoveTitle(String email) {
    return 'Remover $email?';
  }

  @override
  String get serverRemoveBody =>
      'A pessoa não poderá mais usar o servidor. A fila dela e a permissão do Drive dela são apagadas; o que já está no Drive dela permanece.';

  @override
  String get serverCancel => 'Cancelar';

  @override
  String get serverRemove => 'Remover';

  @override
  String get serverAdd => 'Adicionar';

  @override
  String get serverOwnerYou => 'Você, o proprietário';

  @override
  String get serverConnected => 'Conectou o servidor';

  @override
  String get serverInvitedPending => 'Convidado, ainda não conectou o servidor';

  @override
  String get setupIntro =>
      'Lê a pasta de mangás que a sincronização deixa no celular, ou a mesma biblioteca direto do Google Drive, sem trazê-la toda para cá.';

  @override
  String get setupAccessTitle => 'Acesso aos arquivos';

  @override
  String get setupAccessBody =>
      'A pasta fica fora do espaço privado do app e contém dezenas de milhares de imagens: o Kagami precisa lê-las diretamente. Ele só escreve as cópias dos dados na subpasta reading/ da biblioteca e, se você pedir, os capítulos que baixar do Drive.';

  @override
  String get setupGrantAccess => 'Conceder acesso';

  @override
  String get setupFolderTitle => 'A pasta';

  @override
  String get setupFolderBody =>
      'Indique a pasta sincronizada pelo FolderSync: a que contém library.json e uma subpasta por série.';

  @override
  String get setupChooseFolder => 'Escolher a pasta';

  @override
  String get setupOr => 'ou';

  @override
  String get setupDriveTitle => 'Google Drive';

  @override
  String get setupDriveBody =>
      'Você entra com o Google e escolhe a pasta da biblioteca no Drive: as páginas chegam enquanto você lê, e os capítulos que quiser ter sempre à mão são baixados com um toque. Não é preciso acesso aos arquivos do celular.';

  @override
  String get setupReadFromDrive => 'Ler do Google Drive';

  @override
  String get setupLibraryProblemTitle => 'Biblioteca ilegível';

  @override
  String get setupChangeFolder => 'Trocar de pasta';

  @override
  String get driveFolderSheetTitle => 'Pasta no Drive';

  @override
  String get driveDestinationTitle => 'Onde salvo os mangás?';

  @override
  String get driveDestinationBody =>
      'Não há uma pasta de mangás no celular. Em uma pasta, os capítulos baixados permanecem mesmo se o app for desinstalado, e o Kagami os lê junto com os que já existem. No espaço do app não é preciso nenhuma permissão, mas eles se vão com o app.';

  @override
  String get driveChooseFolder => 'Escolher uma pasta';

  @override
  String get driveInAppSpace => 'No espaço do app';

  @override
  String get driveMyDrive => 'Meu Drive';

  @override
  String get driveSharedWithMe => 'Compartilhados comigo';

  @override
  String get driveBack => 'Voltar';

  @override
  String get driveNoResponse => 'O Drive não responde';

  @override
  String get driveRetry => 'Tentar de novo';

  @override
  String get driveIsLibrary => 'Contém library.json: é uma biblioteca';

  @override
  String get driveNotLibrary =>
      'Não contém library.json: a biblioteca é a pasta que o tem';

  @override
  String get driveUseFolder => 'Usar esta pasta';

  @override
  String get driveNoFolders => 'Nenhuma pasta aqui';

  @override
  String get driveNoticeAuthRequired =>
      'O Kagami ainda não tem permissão para ler o Google Drive';

  @override
  String get driveAuthorize => 'Autorizar';

  @override
  String get driveSignIn => 'Entrar';

  @override
  String get driveNoticeOffline =>
      'Você está offline: dá para ler os capítulos do celular e as páginas do Drive já baixadas. O resto volta sozinho com a rede';

  @override
  String driveNoticeError(String message) {
    return 'Drive: $message. Aparece o que está no celular';
  }

  @override
  String get syncSummaryOff => 'Desligada';

  @override
  String get syncSummaryDownload => 'Do Drive para o celular';

  @override
  String get syncSummaryUpload => 'Do celular para o Drive';

  @override
  String get syncSummaryBoth => 'Nos dois sentidos';

  @override
  String syncSummaryManual(String direction) {
    return '$direction, manual';
  }

  @override
  String syncSummaryDaily(String direction, String time) {
    return '$direction, todo dia às $time';
  }

  @override
  String get syncTitle => 'Sincronização';

  @override
  String get syncIntro =>
      'Mantém iguais a pasta de mangás no celular e a do Drive, sem o FolderSync. Se você ainda o usa nesta pasta, desligue-o: duas sincronizações nos mesmos arquivos acabam se atrapalhando.';

  @override
  String get syncFolders => 'Pastas';

  @override
  String get syncOnPhone => 'No celular';

  @override
  String get syncNoFolderChosen => 'Nenhuma pasta escolhida';

  @override
  String get syncOnDrive => 'No Drive';

  @override
  String get syncDriveNotConnected => 'O Drive não está conectado';

  @override
  String get syncDirection => 'Sentido';

  @override
  String get syncDirectionOff => 'Desligada';

  @override
  String get syncDirectionFromDrive => 'Do Drive';

  @override
  String get syncDirectionToDrive => 'Para o Drive';

  @override
  String get syncDirectionBoth => 'Ambos';

  @override
  String get syncDescOff =>
      'Nada se move sozinho. A biblioteca do Drive é lida do mesmo jeito, e «Baixar» funciona como sempre.';

  @override
  String get syncDescDownload =>
      'O que chega ao Drive desce para o celular. Do celular nada sobe.';

  @override
  String get syncDescUpload =>
      'O que está no celular sobe para o Drive — por exemplo, as cópias dos dados em reading/backup. Os índices da biblioteca continuam sendo os do servidor.';

  @override
  String get syncDescBoth =>
      'O que muda de um lado chega ao outro; se mudou nos dois, vence o mais recente. Os índices da biblioteca só descem: são do servidor.';

  @override
  String get syncDeletions => 'Propagar as exclusões';

  @override
  String get syncDeletionsDownload => 'Remove do celular o que some do Drive';

  @override
  String get syncDeletionsUpload =>
      'Move para a lixeira do Drive o que você remove do celular';

  @override
  String get syncDeletionsBoth =>
      'De um lado para o outro; do Drive, só para a lixeira';

  @override
  String get syncDeletionsOnNote =>
      '«Liberar espaço» remove os capítulos lidos também do Drive, na próxima rodada.';

  @override
  String get syncDeletionsOffNote =>
      'Um arquivo removido de um lado permanece do outro e não volta: «Liberar espaço» libera o celular e deixa os capítulos no Drive.';

  @override
  String get syncDaily => 'Todo dia';

  @override
  String get syncScheduled => 'Sincronização programada';

  @override
  String get syncManualOnly => 'Só manualmente';

  @override
  String syncAtTime(String time) {
    return 'Às $time, mesmo com o app fechado';
  }

  @override
  String get syncTime => 'Horário';

  @override
  String get syncWifiOnly => 'Só com Wi-Fi';

  @override
  String get syncWifiOnlyOn =>
      'Espera uma rede que não seja cobrada por consumo';

  @override
  String get syncWifiOnlyOff => 'Também com dados móveis';

  @override
  String get syncScheduleNote =>
      'O Android decide o momento exato: se no horário escolhido não houver rede, a rodada começa assim que ela voltar.';

  @override
  String get syncNow => 'Agora';

  @override
  String get syncTimePickerHelp => 'Horário da sincronização';

  @override
  String get syncRunNow => 'Sincronizar agora';

  @override
  String get syncRunNowReady =>
      'Você pode continuar lendo: as cópias seguem sozinhas';

  @override
  String get syncRunNowNotReady =>
      'São necessárias a pasta do celular e a do Drive';

  @override
  String get syncPhaseListing => 'Vendo o que há no Drive…';

  @override
  String get syncPhaseComparing => 'Comparando com o celular…';

  @override
  String get syncPhaseNothing => 'Nada para copiar';

  @override
  String syncPhaseFiles(int done, int total) {
    return 'Arquivo $done de $total';
  }

  @override
  String get syncStop => 'Interromper';

  @override
  String get syncNever => 'Nunca sincronizada';

  @override
  String get syncNeverNote =>
      'A primeira rodada em uma pasta já cheia é rápida: os arquivos iguais são reconhecidos pelo tamanho';

  @override
  String syncLastScheduled(String date, String time) {
    return 'Última, programada: $date às $time';
  }

  @override
  String syncLastManual(String date, String time) {
    return 'Última, manual: $date às $time';
  }

  @override
  String syncOutcomeDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count baixados',
      one: '$count baixado',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeUploaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enviados',
      one: '$count enviado',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeDeletedLocal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count removidos do celular',
      one: '$count removido do celular',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeTrashed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count na lixeira do Drive',
      one: '$count na lixeira do Drive',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count com falha, serão tentados de novo',
      one: '$count com falha, será tentado de novo',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeErrorSoFar(String error, String done) {
    return '$error. Até ali: $done';
  }

  @override
  String get syncOutcomeAligned => 'Já estava tudo alinhado';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsAppearance => 'Aparência';

  @override
  String get settingsThemeDark => 'Escuro';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeSystem => 'Igual ao sistema';

  @override
  String get settingsLibrary => 'Biblioteca';

  @override
  String get settingsFolder => 'Pasta';

  @override
  String get settingsNoFolder => 'Nenhuma pasta escolhida';

  @override
  String get settingsReloadIndexes => 'Reler os índices';

  @override
  String get settingsReloadIndexesNote =>
      'Para fazer quando a sincronização acabou de trazer coisas novas';

  @override
  String get settingsIndexesReloaded => 'Índices relidos';

  @override
  String get settingsGoogleDrive => 'Google Drive';

  @override
  String get settingsReading => 'Leitura';

  @override
  String get settingsAccount => 'Conta';

  @override
  String get settingsData => 'Dados';

  @override
  String get settingsAbout => 'Sobre';

  @override
  String get settingsAutoBackup => 'Cópia automática na biblioteca';

  @override
  String get settingsAutoBackupNote =>
      'Uma vez por dia em reading/backup/, que a sincronização leva para o Drive junto com os mangás';

  @override
  String get settingsExport => 'Exportar os dados';

  @override
  String get settingsExportNote =>
      'Status, notas, histórico, coleções e marcadores em um arquivo';

  @override
  String get settingsExportDialog => 'Onde salvar o backup';

  @override
  String get settingsExportCancelled => 'Exportação cancelada';

  @override
  String get settingsExportSaved => 'Backup salvo';

  @override
  String get settingsImport => 'Importar de um backup';

  @override
  String get settingsImportNote =>
      'Mostra o que contém antes de mexer em qualquer coisa';

  @override
  String get settingsImportDialog => 'Escolha um backup do Kagami';

  @override
  String get settingsImportInvalid => 'Não é um backup do Kagami';

  @override
  String get settingsImportSheetTitle => 'Importar este backup?';

  @override
  String get settingsImportSeries => 'Séries';

  @override
  String get settingsImportRead => 'Lidos';

  @override
  String get settingsImportCollections => 'Coleções';

  @override
  String settingsImportExplain(String date) {
    return 'Feito em $date. Mesclar mantém o que você já tem e acrescenta: os capítulos lidos se somam e, no resto, vale o registro mais recente. Substituir apaga os dados deste dispositivo.';
  }

  @override
  String get settingsImportExplainUnknownDate =>
      'Feito em data desconhecida. Mesclar mantém o que você já tem e acrescenta: os capítulos lidos se somam e, no resto, vale o registro mais recente. Substituir apaga os dados deste dispositivo.';

  @override
  String get settingsImportMerge => 'Mesclar';

  @override
  String get settingsImportReplace => 'Substituir';

  @override
  String get settingsImportDone => 'Dados importados';

  @override
  String get settingsImportFailed => 'Falha na importação';

  @override
  String get settingsWipe => 'Excluir os dados pessoais';

  @override
  String get settingsWipeNote =>
      'Status, notas, histórico e coleções. Os mangás não são tocados';

  @override
  String get settingsWipeSheetTitle => 'Excluir todos os dados pessoais?';

  @override
  String get settingsWipeExplain =>
      'Somem status, notas, favoritos, capítulos lidos, histórico, sessões, coleções e marcadores deste dispositivo. Os mangás e os índices da biblioteca não são tocados.\n\nSe você não tem um backup, esta é a última chance de fazer um.';

  @override
  String get settingsWipeConfirm => 'Excluir tudo';

  @override
  String get settingsWipeDone => 'Dados pessoais excluídos';

  @override
  String get settingsDriveConnect => 'Conectar o Google Drive';

  @override
  String get settingsDriveConnectNote =>
      'Lê a biblioteca do Drive sem trazê-la toda para o celular e baixa só o que você escolher';

  @override
  String get settingsDriveFolder => 'Pasta no Drive';

  @override
  String get settingsDriveSync => 'Sincronização da pasta';

  @override
  String get settingsDriveDownloadsGo => 'Os capítulos baixados vão';

  @override
  String settingsDriveDownloadsFolder(String path) {
    return 'Para a pasta da biblioteca: $path';
  }

  @override
  String get settingsDriveDownloadsApp =>
      'Para o espaço do app: somem se ele for desinstalado';

  @override
  String get settingsDriveDownloadsAsk => 'Pergunta no primeiro download';

  @override
  String get settingsDriveCache => 'Páginas lidas do Drive';

  @override
  String settingsDriveCacheNote(String used, String limit) {
    return '$used em cache, no máximo $limit. Podem ser relidas sem rede';
  }

  @override
  String get settingsDriveCacheLimitTitle => 'Espaço para as páginas';

  @override
  String get settingsDriveClearCache => 'Esvaziar o cache';

  @override
  String get settingsDriveClearCacheNote =>
      'Os capítulos baixados não são tocados';

  @override
  String get settingsDriveDisconnect => 'Desconectar o Drive';

  @override
  String get settingsDriveDisconnectNote =>
      'A biblioteca volta a ser a pasta do celular. Os capítulos baixados permanecem';

  @override
  String get settingsAccountUnavailable => 'Conta indisponível aqui';

  @override
  String get settingsAccountUnavailableNote =>
      'Esta versão não tem Firebase: os dados ficam onde estão, no dispositivo';

  @override
  String get settingsAccountSignIn => 'Entrar com o Google';

  @override
  String get settingsAccountSignInNote =>
      'Notas, status, capítulos lidos, histórico e coleções acompanham a conta em vez do celular';

  @override
  String get settingsAccountSyncNow => 'Sincronizar agora';

  @override
  String get settingsAccountNeverSynced => 'Nunca sincronizado neste celular';

  @override
  String settingsAccountLastSync(String date, String time) {
    return 'Última vez em $date às $time';
  }

  @override
  String get settingsAccountSignOut => 'Sair';

  @override
  String get settingsAccountSignOutNote =>
      'Envia a última leitura e depois encerra a sessão';

  @override
  String get settingsAccountForget => 'Parar de guardar uma cópia';

  @override
  String get settingsAccountForgetNote =>
      'Apaga os dados da conta. Os deste celular permanecem onde estão';

  @override
  String get settingsAccountErrorNote =>
      'Os dados deste celular não foram tocados';

  @override
  String get settingsAccountForgetSheetTitle => 'Apagar os dados da conta?';

  @override
  String get settingsAccountForgetExplain =>
      'Some a cópia guardada para você, e a sessão é encerrada. Status, notas, histórico e coleções deste celular permanecem onde estão — mas não serão mais vistos em outro celular.';

  @override
  String get settingsAccountForgetConfirm => 'Apagar da conta';

  @override
  String get settingsReaderDirection => 'Sentido na leitura paginada';

  @override
  String get settingsReaderBackground => 'Fundo';

  @override
  String get settingsReaderKeepAwake => 'Manter a tela ligada';

  @override
  String get settingsReaderProgressBar => 'Barra de progresso';

  @override
  String get settingsProbe => 'Medir a fluidez';

  @override
  String get settingsProbeNote =>
      'No leitor, no alto: quadros lentos e perdidos, de onde vêm as faixas, GC. Um toque nos números os zera';

  @override
  String get settingsProbeInfo1 =>
      'Mostra no leitor, no canto superior esquerdo, um quadro de números sobre a fluidez da leitura. Serve para entender por que a rolagem trava: não muda nada em como você lê e custa muito pouco.';

  @override
  String get settingsProbeInfo2 =>
      'O número que mais conta é «perdidos»: os quadros que faltam enquanto a página rola. Cada um é um pequeno engasgo visível. «Atrasados» e «Lentos UI» dizem se o app estava ocupado, «GC Android» se o sistema estava liberando memória.';

  @override
  String get settingsProbeInfo3 =>
      '«Blocos», «inteiras», «do celular» e «Nativas» dizem de onde veio cada pedaço de página: as três primeiras são os caminhos leves, a última é o recorte feito na hora, que é o que pesa.';

  @override
  String get settingsProbeInfo4 =>
      'Um toque no quadro zera os números, para medir a partir de um ponto preciso do capítulo. Ao reabrir o app, a medição se desliga sozinha.';

  @override
  String get settingsTexture => 'Faixas nativas como textura';

  @override
  String get settingsTextureNote =>
      'Teste: as páginas ainda por cortar chegam à GPU sem passar pela interface. Desliga ao reabrir o app';

  @override
  String get settingsTextureInfo1 =>
      'As páginas muito altas de um webtoon são lidas em pedaços. Quase sempre os pedaços já estão prontos: cortados pelo arquivo no servidor ou pelo celular na primeira vez que o capítulo é aberto. Quando não estão, o decodificador do Android os recorta na hora.';

  @override
  String get settingsTextureInfo2 =>
      'Normalmente os pixels desses pedaços passam pelo app antes de chegar à tela. Com esta opção vão direto para a placa de vídeo: o app trabalha menos durante a rolagem, e ela pode travar menos. A qualidade da imagem não muda.';

  @override
  String get settingsTextureInfo3 =>
      'É um teste: é uma forma nova de desenhar, ainda não verificada neste celular. Se você vir páginas pretas, linhas ou cintilações, desligue. Se o celular não for compatível, o app volta sozinho ao modo normal.';

  @override
  String get settingsTextureInfo4 =>
      'Nos capítulos já cortados em blocos nada muda, porque ali este caminho não é usado. Ao reabrir o app, ela se desliga sozinha.';

  @override
  String get settingsWhatItDoes => 'O que faz';

  @override
  String get settingsBackupsTitle => 'Cópias na biblioteca';

  @override
  String get settingsBackupsNone =>
      'Nenhuma cópia ainda: a primeira é feita na próxima abertura';

  @override
  String settingsBackupsLatest(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cópias, a última $name',
      one: '1 cópia, a última $name',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupNow => 'Fazer uma cópia agora';

  @override
  String settingsBackupWritten(String path) {
    return 'Cópia gravada em $path';
  }

  @override
  String settingsVersion(String version, String build) {
    return 'versão $version ($build)';
  }

  @override
  String get settingsTagline => 'leitor para arquivos MALF locais';

  @override
  String get librarySortUpdated => 'Atualizadas recentemente';

  @override
  String get librarySortTitle => 'Título';

  @override
  String get librarySortProgress => 'Progresso';

  @override
  String get librarySortAdded => 'Adicionadas recentemente';

  @override
  String get librarySortLastRead => 'Lidas recentemente';

  @override
  String get librarySortUnread => 'Para ler';

  @override
  String get librarySortRating => 'Nota';

  @override
  String get librarySortChapters => 'Número de capítulos';

  @override
  String get librarySortShuffle => 'Aleatória';

  @override
  String get libraryDisplayComfortable => 'Grade confortável';

  @override
  String get libraryDisplayCompact => 'Grade compacta';

  @override
  String get libraryDisplayList => 'Lista';

  @override
  String get libraryDisplayDetailed => 'Lista detalhada';

  @override
  String get libraryAutoReading => 'Lendo';

  @override
  String get libraryAutoFresh => 'Novidades';

  @override
  String get libraryAutoFavorites => 'Favoritos';

  @override
  String get libraryAutoPlanned => 'Para começar';

  @override
  String get libraryAutoFinished => 'Concluídas';

  @override
  String libraryRowChapters(int count) {
    return '$count cap.';
  }

  @override
  String libraryRowUnread(int count) {
    return '$count para ler';
  }

  @override
  String get libraryNoMatchTitle => 'Nenhum resultado';

  @override
  String get libraryNoMatchMessage =>
      'Nenhuma série corresponde à busca e aos filtros escolhidos.';

  @override
  String get libraryEmptyTitle => 'Biblioteca vazia';

  @override
  String get libraryEmptyMessage =>
      'A biblioteca não contém séries. Se deveria, verifique a sincronização da pasta.';

  @override
  String get libraryClearFilters => 'Limpar os filtros';

  @override
  String get libraryTitle => 'Biblioteca';

  @override
  String get libraryCancelSelection => 'Cancelar seleção';

  @override
  String librarySelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionadas',
      one: '1 selecionada',
    );
    return '$_temp0';
  }

  @override
  String libraryAllWithCount(int count) {
    return 'Todas ($count)';
  }

  @override
  String get libraryAll => 'Todas';

  @override
  String get libraryMarkAllRead => 'Marcar tudo como lido';

  @override
  String get libraryMarkAllUnread => 'Marcar tudo para ler';

  @override
  String get libraryStatus => 'Status';

  @override
  String get libraryFavorites => 'Favoritos';

  @override
  String get libraryAddToCollection => 'Adicionar a uma coleção';

  @override
  String libraryStatusOfSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Status de $count séries',
      one: 'Status de 1 série',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries marcadas como lidas',
      one: '1 série marcada como lida',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries voltaram para ler',
      one: '1 série voltou para ler',
    );
    return '$_temp0';
  }

  @override
  String get librarySearchHint => 'Título, autor, tag:…';

  @override
  String get libraryLayout => 'Layout';

  @override
  String get libraryFiltersAndSort => 'Filtros e ordem';

  @override
  String get libraryReset => 'Limpar';

  @override
  String get librarySortSection => 'Ordenar';

  @override
  String get libraryShowOnly => 'Mostrar só';

  @override
  String get libraryOnlyUnread => 'Com capítulos para ler';

  @override
  String get libraryOnlyStarted => 'Começadas';

  @override
  String get libraryOnlyNew => 'Com capítulos novos';

  @override
  String get libraryOnlyFavorite => 'Favoritas';

  @override
  String get libraryMinRating => 'Nota mínima';

  @override
  String get libraryRelease => 'Publicação';

  @override
  String get libraryGenres => 'Gêneros';

  @override
  String get libraryTriHint => 'Um toque exige, dois excluem';

  @override
  String get libraryTags => 'Tags';

  @override
  String get libraryAuthors => 'Autores';

  @override
  String get homeEmptyTitle => 'Biblioteca vazia';

  @override
  String get homeEmptyMessage =>
      'Nada para explorar: a pasta ainda não contém nenhuma série.';

  @override
  String get homeToStart => 'Para começar';

  @override
  String get homeSimilarTitle => 'Por que você lê o que lê';

  @override
  String get homeSimilarSubtitle =>
      'Ainda não abertas, com os gêneros de que você gosta';

  @override
  String get homeRecentlyArrived => 'Chegaram recentemente';

  @override
  String get homeLeftHalfway => 'Deixadas no meio';

  @override
  String get homeLeftHalfwaySubtitle => 'Em pausa e abandonadas';

  @override
  String get homeCaughtUpTitle => 'Você está em dia';

  @override
  String get homeCaughtUpMessage =>
      'Com tudo o que está sincronizado. O próximo capítulo chegará com a pasta.';

  @override
  String get homeRandomSeries => 'Uma aleatória';

  @override
  String get homeReloadLibrary => 'Reler a biblioteca';

  @override
  String get homeGreetingNight => 'Madrugada';

  @override
  String get homeGreetingMorning => 'Bom dia';

  @override
  String get homeGreetingAfternoon => 'Boa tarde';

  @override
  String get homeGreetingEvening => 'Boa noite';

  @override
  String get homeStatRead => 'Lidos';

  @override
  String get homeStatReadCaption => 'capítulos no total';

  @override
  String get homeStatUnread => 'Para ler';

  @override
  String get homeStatUnreadCaption => 'no celular';

  @override
  String get homeStatStreak => 'Seguidos';

  @override
  String homeStatStreakCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dias',
      one: 'dia',
    );
    return '$_temp0';
  }

  @override
  String get homeResume => 'Retomar';

  @override
  String get homeNextChapter => 'Próximo capítulo';

  @override
  String get homeRead => 'Ler';

  @override
  String get homeUpdates => 'Atualizações';

  @override
  String get homeUpdatesSubtitle => 'Capítulos sincronizados e ainda não lidos';

  @override
  String homeLatestChapter(String number) {
    return 'cap. $number';
  }

  @override
  String get homeAgoToday => 'hoje';

  @override
  String get homeAgoYesterday => 'ontem';

  @override
  String homeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count dias',
      one: 'há 1 dia',
    );
    return '$_temp0';
  }

  @override
  String homeAgoWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count semanas',
      one: 'há 1 semana',
    );
    return '$_temp0';
  }

  @override
  String homeAgoMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count meses',
      one: 'há 1 mês',
    );
    return '$_temp0';
  }

  @override
  String homeAgoYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count anos',
      one: 'há 1 ano',
    );
    return '$_temp0';
  }

  @override
  String get collectionsTitle => 'Coleções';

  @override
  String get collectionsNew => 'Nova';

  @override
  String get collectionsAutomatic => 'Automáticas';

  @override
  String get collectionsYours => 'Suas coleções';

  @override
  String get collectionsNoneTitle => 'Nenhuma coleção';

  @override
  String get collectionsNoneMessage =>
      'São a forma de dar estrutura a uma biblioteca que cresce sozinha: uma série pode estar em várias coleções e a ordem é você quem escolhe.';

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
  String get collectionsEdit => 'Editar';

  @override
  String get collectionsRenameRecolor => 'Renomear e mudar a cor';

  @override
  String get collectionsDelete => 'Excluir a coleção';

  @override
  String get collectionsNotFound => 'Coleção não encontrada.';

  @override
  String get collectionsDone => 'Concluir';

  @override
  String get collectionsReorder => 'Reordenar';

  @override
  String get collectionsEmptyTitle => 'Coleção vazia';

  @override
  String get collectionsEmptyMessage =>
      'Você adiciona uma série pela ficha dela, ou mantendo uma capa pressionada na biblioteca.';

  @override
  String get collectionsRemoveFrom => 'Tirar da coleção';

  @override
  String get shellDataUnreadableTitle => 'Dados do app ilegíveis';

  @override
  String get shellRetry => 'Tentar de novo';

  @override
  String get shellTabHome => 'Início';

  @override
  String get shellTabLibrary => 'Biblioteca';

  @override
  String get shellTabCollections => 'Coleções';

  @override
  String get shellTabMore => 'Mais';

  @override
  String get moreTitle => 'Mais';

  @override
  String get moreSectionLibrary => 'Biblioteca';

  @override
  String get moreSectionReading => 'Sua leitura';

  @override
  String get moreSectionPrivacy => 'Privacidade';

  @override
  String get moreSectionApp => 'App';

  @override
  String get moreDownload => 'Baixar um mangá';

  @override
  String get moreDownloadSubtitle => 'Busque um título ou cole um link';

  @override
  String get moreHistory => 'Histórico';

  @override
  String get moreHistorySubtitle => 'O que você leu e quando';

  @override
  String get moreStatistics => 'Estatísticas';

  @override
  String get moreStatisticsSubtitle => 'Quanto você lê, o que lê, quando';

  @override
  String get moreIncognito => 'Leitura anônima';

  @override
  String get moreIncognitoSubtitle =>
      'Não registra posição, capítulos concluídos nem tempo de leitura';

  @override
  String get moreSettings => 'Configurações';

  @override
  String get moreSettingsSubtitle => 'Aparência, biblioteca, leitura, backup';

  @override
  String get historyTitle => 'Histórico';

  @override
  String get historyIncognitoOn => 'Modo anônimo ativo';

  @override
  String get historyIncognitoOff => 'Ler em modo anônimo';

  @override
  String get historyClear => 'Esvaziar';

  @override
  String get historyUnreadable => 'Histórico ilegível';

  @override
  String get historyEmptyTitle => 'Nada lido, por enquanto';

  @override
  String get historyEmptyMessage =>
      'Cada capítulo concluído aparecerá aqui com a sua data.';

  @override
  String get historyClearTitle => 'Esvaziar o histórico?';

  @override
  String get historyClearMessage =>
      'As datas de leitura e o tempo gasto lendo somem, e com eles as estatísticas que dependem disso. Os capítulos voltam para ler.';

  @override
  String get historyIncognitoBanner =>
      'Em modo anônimo: posição, capítulos concluídos e tempo de leitura não são registrados.';

  @override
  String get historyToday => 'Hoje';

  @override
  String get historyYesterday => 'Ontem';

  @override
  String get historyReread => 'Reler';

  @override
  String get historyRemove => 'Tirar do histórico';

  @override
  String get originLocal => 'No celular';

  @override
  String get originDrive => 'No Drive';

  @override
  String get originMixed => 'No celular, e outros capítulos no Drive';

  @override
  String get coverNoChapters => 'Nenhum capítulo baixado';

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
    return '$_temp0 · $unread para ler';
  }

  @override
  String coverNewChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos novos',
      one: '1 capítulo novo',
    );
    return '$_temp0';
  }

  @override
  String coverUnread(int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '$unread capítulos para ler',
      one: '1 capítulo para ler',
    );
    return '$_temp0';
  }

  @override
  String coverUnreadFresh(int unread, int fresh) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '$unread capítulos para ler',
      one: '1 capítulo para ler',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fresh,
      locale: localeName,
      other: '$fresh novos',
      one: '1 novo',
    );
    return '$_temp0, dos quais $_temp1';
  }

  @override
  String chartsDayNothing(String date) {
    return '$date: nada';
  }

  @override
  String chartsDayChapters(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos',
      one: '1 capítulo',
    );
    return '$date: $_temp0';
  }

  @override
  String get kitClose => 'Fechar';

  @override
  String get collectionSheetTitle => 'Coleções';

  @override
  String collectionSheetTitleMany(int count) {
    return 'Coleções de $count séries';
  }

  @override
  String get collectionSheetNew => 'Nova';

  @override
  String get collectionSheetEmptyTitle => 'Nenhuma coleção';

  @override
  String get collectionSheetEmptyMessage =>
      'Servem para dar estrutura a uma biblioteca que cresce sozinha.';

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
  String get collectionSheetCreateTitle => 'Nova coleção';

  @override
  String get collectionSheetEditTitle => 'Editar coleção';

  @override
  String get collectionSheetNameHint => 'Nome';

  @override
  String get collectionSheetColor => 'Cor';

  @override
  String get collectionSheetCreate => 'Criar';

  @override
  String get collectionSheetSave => 'Salvar';

  @override
  String get cleanupTitle => 'Liberar espaço?';

  @override
  String get cleanupSyncBusy =>
      'Uma sincronização está em andamento: tente de novo quando terminar';

  @override
  String cleanupNotAllDeleted(String error) {
    return 'Nem tudo foi apagado: $error';
  }

  @override
  String cleanupDriveError(String error) {
    return 'Drive: $error. O que já foi removido continua removido';
  }

  @override
  String cleanupFreed(String size) {
    return '$size liberados';
  }

  @override
  String get cleanupNeedsNetwork => 'Para remover do Drive é preciso ter rede';

  @override
  String cleanupIntroDrive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos já lidos ainda estão no Drive.',
      one: 'Um capítulo já lido ainda está no Drive.',
    );
    return '$_temp0';
  }

  @override
  String cleanupIntroPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos já lidos ainda ocupam espaço no celular.',
      one: 'Um capítulo já lido ainda ocupa espaço no celular.',
    );
    return '$_temp0';
  }

  @override
  String get cleanupPhoneChapters => 'Capítulos no celular';

  @override
  String get cleanupDriveCache => 'Cache do Drive';

  @override
  String get cleanupDriveChapters => 'Capítulos no Drive';

  @override
  String cleanupApproxSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos',
      one: '1 capítulo',
    );
    return '$_temp0 · cerca de $size';
  }

  @override
  String cleanupExactSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos',
      one: '1 capítulo',
    );
    return '$_temp0 · $size';
  }

  @override
  String cleanupApproxSizeTrash(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos',
      one: '1 capítulo',
    );
    return '$_temp0 · cerca de $size · para a lixeira';
  }

  @override
  String get cleanupQuiet => 'Não perguntar mais para esta série';

  @override
  String get cleanupWarnNotOnDrive =>
      'Esta série não está no Drive: os capítulos apagados não poderão ser relidos até que a sincronização os traga de volta.';

  @override
  String get cleanupWarnGoneEverywhere =>
      'Não restarão nem no celular nem no Drive.';

  @override
  String get cleanupWarnStaysOnDrive =>
      'Os capítulos permanecem no Drive e são relidos de lá.';

  @override
  String get cleanupWarnTrash =>
      'Da lixeira do Drive eles podem ser recuperados por trinta dias. O índice do servidor ainda os lista: se o servidor os enviar de novo, voltam a ser lidos pelo Drive.';

  @override
  String get cleanupDelete => 'Excluir';

  @override
  String get cleanupNotNow => 'Agora não';

  @override
  String get cleanupSyncWarnExternal =>
      'Se o FolderSync sincroniza a pasta nos dois sentidos, a exclusão pode chegar também ao Drive; se só baixa, os capítulos podem voltar na rodada seguinte.';

  @override
  String get cleanupSyncWarnOwn =>
      'A sincronização respeita esta escolha: o que você remove de um lado não volta e não some do outro, mesmo com as exclusões propagadas.';

  @override
  String get statsRangeMonth => '30 dias';

  @override
  String get statsRangeQuarter => '3 meses';

  @override
  String get statsRangeYear => 'Um ano';

  @override
  String get statsTitle => 'Estatísticas';

  @override
  String get statsUnavailable => 'Não foi possível calcular as estatísticas';

  @override
  String get statsChaptersRead => 'capítulos lidos';

  @override
  String get statsSeriesInLibrary => 'séries na biblioteca';

  @override
  String statsMinutes(int count) {
    return '$count min';
  }

  @override
  String statsHours(int count) {
    return '$count h';
  }

  @override
  String get statsReadingTime => 'tempo de leitura';

  @override
  String get statsReadingTimeHint => 'medido enquanto você lê';

  @override
  String get statsPagesSeen => 'páginas vistas';

  @override
  String get statsStreak => 'dias seguidos';

  @override
  String statsStreakRecord(int count) {
    return 'recorde: $count';
  }

  @override
  String get statsAverageRating => 'nota média';

  @override
  String statsRatedSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries avaliadas',
      one: '1 série avaliada',
    );
    return '$_temp0';
  }

  @override
  String get statsChaptersOverTime => 'Capítulos lidos';

  @override
  String get statsPerWeek => 'por semana';

  @override
  String get statsPerDay => 'por dia';

  @override
  String get statsActivityTitle => 'Quando você lê';

  @override
  String get statsActivitySubtitle =>
      'um quadradinho por dia, nos últimos seis meses';

  @override
  String get statsShelfTitle => 'A biblioteca por status';

  @override
  String statsGenreOthers(int count) {
    return 'Outros $count';
  }

  @override
  String get statsGenresTitle => 'Gêneros que você lê';

  @override
  String get statsGenresSubtitle => 'entre as séries que você começou';

  @override
  String get statsRatingsTitle => 'Como você avalia';

  @override
  String get statsRatingsSubtitle => 'quantas séries para cada nota';

  @override
  String get statsTopSeries => 'Séries mais lidas';

  @override
  String get statsShapeTitle => 'Como é a biblioteca';

  @override
  String get statsSyncedChapters => 'capítulos sincronizados';

  @override
  String get statsStillUnread => 'ainda para ler';

  @override
  String get statsOngoingSeries => 'séries em andamento';

  @override
  String statsAnnouncedMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos anunciados e não baixados',
      one: '1 capítulo anunciado e não baixado',
    );
    return '$_temp0';
  }

  @override
  String get statsBytesOnPhone => 'ocupados no celular';

  @override
  String get statsNoHistory =>
      'Nada lido neste período. O histórico começa a partir de quando o app passou a registrá-lo.';

  @override
  String get dataDriveNotLinked => 'O Drive não está conectado';

  @override
  String get dataChapterNotOnDrive => 'Capítulo não encontrado no Drive';

  @override
  String get dataChapterNoPagesOnDrive => 'O capítulo não tem páginas no Drive';

  @override
  String get dataPageNotOnDrive => 'Página não encontrada no Drive';

  @override
  String get dataPrefetchCancelled => 'Pré-carregamento cancelado';

  @override
  String get dataDriveAccessDenied => 'O Google não concedeu acesso ao Drive';

  @override
  String get dataDriveOfflineNeverOpened =>
      'Sem conexão, e a biblioteca no Drive nunca foi aberta neste celular';

  @override
  String get dataDriveSignedOut =>
      'Entre com o Google para ler a biblioteca no Drive';

  @override
  String get dataSyncMissingFolderOrDirection => 'Falta a pasta ou o sentido';

  @override
  String get dataSyncFailed => 'Falha na sincronização';

  @override
  String get dataSyncFolderUnreadable =>
      'Não é possível ler a pasta do celular';

  @override
  String get dataSyncBusy => 'Já há uma sincronização em andamento';

  @override
  String get dataSyncCancelled => 'Sincronização interrompida';

  @override
  String get dataSyncDirectionDownload => 'Do Drive';

  @override
  String get dataSyncDirectionUpload => 'Para o Drive';

  @override
  String get dataSyncDirectionBoth => 'Ambos';

  @override
  String dataServerInviteTitle(String sender) {
    return '$sender deu a você acesso ao servidor dele';
  }

  @override
  String dataServerInviteText(String serverName) {
    return 'Conecte «$serverName» e ele baixará os mangás no seu Drive, mesmo com o celular desligado.';
  }

  @override
  String get dataServerSignInRequired =>
      'Entre com o Google para usar o servidor.';

  @override
  String get dataServerNotLinked => 'Nenhum servidor conectado.';

  @override
  String dataServerUserNotNotified(String email, String url) {
    return '$email pode usar o servidor, mas não consegui avisar: envie você o endereço $url.';
  }

  @override
  String get dataPickLibraryFolderTitle =>
      'Escolha a pasta da biblioteca de mangás';

  @override
  String get dataCloudSignInNotEnabled =>
      'O login com o Google ainda não está ativo neste projeto';

  @override
  String get dataCloudNoConnection => 'Sem conexão';

  @override
  String get dataCloudNoSignIn => 'Sem login';

  @override
  String get dataCloudNoIdentityToken =>
      'O Google não forneceu um token de identidade';

  @override
  String get dataCloudSignInFailed => 'Falha ao entrar';

  @override
  String get dataCloudSignInInterrupted => 'Login interrompido';

  @override
  String get dataCloudGoogleNotConfigured =>
      'O Google não está configurado para este app';

  @override
  String get dataCloudGoogleSignInFailed => 'Falha ao entrar com o Google';

  @override
  String dataNewChaptersNotification(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Chegaram $count capítulos novos',
      one: 'Chegou um capítulo novo',
    );
    return '$_temp0';
  }

  @override
  String get dataArchivePhoneFolderMissing => 'Falta a pasta do celular.';

  @override
  String get dataArchiveDriveFolderMissing => 'Falta a pasta do Drive.';

  @override
  String dataChapterLabel(String number) {
    return 'Capítulo $number';
  }

  @override
  String get dataLibraryMissing => 'A pasta não existe ou não pode ser lida.';

  @override
  String get dataLibraryNotIndexed =>
      'A pasta não contém library.json: é preciso gerar os índices de novo com o arquivador que escreveu a biblioteca.';

  @override
  String get dataLibraryUnreadable =>
      'library.json não pode ser lido ou não é um índice MALF válido.';

  @override
  String get dataLibraryUnsupported =>
      'library.json usa uma versão do formato mais recente que a deste app.';

  @override
  String get dataReaderModeContinuous => 'Contínua';

  @override
  String get dataReaderModePaged => 'Paginada';

  @override
  String get dataReaderDirectionLtr => 'Esquerda → direita';

  @override
  String get dataReaderDirectionRtl => 'Direita → esquerda';

  @override
  String get dataReaderFitWidth => 'Largura';

  @override
  String get dataReaderFitHeight => 'Altura';

  @override
  String get dataReaderFitOriginal => 'Original';

  @override
  String get dataReaderBackgroundBlack => 'Preto';

  @override
  String get dataReaderBackgroundGrey => 'Cinza';

  @override
  String get dataReaderBackgroundWhite => 'Branco';

  @override
  String readerProbeFrames(String frames, String budget) {
    return 'Quadros $frames · limite $budget ms';
  }

  @override
  String readerProbeSlow(
    String build,
    String buildMax,
    String raster,
    String rasterMax,
  ) {
    return 'Lentos UI $build (máx $buildMax ms) · GPU $raster (máx $rasterMax ms)';
  }

  @override
  String readerProbeLate(String late, String lateMax) {
    return 'Atrasados $late (máx $lateMax ms)';
  }

  @override
  String readerProbeScroll(String scroll, String missed, String gap) {
    return 'Rolando $scroll · perdidos $missed (vão máx $gap ms)';
  }

  @override
  String readerProbeSources(
    String tiles,
    String whole,
    String phone,
    String phoneMade,
  ) {
    return 'Blocos $tiles · inteiras $whole · do celular $phone (feitos $phoneMade)';
  }

  @override
  String readerProbeNative(String bands, String textures, String decodes) {
    return 'Nativas $bands (textura $textures) · páginas decodificadas $decodes';
  }

  @override
  String readerProbeDecode(
    String decode,
    String decodeMax,
    String arrival,
    String arrivalMax,
  ) {
    return 'Decodificação $decode ms (máx $decodeMax) · chegada $arrival ms (máx $arrivalMax)';
  }

  @override
  String readerProbeMemory(
    String copy,
    String gc,
    String gcMs,
    String blocking,
    String blockingMs,
  ) {
    return 'Cópia máx $copy ms · GC Android $gc ($gcMs ms) · bloqueantes $blocking ($blockingMs ms)';
  }

  @override
  String readerProbeWaits(String drive, String fallbacks) {
    return 'Esperas do Drive $drive · alternativas Dart $fallbacks';
  }

  @override
  String readerProbeJumps(String corrections, String jumps, String jumped) {
    return 'Correções $corrections · saltos $jumps ($jumped px)';
  }
}
