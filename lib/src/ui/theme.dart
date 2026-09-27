/// Tema dell'app.
///
/// Scuro come impostazione predefinita: si legge quasi sempre al buio e una
/// cornice chiara attorno a una tavola in bianco e nero abbaglia.
///
/// Le superfici sono neutre di proposito, anche quando il sistema offre un
/// colore d'accento: in una griglia di copertine il colore ce l'hanno già le
/// copertine, e un tema tinto litiga con tutte. L'accento resta perciò
/// confinato a ciò che si tocca — pulsanti, selezioni, avanzamento.
library;

import 'package:flutter/material.dart';

/// Rosso da lettore di manga: è il colore che l'occhio associa ai comandi
/// ("continua", "leggi"), e su superfici quasi nere resta leggibile senza
/// illuminare la pagina accanto.
const Color _seed = Color(0xFFEF4444);

/// I grigi della cornice. Material 3 li deriverebbe dal seed, tinti di rosso;
/// qui vengono imposti perché la gerarchia la fanno tono e dimensione.
const Color _paperDark = Color(0xFF09090B);
const Color _cardDark = Color(0xFF131316);
const Color _highDark = Color(0xFF1B1B20);
const Color _raisedDark = Color(0xFF232329);
const Color _lineDark = Color(0xFF2A2A31);

const Color _paperLight = Color(0xFFFFFFFF);
const Color _cardLight = Color(0xFFF5F5F7);
const Color _highLight = Color(0xFFEFEFF2);
const Color _raisedLight = Color(0xFFE7E7EC);
const Color _lineLight = Color(0xFFE2E2E8);

