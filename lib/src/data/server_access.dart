/// L'account davanti a un Kagami Server: chi sei, il permesso sul tuo Drive
/// che il server usa a telefono spento, e gli inviti fra proprietari e
/// amici.
///
/// Il server riconosce l'account dal token d'identità di Firebase
/// (docs/server-api.md, «Chi chiama»), che Firebase rinnova da sé: nessuna
/// chiave da copiare. Il permesso di Drive è un refresh token per il client
/// «Web» del progetto, che solo un client col suo segreto può riscattare:
/// il segreto lo mette chi compila (`--dart-define=GOOGLE_SERVER_CLIENT_SECRET`),
/// accanto a `google-services.json` che dà l'id.
///
/// Gli inviti stanno su Firestore (`serverInvites`): il proprietario ne
/// scrive uno per l'indirizzo che ammette, e l'app di quell'account lo trova
/// all'avvio e ne dà notizia. Il server non manda email e non conosce
/// Firebase oltre ai token.
library;

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/google_token.dart';
import 'package:kagami_archive/remote.dart';

import '../l10n.dart';

const String _clientSecret = String.fromEnvironment('GOOGLE_SERVER_CLIENT_SECRET');

/// L'immagine che il comando di avvio scarica. Chi pubblica la sua la
/// indica con `--dart-define=KAGAMI_SERVER_IMAGE=…`; di serie è quella del
/// progetto, che non contiene niente di personale: tutto arriva da
/// `KAGAMI_SETUP`.
const String serverImage = String.fromEnvironment(
  'KAGAMI_SERVER_IMAGE',
  defaultValue: 'ghcr.io/gabryxnlab/kagami-server:latest',
);

/// Perché questa build non può dare un permesso di Drive a un server, o
/// `null` se può.
String? get serverGrantUnavailable => Platform.isAndroid
    ? (_clientSecret.isEmpty ? currentL10n().serverUnavailableNoSecret : null)
    : currentL10n().serverUnavailableAndroidOnly;

class ServerInvite {
  const ServerInvite({
    required this.id,
    required this.to,
    required this.from,
    required this.url,
    required this.serverName,
    this.fromName,
  });

  factory ServerInvite.fromDoc(String id, Map<String, Object?> data) => ServerInvite(
        id: id,
        to: data['to'] as String? ?? '',
        from: data['from'] as String? ?? '',
        fromName: data['fromName'] as String?,
        url: data['url'] as String? ?? '',
        serverName: data['serverName'] as String? ?? 'Kagami Server',
      );

  final String id;
  final String to;
  final String from;
  final String? fromName;
  final String url;
  final String serverName;

  /// Chi l'ha mandato, come lo si scrive.
  String get sender => fromName == null || fromName!.isEmpty ? from : fromName!;
}

class ServerAccess {
  const ServerAccess();

  static const MethodChannel _google = MethodChannel('kagami/google');

  /// La raccolta degli inviti: uno per coppia server–indirizzo, così aggiungere
  /// due volte lo stesso amico non ne scrive due.
  static const String collection = 'serverInvites';

  /// Il token d'identità dell'account, per il server.
  Future<String> idToken({bool refresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw ServerUnauthorized(currentL10n().serverSignInRequired);
    try {
      final token = await user.getIdToken(refresh);
      if (token == null) throw const ServerUnauthorized();
      return token;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'network-request-failed') throw ServerOffline(currentL10n().serverNoConnection);
      throw const ServerUnauthorized();
    }
  }

  /// Il progetto Firebase dell'app: il server accetta solo i suoi token.
  String get project => Firebase.app().options.projectId;

  /// Un permesso duraturo sul Drive di [email], per il server. Mostra la
  /// finestra di Google col consenso a Drive: va chiamata da un gesto.
  ///
  /// `null` se l'utente ha rinunciato.
  Future<({GoogleClient client, String refreshToken})?> grantDrive(String email) async {
    final unavailable = serverGrantUnavailable;
    if (unavailable != null) throw ServerException(unavailable);
    final id = await _google.invokeMethod<String>('webClientId');
    if (id == null) throw ServerException(currentL10n().serverMissingGoogleServices);
    final ServerAuthorizationTokenData? granted;
    try {
      granted = await GoogleSignInPlatform.instance.serverAuthorizationTokensForScopes(
        ServerAuthorizationTokensForScopesParameters(
          request: AuthorizationRequestDetails(
            scopes: const [driveWriteScope],
            userId: null,
            email: email,
            promptIfUnauthorized: true,
          ),
        ),
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw ServerException(currentL10n().serverDriveAccessDenied);
    }
    if (granted == null) return null;
    final client = GoogleClient(id, _clientSecret);
    try {
      return (client: client, refreshToken: await redeemServerCode(client, granted.serverAuthCode));
    } on DriveOffline {
      throw ServerOffline(currentL10n().serverGoogleNotResponding);
    } on DriveException catch (error) {
      throw ServerException('$error');
    }
  }

  CollectionReference<Map<String, Object?>> get _invites => FirebaseFirestore.instance.collection(collection);

  static String _inviteId(String to, Uri url) => sha256.convert(utf8.encode('$to|$url')).toString().substring(0, 32);

  /// Dice a [to] che può usare il server: lo trova la sua app.
  Future<void> invite({required String to, required Uri url, required String serverName}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) throw const ServerUnauthorized();
    await _invites.doc(_inviteId(to, url)).set({
      'to': to,
      'from': user!.email!.toLowerCase(),
      'fromName': user.displayName,
      'url': '$url',
      'serverName': serverName,
      'at': FieldValue.serverTimestamp(),
    });
  }

  /// Toglie l'invito: il proprietario che toglie l'amico, o l'amico che lo
  /// ha usato o non lo vuole.
  Future<void> withdraw(String to, Uri url) => _invites.doc(_inviteId(to, url)).delete();

  /// Gli inviti per [email], come arrivano.
  Stream<List<ServerInvite>> invitesFor(String email) => _invites
      .where('to', isEqualTo: email.toLowerCase())
      .snapshots()
      .map((snapshot) => [for (final doc in snapshot.docs) ServerInvite.fromDoc(doc.id, doc.data())]);
}
