/// La scheda manuale: un manga che Kagami non sa scaricare — senza link, o
/// col link di un sito non registrato — salvato nella libreria con titolo,
/// copertina, al più un link e lo stato dell'utente.
///
/// Il modulo vive nello stesso percorso di `archive_series.dart` (stessi
/// campi del ripiano, stessa destinazione), ma non passa dalla coda: non c'è
/// niente da scaricare, la scheda si scrive subito. La scrittura vera è
/// `saveManualCard`, usabile senza interfaccia.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/manual.dart';
import 'package:kagami_archive/model.dart';
import 'package:kagami_archive/providers.dart';
import 'package:kagami_archive/stores.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

import '../archive/device.dart';
import '../archive/manual_card.dart';
import '../data/cloud.dart';
import '../data/drive.dart';
import '../data/network.dart';
import '../format/reading.dart';
import '../l10n.dart';
import '../providers.dart';
import 'archive_series.dart';
import 'drive_ui.dart';
import 'library_screen.dart' show seriesRoute;
import 'theme.dart';
import 'widgets/kit.dart';

/// Dove una scheda manuale si scrive: mai sul server, che non ha niente da
/// scaricare.
enum ManualWhere { drive, phone }

/// Lo store in cui scrivere schede, e come chiuderlo.
class ManualTarget {
  const ManualTarget(this.store, this.where, this.close);

  final ArchiveStore store;
  final ManualWhere where;

  /// Chiude il client di Drive; da chiamare a fine uso.
  final void Function() close;
}

/// Drive se la libreria ne ha la cartella, altrimenti il telefono.
ManualWhere manualWhere(WidgetRef ref) =>
    cloudAvailable && ref.read(driveFolderProvider).value != null ? ManualWhere.drive : ManualWhere.phone;

/// Apre lo store per scrivere schede, chiedendo il permesso di scrivere su
/// Drive o la cartella del telefono, se servono. Gli errori li dice con uno
/// snackbar e restituisce `null`, come l'utente che rinuncia.
Future<ManualTarget?> openManualTarget(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = currentL10n();
  if (manualWhere(ref) == ManualWhere.drive) {
    final folder = ref.read(driveFolderProvider).value!;
    try {
      await ref.read(driveAuthProvider).authorize(write: true);
    } on DriveAuthRequired {
      messenger.showSnackBar(SnackBar(content: Text(l10n.archiveManualNeedsDrive)));
      return null;
    } on DriveException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return null;
    }
    final client = DriveClient(ref.read(driveAuthProvider).writeToken, network: NetworkMonitor.instance);
    final store = DriveStore(
      remote: DriveSyncRemote(client),
      folderId: folder.id,
      staging: ref.read(archiveFilesProvider).staging(folder.id).path,
    );
    return ManualTarget(store, ManualWhere.drive, client.close);
  }
  final root = await downloadDestination(context, ref);
  if (root == null) return null;
  final private = root == ref.read(appDirectoriesProvider).privateLibrary;
  return ManualTarget(LocalStore(root, hideFromGallery: !private), ManualWhere.phone, () {});
}

/// Il testo di un errore nello scrivere una scheda.
String manualErrorText(Object error) => switch (error) {
      DriveOffline() || ProviderOffline() => currentL10n().archiveErrOffline,
      DriveException(:final message) => message,
      ProviderError(:final message) => message,
      _ => currentL10n().archiveManualFailed('$error'),
    };

class ManualCardPage extends ConsumerStatefulWidget {
  const ManualCardPage({this.link, super.key});

  /// Il link con cui si apre, già compilato.
  final String? link;

  /// Apre il modulo. Restituisce il link da leggere col percorso normale se
  /// l'utente, incollandone uno di un sito supportato, sceglie quello;
  /// `null` altrimenti, anche dopo aver salvato.
  static Future<String?> open(BuildContext context, {String? link}) =>
      Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => ManualCardPage(link: link)));

  @override
  ConsumerState<ManualCardPage> createState() => _ManualCardPageState();
}

class _ManualCardPageState extends ConsumerState<ManualCardPage> {
  late final TextEditingController _title = TextEditingController();
  late final TextEditingController _link = TextEditingController(text: widget.link ?? '');
  final TextEditingController _reached = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  ShelfStatus _status = ShelfStatus.none;
  int? _rating;
  bool _favorite = false;
  bool _saving = false;
  bool _titleError = false;

