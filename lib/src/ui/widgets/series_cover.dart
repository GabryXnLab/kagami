/// La cella della griglia: copertina, titolo e i due segnali che devono
/// leggersi senza aprire niente — cosa è arrivato e a che punto si è.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/drive.dart';
import '../../data/library.dart';
import '../../data/network.dart';
import '../../data/library_view.dart';
import '../../format/malf.dart';
import '../../l10n.dart';
import '../../providers.dart';
import '../theme.dart';
import 'kit.dart';
import 'origin.dart';

/// Immagine di copertina decodificata alla dimensione a cui si vede.
///
/// [width] è la larghezza in pixel logici della cella: senza `cacheWidth` una
/// griglia lunga tiene in memoria copertine a risoluzione piena e il telefono
/// si scalda per niente. La miniatura fa eccezione: è già piccola, e decodificata
/// alla sua misura è la stessa immagine in cache per la griglia, il volo verso
/// la scheda e la scheda stessa, quindi c'è dal primo fotogramma.
///
/// Dove stia il file lo sa la libreria: sul telefono è un `Image.file` come
/// sempre, su Drive lo diventa appena scaricato — e una volta scaricato resta
/// in cache, quindi la seconda volta è di nuovo un `Image.file` immediato.
class CoverImage extends ConsumerWidget {
  const CoverImage({
    required this.entry,
    required this.width,
    this.full = false,
    this.fit = BoxFit.cover,
    super.key,
  });

  final SeriesEntry? entry;
  final double width;

  /// La copertina piena invece della miniatura: solo per la scheda.
  final bool full;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = this.entry;
    final library = ref.watch(libraryProvider);
    if (entry == null || library == null) return const _CoverPlaceholder();
    final placeholder = _CoverPlaceholder(title: entry.title);
    final holders = ref.watch(seriesHoldersProvider(entry.key));
    final image = full
        ? library.coverImage(entry, holders)
        : library.gridImage(entry, holders);
    if (image == null) return placeholder;
    return _AddressImage(
      address: image.primary,
      placeholder: placeholder,
      fallback: image.fallback,
      width: width,
      fit: fit,
      natural: !full,
      // La copertina piena arriva qualche fotogramma dopo: nel frattempo c'è
      // la miniatura, già decodificata dalla griglia, invece di un riquadro
      // grigio che lampeggia a fine volo.
      loading: full
          ? CoverImage(entry: entry, width: width, fit: fit)
          : null,
    );
  }
}

/// Il volo della copertina fra griglia e scheda: la copertina piena, con gli
/// angoli che si raddrizzano man mano invece di diventare dritti di colpo.
/// Le pastiglie della cella non volano: sparirebbero a metà strada.
Widget coverFlight(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromContext,
  BuildContext toContext,
) {
  final page = (direction == HeroFlightDirection.push ? toContext : fromContext)
      .widget as Hero;
  return AnimatedBuilder(
    animation: animation,
    builder: (_, child) => ClipRRect(
      borderRadius: BorderRadius.circular(14 * (1 - animation.value)),
      child: child,
    ),
    child: page.child,
  );
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({this.title});

  /// Una scheda manuale può non avere copertina: l'iniziale del titolo
  /// distingue una cella dall'altra in una griglia di segnaposto.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant.withValues(alpha: 0.5);
    final text = title?.trim() ?? '';
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: text.isEmpty
            ? Icon(LucideIcons.bookImage, color: muted)
            : Text(
                String.fromCharCode(text.runes.first).toUpperCase(),
                style: KagamiType.title(40, weight: 700, color: muted),
              ),
      ),
    );
  }
}

class _AddressImage extends StatefulWidget {
  const _AddressImage({
    required this.address,
    required this.width,
    required this.fit,
    this.fallback,
    this.loading,
    this.placeholder = const _CoverPlaceholder(),
    this.natural = false,
  });

  /// Cosa mostrare se né il file né la copia hanno un'immagine.
  final Widget placeholder;

