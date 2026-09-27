/// Le notifiche dei capitoli nuovi, lato Dart.
///
/// Cosa annunciare lo decide `arrivals.dart`; qui si parla col sistema
/// (`ArrivalNotifier.kt`). Niente pacchetto: sono tre chiamate, e il Kotlin
/// dell'app già c'è. Dove il canale non esiste — build Linux, test — non si
/// notifica niente.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import 'arrivals.dart';

/// Dove Dart e `LibraryWatchWorker.kt` si passano le consegne: le serie da
/// guardare vanno da qui a là, ciò che è stato annunciato da là a qui. Due
/// file, uno per verso, così nessuno dei due scrive sopra l'altro.
class ArrivalFiles {
  ArrivalFiles(String supportDirectory)
      : watch = File(p.join(supportDirectory, 'arrivals', 'watch.json')),
        record = File(p.join(supportDirectory, 'arrivals', 'record.json'));

  final File watch;
  final File record;

  Future<Map<String, int>> readRecord() async {
    if (!await record.exists()) return const {};
    final data = await compute(jsonDecode, await record.readAsString());
    return {
      if (data is Map)
        for (final MapEntry(:key, :value) in data.entries)
          if (key is String && value is num) key: value.toInt(),
    };
  }

  /// Senza cartella locale non c'è niente da guardare: il file sparisce e il
  /// lavoro, che lo cerca, non fa niente.
  Future<void> writeWatch(Map<String, Object?>? list) async {
    if (list == null) {
      if (await watch.exists()) await watch.delete();
      return;
    }
    await watch.parent.create(recursive: true);
    // Scritto a parte e poi rinominato: il lavoro può partire proprio ora, e
    // un file a metà non lo deve vedere.
    final pending = File('${watch.path}.part');
    await pending.writeAsString(jsonEncode(list), flush: true);
    await pending.rename(watch.path);
  }
}

const MethodChannel notificationsChannel = MethodChannel('kagami/notifications');

class ArrivalNotifications {
  ArrivalNotifications({this.channel = notificationsChannel})
      : _native = !kIsWeb && Platform.isAndroid;

  static final ArrivalNotifications instance = ArrivalNotifications();

  final MethodChannel channel;
  final bool _native;
  final StreamController<String> _opened = StreamController.broadcast();

  /// Le serie di cui è stata toccata una notifica con l'app già aperta.
  Stream<String> get opened => _opened.stream;

  void start() {
    if (!_native) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'open' && call.arguments is String) {
        _opened.add(call.arguments as String);
      }
    });
  }

  /// La serie della notifica che ha avviato l'app, una volta sola.
  Future<String?> launched() async {
    if (!_native) return null;
    return channel.invokeMethod<String>('launched');
  }

  Future<void> show(List<ArrivalAlert> alerts) async {
    if (!_native || alerts.isEmpty) return;
    // Da Android 13 serve il permesso, e lo si chiede quando c'è qualcosa da
    // dire: all'avvio sarebbe una domanda senza motivo apparente. Negato, il
    // sistema scarta la notifica e il pallino sulla copertina resta.
    await Permission.notification.request();
    for (final alert in alerts) {
      await channel.invokeMethod<void>('show', {
        'key': alert.entry.key,
        'title': alert.entry.title,
        'text': alert.count == 1
            ? 'È arrivato un capitolo nuovo'
            : 'Sono arrivati ${alert.count} capitoli nuovi',
      });
    }
  }

  /// Programma il controllo della cartella locale ad app chiusa.
  Future<void> watch(ArrivalFiles files) async {
    if (!_native) return;
    await channel.invokeMethod<void>('watch', {
      'watch': files.watch.path,
      'record': files.record.path,
    });
  }

  /// Aperta la scheda, la notifica non ha più niente da dire.
  Future<void> dismiss(String seriesKey) async {
    if (!_native) return;
    await channel.invokeMethod<void>('dismiss', {'key': seriesKey});
  }
}