  /// Titolo e copertina letti dalla pagina del link: il titolo si riempie
  /// da solo solo finché l'utente non ci mette mano.
  bool _titleFromPage = false;
  String? _coverUrl;
  String? _fetched;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _linkChanged();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final controller in [_title, _link, _reached, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Il link è di un sito che Kagami sa leggere: la scheda manuale non è la
  /// strada.
  bool get _supported {
    final text = _link.text.trim();
    if (text.isEmpty) return false;
    try {
      resolveLink(text);
      return true;
    } on UnsupportedLink {
      return false;
    }
  }

  void _linkChanged() {
    _debounce?.cancel();
    final text = _link.text.trim();
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || _supported) {
      setState(() => _coverUrl = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 700), () => _readPage(text));
    setState(() {});
  }

  Future<void> _readPage(String link) async {
    if (_fetched == link) return;
    _fetched = link;
    final meta = await fetchPageMeta(link);
    if (!mounted || _link.text.trim() != link) return;
    setState(() {
      _coverUrl = meta.image;
      if (meta.title != null && (_title.text.trim().isEmpty || _titleFromPage)) {
        _title.text = meta.title!;
        _titleFromPage = true;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      return;
    }
    final link = _link.text.trim();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      if (link.isNotEmpty) {
        final catalog = await ref.read(libraryCatalogProvider.future);
        final known = entryForLink(catalog.index, link);
        if (known != null) {
          messenger.showSnackBar(SnackBar(content: Text(l10n.archiveManualExists(known.title))));
          if (mounted) navigator.pushReplacement(seriesRoute(known.key));
          return;
        }
      }
      if (!mounted) return;
      final target = await openManualTarget(context, ref);
      if (target == null) return;
      try {
        await saveManualCard(
          target.store,
          ref.read(readingProvider.notifier),
          ManualCard(
            title: title,
            link: link.isEmpty ? null : link,
            coverUrl: link.isEmpty ? null : _coverUrl,
            reached: _reached.text.trim().isEmpty ? null : _reached.text.trim(),
            status: _status,
            rating: _rating,
            notes: _notes.text,
            favorite: _favorite,
          ),
          scratch: Directory(p.join(ref.read(appDirectoriesProvider).cache, 'archive')),
          images: NativeImageTools.platform,
        );
      } finally {
        target.close();
      }
      if (!mounted) return;
      reloadLibrary(ref);
      messenger.showSnackBar(SnackBar(content: Text(l10n.archiveManualSaved(title))));
      navigator.pop();
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(manualErrorText(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final supported = _supported;
    final where = manualWhere(ref);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.archiveManualTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          if (_coverUrl != null) ...[
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  _coverUrl!,
                  height: 160,
                  fit: BoxFit.cover,
                  headers: {'Referer': _link.text.trim(), 'User-Agent': defaultUserAgent},
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {
              _titleFromPage = false;
              _titleError = false;
            }),
            decoration: InputDecoration(
              hintText: l10n.archiveManualTitleHint,
              errorText: _titleError ? l10n.archiveManualTitleRequired : null,
              prefixIcon: const Icon(LucideIcons.bookOpen, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _link,
            keyboardType: TextInputType.url,
            onChanged: (_) => _linkChanged(),
            decoration: InputDecoration(
              hintText: l10n.archiveManualLinkHint,
              prefixIcon: const Icon(LucideIcons.link, size: 18),
            ),
          ),
          if (supported) ...[
            const SizedBox(height: 12),
            KCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.archiveManualSupported,
                    style: KagamiType.body(13, height: 1.45, color: tokens.warning),
                  ),
                  const SizedBox(height: 10),
                  KButton(
                    label: l10n.archiveManualSupportedAction,
                    icon: LucideIcons.search,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(_link.text.trim()),
                  ),
                ],
              ),
            ),
          ] else if (_link.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n.archiveManualNoDownload,
              style: KagamiType.body(12.5, height: 1.4, color: tokens.muted),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _reached,
            decoration: InputDecoration(
              hintText: l10n.archiveManualReachedHint,
              prefixIcon: const Icon(LucideIcons.bookmark, size: 18),
            ),
          ),
          const SizedBox(height: 4),
          ArchiveShelfFields(
            status: _status,
            favorite: _favorite,
            rating: _rating,
            notes: _notes,
            onStatus: (value) => setState(() => _status = value),
            onFavorite: () => setState(() => _favorite = !_favorite),
            onRating: (value) => setState(() => _rating = value),
          ),
          const SizedBox(height: 16),
          Text(
            where == ManualWhere.drive ? l10n.archiveManualWhereDrive : l10n.archiveManualWherePhone,
            style: KagamiType.body(12.5, height: 1.4, color: tokens.muted),
          ),
          const SizedBox(height: 12),
          KButton(
            label: l10n.archiveManualSave,
            icon: LucideIcons.bookmarkPlus,
            expand: true,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
