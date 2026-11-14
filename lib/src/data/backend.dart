/// Il backend dell'account: dove stanno i dati personali che seguono il
/// lettore e gli inviti fra account.
///
/// È un servizio compatibile con Supabase **di chi compila**: l'app non ne
/// conosce nessuno, e l'indirizzo e la chiave pubblica arrivano con
/// `--dart-define=BACKEND_URL=…` e `--dart-define=BACKEND_ANON_KEY=…`. Senza,
/// la build nasce senza account. Lo schema che il backend deve avere sta in
/// `backend/` di questo repo.
///
/// Qui c'è solo il contratto — la configurazione, il client, come si legge un
/// errore, la forma dei dati di un lettore. Chi lo usa (`cloud.dart`,
/// `server_access.dart`) non importa il pacchetto di Supabase per sapere
/// perché una richiesta è fallita.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_session.dart';

/// A quale backend parla questa build.
class BackendConfig {
  const BackendConfig({required this.url, required this.anonKey});

  /// Quello scelto da chi ha compilato.
  static const environment = BackendConfig(
    url: String.fromEnvironment('BACKEND_URL'),
    anonKey: String.fromEnvironment('BACKEND_ANON_KEY'),
  );

  final String url;

  /// La chiave pubblica del progetto: identifica la build, non dà accesso a
  /// niente che le regole del backend non concedano a chiunque.
  final String anonKey;

  bool get isConfigured {
    final uri = Uri.tryParse(url);
    return anonKey.isNotEmpty &&
        uri != null &&
        (uri.isScheme('https') || uri.isScheme('http')) &&
        uri.host.isNotEmpty;
  }
}

/// La chiave con cui `supabase_flutter` tiene la sessione nelle preferenze.
String persistSessionKeyFor(String url) => 'sb-${Uri.parse(url).host.split('.').first}-auth-token';

/// Il client del backend, o `null` in una build che non ne ha uno (o prima di
/// [openBackend]).
SupabaseClient? get backend => _backend;
SupabaseClient? _backend;

/// Apre il backend e ripristina la sessione salvata. Va chiamata prima di
/// `runApp`, per lo stesso motivo per cui ci andava l'accensione dell'account:
/// senza, l'app all'avvio si crederebbe scollegata per un istante.
///
/// Non tocca la rete: una build configurata apre il client anche senza
/// connessione, e un backend spento si scopre alla prima richiesta.
Future<SupabaseClient?> openBackend([
  BackendConfig config = BackendConfig.environment,
]) async {
  if (!config.isConfigured) return null;
  final supabase = await Supabase.initialize(
    url: config.url,
    publishableKey: config.anonKey,
    // L'accesso passa dal token d'identità di Google, mai da un link che
    // riapre l'app: niente da ascoltare.
    // La sessione nell'archivio sicuro, con la chiave di supabase_flutter
    // perché la migrazione trovi quella di prima (T17).
    authOptions: FlutterAuthClientOptions(
      detectSessionInUri: false,
      localStorage: SecureSessionStorage(persistSessionKey: persistSessionKeyFor(config.url)),
    ),
  );
  return _backend = supabase.client;
}

/// Perché una richiesta al backend non è andata. Nessuno di questi vuol dire
/// «non c'è niente»: chi legge e riceve un errore non ha saputo, e non scrive.
enum BackendFailure {
  /// Non si è potuto chiedere: senza rete, backend spento, tempo scaduto.
  offline,

  /// Il backend ha risposto che la tabella non esiste o non è concessa: ha uno
  /// schema più vecchio di questa app. La funzione non è disponibile lì.
  unavailable,

  /// La sessione non vale più: serve rifare l'accesso.
  signedOut,

  other,
}

/// Classifica un errore di una richiesta fatta **con una sessione**. Senza
/// sessione il backend risponde `42501` a tutto, e sarebbe un «non
/// disponibile» falso: chi chiama controlla prima di aver fatto l'accesso.
///
/// I codici: `PGRST205` e `42P01` tabella assente, `PGRST202` e `42883`
/// funzione assente, `42501` permesso negato
/// (misurati su un backend senza la tabella il 2026-11-13); `PGRST301` e
/// `PGRST303` token scaduto o non valido, dalla documentazione di PostgREST.
BackendFailure backendFailure(Object error) => switch (error) {
      AuthRetryableFetchException() ||
      SocketException() ||
      TimeoutException() =>
        BackendFailure.offline,
      PostgrestException(code: 'PGRST205' || '42P01' || '42501' || 'PGRST202' || '42883') =>
        BackendFailure.unavailable,
      AuthSessionMissingException() ||
      PostgrestException(code: 'PGRST301' || 'PGRST303') =>
        BackendFailure.signedOut,
      _ => BackendFailure.other,
    };

/// I dati personali di un lettore come viaggiano: il file di backup e chi
/// l'ha scritto.
class ReaderRow {
  const ReaderRow({required this.payload, required this.revision, this.device});

  /// Gli stessi byte che `BackupService.export` scrive in un file.
  final Uint8List payload;

  /// Cambia a ogni scrittura: chi ne trova una diversa da quella che ricorda
  /// sa che un altro dispositivo ha scritto, e fonde prima di riscrivere.
  final String revision;

  /// Da quale sistema è arrivata l'ultima scrittura.
  final String? device;
}

/// Dove sta la riga del lettore che ha fatto l'accesso. L'app parla con
/// questo, non con le tabelle: è ciò che i test sostituiscono con una copia in
/// memoria.
///
/// La riga si trova per **proprietario**, non per `id`: chi arriva da un
/// altro backend ha una riga importata il cui `id` è quello di allora. Chi
/// scrive riusa l'`id` della riga letta e ne crea una col proprio solo se non
/// ne aveva.
abstract interface class ReaderStore {
  /// La riga, o `null` se il lettore non ne ha ancora una. Una lettura
  /// fallita lancia (vedi [backendFailure]) e non torna mai `null`: da un
  /// `null` chi chiama conclude che può scrivere senza fondere.
  Future<ReaderRow?> read();

  /// Sostituisce la riga per intero. La data la mette il backend.
  Future<void> write(ReaderRow row);

  /// Toglie la riga. I dati sul dispositivo non c'entrano.
  Future<void> delete();
}
