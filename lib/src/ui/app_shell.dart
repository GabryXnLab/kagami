/// Le quattro destinazioni dell'app.
///
/// Finché non c'è una cartella leggibile non c'è niente da navigare: al suo
/// posto sta la schermata che chiede permesso e cartella.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/notifications.dart';
import '../providers.dart';
import 'archive_screen.dart';
import 'collections_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'more_screen.dart';
import 'setup_screen.dart';
import 'theme.dart';
import 'widgets/kit.dart';

/// Quanto spazio lasciare in fondo a una schermata perché l'ultima riga non
/// finisca sotto la barra sospesa.
const double navBarInset = 96;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  DateTime? _indexSeenAt;
  StreamSubscription<String>? _notificationTaps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final notifications = ArrivalNotifications.instance;
    _notificationTaps = notifications.opened.listen(_openFromNotification);
    notifications.launched().then((key) {
      if (key != null) _openFromNotification(key);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTaps?.cancel();
    super.dispose();
  }

  /// Il tocco su una notifica porta alla scheda della serie, o per un
  /// invito a un server dove lo si collega. Con l'app appena avviata la
  /// libreria non è ancora letta: la si aspetta, altrimenti la scheda
  /// direbbe che la serie non c'è.
  Future<void> _openFromNotification(String key) async {
    if (key.startsWith(serverInvitePrefix)) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ArchiveScreen()));
      return;
    }
    await ref.read(libraryIndexProvider.future);
    if (!mounted || ref.read(seriesEntryProvider(key)) == null) return;
    openSeries(context, key);
  }

  /// Tornando in primo piano la cartella può essere cambiata sotto i piedi:
  /// la sincronizzazione arriva quando vuole. Si guarda la data di
  /// `library.json` — una `stat()` — e si rilegge solo se è cambiata, che è
  /// esattamente il motivo per cui l'indice esiste.
  ///
  /// Uscendo, invece, i dati personali vanno su: è il momento in cui una
  /// sessione di lettura è finita davvero.
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      ref.read(arrivalsProvider.notifier).handOver();
      await ref.read(cloudAccountProvider.notifier).pushNow();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    // Il giro programmato può essere passato mentre l'app era chiusa.
    unawaited(ref.read(folderSyncRunProvider.notifier).refresh());
    // Drive non ha una `stat()` da un millisecondo: si rilegge solo se
    // l'ultima lettura è vecchia, e allora costa due richieste.
    if (ref.read(driveRepositoryProvider)?.stale ?? false) {
      ref.invalidate(libraryCatalogProvider);
      return;
    }
    final repository = ref.read(libraryProvider)?.folder;
    if (repository == null) return;
    final modified = await repository.libraryModifiedAt();
    if (modified == null || modified == _indexSeenAt) return;
    final first = _indexSeenAt == null;
    _indexSeenAt = modified;
    if (!first) ref.invalidate(libraryCatalogProvider);
  }

  DateTime? _reloadedAt;

  @override
  Widget build(BuildContext context) {
    // Gli inviti ai server degli altri arrivano mentre l'app è aperta, da
    // qualunque schermata.
    ref.listen(serverInvitesProvider, (_, next) {
      final invites = next.value;
      if (invites == null || invites.isEmpty) return;
      unawaited(announceServerInvites(
        ref.read(userRepositoryProvider),
        invites,
        linked: ref.read(serverLinkProvider).value?.url.toString(),
      ));
    });
    if (ref.watch(libraryProvider) == null) {
      // La cartella di Drive sta nel database e arriva un istante dopo: senza
      // aspettarla, chi legge solo da Drive vedrebbe lampeggiare il primo
      // avvio a ogni apertura.
      final folder = ref.watch(driveFolderProvider);
      if (folder.isLoading) return const Scaffold();
      // Un database che non risponde non è una cartella mai scelta: chiederla
      // di nuovo nasconderebbe il guasto, e il perché va mostrato.
      if (folder case AsyncError(:final error)) {
        return Scaffold(
          body: KEmpty(
            icon: LucideIcons.databaseZap,
            title: 'Dati dell\'app non leggibili',
            message: '$error',
            action: KButton(
              label: 'Riprova',
              icon: LucideIcons.refreshCw,
              onPressed: () => ref.invalidate(driveFolderProvider),
            ),
          ),
        );
      }
      return const SetupScreen();
    }
    // Tornata la rete, quello che senza non si era potuto leggere — la
    // libreria di Drive, gli indici di una serie mai aperta — si rilegge da
    // sé. Le tavole no: le riprova il magazzino delle fasce, che sa quali
    // sono sullo schermo.
    ref.listen(networkOnlineProvider, (was, online) {
      if (was != false || !online) return;
      final drive = ref.read(driveRepositoryProvider);
      if (drive == null) return;
      // Su una rete a scatti la connessione va e viene ogni pochi secondi:
      // rileggere a ogni ritorno vorrebbe dire due richieste ogni volta.
      final now = DateTime.now();
      final recent = _reloadedAt != null &&
          now.difference(_reloadedAt!) < const Duration(minutes: 1);
      if (recent && !drive.fromSnapshot) return;
      _reloadedAt = now;
      reloadLibrary(ref);
    });
    // La copia automatica si fa all'apertura, una volta: è l'unica cosa che
    // porta i dati personali fuori dal telefono.
    ref.watch(autoBackupRunProvider);
    // E, se c'è un account, si va a vedere cosa è successo sull'altro
    // telefono: il segno di lettura deve essere già al suo posto.
    ref.watch(cloudSyncRunProvider);
    // I capitoli nuovi si contano a ogni lettura della libreria, qualunque
    // destinazione sia aperta: tenerli vivi qui non ricostruisce la shell.
    ref.listen(arrivalsProvider, (_, _) {});
    // Le cartelle cambiate vanno scritte dove le legge il giro programmato,
    // anche se nessuno apre la schermata della sincronizzazione.
    ref.listen(folderSyncSettingsProvider, (_, _) {});

    final tab = ref.watch(shellTabProvider);
    return Scaffold(
      // La barra è sospesa sopra il contenuto, non sotto: sotto a una griglia
      // di copertine taglierebbe l'ultima riga con una fascia opaca.
      body: Stack(
        children: [
          _ShellTabs(tab: tab),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 12,
            // Con delle serie selezionate in libreria le azioni sulla
            // selezione prendono il posto della barra: sospesa com'è, le
            // coprirebbe.
            child: Consumer(
              builder: (context, ref, _) =>
                  tab == ShellTab.library &&
                          ref.watch(selectionProvider).isNotEmpty
                      ? const SizedBox.shrink()
                      : Center(
                          child: _NavBar(
                            index: tab.index,
                            onSelect: (index) => ref
                                .read(shellTabProvider.notifier)
                                .show(ShellTab.values[index]),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le destinazioni, una sopra l'altra, con un passaggio morbido fra loro.
///
/// Restano tutte montate: tornare in libreria non deve rileggere l'indice né
/// perdere la posizione della griglia. Il cambio però non è più di scatto:
/// la nuova sale e compare mentre la vecchia svanisce, e quel quarto di
/// secondo è anche il tempo in cui la nuova disegna il primo fotogramma.
class _ShellTabs extends StatefulWidget {
  const _ShellTabs({required this.tab});

  final ShellTab tab;

  @override
  State<_ShellTabs> createState() => _ShellTabsState();
}

class _ShellTabsState extends State<_ShellTabs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _switch = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );

  /// La destinazione che se ne va, finché il passaggio non è finito.
  ShellTab? _leaving;

  late final Animation<double> _enter = CurvedAnimation(
    parent: _switch,
    curve: Curves.easeOutCubic,
  );

  // La vecchia sparisce nella prima metà: due schermate piene sovrapposte a
  // lungo sono solo confusione.
  late final Animation<double> _exit = ReverseAnimation(CurvedAnimation(
    parent: _switch,
    curve: const Interval(0, 0.5, curve: Curves.easeOut),
  ));

  late final Animation<Offset> _rise = Tween<Offset>(
    begin: const Offset(0, 0.018),
    end: Offset.zero,
  ).animate(_enter);

  @override
  void initState() {
    super.initState();
    _switch.addStatusListener((status) {
      if (status.isCompleted && _leaving != null) {
        setState(() => _leaving = null);
      }
    });
  }

  @override
  void didUpdateWidget(_ShellTabs old) {
    super.didUpdateWidget(old);
    if (old.tab == widget.tab) return;
    _leaving = old.tab;
    _switch.forward(from: 0);
  }

  @override
  void dispose() {
    _switch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leaving = _leaving;
    return Stack(
      fit: StackFit.expand,
      children: [
        // L'ordine resta quello delle destinazioni: cambiarlo smonterebbe e
        // rimonterebbe le schermate. Chi sta sopra lo decide l'opacità.
        for (final destination in ShellTab.values)
          _layer(destination, leaving),
      ],
    );
  }

  Widget _layer(ShellTab destination, ShellTab? leaving) {
    final current = destination == widget.tab;
    final going = destination == leaving;
    final entering = current && leaving != null;
    // La struttura è la stessa per tutte e in ogni momento, cambiano solo le
    // animazioni: un involucro diverso smonterebbe la schermata.
    return Offstage(
      offstage: !current && !going,
      child: IgnorePointer(
        ignoring: going,
        child: FadeTransition(
          opacity: entering
              ? _enter
              : going
                  ? _exit
                  : kAlwaysCompleteAnimation,
          child: SlideTransition(
            position: entering ? _rise : _still,
            child: TickerMode(
              enabled: current,
              child: _screenOf(destination),
            ),
          ),
        ),
      ),
    );
  }

  static const Animation<Offset> _still = AlwaysStoppedAnimation(Offset.zero);
}

Widget _screenOf(ShellTab tab) => switch (tab) {
      ShellTab.home => const HomeScreen(),
      ShellTab.library => const LibraryScreen(),
      ShellTab.collections => const CollectionsScreen(),
      ShellTab.more => const MoreScreen(),
    };

const List<({IconData icon, String label})> _destinations = [
  (icon: LucideIcons.house, label: 'Home'),
  (icon: LucideIcons.libraryBig, label: 'Libreria'),
  (icon: LucideIcons.bookmark, label: 'Raccolte'),
  (icon: LucideIcons.ellipsis, label: 'Altro'),
];

/// La barra sospesa: una pastiglia che galleggia sul contenuto. L'etichetta
/// compare solo sulla destinazione scelta — le altre tre sono icone, e quattro
/// etichette insieme non ci stanno senza rimpicciolire tutto.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.tokens.line.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _destinations.length; i++)
            _NavItem(
              icon: _destinations[i].icon,
              label: _destinations[i].label,
              selected: i == index,
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(i);
              },
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final tint = selected ? scheme.primary : context.tokens.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 15 : 13,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: selected ? 0.16 : 0),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.06 : 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: Icon(icon, size: 20, color: tint),
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            label,
                            maxLines: 1,
                            softWrap: false,
                            style: KagamiType.label(size: 13, color: tint),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
