/// I pezzi con cui sono costruite tutte le schermate.
///
/// Esistono perché la stessa cosa si presenti sempre nello stesso modo: una
/// scheda ha un raggio solo, un'etichetta di sezione un peso solo, un tocco
/// una risposta sola. Chi scrive una schermata sceglie il contenuto, non la
/// forma.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n.dart';
import '../theme.dart';

/// Il riscontro al tocco: la superficie cede di un soffio e torna. Sostituisce
/// l'onda d'inchiostro di Material, che su una griglia di copertine lascia una
/// scia sopra l'immagine.
class KPress extends StatefulWidget {
  const KPress({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.975,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<KPress> createState() => _KPressState();
}

class _KPressState extends State<KPress> {
  bool _down = false;

  void _set(bool value) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onLongPress!();
              },
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// Un contenitore: tono più chiaro del fondo, angoli larghi, nessun bordo.
class KCard extends StatelessWidget {
  const KCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.color,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.colors.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
    if (onTap == null && onLongPress == null) return body;
    return KPress(onTap: onTap, onLongPress: onLongPress, child: body);
  }
}

/// L'intestazione di una sezione. Maiuscoletto spaziato: si legge come
/// un'etichetta e non come un titolo, quindi non compete con il contenuto.
class KSection extends StatelessWidget {
  const KSection(this.label, {this.trailing, this.padding, super.key});

  final String label;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KagamiType.overline(color: context.tokens.muted),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      );
}

/// Il pulsante pieno d'accento: quello che si preme davvero, uno per
/// schermata.
class KButton extends StatelessWidget {
  const KButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.height = 50,
    this.tone,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final double height;

