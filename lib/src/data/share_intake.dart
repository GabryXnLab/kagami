/// Il testo condiviso con Kagami da un'altra app (Condividi → Kagami): uno o
/// più link, o il JSON di un'automazione. Il lato nativo è `SharedText.kt`;
/// che farne lo decide `AppShell`.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
