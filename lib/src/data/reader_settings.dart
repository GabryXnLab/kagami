/// Come si legge: modalità, direzione, adattamento, sfondo.
///
/// Sono impostazioni di visualizzazione, non stato di lettura: MALF non le
/// prevede e infatti non stanno in un file della libreria. Stanno però nel
/// database insieme al resto dei dati personali, così il backup se le porta
/// dietro invece di lasciarle morire con l'installazione.
library;

import 'package:drift/drift.dart';

import '../l10n.dart';
import 'db/database.dart';

/// Come scorrono le tavole.
enum ReaderMode {
  /// Scorrimento verticale senza stacchi: è come sono fatti i manhwa.
  continuous,

  /// Una tavola per volta.
  paged;

  static ReaderMode parse(String? value) =>
      value == 'paged' ? ReaderMode.paged : ReaderMode.continuous;

  String get label => switch (this) {
        continuous => currentL10n().dataReaderModeContinuous,
        paged => currentL10n().dataReaderModePaged,
      };
}

/// Verso di avanzamento in modalità paginata.
enum ReaderDirection {
  leftToRight,
  rightToLeft;

  static ReaderDirection parse(String? value) => value == 'rtl'
      ? ReaderDirection.rightToLeft
      : ReaderDirection.leftToRight;

  String get label => switch (this) {
        leftToRight => currentL10n().dataReaderDirectionLtr,
        rightToLeft => currentL10n().dataReaderDirectionRtl,
      };

  String get wireValue => this == ReaderDirection.rightToLeft ? 'rtl' : 'ltr';
}

/// Come la tavola riempie lo schermo. Su un telefono in verticale la
/// larghezza è quasi sempre la risposta, ma una tavola doppia scansionata
/// intera si legge solo per altezza.
enum ReaderFit {
  width,
  height,
  original;

  static ReaderFit parse(String? value) =>
      ReaderFit.values.firstWhere((row) => row.name == value, orElse: () => width);

  String get label => switch (this) {
        width => currentL10n().dataReaderFitWidth,
        height => currentL10n().dataReaderFitHeight,
        original => currentL10n().dataReaderFitOriginal,
      };
}

/// Il colore attorno alla tavola. Il nero sparisce al buio, il bianco continua
/// la carta di una scansione chiara e il grigio sta in mezzo.
enum ReaderBackground {
  black,
  grey,
  white;

  static ReaderBackground parse(String? value) => ReaderBackground.values
      .firstWhere((row) => row.name == value, orElse: () => black);

  String get label => switch (this) {
        black => currentL10n().dataReaderBackgroundBlack,
        grey => currentL10n().dataReaderBackgroundGrey,
        white => currentL10n().dataReaderBackgroundWhite,
      };
}

class ReaderSettings {
  const ReaderSettings({
    this.mode = ReaderMode.continuous,
    this.direction = ReaderDirection.rightToLeft,
    this.fit = ReaderFit.width,
    this.background = ReaderBackground.black,
    this.brightness = 1.0,
    this.keepAwake = true,
    this.doublePage = false,
    this.showPageNumber = true,
    this.showProgress = true,
    this.showScrollTop = true,
    this.autoScroll = 0,
  });

  final ReaderMode mode;
  final ReaderDirection direction;
  final ReaderFit fit;
  final ReaderBackground background;

  /// Attenuazione applicata sopra la tavola, 0,25–1,0: si legge al buio e lo
  /// schermo al minimo di sistema è spesso ancora troppo.
  final double brightness;
  final bool keepAwake;

  /// Due tavole affiancate quando lo schermo è più largo che alto: è il modo
  /// in cui il manga è stampato, e su un tablet sdraiato si vede.
  final bool doublePage;
  final bool showPageNumber;

  /// Una striscia di avanzamento in fondo allo schermo e il pulsante che
  /// riporta all'inizio del capitolo: su un manhwa di duecento tavole servono
  /// entrambi, su un capitolo corto sono due cose in più da guardare.
  final bool showProgress;
  final bool showScrollTop;

  /// Tavole al minuto dello scorrimento automatico; 0 significa spento.
  final double autoScroll;

  ReaderSettings copyWith({
    ReaderMode? mode,
    ReaderDirection? direction,
    ReaderFit? fit,
    ReaderBackground? background,
    double? brightness,
    bool? keepAwake,
    bool? doublePage,
    bool? showPageNumber,
    bool? showProgress,
    bool? showScrollTop,
    double? autoScroll,
  }) =>
      ReaderSettings(
        mode: mode ?? this.mode,
        direction: direction ?? this.direction,
        fit: fit ?? this.fit,
        background: background ?? this.background,
        brightness: brightness ?? this.brightness,
        keepAwake: keepAwake ?? this.keepAwake,
        doublePage: doublePage ?? this.doublePage,
        showPageNumber: showPageNumber ?? this.showPageNumber,
        showProgress: showProgress ?? this.showProgress,
        showScrollTop: showScrollTop ?? this.showScrollTop,
        autoScroll: autoScroll ?? this.autoScroll,
      );
}

/// Lettura e scrittura delle impostazioni del lettore.
///
/// Una serie senza riga propria eredita quella predefinita: chi imposta la
/// lettura destra→sinistra una volta non vuole rifarlo per ogni manga.
class ReaderSettingsStore {
  ReaderSettingsStore(this.db, {this.profileId = defaultProfileId});

  final KagamiDatabase db;
  final String profileId;

  Future<ReaderSettings> forSeries(String seriesKey) async {
    final row = await _row(seriesKey) ?? await _row(globalSettingsKey);
    if (row == null) return const ReaderSettings();
    return ReaderSettings(
      mode: ReaderMode.parse(row.mode),
      direction: ReaderDirection.parse(row.direction),
      fit: ReaderFit.parse(row.fit),
      background: ReaderBackground.parse(row.background),
      brightness: row.brightness,
      keepAwake: row.keepAwake,
      doublePage: row.doublePage,
      showPageNumber: row.showPageNumber,
      showProgress: row.showProgress,
      showScrollTop: row.showScrollTop,
      autoScroll: row.autoScroll,
    );
  }

  /// Salva per la serie e, insieme, come predefinito: l'ultima scelta è
  /// quasi sempre quella giusta anche per la prossima serie.
  Future<void> save(String seriesKey, ReaderSettings settings) async {
    for (final key in {seriesKey, globalSettingsKey}) {
      await db.into(db.readerSettingsRows).insertOnConflictUpdate(
            ReaderSettingsRowsCompanion.insert(
              profileId: profileId,
              seriesKey: key,
              mode: settings.mode.name,
              direction: settings.direction.wireValue,
              fit: settings.fit.name,
              background: settings.background.name,
              brightness: Value(settings.brightness),
              keepAwake: Value(settings.keepAwake),
              doublePage: Value(settings.doublePage),
              showPageNumber: Value(settings.showPageNumber),
              showProgress: Value(settings.showProgress),
              showScrollTop: Value(settings.showScrollTop),
              autoScroll: Value(settings.autoScroll),
            ),
          );
    }
  }

  Future<ReaderSettingsRow?> _row(String seriesKey) =>
      (db.select(db.readerSettingsRows)
            ..where((row) =>
                row.profileId.equals(profileId) &
                row.seriesKey.equals(seriesKey)))
          .getSingleOrNull();
}