  /// Un colore diverso dall'accento, per le azioni che non sono "leggi".
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final background = tone ?? scheme.primary;
    final foreground =
        background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return Semantics(
      button: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: onPressed == null ? 0.4 : 1,
        child: KPress(
          onTap: onPressed,
          child: Container(
            height: height,
            width: expand ? double.infinity : null,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 17, color: foreground),
                  const SizedBox(width: 9),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KagamiType.title(15, weight: 700, color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Il pulsante secondario: stessa forma, nessun riempimento.
class KGhostButton extends StatelessWidget {
  const KGhostButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.height = 50,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: onPressed == null ? 0.4 : 1,
      child: KPress(
        onTap: onPressed,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: scheme.onSurface),
                const SizedBox(width: 9),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KagamiType.title(14.5,
                      weight: 600, color: scheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un'azione quadrata accanto al pulsante principale: icona sola, stessa
/// altezza, nessuna etichetta da tradurre.
class KIconAction extends StatelessWidget {
  const KIconAction({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
    this.size = 50,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final button = KPress(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? scheme.primary.withValues(alpha: 0.18)
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          size: 19,
          color: active ? scheme.primary : scheme.onSurface,
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Una pastiglia di stato o di genere. Attiva si inverte: pieno d'accento,
/// testo chiaro.
class KChip extends StatelessWidget {
  const KChip({
    required this.label,
    this.active = false,
    this.onTap,
    this.icon,
    this.tint,
    super.key,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Il pallino che precede l'etichetta, quando il colore dice qualcosa.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final foreground = active ? scheme.onPrimary : context.tokens.muted;
    return Semantics(
      button: onTap != null,
      selected: active,
      child: KPress(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: active ? scheme.primary : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tint != null && !active) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
              ],
              if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KagamiType.label(size: 13, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una fila di pastiglie che scorre di lato invece di andare a capo: il numero
/// di generi di una serie non deve decidere l'altezza della scheda.
class KChipBar extends StatelessWidget {
  const KChipBar({
    required this.children,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: padding,
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) => children[index],
        ),
      );
}

/// Un'etichetta che nomina qualcosa — genere, tag, autore, tipo — con il
/// colore che spetta al suo testo ([TagTint]): la stessa parola ha lo stesso
/// colore in ogni scheda, ed è il modo in cui si riconosce a colpo d'occhio.
///
/// [prefix] è il segno davanti al nome (il `#` dei tag), più tenue del nome;
/// il colore lo decide il nome solo, quindi non cambia se il segno cambia.
class KTag extends StatelessWidget {
  const KTag({
    required this.label,
    this.prefix,
    this.icon,
    this.onTap,
    this.dense = false,
    super.key,
  });

  final String label;
  final String? prefix;
  final IconData? icon;
  final VoidCallback? onTap;

  /// Più bassa e più piccola, per le righe fitte dove l'etichetta accompagna.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tint = TagTint.of(context, label);
    final size = dense ? 11.5 : 13.0;
    return Semantics(
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      child: KPress(
        onTap: onTap,
        child: Container(
          height: dense ? 24 : 34,
          padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 13),
          decoration: BoxDecoration(
            color: tint.background,
            borderRadius: BorderRadius.circular(dense ? 8 : 12),
            border: Border.all(color: tint.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: dense ? 11 : 13, color: tint.foreground),
                SizedBox(width: dense ? 4 : 6),
              ],
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (prefix != null)
                        TextSpan(
                          text: prefix,
                          style: TextStyle(
                            color: tint.foreground.withValues(alpha: 0.55),
                          ),
                        ),
                      TextSpan(text: label),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KagamiType.label(size: size, color: tint.foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La scelta fra due o tre alternative che stanno tutte sullo schermo: il
/// cursore scorre, non salta, perché è il modo in cui si capisce che le
/// alternative sono le facce di una cosa sola.
class KSegmented extends StatelessWidget {
  const KSegmented({
    required this.options,
    required this.index,
    required this.onChanged,
    this.expand = true,
    this.icons,
    super.key,
  });

  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;
  final bool expand;
  final List<IconData>? icons;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(15),
      ),
      child: SizedBox(
        height: 36,
        child: LayoutBuilder(
          builder: (context, box) {
            final cell = box.maxWidth / options.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  left: cell * index,
                  width: cell,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < options.length; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onChanged(i);
                          },
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (icons != null) ...[
                                  Icon(
                                    icons![i],
                                    size: 15,
                                    color: i == index
                                        ? scheme.onPrimary
                                        : context.tokens.muted,
                                  ),
                                  const SizedBox(width: 7),
                                ],
                                Flexible(
                                  child: Text(
                                    options[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: KagamiType.label(
                                      size: 13,
                                      color: i == index
                                          ? scheme.onPrimary
                                          : context.tokens.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Un numero con la sua etichetta: il mattone di tutte le file di statistiche.
class KFigure extends StatelessWidget {
  const KFigure({
    required this.value,
    required this.label,
    this.tint,
    this.size = 20,
    super.key,
  });

  final String value;
  final String label;
  final Color? tint;
  final double size;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            style: KagamiType.figure(
              size,
              color: tint ?? context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KagamiType.overline(size: 10, color: context.tokens.muted),
          ),
        ],
      );
}

/// La fila di numeri della scheda serie, divisa da righe verticali sottili.
class KFigureRow extends StatelessWidget {
  const KFigureRow({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 28,
                color: context.tokens.line,
              ),
            Expanded(child: children[i]),
          ],
        ],
      );
}

/// Una scheda con un numero grande: la statistica che si guarda da lontano.
class KStatCard extends StatelessWidget {
  const KStatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.tint,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.muted;
    return KCard(
      onTap: onTap,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: muted),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KagamiType.label(color: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: KagamiType.figure(
                26,
                color: tint ?? context.colors.onSurface,
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 5),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KagamiType.label(size: 11.5, color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Una riga d'impostazione o di menù.
class KTile extends StatelessWidget {
  const KTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.tint,
    this.leading,
    super.key,
  });

  final IconData icon;

  /// Un'immagine al posto dell'icona (il logo di un sito), nello stesso posto.
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final muted = context.tokens.muted;
    return KPress(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (tint ?? scheme.onSurface).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: leading ??
                  Icon(icon, size: 18, color: tint ?? scheme.onSurface),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KagamiType.title(14.5,
                        color: tint ?? scheme.onSurface),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KagamiType.body(12.5, color: muted),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Un gruppo di righe dentro una scheda sola, separate da una linea che non
/// arriva ai bordi.
class KGroup extends StatelessWidget {
  const KGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => KCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 63),
                  child: Divider(height: 1, color: context.tokens.line),
                ),
              children[i],
            ],
          ],
        ),
      );
}

/// Lo stato vuoto: un'icona dentro un alone, cosa manca e cosa si può fare.
class KEmpty extends StatelessWidget {
  const KEmpty({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final halo = compact ? 72.0 : 104.0;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 36,
          vertical: compact ? 26 : 40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: halo,
              height: halo,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.18),
                    scheme.primary.withValues(alpha: 0.03),
                  ],
                ),
              ),
              child: Icon(icon, size: compact ? 30 : 42, color: scheme.primary),
            ),
            SizedBox(height: compact ? 18 : 26),
            Text(
              title,
              textAlign: TextAlign.center,
              style: KagamiType.display(compact ? 16 : 20),
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: KagamiType.body(
                  compact ? 13 : 14,
                  color: context.tokens.muted,
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: compact ? 20 : 28),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// L'entrata in scena delle schede di una schermata: salgono di poco, una
/// dopo l'altra. Serve a far sembrare che la schermata si componga invece di
/// apparire tutta insieme.
class Entrance extends StatefulWidget {
  const Entrance({required this.child, this.index = 0, this.offset = 14,
      super.key});

  final Widget child;
  final int index;
  final double offset;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    // Oltre l'ottava scheda lo scaglionamento non si vede più e si paga solo
    // in attesa.
    Future<void>.delayed(
      Duration(milliseconds: 45 * widget.index.clamp(0, 8)),
      () {
        if (mounted) _controller.forward();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  late final Animation<double> _settle =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  // `FadeTransition` cambia solo l'opacità del livello, senza ricostruire né
  // ridisegnare la scheda a ogni fotogramma come faceva `Opacity`: le schede
  // entrano mentre la pagina sta ancora arrivando, e lì ogni millisecondo
  // conta.
  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _controller,
        child: AnimatedBuilder(
          animation: _settle,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, widget.offset * (1 - _settle.value)),
            child: child,
          ),
          child: widget.child,
        ),
      );
}

/// Il foglio che sale dal basso, con il suo titolo e la sua croce.
Future<T?> showKagamiSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext context) builder,
  Widget? action,
  bool scrollable = false,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => KSheet(
        title: title,
        action: action,
        scrollable: scrollable,
        child: Builder(builder: builder),
      ),
    );

class KSheet extends StatelessWidget {
  const KSheet({
    required this.title,
    required this.child,
    this.action,
    this.scrollable = false,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? action;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: child,
    );
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
            child: Row(
              children: [
                Expanded(child: Text(title, style: KagamiType.display(19))),
                if (action != null) ...[action!, const SizedBox(width: 4)],
                IconButton(
                  tooltip: context.l10n.kitClose,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, size: 20),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.tokens.line),
          if (scrollable) Flexible(child: body) else body,
        ],
      ),
    );
  }
}

/// Una barra di avanzamento sottile, senza etichetta: dice a che punto si è
/// mentre si guarda altro.
class KProgress extends StatelessWidget {
  const KProgress({required this.value, this.height = 5, this.tint, super.key});

  final double value;
  final double height;
  final Color? tint;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: height,
          backgroundColor: context.colors.surfaceContainerHighest,
          valueColor:
              AlwaysStoppedAnimation(tint ?? context.colors.primary),
        ),
      );
}
