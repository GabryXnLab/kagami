/// Il testo condiviso con Kagami da un'altra app (Condividi → Kagami): uno o
/// più link, o il JSON di un'automazione. Il lato nativo è `SharedText.kt`;
/// che farne lo decide `AppShell`.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../archive/bulk_import.dart';

/// Oltre questa lunghezza un testo condiviso non è un elenco di link ma
/// altro: non lo si legge.
const sharedTextLimit = 100000;

/// Oltre questa lunghezza un indirizzo condiviso è scartato.
const sharedLinkLimit = 2048;

/// I link del testo [text] arrivato da un'altra app, che non è fidata: un
/// testo troppo lungo non dà niente, e un indirizzo troppo lungo è scartato.
/// Resta solo http/https (`parseImportText`); niente parte da qui senza un tocco.
List<ImportItem> sharedLinks(String text) {
  if (text.length > sharedTextLimit) return const [];
  return [
    for (final item in parseImportText(text))
      if (item.url.length <= sharedLinkLimit) item,
  ];
}

class SharedText {
  SharedText({this.channel = const MethodChannel('kagami/share')}) : _native = !kIsWeb && Platform.isAndroid;

  static final SharedText instance = SharedText();

  final MethodChannel channel;
  final bool _native;
  final StreamController<String> _shared = StreamController.broadcast();

  /// I testi condivisi con l'app già aperta.
  Stream<String> get shared => _shared.stream;

  void start() {
    if (!_native) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'shared' && call.arguments is String) _shared.add(call.arguments as String);
    });
  }

  /// Il testo condiviso che ha avviato l'app, una volta sola.
  Future<String?> launched() async {
    if (!_native) return null;
    return channel.invokeMethod<String>('launched');
  }
}
