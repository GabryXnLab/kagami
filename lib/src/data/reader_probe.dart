/// Le misure del lettore, per capire da un telefono vero perché scatta.
///
/// Gli scatti non si vedono nei test né su una macchina senza schermo: le
/// ipotesi si possono solo verificare dove succedono, e questo è il modo di
/// farlo senza strumenti di sviluppo: acceso dalle impostazioni, il lettore
/// mostra in un angolo quanto costano i fotogrammi, le fasce e le correzioni
/// della striscia.
///
/// Spento non fa niente: nessun callback registrato, contatori fermi.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class ReaderProbe {
  ReaderProbe._();

  static final ReaderProbe instance = ReaderProbe._();

  /// Se la misura è accesa. Non si salva: è una diagnosi, non
  /// un'impostazione, e riaprendo l'app torna spenta.
  final ValueNotifier<bool> enabled = ValueNotifier(false);

  int frames = 0;

  /// Fotogrammi fuori tempo per colpa del thread dell'interfaccia, e per
  /// colpa della GPU. Sono due cause diverse con due rimedi diversi.
  int slowBuild = 0;
  int slowRaster = 0;
  Duration worstBuild = Duration.zero;
  Duration worstRaster = Duration.zero;

  /// Fotogrammi partiti in ritardo: fra il segnale dello schermo e l'inizio
  /// del lavoro è passato più di un fotogramma. È il thread dell'interfaccia
  /// occupato *fuori* dai fotogrammi — che da Flutter 3.29 è anche il thread
  /// principale di Android — e i fotogrammi lenti non lo vedono.
  int lateStarts = 0;
  Duration worstStart = Duration.zero;

  /// Fotogrammi mai disegnati mentre la striscia scorreva: lo scatto che si
  /// vede davvero, e che nessuna durata di fotogramma può contare.
  int scrollFrames = 0;
  int missedFrames = 0;
  Duration worstGap = Duration.zero;

  /// Da dove sono arrivate le fasce: tessere dell'archivio, tavole intere,
  /// tessere fatte dal telefono, ritagli nativi (pixel o texture).
  int tileBands = 0;
  int wholeBands = 0;
  int phoneBands = 0;
  int textureBands = 0;

  /// Tavole tagliate in tessere dal telefono, e tavole intere decodificate
  /// dal Kotlin per ritagliarne le fasce.
  int phoneTiled = 0;
  int pageDecodes = 0;

  /// Il GC di Android dall'azzeramento: raccolte e millisecondi, tutte e
  /// quelle che hanno fermato chi allocava. Il Kotlin li legge a ogni fascia.
  int gcCount = 0;
  int gcMillis = 0;
  int blockingCount = 0;
  int blockingMillis = 0;
  List<int>? _runtime;
  List<int>? _baseline;

  int bands = 0;

  /// Fasce che il decodificatore a ritagli non ha saputo dare: sono passate
  /// dalla tavola intera, che costa molto di più.
  int wholeDecodes = 0;

  /// Dall'invio della richiesta all'arrivo dei pixel, e di questo quanto è
  /// stata la decodifica vera: la differenza è attesa in coda.
  Duration nativeTotal = Duration.zero;
  Duration nativeWorst = Duration.zero;
  Duration decodeTotal = Duration.zero;
  Duration decodeWorst = Duration.zero;

  /// La copia dei pixel dentro l'engine: è sincrona, sul thread
  /// dell'interfaccia.
  Duration copyWorst = Duration.zero;

  /// Fasce la cui tavola non era ancora scesa da Drive quando servivano.
  int driveWaits = 0;

  int corrections = 0;
  int jumps = 0;
  double jumped = 0;

  bool _listening = false;
  bool _framing = false;

  /// Se la striscia sta scorrendo: lo dice il lettore, dalle notifiche della
  /// lista.
  bool scrolling = false;
  Duration? _lastFrame;

  bool get on => enabled.value;

  void setEnabled(bool value) {
    enabled.value = value;
    if (value && !_listening) {
      _listening = true;
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      if (!_framing) {
        // Un callback persistente non si toglie: da spento non fa niente.
        _framing = true;
        SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
      }
    } else if (!value && _listening) {
      _listening = false;
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
    reset();
  }

  void reset() {
    frames = slowBuild = slowRaster = 0;
    worstBuild = worstRaster = Duration.zero;
    lateStarts = scrollFrames = missedFrames = 0;
    worstStart = worstGap = Duration.zero;
    tileBands = wholeBands = phoneBands = textureBands = 0;
    phoneTiled = pageDecodes = 0;
    gcCount = gcMillis = blockingCount = blockingMillis = 0;
    _baseline = _runtime;
    bands = wholeDecodes = driveWaits = 0;
    nativeTotal = nativeWorst = Duration.zero;
    decodeTotal = decodeWorst = Duration.zero;
    copyWorst = Duration.zero;
    corrections = jumps = 0;
    jumped = 0;
  }

  /// Quanto dura un fotogramma sullo schermo di questo telefono: a 120 Hz
  /// il margine è la metà che a 60.
  Duration get budget {
    final views = ui.PlatformDispatcher.instance.views;
    final rate = views.isEmpty ? 60.0 : views.first.display.refreshRate;
    return Duration(microseconds: (1000000 / (rate <= 0 ? 60 : rate)).round());
  }

  void _onTimings(List<ui.FrameTiming> timings) {
    final limit = budget;
    for (final timing in timings) {
      frames++;
      final build = timing.buildDuration;
      final raster = timing.rasterDuration;
      if (build > limit) slowBuild++;
      if (raster > limit) slowRaster++;
      if (build > worstBuild) worstBuild = build;
      if (raster > worstRaster) worstRaster = raster;
      final start = timing.vsyncOverhead;
      if (start > limit) lateStarts++;
      if (start > worstStart) worstStart = start;
    }
  }

  /// I segnali dello schermo arrivano a intervalli fissi: fra due fotogrammi
  /// di scorrimento ne passa uno solo, e ogni intervallo in più è un
  /// fotogramma che non c'è stato.
  void _onFrame(Duration stamp) {
    if (!on || !scrolling) {
      _lastFrame = null;
      return;
    }
    final last = _lastFrame;
    _lastFrame = stamp;
    if (last == null) return;
    scrollFrames++;
    final gap = stamp - last;
    if (gap > worstGap) worstGap = gap;
    final skipped = (gap.inMicroseconds / budget.inMicroseconds).round() - 1;
    if (skipped > 0) missedFrames += skipped;
  }

  void noteBand({
    required Duration native,
    required Duration decode,
    required Duration copy,
    bool texture = false,
  }) {
    if (!on) return;
    bands++;
    if (texture) textureBands++;
    nativeTotal += native;
    decodeTotal += decode;
    if (native > nativeWorst) nativeWorst = native;
    if (decode > decodeWorst) decodeWorst = decode;
    if (copy > copyWorst) copyWorst = copy;
  }

  void noteTile() {
    if (on) tileBands++;
  }

  void noteWhole() {
    if (on) wholeBands++;
  }

  void notePhoneTile() {
    if (on) phoneBands++;
  }

  void notePhoneTiled() {
    if (on) phoneTiled++;
  }

  /// I contatori del GC di Android arrivano cumulativi dall'avvio dell'app:
  /// si mostrano come differenza da quelli visti all'azzeramento.
  void noteRuntime({
    required int gcCount,
    required int gcMillis,
    required int blockingCount,
    required int blockingMillis,
    required bool pageDecoded,
  }) {
    final now = [gcCount, gcMillis, blockingCount, blockingMillis];
    _runtime = now;
    if (!on) return;
    if (pageDecoded) pageDecodes++;
    final base = _baseline ??= now;
    this.gcCount = now[0] - base[0];
    this.gcMillis = now[1] - base[1];
    this.blockingCount = now[2] - base[2];
    this.blockingMillis = now[3] - base[3];
  }

  void noteWholeDecode() {
    if (on) wholeDecodes++;
  }

  void noteDriveWait() {
    if (on) driveWaits++;
  }

  void noteCorrection(double shift) {
    if (!on) return;
    corrections++;
    if (shift.abs() >= 0.5) {
      jumps++;
      jumped += shift.abs();
    }
  }
}
