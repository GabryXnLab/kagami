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
  String seriesWaitingChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Você leu tudo o que foi baixado: $count capítulos não lidos ainda não chegaram.',
      one: 'Você leu tudo o que foi baixado: um capítulo não lido ainda não chegou.',
    );
    return '$_temp0';
  }

  @override
  String seriesWaitingQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Você leu tudo o que foi baixado: $count capítulos para ler, os próximos estão na fila.',
      one: 'Você leu tudo o que foi baixado: o próximo capítulo está na fila.',
    );
    return '$_temp0';
  }

  @override
  String get seriesFetchNext => 'Baixar os próximos';

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
  String get seriesChapterUnlisted => 'Não está mais no site';

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
      'Busque um título nos sites compatíveis ou cole o link de uma série ou de um de seus capítulos: o Kagami a baixa do site para a biblioteca, com metadados, capa e a lista completa de capítulos. Ou salva só a ficha, sem capítulos.';

  @override
  String get archiveSearchHint => 'Buscar um mangá pelo título';

  @override
  String get archiveFilterOngoing => 'Em andamento';

  @override
  String get archiveFilterCompleted => 'Concluídas';

  @override
  String get archiveFilterNotInLibrary => 'Fora da biblioteca';

  @override
  String get archiveInLibrary => 'Na biblioteca';

  @override
  String archiveResultsFiltered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados, ocultos pelos filtros',
      one: '1 resultado, oculto pelos filtros',
    );
    return '$_temp0';
  }

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
  String get archiveChooseTitle => 'O que baixar';

  @override
  String get archiveModeAhead => 'Conforme lê';

  @override
  String get archiveModeAllLine => 'Cada capítulo, uma vez só';

  @override
  String archiveModeAheadLine(int count) {
    return '$count prontos, depois um por capítulo lido';
  }

  @override
  String get archiveModeFromLine => 'De um capítulo até o último';

  @override
  String get archiveModePickLine => 'Só os que você tocar';

  @override
  String archiveModeAheadHint(int count) {
    return 'Baixa $count a partir do capítulo escolhido. Cada capítulo lido traz um novo, para você ter sempre $count para ler, até o fim da série; quando o site publica mais, eles chegam do mesmo jeito.';
  }

  @override
  String get archiveModeAheadUnavailable =>
      'Não é possível com este site: ele pede a verificação do navegador a cada visita, e o telefone não consegue passar sozinho.';

  @override
  String get archiveModeAheadServer =>
      'O servidor vinculado ainda não sabe baixar conforme você lê: ele se atualiza sozinho em até uma hora após sair uma versão nova.';

  @override
  String get archiveChapterSearch => 'Buscar por número ou título';

  @override
  String get archiveNewestFirst => 'Mais recentes primeiro';

  @override
  String get archiveOldestFirst => 'Do primeiro';

  @override
  String get archiveChooseStart => 'Toque no capítulo de onde começar.';

  @override
  String get archiveSelectMissing => 'Os que faltam';

  @override
  String get archiveRangeHint =>
      'Toque e segure um capítulo para pegar também todos entre ele e o último tocado.';

  @override
  String get archivePickNone => 'Nenhum capítulo escolhido';

  @override
  String archiveSummaryChapters(int count, String where) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos',
      one: '1 capítulo',
    );
    return '$_temp0 · $where';
  }

  @override
  String archiveSummaryAhead(int count, String where) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos agora',
      one: '1 capítulo agora',
    );
    return '$_temp0, depois um por capítulo lido · $where';
  }

  @override
  String archiveDownloadAhead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Baixar $count capítulos e depois conforme lê',
      one: 'Baixar 1 capítulo e depois conforme lê',
    );
    return '$_temp0';
  }

  @override
  String archiveInLibraryCount(int archived, int total) {
    return 'Na biblioteca: $archived de $total';
  }

  @override
  String get archiveChapterInLibrary => 'na biblioteca';

  @override
  String get archiveChapterStart => 'começa aqui';

  @override
  String get archiveChapterLater => 'chega ao ler';

  @override
  String get archiveAdvanced => 'Avançado';

  @override
  String archiveAdvancedLine(String pause) {
    return 'Pausa entre pedidos: $pause';
  }

  @override
  String get archiveReopen => 'Escolher o que baixar';

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
  String get archiveResults => 'Resultados';

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
  String archiveLatestChapter(String number) {
    return 'último: cap. $number';
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
  String get archiveRecent => 'Baixadas recentemente';

  @override
  String archiveRecentAll(int count) {
    return 'Todas ($count)';
  }

  @override
  String get archiveRecentFailed => 'Falhou';

  @override
  String get archiveFollowedTitle => 'Séries seguidas';

  @override
  String archiveFollowedProblems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count a corrigir',
      one: '1 a corrigir',
    );
    return '$_temp0';
  }

  @override
  String archiveRecentLineRuns(String when, int runs, String message) {
    return '$when · $runs downloads · $message';
  }

  @override
  String get archiveRetry => 'Tentar de novo';

  @override
  String archiveJobAhead(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos',
      one: '1 capítulo',
    );
    return 'Conforme lê: $_temp0 · $destination';
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
      'Todos os dias todas as séries em andamento da biblioteca são verificadas de novo, baixadas daqui ou por outros, exceto as que você deixou de seguir: só chegam os capítulos novos. Baixar uma de novo pelo site faz com que volte a ser seguida.';

  @override
  String get archiveTrackedByServer =>
      'As séries seguidas são verificadas pelo servidor, como escolhido nas Configurações (“Quem baixa e verifica”). As que o celular seguia ficam paradas até você voltar para o celular.';

  @override
  String get archiveCheckDaily => 'Verificação diária';

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
  String get archiveRepair => 'Reparar as séries arquivadas';

  @override
  String get archiveRepairHint =>
      'Relê cada série a partir do site e corrige título, capa e capítulos';

  @override
  String get archiveRepairAll => 'Toda a biblioteca';

  @override
  String archiveRepairSite(String site) {
    return 'Só as séries de $site';
  }

  @override
  String get archiveRepairSeries => 'Reparar a série';

  @override
  String archiveRepairRunning(int done, int total, String title) {
    return 'Reparando $done de $total: $title';
  }

  @override
  String get archiveRepairQueued =>
      'Reparação iniciada no servidor: os resultados aparecem no histórico.';

  @override
  String archiveRepairFinished(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries reparadas.',
      one: '1 série reparada.',
      zero: 'Nenhuma série para reparar.',
    );
    return '$_temp0';
  }

  @override
  String get archiveRepairNoLibrary =>
      'Não há biblioteca para reparar: escolhe a pasta do Drive ou do telemóvel.';

  @override
  String get archiveRepairNoServer =>
      'O servidor ainda não sabe reparar séries: precisa de ser atualizado.';

  @override
  String archiveRepairFailed(String error) {
    return 'A reparação falhou: $error';
  }

  @override
  String get archiveRepairPagesDone => 'Série reparada.';

  @override
  String get archiveRepairPagesNone =>
      'O servidor não encontrou a série na biblioteca.';

  @override
  String get archiveRepairNoVerification =>
      'Verificação não concluída: a série não foi reparada.';

  @override
  String get archiveRepairBusy =>
      'O telemóvel já está a reparar ou a transferir: tenta novamente daqui a pouco.';

  @override
  String archiveRepairRecovered(String site) {
    return '$site voltou a funcionar: repara as suas séries';
  }

  @override
  String get archiveRepairRecoveredAction => 'Reparar';

  @override
  String get archiveRepairDismiss => 'Ignorar';

  @override
  String get archiveRepairNothing => 'Nada para reparar';

  @override
  String get archiveRepairAdopted => 'nova chave adotada';

  @override
  String get archiveRepairRetitled => 'título atualizado';

  @override
  String get archiveRepairCover => 'capa atualizada';

  @override
  String archiveRepairAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos novos',
      one: '1 capítulo novo',
    );
    return '$_temp0';
  }

  @override
  String archiveRepairUnlisted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos já não constam',
      one: '1 capítulo já não consta',
    );
    return '$_temp0';
  }

  @override
  String archiveRepairError(String error) {
    return 'Não reparada: $error';
  }

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
  String archiveTrackedAhead(int count, String destination) {
    return 'Conforme lê, $count prontos para ler · $destination';
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
  String get archiveStartNoMatch => 'Nenhum capítulo com este número.';

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
  String get serverRecent => 'Baixadas pelo servidor';

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
  String serverJobAhead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos',
      one: '1 capítulo',
    );
    return 'Conforme lê: $_temp0';
  }

  @override
  String serverSeriesAhead(int count) {
    return 'Conforme lê, $count prontos para ler: o app pede os capítulos enquanto você lê';
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
  String get serverDriveForeignTitle => 'Dar o teu Drive a este servidor?';

  @override
  String get serverDriveForeignBody =>
      'Este servidor não é teu: quem o gere poderá ler, escrever e apagar em todo o teu Drive, não só na pasta da biblioteca. Continua só se confiares nessa pessoa.';

  @override
  String get serverDriveForeignConfirm => 'Dar a permissão';

  @override
  String get serverDriveNeedsHttps =>
      'A permissão do Drive não é enviada a um servidor sem cifra (http://) num endereço público: podia ser lida pelo caminho. Usa um endereço https:// ou uma rede privada como o Tailscale.';

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
      'Cole estes comandos no terminal dele: o primeiro liga o servidor, o segundo o mantém atualizado sozinho. Eles contêm a permissão do seu Drive: não envie a ninguém.';

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
      'O que está no celular sobe para o Drive. Os índices da biblioteca continuam sendo os do servidor.';

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
  String get settingsTheme => 'Tema';

  @override
  String get settingsLibraryNote => 'Pasta, índices e Google Drive';

  @override
  String get settingsLibraryNoteLocal => 'Pasta e índices';

  @override
  String get settingsReadingNote => 'Modo padrão e medições do leitor';

  @override
  String get settingsAccountNote => 'Login com Google e sincronização';

  @override
  String get settingsDataNote => 'Backups, restauração e exclusão';

  @override
  String get settingsAutoBackup => 'Cópia automática no celular';

  @override
  String get settingsAutoBackupNote =>
      'Uma vez por dia no espaço do app, neste celular. Para tê-las em outro lugar, use a conta ou «Exportar»';

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
      'Esta versão não tem backend: os dados ficam onde estão, no dispositivo';

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
      'Envia a última leitura e encerra a sessão: o celular volta aos dados do uso sem conta';

  @override
  String get settingsAccountSessionLostNote =>
      'A sessão expirou: entre de novo para sincronizar, ou saia para voltar aos dados do uso sem conta';

  @override
  String get settingsAccountForget => 'Parar de guardar uma cópia';

  @override
  String get settingsAccountForgetNote =>
      'Apaga os dados da conta e você volta ao uso sem conta. Os da conta permanecem no arquivo próprio neste celular, ocultos até você entrar de novo';

  @override
  String get settingsAccountErrorNote =>
      'Os dados deste celular não foram tocados';

  @override
  String get settingsAccountForgetSheetTitle => 'Apagar os dados da conta?';

  @override
  String get settingsAccountForgetExplain =>
      'Some a cópia guardada para você, e a sessão é encerrada. O celular volta aos dados do uso sem conta; status, notas, histórico e coleções da conta permanecem em um arquivo próprio neste celular, mas não aparecem até você entrar de novo com a mesma conta (e não serão mais vistos em outro celular).';

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
  String get settingsBackupsTitle => 'Cópias no celular';

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
  String get homeUpdatesSubtitle => 'Capítulos novos depois do último lido';

  @override
  String homeLatestChapter(String number) {
    return 'cap. $number';
  }

  @override
  String homeSiteChapters(int count, String site) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count novos em $site',
      one: '1 novo em $site',
    );
    return '$_temp0';
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
  String get moreDownload => 'Baixar um mangá';

  @override
  String get moreDownloadSubtitle => 'Busque um título ou cole um link';

  @override
  String get settingsEngine => 'Quem baixa e verifica';

  @override
  String get settingsEngineServer => 'O servidor';

  @override
  String get settingsEnginePhone => 'O celular';

  @override
  String get settingsEngineServerNote =>
      'Séries novas, conforme você lê e verificação das séries seguidas: tudo no servidor, que também acompanha as séries que o celular baixou no Drive';

  @override
  String get settingsEnginePhoneNote =>
      'Séries novas, conforme você lê e verificação das séries seguidas: tudo no celular. O servidor continua vinculado, mas não verifica nada';

  @override
  String get settingsEngineNoServer =>
      'Tudo no celular. Para deixar com um servidor, vincule um em “Baixar um mangá”';

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
  String removeSeriesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Excluir $count séries?',
      one: 'Excluir a série?',
    );
    return '$_temp0';
  }

  @override
  String removeSeriesBody(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Elas saem da biblioteca: os capítulos no telefone são apagados e não chegam novos. O progresso de leitura continua.',
      one:
          '«$title» sai da biblioteca: os capítulos no telefone são apagados e não chegam novos. O progresso de leitura continua.',
    );
    return '$_temp0';
  }

  @override
  String get removeSeriesDrive =>
      'No Drive a pasta vai para a lixeira: dá para recuperá-la de lá por trinta dias.';

  @override
  String get removeSeriesDriveNotOwned =>
      'No Drive a série fica: a pasta da biblioteca não é da sua conta, ou o Drive ainda não confirmou, e o Kagami só apaga onde você é dono.';

  @override
  String get removeSeriesConfirm => 'Excluir';

  @override
  String removeSeriesDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries excluídas.',
      one: 'Série excluída.',
    );
    return '$_temp0';
  }

  @override
  String removeSeriesFailed(String error) {
    return 'Não foi possível excluir tudo: $error';
  }

  @override
  String get removeSeriesAction => 'Excluir da biblioteca';

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
  String get dataCloudBackendUnavailable =>
      'Função indisponível no backend desta versão';

  @override
  String get dataCloudTooLarge =>
      'Seus dados pessoais passam dos 16 MiB que o backend aceita: ficam neste celular, mas não são sincronizados';

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
  String dataNewSiteChaptersNotification(int count, String site) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saíram $count capítulos novos em $site',
      one: 'Saiu um capítulo novo em $site',
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

  @override
  String get serverCheckDaily => 'Verificação diária de capítulos novos';

  @override
  String serverCheckDailyAt(String clock) {
    return 'Todos os dias às $clock, hora do servidor';
  }

  @override
  String get serverCheckDailyOff =>
      'Desligado: os capítulos novos só são baixados à mão';

  @override
  String get serverCheckByPhone =>
      'Desligado: as séries seguidas são verificadas pelo celular, como escolhido nas Configurações';

  @override
  String serverCheckLast(String when, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries com capítulos novos',
      one: '1 série com capítulos novos',
      zero: 'nenhum capítulo novo',
    );
    return 'Última verificação $when: $_temp0';
  }

  @override
  String get serverCheckTimeHelp => 'Hora da verificação';

  @override
  String get seriesRatingInviteTitle => 'Que nota você dá?';

  @override
  String get seriesRatingInviteBody =>
      'A nota serve para filtrar e ordenar a biblioteca e conta nas estatísticas.';

  @override
  String get seriesRatingInviteRate => 'Avaliar';

  @override
  String get seriesRatingInviteIgnore => 'Ignorar';

  @override
  String get seriesRatingInviteNever => 'Não perguntar mais';

  @override
  String get settingsRatingInvite => 'Pedir uma nota ao abrir uma série';

  @override
  String get settingsRatingInviteNote =>
      'Séries sem nota mostram um convite para avaliar';

  @override
  String get archiveModeCard => 'Só a ficha';

  @override
  String get archiveModeCardLine =>
      'Nenhum capítulo: status, nota e onde você parou';

  @override
  String get archiveModeCardHint =>
      'Salva a série na biblioteca sem baixar capítulos: capa, metadados, a lista de capítulos e o link para o site. Indique até onde você chegou: esse capítulo e os anteriores ficam como lidos. Os capítulos podem ser baixados depois.';

  @override
  String get archiveReachedSection => 'Cheguei até o…';

  @override
  String get archiveReachedHint => 'Toque no último capítulo que você leu.';

  @override
  String get archiveReachedNone => 'Não comecei';

  @override
  String get archiveChapterReached => 'parei aqui';

  @override
  String get archiveCardServer =>
      'As fichas são salvas pelo celular: o servidor conectado só baixa capítulos.';

  @override
  String get archiveCardNotesHint => 'Uma nota para você (opcional)';

  @override
  String archiveSummaryCard(String where) {
    return 'Salva a ficha, nenhum capítulo baixado · $where';
  }

  @override
  String archiveSummaryCardReached(String number, String where) {
    return 'Salva a ficha lida até o $number, nenhum capítulo baixado · $where';
  }

  @override
  String get archiveSaveCard => 'Salvar ficha';

  @override
  String archiveCardQueuedSnack(String title) {
    return 'Ficha de “$title” salva: a capa e a lista de capítulos chegam em instantes.';
  }

  @override
  String archiveCardProgress(String message) {
    return 'Ficha · $message';
  }

  @override
  String archiveJobCard(String destination) {
    return 'Ficha · $destination';
  }

  @override
  String archiveJobCardUpdate(String destination) {
    return 'Atualização da ficha · $destination';
  }

  @override
  String archiveRecentCard(String when) {
    return 'Ficha · $when';
  }

  @override
  String archiveCheckCards(String names) {
    return 'capítulos novos na lista, não baixados, para as fichas de $names';
  }

  @override
  String get seriesOpenSite => 'Abrir no site';

  @override
  String get seriesRefreshCard => 'Atualizar ficha';

  @override
  String get seriesDownloadMore => 'Baixar mais capítulos';

  @override
  String get seriesStartDownload => 'Começar a baixar';

  @override
  String get seriesStartDownloadMessage =>
      'Esta série é só uma ficha: os capítulos estão no site. Baixe-os para lê-los aqui, a partir do seguinte ao último lido.';

  @override
  String get seriesDownloadFromSite => 'Baixar do site';

  @override
  String get seriesDownloadFromSiteQueued => 'Na fila do site';

  @override
  String get coverCardBadge => 'Ficha';

  @override
  String coverReached(String number) {
    return 'Chegou ao cap. $number';
  }

  @override
  String get libraryOnlyCards => 'Só fichas';

  @override
  String get seriesReachedTitle => 'Chegou a';

  @override
  String get seriesReachedNone => 'Não iniciado';

  @override
  String seriesReachedChapter(String number) {
    return 'Cap. $number';
  }

  @override
  String get seriesReachedSearch => 'Procurar um capítulo';

  @override
  String get seriesReachedNumberHint => 'Número do capítulo';

  @override
  String get seriesReachedNumberHelp =>
      'Como o site escreve, por exemplo 52. Vazio para remover.';

  @override
  String get seriesReachedBackTitle => 'Voltar atrás?';

  @override
  String seriesReachedBackMessage(String chapter) {
    return 'Os capítulos depois de «$chapter» continuam marcados como lidos: para voltarem a ficar por ler, desmarque-os na lista de capítulos.';
  }

  @override
  String get seriesReachedBackConfirm => 'Mover';

  @override
  String get seriesCardEmptyTitle => 'Ficha sem capítulos';

  @override
  String get seriesCardEmptyMessage =>
      'O Kagami não baixa deste site, mas a ficha guarda estado, nota, comentário e ponto de leitura.';

  @override
  String get seriesLinkSite => 'Vincular a um site';

  @override
  String get seriesLinkTitle => 'Vincular a um site';

  @override
  String get seriesLinkMessage =>
      'Cole o link da série num site de que o Kagami sabe baixar. Estado, nota, coleções e ponto de leitura passam para a série real, e esta ficha é removida.';

  @override
  String get seriesLinkHint => 'Link da série';

  @override
  String get seriesLinkContinue => 'Continuar';

  @override
  String seriesLinkDone(String title) {
    return '«$title» vinculada: a série aparecerá na biblioteca quando o trabalho terminar.';
  }

  @override
  String get seriesSwitchProvider => 'Mudar de provedor';

  @override
  String get seriesSwitchMessage =>
      'Escolha o provedor de onde baixar a série de novo. Capítulos, páginas e metadados são baixados de novo de lá e a cópia atual é removida, no Drive para a lixeira. Status, nota, comentário, coleções, capítulos lidos e ponto de leitura passam para a nova série, capítulo por capítulo.';

  @override
  String get seriesSwitchOther => 'Toque para escolher outro';

  @override
  String seriesSwitchSearching(String title, String site) {
    return 'Procurando \"$title\" em $site…';
  }

  @override
  String seriesSwitchNotFound(String title, String site) {
    return '\"$title\" não foi encontrada em $site. Talvez lá tenha outro título: procure abaixo e escolha a certa.';
  }

  @override
  String seriesSwitchSearchHint(String site) {
    return 'Pesquisar em $site';
  }

  @override
  String seriesSwitchDone(String title, String site) {
    return '\"$title\" agora vem de $site: aparecerá na biblioteca quando o trabalho terminar.';
  }

  @override
  String seriesSwitchMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count capítulos lidos não estão no novo site e ficam só no histórico.',
      one: 'Um capítulo lido não está no novo site e fica só no histórico.',
    );
    return '$_temp0';
  }

  @override
  String get archiveManualAction => 'Adicionar sem link';

  @override
  String get archiveManualUnsupported =>
      'O Kagami não sabe baixar deste site: você pode salvá-lo como ficha com título e link, mas os capítulos não poderão ser baixados.';

  @override
  String get archiveManualUnsupportedAction => 'Salvar como ficha';

  @override
  String get archiveManualTitle => 'Ficha manual';

  @override
  String get archiveManualTitleHint => 'Título';

  @override
  String get archiveManualTitleRequired => 'Escreva um título.';

  @override
  String get archiveManualLinkHint => 'Link da página da série (opcional)';

  @override
  String get archiveManualSupported =>
      'O Kagami sabe ler este site: pelo caminho normal você tem a lista de capítulos e pode baixá-los.';

  @override
  String get archiveManualSupportedAction => 'Usar o caminho normal';

  @override
  String get archiveManualNoDownload =>
      'Os capítulos deste site não poderão ser baixados: fica só o link, mais o título e a capa se a página os declarar.';

  @override
  String get archiveManualReachedHint => 'Cheguei ao capítulo (ex.: 52)';

  @override
  String get archiveManualWhereDrive =>
      'A ficha é salva no Drive, na pasta da biblioteca.';

  @override
  String get archiveManualWherePhone => 'A ficha é salva no telefone.';

  @override
  String get archiveManualSave => 'Salvar a ficha';

  @override
  String archiveManualSaved(String title) {
    return 'Ficha de «$title» salva.';
  }

  @override
  String archiveManualExists(String title) {
    return 'Este link já está na biblioteca: «$title».';
  }

  @override
  String get archiveManualNeedsDrive =>
      'Salvar a ficha no Drive exige permissão de escrita.';

  @override
  String archiveManualFailed(String error) {
    return 'Não foi possível salvar a ficha: $error';
  }

  @override
  String get archiveImportAction => 'Importar vários links';

  @override
  String get archiveImportTitle => 'Importar vários links';

  @override
  String get archiveImportIntro =>
      'Cole links: as abas do navegador, uma lista, um JSON. Cada mangá vira uma ficha na biblioteca, sem baixar capítulos; a partir do link de um capítulo, lido até esse capítulo.';

  @override
  String get archiveImportHint => 'Cole aqui o texto com os links…';

  @override
  String archiveImportFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links encontrados',
      one: 'Um link encontrado',
      zero: 'Nenhum link encontrado',
    );
    return '$_temp0';
  }

  @override
  String get archiveImportWhereDrive =>
      'As fichas são salvas no Drive, na pasta da biblioteca.';

  @override
  String get archiveImportWherePhone => 'As fichas são salvas no telefone.';

  @override
  String get archiveImportCollection => 'Adicionar a uma coleção';

  @override
  String get archiveImportCollectionNone => 'Nenhuma coleção';

  @override
  String get archiveImportPause => 'Pausa entre links';

  @override
  String get archiveImportPauseHint =>
      'As séries são lidas do site uma de cada vez: uma pausa maior pesa menos nos sites.';

  @override
  String archiveImportSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String archiveImportStart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importar $count links',
      one: 'Importar um link',
    );
    return '$_temp0';
  }

  @override
  String get archiveImportStop => 'Parar';

  @override
  String get archiveImportResume => 'Continuar';

  @override
  String get archiveImportWaiting => 'Aguardando';

  @override
  String get archiveImportRunning => 'Em andamento…';

  @override
  String get archiveImportSaved => 'Salva como ficha';

  @override
  String archiveImportSavedReached(String chapter) {
    return 'Salva como ficha · lido até o $chapter';
  }

  @override
  String get archiveImportManual =>
      'Ficha manual: o Kagami não poderá baixar os capítulos';

  @override
  String archiveImportKnown(String title) {
    return 'Já na biblioteca: “$title”';
  }

  @override
  String get archiveImportQueued => 'Já na fila';

  @override
  String get archiveImportNeedsCheck => 'O site pede uma verificação';

  @override
  String get archiveImportVerify => 'Verificar';

  @override
  String get archiveImportRetry => 'Tentar de novo';

  @override
  String get archiveImportCheckHint =>
      'Alguns sites pedem uma verificação do navegador: toque em um e passe por ela; os outros links do mesmo site recomeçam sozinhos.';

  @override
  String archiveImportProgress(int done, int total) {
    return '$done de $total';
  }

  @override
  String archiveImportCountSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichas',
      one: '1 ficha',
    );
    return '$_temp0';
  }

  @override
  String archiveImportCountManual(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count manuais',
      one: '1 manual',
    );
    return '$_temp0';
  }

  @override
  String archiveImportCountKnown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count já presentes',
      one: '1 já presente',
    );
    return '$_temp0';
  }

  @override
  String archiveImportCountFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count erros',
      one: '1 erro',
    );
    return '$_temp0';
  }

  @override
  String archiveImportCountCheck(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count a verificar',
      one: '1 a verificar',
    );
    return '$_temp0';
  }

  @override
  String get archiveImportLeaveTitle => 'Parar a importação?';

  @override
  String get archiveImportLeaveBody =>
      'As fichas já salvas ficam; os links restantes não serão importados.';

  @override
  String get archiveImportLeaveConfirm => 'Parar e sair';

  @override
  String get shareNoLinks => 'O texto compartilhado não contém links.';

  @override
  String dataVerifyTitle(String sites) {
    return '$sites pede a verificação';
  }

  @override
  String dataVerifyText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'A verificação automática não conseguiu ler $count séries. Toque para passar a verificação.',
      one: 'A verificação automática não conseguiu ler uma série. Toque para passar a verificação.',
    );
    return '$_temp0';
  }

  @override
  String archiveGatedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries aguardam a verificação',
      one: 'Uma série aguarda a verificação',
    );
    return '$_temp0';
  }

  @override
  String archiveGatedBody(String sites) {
    return '$sites pede para marcar «Verify you are human», e a verificação automática não faz isso. Passe você: a verificação continua a partir destas séries.';
  }

  @override
  String get archiveGatedAction => 'Verificar';

  @override
  String get archiveGatedNothing =>
      'A verificação não foi concluída: as séries continuam aguardando.';

  @override
  String get archiveGatedChecking =>
      'Verificação concluída, verificando as séries…';

  @override
  String archiveCheckQueuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'capítulos novos de $count séries',
      one: 'capítulos novos de uma série',
    );
    return '$_temp0';
  }

  @override
  String get settingsAutoCleanup => 'Limpeza automática';

  @override
  String get settingsAutoCleanupRead => 'Remover capítulos lidos';

  @override
  String get settingsAutoCleanupReadNote =>
      'Do telefone e do Drive, para a lixeira, automaticamente. O progresso e os capítulos lidos são mantidos';

  @override
  String get settingsAutoCleanupSharedRead =>
      'Um capítulo lido de um compartilhamento conta como lido: a cópia no seu Drive também sai.';

  @override
  String get settingsAutoCleanupIdle => 'Remover capítulos de séries paradas';

  @override
  String settingsAutoCleanupIdleNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '1 dia',
    );
    return 'Também os não lidos, quando uma série não é lida há $_temp0';
  }

  @override
  String get settingsAutoCleanupPause => 'Pausar séries paradas';

  @override
  String settingsAutoCleanupPauseNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '1 dia',
    );
    return 'Séries «lendo» passam para «em pausa» quando não são lidas há $_temp0';
  }

  @override
  String get settingsAutoCleanupIdleAfter => 'Sem leituras há';

  @override
  String settingsAutoCleanupDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '1 dia',
    );
    return '$_temp0';
  }

  @override
  String get settingsAutoCleanupPhoneOnly =>
      'Sem permissão para escrever no Drive, os capítulos são removidos só do telefone';

  @override
  String homeUpdatesMore(int count) {
    return 'Mais ($count)';
  }

  @override
  String get homeUpdatesLess => 'Mostrar menos';

  @override
  String get settingsHomeUpdates => 'Atualizações no Início';

  @override
  String get settingsHomeUpdatesShown => 'Séries mostradas';

  @override
  String get settingsHomeUpdatesShownNote =>
      'As outras aparecem ao tocar em «Mais»';

  @override
  String settingsHomeUpdatesSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries',
      one: '1 série',
    );
    return '$_temp0';
  }

  @override
  String get settingsHomeUpdatesMaxPending => 'Máximo de capítulos novos';

  @override
  String get settingsHomeUpdatesMaxPendingNote =>
      'Uma série com mais capítulos para ler depois do último lido não é uma atualização';

  @override
  String settingsHomeUpdatesChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos',
      one: '1 capítulo',
    );
    return '$_temp0';
  }

  @override
  String get collectionPropsTitle => 'Propriedades da coleção';

  @override
  String get collectionPropsEntry => 'Propriedades';

  @override
  String get collectionsHasProps => 'Tem propriedades ativas';

  @override
  String get collectionPropsAutoTitle => 'Adição automática';

  @override
  String get collectionPropsAutoNote =>
      'As séries que cumprem todas as regras entram sozinhas. Se você remover uma à mão, ela não volta.';

  @override
  String get collectionPropsTypes => 'Tipo';

  @override
  String get collectionPropsTags => 'Gêneros e tags (todos obrigatórios)';

  @override
  String get collectionPropsTagSearch => 'Buscar tag';

  @override
  String get collectionPropsShelf => 'Estado de leitura';

  @override
  String get collectionPropsRelease => 'Publicação';

  @override
  String get collectionPropsProviders => 'Site';

  @override
  String get collectionPropsMinRating => 'Nota mínima';

  @override
  String get collectionPropsFavorite => 'Só favoritas';

  @override
  String get collectionPropsTraitsTitle => 'Para todas as séries da coleção';

  @override
  String get collectionPropsMuted => 'Silenciar novidades';

  @override
  String get collectionTraitHidden => 'Ocultar';

  @override
  String get collectionTraitHiddenHint =>
      'Sem notificações; as séries só aparecem ao abrir a coleção';

  @override
  String get collectionPropsKeepChapters => 'Excluir da limpeza automática';

  @override
  String get collectionPropsNoAutoPause => 'Excluir da pausa automática';

  @override
  String get collectionPropsNoRatingInvite => 'Não pedir a nota';

  @override
  String get collectionPropsApply => 'Aplicar';

  @override
  String get settingsReadAhead => 'Baixar conforme lê';

  @override
  String get settingsReadAheadWindow => 'Capítulos prontos';

  @override
  String get settingsReadAheadWindowNote =>
      'Quantos capítulos baixados ficam à frente do que você está lendo, em todas as séries baixadas conforme lê';

  @override
  String archiveSiteBroken(String site) {
    return 'O site $site não funciona: mudou e o Kagami precisa ser atualizado.';
  }

  @override
  String get elsewhereTitle => 'Em outros sites';

  @override
  String get elsewhereChecking => 'Procurando a série em outros sites…';

  @override
  String elsewhereChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos',
      one: '1 capítulo',
    );
    return '$_temp0';
  }

  @override
  String elsewhereLatest(String chapter) {
    return 'Último: capítulo $chapter';
  }

  @override
  String elsewhereLatestAt(String chapter, String date) {
    return 'Último: capítulo $chapter, $date';
  }

  @override
  String elsewhereAhead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos à frente',
      one: '1 capítulo à frente',
    );
    return '$_temp0';
  }

  @override
  String elsewhereBehind(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos atrás',
      one: '1 capítulo atrás',
    );
    return '$_temp0';
  }

  @override
  String get elsewhereSame => 'Mesmo capítulo';

  @override
  String get elsewhereMissing => 'Não está aqui';

  @override
  String get elsewhereBroken => 'Site fora do ar';

  @override
  String get elsewhereGated => 'Pede a verificação do navegador';

  @override
  String get elsewhereError => 'Não respondeu';

  @override
  String get elsewhereSwitch => 'Mudar para este site';

  @override
  String get elsewhereSiteAction => 'Onde ler em outro lugar';

  @override
  String elsewhereSiteTitle(String site) {
    return 'Séries de $site';
  }

  @override
  String get elsewhereSiteEmpty =>
      'Nenhuma série da biblioteca vem deste site.';

  @override
  String get elsewhereSiteUnknown => 'Ainda não procurada em outros sites';

  @override
  String get elsewhereSiteNowhere => 'Não encontrada em outros sites';

  @override
  String get elsewhereSiteOffline =>
      'Mostra-se o que já tinha sido encontrado. Com um Kagami Server ligado, todas as séries são procuradas.';

  @override
  String get sitesTitle => 'Sites';

  @override
  String get sitesEntrySubtitle => 'Os incluídos e os que você adiciona';

  @override
  String get sitesBuiltInSection => 'Incluídos no app';

  @override
  String get sitesAddedSection => 'Adicionados';

  @override
  String get sitesNoneAdded => 'Nenhum site adicionado.';

  @override
  String get sitesNoLibrary =>
      'É preciso uma pasta do Drive ou do telefone como biblioteca: os sites são salvos lá.';

  @override
  String sitesVersion(int version) {
    return 'versão $version';
  }

  @override
  String sitesReplaces(String name) {
    return 'Substitui $name';
  }

  @override
  String get sitesBroken => 'Arquivo danificado';

  @override
  String get sitesUpdateNow => 'Atualizar agora';

  @override
  String get sitesUpdated => 'Site atualizado.';

  @override
  String get sitesUpToDate => 'Nada novo: o site já está atualizado.';

  @override
  String get sitesRemove => 'Remover';

  @override
  String sitesRemoveTitle(String name) {
    return 'Remover $name?';
  }

  @override
  String get sitesRemoveBody =>
      'As séries deste site continuam na biblioteca, mas não são atualizadas até o site voltar.';

  @override
  String get sitesAdd => 'Adicionar um site';

  @override
  String get sitesAddHint => 'Link do arquivo ou texto colado';

  @override
  String get sitesAddCheck => 'Verificar';

  @override
  String get sitesInvalid => 'O arquivo não é válido';

  @override
  String get sitesFetchFailed => 'Não foi possível baixar o arquivo';

  @override
  String get sitesPreviewHosts => 'Pedirá as páginas a';

  @override
  String get sitesTryTitle => 'Teste antes de instalar (opcional)';

  @override
  String get sitesTryHint => 'Uma busca ou o link de uma série';

  @override
  String get sitesTry => 'Testar';

  @override
  String sitesTrySeries(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos',
      one: 'um capítulo',
    );
    return '$title: $_temp0';
  }

  @override
  String sitesTryResults(int count, String first) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados, o primeiro: $first',
      one: 'Um resultado: $first',
      zero: 'Nenhum resultado',
    );
    return '$_temp0';
  }

  @override
  String get sitesTryFailed => 'O teste falhou';

  @override
  String sitesFault(String phase, String field) {
    return 'Fase: $phase · campo: $field';
  }

  @override
  String sitesFaultPhase(String phase) {
    return 'Fase: $phase';
  }

  @override
  String get sitesInstall => 'Instalar';

  @override
  String sitesInstalled(String name) {
    return '$name instalado.';
  }

  @override
  String get seriesKindManga => 'Mangá';

  @override
  String get seriesKindManhwa => 'Manhwa';

  @override
  String get seriesKindManhua => 'Manhua';

  @override
  String get seriesKindOther => 'Outros';

  @override
  String get collectionPropsBinding => 'Vinculante';

  @override
  String get collectionPropsBindingNote =>
      'Só as séries que cumprem os critérios podem estar na coleção, mesmo adicionadas à mão.';

  @override
  String collectionBindingWillRemove(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries que não cumprem os critérios sairão da coleção',
      one: 'Uma série que não cumpre os critérios sairá da coleção',
    );
    return '$_temp0';
  }

  @override
  String collectionBindingRefused(String title, String collection) {
    return '«$title» não cumpre os critérios de «$collection»';
  }

  @override
  String collectionBindingRefusedMany(int count, String collection) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séries não cumprem',
      one: 'Uma série não cumpre',
    );
    return '$_temp0 os critérios de «$collection»';
  }

  @override
  String get collectionBindingLockTip => 'Coleção vinculante';

  @override
  String get accessDurationWeek => 'Uma semana';

  @override
  String get accessDurationMonth => 'Um mês';

  @override
  String get accessDurationQuarter => 'Três meses';

  @override
  String get accessDurationYear => 'Um ano';

  @override
  String get accessDurationNever => 'Sem validade';

  @override
  String serverUserExpires(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Expira em $dateString';
  }

  @override
  String get serverUserExpired => 'Expirado';

  @override
  String get serverUserRenew => 'Renovar';

  @override
  String serverUserRenewTitle(String email) {
    return 'Renovar o acesso de $email';
  }

  @override
  String serverMyAccessExpires(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'O seu acesso expira em $dateString';
  }

  @override
  String get serverAccessExpired =>
      'Acesso expirado: peça a quem tem o servidor que o renove';

  @override
  String dataServerExpiryTitle(String serverName) {
    return 'O seu acesso a «$serverName» está prestes a expirar';
  }

  @override
  String dataServerExpiryText(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Expira em $dateString: peça a quem tem o servidor que o renove.';
  }

  @override
  String get driveShareTitle => 'Quem pode ler a minha biblioteca';

  @override
  String get driveShareEntryNote => 'Quem vê a pasta no Drive e até quando';

  @override
  String driveShareIntro(String folder) {
    return 'Adicione a conta Google de quem quiser: poderá ler a pasta «$folder» no Drive, só leitura, pelo tempo que escolher.';
  }

  @override
  String get driveShareConsentTitle => 'É preciso mais uma permissão no Drive';

  @override
  String driveShareConsentBody(String folder) {
    return 'Quem você adicionar verá todos os arquivos da pasta «$folder», não só a biblioteca. Para gerenciar os compartilhamentos, o Google pede mais uma permissão. As cópias dos seus dados de leitura que estão na pasta vão para a lixeira do Drive.';
  }

  @override
  String get driveShareConsentContinue => 'Continuar';

  @override
  String get driveShareAdd => 'Compartilhar';

  @override
  String driveShareInFolder(String name) {
    return 'Pasta «$name»';
  }

  @override
  String get driveShareFromDrive => 'Compartilhado pelo Drive';

  @override
  String get driveShareRemoveBody => 'Não poderá mais ler a pasta.';

  @override
  String get driveShareLinkAccess =>
      'A pasta também pode ser lida por quem tem o link ou por um domínio: gerencia-se pelo Drive.';

  @override
  String get driveShareDriveSilent =>
      'O Drive não respondeu: a lista pode estar incompleta.';

  @override
  String get driveSharePersonalFound =>
      'A pasta tem cópias dos seus dados de leitura (reading/backup, state.json, collections.json): quem a lê pode vê-las.';

  @override
  String get driveSharePersonalRemove => 'Remover';

  @override
  String get driveSharePersonalUnchecked =>
      'Não foi possível verificar se ainda há cópias dos seus dados de leitura na pasta.';

  @override
  String get driveShareUnavailable =>
      'Este backend não tem o compartilhamento da biblioteca.';

  @override
  String driveShareLoadFailed(String message) {
    return 'Não consigo ler quem tem acesso: $message';
  }

  @override
  String get driveShareNobody => 'Ninguém, por enquanto.';

  @override
  String driveShareAdded(String email) {
    return '$email pode ler a biblioteca.';
  }

  @override
  String get driveShareOffline => 'Sem conexão: nada mudou.';

  @override
  String driveShareFailed(String message) {
    return 'Não deu certo: $message';
  }

  @override
  String get driveShareSelf => 'É o seu próprio endereço.';

  @override
  String get driveReceivedTitle => 'Bibliotecas compartilhadas comigo';

  @override
  String get driveReceivedEntryNote =>
      'Convites e acessos a bibliotecas de outras pessoas';

  @override
  String driveReceivedInvite(String owner, String folder) {
    return '$owner deu a você acesso somente leitura à biblioteca “$folder”.';
  }

  @override
  String get driveReceivedAccept => 'Aceitar';

  @override
  String get driveReceivedDecline => 'Recusar';

  @override
  String get driveReceivedRemove => 'Remover';

  @override
  String driveReceivedUntil(String owner, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$owner · até $dateString';
  }

  @override
  String driveReceivedNoLimit(String owner) {
    return '$owner · sem validade';
  }

  @override
  String driveReceivedExpiredRow(String owner) {
    return '$owner · acesso expirado';
  }

  @override
  String get driveReceivedEmpty =>
      'Nenhuma biblioteca compartilhada com você, por enquanto.';

  @override
  String driveReceivedNotificationTitle(String owner) {
    return '$owner compartilhou uma biblioteca com você';
  }

  @override
  String driveReceivedNotificationText(String folder) {
    return 'Abra o Kagami para aceitar “$folder”.';
  }

  @override
  String driveNoticeSharedExpired(String name) {
    return 'O acesso à biblioteca de $name expirou.';
  }

  @override
  String driveNoticeSharedUnavailable(String name) {
    return 'A biblioteca de $name não responde: talvez não esteja mais compartilhada com você.';
  }

  @override
  String get driveNoticeSourcesUnreadable =>
      'Não foi possível ler as bibliotecas compartilhadas.';

  @override
  String get driveReceivedManage => 'Gerenciar';

  @override
  String get sourcesTitle => 'Fontes';

  @override
  String get sourcesEntryNote => 'Ordem de leitura e bibliotecas extras';

  @override
  String get sourcesHelp =>
      'As séries de todas as fontes formam uma só biblioteca. Se uma série estiver em várias, vence a primeira.';

  @override
  String get sourcesBuiltInFolder => 'Pasta do telefone';

  @override
  String get sourcesBuiltInApp => 'Espaço do app';

  @override
  String get sourcesBuiltInDrive => 'Google Drive';

  @override
  String get sourcesKindWebdav => 'WebDAV / NAS';

  @override
  String get sourcesKindSmb => 'SMB';

  @override
  String get sourcesComingSoon => 'Em breve';

  @override
  String get sourcesStateReady => 'Pronta';

  @override
  String get sourcesStateOffline => 'Sem conexão';

  @override
  String get sourcesStateNeedsAuth => 'Reconectar';

  @override
  String sourcesStateExpired(String date) {
    return 'Expirou em $date';
  }

  @override
  String get sourcesStateMissing => 'Pasta sumiu';

  @override
  String get sourcesStateOtherAccount => 'De outra conta';

  @override
  String get sourcesReadOnlyBadge => 'Somente leitura';

  @override
  String sourcesOwner(String owner) {
    return 'Compartilhada por $owner';
  }

  @override
  String get sourcesAdd => 'Adicionar fonte';

  @override
  String get sourcesWebdavFolderHint => 'Pasta da biblioteca (ex.: /manga)';

  @override
  String get sourcesWebdavUserHint => 'Usuário';

  @override
  String get sourcesWebdavPasswordHint => 'Senha';

  @override
  String get sourcesWebdavNameHint => 'Nome (opcional, ex.: NAS de casa)';

  @override
  String get sourcesSmbHostHint => 'Endereço do computador (ex.: 192.168.1.10)';

  @override
  String get sourcesSmbShareHint => 'Compartilhamento (ex.: manga)';

  @override
  String get sourcesSmbUserHint => 'Usuário (vazio = convidado)';

  @override
  String get sourcesSmbDomainHint => 'Domínio (opcional)';

  @override
  String get sourcesSmbSealLabel => 'Criptografia (SMB 3)';

  @override
  String get sourcesSmbSealNote =>
      'Fora da rede de casa a criptografia é obrigatória: o computador precisa falar SMB 3.';

  @override
  String get sourcesSmbPlainWarning =>
      'Sem criptografia, a senha e os arquivos trafegam às claras: só serve na rede de casa.';

  @override
  String get sourcesHttpPrivateWarning =>
      'Endereço HTTP sem criptografia na rede privada: usuário e senha trafegam em texto aberto. Use só no Wi-Fi de casa.';

  @override
  String get sourcesHttpPublicWarning =>
      'Endereço HTTP público inseguro: a senha trafegaria em texto aberto pela Internet. Fora da rede local use https://.';

  @override
  String get sourcesProbeButton => 'Testar conexão';

  @override
  String get sourcesProbing => 'Testando…';

  @override
  String sourcesProbeSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Conexão bem-sucedida: $count séries encontradas.',
      one: 'Conexão bem-sucedida: 1 série encontrada.',
    );
    return '$_temp0';
  }

  @override
  String get sourcesProbeAuthFailed =>
      'Credenciais recusadas: confira usuário e senha.';

  @override
  String get sourcesProbeUnreachable =>
      'Inacessível: confira o endereço e a conexão.';

  @override
  String get sourcesProbeNoLibrary =>
      'Nenhuma biblioteca aqui: falta o library.json na pasta.';

  @override
  String get sourcesSave => 'Salvar';

  @override
  String get sourcesPasswordRewriteHint =>
      'Reescreva a senha (vazio: continua igual)';

  @override
  String get sourcesSecretNote =>
      'A senha fica só neste telefone: não vai para o backup nem para a conta.';

  @override
  String get sourcesRemove => 'Remover fonte';

  @override
  String get sourcesRemoveSubtitle =>
      'Remove configuração, senha e cache; o progresso de leitura fica.';

  @override
  String sourcesRemoveConfirmTitle(String name) {
    return 'Remover “$name”?';
  }

  @override
  String get sourcesRemoveConfirmBody =>
      'Remove configuração, senha e cache deste telefone. Progresso, notas e histórico ficam.';

  @override
  String get sourcesDismiss => 'Remover';

  @override
  String get socialTitle => 'Comunidade';

  @override
  String get socialSubtitleOff => 'Desligada: nada sobre você sai do telefone';

  @override
  String get socialSubtitleOn => 'Perfil, classificações e notas de leitura';

  @override
  String get socialOffIntro =>
      'A Comunidade está desligada: nada sai do seu telefone e o app não pede nada à rede. Abaixo você vê exatamente o cartão que os outros leitores veriam se você a ligasse.';

  @override
  String get socialNameLabel => 'Apelido';

  @override
  String get socialNameHint => 'De 2 a 24 caracteres (nunca seu e-mail)';

  @override
  String get socialBioLabel => 'Apresentação (opcional)';

  @override
  String get socialAudienceSection => 'Quem vê seu perfil e suas publicações';

  @override
  String get socialAudienceEveryone => 'Todos';

  @override
  String get socialAudienceFollowing => 'Quem eu sigo';

  @override
  String get socialAudienceMutual => 'Amigos em comum';

  @override
  String get socialAudienceEveryoneNote =>
      'Qualquer pessoa com a Comunidade ligada neste backend vê seu perfil, publicações e posição.';

  @override
  String get socialAudienceFollowingNote =>
      'Só as pessoas que você segue primeiro veem seu perfil, publicações e linha na classificação.';

  @override
  String get socialAudienceMutualNote =>
      'Só quem você segue e que também segue você vê seu perfil e publicações. Essa pessoa recebe seu apelido para poder retribuir.';

  @override
  String get socialSwitchesSection =>
      'O que mostrar além dos números e gêneros';

  @override
  String get socialShowPhoto => 'Mostrar a foto da conta';

  @override
  String get socialShowSeries => 'Mostrar os títulos mais lidos';

  @override
  String get socialShowActivity => 'Mostrar a atividade dos últimos 14 dias';

  @override
  String get socialPreviewSection => 'Prévia exata do que sai';

  @override
  String get socialPreviewHiddenExcluded => 'Séries ocultas excluídas';

  @override
  String socialPreviewLocked(String what) {
    return '$what: não publicado';
  }

  @override
  String get socialPreviewPhoto => 'Foto';

  @override
  String get socialPreviewSeries => 'Títulos';

  @override
  String get socialPreviewActivity => 'Atividade';

  @override
  String get socialWipeWarning =>
      'Desligar a Comunidade apaga tudo o que você publicou: perfil, publicações, comentários, curtidas, vínculos e mensagens (também nas conversas dos outros). Os bloqueios permanecem.';

  @override
  String get socialTurnOn => 'Ligar a Comunidade';

  @override
  String get socialTurnOff => 'Desligar a Comunidade e apagar tudo';

  @override
  String get socialTabBoards => 'Classificações';

  @override
  String get socialTabFeed => 'Feed';

  @override
  String get socialTabPeople => 'Pessoas';

  @override
  String get socialBoardWeek => 'Semana';

  @override
  String get socialBoardMonth => 'Mês';

  @override
  String get socialBoardAllTime => 'Sempre';

  @override
  String get socialBoardStreak => 'Sequência';

  @override
  String get socialYouBadge => 'VOCÊ';

  @override
  String socialChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos',
      one: '1 capítulo',
    );
    return '$_temp0';
  }

  @override
  String socialStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '1 dia',
    );
    return '$_temp0';
  }

  @override
  String get socialBoardEmpty => 'Ninguém na classificação ainda';

  @override
  String get socialFeedEmptyTitle => 'Nenhuma publicação ainda';

  @override
  String get socialFeedEmptyMessage =>
      'Notas, resenhas e recomendações dos leitores aparecerão aqui.';

  @override
  String get socialPostKindNote => 'Nota';

  @override
  String get socialPostKindReview => 'Resenha';

  @override
  String get socialPostKindRecommendation => 'Recomendação';

  @override
  String socialSpoilerUpTo(String chapter) {
    return 'Contém spoilers até o cap. $chapter';
  }

  @override
  String get socialSpoilerGeneric => 'Contém spoilers';

  @override
  String get socialSpoilerReveal => 'Toque para mostrar mesmo assim';

  @override
  String get socialFlaggedTitle => 'Conteúdo denunciado por vários leitores';

  @override
  String socialFlaggedReveal(String author) {
    return 'De $author · Toque para ver';
  }

  @override
  String get socialSearchPeopleHint => 'Buscar por apelido…';

  @override
  String get socialSearchNoEmailNotice =>
      'Aqui não há e-mails: busque o apelido escolhido pelo leitor.';

  @override
  String get socialPeopleFollowingSection => 'Seguindo';

  @override
  String get socialPeopleEmpty =>
      'Você ainda não segue ninguém. Busque um apelido ou abra alguém pelas classificações.';

  @override
  String get socialSearchNone => 'Ninguém com esse apelido';

  @override
  String socialAffinityLabel(int percent) {
    return '$percent% de afinidade';
  }

  @override
  String get socialInCommonSection => 'Em comum';

  @override
  String socialInCommonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count títulos em comum',
      one: '1 título em comum',
    );
    return '$_temp0';
  }

  @override
  String get socialFollow => 'Seguir';

  @override
  String get socialFollowBack => 'Seguir de volta';

  @override
  String get socialFollowing => 'Seguindo';

  @override
  String get socialMutual => 'Amigos';

  @override
  String get socialUnavailableTitle => 'Este backend não tem a Comunidade';

  @override
  String get socialUnavailableBody =>
      'O servidor ao qual a conta está ligada não tem as tabelas da Comunidade. O resto do app funciona normalmente.';

  @override
  String get socialNeedsAccount =>
      'A Comunidade precisa de uma conta: entre pelas Configurações.';

  @override
  String get socialRefusedSnack => 'Não foi possível concluir a ação.';

  @override
  String get socialLoadError => 'Não consigo ler a Comunidade agora.';

  @override
  String get socialRetry => 'Tentar de novo';

  @override
  String get socialProfileUnavailable => 'Perfil indisponível';

  @override
  String get socialProfilePrivate => 'Perfil privado';

  @override
  String get socialProfileGenres => 'Gêneros';

  @override
  String get socialProfileActivity => 'Últimos 14 dias';

  @override
  String get socialProfileSeriesTitles => 'Mais lidas';

  @override
  String get socialStatChapters => 'Capítulos';

  @override
  String get socialStatSeries => 'Séries';

  @override
  String get socialStatStreak => 'Sequência';

  @override
  String get socialWrite => 'Escrever';

  @override
  String get socialComposeTitle => 'Nova publicação';

  @override
  String get socialComposeBodyHint => 'O que você acha?';

  @override
  String get socialComposeSeries => 'Série';

  @override
  String get socialComposeNoSeries => 'Nenhuma série';

  @override
  String get socialComposeRating => 'Nota';

  @override
  String get socialComposeSpoiler => 'Contém spoilers';

  @override
  String get socialComposeSpoilerChapter => 'Até o capítulo (opcional)';

  @override
  String get socialComposePublish => 'Publicar';

  @override
  String get socialRefusalEmpty => 'Escreva algo antes de publicar.';

  @override
  String get socialRefusalTooLong => 'O texto é longo demais.';

  @override
  String get socialRefusalHiddenSeries =>
      'Esta série está oculta: não é citada na Comunidade.';

  @override
  String get socialRefusalNeedsSeries =>
      'Uma resenha ou recomendação fala de uma série: escolha uma.';

  @override
  String get socialRefusalNeedsRating => 'Escolha uma nota de 1 a 10.';

  @override
  String socialCommentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comentários',
      one: '1 comentário',
      zero: 'Comentar',
    );
    return '$_temp0';
  }

  @override
  String get socialCommentsTitle => 'Comentários';

  @override
  String get socialCommentsEmpty => 'Ainda sem comentários';

  @override
  String get socialCommentHint => 'Escreva um comentário…';

  @override
  String socialReplyHint(String author) {
    return 'Responder a $author…';
  }

  @override
  String get socialReply => 'Responder';

  @override
  String get socialCancelReply => 'Cancelar resposta';

  @override
  String get socialSend => 'Enviar';

  @override
  String get socialLike => 'Curtir';

  @override
  String get socialMoreActions => 'Mais ações';

  @override
  String get socialMute => 'Silenciar';

  @override
  String get socialUnmute => 'Reativar';

  @override
  String get socialFollowersSection => 'Seguem você';

  @override
  String get socialMutedNote =>
      'Silenciado: as publicações e os comentários dessa pessoa ficam ocultos aqui.';

  @override
  String get socialRemovePost => 'Remover publicação';

  @override
  String get socialRemovePostConfirm =>
      'A publicação sai com seus comentários e curtidas. Não dá para editar: você pode escrevê-la de novo.';

  @override
  String get socialRemoveComment => 'Remover';

  @override
  String get socialUnknownReader => 'Um leitor';

  @override
  String get socialSeriesPostsTitle => 'Na Comunidade';

  @override
  String get socialSeriesPostsEmpty => 'Ninguém falou dela ainda';

  @override
  String get socialSeriesTalk => 'Fale dela na Comunidade';

  @override
  String socialBlockPerson(String name) {
    return 'Bloquear $name';
  }

  @override
  String get socialBlockAction => 'Bloquear';

  @override
  String get socialBlockConfirm =>
      'Nenhum dos dois verá o perfil, as publicações ou os comentários do outro, nem poderá escrever-lhe. Os vínculos entre vocês são removidos. A outra pessoa não será avisada.';

  @override
  String get socialBlockedSnack => 'Pessoa bloqueada.';

  @override
  String get socialReport => 'Denunciar';

  @override
  String get socialReportIntro =>
      'Por que você está denunciando? A pessoa denunciada não saberá, e a denúncia leva uma cópia do texto.';

  @override
  String get socialReportReasonSpam => 'Spam ou publicidade';

  @override
  String get socialReportReasonHarassment => 'Assédio ou insistência';

  @override
  String get socialReportReasonSpoiler => 'Spoiler sem aviso';

  @override
  String get socialReportReasonInappropriate => 'Conteúdo inadequado';

  @override
  String get socialReportReasonOther => 'Outro';

  @override
  String get socialReportNoteHint => 'Uma nota, se quiser (opcional)';

  @override
  String get socialReportSend => 'Enviar';

  @override
  String get socialReportSent => 'Denúncia enviada.';

  @override
  String get messagesTitle => 'Mensagens';

  @override
  String get messagesWrite => 'Escrever';

  @override
  String get messagesEmpty =>
      'Nenhuma conversa ainda. Escreva a alguém a partir do perfil.';

  @override
  String get messagesThreadEmpty => 'Ainda não há mensagens.';

  @override
  String get messagesHint => 'Escreva uma mensagem';

  @override
  String get messagesSend => 'Enviar';

  @override
  String get messagesUnknownPerson => 'Um leitor';

  @override
  String get messagesDeleteTitle => 'Excluir a mensagem?';

  @override
  String get messagesDeleteBody => 'Some para os dois.';

  @override
  String get messagesDeleteAction => 'Excluir';

  @override
  String messagesExtensionMine(String folder) {
    return 'Você pediu mais tempo para «$folder».';
  }

  @override
  String messagesExtensionTheirs(String name, String folder) {
    return '$name pede mais tempo para «$folder».';
  }

  @override
  String get messagesRenew => 'Renovar';

  @override
  String messagesRenewed(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Compartilhamento renovado até $dateString.';
  }

  @override
  String get messagesAskMore => 'Pedir mais tempo';

  @override
  String get messagesAskSent => 'Pedido enviado.';

  @override
  String get privacyTitle => 'Privacidade e Comunidade';

  @override
  String get privacyEntryNote =>
      'Comunidade, quem vê o seu perfil, mensagens e pessoas bloqueadas';

  @override
  String get privacyOffNote =>
      'Com a Comunidade desligada, nada sai do telemóvel. As escolhas abaixo valem quando a ligar.';

  @override
  String get privacyNeedsName =>
      'Para ligar a Comunidade é preciso um apelido e uma conta: escolha o apelido no ecrã que se abre.';

  @override
  String get privacyMessagesSection => 'Quem pode escrever-me';

  @override
  String get privacyMessagesNobody => 'Ninguém';

  @override
  String get privacyBlockedSection => 'Pessoas bloqueadas';

  @override
  String get privacyBlockedEmpty => 'Não bloqueou ninguém.';

  @override
  String get privacyBlockedPerson => 'Pessoa bloqueada';

  @override
  String get privacyUnblock => 'Desbloquear';

  @override
  String messageNotificationTitle(String sender) {
    return 'Nova mensagem de $sender';
  }

  @override
  String driveExpiryNoticeTitle(String owner) {
    return 'A biblioteca de $owner está prestes a expirar';
  }

  @override
  String driveExpiryNoticeText(String folder, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '“$folder” expira em $dateString. Abra o Kagami para pedir mais tempo.';
  }

  @override
  String get settingsBackupFolder => 'Pasta das cópias';

  @override
  String settingsBackupFolderChosen(String path) {
    return 'Além do espaço do app, a cópia automática também vai para $path';
  }

  @override
  String get settingsBackupFolderNone =>
      'Nenhuma: as cópias ficam só no espaço do app';

  @override
  String get settingsBackupFolderRefused =>
      'Esta pasta está dentro de uma fonte da biblioteca: a biblioteca é compartilhada e as cópias contêm seus dados pessoais. Escolha outra.';

  @override
  String get driveShareDownloadOption => 'Também pode baixar';

  @override
  String get driveShareDownloadNote =>
      'É um acordo entre apps, não uma proteção: quem tem acesso à pasta pode baixar os arquivos pelo Drive, pelo site ou com outro app. O Kagami de quem recebe só baixa se você permitir aqui.';

  @override
  String get driveShareRowDownload => 'também baixar';

  @override
  String get driveShareRowStreaming => 'só streaming';

  @override
  String get driveShareDownloadAllow => 'Permitir baixar';

  @override
  String get driveShareDownloadDeny => 'Só streaming';

  @override
  String get driveShareDownloadUnavailable =>
      'Este backend ainda não conhece a permissão de baixar: o compartilhamento continua só streaming.';

  @override
  String get driveReceivedCanDownload => 'você pode ler e baixar';

  @override
  String get driveReceivedStreamOnly => 'você só pode ler em streaming';

  @override
  String get seriesArchiveOwn => 'Arquivar no meu Drive';

  @override
  String get seriesArchiveOwnSiteMissing =>
      'É preciso o site desta série: instale-o em Configurações → Sites; os sites da biblioteca de outra pessoa não se instalam sozinhos.';

  @override
  String get seriesBringData => 'Trazer meus dados para cá';

  @override
  String get seriesBringDataPick => 'De qual série?';

  @override
  String get seriesBringDataEmpty =>
      'Nenhuma outra série da biblioteca tem dados seus para trazer.';

  @override
  String seriesBringDataBody(String from, String to, int matched) {
    String _temp0 = intl.Intl.pluralLogic(
      matched,
      locale: localeName,
      other: '# capítulos lidos com o mesmo número',
      one: '# capítulo lido com o mesmo número',
    );
    return '«$from» → «$to». Status, nota, anotações e coleções passam para a série de destino, junto com $_temp0. Eles se fundem com o que já existe: as leituras se somam e, no resto, vale o mais recente. «$from» continua na biblioteca, sem seus dados.';
  }

  @override
  String seriesBringDataLost(int lost) {
    String _temp0 = intl.Intl.pluralLogic(
      lost,
      locale: localeName,
      other: '# capítulos lidos não têm um capítulo com o mesmo número: não são trazidos, e suas posições, histórico e marcadores se perdem.',
      one: '# capítulo lido não tem um capítulo com o mesmo número: não é trazido, e sua posição, histórico e marcadores se perdem.',
    );
    return '$_temp0';
  }

  @override
  String get seriesBringDataConfirm => 'Trazer os dados';

  @override
  String seriesBringDataDone(String title) {
    return 'Dados trazidos para «$title».';
  }

  @override
  String get seriesBringDataNoChapters =>
      'Não é possível ler agora os capítulos de uma das duas séries: tente de novo daqui a pouco.';

  @override
  String sitesUnconfirmed(String name) {
    return '$name continua até você confirmar';
  }

  @override
  String sitesConfirmReplace(String name) {
    return 'Substituir $name';
  }

  @override
  String get serverLinkTrust =>
      'Quem gerencia este servidor pode escrever no seu Drive: a permissão que o Google pede fica nas mãos dessa pessoa. Conecte apenas um servidor em que você confia.';

  @override
  String get serverErrorUpdateServer =>
      'Este servidor precisa ser atualizado: enquanto não aceitar bilhetes, seu acesso não é enviado a ele.';

  @override
  String get serverErrorTicketsUnavailable =>
      'O backend não emite bilhetes para servidores: seu acesso não é enviado ao servidor de outra pessoa.';

  @override
  String get serverErrorImpostor =>
      'Este servidor diz ser um já conectado em outro endereço: nada é enviado a ele.';

  @override
  String get serverErrorOtherServer =>
      'Neste endereço agora responde outro servidor: conecte-o novamente.';

  @override
  String get serverErrorNotOwner =>
      'Esta pasta do Drive não é sua: o servidor não move nada para a lixeira.';

  @override
  String get sitesOriginBuiltIn => 'Incluído';

  @override
  String get sitesOriginCatalog => 'Catálogo';

  @override
  String get sitesOriginUser => 'Seu';

  @override
  String get sitesCatalogBroken => 'Fora de serviço';

  @override
  String sitesCatalogBrokenWith(String message) {
    return 'Fora de serviço: $message';
  }

  @override
  String get sitesNeedsNewer => 'Precisa de uma versão mais nova do Kagami';

  @override
  String get sitesCatalogSection => 'Catálogo de sites';

  @override
  String get sitesCatalogUse => 'Usar o catálogo';

  @override
  String get sitesCatalogOff =>
      'Desligado: valem só os sites incluídos e os seus, e o app não faz nenhuma requisição de rede para isso.';

  @override
  String sitesCatalogIssue(int serial, String date) {
    return 'Edição $serial de $date';
  }

  @override
  String sitesCatalogChecked(String when) {
    return 'Última verificação: $when';
  }
}
