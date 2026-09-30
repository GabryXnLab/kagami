/// Google Drive nell'app: il permesso dell'account e la cache delle tavole.
///
/// Il client REST sta nel pacchetto `kagami_archive`, che non dipende da
/// Flutter e lo usa anche il server; qui c'è ciò che vuole il telefono.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:kagami_archive/drive.dart';
import 'package:path/path.dart' as p;

import '../l10n.dart';

export 'package:kagami_archive/drive.dart';

/// Il token d'accesso a Drive.
///
/// L'accesso con Google fatto per l'account dà un'identità, non un permesso
/// sui file: questo si chiede a parte, una volta, con [authorize]. Dopo, il
/// sistema lo rinnova da sé e [token] lo ottiene senza mostrare niente.
///
/// Il permesso si chiede per l'indirizzo che [account] dà — quello che
/// Firebase ricorda — e non passando da `attemptLightweightAuthentication`:
/// quella rifà l'accesso con Credential Manager, che a ogni avvio mostra il
/// foglio «Accesso come…» o, peggio, la scelta dell'account. L'API pubblica
/// di `google_sign_in` lega l'indirizzo solo a un account appena autenticato,
/// per questo la richiesta va all'interfaccia di piattaforma.
class DriveAuth {
  /// Senza [account] il sistema sceglie da sé: su un telefono con un solo
  /// account Google basta, ed è il caso della sincronizzazione programmata,
  /// che gira senza Firebase.
  DriveAuth({String? Function()? account}) : _account = account ?? _anyone;

  static String? _anyone() => null;

  final String? Function() _account;
  final Map<String, ({String token, DateTime at})> _tokens = {};

  /// Google non dice quando un token scade; dura un'ora, e chiederne uno
  /// nuovo un po' prima costa una chiamata locale al sistema.
  static const Duration _lifetime = Duration(minutes: 45);

  Future<String?> _request(String scope, {required bool prompt}) async {
    final granted = await GoogleSignInPlatform.instance
        .clientAuthorizationTokensForScopes(
      ClientAuthorizationTokensForScopesParameters(
        request: AuthorizationRequestDetails(
          scopes: [scope],
          userId: null,
          email: _account(),
          promptIfUnauthorized: prompt,
        ),
      ),
    );
    return granted?.accessToken;
  }

  Future<String> token({bool refresh = false}) => _token(driveScope, refresh);

  /// Il token con cui si scrive: vale anche per leggere.
  Future<String> writeToken({bool refresh = false}) =>
      _token(driveWriteScope, refresh);

  Future<String> _token(String scope, bool refresh) async {
    final cached = _tokens[scope];
    if (!refresh &&
        cached != null &&
        DateTime.now().difference(cached.at) < _lifetime) {
      return cached.token;
    }
    if (refresh && cached != null) {
      await GoogleSignInPlatform.instance.clearAuthorizationToken(
        ClearAuthorizationTokenParams(accessToken: cached.token),
      );
    }
    final String? granted;
    try {
      granted = await _request(scope, prompt: false);
    } on GoogleSignInException {
      throw const DriveAuthRequired();
    }
    if (granted == null) throw const DriveAuthRequired();
    return _keep(scope, granted);
  }

  /// Chiede il permesso mostrando la finestra di Google. Va chiamata solo da
  /// un gesto dell'utente; [write] chiede anche di poter scrivere.
  Future<void> authorize({bool write = false}) async {
    final scope = write ? driveWriteScope : driveScope;
    final String? granted;
    try {
      granted = await _request(scope, prompt: true);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const DriveAuthRequired();
      }
      throw DriveException(currentL10n().dataDriveAccessDenied);
    }
    if (granted == null) {
      throw DriveException(currentL10n().dataDriveAccessDenied);
    }
    _keep(scope, granted);
  }

  String _keep(String scope, String token) {
    _tokens[scope] = (token: token, at: DateTime.now());
    return token;
  }

  void forget() => _tokens.clear();
}

/// Le tavole e le copertine scaricate, con un tetto di spazio.
///
/// Quando lo spazio finisce esce prima chi vale meno — [rank], che sa cosa
/// si sta leggendo — e a parità quella usata meno di recente. Il conto sta in
/// memoria e si rifà una volta all'apertura con un elenco della cartella:
/// aggiornare la data di ogni file a ogni lettura sarebbe una scrittura su
/// disco per tavola.
class DriveFileCache {
  DriveFileCache(this.directory, {required this.limitBytes});

