// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Igual que el sistema';

  @override
  String get seriesShelfNone => 'Sin estado';

  @override
  String get seriesShelfPlanned => 'Por leer';

  @override
  String get seriesShelfReading => 'Leyendo';

  @override
  String get seriesShelfPaused => 'En pausa';

  @override
  String get seriesShelfCompleted => 'Terminada';

  @override
  String get seriesShelfDropped => 'Abandonada';

  @override
  String get seriesReleaseOngoing => 'En curso';

  @override
  String get seriesReleaseCompleted => 'Finalizada';

  @override
  String get seriesReleaseHiatus => 'En pausa';

  @override
  String get seriesReleaseCancelled => 'Cancelada';

  @override
  String get seriesReleaseUnknown => 'Estado desconocido';

  @override
  String get seriesNotFound => 'Serie no encontrada.';

  @override
  String get seriesOfflineTitle => 'Capítulos en Drive';

  @override
  String get seriesOfflineMessage =>
      'Sin conexión no se puede ver la lista de capítulos de esta serie. Aparecerá sola en cuanto vuelva la red.';

  @override
  String get seriesNoIndexTitle => 'Sin índice';

  @override
  String get seriesNoIndexMessage =>
      'Esta serie no tiene un index.json: hay que regenerar los índices con el archivador que la escribió.';

  @override
  String get seriesNoChaptersTitle => 'Sin capítulos';

  @override
  String get seriesNoChaptersMessage =>
      'Ninguno coincide con la búsqueda y los filtros elegidos.';

  @override
  String seriesDownloadAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Descargar $count capítulos?',
      one: '¿Descargar un capítulo?',
    );
    return '$_temp0';
  }

  @override
  String get seriesDownloadAllMessage =>
      'Todos los capítulos que ahora se leen desde Drive pasarán al teléfono, y desde ahí también se leen sin red.';

  @override
  String get seriesDownload => 'Descargar';

  @override
  String seriesCleanupRemote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos leídos siguen en Drive',
      one: 'Un capítulo leído sigue en Drive',
    );
    return '$_temp0';
  }

  @override
  String seriesCleanupLocal(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos leídos ocupan $size',
      one: 'Un capítulo leído ocupa $size',
    );
    return '$_temp0';
  }

  @override
  String seriesDownloadFailed(String error) {
    return 'La descarga falló: $error. Reintentar';
  }

  @override
  String get seriesDownloadWaiting =>
      'Esperando la red: se reanuda sola. Cancelar';

  @override
  String get seriesDownloadQueued => 'En cola. Cancelar';

  @override
  String get seriesDownloadCancel => 'Cancelar la descarga';

  @override
  String get seriesPlaceLocal => 'En el teléfono';

  @override
  String get seriesPlaceDrive => 'En Drive';

  @override
  String get seriesPlaceMixed => 'Teléfono y Drive';

  @override
  String get seriesMuteTooltipOn => 'Avisos de capítulos nuevos silenciados';

  @override
  String get seriesMuteTooltipOff => 'Avisos de capítulos nuevos activados';

  @override
  String get seriesMuteUnmuted => 'Avisos de capítulos nuevos reactivados.';

  @override
  String get seriesMuteMuted => 'Avisos de capítulos nuevos silenciados.';

  @override
  String seriesCaughtUpMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Al día con lo que hay en el teléfono: faltan $count capítulos anunciados.',
      one: 'Al día con lo que hay en el teléfono: falta un capítulo anunciado.',
    );
    return '$_temp0';
  }

  @override
  String get seriesCaughtUpAll => 'Leída entera.';

  @override
  String get seriesResumeToContinue => 'PARA CONTINUAR';

  @override
  String get seriesResumeToStart => 'PARA EMPEZAR';

  @override
  String get seriesResumeHalfway => 'DEJADO A MEDIAS';

  @override
  String seriesResumePage(int page, int total) {
    return 'página $page de $total';
  }

  @override
  String get seriesContinue => 'Continuar';

  @override
  String get seriesStart => 'Empezar';

  @override
  String get seriesResume => 'Retomar';

  @override
  String get seriesNextChapter => 'Capítulo siguiente';

  @override
  String get seriesFigureChapters => 'Capítulos';

  @override
  String get seriesFigureRead => 'Leídos';

  @override
  String get seriesFigureProgress => 'Avance';

  @override
  String get seriesFigureRating => 'Nota';

  @override
  String get seriesMyShelf => 'Mi estante';

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
  String get seriesCollections => 'Colecciones';

  @override
  String get seriesNotes => 'Notas';

  @override
  String get seriesRatingSheetTitle => '¿Qué nota le pones?';

  @override
  String get seriesNotesHint => 'Por dónde ibas, qué te parece…';

  @override
  String get seriesSave => 'Guardar';

  @override
  String get seriesRatingWord1 => 'Pésima';

  @override
  String get seriesRatingWord2 => 'Mala';

  @override
  String get seriesRatingWord3 => 'Floja';

  @override
  String get seriesRatingWord4 => 'Mediocre';

  @override
  String get seriesRatingWord5 => 'Aceptable';

  @override
  String get seriesRatingWord6 => 'Correcta';

  @override
  String get seriesRatingWord7 => 'Buena';

  @override
  String get seriesRatingWord8 => 'Muy buena';

  @override
  String get seriesRatingWord9 => 'Excelente';

  @override
  String get seriesRatingWord10 => 'Obra maestra';

  @override
  String get seriesRatingNone => 'Sin nota';

  @override
  String get seriesRatingHint => 'Toca o desliza';

  @override
  String seriesRatingBefore(int rating) {
    return 'Antes: $rating';
  }

  @override
  String get seriesRatingRemove => 'Quitar';

  @override
  String get seriesRatingSave => 'Guardar la nota';

  @override
  String get seriesSynopsis => 'Sinopsis';

  @override
  String get seriesGenres => 'Géneros';

  @override
  String get seriesTags => 'Etiquetas';

  @override
  String get seriesCreators => 'Quién la hizo';

  @override
  String seriesMoreTags(int count) {
    return '$count más';
  }

  @override
  String get seriesPaceToRead => 'Por leer';

  @override
  String seriesPaceCaption(int chapters, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      chapters,
      locale: localeName,
      other: '$chapters capítulos',
      one: 'un capítulo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages páginas',
      one: 'una página',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get seriesPaceNext => 'Próximo capítulo';

  @override
  String get seriesPaceNextCaption => 'según el ritmo de los últimos';

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
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get seriesWhenLate => 'con retraso';

  @override
  String get seriesWhenExpected => 'esperado';

  @override
  String get seriesWhenToday => 'hoy';

  @override
  String get seriesWhenTomorrow => 'mañana';

  @override
  String seriesWhenInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'en $count días',
      one: 'en 1 día',
    );
    return '$_temp0';
  }

  @override
  String seriesWhenInWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'en $count semanas',
      one: 'en 1 semana',
    );
    return '$_temp0';
  }

  @override
  String get seriesShowLess => 'Reducir';

  @override
  String get seriesShowMore => 'Leer más';

  @override
  String get seriesChaptersTitle => 'Capítulos';

  @override
  String seriesChaptersOf(int total) {
    return 'de $total';
  }

  @override
  String get seriesSearchChapter => 'Buscar capítulo…';

  @override
  String get seriesSortNewest => 'Del más reciente';

  @override
  String get seriesSortOldest => 'Desde el primero';

  @override
  String get seriesMarkAll => 'Marcar todos';

  @override
  String get seriesDownloadFromDrive => 'Descargar de Drive';

  @override
  String get seriesFreeSpace => 'Liberar espacio';

  @override
  String get seriesFilterUnread => 'Por leer';

  @override
  String get seriesFilterDownloaded => 'Descargados';

  @override
  String get seriesFilterAll => 'Todos';

  @override
  String seriesSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seleccionados',
      one: '1 seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get seriesMarkReadMany => 'Marcar como leídos';

  @override
  String get seriesMarkUnread => 'Marcar como por leer';

  @override
  String get seriesMarkRead => 'Marcar como leído';

  @override
  String get seriesMarkReadThrough => 'Marcar como leído hasta aquí';

  @override
  String get seriesSimilar => 'Más como esta';

  @override
  String get seriesChapterNotDownloaded => 'No descargado';

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
  String get seriesDownloadToPhone => 'Descargar al teléfono';

  @override
  String get readerSeriesUnavailable => 'Serie no disponible.';

  @override
  String get readerNoPagesIndex =>
      'Esta serie no tiene un pages.json: hay que regenerar los índices con el archivador que la escribió.';

  @override
  String get readerSeriesOffline =>
      'Sin conexión no se puede abrir esta serie: la lista de sus páginas está en Drive. Se abrirá en cuanto vuelva la red.';

  @override
  String get readerChapterNotOnPhone =>
      'Este capítulo todavía no está en el teléfono. Puede que la sincronización esté a medias: vuelve a intentarlo más tarde.';

  @override
  String get readerChapterNoPages => 'El capítulo no tiene páginas legibles.';

  @override
  String get readerPagesNotOnPhone =>
      'Las páginas de este capítulo todavía no están en el teléfono. El índice las anuncia, los archivos no: los tiene que traer la carpeta sincronizada.';

  @override
  String get readerMarkEarlierTitle => '¿Marcar los anteriores como leídos?';

  @override
  String readerMarkEarlierBody(int count, String chapter) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Terminaste $chapter. Los $count capítulos anteriores siguen como por leer: si ya los leíste en otro sitio, márcalos todos como leídos.',
      one:
          'Terminaste $chapter. El capítulo anterior sigue como por leer: si ya lo leíste en otro sitio, márcalo como leído.',
    );
    return '$_temp0';
  }

  @override
  String readerMarkEarlierConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Marcar los $count como leídos',
      one: 'Marcar el anterior como leído',
    );
    return '$_temp0';
  }

  @override
  String get readerMarkEarlierDecline => 'Dejarlos por leer';

  @override
  String readerBookmarkAdded(int page) {
    return 'Página $page guardada';
  }

  @override
  String get readerChapters => 'Capítulos';

  @override
  String get readerBookmarks => 'Páginas guardadas';

  @override
  String get readerNoBookmarks => 'Ninguna página guardada';

  @override
  String get readerNoBookmarksHint =>
      'El marcador guarda el punto de una página; el del capítulo ya lo recuerda la reanudación.';

  @override
  String readerBookmarkPage(int page) {
    return 'página $page';
  }

  @override
  String get readerBookmarkRemove => 'Quitar';

  @override
  String get readerToTop => 'Volver arriba';

  @override
  String get readerPageNotFromDrive => 'Página no llegada de Drive';

  @override
  String get readerPageUnreadable => 'Página ilegible';

  @override
  String get readerPageNotSynced => 'Página sin sincronizar';

  @override
  String get readerPageNotDownloaded => 'Página aún sin descargar';

  @override
  String get readerPageOfflineHint =>
      'Sin conexión. Llegará sola en cuanto vuelva la red.';

  @override
  String get readerRetryNow => 'Reintentar ahora';

  @override
  String get readerLastChapterOnPhone =>
      'Es el último capítulo que hay en el teléfono.';

  @override
  String get readerNextChapter => 'Capítulo siguiente';

  @override
  String get readerContinue => 'Continuar';

  @override
  String get readerBookmarkThisPage => 'Guardar esta página';

  @override
  String get readerHowToRead => 'Cómo se lee';

  @override
  String get readerPreviousChapter => 'Capítulo anterior';

  @override
  String get readerNextChapterTooltip => 'Capítulo siguiente';

  @override
  String get readerSearchChapter => 'Buscar capítulo…';

  @override
  String get readerNewestFirst => 'Del más reciente';

  @override
  String get readerOldestFirst => 'Desde el primero';

  @override
  String readerReadingNow(String current, int total) {
    return 'Leyendo: $current / $total capítulos';
  }

  @override
  String get readerMode => 'Modo de lectura';

  @override
  String get readerModeStrip => 'Continua';

  @override
  String get readerModePage => 'Paginada';

  @override
  String get readerDirection => 'Sentido de lectura';

  @override
  String get readerDirectionLtr => 'Izquierda → derecha';

  @override
  String get readerDirectionRtl => 'Derecha → izquierda';

  @override
  String get readerFit => 'Ajuste';

  @override
  String get readerBackground => 'Fondo';

  @override
  String get readerBrightness => 'Brillo';

  @override
  String get readerAutoScroll => 'Desplazamiento automático';

  @override
  String get readerAutoScrollOff => 'desactivado';

  @override
  String readerAutoScrollRate(int rate) {
    return '$rate páginas/min';
  }

  @override
  String get readerShowPageNumber => 'Número de página';

  @override
  String get readerShowProgress => 'Barra de avance';

  @override
  String get readerShowScrollTop => 'Botón para volver arriba';

  @override
  String get readerKeepAwake => 'Mantener la pantalla encendida';

  @override
  String get readerDoublePage => 'Dos páginas juntas';

  @override
  String get readerLockRotation => 'Bloquear la rotación';

  @override
  String get archiveTitle => 'Descargar un manga';

  @override
  String get archiveIntro =>
      'Busca un título en los sitios compatibles o pega el enlace de una serie: Kagami la descarga del sitio, con metadatos, portada y la lista completa de capítulos, en la biblioteca.';

  @override
  String get archiveSearchHint => 'Buscar un manga por título';

  @override
  String get archiveClear => 'Borrar';

  @override
  String get archivePaste => 'Pegar';

  @override
  String get archiveReading => 'Leyendo la serie…';

  @override
  String get archiveVerify => 'Verificar serie';

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
    return 'Ya en la biblioteca: $archived de $total capítulos. Los que ya están se omiten.';
  }

  @override
  String get archiveWhatSection => 'Qué descargar';

  @override
  String get archiveModeAll => 'Toda';

  @override
  String get archiveModeFrom => 'Desde el capítulo';

  @override
  String get archiveModePick => 'Elegidos';

  @override
  String get archiveModeAllHint =>
      'Todos los capítulos. Si lo repites más adelante, solo llegan los nuevos o los dañados.';

  @override
  String get archiveModeFromHint =>
      'Desde el capítulo elegido en adelante: los anteriores quedan en la lista de la serie, marcados como no descargados.';

  @override
  String get archiveModePickHint =>
      'Solo los capítulos que toques. Los demás quedan en la lista, sin descargar.';

  @override
  String get archiveChapterNumberHint =>
      'Número del capítulo, como en el sitio';

  @override
  String archivePickedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elegidos',
      one: '1 elegido',
    );
    return '$_temp0';
  }

  @override
  String get archiveSelectAll => 'Todos';

  @override
  String get archiveSelectNone => 'Ninguno';

  @override
  String get archiveWhereSection => 'Dónde';

  @override
  String get archiveWhereServer => 'Servidor';

  @override
  String get archiveWhereDrive => 'Drive';

  @override
  String get archiveWhereDriveAndPhone => 'Drive y teléfono';

  @override
  String get archiveWherePhone => 'Teléfono';

  @override
  String get archiveWhereDriveHint =>
      'En la carpeta de Drive de la biblioteca. Las páginas pasan por el teléfono y se van en cuanto Drive las tiene: se leen en streaming o se descargan después.';

  @override
  String get archiveWhereDriveAndPhoneHint =>
      'En la carpeta de Drive de la biblioteca, y los capítulos se quedan también en el teléfono para leerlos sin red.';

  @override
  String get archiveWherePhoneHint =>
      'En el teléfono, en la carpeta de manga o en el espacio de la app. Si conectas Drive, se puede descargar directamente allí.';

  @override
  String archiveServerHint(String name, String folder, String other) {
    String _temp0 = intl.Intl.selectLogic(other, {
      'other': ' Atención: no es la carpeta que lee la app.',
      'same': '',
    });
    return 'Lo descarga «$name» y lo sube a «$folder» en Drive, incluso con el teléfono apagado. Las series en curso las sigue el servidor.$_temp0';
  }

  @override
  String get archiveDelaySection => 'Pausa entre solicitudes';

  @override
  String get archiveDelayNone => 'Ninguna';

  @override
  String archiveDelaySeconds(String seconds) {
    return '$seconds s';
  }

  @override
  String get archiveDelayHint =>
      'A los sitios no les gusta que se descargue a ráfagas: una pausa corta evita que te bloqueen.';

  @override
  String get archiveDownloadAll => 'Descargar toda la serie';

  @override
  String get archiveDownloadFrom => 'Descargar desde el capítulo elegido';

  @override
  String archiveDownloadPicked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Descargar $count capítulos',
      one: 'Descargar 1 capítulo',
    );
    return '$_temp0';
  }

  @override
  String archiveNoResults(String site) {
    return 'Sin resultados en $site.';
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
      'El sitio quiere saber que eres una persona: al tocar se abre la verificación y luego se busca también allí';

  @override
  String get archiveStatusOngoing => 'en curso';

  @override
  String get archiveStatusCompleted => 'finalizada';

  @override
  String get archiveStatusHiatus => 'en pausa';

  @override
  String get archiveStatusCancelled => 'cancelada';

  @override
  String get archiveStatusUnknown => 'estado desconocido';

  @override
  String get archiveErrChallenge =>
      'El sitio pide una verificación que desde aquí no se puede hacer.';

  @override
  String get archiveErrOffline => 'Sin conexión: el sitio no responde.';

  @override
  String get archiveErrVerifyIncomplete =>
      'La verificación del sitio no se completó.';

  @override
  String archiveQueuedSnack(String title) {
    return '«$title» está en cola. Continúa incluso con la pantalla apagada.';
  }

  @override
  String archiveQueuedServerSnack(String title, String server) {
    return '«$title» está en cola en «$server». El teléfono incluso puede apagarse.';
  }

  @override
  String get archiveServerFallbackName => 'servidor';

  @override
  String get archiveDownloads => 'Descargas';

  @override
  String get archiveClearHistory => 'Limpiar';

  @override
  String get archiveQueueStopped => 'Cola detenida';

  @override
  String get archiveQueueResumeHint =>
      'Se reanuda sola; si la tocas, arranca ahora';

  @override
  String archiveJobAutomatic(String destination) {
    return 'Capítulos nuevos · $destination';
  }

  @override
  String archiveJobQueued(String destination) {
    return 'En cola · $destination';
  }

  @override
  String get archiveRemoveFromQueue => 'Quitar de la cola';

  @override
  String archiveHistoryLine(String when, String message) {
    return '$when · $message';
  }

  @override
  String get archiveSites => 'Sitios compatibles';

  @override
  String get archiveMoreSites =>
      'Vendrán más sitios: el soporte para nuevos proveedores llegará con las próximas actualizaciones.';

  @override
  String archiveLinkCopied(String url) {
    return '$url copiado al portapapeles.';
  }

  @override
  String get archiveTracked => 'Series en curso';

  @override
  String get archiveTrackedIntro =>
      'Las series en curso descargadas desde aquí se vuelven a revisar: solo llegan los capítulos nuevos, al mismo destino. Las del servidor las sigue el servidor.';

  @override
  String get archiveCheckDaily => 'Revisión diaria';

  @override
  String get archiveCheckManual => 'Solo manual';

  @override
  String archiveCheckAt(String time) {
    return 'A las $time, incluso con la app cerrada';
  }

  @override
  String get archiveCheckTime => 'Hora';

  @override
  String get archiveCheckTimeHelp => 'Hora de la revisión';

  @override
  String get archiveWifiOnly => 'Solo con Wi-Fi';

  @override
  String get archiveWifiOnlyOn => 'Espera una red que no se pague por consumo';

  @override
  String get archiveWifiOnlyOff => 'También con datos móviles';

  @override
  String get archiveCheckNow => 'Revisar ahora';

  @override
  String get archiveNoTracked => 'Ninguna serie que seguir, por ahora';

  @override
  String archiveTrackedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series que seguir',
      one: '1 serie que seguir',
    );
    return '$_temp0';
  }

  @override
  String archiveTrackedLine(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos conocidos',
      one: '1 capítulo conocido',
    );
    return '$_temp0 · $destination';
  }

  @override
  String archiveTrackedLineChecked(int count, String destination, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos conocidos',
      one: '1 capítulo conocido',
    );
    return '$_temp0 · $destination · revisada $when';
  }

  @override
  String get archiveStopFollowing => 'Dejar de seguirla';

  @override
  String archiveCheckQueued(String names) {
    return 'capítulos nuevos de $names';
  }

  @override
  String archiveCheckRemoved(String names) {
    return '$names ahora finalizada';
  }

  @override
  String archiveCheckFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count no alcanzadas',
      one: '1 no alcanzada',
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
  String get archiveNoNewChapters => 'Ningún capítulo nuevo.';

  @override
  String get archiveNoConnection => 'Sin conexión.';

  @override
  String get archiveForgetTitle => '¿Dejar de seguirla?';

  @override
  String archiveForgetBody(String title) {
    return 'Los capítulos nuevos de «$title» ya no llegarán solos. Los ya descargados se quedan.';
  }

  @override
  String get archiveCancel => 'Cancelar';

  @override
  String get archiveForgetConfirm => 'Dejar';

  @override
  String archiveStartIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos.',
      one: '1 capítulo.',
    );
    return '$_temp0 Descarga todo o elige desde qué capítulo empezar: los anteriores quedan en la lista del lector, sin páginas.';
  }

  @override
  String get archiveStartNoMatch => 'Ningún capítulo con ese número.';

  @override
  String archiveStartFrom(String title, int remaining) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: '$remaining capítulos',
      one: '1 capítulo',
    );
    return 'Desde «$title» en adelante: $_temp0.';
  }

  @override
  String get archiveStartNone =>
      'Ningún capítulo elegido: se puede descargar todo.';

  @override
  String get archiveStartAll => 'Descargar todo';

  @override
  String get archiveStartHere => 'Desde aquí';

  @override
  String get browserTitle => 'Verificación del sitio';

  @override
  String get browserPhoneOnly =>
      'La verificación solo se hace desde el teléfono.';

  @override
  String get browserInstructionsChapters =>
      'El sitio quiere saber que eres una persona. Completa la verificación: cuando aparezca la lista de capítulos, Kagami lo detecta y vuelve atrás sola.';

  @override
  String get browserInstructionsSearch =>
      'El sitio quiere saber que eres una persona. Completa la verificación: cuando aparezca la búsqueda del sitio, Kagami lo detecta y vuelve atrás sola.';

  @override
  String get browserSearchPhoneOnly =>
      'En este sitio solo se puede buscar desde el teléfono.';

  @override
  String get browserSearchSuperseded =>
      'Reemplazada por una búsqueda más reciente.';

  @override
  String get browserResponseTooLarge => 'Respuesta demasiado grande.';

  @override
  String get serverTitle => 'Servidor';

  @override
  String get serverClear => 'Limpiar';

  @override
  String get serverUnavailableNoSecret =>
      'Esta versión de la app no puede conectar servidores: quien la compiló no indicó el secreto del cliente Web (GOOGLE_SERVER_CLIENT_SECRET).';

  @override
  String get serverUnavailableAndroidOnly =>
      'Solo se puede conectar un servidor desde Android.';

  @override
  String get serverSignInRequired =>
      'Inicia sesión con Google para usar el servidor.';

  @override
  String get serverNoConnection => 'Sin conexión.';

  @override
  String get serverMissingGoogleServices =>
      'Falta google-services.json: esta versión no tiene el cliente de Google.';

  @override
  String get serverDriveAccessDenied => 'Google no concedió el acceso a Drive.';

  @override
  String get serverGoogleNotResponding =>
      'Google no responde: inténtalo de nuevo en un momento.';

  @override
  String serverWhenToday(String clock) {
    return 'hoy a las $clock';
  }

  @override
  String serverWhenDate(String date, String clock) {
    return '$date a las $clock';
  }

  @override
  String serverProgressStats(int pages, String size, int skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: ' · $skipped ya listas',
      zero: '',
    );
    return '$pages páginas nuevas · $size$_temp0';
  }

  @override
  String get serverRemoveFromQueue => 'Quitar de la cola';

  @override
  String get serverNoFirebase =>
      'El servidor reconoce a quien lo usa por la cuenta de Google, que en esta versión de la app no existe.';

  @override
  String get serverSignedOutIntro =>
      'Un ordenador siempre encendido puede descargar y subir a tu Drive en lugar del teléfono, que mientras tanto puede incluso apagarse. El servidor te reconoce por tu cuenta de Google.';

  @override
  String get serverSignIn => 'Iniciar sesión con Google';

  @override
  String get serverSignInSubtitle =>
      'Para crear tu servidor o usar el de otra persona';

  @override
  String serverInviteTitle(String sender, String serverName) {
    return '$sender te dio acceso a «$serverName»';
  }

  @override
  String get serverInviteSubtitle =>
      'Descarga en tu Drive, incluso con el teléfono apagado. Toca para conectarlo';

  @override
  String get serverIgnore => 'Ignorar';

  @override
  String get serverLinkIntro =>
      'Un ordenador siempre encendido —el tuyo o el de quien te dio acceso— puede descargar y subir a tu Drive en lugar del teléfono, que mientras tanto puede incluso apagarse.';

  @override
  String get serverCreate => 'Crea tu servidor';

  @override
  String get serverCreateSubtitle =>
      'Un comando para pegar en un ordenador con Docker: nada que configurar';

  @override
  String get serverLinkTitle => 'Conectar un servidor';

  @override
  String get serverLinkSubtitle =>
      'El tuyo, ya encendido, o el de quien te añadió';

  @override
  String get serverStateConnecting => 'Conectando…';

  @override
  String get serverStateNoGrant => 'Todavía no tiene permiso para tu Drive';

  @override
  String get serverStateNoFolder =>
      'Todavía no sabe en qué carpeta de tu Drive escribir';

  @override
  String serverStateReady(String folder) {
    return 'Listo · escribe en «$folder» de tu Drive';
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
  String get serverPlainTitle => 'La conexión no está cifrada';

  @override
  String get serverPlainSubtitle =>
      'El token de tu cuenta se puede leer por el camino: hace falta HTTPS (Tailscale Funnel, un reverse proxy)';

  @override
  String get serverGrantTitle => 'Da tu Drive al servidor';

  @override
  String get serverGrantSubtitle =>
      'Descargará en la carpeta que lee la app, incluso con el teléfono apagado';

  @override
  String get serverUseAppFolder => 'Usar la carpeta de la app';

  @override
  String serverUseAppFolderSubtitle(String serverFolder, String appFolder) {
    return 'El servidor escribe en «$serverFolder», la app lee «$appFolder»';
  }

  @override
  String get serverUsersTitle => 'Quién puede usarlo';

  @override
  String get serverUsersOnlyYou =>
      'Solo tú. Añade la cuenta de Google de quien quieras';

  @override
  String serverUsersCount(int count) {
    return '$count cuentas, contigo incluido';
  }

  @override
  String get serverQueueWaiting => 'Cola en espera';

  @override
  String get serverQueueRestarts => 'El servidor se reanuda solo';

  @override
  String get serverJobAutomatic => 'Capítulos nuevos · en el servidor';

  @override
  String get serverJobQueued => 'En cola · en el servidor';

  @override
  String get serverOngoingTitle => 'Series en curso en el servidor';

  @override
  String serverOngoingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count que seguir',
      zero: 'Ninguna por ahora',
    );
    return '$_temp0';
  }

  @override
  String get serverOngoingCheckOff => 'revisión desactivada';

  @override
  String serverOngoingCheckAt(String clock) {
    return 'revisión a las $clock';
  }

  @override
  String serverOngoingSubtitle(String count, String check) {
    return '$count · $check. Toca para revisar ahora';
  }

  @override
  String serverSeriesKnown(int count) {
    return '$count capítulos conocidos';
  }

  @override
  String serverSeriesKnownChecked(int count, String when) {
    return '$count capítulos conocidos · revisada $when';
  }

  @override
  String get serverStopFollowing => 'Dejar de seguirla';

  @override
  String get serverInviteRemoveFailed =>
      'No pude quitar la invitación: inténtalo de nuevo.';

  @override
  String get serverCheckingNow =>
      'El servidor está revisando: los capítulos nuevos aparecen en su cola.';

  @override
  String get serverPaste => 'Pegar';

  @override
  String get serverAddressExposed =>
      'Atención: sin cifrar en una dirección pública, el token de tu cuenta se puede leer por el camino. Usa HTTPS (Tailscale Funnel, un reverse proxy) o Tailscale.';

  @override
  String get serverAddressSavedNote =>
      'La dirección viaja con la copia de seguridad y con la cuenta, como la carpeta de Drive.';

  @override
  String get serverAddressMissing =>
      'Escribe la dirección del servidor, por ejemplo http://192.168.1.20:8080.';

  @override
  String serverLinked(String name, String folder) {
    return 'Conectado a «$name»: descarga en «$folder» de tu Drive.';
  }

  @override
  String serverLinkFromInvite(String sender, String serverName) {
    return '$sender te añadió a «$serverName». Al conectarlo, el servidor descargará los manga que elijas en la carpeta de tu biblioteca de tu Drive: Google te pedirá que le permitas escribir ahí. Quien administra el servidor podrá usar ese permiso.';
  }

  @override
  String serverLinkLinked(String account) {
    return 'El servidor te reconoce como $account. Si lo desconectas y no es tuyo, también olvida el permiso sobre tu Drive y tu cola.';
  }

  @override
  String get serverSignedInAccount => 'la cuenta con la que iniciaste sesión';

  @override
  String get serverLinkNew =>
      'Escribe la dirección del servidor: el tuyo, o el que te dio quien te añadió. El servidor te reconoce por la cuenta de Google, y la primera vez le das permiso para escribir en la carpeta de tu biblioteca en Drive.';

  @override
  String get serverVerifying => 'Verificando…';

  @override
  String get serverVerifyAgain => 'Verificar de nuevo';

  @override
  String get serverVerifyAndLink => 'Verificar y conectar';

  @override
  String get serverUnlink => 'Desconectar';

  @override
  String get serverDefaultNameOwn => 'Mi Kagami Server';

  @override
  String serverDefaultNameOf(String name) {
    return 'El servidor de $name';
  }

  @override
  String get serverCommandCopied => 'Comando copiado.';

  @override
  String get serverComputerAddressMissing =>
      'Escribe la dirección del ordenador, por ejemplo http://192.168.1.20:8080.';

  @override
  String serverNotOwner(String owner) {
    return 'Ese servidor es de $owner: está conectado, pero no lo creaste tú.';
  }

  @override
  String serverReady(String name) {
    return '«$name» está listo. Añade a quien quieras desde «Quién puede usarlo».';
  }

  @override
  String get serverLibraryFolderFallback => 'la carpeta de la biblioteca';

  @override
  String serverSetupIntro(String folder) {
    return 'Hace falta un ordenador que se quede encendido —un mini PC, un NAS, una Raspberry Pi, un servidor en red— con Docker. El servidor descarga los manga y los sube a tu Drive, en «$folder», incluso con el teléfono apagado.';
  }

  @override
  String serverPrepareIntro(String signIn, String folder) {
    String _temp0 = intl.Intl.selectLogic(signIn, {
      'yes': 'primero inicias sesión con Google, luego ',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(folder, {
      'yes': 'eliges la carpeta de manga en Drive, luego ',
      'other': '',
    });
    return 'Preparo un comando que lo contiene todo: $_temp0${_temp1}Google te pide que permitas al servidor escribir en tu Drive.';
  }

  @override
  String get serverPreparing => 'Preparando…';

  @override
  String get serverGenerate => 'Generar el comando';

  @override
  String get serverStep1 =>
      'Instala Docker en el ordenador (docker.com), si aún no lo tiene.';

  @override
  String get serverStep2 =>
      'Pega este comando en su terminal. Contiene el permiso sobre tu Drive: no se lo envíes a nadie.';

  @override
  String get serverCopyCommand => 'Copiar el comando';

  @override
  String get serverStep3 =>
      'Escribe aquí la dirección del ordenador: en casa, la de la red local; desde fuera, su nombre en Tailscale o la dirección HTTPS con la que lo expones.';

  @override
  String get serverPortNote => 'El servidor responde en el puerto 8080.';

  @override
  String get serverUsersIntro =>
      'Añade la cuenta de Google de quien quieras. En su app de Kagami aparecerá la invitación: al conectar el servidor, sus descargas irán a su Drive, con su cola.';

  @override
  String get serverUserEmailInvalid =>
      'Escribe la dirección de la cuenta de Google, por ejemplo nombre@gmail.com.';

  @override
  String serverUserAdded(String email) {
    return '$email puede usar el servidor: se lo avisa su app.';
  }

  @override
  String serverRemoveTitle(String email) {
    return '¿Quitar a $email?';
  }

  @override
  String get serverRemoveBody =>
      'Ya no podrá usar el servidor. Su cola y el permiso sobre su Drive se borran; lo que ya está en su Drive se queda.';

  @override
  String get serverCancel => 'Cancelar';

  @override
  String get serverRemove => 'Quitar';

  @override
  String get serverAdd => 'Añadir';

  @override
  String get serverOwnerYou => 'Tú, el propietario';

  @override
  String get serverConnected => 'Ha conectado el servidor';

  @override
  String get serverInvitedPending =>
      'Invitado, aún no ha conectado el servidor';

  @override
  String get setupIntro =>
      'Lee la carpeta de manga que la sincronización deja en el teléfono, o la misma biblioteca directamente desde Google Drive, sin traerla toda aquí.';

  @override
  String get setupAccessTitle => 'Acceso a los archivos';

  @override
  String get setupAccessBody =>
      'La carpeta está fuera del espacio privado de la app y contiene decenas de miles de imágenes: Kagami necesita leerlas directamente. Solo escribe las copias de los datos en la subcarpeta reading/ de la biblioteca y, si se lo pides, los capítulos que descargas de Drive.';

  @override
  String get setupGrantAccess => 'Conceder acceso';

  @override
  String get setupFolderTitle => 'La carpeta';

  @override
  String get setupFolderBody =>
      'Indica la carpeta sincronizada por FolderSync: la que contiene library.json y una subcarpeta por serie.';

  @override
  String get setupChooseFolder => 'Elegir la carpeta';

  @override
  String get setupOr => 'o';

  @override
  String get setupDriveTitle => 'Google Drive';

  @override
  String get setupDriveBody =>
      'Se inicia sesión con Google y se elige la carpeta de la biblioteca en Drive: las páginas llegan mientras se lee, y los capítulos que quieres tener siempre a mano se descargan con un toque. No hace falta acceso a los archivos del teléfono.';

  @override
  String get setupReadFromDrive => 'Leer desde Google Drive';

  @override
  String get setupLibraryProblemTitle => 'Biblioteca ilegible';

  @override
  String get setupChangeFolder => 'Cambiar carpeta';

  @override
  String get driveFolderSheetTitle => 'Carpeta en Drive';

  @override
  String get driveDestinationTitle => '¿Dónde guardo los manga?';

  @override
  String get driveDestinationBody =>
      'No hay una carpeta de manga en el teléfono. En una carpeta, los capítulos descargados se conservan aunque se desinstale la app, y Kagami los lee junto con los que ya están. En el espacio de la app no hace falta ningún permiso, pero se van con ella.';

  @override
  String get driveChooseFolder => 'Elegir una carpeta';

  @override
  String get driveInAppSpace => 'En el espacio de la app';

  @override
  String get driveMyDrive => 'Mi unidad';

  @override
  String get driveSharedWithMe => 'Compartidos conmigo';

  @override
  String get driveBack => 'Atrás';

  @override
  String get driveNoResponse => 'Drive no responde';

  @override
  String get driveRetry => 'Reintentar';

  @override
  String get driveIsLibrary => 'Contiene library.json: es una biblioteca';

  @override
  String get driveNotLibrary =>
      'No contiene library.json: la biblioteca es la carpeta que lo tiene';

  @override
  String get driveUseFolder => 'Usar esta carpeta';

  @override
  String get driveNoFolders => 'Ninguna carpeta aquí';

  @override
  String get driveNoticeAuthRequired =>
      'Kagami todavía no tiene permiso para leer Google Drive';

  @override
  String get driveAuthorize => 'Autorizar';

  @override
  String get driveSignIn => 'Iniciar sesión';

  @override
  String get driveNoticeOffline =>
      'Estás sin conexión: se leen los capítulos del teléfono y las páginas de Drive ya descargadas. Lo demás vuelve solo con la red';

  @override
  String driveNoticeError(String message) {
    return 'Drive: $message. Se ve lo que hay en el teléfono';
  }

  @override
  String get syncSummaryOff => 'Desactivada';

  @override
  String get syncSummaryDownload => 'De Drive al teléfono';

  @override
  String get syncSummaryUpload => 'Del teléfono a Drive';

  @override
  String get syncSummaryBoth => 'En ambos sentidos';

  @override
  String syncSummaryManual(String direction) {
    return '$direction, manual';
  }

  @override
  String syncSummaryDaily(String direction, String time) {
    return '$direction, cada día a las $time';
  }

  @override
  String get syncTitle => 'Sincronización';

  @override
  String get syncIntro =>
      'Mantiene iguales la carpeta de manga del teléfono y la de Drive, sin FolderSync. Si todavía lo usas en esta carpeta, apágalo: dos sincronizaciones sobre los mismos archivos se estorban.';

  @override
  String get syncFolders => 'Carpetas';

  @override
  String get syncOnPhone => 'En el teléfono';

  @override
  String get syncNoFolderChosen => 'Ninguna carpeta elegida';

  @override
  String get syncOnDrive => 'En Drive';

  @override
  String get syncDriveNotConnected => 'Drive no está conectado';

  @override
  String get syncDirection => 'Sentido';

  @override
  String get syncDirectionOff => 'Desactivada';

  @override
  String get syncDirectionFromDrive => 'Desde Drive';

  @override
  String get syncDirectionToDrive => 'Hacia Drive';

  @override
  String get syncDirectionBoth => 'Ambos';

  @override
  String get syncDescOff =>
      'Nada se mueve solo. La biblioteca de Drive se lee igualmente, y «Descargar» funciona como siempre.';

  @override
  String get syncDescDownload =>
      'Lo que llega a Drive baja al teléfono. Del teléfono no sube nada.';

  @override
  String get syncDescUpload =>
      'Lo que hay en el teléfono sube a Drive, por ejemplo las copias de los datos en reading/backup. Los índices de la biblioteca siguen siendo los del servidor.';

  @override
  String get syncDescBoth =>
      'Lo que cambia en un lado llega al otro; si cambió en los dos, gana lo más reciente. Los índices de la biblioteca solo bajan: son del servidor.';

  @override
  String get syncDeletions => 'Propagar los borrados';

  @override
  String get syncDeletionsDownload =>
      'Quita del teléfono lo que desaparece de Drive';

  @override
  String get syncDeletionsUpload =>
      'Mueve a la papelera de Drive lo que quitas del teléfono';

  @override
  String get syncDeletionsBoth =>
      'De un lado al otro; en Drive, solo a la papelera';

  @override
  String get syncDeletionsOnNote =>
      '«Liberar espacio» quita los capítulos leídos también de Drive, en la siguiente pasada.';

  @override
  String get syncDeletionsOffNote =>
      'Un archivo quitado de un lado se queda en el otro y no vuelve: «Liberar espacio» libera el teléfono y deja los capítulos en Drive.';

  @override
  String get syncDaily => 'Cada día';

  @override
  String get syncScheduled => 'Sincronización programada';

  @override
  String get syncManualOnly => 'Solo manual';

  @override
  String syncAtTime(String time) {
    return 'A las $time, incluso con la app cerrada';
  }

  @override
  String get syncTime => 'Hora';

  @override
  String get syncWifiOnly => 'Solo con Wi-Fi';

  @override
  String get syncWifiOnlyOn => 'Espera una red que no se pague por consumo';

  @override
  String get syncWifiOnlyOff => 'También con datos móviles';

  @override
  String get syncScheduleNote =>
      'Android decide el momento exacto: si a la hora elegida no hay red, la pasada empieza en cuanto vuelva.';

  @override
  String get syncNow => 'Ahora';

  @override
  String get syncTimePickerHelp => 'Hora de la sincronización';

  @override
  String get syncRunNow => 'Sincronizar ahora';

  @override
  String get syncRunNowReady =>
      'Puedes seguir leyendo: las copias avanzan solas';

  @override
  String get syncRunNowNotReady =>
      'Hacen falta la carpeta del teléfono y la de Drive';

  @override
  String get syncPhaseListing => 'Mirando qué hay en Drive…';

  @override
  String get syncPhaseComparing => 'Comparando con el teléfono…';

  @override
  String get syncPhaseNothing => 'Nada que copiar';

  @override
  String syncPhaseFiles(int done, int total) {
    return 'Archivo $done de $total';
  }

  @override
  String get syncStop => 'Detener';

  @override
  String get syncNever => 'Nunca sincronizada';

  @override
  String get syncNeverNote =>
      'La primera pasada en una carpeta ya llena es rápida: los archivos iguales se reconocen por el tamaño';

  @override
  String syncLastScheduled(String date, String time) {
    return 'Última, programada: $date a las $time';
  }

  @override
  String syncLastManual(String date, String time) {
    return 'Última, manual: $date a las $time';
  }

  @override
  String syncOutcomeDownloaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count descargados',
      one: '$count descargado',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeUploaded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subidos',
      one: '$count subido',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeDeletedLocal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quitados del teléfono',
      one: '$count quitado del teléfono',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeTrashed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count en la papelera de Drive',
      one: '$count en la papelera de Drive',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fallidos, se reintentan',
      one: '$count fallido, se reintenta',
    );
    return '$_temp0';
  }

  @override
  String syncOutcomeErrorSoFar(String error, String done) {
    return '$error. Hasta ahí: $done';
  }

  @override
  String get syncOutcomeAligned => 'Ya estaba todo al día';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsThemeDark => 'Oscuro';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeSystem => 'Igual que el sistema';

  @override
  String get settingsLibrary => 'Biblioteca';

  @override
  String get settingsFolder => 'Carpeta';

  @override
  String get settingsNoFolder => 'Ninguna carpeta elegida';

  @override
  String get settingsReloadIndexes => 'Releer los índices';

  @override
  String get settingsReloadIndexesNote =>
      'Hazlo cuando la sincronización acabe de traer cosas nuevas';

  @override
  String get settingsIndexesReloaded => 'Índices releídos';

  @override
  String get settingsGoogleDrive => 'Google Drive';

  @override
  String get settingsReading => 'Lectura';

  @override
  String get settingsAccount => 'Cuenta';

  @override
  String get settingsData => 'Datos';

  @override
  String get settingsAbout => 'Información';

  @override
  String get settingsAutoBackup => 'Copia automática en la biblioteca';

  @override
  String get settingsAutoBackupNote =>
      'Una vez al día en reading/backup/, que la sincronización sube a Drive junto con los manga';

  @override
  String get settingsExport => 'Exportar los datos';

  @override
  String get settingsExportNote =>
      'Estado, notas, historial, colecciones y marcadores en un archivo';

  @override
  String get settingsExportDialog => 'Dónde guardar la copia de seguridad';

  @override
  String get settingsExportCancelled => 'Exportación cancelada';

  @override
  String get settingsExportSaved => 'Copia de seguridad guardada';

  @override
  String get settingsImport => 'Importar de una copia de seguridad';

  @override
  String get settingsImportNote => 'Dice qué contiene antes de tocar nada';

  @override
  String get settingsImportDialog => 'Elige una copia de seguridad de Kagami';

  @override
  String get settingsImportInvalid => 'No es una copia de seguridad de Kagami';

  @override
  String get settingsImportSheetTitle => '¿Importar esta copia de seguridad?';

  @override
  String get settingsImportSeries => 'Series';

  @override
  String get settingsImportRead => 'Leídos';

  @override
  String get settingsImportCollections => 'Colecciones';

  @override
  String settingsImportExplain(String date) {
    return 'Hecha el $date. Fusionar conserva lo que ya tienes y añade: los capítulos leídos se suman y, en lo demás, gana el registro más reciente. Reemplazar borra los datos de este dispositivo.';
  }

  @override
  String get settingsImportExplainUnknownDate =>
      'Hecha en una fecha desconocida. Fusionar conserva lo que ya tienes y añade: los capítulos leídos se suman y, en lo demás, gana el registro más reciente. Reemplazar borra los datos de este dispositivo.';

  @override
  String get settingsImportMerge => 'Fusionar';

  @override
  String get settingsImportReplace => 'Reemplazar';

  @override
  String get settingsImportDone => 'Datos importados';

  @override
  String get settingsImportFailed => 'No se pudo importar';

  @override
  String get settingsWipe => 'Eliminar los datos personales';

  @override
  String get settingsWipeNote =>
      'Estado, notas, historial y colecciones. Los manga no se tocan';

  @override
  String get settingsWipeSheetTitle => '¿Eliminar todos los datos personales?';

  @override
  String get settingsWipeExplain =>
      'Desaparecen el estado, las notas, los favoritos, los capítulos leídos, el historial, las sesiones, las colecciones y los marcadores de este dispositivo. Los manga y los índices de la biblioteca no se tocan.\n\nSi no tienes una copia de seguridad, esta es la última oportunidad de hacerla.';

  @override
  String get settingsWipeConfirm => 'Eliminar todo';

  @override
  String get settingsWipeDone => 'Datos personales eliminados';

  @override
  String get settingsDriveConnect => 'Conectar Google Drive';

  @override
  String get settingsDriveConnectNote =>
      'Lee la biblioteca desde Drive sin traerla toda al teléfono, y descarga solo lo que eliges';

  @override
  String get settingsDriveFolder => 'Carpeta en Drive';

  @override
  String get settingsDriveSync => 'Sincronización de la carpeta';

  @override
  String get settingsDriveDownloadsGo => 'Los capítulos descargados van';

  @override
  String settingsDriveDownloadsFolder(String path) {
    return 'A la carpeta de la biblioteca: $path';
  }

  @override
  String get settingsDriveDownloadsApp =>
      'Al espacio de la app: se van al desinstalarla';

  @override
  String get settingsDriveDownloadsAsk => 'Se pregunta en la primera descarga';

  @override
  String get settingsDriveCache => 'Páginas leídas de Drive';

  @override
  String settingsDriveCacheNote(String used, String limit) {
    return '$used en caché, como máximo $limit. Se releen sin red';
  }

  @override
  String get settingsDriveCacheLimitTitle => 'Espacio para las páginas';

  @override
  String get settingsDriveClearCache => 'Vaciar la caché';

  @override
  String get settingsDriveClearCacheNote =>
      'Los capítulos descargados no se tocan';

  @override
  String get settingsDriveDisconnect => 'Desconectar Drive';

  @override
  String get settingsDriveDisconnectNote =>
      'La biblioteca vuelve a ser la carpeta del teléfono. Los capítulos descargados se quedan';

  @override
  String get settingsAccountUnavailable => 'Cuenta no disponible aquí';

  @override
  String get settingsAccountUnavailableNote =>
      'Esta versión no tiene Firebase: los datos se quedan donde están, en el dispositivo';

  @override
  String get settingsAccountSignIn => 'Iniciar sesión con Google';

  @override
  String get settingsAccountSignInNote =>
      'Notas, estado, capítulos leídos, historial y colecciones siguen a la cuenta en lugar del teléfono';

  @override
  String get settingsAccountSyncNow => 'Sincronizar ahora';

  @override
  String get settingsAccountNeverSynced =>
      'Nunca sincronizado en este teléfono';

  @override
  String settingsAccountLastSync(String date, String time) {
    return 'La última vez, el $date a las $time';
  }

  @override
  String get settingsAccountSignOut => 'Cerrar sesión';

  @override
  String get settingsAccountSignOutNote =>
      'Sube la última lectura y luego cierra la sesión';

  @override
  String get settingsAccountForget => 'Dejar de guardar una copia';

  @override
  String get settingsAccountForgetNote =>
      'Borra los datos de la cuenta. Los de este teléfono se quedan donde están';

  @override
  String get settingsAccountErrorNote =>
      'Los datos de este teléfono no se han tocado';

  @override
  String get settingsAccountForgetSheetTitle =>
      '¿Borrar los datos de la cuenta?';

  @override
  String get settingsAccountForgetExplain =>
      'Desaparece la copia guardada para ti y se cierra la sesión. El estado, las notas, el historial y las colecciones de este teléfono se quedan donde están, pero desde otro teléfono ya no se verán.';

  @override
  String get settingsAccountForgetConfirm => 'Borrar de la cuenta';

  @override
  String get settingsReaderDirection => 'Sentido en modo paginado';

  @override
  String get settingsReaderBackground => 'Fondo';

  @override
  String get settingsReaderKeepAwake => 'Mantener la pantalla encendida';

  @override
  String get settingsReaderProgressBar => 'Barra de avance';

  @override
  String get settingsProbe => 'Medir la fluidez';

  @override
  String get settingsProbeNote =>
      'En el lector, arriba: fotogramas lentos y saltados, de dónde llegan las franjas, GC. Un toque sobre los números los pone a cero';

  @override
  String get settingsProbeInfo1 =>
      'Muestra en el lector, arriba a la izquierda, un recuadro de números sobre lo fluida que es la lectura. Sirve para entender por qué el desplazamiento se entrecorta: no cambia nada de cómo se lee y cuesta muy poco.';

  @override
  String get settingsProbeInfo2 =>
      'El número que más cuenta es «saltados»: los fotogramas que faltan mientras la página se desplaza. Cada uno es un pequeño tirón que se nota. «Tardíos» y «Lentos» indican si la app estaba ocupada, «GC Android» si el sistema estaba liberando memoria.';

  @override
  String get settingsProbeInfo3 =>
      '«Teselas», «enteras», «del teléfono» y «Nativas» indican de dónde llegó cada trozo de página: las tres primeras son las vías ligeras, la última es el recorte hecho al momento, que es la que pesa.';

  @override
  String get settingsProbeInfo4 =>
      'Un toque sobre el recuadro pone los números a cero, para medir desde un punto preciso del capítulo. Al reabrir la app la medición se apaga sola.';

  @override
  String get settingsTexture => 'Franjas nativas como textura';

  @override
  String get settingsTextureNote =>
      'Prueba: las páginas que aún hay que cortar llegan a la GPU sin pasar por la interfaz. Se apaga al reabrir la app';

  @override
  String get settingsTextureInfo1 =>
      'Las páginas muy altas de un webtoon se leen por trozos. Casi siempre los trozos ya están listos: cortados por el archivo en el servidor, o por el teléfono la primera vez que se abre el capítulo. Cuando no lo están, los recorta al momento el decodificador de Android.';

  @override
  String get settingsTextureInfo2 =>
      'Normalmente los píxeles de esos trozos pasan por la app antes de llegar a la pantalla. Con esta opción van directamente a la tarjeta gráfica: la app tiene menos trabajo mientras se desplaza, y el desplazamiento puede entrecortarse menos. La calidad de la imagen no cambia.';

  @override
  String get settingsTextureInfo3 =>
      'Es una prueba: es una forma de dibujar nueva, aún no verificada en este teléfono. Si ves páginas negras, rayas o parpadeos, apágala. Si el teléfono no la admite, la app vuelve sola al modo normal.';

  @override
  String get settingsTextureInfo4 =>
      'En los capítulos ya cortados en teselas no cambia nada, porque ahí este camino no se usa. Al reabrir la app se apaga sola.';

  @override
  String get settingsWhatItDoes => 'Qué hace';

  @override
  String get settingsBackupsTitle => 'Copias en la biblioteca';

  @override
  String get settingsBackupsNone =>
      'Todavía no hay copias: la primera se hace en la próxima apertura';

  @override
  String settingsBackupsLatest(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copias, la última $name',
      one: '1 copia, la última $name',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupNow => 'Hacer una copia ahora';

  @override
  String settingsBackupWritten(String path) {
    return 'Copia escrita en $path';
  }

  @override
  String settingsVersion(String version, String build) {
    return 'versión $version ($build)';
  }

  @override
  String get settingsTagline => 'lector para archivos MALF locales';

  @override
  String get librarySortUpdated => 'Actualizadas recientemente';

  @override
  String get librarySortTitle => 'Título';

  @override
  String get librarySortProgress => 'Avance';

  @override
  String get librarySortAdded => 'Añadidas recientemente';

  @override
  String get librarySortLastRead => 'Leídas recientemente';

  @override
  String get librarySortUnread => 'Por leer';

  @override
  String get librarySortRating => 'Nota';

  @override
  String get librarySortChapters => 'Número de capítulos';

  @override
  String get librarySortShuffle => 'Al azar';

  @override
  String get libraryDisplayComfortable => 'Cuadrícula cómoda';

  @override
  String get libraryDisplayCompact => 'Cuadrícula compacta';

  @override
  String get libraryDisplayList => 'Lista';

  @override
  String get libraryDisplayDetailed => 'Lista detallada';

  @override
  String get libraryAutoReading => 'Leyendo';

  @override
  String get libraryAutoFresh => 'Novedades';

  @override
  String get libraryAutoFavorites => 'Favoritos';

  @override
  String get libraryAutoPlanned => 'Por empezar';

  @override
  String get libraryAutoFinished => 'Terminadas';

  @override
  String libraryRowChapters(int count) {
    return '$count cap.';
  }

  @override
  String libraryRowUnread(int count) {
    return '$count por leer';
  }

  @override
  String get libraryNoMatchTitle => 'Sin coincidencias';

  @override
  String get libraryNoMatchMessage =>
      'Ninguna serie coincide con la búsqueda y los filtros elegidos.';

  @override
  String get libraryEmptyTitle => 'Biblioteca vacía';

  @override
  String get libraryEmptyMessage =>
      'La biblioteca no contiene series. Si debería, revisa la sincronización de la carpeta.';

  @override
  String get libraryClearFilters => 'Quitar los filtros';

  @override
  String get libraryTitle => 'Biblioteca';

  @override
  String get libraryCancelSelection => 'Cancelar selección';

  @override
  String librarySelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seleccionadas',
      one: '1 seleccionada',
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
  String get libraryMarkAllRead => 'Marcar todo como leído';

  @override
  String get libraryMarkAllUnread => 'Marcar todo como por leer';

  @override
  String get libraryStatus => 'Estado';

  @override
  String get libraryFavorites => 'Favoritos';

  @override
  String get libraryAddToCollection => 'Añadir a una colección';

  @override
  String libraryStatusOfSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Estado de $count series',
      one: 'Estado de 1 serie',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedRead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series marcadas como leídas',
      one: '1 serie marcada como leída',
    );
    return '$_temp0';
  }

  @override
  String libraryMarkedUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series vueltas a por leer',
      one: '1 serie vuelta a por leer',
    );
    return '$_temp0';
  }

  @override
  String get librarySearchHint => 'Título, autor, tag:…';

  @override
  String get libraryLayout => 'Disposición';

  @override
  String get libraryFiltersAndSort => 'Filtros y orden';

  @override
  String get libraryReset => 'Restablecer';

  @override
  String get librarySortSection => 'Ordenar';

  @override
  String get libraryShowOnly => 'Mostrar solo';

  @override
  String get libraryOnlyUnread => 'Con capítulos por leer';

  @override
  String get libraryOnlyStarted => 'Empezadas';

  @override
  String get libraryOnlyNew => 'Con capítulos nuevos';

  @override
  String get libraryOnlyFavorite => 'Favoritas';

  @override
  String get libraryMinRating => 'Nota mínima';

  @override
  String get libraryRelease => 'Publicación';

  @override
  String get libraryGenres => 'Géneros';

  @override
  String get libraryTriHint => 'Un toque lo exige, dos lo excluyen';

  @override
  String get libraryTags => 'Etiquetas';

  @override
  String get libraryAuthors => 'Autores';

  @override
  String get homeEmptyTitle => 'Biblioteca vacía';

  @override
  String get homeEmptyMessage =>
      'Nada que explorar: la carpeta todavía no contiene ninguna serie.';

  @override
  String get homeToStart => 'Por empezar';

  @override
  String get homeSimilarTitle => 'Por qué lees lo que lees';

  @override
  String get homeSimilarSubtitle =>
      'Aún sin abrir, con los géneros que te gustan';

  @override
  String get homeRecentlyArrived => 'Llegadas recientemente';

  @override
  String get homeLeftHalfway => 'Dejadas a medias';

  @override
  String get homeLeftHalfwaySubtitle => 'En pausa y abandonadas';

  @override
  String get homeCaughtUpTitle => 'Estás al día';

  @override
  String get homeCaughtUpMessage =>
      'Con todo lo que está sincronizado. El próximo capítulo llegará con la carpeta.';

  @override
  String get homeRandomSeries => 'Una al azar';

  @override
  String get homeReloadLibrary => 'Releer la biblioteca';

  @override
  String get homeGreetingNight => 'Madrugada';

  @override
  String get homeGreetingMorning => 'Buenos días';

  @override
  String get homeGreetingAfternoon => 'Buenas tardes';

  @override
  String get homeGreetingEvening => 'Buenas noches';

  @override
  String get homeStatRead => 'Leídos';

  @override
  String get homeStatReadCaption => 'capítulos en total';

  @override
  String get homeStatUnread => 'Por leer';

  @override
  String get homeStatUnreadCaption => 'en el teléfono';

  @override
  String get homeStatStreak => 'Seguidos';

  @override
  String homeStatStreakCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'días',
      one: 'día',
    );
    return '$_temp0';
  }

  @override
  String get homeResume => 'Retomar';

  @override
  String get homeNextChapter => 'Capítulo siguiente';

  @override
  String get homeRead => 'Leer';

  @override
  String get homeUpdates => 'Novedades';

  @override
  String get homeUpdatesSubtitle => 'Capítulos sincronizados y aún sin leer';

  @override
  String homeLatestChapter(String number) {
    return 'cap. $number';
  }

  @override
  String get homeAgoToday => 'hoy';

  @override
  String get homeAgoYesterday => 'ayer';

  @override
  String homeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count días',
      one: 'hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String homeAgoWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count semanas',
      one: 'hace 1 semana',
    );
    return '$_temp0';
  }

  @override
  String homeAgoMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count meses',
      one: 'hace 1 mes',
    );
    return '$_temp0';
  }

  @override
  String homeAgoYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count años',
      one: 'hace 1 año',
    );
    return '$_temp0';
  }

  @override
  String get collectionsTitle => 'Colecciones';

  @override
  String get collectionsNew => 'Nueva';

  @override
  String get collectionsAutomatic => 'Automáticas';

  @override
  String get collectionsYours => 'Tus colecciones';

  @override
  String get collectionsNoneTitle => 'Ninguna colección';

  @override
  String get collectionsNoneMessage =>
      'Sirven para dar estructura a una biblioteca que crece sola: una serie puede estar en varias colecciones y el orden lo eliges tú.';

  @override
  String collectionsSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series',
      one: '1 serie',
    );
    return '$_temp0';
  }

  @override
  String get collectionsEdit => 'Editar';

  @override
  String get collectionsRenameRecolor => 'Renombrar y cambiar color';

  @override
  String get collectionsDelete => 'Eliminar la colección';

  @override
  String get collectionsNotFound => 'Colección no encontrada.';

  @override
  String get collectionsDone => 'Listo';

  @override
  String get collectionsReorder => 'Reordenar';

  @override
  String get collectionsEmptyTitle => 'Colección vacía';

  @override
  String get collectionsEmptyMessage =>
      'Se añade una serie desde su ficha, o manteniendo pulsada una portada en la biblioteca.';

  @override
  String get collectionsRemoveFrom => 'Quitar de la colección';

  @override
  String get shellDataUnreadableTitle => 'Datos de la app ilegibles';

  @override
  String get shellRetry => 'Reintentar';

  @override
  String get shellTabHome => 'Inicio';

  @override
  String get shellTabLibrary => 'Biblioteca';

  @override
  String get shellTabCollections => 'Colecciones';

  @override
  String get shellTabMore => 'Más';

  @override
  String get moreTitle => 'Más';

  @override
  String get moreSectionLibrary => 'Biblioteca';

  @override
  String get moreSectionReading => 'Tu lectura';

  @override
  String get moreSectionPrivacy => 'Privacidad';

  @override
  String get moreSectionApp => 'App';

  @override
  String get moreDownload => 'Descargar un manga';

  @override
  String get moreDownloadSubtitle => 'Busca un título o pega un enlace';

  @override
  String get moreHistory => 'Historial';

  @override
  String get moreHistorySubtitle => 'Qué has leído y cuándo';

  @override
  String get moreStatistics => 'Estadísticas';

  @override
  String get moreStatisticsSubtitle => 'Cuánto lees, qué lees, cuándo';

  @override
  String get moreIncognito => 'Lectura en incógnito';

  @override
  String get moreIncognitoSubtitle =>
      'No registra posición, capítulos terminados ni tiempo de lectura';

  @override
  String get moreSettings => 'Ajustes';

  @override
  String get moreSettingsSubtitle =>
      'Apariencia, biblioteca, lectura, copia de seguridad';

  @override
  String get historyTitle => 'Historial';

  @override
  String get historyIncognitoOn => 'Incógnito activado';

  @override
  String get historyIncognitoOff => 'Leer en incógnito';

  @override
  String get historyClear => 'Vaciar';

  @override
  String get historyUnreadable => 'Historial ilegible';

  @override
  String get historyEmptyTitle => 'Nada leído, por ahora';

  @override
  String get historyEmptyMessage =>
      'Cada capítulo terminado aparecerá aquí con su fecha.';

  @override
  String get historyClearTitle => '¿Vaciar el historial?';

  @override
  String get historyClearMessage =>
      'Las fechas de lectura y el tiempo dedicado a leer desaparecen, y con ellos las estadísticas que se derivan. Los capítulos vuelven a por leer.';

  @override
  String get historyIncognitoBanner =>
      'En incógnito: no se registran posición, capítulos terminados ni tiempo de lectura.';

  @override
  String get historyToday => 'Hoy';

  @override
  String get historyYesterday => 'Ayer';

  @override
  String get historyReread => 'Releer';

  @override
  String get historyRemove => 'Quitar del historial';

  @override
  String get originLocal => 'En el teléfono';

  @override
  String get originDrive => 'En Drive';

  @override
  String get originMixed => 'En el teléfono, y otros capítulos en Drive';

  @override
  String get coverNoChapters => 'Ningún capítulo descargado';

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
    return '$_temp0 · $unread por leer';
  }

  @override
  String coverNewChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos nuevos',
      one: '1 capítulo nuevo',
    );
    return '$_temp0';
  }

  @override
  String coverUnread(int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '$unread capítulos por leer',
      one: '1 capítulo por leer',
    );
    return '$_temp0';
  }

  @override
  String coverUnreadFresh(int unread, int fresh) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '$unread capítulos por leer',
      one: '1 capítulo por leer',
    );
    String _temp1 = intl.Intl.pluralLogic(
      fresh,
      locale: localeName,
      other: '$fresh nuevos',
      one: '1 nuevo',
    );
    return '$_temp0, de los cuales $_temp1';
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
  String get kitClose => 'Cerrar';

  @override
  String get collectionSheetTitle => 'Colecciones';

  @override
  String collectionSheetTitleMany(int count) {
    return 'Colecciones de $count series';
  }

  @override
  String get collectionSheetNew => 'Nueva';

  @override
  String get collectionSheetEmptyTitle => 'Ninguna colección';

  @override
  String get collectionSheetEmptyMessage =>
      'Sirven para dar estructura a una biblioteca que crece sola.';

  @override
  String collectionSheetSeriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series',
      one: '1 serie',
    );
    return '$_temp0';
  }

  @override
  String get collectionSheetCreateTitle => 'Nueva colección';

  @override
  String get collectionSheetEditTitle => 'Editar colección';

  @override
  String get collectionSheetNameHint => 'Nombre';

  @override
  String get collectionSheetColor => 'Color';

  @override
  String get collectionSheetCreate => 'Crear';

  @override
  String get collectionSheetSave => 'Guardar';

  @override
  String get cleanupTitle => '¿Liberar espacio?';

  @override
  String get cleanupSyncBusy =>
      'Hay una sincronización en curso: inténtalo de nuevo cuando termine';

  @override
  String cleanupNotAllDeleted(String error) {
    return 'No todo se borró: $error';
  }

  @override
  String cleanupDriveError(String error) {
    return 'Drive: $error. Lo que ya se quitó, quitado queda';
  }

  @override
  String cleanupFreed(String size) {
    return 'Liberados $size';
  }

  @override
  String get cleanupNeedsNetwork => 'Para quitar de Drive hace falta red';

  @override
  String cleanupIntroDrive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos ya leídos siguen en Drive.',
      one: 'Un capítulo ya leído sigue en Drive.',
    );
    return '$_temp0';
  }

  @override
  String cleanupIntroPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count capítulos ya leídos siguen ocupando espacio en el teléfono.',
      one: 'Un capítulo ya leído sigue ocupando espacio en el teléfono.',
    );
    return '$_temp0';
  }

  @override
  String get cleanupPhoneChapters => 'Capítulos en el teléfono';

  @override
  String get cleanupDriveCache => 'Caché de Drive';

  @override
  String get cleanupDriveChapters => 'Capítulos en Drive';

  @override
  String cleanupApproxSize(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos',
      one: '1 capítulo',
    );
    return '$_temp0 · unos $size';
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
    return '$_temp0 · unos $size · a la papelera';
  }

  @override
  String get cleanupQuiet => 'No volver a preguntar por esta serie';

  @override
  String get cleanupWarnNotOnDrive =>
      'Esta serie no está en Drive: los capítulos borrados no se podrán volver a leer hasta que la sincronización los traiga de nuevo.';

  @override
  String get cleanupWarnGoneEverywhere =>
      'No quedarán ni en el teléfono ni en Drive.';

  @override
  String get cleanupWarnStaysOnDrive =>
      'Los capítulos se quedan en Drive y se vuelven a leer desde allí.';

  @override
  String get cleanupWarnTrash =>
      'Desde la papelera de Drive se recuperan durante treinta días. El índice del servidor todavía los lista: si el servidor los vuelve a subir, se vuelven a leer desde Drive.';

  @override
  String get cleanupDelete => 'Eliminar';

  @override
  String get cleanupNotNow => 'Ahora no';

  @override
  String get cleanupSyncWarnExternal =>
      'Si FolderSync sincroniza la carpeta en ambos sentidos, el borrado puede llegar también a Drive; si solo descarga, los capítulos pueden volver en la siguiente pasada.';

  @override
  String get cleanupSyncWarnOwn =>
      'La sincronización respeta esta elección: lo que quitas de un lado no vuelve ni desaparece del otro, incluso con los borrados propagados.';

  @override
  String get statsRangeMonth => '30 días';

  @override
  String get statsRangeQuarter => '3 meses';

  @override
  String get statsRangeYear => 'Un año';

  @override
  String get statsTitle => 'Estadísticas';

  @override
  String get statsUnavailable => 'No se pueden calcular las estadísticas';

  @override
  String get statsChaptersRead => 'capítulos leídos';

  @override
  String get statsSeriesInLibrary => 'series en la biblioteca';

  @override
  String statsMinutes(int count) {
    return '$count min';
  }

  @override
  String statsHours(int count) {
    return '$count h';
  }

  @override
  String get statsReadingTime => 'tiempo de lectura';

  @override
  String get statsReadingTimeHint => 'medido mientras lees';

  @override
  String get statsPagesSeen => 'páginas vistas';

  @override
  String get statsStreak => 'días seguidos';

  @override
  String statsStreakRecord(int count) {
    return 'récord: $count';
  }

  @override
  String get statsAverageRating => 'nota media';

  @override
  String statsRatedSeries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count series con nota',
      one: '1 serie con nota',
    );
    return '$_temp0';
  }

  @override
  String get statsChaptersOverTime => 'Capítulos leídos';

  @override
  String get statsPerWeek => 'por semana';

  @override
  String get statsPerDay => 'por día';

  @override
  String get statsActivityTitle => 'Cuándo lees';

  @override
  String get statsActivitySubtitle =>
      'un cuadrito por día, en los últimos seis meses';

  @override
  String get statsShelfTitle => 'La biblioteca por estado';

  @override
  String statsGenreOthers(int count) {
    return '$count más';
  }

  @override
  String get statsGenresTitle => 'Géneros que lees';

  @override
  String get statsGenresSubtitle => 'sobre las series que has empezado';

  @override
  String get statsRatingsTitle => 'Cómo puntúas';

  @override
  String get statsRatingsSubtitle => 'cuántas series por cada nota';

  @override
  String get statsTopSeries => 'Series más leídas';

  @override
  String get statsShapeTitle => 'Cómo es la biblioteca';

  @override
  String get statsSyncedChapters => 'capítulos sincronizados';

  @override
  String get statsStillUnread => 'aún por leer';

  @override
  String get statsOngoingSeries => 'series en curso';

  @override
  String statsAnnouncedMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos anunciados y no descargados',
      one: '1 capítulo anunciado y no descargado',
    );
    return '$_temp0';
  }

  @override
  String get statsBytesOnPhone => 'ocupados en el teléfono';

  @override
  String get statsNoHistory =>
      'Nada leído en este periodo. El historial empieza desde que la app comenzó a registrarlo.';

  @override
  String get dataDriveNotLinked => 'Drive no está conectado';

  @override
  String get dataChapterNotOnDrive => 'Capítulo no encontrado en Drive';

  @override
  String get dataChapterNoPagesOnDrive =>
      'El capítulo no tiene páginas en Drive';

  @override
  String get dataPageNotOnDrive => 'Página no encontrada en Drive';

  @override
  String get dataPrefetchCancelled => 'Precarga cancelada';

  @override
  String get dataDriveAccessDenied => 'Google no concedió el acceso a Drive';

  @override
  String get dataDriveOfflineNeverOpened =>
      'Sin conexión, y la biblioteca de Drive nunca se ha abierto en este teléfono';

  @override
  String get dataDriveSignedOut =>
      'Inicia sesión con Google para leer la biblioteca en Drive';

  @override
  String get dataSyncMissingFolderOrDirection =>
      'Falta la carpeta o el sentido';

  @override
  String get dataSyncFailed => 'La sincronización falló';

  @override
  String get dataSyncFolderUnreadable =>
      'La carpeta del teléfono no se puede leer';

  @override
  String get dataSyncBusy => 'Ya hay una sincronización en curso';

  @override
  String get dataSyncCancelled => 'Sincronización interrumpida';

  @override
  String get dataSyncDirectionDownload => 'Desde Drive';

  @override
  String get dataSyncDirectionUpload => 'Hacia Drive';

  @override
  String get dataSyncDirectionBoth => 'Ambos';

  @override
  String dataServerInviteTitle(String sender) {
    return '$sender te dio acceso a su servidor';
  }

  @override
  String dataServerInviteText(String serverName) {
    return 'Conecta «$serverName» y descargará los manga en tu Drive, incluso con el teléfono apagado.';
  }

  @override
  String get dataServerSignInRequired =>
      'Inicia sesión con Google para usar el servidor.';

  @override
  String get dataServerNotLinked => 'Ningún servidor conectado.';

  @override
  String dataServerUserNotNotified(String email, String url) {
    return '$email puede usar el servidor, pero no pude avisarle: envíale tú la dirección $url.';
  }

  @override
  String get dataPickLibraryFolderTitle =>
      'Elige la carpeta de la biblioteca de manga';

  @override
  String get dataCloudSignInNotEnabled =>
      'El inicio de sesión con Google todavía no está activo en este proyecto';

  @override
  String get dataCloudNoConnection => 'Sin conexión';

  @override
  String get dataCloudNoSignIn => 'Sin sesión iniciada';

  @override
  String get dataCloudNoIdentityToken => 'Google no dio un token de identidad';

  @override
  String get dataCloudSignInFailed => 'No se pudo iniciar sesión';

  @override
  String get dataCloudSignInInterrupted => 'Inicio de sesión interrumpido';

  @override
  String get dataCloudGoogleNotConfigured =>
      'Google no está configurado para esta app';

  @override
  String get dataCloudGoogleSignInFailed =>
      'No se pudo iniciar sesión con Google';

  @override
  String dataNewChaptersNotification(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Han llegado $count capítulos nuevos',
      one: 'Ha llegado un capítulo nuevo',
    );
    return '$_temp0';
  }

  @override
  String get dataArchivePhoneFolderMissing => 'Falta la carpeta del teléfono.';

  @override
  String get dataArchiveDriveFolderMissing => 'Falta la carpeta de Drive.';

  @override
  String dataChapterLabel(String number) {
    return 'Capítulo $number';
  }

  @override
  String get dataLibraryMissing => 'La carpeta no existe o no se puede leer.';

  @override
  String get dataLibraryNotIndexed =>
      'La carpeta no contiene library.json: hay que regenerar los índices con el archivador que escribió la biblioteca.';

  @override
  String get dataLibraryUnreadable =>
      'library.json no se puede leer o no es un índice MALF válido.';

  @override
  String get dataLibraryUnsupported =>
      'library.json usa una versión del formato más reciente que esta app.';

  @override
  String get dataReaderModeContinuous => 'Continua';

  @override
  String get dataReaderModePaged => 'Paginada';

  @override
  String get dataReaderDirectionLtr => 'Izquierda → derecha';

  @override
  String get dataReaderDirectionRtl => 'Derecha → izquierda';

  @override
  String get dataReaderFitWidth => 'Ancho';

  @override
  String get dataReaderFitHeight => 'Alto';

  @override
  String get dataReaderFitOriginal => 'Original';

  @override
  String get dataReaderBackgroundBlack => 'Negro';

  @override
  String get dataReaderBackgroundGrey => 'Gris';

  @override
  String get dataReaderBackgroundWhite => 'Blanco';

  @override
  String readerProbeFrames(String frames, String budget) {
    return 'Fotogramas $frames · límite $budget ms';
  }

  @override
  String readerProbeSlow(
    String build,
    String buildMax,
    String raster,
    String rasterMax,
  ) {
    return 'Lentos UI $build (máx. $buildMax ms) · GPU $raster (máx. $rasterMax ms)';
  }

  @override
  String readerProbeLate(String late, String lateMax) {
    return 'Tardíos $late (máx. $lateMax ms)';
  }

  @override
  String readerProbeScroll(String scroll, String missed, String gap) {
    return 'Desplazando $scroll · saltados $missed (hueco máx. $gap ms)';
  }

  @override
  String readerProbeSources(
    String tiles,
    String whole,
    String phone,
    String phoneMade,
  ) {
    return 'Teselas $tiles · enteras $whole · del teléfono $phone (hechas $phoneMade)';
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
    return 'Decodificación $decode ms (máx. $decodeMax) · llegada $arrival ms (máx. $arrivalMax)';
  }

  @override
  String readerProbeMemory(
    String copy,
    String gc,
    String gcMs,
    String blocking,
    String blockingMs,
  ) {
    return 'Copia máx. $copy ms · GC Android $gc ($gcMs ms) · bloqueantes $blocking ($blockingMs ms)';
  }

  @override
  String readerProbeWaits(String drive, String fallbacks) {
    return 'Esperas de Drive $drive · alternativas Dart $fallbacks';
  }

  @override
  String readerProbeJumps(String corrections, String jumps, String jumped) {
    return 'Correcciones $corrections · saltos $jumps ($jumped px)';
  }
}
