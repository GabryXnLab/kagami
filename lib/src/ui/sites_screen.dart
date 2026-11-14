/// «Siti»: quelli inclusi nell'app e quelli che l'utente aggiunge con un file
/// (`docs/siti.md`, `docs/design.md` § «Siti degli utenti»).
///
/// Il file non contiene codice: l'unica cosa che conta per fidarsene sono gli
/// host a cui il sito chiederà le pagine, e l'anteprima li mostra prima di
/// installare. Gli errori di [SiteDefinitionError] sono in italiano fisso, il
/// motore non ha una lingua: qui si dice in generale cosa è andato storto e il
/// messaggio tecnico sta sotto, in piccolo.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/http.dart';
import 'package:kagami_archive/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/drive.dart' show DriveAuthRequired;
import '../data/user_sites.dart';
import '../l10n.dart';
import 'theme.dart';
import 'widgets/kit.dart';

class SitesScreen extends ConsumerWidget {
  const SitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final muted = context.tokens.muted;
    final sites = ref.watch(userSitesProvider).value ?? const UserSites();
    // Un file rovinato senza il sito di prima non è in `sites`.
    final orphans = [
      for (final file in sites.errors.keys)
        if (sites.byId(_idOf(file)) == null) _idOf(file),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sitesTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          KSection(l10n.sitesBuiltInSection),
          KGroup(
            children: [
              for (final site in builtInProviders)
                KTile(
                  icon: LucideIcons.globe,
                  leading: _icon(site),
                  title: site.name,
                  subtitle: Uri.parse(site.home).host,
                ),
            ],
          ),
          const SizedBox(height: 24),
          KSection(l10n.sitesAddedSection),
          if (sites.sites.isEmpty && orphans.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(l10n.sitesNoneAdded, style: KagamiType.body(13, color: muted)),
            )
          else
            KGroup(
              children: [
                for (final site in sites.sites)
                  KTile(
                    icon: LucideIcons.globe,
                    leading: _icon(site),
                    title: site.name,
                    subtitle: _subtitle(context, sites, site),
                    trailing: sites.errors.containsKey('${site.id}.json')
                        ? Icon(LucideIcons.triangleAlert, size: 18, color: context.tokens.danger)
                        : const Icon(LucideIcons.ellipsis, size: 18),
                    onTap: () => _actions(context, ref, site.id, site),
                  ),
                for (final id in orphans)
                  KTile(
                    icon: LucideIcons.fileWarning,
                    title: id,
                    subtitle: l10n.sitesBroken,
                    trailing: Icon(LucideIcons.triangleAlert, size: 18, color: context.tokens.danger),
                    onTap: () => _actions(context, ref, id, null),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          if (!sites.hasLibrary)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(l10n.sitesNoLibrary, style: KagamiType.body(12.5, height: 1.45, color: muted)),
            ),
          KButton(
            label: l10n.sitesAdd,
            icon: LucideIcons.plus,
            expand: true,
            onPressed: sites.hasLibrary ? () => AddSitePage.open(context) : null,
          ),
        ],
      ),
    );
  }

  static String _idOf(String file) => file.endsWith('.json') ? file.substring(0, file.length - 5) : file;

  Widget _icon(Provider site) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SiteIcon(site, size: 36),
      );

  String _subtitle(BuildContext context, UserSites sites, DeclarativeProvider site) {
    final l10n = context.l10n;
    return [
      l10n.sitesVersion(site.version),
      if (sites.unconfirmed.contains(site.id))
        l10n.sitesUnconfirmed(providerNameOf(site.id))
      else if (sites.replacesBuiltIn(site.id))
        l10n.sitesReplaces(providerNameOf(site.id)),
      if (sites.errors.containsKey('${site.id}.json')) l10n.sitesBroken,
    ].join(' · ');
  }

  void _actions(BuildContext context, WidgetRef ref, String id, DeclarativeProvider? site) {
    showKagamiSheet<void>(
      context,
      title: site?.name ?? id,
      builder: (sheet) {
        final l10n = sheet.l10n;
        final error = ref.read(userSitesProvider).value?.errors['$id.json'];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Text(error, style: KagamiType.body(11.5, height: 1.4, color: sheet.tokens.muted)),
              ),
            if (site != null && ref.read(userSitesProvider).value?.unconfirmed.contains(id) == true)
              KTile(
                icon: LucideIcons.check,
                title: l10n.sitesConfirmReplace(providerNameOf(id)),
                onTap: () {
                  Navigator.pop(sheet);
                  unawaited(ref.read(userSitesProvider.notifier).confirmReplacement(id));
                },
              ),
            if (site?.updateUrl != null)
              KTile(
                icon: LucideIcons.refreshCw,
                title: l10n.sitesUpdateNow,
                onTap: () {
                  Navigator.pop(sheet);
                  unawaited(_update(context, ref));
                },
              ),
            KTile(
              icon: LucideIcons.trash2,
              title: l10n.sitesRemove,
              tint: sheet.tokens.danger,
              onTap: () {
                Navigator.pop(sheet);
                unawaited(_remove(context, ref, id, site?.name ?? id));
              },
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Future<void> _update(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final updated = await ref.read(userSitesProvider.notifier).checkUpdates(force: true);
      messenger.showSnackBar(SnackBar(content: Text(updated.isEmpty ? l10n.sitesUpToDate : l10n.sitesUpdated)));
    } on DriveAuthRequired {
      return;
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String id, String name) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.sitesRemoveTitle(name)),
        content: Text(l10n.sitesRemoveBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.archiveCancel)),
          TextButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.sitesRemove)),
        ],
      ),
    );
    if (!(sure ?? false)) return;
    try {
      await ref.read(userSitesProvider.notifier).remove(id);
    } on DriveAuthRequired {
      return;
    } on SiteDefinitionError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.sitesInvalid}: ${error.message}')));
    }
  }
}

