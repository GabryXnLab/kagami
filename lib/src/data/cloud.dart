/// L'account: i dati personali che seguono il lettore invece del telefono.
///
/// La libreria resta locale — l'app non scarica niente e non conosce nessun
/// sito — ma quello che il lettore ci ha fatto sopra (stato, voti, capitoli
/// letti, cronologia, raccolte, segnalibri, impostazioni) vive nel database
/// dell'app, e fin qui l'unico modo di portarselo su un altro telefono era il
/// backup. Con un account è lo stesso backup, che però va e torna da sé.
///
/// Quello che viaggia è esattamente il file che [BackupService] esporta: gli
/// stessi byte compressi, dentro una riga sola. Sembra pigrizia e non lo
/// è — le regole con cui due copie dei dati si fondono esistono già, sono
/// quelle del backup e sono provate: i capitoli letti si sommano, sul resto
/// vince il record con `updatedAt` più recente. Un secondo meccanismo di
/// fusione, campo per campo nel backend, sarebbe stato una seconda occasione
/// di perdere qualcosa.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n.dart';
import 'backend.dart';
import 'backup.dart';
import 'db/account_databases.dart' show sessionOwnsSlot;
import 'user_repository.dart';

/// Se in questa build l'account esiste.
///
/// Serve il backend di chi ha compilato (`BACKEND_URL`, vedi `backend.dart`)
/// e l'accesso con Google, che c'è solo su Android: senza, la sezione
/// «Account» e Drive dicono che non ci sono, invece di offrire un pulsante
/// che fallirebbe. Lo decide [initCloud], prima del primo fotogramma.
bool get cloudAvailable => _cloudAvailable;
var _cloudAvailable = false;

/// Il client OAuth «Web» per cui Google firma il token d'identità. Vuoto: lo
/// ricava `google_sign_in` da `google-services.json`, come sempre.
const String _serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

/// Apre il backend e l'accesso con Google. Va chiamata prima di `runApp`: la
/// sessione salvata si ripristina qui, e senza di essa l'app all'avvio si
/// crederebbe scollegata per un istante.
Future<void> initCloud() async {
  if (!Platform.isAndroid) return;
  final client = await openBackend();
  if (client == null) return;
  try {
    await GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
  } on Exception {
    return;
  }
  _cloudAvailable = true;
  _resuming = const CloudAuth()._resumeSilently();
}

Future<void>? _resuming;

/// Chi ha fatto l'accesso, come lo si mostra.
class CloudAccount {
  const CloudAccount({
    required this.id,
    required this.email,
    this.name,
    this.photo,
  });

  final String id;
  final String email;
  final String? name;
  final String? photo;

  /// Il nome di Google se c'è, altrimenti l'indirizzo: qualcosa da scrivere
  /// accanto all'avatar c'è sempre.
  String get label => name != null && name!.isNotEmpty ? name! : email;
}

/// Come è andata l'ultima sincronizzazione. Serve dirlo: una copia dei propri
/// dati di cui non si sa quando è stata fatta non è una garanzia.
class CloudStatus {
  const CloudStatus({
    this.account,
    this.busy = false,
    this.lastSyncAt,
    this.error,
  });

  final CloudAccount? account;
  final bool busy;
  final DateTime? lastSyncAt;
  final String? error;

  bool get signedIn => account != null;

  CloudStatus copyWith({
    CloudAccount? account,
    bool? busy,
    DateTime? lastSyncAt,
    String? error,
    bool clearError = false,
  }) =>
      CloudStatus(
        account: account ?? this.account,
        busy: busy ?? this.busy,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        error: clearError ? null : error ?? this.error,
      );
}

/// Quando qualcosa non va, il perché in una riga.
class CloudException implements Exception {
  const CloudException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Perché non ha funzionato, in una riga leggibile.
///
/// Sta qui e non nel grafo delle dipendenze perché i tipi degli errori sono
/// quelli del backend e di dart:io: il resto dell'app non deve conoscerli.
String cloudMessage(Object error) => switch (error) {
      CloudException(:final message) => message,
      // L'unico vincolo `check` di `readers` è il tetto di 16 MiB
      // (`readers_data_size`, migrazione 0008): riprovare non serve.
      PostgrestException(code: '23514') => currentL10n().dataCloudTooLarge,
      _ => switch (backendFailure(error)) {
          BackendFailure.offline => currentL10n().dataCloudNoConnection,
          BackendFailure.signedOut => currentL10n().dataCloudNoSignIn,
          BackendFailure.unavailable => currentL10n().dataCloudBackendUnavailable,
          BackendFailure.other => currentL10n().dataSyncFailed,
        },
    };

/// Il viaggio dei dati personali: di là e di qua.
class CloudSync {
  CloudSync(
    this.backup,
    this.user,
    this.store, {
    required this.slot,
    required this.sessionUid,
  });

