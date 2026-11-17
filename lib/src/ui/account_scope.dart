import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/account_databases.dart';
import '../data/library_location.dart';
import '../data/sources/secure_source_secrets.dart';
import '../data/sources/source.dart' show SourceSecrets;
import '../providers.dart';
import '../providers_sources.dart';

/// Il contenitore dei provider legato allo slot: cambiare account smonta e
/// ricrea tutto, così nessun consumatore tiene il repository del file vecchio
/// e `databaseProvider` chiude quel file (niente elenco di `invalidate`).
class AccountScope extends StatelessWidget {
  const AccountScope({
    super.key,
    required this.slots,
    required this.directories,
    required this.child,
    this.secrets,
  });

  final AccountSlots slots;
  final AppDirectories directories;
  final Widget child;

  /// `null`: le credenziali sul portachiavi del sistema.
  final SourceSecrets? secrets;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: slots,
        builder: (context, slot, _) => ProviderScope(
          key: ValueKey(slot),
          overrides: [
            appDirectoriesProvider.overrideWithValue(directories),
            sourceSecretsProvider.overrideWithValue(secrets ?? SecureSourceSecrets()),
            accountSlotsProvider.overrideWithValue(slots),
            databaseSlotProvider.overrideWithValue(slot),
          ],
          child: child,
        ),
      );
}
