/// L'account: i dati personali che seguono il lettore invece del telefono.
///
/// La libreria resta locale — l'app non scarica niente e non conosce nessun
/// sito — ma quello che il lettore ci ha fatto sopra (stato, voti, capitoli
/// letti, cronologia, raccolte, segnalibri, impostazioni) vive nel database
/// dell'app, e fin qui l'unico modo di portarselo su un altro telefono era il
/// backup. Con un account è lo stesso backup, che però va e torna da sé.
///
/// Quello che viaggia è esattamente il file che [BackupService] esporta: gli
/// stessi byte compressi, dentro un documento solo. Sembra pigrizia e non lo
/// è — le regole con cui due copie dei dati si fondono esistono già, sono
/// quelle del backup e sono provate: i capitoli letti si sommano, sul resto
/// vince il record con `updatedAt` più recente. Un secondo meccanismo di
/// fusione, campo per campo su Firestore, sarebbe stato una seconda occasione
/// di perdere qualcosa.
library;

import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../l10n.dart';
import 'backup.dart';
import 'user_repository.dart';

/// Se in questa build l'account esiste.
///
/// Serve Firebase, e Firebase c'è solo su Android e solo se chi ha compilato
/// ha messo il proprio `android/app/google-services.json` (vedi README): senza,
/// la sezione «Account» e Drive dicono che non ci sono, invece di offrire un
/// pulsante che fallirebbe. Lo decide [initCloud], prima del primo fotogramma.
bool get cloudAvailable => _cloudAvailable;
var _cloudAvailable = false;

/// Accende Firebase. Va chiamata prima di `runApp`: la sessione salvata si
/// ripristina qui, e senza di essa l'app all'avvio si crederebbe scollegata
/// per un istante.
///
/// La configurazione arriva da `android/app/google-services.json`, che il
/// plugin Gradle di Google trasforma in risorse dell'APK: le stesse da cui
/// `google_sign_in` ricava per conto di chi chiedere il token d'identità.
/// Senza quel file le risorse mancano e `initializeApp` fallisce: è una
/// build senza account, non un errore.
Future<void> initCloud() async {
  if (!Platform.isAndroid) return;
  try {
    await Firebase.initializeApp();
  } on Exception {
    return;
  }
  await GoogleSignIn.instance.initialize();
  _cloudAvailable = true;
}

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
/// quelli di Firebase e di dart:io: il resto dell'app non deve conoscerli.
String cloudMessage(Object error) => switch (error) {
      CloudException(:final message) => message,
      FirebaseAuthException(code: 'operation-not-allowed') =>
        currentL10n().dataCloudSignInNotEnabled,
      FirebaseAuthException(code: 'network-request-failed') =>
        currentL10n().dataCloudNoConnection,
      FirebaseException(:final String message) => message,
      SocketException() => currentL10n().dataCloudNoConnection,
      _ => currentL10n().dataSyncFailed,
    };

/// Il viaggio dei dati personali: di là e di qua.
class CloudSync {
  CloudSync(this.backup, this.user);

  /// Una raccolta, un documento per lettore. Le regole di sicurezza non
  /// lasciano nessuna strada verso il documento di qualcun altro.
  static const String collection = 'readers';

  /// Da quando ci si è sincronizzati l'ultima volta: lo si ricorda nelle
  /// impostazioni, che il backup si porta dietro come tutto il resto.
  static const String lastSyncKey = 'cloud.lastSync';

  final BackupService backup;
  final UserRepository user;

  DocumentReference<Map<String, Object?>> get _document =>
      FirebaseFirestore.instance.collection(collection).doc(_requireUser());

  /// La `revision` del documento com'era l'ultima volta che lo si è letto o
  /// scritto da qui, in memoria: `null` finché in questo processo non lo si è
  /// mai fuso, cioè sempre all'avvio.
  String? _seen;

  /// Prende quello che c'è in rete, lo fonde con quello che c'è qui, e
  /// rimanda su il risultato. Dice anche se ha fuso: solo allora il database
  /// è cambiato sotto l'app.
  ///
  /// Fondere in tutt'e due le direzioni invece di scegliere un vincitore è ciò
  /// che rende innocuo leggere due capitoli su un telefono e tre sull'altro
  /// senza aver aperto l'app nel mezzo.
  ///
  /// Non c'è un invio senza fusione, nemmeno uscendo dall'app: il documento
  /// remoto si sostituisce per intero, e un telefono che lo scrive senza averlo
  /// letto cancella ciò che c'era. Succedeva reinstallando: Android rimetteva
  /// il database com'era al suo ultimo backup, e la prima uscita dall'app —
  /// per concedere l'accesso ai file, prima ancora della sincronizzazione
  /// d'avvio — mandava su quella copia vecchia al posto di quella giusta.
  /// La lettura costa un documento; la fusione si salta se la `revision` è
  /// quella che questo processo ha già visto, cioè nessun altro ha scritto.
  Future<({DateTime at, bool merged})> sync() async {
    final snapshot = await _document.get();
    final data = snapshot.data();
    final payload = data?['payload'];
    final revision = data?['revision'];
    final merged = payload is Blob && (_seen == null || revision != _seen);
    if (merged) await backup.import(payload.bytes, ImportMode.merge);
    return (at: await _upload(), merged: merged);
  }

  Future<DateTime> _upload() async {
    final revision = _newRevision();
    await _document.set({
      'payload': Blob(await backup.export()),
      // Chi ha scritto per ultimo: un altro telefono che trova una revisione
      // diversa da quella che ricorda sa di dover fondere prima di scrivere.
      'revision': revision,
      // Da quale dispositivo è arrivata l'ultima scrittura: l'unica cosa che
      // permetta di capire, guardando i dati, chi ha sovrascritto cosa.
      'device': Platform.operatingSystem,
      // La data la mette il server: un telefono con l'orologio sbagliato non
      // deve poter dichiarare di essere il più recente.
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
  /// «smetti di tenerne copia», non un «cancella tutto».
  Future<void> forget() async {
    await _document.delete();
    _seen = null;
    await user.writeSetting(lastSyncKey, '');
  }

  Future<DateTime?> lastSync() async {
    final value = await user.readSetting(lastSyncKey);
    return value == null || value.isEmpty ? null : DateTime.tryParse(value);
  }

  String _requireUser() {
    final id = FirebaseAuth.instance.currentUser?.uid;
    if (id == null) throw CloudException(currentL10n().dataCloudNoSignIn);
    return id;
  }
}

/// L'accesso con Google.
///
/// L'app non gestisce password: chiede al sistema chi è l'utente, riceve un
/// token d'identità firmato da Google e lo passa a Firebase, che ne ricava la
/// sessione. Passare dal sistema invece che da un browser è anche ciò che
/// evita di uscire dall'app per rientrarci.
class CloudAuth {
  const CloudAuth();

  CloudAccount? get current => _accountOf(FirebaseAuth.instance.currentUser);

  Stream<CloudAccount?> changes() =>
      FirebaseAuth.instance.authStateChanges().map(_accountOf);

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
    final idToken = google.authentication.idToken;
    if (idToken == null) {
      throw CloudException(currentL10n().dataCloudNoIdentityToken);
    }
    final credential = await FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    final account = _accountOf(credential.user);
    if (account == null) throw CloudException(currentL10n().dataCloudSignInFailed);
    return account;
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }

  static CloudAccount? _accountOf(User? user) => user == null
      ? null
      : CloudAccount(
          id: user.uid,
          email: user.email ?? '',
          name: user.displayName,
          photo: user.photoURL,
        );

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