  /// Da quando ci si è sincronizzati l'ultima volta: lo si ricorda nelle
  /// impostazioni, che il backup si porta dietro come tutto il resto.
  static const String lastSyncKey = 'cloud.lastSync';

  final BackupService backup;
  final UserRepository user;

  /// La riga del lettore nel backend. Le regole di sicurezza non lasciano
  /// nessuna strada verso quella di qualcun altro.
  final ReaderStore store;

  /// Lo slot del database di [user] e [backup].
  final String slot;

  /// L'uid della sessione di adesso (`null` = nessuna): chiesto a ogni giro,
  /// perché la sessione cambia sotto il contenitore prima che lo slot lo segua.
  final String? Function() sessionUid;

  bool get _owned => sessionOwnsSlot(slot, sessionUid());

  /// La `revision` della riga com'era l'ultima volta che la si è letta o
  /// scritta da qui, in memoria: `null` finché in questo processo non la si è
  /// mai fusa, cioè sempre all'avvio.
  String? _seen;

  /// Prende quello che c'è in rete, lo fonde con quello che c'è qui, e
  /// rimanda su il risultato. Dice anche se ha fuso: solo allora il database
  /// è cambiato sotto l'app.
  ///
  /// Fondere in tutt'e due le direzioni invece di scegliere un vincitore è ciò
  /// che rende innocuo leggere due capitoli su un telefono e tre sull'altro
  /// senza aver aperto l'app nel mezzo.
  ///
  /// Non c'è un invio senza fusione, nemmeno uscendo dall'app: la riga
  /// remota si sostituisce per intero, e un telefono che la scrive senza averla
  /// letto cancella ciò che c'era. Succedeva reinstallando: Android rimetteva
  /// il database com'era al suo ultimo backup, e la prima uscita dall'app —
  /// per concedere l'accesso ai file, prima ancora della sincronizzazione
  /// d'avvio — mandava su quella copia vecchia al posto di quella giusta.
  /// La lettura costa una riga; la fusione si salta se la `revision` è
  /// quella che questo processo ha già visto, cioè nessun altro ha scritto.
  ///
  /// Una lettura fallita lancia prima di qualunque scrittura; una riga che non
  /// c'è ancora (`null`) fa mandare su i dati di qui senza fondere niente.
  ///
  /// `null`: la sessione non è quella dello slot (slot `guest`, o un altro
  /// account entrato mentre questo contenitore è ancora a schermo), e il
  /// backend non si è né letto né scritto: il file di uno non va nella riga
  /// dell'altro.
  Future<({DateTime at, bool merged})?> sync() async {
    if (!_owned) return null;
    final row = await store.read();
    final merged = row != null && (_seen == null || row.revision != _seen);
    if (merged) await backup.import(row.payload, ImportMode.merge);
    return (at: await _upload(), merged: merged);
  }

  Future<DateTime> _upload() async {
    final revision = _newRevision();
    await store.write(ReaderRow(
      payload: await backup.export(),
      // Chi ha scritto per ultimo: un altro telefono che trova una revisione
      // diversa da quella che ricorda sa di dover fondere prima di scrivere.
      revision: revision,
      // Da quale dispositivo è arrivata l'ultima scrittura: l'unica cosa che
      // permetta di capire, guardando i dati, chi ha sovrascritto cosa.
      device: Platform.operatingSystem,
    ));
    _seen = revision;
    final now = DateTime.now().toUtc();
    await user.writeSetting(lastSyncKey, now.toIso8601String());
    return now;
  }

  static String _newRevision() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  /// Toglie i propri dati dalla rete. Quelli sul telefono restano: è uno
  /// «smetti di tenerne copia», non un «cancella tutto». `false`, senza
  /// toccare il backend, se la sessione non è quella dello slot.
  Future<bool> forget() async {
    if (!_owned) return false;
    await store.delete();
    _seen = null;
    await user.writeSetting(lastSyncKey, '');
    return true;
  }

  Future<DateTime?> lastSync() async {
    final value = await user.readSetting(lastSyncKey);
    return value == null || value.isEmpty ? null : DateTime.tryParse(value);
  }
}

/// L'accesso con Google.
///
/// L'app non gestisce password: chiede al sistema chi è l'utente, riceve un
/// token d'identità firmato da Google e lo passa al backend, che ne ricava la
/// sessione. Passare dal sistema invece che da un browser è anche ciò che
/// evita di uscire dall'app per rientrarci.
class CloudAuth {
  const CloudAuth();

  GoTrueClient? get _auth => backend?.auth;

  CloudAccount? get current => _accountOf(_auth?.currentUser);

