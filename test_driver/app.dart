// L'app con l'estensione di Flutter Driver accesa: è il punto d'ingresso che
// `launch_app` del server MCP di Dart usa per toccare e leggere i widget per
// testo o tipo, invece che a coordinate. L'app vera resta `lib/main.dart`.
import 'package:flutter_driver/driver_extension.dart';
import 'package:kagami/main.dart' as app;

void main() {
  enableFlutterDriverExtension();
  app.main();
}
