/// L'account davanti a un Kagami Server: chi sei, il permesso sul tuo Drive
/// che il server usa a telefono spento, e gli inviti fra proprietari e
/// amici.
///
/// Il server riconosce l'account da un biglietto che il backend rilascia per
/// l'id di quel server e l'indirizzo a cui l'app gli parla, garantito dal
/// proprietario (docs/server-api.md, «Biglietto»): il token della
/// sessione, che varrebbe sul backend, va solo al server che l'app ha creato
/// per questo account, e solo se lui o il backend non hanno i biglietti. Il permesso di Drive è un refresh token per il client
/// «Web» del progetto, che solo un client col suo segreto può riscattare:
/// il segreto lo mette chi compila (`--dart-define=GOOGLE_SERVER_CLIENT_SECRET`),
/// accanto a `google-services.json` che dà l'id.
///
/// Gli inviti stanno sul backend (`server_invites`, vedi `invite_store.dart`):
/// il proprietario ne scrive uno per l'indirizzo che ammette, e l'app di
/// quell'account lo trova all'avvio e ne dà notizia. Il server non manda
/// email.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/google_token.dart';
import 'package:kagami_archive/remote.dart';

import '../l10n.dart';
import 'backend.dart';
import 'cloud.dart';
import 'invite_store.dart';

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

  factory ServerInvite.fromRow(Map<String, Object?> row) => ServerInvite(
        id: row['id'] as String? ?? '',
        to: row['to_email'] as String? ?? '',
        from: row['from_email'] as String? ?? '',
        fromName: row['from_name'] as String?,
        url: row['url'] as String? ?? '',
        serverName: row['server_name'] as String? ?? 'Kagami Server',
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
  const ServerAccess({
    this.invites = const SupabaseInviteStore(),
    this.account,
    this.session,
    this.ticket,
    this.vouch,
  });

  static const MethodChannel _google = MethodChannel('kagami/google');

  /// Dove stanno gli inviti: uno per coppia server–indirizzo, così aggiungere
  /// due volte lo stesso amico non ne scrive due.
  final InviteStore invites;

  /// Chi è dentro; di serie l'account della sessione del backend.
  final CloudAccount? Function()? account;

  /// Il token della sessione; di serie quello del backend ([sessionToken]).
  final Future<String> Function({bool refresh})? session;

  /// Un biglietto nuovo per il server con quell'id, a quell'indirizzo
  /// ([originOf]); di serie `kagami_ticket`.
  final Future<String> Function(String audience, String origin)? ticket;

  /// Dice al backend che a quell'indirizzo risponde il proprio server con
  /// quell'id; di serie `kagami_server_origin`.
  final Future<void> Function(String audience, String origin)? vouch;

  /// I biglietti già avuti, per account, server e indirizzo: valgono dieci
  /// minuti, e se ne usa uno per nove.
  static final Map<String, (String, DateTime)> _tickets = {};

  /// Gli indirizzi garantiti da questo avvio dell'app, per account, e quando.
  static final Map<String, DateTime> _vouched = {};

  /// Ogni quanto si dichiara di nuovo un indirizzo già garantito: sul backend vale 90 giorni
  /// dall'ultima dichiarazione (migrazione 0015), e qui se ne ripete una a settimana.
  static const originRenewal = Duration(days: 7);

  /// L'indirizzo per cui chiedere il biglietto: quello a cui l'app parla,
  /// nella forma di [normalizeServerUrl]. Lo sceglie l'app, non il server:
  /// l'id che il server dichiara è pubblico, e uno che si spaccia per un altro
  /// riceverebbe un biglietto buono per l'altro.
  static String originOf(Uri url) => '${normalizeServerUrl('$url') ?? url}';

  /// Come presentarsi a [link] (`Authorization`, [ServerCredentials]): con un
  /// biglietto per il suo id e il suo indirizzo se lo accetta (per il proprio
  /// server, garantito prima l'indirizzo); col token della sessione solo se
  /// il server è di questo account secondo il collegamento ([ServerLink.owner]),
  /// mai secondo ciò che dichiara lui. A un server altrui senza biglietti
  /// non si manda niente.
  Future<String> idToken(ServerLink link, ServerHello hello, {bool refresh = false}) async {
    final me = (account != null ? account!() : const CloudAuth().current)?.email.toLowerCase();
    if (hello.tickets) {
      final origin = originOf(link.url);
      try {
        if (me != null && me.isNotEmpty && link.owner == me) await _vouch(me, hello.id!, origin);
        return 'Kagami-Ticket ${await _ticketFor('$me|${hello.id}|$origin', hello.id!, origin, refresh)}';
      } on Object catch (error) {
        // Un backend senza kagami_ticket o kagami_server_origin (0013): resta il
        // token, se il server è il proprio.
        if (backendFailure(error) != BackendFailure.unavailable) rethrow;
      }
    }
    // Un collegamento di prima dei biglietti ([ServerLink.legacy]) ha già dato il
    // token a questo server: gli si manda ancora, finché il primo contatto
    // riuscito non lo adotta (`ServerLinkNotifier.adopt`).
    if (me == null || me.isEmpty || (link.owner != me && !link.legacy)) {
      throw ServerException(
        hello.tickets
            ? 'Il backend non rilascia biglietti per i server: a un server di altri non si manda il tuo accesso.'
            : 'Questo server va aggiornato: finché non accetta i biglietti, non gli si manda il tuo accesso.',
        code: hello.tickets ? 'tickets_unavailable' : 'update_server',
      );
    }
    return 'Bearer ${await (session ?? sessionToken)(refresh: refresh)}';
  }

  Future<void> _vouch(String me, String audience, String origin) async {
    final key = '$me|$audience|$origin';
    final last = _vouched[key];
    if (last != null && DateTime.now().difference(last) < originRenewal) return;
    if (vouch != null) {
      await vouch!(audience, origin);
    } else {
      await _rpc('kagami_server_origin', {'audience': audience, 'origin': origin});
    }
    _vouched[key] = DateTime.now();
  }

  Future<String> _ticketFor(String key, String audience, String origin, bool refresh) async {
    final now = DateTime.now();
    final kept = _tickets[key];
    if (!refresh && kept != null && now.isBefore(kept.$2)) return kept.$1;
    final fresh = ticket != null
        ? await ticket!(audience, origin)
        : '${await _rpc('kagami_ticket', {'audience': audience, 'origin': origin})}';
    _tickets[key] = (fresh, now.add(const Duration(minutes: 9)));
    return fresh;
  }

  static Future<Object?> _rpc(String function, Map<String, Object?> params) async {
    final active = backend;
    if (active == null || active.auth.currentSession == null) {
      throw ServerUnauthorized(currentL10n().serverSignInRequired);
    }
    try {
      return await active.rpc<Object?>(function, params: params);
    } on Exception catch (error) {
      if (backendFailure(error) == BackendFailure.offline) throw ServerOffline(currentL10n().serverNoConnection);
      rethrow;
    }
  }

  /// Il token della sessione del backend, che il client rinnova da sé.
  Future<String> sessionToken({bool refresh = false}) async {
    final auth = backend?.auth;
    final session = auth?.currentSession;
    if (auth == null || session == null) throw ServerUnauthorized(currentL10n().serverSignInRequired);
    if (!refresh && !session.isExpired) return session.accessToken;
    try {
      final token = (await auth.refreshSession()).session?.accessToken;
      if (token == null) throw const ServerUnauthorized();
      return token;
    } on Exception catch (error) {
      if (error is ServerUnauthorized) rethrow;
      if (backendFailure(error) == BackendFailure.offline) throw ServerOffline(currentL10n().serverNoConnection);
      throw const ServerUnauthorized();
    }
  }

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

  /// L'id dell'invito: `sha256("<from>|<to>|<url>")`, i primi 32 caratteri, e il
  /// backend lo controlla (0014). Col mittente dentro, chi scrive per primo
  /// non occupa l'id dell'invito di un altro.
  static String inviteId(String from, String to, Uri url) =>
      sha256.convert(utf8.encode('$from|$to|$url')).toString().substring(0, 32);

  /// L'id degli inviti di prima, senza mittente: restano, e si tolgono anche così.
  static String _legacyInviteId(String to, Uri url) =>
      sha256.convert(utf8.encode('$to|$url')).toString().substring(0, 32);

  /// Dice a [to] che può usare il server: lo trova la sua app.
  Future<void> invite({required String to, required Uri url, required String serverName}) async {
    final me = account != null ? account!() : const CloudAuth().current;
    if (me == null || me.email.isEmpty) throw const ServerUnauthorized();
    final target = to.toLowerCase();
    await invites.put(ServerInvite(
      id: inviteId(me.email.toLowerCase(), target, url),
      to: target,
      from: me.email.toLowerCase(),
      fromName: me.name,
      url: '$url',
      serverName: serverName,
    ));
  }

  /// Toglie l'invito: il proprietario che toglie l'amico, o l'amico che lo
  /// ha usato o non lo vuole. L'amico non sa il mittente, quindi toglie tutti
  /// i suoi inviti a quell'indirizzo; quelli con l'id di prima si tolgono
  /// comunque (il backend lascia toccare solo i propri).
  Future<void> withdraw(String to, Uri url) async {
    final me = (account != null ? account!() : const CloudAuth().current)?.email.toLowerCase();
    final target = to.toLowerCase();
    final ids = {
      if (me != null && me.isNotEmpty) inviteId(me, target, url),
      _legacyInviteId(target, url),
      if (me == target)
        for (final invite in await invites.listFor(target))
          if (invite.url == '$url') invite.id,
    };
    for (final id in ids) {
      await invites.remove(id);
    }
  }

  /// Gli inviti per [email]. Una lettura fallita lancia: non è «nessun invito».
  Future<List<ServerInvite>> invitesFor(String email) => invites.listFor(email);

  /// Quando gli inviti per [email] possono essere cambiati.
  Stream<void> inviteChanges(String email) => invites.changes(email);
}

/// Gli inviti per [email] nel tempo: letti subito, e riletti a ogni evento di
/// [InviteStore.changes] e di [resumed] (l'app torna in primo piano). Una
/// lettura fallita non emette niente, quindi l'elenco di prima resta; se il
/// backend non ha la tabella (`unavailable`) la funzione non c'è e non si
/// riprova.
Stream<List<ServerInvite>> watchServerInvites(
  ServerAccess access,
  String email, {
  Stream<void> resumed = const Stream.empty(),
}) {
  late final StreamController<List<ServerInvite>> controller;
  final subscriptions = <StreamSubscription<void>>[];
  var unavailable = false;
  Future<void> load() async {
    if (unavailable || controller.isClosed) return;
    try {
      final invites = await access.invitesFor(email);
      if (!controller.isClosed) controller.add(invites);
    } on Object catch (error) {
      if (backendFailure(error) == BackendFailure.unavailable) unavailable = true;
    }
  }

  controller = StreamController<List<ServerInvite>>(
    onListen: () {
      for (final source in [access.inviteChanges(email), resumed]) {
        subscriptions.add(source.listen((_) => load(), onError: (Object _) {}));
      }
      unawaited(load());
    },
    onCancel: () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );
  return controller.stream;
}