  final Directory directory;
  int limitBytes;

  /// Quanto vale tenere un file. Senza, conta solo quando è stato usato.
  CacheRank Function(String key)? rank;

  final LinkedHashMap<String, int> _entries = LinkedHashMap();
  int _bytes = 0;
  bool _scanned = false;
  Future<void>? _scanning;

  int get bytes => _bytes;

  static const String _partial = '.part';

  Future<void> ready() => _scanning ??= _scan();

  Future<void> _scan() async {
    await directory.create(recursive: true);
    final found = <(String, int, DateTime)>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      final stat = await entity.stat();
      if (name.endsWith(_partial)) {
        // Un pezzo lasciato da un tentativo di ieri non verrà ripreso: la
        // tavola l'avrà scaricata qualcun altro, o nessuno la vuole più.
        if (DateTime.now().difference(stat.modified) > const Duration(days: 1)) {
          await entity.delete().catchError((_) => entity);
        }
        continue;
      }
      found.add((name, stat.size, stat.modified));
    }
    found.sort((a, b) => a.$3.compareTo(b.$3));
    for (final (name, size, _) in found) {
      _entries[name] = size;
      _bytes += size;
    }
    _scanned = true;
  }

  String _path(String key) => p.join(directory.path, key);

  /// Il file, se c'è, senza toccare il disco.
  String? peek(String key) {
    if (!_scanned) return null;
    final size = _entries.remove(key);
    if (size == null) return null;
    _entries[key] = size;
    return _path(key);
  }

  /// Se il file c'è, senza contarlo come un uso.
  bool has(String key) => _entries.containsKey(key);

  /// Quanto occupa il file, o zero se non c'è.
  int sizeOf(String key) => _entries[key] ?? 0;

  /// Mette in cache ciò che [write] scrive. Il file compare col suo nome
  /// solo a scrittura finita: una tavola troncata non deve mai sembrare
  /// buona.
  Future<String> store(String key, Future<void> Function(File target) write) async {
    await ready();
    final existing = peek(key);
    if (existing != null) return existing;
    final target = File(_path(key));
    // Il nome del pezzo è sempre lo stesso: un tentativo interrotto dalla rete
    // lo lascia lì, e il prossimo riprende da dove era arrivato.
    final temporary = File('${target.path}$_partial');
    try {
      await write(temporary);
      await temporary.rename(target.path);
    } on Object catch (error) {
      if (!isNetworkFailure(error)) {
        await temporary.delete().catchError((_) => temporary);
      }
      rethrow;
    }
    final size = await target.length();
    _entries.remove(key);
    _entries[key] = size;
    _bytes += size;
    await _trim(keep: key);
    return target.path;
  }

  Future<void> _trim({String? keep}) async {
    if (_bytes <= limitBytes) return;
    // Si scende un decimo sotto il tetto: sfoltire ogni tanto un po' di più
    // costa meno che rifare l'ordine a ogni tavola scaricata.
    final target = limitBytes - limitBytes ~/ 10;
    final order = _entries.keys.where((key) => key != keep).toList();
    final rank = this.rank;
    if (rank != null) {
      final ranks = {for (final key in order) key: rank(key).index};
      // Stabile, perché dentro lo stesso rango l'ordine è quello d'uso.
      mergeSort(order, compare: (a, b) => ranks[a]!.compareTo(ranks[b]!));
    }
    for (final key in order) {
      if (_bytes <= target) break;
      final size = _entries.remove(key);
      if (size == null) continue;
      _bytes -= size;
      await File(_path(key)).delete().catchError((_) => File(''));
    }
  }

  /// Toglie dei file che non servono più, senza aspettare che manchi posto.
  Future<void> forget(Iterable<String> keys) async {
    await ready();
    for (final key in keys.toList(growable: false)) {
      final size = _entries.remove(key);
      if (size == null) continue;
      _bytes -= size;
      await File(_path(key)).delete().catchError((_) => File(''));
    }
  }

  Future<void> setLimit(int bytes) async {
    limitBytes = bytes;
    await ready();
    await _trim();
  }

  Future<void> clear() async {
    await ready();
    for (final key in _entries.keys.toList()) {
      await File(_path(key)).delete().catchError((_) => File(''));
    }
    _entries.clear();
    _bytes = 0;
  }
}