  final String address;
  final String? fallback;
  final double width;
  final BoxFit fit;

  /// Cosa mostrare finché il file non è pronto e decodificato.
  final Widget? loading;

  /// Decodificata alla sua misura, senza `cacheWidth`: solo per le miniature.
  final bool natural;

  @override
  State<_AddressImage> createState() => _AddressImageState();
}

class _AddressImageState extends State<_AddressImage> {
  Future<String>? _pending;
  String? _for;

  /// Una copertina che la rete non ha portato si riprova da sola: presto,
  /// poi sempre più di rado, e subito quando la rete torna.
  bool _missed = false;
  int _misses = 0;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    NetworkMonitor.instance.online.addListener(_onNetwork);
  }

  @override
  void dispose() {
    NetworkMonitor.instance.online.removeListener(_onNetwork);
    _retry?.cancel();
    super.dispose();
  }

  void _onNetwork() {
    if (_missed && NetworkMonitor.instance.isOnline) _again();
  }

  void _again() {
    if (!mounted) return;
    _retry?.cancel();
    _retry = null;
    setState(() {
      _missed = false;
      _for = null;
    });
  }

  void _missedOnce() {
    if (!mounted) return;
    _missed = true;
    final seconds = (2 << _misses).clamp(2, 30);
    _misses++;
    _retry?.cancel();
    _retry = Timer(Duration(seconds: seconds), () {
      if (NetworkMonitor.instance.isOnline) _again();
    });
  }

  /// Il file già pronto, senza passare da un `Future`: una copertina in cache
  /// deve comparire nello stesso fotogramma, come quella di una cartella.
  String? _ready(String address) =>
      isRemote(address) ? RemoteFiles.instance?.peek(address) : address;

  Future<String> _fetch(String address) {
    if (_for != address) {
      _for = address;
      final pending = localFileOf(address);
      _pending = pending;
      pending.then(
        (_) => _misses = 0,
        onError: (Object error) {
          if (isNetworkFailure(error)) _missedOnce();
        },
      );
    }
    return _pending!;
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ready(widget.address);
    if (ready != null) return _file(context, ready);
    return FutureBuilder<String>(
      future: _fetch(widget.address),
      builder: (context, snapshot) => switch (snapshot) {
        AsyncSnapshot(:final data?) => _file(context, data),
        AsyncSnapshot(hasError: true) => _fallbackOr(context),
        _ => widget.loading ??
            ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest),
      },
    );
  }

  Widget _fallbackOr(BuildContext context) {
    final fallback = widget.fallback;
    if (fallback == null) return widget.placeholder;
    return _AddressImage(
      address: fallback,
      placeholder: widget.placeholder,
      width: widget.width,
      fit: widget.fit,
    );
  }

  Widget _file(BuildContext context, String path) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return Image.file(
      File(path),
      fit: widget.fit,
      filterQuality: FilterQuality.medium,
      cacheWidth: widget.natural ? null : (widget.width * ratio).round(),
      // Un file annunciato dall'indice e non ancora sincronizzato è normale,
      // non un errore: si mostra il posto che occupa, o la copia su Drive.
      errorBuilder: (context, _, _) => _fallbackOr(context),
      frameBuilder: (_, child, frame, wasSync) => wasSync || frame != null
          ? child
          : widget.loading ?? ColoredBox(color: scheme.surfaceContainerHighest),
    );
  }
}

class SeriesCover extends StatelessWidget {
  const SeriesCover({
    required this.signals,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    super.key,
  });

