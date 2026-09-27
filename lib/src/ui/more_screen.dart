/// Altro: quello che non si guarda tutti i giorni ma deve esserci.
///
/// Cronologia, statistiche e impostazioni stanno dietro una destinazione sola
/// perché sono i posti in cui si entra di proposito, non quelli in cui si
/// passa scorrendo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
              child: Text('Altro', style: KagamiType.display(30)),
            ),
            const KSection('Libreria'),
            KGroup(
              children: [
                KTile(
                  icon: LucideIcons.download,
                  title: 'Scarica un manga',
                  subtitle: 'Cerca un titolo o incolla un link',
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => open(const ArchiveScreen()),
                ),
              ],
            ),
            const SizedBox(height: 26),
            const KSection('La tua lettura'),
            KGroup(
              children: [
                KTile(
                  icon: LucideIcons.history,
                  title: 'Cronologia',
                  subtitle: 'Cosa hai letto e quando',
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => open(const HistoryScreen()),
                ),
                KTile(
                  icon: LucideIcons.chartColumn,
                  title: 'Statistiche',
                  subtitle: 'Quanto leggi, cosa leggi, quando',
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => open(const StatisticsScreen()),
                ),
              ],
            ),
            const SizedBox(height: 26),
            const KSection('Privatezza'),
            KGroup(
              children: [
                KTile(
                  icon: incognito ? LucideIcons.eyeOff : LucideIcons.eye,
                  title: 'Lettura in incognito',
                  subtitle: 'Non registra posizione, capitoli finiti né '
                      'tempo di lettura',
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
            const KSection('App'),
            KGroup(
              children: [
                KTile(
                  icon: LucideIcons.settings,
                  title: 'Impostazioni',
                  subtitle: 'Aspetto, libreria, lettura, backup',
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
