/// Una sorgente della libreria: un posto da cui arrivano serie in formato
/// MALF.
///
/// Le tre di sempre — la cartella scelta, lo spazio dell'app, la cartella di
/// Drive dell'account — hanno ciascuna la sua impostazione e non passano di
/// qui. Questo è il contratto delle altre: il Drive che qualcuno ha condiviso,
/// un NAS, un altro cloud. Una sorgente in più deve essere una riga di
/// configurazione, non un ramo nel lettore o nell'unione degli indici.
library;

import 'dart:convert';
import 'dart:math';

import '../library.dart';

enum SourceKind { folder, appPrivate, drive, driveShared, webdav, smb }

/// Cosa si può fare su una sorgente oltre a leggerla. Lo dichiara la
/// sorgente, e chi scrive o cancella lo chiede prima: una cartella condivisa
/// in sola lettura non è un posto dove un'operazione «fallisce», è un posto
/// dove non si propone.
class SourceCapabilities {
  const SourceCapabilities({
    this.write = false,
    this.trash = false,
    this.closedApp = false,
    this.download = false,
  });

  static const readOnly = SourceCapabilities();

  /// Caricare, rinominare, riscrivere gli indici.
  final bool write;

  /// Togliere capitoli e serie.
  final bool trash;

  /// Leggibile dai lavori ad app chiusa.
  final bool closedApp;

  /// Se la scheda offre «Scarica»: si può portarne i capitoli sul telefono.
  final bool download;
}

/// Come si arriva a una sorgente: ciò che di lei si salva. Mai un segreto
/// (vedi [SourceSecrets]): la lista viaggia con backup e account.
class SourceConfig {
  const SourceConfig({
    required this.id,
    required this.kind,
    required this.label,
    this.params = const {},
    this.expiresAt,
    this.order = 0,
  });

  /// Gli id delle tre di sempre, che non stanno nella lista salvata.
  static const String folderId = 'folder';
  static const String privateId = 'private';
  static const String driveId = 'drive';

  /// Un id nuovo: `s-` e otto cifre esadecimali. Finisce negli indirizzi dei
  /// file e nelle chiavi di cache, quindi non cambia più e non dice niente
  /// della sorgente.
  static String newId() {
    final random = Random.secure();
    return 's-${[
      for (var i = 0; i < 4; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join()}';
  }

  final String id;
  final SourceKind kind;

  /// Il nome che l'utente le ha dato, o quello che aveva quando è arrivata.
  final String label;

  /// Ciò che serve al suo tipo per trovarla: per un Drive `folderId`,
  /// `folderName`, `owner`; per WebDAV `url`, `user`, `root`; per SMB `host`, `share`, `folder`, `user`,
  /// `domain`, `seal`.
  final Map<String, Object?> params;

  /// Fino a quando vale, se chi l'ha concessa ha messo un termine.
  final DateTime? expiresAt;

  /// La posizione fra le sorgenti: a parità di serie vince la prima.
  final int order;

  bool expiredAt(DateTime now) =>
      expiresAt != null && !expiresAt!.isAfter(now);

  /// [clearExpiry]: il termine è caduto (un rinnovo senza scadenza); con
  /// `expiresAt: null` da solo non si distingue da «non cambiare».
  SourceConfig copyWith({
    String? label,
    Map<String, Object?>? params,
    int? order,
    DateTime? expiresAt,
    bool clearExpiry = false,
  }) =>
      SourceConfig(
        id: id,
        kind: kind,
        label: label ?? this.label,
        params: params ?? this.params,
        expiresAt: clearExpiry ? null : expiresAt ?? this.expiresAt,
        order: order ?? this.order,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'label': label,
        if (params.isNotEmpty) 'params': params,
        if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
        'order': order,
      };

  /// `null` se la riga non è di una forma che questa versione conosce.
  static SourceConfig? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final kind = SourceKind.values.asNameMap()[json['kind']];
    final label = json['label'];
    final params = json['params'];
    final expiresAt = json['expiresAt'];
    final order = json['order'];
    if (id is! String || id.isEmpty || kind == null || label is! String) {
      return null;
    }
    if (params != null && params is! Map) return null;
    final expiry = expiresAt == null
        ? null
        : (expiresAt is String ? DateTime.tryParse(expiresAt) : null);
    // Una scadenza scritta e non capita non diventa «senza scadenza».
    if (expiresAt != null && expiry == null) return null;
    return SourceConfig(
      id: id,
      kind: kind,
      label: label,
      params: {
        if (params is Map)
          for (final MapEntry(:key, :value) in params.entries) '$key': value,
      },
      expiresAt: expiry,
      order: order is int ? order : 0,
    );
  }
}