  /// Una sessione che non si rinnova (senza rete, revocata) arriva qui come
  /// errore: non è un evento da riferire, e lo stato resta l'ultimo saputo.
  Stream<CloudAccount?> changes() =>
      _auth?.onAuthStateChange
          .map((state) => _accountOf(state.session?.user))
          .handleError((Object _) {}) ??
      Stream.value(null);

  /// Torna `null` se l'utente ha chiuso la finestra di Google: rinunciare non
  /// è un errore e non va riferito come tale.
  Future<CloudAccount?> signIn() async {
    final GoogleSignInAccount google;
    try {
      google = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw CloudException(_googleMessage(error));
    }
    final account = await _signInWith(google);
    if (account == null) throw CloudException(currentL10n().dataCloudSignInFailed);
    await _setSignedOut(false);
    return account;
  }

  Future<CloudAccount?> _signInWith(GoogleSignInAccount google) async {
    final idToken = google.authentication.idToken;
    if (idToken == null) {
      throw CloudException(currentL10n().dataCloudNoIdentityToken);
    }
    final auth = _auth;
    if (auth == null) throw CloudException(currentL10n().dataCloudSignInFailed);
    try {
      // Senza `nonce`: google_sign_in non ne mette nel token.
      final response = await auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      return _accountOf(response.user);
    } on AuthException catch (error) {
      if (backendFailure(error) == BackendFailure.offline) rethrow;
      throw CloudException(error.code == 'provider_disabled'
          ? currentL10n().dataCloudSignInNotEnabled
          : currentL10n().dataCloudSignInFailed);
    }
  }

  /// Chi era entrato quando l'account stava su Firebase non deve ritrovarsi
  /// fuori dopo l'aggiornamento: se il backend non ha sessione, si chiede a
  /// Google l'account già autorizzato per l'app, senza finestre (Google non ne
  /// ha da dare a chi non è mai entrato). Chi è uscito di proposito lo ha
  /// segnato ([signOut]) e non vede comparire niente. Qualunque intoppo vuol
  /// dire «scollegato», senza un errore a schermo: il pulsante «Accedi» resta
  /// lì.
  Future<void> _resumeSilently() async {
    final auth = _auth;
    if (auth == null || auth.currentSession != null) return;
    try {
      if ((await SharedPreferences.getInstance()).getBool(_signedOutKey) ?? false) return;
      final google = await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (google != null) await _signInWith(google);
    } on Exception {
      // Scollegato.
    }
  }

  /// Chi è dentro all'avvio. Se non c'è sessione ma il rientro silenzioso è in
  /// corso (non si è usciti di proposito), lo attende al massimo [limit]: da
  /// qui dipende quale file di dati si apre.
  Future<CloudAccount?> restoredAccount({
    Duration limit = const Duration(seconds: 5),
  }) async {
    final resuming = _resuming;
    if (current == null && resuming != null) {
      try {
        await resuming.timeout(limit);
      } on TimeoutException {
        // Troppo tardi per questo avvio: si parte senza account.
      }
    }
    return current;
  }

  /// L'uscita voluta: sta fuori dal database, che l'uscita non tocca.
  static const String _signedOutKey = 'cloud.signedOut';

  /// Se dal telefono si è usciti di proposito: lo legge anche il lavoro ad
  /// app chiusa, che non ha la sessione del backend.
  static Future<bool> signedOutOnPhone() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_signedOutKey) ?? false;
    } on Exception {
      return true;
    }
  }

  static Future<void> _setSignedOut(bool value) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_signedOutKey, value);
    } on Exception {
      // Al peggio un rientro silenzioso in più, che Google non concede a chi è uscito.
    }
  }

  Future<void> signOut() async {
    await _setSignedOut(true);
    await GoogleSignIn.instance.signOut();
    try {
      await _auth?.signOut();
    } on Exception {
      // La sessione sul telefono è già tolta; senza rete il backend la
      // lascerà scadere da sé.
    }
  }

  static CloudAccount? _accountOf(User? user) {
    if (user == null) return null;
    final meta = user.userMetadata ?? const {};
    String? text(String key) => meta[key] is String ? meta[key] as String : null;
    return CloudAccount(
      id: user.id,
      email: user.email ?? '',
      name: text('full_name') ?? text('name'),
      photo: text('avatar_url') ?? text('picture'),
    );
  }

  /// Un telefono senza i servizi di Google e un'app registrata male sono i due
  /// modi in cui l'accesso non parte proprio, e si rimediano in posti diversi:
  /// vanno distinti.
  static String _googleMessage(GoogleSignInException error) =>
      switch (error.code) {
        GoogleSignInExceptionCode.interrupted => currentL10n().dataCloudSignInInterrupted,
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          currentL10n().dataCloudGoogleNotConfigured,
        _ => currentL10n().dataCloudGoogleSignInFailed,
      };
}
