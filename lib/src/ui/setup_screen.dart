/// Primo avvio: il permesso e la cartella.
///
/// Il permesso che l'app chiede su Android è l'accesso a tutti i file, e va
/// spiegato: è una richiesta grossa, la si concede solo capendo a cosa serve.
/// Vedere `docs/design.md`.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/cloud.dart';
import '../l10n.dart';
import '../providers.dart';
import 'drive_ui.dart';
import 'theme.dart';
import 'widgets/kit.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  bool _granted = !Platform.isAndroid;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final location = await ref.read(libraryLocationProvider.future);
    final granted = await location.hasAccess();
    if (mounted) setState(() => _granted = granted);
  }

  Future<void> _request() async {
    setState(() => _working = true);
    final location = await ref.read(libraryLocationProvider.future);
    final granted = await location.requestAccess();
    if (mounted) {
      setState(() {
        _granted = granted;
        _working = false;
      });
    }
  }

  Future<void> _choose() async {
    setState(() => _working = true);
    final location = await ref.read(libraryLocationProvider.future);
    final chosen = await location.choose();
    if (!mounted) return;
    setState(() => _working = false);
    if (chosen != null) ref.read(libraryRootProvider.notifier).select(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(LucideIcons.bookOpen,
                        size: 30, color: scheme.primary),
                  ),
                  const SizedBox(height: 22),
                  Text('Kagami', style: KagamiType.display(32)),
                  const SizedBox(height: 8),
                  Text(
l10n.setupIntro,
                    style:
                        KagamiType.body(14, color: context.tokens.muted),
                  ),
                  const SizedBox(height: 30),
                  if (!_granted) ...[
                    _Step(
                      number: '1',
                      title: l10n.setupAccessTitle,
                      body: l10n.setupAccessBody,
                    ),
                    const SizedBox(height: 22),
                    KButton(
                      label: l10n.setupGrantAccess,
                      icon: LucideIcons.shieldCheck,
                      expand: true,
                      onPressed: _working ? null : _request,
                    ),
                  ] else ...[
                    _Step(
                      number: '2',
                      title: l10n.setupFolderTitle,
                      body: l10n.setupFolderBody,
                    ),
                    const SizedBox(height: 22),
                    KButton(
                      label: l10n.setupChooseFolder,
                      icon: LucideIcons.folderOpen,
                      expand: true,
                      onPressed: _working ? null : _choose,
                    ),
                  ],
                  if (cloudAvailable) ...[
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(child: Divider(color: context.tokens.line)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            l10n.setupOr,
                            style: KagamiType.label(
                              size: 12,
                              color: context.tokens.muted,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: context.tokens.line)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _Step(
                      icon: LucideIcons.cloud,
                      title: l10n.setupDriveTitle,
                      body: l10n.setupDriveBody,
                    ),
                    const SizedBox(height: 16),
                    KGhostButton(
                      label: l10n.setupReadFromDrive,
                      icon: LucideIcons.cloud,
                      expand: true,
                      onPressed: _working ? null : () => connectDrive(context, ref),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.title,
    required this.body,
    this.number,
    this.icon,
  });

  final String? number;
  final IconData? icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => KCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: icon != null
                  ? Icon(icon, size: 15)
                  : Text(number ?? '', style: KagamiType.figure(13)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: KagamiType.title(15, weight: 700)),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: KagamiType.body(
                      13,
                      height: 1.5,
                      color: context.tokens.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Una libreria che non si riesce a leggere: il messaggio spiega cosa manca
/// e offre il gesto che ci rimedia — rileggere, cambiare cartella, dare il
/// permesso su Drive.
class LibraryProblemView extends ConsumerWidget {
  const LibraryProblemView({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (message, action, onPressed) = noticeOf(context, ref, error);
    return KEmpty(
      icon: LucideIcons.folderX,
      title: context.l10n.setupLibraryProblemTitle,
      message: message,
      action: Column(
        children: [
          KButton(
            label: action,
            icon: LucideIcons.refreshCw,
            onPressed: onPressed,
          ),
          if (ref.watch(libraryRootProvider) != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () async {
                final location =
                    await ref.read(libraryLocationProvider.future);
                final chosen = await location.choose();
                if (chosen != null) {
                  ref.read(libraryRootProvider.notifier).select(chosen);
                }
              },
              child: Text(context.l10n.setupChangeFolder),
            ),
          ],
        ],
      ),
    );
  }
}