/// La lista delle sorgenti in più, come sta nell'impostazione
/// `library.sources`.
///
/// Tre stati, non due: una lista vuota, una lista letta, e una che c'era ma
/// non si è potuta capire ([unreadable]). Nell'ultimo caso non c'è nessuna
/// sorgente in più e l'impostazione resta com'è finché l'utente non ne
/// modifica una: riscriverla da sé vorrebbe dire cancellare ciò che non si è
/// saputo leggere.
class SourceList {
  SourceList(
    Iterable<SourceConfig> sources, {
    this.unreadable = false,
    this.foreign = const [],
  }) : sources = List.unmodifiable(
          sources.toList()
            ..sort((a, b) {
              final byOrder = a.order.compareTo(b.order);
              return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
            }),
        );

  static final SourceList empty = SourceList(const []);

  /// In ordine: la prima vince.
  final List<SourceConfig> sources;

  final bool unreadable;

  /// Le righe che questa versione non conosce (un tipo di sorgente nato
  /// dopo): non si usano, ma si riscrivono come sono, perché la lista torna
  /// anche sul telefono che le sa leggere.
  final List<Object?> foreign;

  static SourceList decode(String? value) {
    if (value == null || value.isEmpty) return empty;
    final Object? json;
    try {
      json = jsonDecode(value);
    } on FormatException {
      return SourceList(const [], unreadable: true);
    }
    if (json is! List) return SourceList(const [], unreadable: true);
    final sources = <String, SourceConfig>{};
    final foreign = <Object?>[];
    for (final row in json) {
      final config = SourceConfig.fromJson(row);
      if (config == null || sources.containsKey(config.id)) {
        foreign.add(row);
      } else {
        sources[config.id] = config;
      }
    }
    return SourceList(sources.values, foreign: foreign);
  }

  String encode() =>
      jsonEncode([for (final source in sources) source.toJson(), ...foreign]);

  SourceConfig? byId(String id) {
    for (final source in sources) {
      if (source.id == id) return source;
    }
    return null;
  }

  /// La stessa lista con queste sorgenti al posto delle sue: è già una
  /// modifica dell'utente, quindi da qui in poi si può scrivere.
  SourceList withSources(Iterable<SourceConfig> next) =>
      SourceList(next, foreign: foreign);
}

/// In che stato è una sorgente. Solo [ready] dice qualcosa sul suo contenuto:
/// negli altri casi non si è potuto chiedere, e «non ho potuto chiedere» non
/// è mai «è vuota».
enum SourceState {
  ready,

  /// Non raggiungibile adesso.
  offline,

  /// Mancano le credenziali, o non valgono più.
  needsAuth,

  /// Chi l'ha concessa ha messo un termine, ed è passato.
  expired,

  /// Ha risposto che la cartella non c'è più.
  missing,

  /// Una libreria condivisa accettata da un altro account di quello entrato:
  /// non si legge, ma non è scaduta né vuota e la configurazione resta.
  otherAccount,
}

/// Perché una sorgente non ha potuto dire cosa contiene.
///
/// La lancia `loadLibrary` di uno scaffale che sa il motivo; `Library.load`
/// la mette così com'è fra gli avvisi del catalogo, con l'id e lo stato. Le
/// serie di quella sorgente mancano dal catalogo, ma l'avviso dice che
/// mancano perché non si è potuto chiedere, non perché sono state tolte:
/// chi conclude qualcosa da un'assenza aspetta un catalogo senza avvisi.
class SourceUnavailable implements Exception {
  const SourceUnavailable(this.sourceId, this.state)
      : assert(state != SourceState.ready);

  final String sourceId;
  final SourceState state;

  @override
  String toString() => 'SourceUnavailable($sourceId, ${state.name})';
}

/// Una sorgente accesa: la configurazione più ciò che serve per leggerla.
abstract interface class StorageSource {
  SourceConfig get config;

  SourceCapabilities get capabilities;

  /// Gli indici e gli indirizzi dei file.
  LibraryShelf get shelf;

  /// Chi porta i suoi file sul telefono; `null` per una sorgente locale, i
  /// cui indirizzi sono già percorsi.
  RemoteFiles? get files;

  Future<SourceState> probe();

  void dispose();
}

/// Le credenziali delle sorgenti, per id. Stanno fuori dalle impostazioni
/// perché quelle vanno in backup e nell'account; una sorgente senza il suo
/// segreto è [SourceState.needsAuth], non un errore.
abstract interface class SourceSecrets {
  Future<String?> read(String id);

  Future<void> write(String id, String secret);

  Future<void> delete(String id);
}

/// Segreti che durano quanto il processo: ciò che c'è finché nessuna sorgente
/// ne ha bisogno davvero.
class MemorySourceSecrets implements SourceSecrets {
  final Map<String, String> _secrets = {};

  @override
  Future<String?> read(String id) async => _secrets[id];

  @override
  Future<void> write(String id, String secret) async => _secrets[id] = secret;

  @override
  Future<void> delete(String id) async => _secrets.remove(id);
}
