/// Altro: quello che non si guarda tutti i giorni ma deve esserci.
///
/// Cronologia, statistiche e impostazioni stanno dietro una destinazione sola
/// perché sono i posti in cui si entra di proposito, non quelli in cui si
/// passa scorrendo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../providers.dart';
import 'app_shell.dart';
import 'archive_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'theme.dart';
import 'widgets/kit.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final incognito = ref.watch(incognitoProvider).value ?? false;
    void open(Widget screen) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => screen),
        );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, navBarInset),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Text(l10n.moreTitle, style: KagamiType.display(30)),
            ),
            KSection(l10n.moreSectionLibrary),
            KGroup(
              children: [
                KTile(
                  icon: LucideIcons.download,
                  title: l10n.moreDownload,
                  subtitle: l10n.moreDownloadSubtitle,
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => open(const ArchiveScreen()),
                ),
              ],
            ),
            const SizedBox(height: 26),
            KSection(l10n.moreSectionReading),
            KGroup(
              children: [
                KTile(
                  icon: LucideIcons.history,
                  title: l10n.moreHistory,
                  subtitle: l10n.moreHistorySubtitle,
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => open(const HistoryScreen()),
                ),
                KTile(
                  icon: LucideIcons.chartColumn,
                  title: l10n.moreStatistics,
                  subtitle: l10n.moreStatisticsSubtitle,
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => open(const StatisticsScreen()),
                ),
              ],
            ),
            const SizedBox(height: 26),
            KSection(l10n.moreSectionPrivacy),
            KGroup(
              children: [
                KTile(
                  icon: incognito ? LucideIcons.eyeOff : LucideIcons.eye,
                  title: l10n.moreIncognito,
                  subtitle: l10n.moreIncognitoSubtitle,
                  tint: incognito ? context.colors.primary : null,
                  onTap: ref.read(incognitoProvider.notifier).toggle,
                  trailing: Switch(
                    value: incognito,
                    onChanged: (_) =>
                        ref.read(incognitoProvider.notifier).toggle(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            KSection(l10n.moreSectionApp),
            KGroup(
              children: [
                KTile(
                  icon: LucideIcons.settings,
                  title: l10n.moreSettings,
                  subtitle: l10n.moreSettingsSubtitle,
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => open(const SettingsScreen()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
