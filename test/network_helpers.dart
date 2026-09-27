import 'package:kagami/src/data/network.dart';

/// Un monitor con la sonda in mano al test.
NetworkMonitor monitor({bool reachable = true}) {
  var up = reachable;
  final network = Switchable(() async => up);
  network.flip = (value) => up = value;
  return network;
}

class Switchable extends NetworkMonitor {
  Switchable(Future<bool> Function() probe) : super(probe: probe, channel: null);

  late void Function(bool) flip;

  Future<void> goOffline() async {
    flip(false);
    await check();
  }

  Future<void> goOnline() async {
    flip(true);
    await check();
  }
}

