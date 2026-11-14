/// Quando il profilo esce: negli stessi tre momenti della sincronizzazione
/// (avvio, uscita, a richiesta) e solo se è cambiato. Contratto in
/// `docs/social.md`, «La radio resta spenta».
library;

import 'backend.dart';
import 'profile.dart';

enum SocialPublish {
  /// Social spento: nessuna chiamata, il profilo non è nemmeno costruito.
  disabled,

  /// Acceso ma senza un soprannome valido: il backend lo rifiuterebbe.
  incomplete,

  /// Uguale all'ultimo pubblicato: nessuna chiamata.
  unchanged,
  published,
}

class SocialSync {
  const SocialSync({required this.backend, required this.readPublished, required this.writePublished});

  /// L'impostazione con l'impronta ([PublicProfile.fingerprint]) dell'ultimo
  /// profilo pubblicato. Non è fra [SocialSettings.keys]: non è una scelta
  /// dell'utente.
  static const String publishedKey = 'social.published';

  final SocialBackend backend;
  final Future<String?> Function() readPublished;
  final Future<void> Function(String? fingerprint) writePublished;

  /// Pubblica il profilo che [build] costruisce (con `buildPublicProfile`,
  /// che tiene fuori le serie nascoste) se il social è acceso e il profilo è
  /// cambiato; [force], a richiesta, lo riscrive comunque. Un errore del
  /// backend passa a chi chiama, e l'impronta non si aggiorna.
  Future<SocialPublish> publish(
    SocialSettings settings,
    Future<PublicProfile> Function() build, {
    bool force = false,
  }) async {
    if (!settings.enabled) return SocialPublish.disabled;
    if (!settings.hasValidName) return SocialPublish.incomplete;
    final profile = await build();
    final fingerprint = profile.fingerprint;
    if (!force && await readPublished() == fingerprint) return SocialPublish.unchanged;
    await backend.publish(profile);
    await writePublished(fingerprint);
    return SocialPublish.published;
  }

  /// Esce: il backend toglie il profilo e, a cascata, tutto ciò che è suo; i
  /// blocchi restano. L'impronta si dimentica, così chi rientra ripubblica.
  Future<void> leave() async {
    await backend.withdraw();
    await writePublished(null);
  }
}