/// Il nome del sito incluso con l'id [id], per «sostituisce …».
String providerNameOf(String id) {
  for (final site in builtInProviders) {
    if (site.id == id) return site.name;
  }
  return id;
}

/// «Aggiungi un sito»: il link o il testo del file, l'anteprima, la prova
/// facoltativa, «Installa».
class AddSitePage extends ConsumerStatefulWidget {
  const AddSitePage({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AddSitePage()));

  @override
  ConsumerState<AddSitePage> createState() => _AddSitePageState();
}

/// Un errore in due livelli: cosa è andato storto in generale, e il messaggio
/// tecnico.
class _Problem {
  const _Problem(this.title, this.detail);

  final String title;
  final String detail;
}

class _AddSitePageState extends ConsumerState<AddSitePage> {
  final _source = TextEditingController();
  final _probe = TextEditingController();
  DeclarativeProvider? _site;
  _Problem? _problem;
  String? _probeResult;
  _Problem? _probeProblem;
  bool _busy = false;

  @override
  void dispose() {
    _source.dispose();
    _probe.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    _source.text = data!.text!;
  }

  Future<void> _check() async {
    final text = _source.text.trim();
    if (text.isEmpty) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _site = null;
      _problem = null;
      _probeResult = null;
      _probeProblem = null;
    });
    DeclarativeProvider? site;
    _Problem? problem;
    try {
      site = text.startsWith('https://')
          ? await ref.read(userSitesProvider.notifier).fetchDefinition(text)
          : DeclarativeProvider.parse(text);
    } on SiteDefinitionError catch (error) {
      problem = _Problem(l10n.sitesInvalid, error.message);
    } on Object catch (error) {
      problem = _Problem(l10n.sitesFetchFailed, '$error');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _site = site;
      _problem = problem;
    });
  }

  Future<void> _try() async {
    final site = _site;
    final text = _probe.text.trim();
    if (site == null || text.isEmpty) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _probeResult = null;
      _probeProblem = null;
    });
    final http = SiteHttp(site.allowedHost, publicOnly: !site.builtIn);
    String? result;
    _Problem? problem;
    try {
      if (text.startsWith('https://')) {
        final series = await site.fetchSeries(text, http);
        result = l10n.sitesTrySeries(series.title, series.chapters.length);
      } else {
        final found = await site.search(text, http);
        result = l10n.sitesTryResults(found.length, found.isEmpty ? '' : found.first.title);
      }
    } on Object catch (error) {
      problem = _Problem(l10n.sitesTryFailed, error is SiteDefinitionError ? error.message : '$error');
    } finally {
      http.close();
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _probeResult = result;
      _probeProblem = problem;
    });
  }

  Future<void> _install() async {
    final site = _site;
    if (site == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(userSitesProvider.notifier).install(site);
    } on DriveAuthRequired {
      if (mounted) setState(() => _busy = false);
      return;
    } on SiteDefinitionError catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = _Problem(l10n.sitesInvalid, error.message);
        });
      }
      return;
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = _Problem(l10n.sitesFetchFailed, '$error');
        });
      }
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.sitesInstalled(site.name))));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = context.tokens.muted;
    final site = _site;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sitesAdd)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          TextField(
            key: const Key('siteSource'),
            controller: _source,
            enabled: !_busy,
            minLines: 1,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: l10n.sitesAddHint,
              prefixIcon: const Icon(LucideIcons.link, size: 18),
              suffixIcon: IconButton(
                icon: const Icon(LucideIcons.clipboardPaste, size: 18),
                onPressed: _busy ? null : _paste,
              ),
            ),
          ),
          const SizedBox(height: 12),
          KButton(label: l10n.sitesAddCheck, expand: true, onPressed: _busy ? null : _check),
          if (_problem != null) ...[
            const SizedBox(height: 12),
            _ProblemText(_problem!),
          ],
          if (site != null) ...[
            const SizedBox(height: 24),
            KCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: SiteIcon(site, size: 36)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(site.name, style: KagamiType.display(16)),
                            Text(l10n.sitesVersion(site.version), style: KagamiType.body(12.5, color: muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (builtInProviders.any((built) => built.id == site.id)) ...[
                    const SizedBox(height: 10),
                    Text(
                      l10n.sitesReplaces(providerNameOf(site.id)),
                      style: KagamiType.body(13, color: context.colors.primary),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(l10n.sitesPreviewHosts, style: KagamiType.body(12.5, color: muted)),
                  const SizedBox(height: 4),
                  for (final host in site.hosts) Text(host, style: KagamiType.body(13.5)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            KSection(l10n.sitesTryTitle),
            TextField(
              key: const Key('siteProbe'),
              controller: _probe,
              enabled: !_busy,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _try(),
              decoration: InputDecoration(
                hintText: l10n.sitesTryHint,
                prefixIcon: const Icon(LucideIcons.search, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            KGhostButton(label: l10n.sitesTry, onPressed: _busy ? null : _try),
            if (_probeResult != null) ...[
              const SizedBox(height: 10),
              Text(_probeResult!, style: KagamiType.body(13.5)),
            ],
            if (_probeProblem != null) ...[
              const SizedBox(height: 10),
              _ProblemText(_probeProblem!),
            ],
            const SizedBox(height: 24),
            KButton(label: l10n.sitesInstall, icon: LucideIcons.download, expand: true, onPressed: _busy ? null : _install),
          ],
        ],
      ),
    );
  }
}

class _ProblemText extends StatelessWidget {
  const _ProblemText(this.problem);

  final _Problem problem;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(problem.title, style: KagamiType.body(13, height: 1.45, color: context.tokens.danger)),
          const SizedBox(height: 2),
          Text(problem.detail, style: KagamiType.body(11, height: 1.4, color: context.tokens.muted)),
        ],
      );
}