  final SeriesSignals signals;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final entry = signals.entry;
    return KPress(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Hero(
              tag: 'cover:${entry.key}',
              flightShuttleBuilder: coverFlight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LayoutBuilder(
                      builder: (context, size) => CoverImage(
                        entry: entry,
                        width: size.maxWidth,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: OriginBadge(seriesKey: entry.key),
                    ),
                    if (signals.hasUnread)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: _UnreadBadge(signals: signals),
                      )
                    // Una scheda non ha arretrato: il segno è solo dei
                    // capitoli usciti sul sito.
                    else if (signals.isNew)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: NewChaptersDot(count: signals.newChapters),
                      ),
                    if (signals.isCard)
                      Positioned(
                        right: 6,
                        bottom: 8,
                        child: _Pill(
                          background: Colors.black.withValues(alpha: 0.65),
                          foreground: Colors.white70,
                          label: context.l10n.coverCardBadge,
                        ),
                      ),
                    if (signals.entry.isOngoing &&
                        signals.entry.missingChapterCount > 0)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: _MissingBadge(
                          count: signals.entry.missingChapterCount,
                        ),
                      ),
                    if (selected)
                      ColoredBox(
                        color: scheme.primary.withValues(alpha: 0.45),
                        child: Center(
                          child: Icon(
                            LucideIcons.circleCheck,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    if (signals.fraction > 0 && signals.fraction < 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: signals.fraction,
                          minHeight: 3,
                          backgroundColor: Colors.black45,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            entry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: KagamiType.title(13.5, weight: 600),
          ),
          const SizedBox(height: 2),
          Text(
            _subtitle(context.l10n),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KagamiType.label(size: 11, color: context.tokens.muted),
          ),
        ],
      ),
    );
  }

  String _subtitle(AppLocalizations l10n) {
    final entry = signals.entry;
    final reached = signals.state.reachedChapter;
    if (entry.archivedChapterCount == 0) {
      return reached == null ? l10n.coverNoChapters : l10n.coverReached(reached);
    }
    return signals.hasUnread
        ? l10n.coverChaptersUnread(
            entry.archivedChapterCount,
            signals.unreadCount,
          )
        : l10n.coverChapters(entry.archivedChapterCount);
  }
}

/// Quanti capitoli sono arrivati dall'ultima apertura della scheda. È
/// l'unico segnale a colore pieno della copertina: la novità si deve vedere
/// da lontano, l'arretrato no.
class NewChaptersDot extends StatelessWidget {
  const NewChaptersDot({required this.count, this.size = 20, super.key});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Semantics(
      label: context.l10n.coverNewChapters(count),
      child: Container(
        constraints: BoxConstraints(minWidth: size, minHeight: size),
        padding: EdgeInsets.symmetric(horizontal: size * 0.25),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(size / 2),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: KagamiType.figure(size * 0.55, color: scheme.onPrimary),
        ),
      ),
    );
  }
}

/// I capitoli che aspettano, arretrato compreso. Uno solo per copertina:
/// accanto a un pallino dei nuovi sembravano due volte lo stesso numero,
/// quindi l'arrivo non ha un segno suo ma colora questo, a colore pieno
/// perché la novità si deve vedere da lontano e l'arretrato no.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.signals});

  final SeriesSignals signals;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final unread = signals.unreadCount;
    final fresh = signals.newChapters;
    return Semantics(
      label: fresh > 0
          ? context.l10n.coverUnreadFresh(unread, fresh)
          : context.l10n.coverUnread(unread),
      excludeSemantics: true,
      child: _Pill(
        background: fresh > 0
            ? scheme.primary
            : Colors.black.withValues(alpha: 0.65),
        foreground: fresh > 0 ? scheme.onPrimary : Colors.white,
        label: unread > 99 ? '99+' : '$unread',
      ),
    );
  }
}

/// Capitoli che il provider pubblica e che non sono ancora sul telefono: la
/// normalità di una serie in corso, non un difetto dell'archivio.
class _MissingBadge extends StatelessWidget {
  const _MissingBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => _Pill(
        background: Colors.black.withValues(alpha: 0.65),
        foreground: Colors.white70,
        label: '↓ $count',
      );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.background,
    required this.foreground,
    required this.label,
  });

  final Color background;
  final Color foreground;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            label,
            style: KagamiType.figure(11, color: foreground),
          ),
        ),
      );
}