/// I colori che non stanno nella `ColorScheme` e che servono ovunque: il
/// grigio del testo secondario e i quattro colori di significato.
class KagamiTokens extends ThemeExtension<KagamiTokens> {
  const KagamiTokens({
    required this.muted,
    required this.line,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  static const dark = KagamiTokens(
    muted: Color(0xFF8E8E98),
    line: _lineDark,
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    info: Color(0xFF38BDF8),
  );

  static const light = KagamiTokens(
    muted: Color(0xFF6B6B75),
    line: _lineLight,
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    info: Color(0xFF0284C7),
  );

  final Color muted;
  final Color line;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  @override
  KagamiTokens copyWith({
    Color? muted,
    Color? line,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) =>
      KagamiTokens(
        muted: muted ?? this.muted,
        line: line ?? this.line,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        info: info ?? this.info,
      );

  @override
  KagamiTokens lerp(ThemeExtension<KagamiTokens>? other, double t) {
    if (other is! KagamiTokens) return this;
    return KagamiTokens(
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

extension KagamiThemeX on BuildContext {
  KagamiTokens get tokens => Theme.of(this).extension<KagamiTokens>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
}

/// La tipografia dell'app. Un solo carattere, spaziatura negativa sui titoli:
/// è quello che fa sembrare compatto un elenco lungo.
class KagamiType {
  const KagamiType._();

  static const family = 'Figtree';

  static TextStyle display(double size, {Color? color, double height = 1.05}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: height,
        letterSpacing: -0.9,
        color: color,
      );

  /// Per i numeri che cambiano sotto gli occhi: cifre a larghezza fissa,
  /// altrimenti un contatore che sale sposta quello che ha accanto.
  static TextStyle figure(double size, {Color? color, double height = 1.05}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: height,
        letterSpacing: -0.8,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle title(double size, {Color? color, int weight = 600}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.values[(weight ~/ 100) - 1],
        letterSpacing: -0.3,
        color: color,
      );

  static TextStyle body(
    double size, {
    Color? color,
    double height = 1.4,
    int weight = 400,
  }) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.values[(weight ~/ 100) - 1],
        height: height,
        letterSpacing: -0.1,
        color: color,
      );

  static TextStyle label({double size = 12.5, Color? color}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: color,
      );

  /// L'etichetta in maiuscoletto spaziato delle sezioni: si distingue dal
  /// contenuto senza rubargli dimensione.
  static TextStyle overline({double size = 11.5, Color? color}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: color,
      );
}

/// [source] è il colore d'accento del sistema, quando la piattaforma lo offre:
/// entra come accento e non come tinta delle superfici.
ThemeData kagamiTheme(Brightness brightness, [Color? source]) {
  final dark = brightness == Brightness.dark;
  final accent = _adapt(source ?? _seed, dark);
  final tokens = dark ? KagamiTokens.dark : KagamiTokens.light;

  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  ).copyWith(
    primary: accent,
    onPrimary: accent.computeLuminance() > 0.5 ? Colors.black : Colors.white,
    surface: dark ? _paperDark : _paperLight,
    surfaceContainerLowest: dark ? const Color(0xFF060608) : _paperLight,
    surfaceContainerLow: dark ? const Color(0xFF0F0F12) : const Color(0xFFFAFAFC),
    surfaceContainer: dark ? _cardDark : _cardLight,
    surfaceContainerHigh: dark ? _highDark : _highLight,
    surfaceContainerHighest: dark ? _raisedDark : _raisedLight,
    onSurface: dark ? const Color(0xFFEDEDF2) : const Color(0xFF15151A),
    onSurfaceVariant: tokens.muted,
    outlineVariant: tokens.line,
  );

  final text = _typography(scheme.onSurface, tokens.muted);

  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: KagamiType.family,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    // Niente onda d'inchiostro: il riscontro al tocco lo dà la scala dei
    // componenti del kit, che risponde subito e non lascia una scia.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    extensions: [tokens],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      foregroundColor: scheme.onSurface,
      titleTextStyle: KagamiType.display(23, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      titleTextStyle: KagamiType.display(20, color: scheme.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.surfaceContainerHighest,
      contentTextStyle: KagamiType.body(13.5, color: scheme.onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: _button(scheme, text)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _button(scheme, text).copyWith(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
        side: WidgetStatePropertyAll(BorderSide(color: tokens.line)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: KagamiType.label(size: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurface,
        highlightColor: Colors.transparent,
      ),
    ),
    // Niente bordi sui contenitori: separano per tono, non per linea.
    chipTheme: ChipThemeData(
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.primary.withValues(alpha: 0.22),
      showCheckmark: false,
      labelStyle: KagamiType.label(size: 13, color: scheme.onSurface),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textStyle: WidgetStatePropertyAll(KagamiType.body(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      hintStyle: KagamiType.body(14, color: tokens.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.6)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: tokens.muted,
      titleTextStyle: KagamiType.title(14.5, color: scheme.onSurface),
      subtitleTextStyle: KagamiType.body(12.5, color: tokens.muted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : scheme.onSurfaceVariant,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.surfaceContainerHighest,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.12),
      trackHeight: 4,
    ),
    dividerTheme: DividerThemeData(space: 0, thickness: 1, color: tokens.line),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      linearMinHeight: 4,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: KagamiType.label(size: 12, color: scheme.onSurface),
    ),
    // Le animazioni sono brevi e legate al gesto: la lettura non aspetta
    // l'interfaccia.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}

/// Un accento quasi nero su fondo nero (o quasi bianco su bianco) sparirebbe:
/// il colore di sistema può essere qualunque cosa, quello dell'app no.
Color _adapt(Color accent, bool dark) {
  final luminance = accent.computeLuminance();
  if (dark && luminance < 0.06) return const Color(0xFFF2F2F2);
  if (!dark && luminance > 0.82) return const Color(0xFF1C1C1E);
  return accent;
}

ButtonStyle _button(ColorScheme scheme, TextTheme text) => ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(scheme.primary),
      foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
      elevation: const WidgetStatePropertyAll(0),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textStyle: WidgetStatePropertyAll(KagamiType.title(15, weight: 700)),
    );

TextTheme _typography(Color onSurface, Color muted) => TextTheme(
      displayLarge: KagamiType.display(40, color: onSurface),
      displayMedium: KagamiType.display(34, color: onSurface),
      displaySmall: KagamiType.display(28, color: onSurface),
      headlineLarge: KagamiType.display(26, color: onSurface),
      headlineMedium: KagamiType.display(23, color: onSurface),
      headlineSmall: KagamiType.display(20, color: onSurface),
      titleLarge: KagamiType.title(18, color: onSurface, weight: 700),
      titleMedium: KagamiType.title(15.5, color: onSurface, weight: 600),
      titleSmall: KagamiType.title(13.5, color: onSurface, weight: 600),
      bodyLarge: KagamiType.body(15, color: onSurface),
      bodyMedium: KagamiType.body(13.5, color: onSurface),
      bodySmall: KagamiType.body(12.5, color: muted),
      labelLarge: KagamiType.label(size: 14, color: onSurface),
      labelMedium: KagamiType.label(size: 12.5, color: muted),
      labelSmall: KagamiType.label(size: 11.5, color: muted),
    );

/// Il colore di un'etichetta — genere, tag, autore, tipo — ricavato dal suo
/// testo e da nient'altro: lo stesso tag ha lo stesso colore in ogni serie,
/// su ogni telefono e a ogni avvio, senza una tabella da tenere.
///
/// La tinta viene da un'impronta FNV-1a dei caratteri e non da
/// `String.hashCode`, che Dart non promette uguale fra un avvio e l'altro.
/// Maiuscole, spazi ai lati e il `#` davanti non contano: «Action» e
/// «action» sono lo stesso genere scritto da due siti diversi. Saturazione e
/// luminosità sono fisse per tema, così che nessuna etichetta gridi più delle
/// altre e il testo resti leggibile sulla sua pastiglia.
class TagTint {
  const TagTint._(this.foreground, this.background, this.border);

  factory TagTint.of(BuildContext context, String text) {
    final hue = tagHue(text);
    if (Theme.of(context).brightness == Brightness.dark) {
      final ink = HSLColor.fromAHSL(1, hue, 0.8, 0.74).toColor();
      return TagTint._(
        ink,
        ink.withValues(alpha: 0.13),
        ink.withValues(alpha: 0.26),
      );
    }
    final base = HSLColor.fromAHSL(1, hue, 0.7, 0.5).toColor();
    return TagTint._(
      HSLColor.fromAHSL(1, hue, 0.65, 0.34).toColor(),
      base.withValues(alpha: 0.11),
      base.withValues(alpha: 0.3),
    );
  }

  final Color foreground;
  final Color background;
  final Color border;
}

/// La tinta, in gradi, che spetta a un testo. Pubblica per i test.
double tagHue(String text) {
  var normalized = text.trim().toLowerCase();
  if (normalized.startsWith('#')) normalized = normalized.substring(1).trim();
  var hash = 0x811c9dc5;
  for (final unit in normalized.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return (hash % 360).toDouble();
}

/// Il colore di un voto da 1 a 10: dal rosso dei bocciati all'ambra della
/// sufficienza al verde dei preferiti, con i colori di significato del tema.
Color ratingTint(BuildContext context, int rating) {
  final tokens = context.tokens;
  final t = (rating.clamp(1, 10) - 1) / 9;
  return t < 0.5
      ? Color.lerp(tokens.danger, tokens.warning, t * 2)!
      : Color.lerp(tokens.warning, tokens.success, (t - 0.5) * 2)!;
}