/// Quanto vale tenere un file in cache, dal meno al più prezioso: è anche
/// l'ordine in cui escono quando lo spazio finisce.
enum CacheRank {
  /// Già letto: un capitolo finito, o le tavole passate di uno a metà.
  spent,

  /// Né letto né in lettura: un capitolo aperto e lasciato, un precarico.
  ordinary,

  /// Ciò che serve a riprendere: il resto di un capitolo lasciato a metà, e
  /// le miniature della griglia.
  kept,
}

/// Un capitolo di Drive aperto nel lettore: di quali file della cache è
/// fatto, nell'ordine delle tavole, e quando lo si è aperto l'ultima volta.
///
/// È ciò che permette di buttare un capitolo e non una tavola a caso: i
/// nomi dei file in cache sono impronte, e senza questo non si saprebbe di
/// chi sono.
class CachedChapter {
  CachedChapter({
    required this.series,
    required this.chapter,
    required this.keys,
    required this.openedAt,
  });

  factory CachedChapter.fromJson(Map<String, Object?> json) => CachedChapter(
        series: json['series'] as String,
        chapter: json['chapter'] as String,
        keys: [for (final key in json['keys'] as List) key as String],
        openedAt: DateTime.parse(json['openedAt'] as String),
      );

  final String series;
  final String chapter;
  final List<String> keys;
  final DateTime openedAt;

  Map<String, Object?> toJson() => {
        'series': series,
        'chapter': chapter,
        'keys': keys,
        'openedAt': openedAt.toIso8601String(),
      };
}

/// Cosa sa la cache della lettura di un capitolo: se è finito e, se è a
/// metà, da quale tavola si riprende.
typedef ChapterReading = ({bool finished, int? resumePage});

/// Dopo quanto un capitolo finito lascia la cache, anche con spazio libero.
/// Tre giorni bastano a tornarci sopra senza rete; oltre, è un capitolo che
/// si riaprirà di rado, e da Drive si riprende in un attimo.
const Duration spentRetention = Duration(days: 3);

/// Dopo quanto se ne va un capitolo aperto e né finito né in lettura.
const Duration idleRetention = Duration(days: 14);

/// Cosa fare dei capitoli in cache: il rango di ogni loro file e quali file
/// sono scaduti.
///
/// Un capitolo a metà tiene le tavole da dove si riprende in poi — la
/// posizione sta nel database, ed è quella a dover sopravvivere; le tavole
/// già passate valgono quanto un capitolo finito. Il tempo si conta
/// dall'ultima apertura: rileggere un capitolo lo rimette in cima.
({Map<String, CacheRank> ranks, Set<String> expired}) planCache(
  Iterable<CachedChapter> chapters,
  ChapterReading Function(String series, String chapter) reading,
  DateTime now,
) {
  final ranks = <String, CacheRank>{};
  final expired = <String>{};
  for (final chapter in chapters) {
    final state = reading(chapter.series, chapter.chapter);
    final idle = now.difference(chapter.openedAt);
    for (var page = 0; page < chapter.keys.length; page++) {
      final rank = state.finished
          ? CacheRank.spent
          : state.resumePage == null
              ? CacheRank.ordinary
              : page < state.resumePage!
                  ? CacheRank.spent
                  : CacheRank.kept;
      final key = chapter.keys[page];
      ranks[key] = rank;
      final gone = switch (rank) {
        CacheRank.spent => idle > spentRetention,
        CacheRank.ordinary => idle > idleRetention,
        CacheRank.kept => false,
      };
      if (gone) expired.add(key);
    }
  }
  return (ranks: ranks, expired: expired);
}

/// Un'impronta corta e stabile di un indirizzo, per dargli un nome di file.
///
/// FNV-1a a 64 bit: i nomi delle cartelle dei capitoli arrivano a cento
/// caratteri e un percorso intero non starebbe nel nome di un file, mentre
/// qui non serve che l'impronta resista a chi la vuole falsificare.
String addressKey(String address) {
  var hash = 0xcbf29ce484222325;
  for (final unit in utf8.encode(address)) {
    hash ^= unit;
    hash *= 0x100000001b3;
  }
  String half(int value) => value.toRadixString(16).padLeft(8, '0');
  return 'a${half(hash >>> 32)}${half(hash & 0xFFFFFFFF)}';
}
