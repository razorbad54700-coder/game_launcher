import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/device_status.dart';
import 'native_bridge.dart';

/// Surveille la batterie, la température, la RAM et le stockage, et garde un
/// historique court pour tracer les petites courbes du Mode Gaming.
///
/// Sur iOS (mode démo), les valeurs sont SIMULÉES : l'interface l'indique.
class SystemMonitor extends ChangeNotifier {
  static const int historyLength = 40;
  static const Duration period = Duration(seconds: 3);

  BatteryStatus battery = BatteryStatus.unknown;
  MemoryStatus? memory;
  StorageStatus? storage;
  DeviceInfo? device;

  /// Vrai tant qu'aucune mesure n'a réussi (la liaison Android est muette).
  bool get hasNoData => !demo && !battery.hasData && memory == null;

  final List<double> tempHistory = <double>[];
  final List<double> ramHistory = <double>[];
  final List<double> batteryHistory = <double>[];

  bool get demo => !NativeBridge.supported;

  Timer? _timer;
  bool _busy = false;
  bool _disposed = false;
  int _tick = 0;

  /// Démarre les mesures (immédiatement puis toutes les 3 s).
  void start() {
    if (_timer != null) return;
    refresh();
    _timer = Timer.periodic(period, (Timer t) => refresh());
  }

  /// Arrête les mesures (appli en arrière-plan : on économise la batterie).
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _push(List<double> list, double v) {
    list.add(v);
    while (list.length > historyLength) {
      list.removeAt(0);
    }
  }

  Future<void> refresh() async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      if (demo) {
        _simulate();
      } else {
        final BatteryStatus? b = await NativeBridge.getBattery();
        final MemoryStatus? m = await NativeBridge.getMemory();
        if (_tick % 10 == 0) {
          final StorageStatus? s = await NativeBridge.getStorage();
          if (s != null) storage = s;
        }
        if (device == null) {
          final DeviceInfo? d = await NativeBridge.getDeviceInfo();
          if (d != null) device = d;
        }
        if (b != null) {
          battery = b;
          if (b.hasTemp) _push(tempHistory, b.tempC);
          if (b.hasData) _push(batteryHistory, b.level.toDouble());
        }
        if (m != null) {
          memory = m;
          _push(ramHistory, m.usedRatio * 100.0);
        }
      }
      _tick++;
    } catch (_) {
      // Une mesure ratée n'est pas grave : on réessaiera au prochain tour.
    } finally {
      _busy = false;
    }
    if (!_disposed) notifyListeners();
  }

  /// Valeurs plausibles pour le mode démo (iOS).
  void _simulate() {
    final double t = _tick.toDouble();
    final double temp = 35.0 + 3.0 * math.sin(t / 6.0);
    final double ram = 0.58 + 0.08 * math.sin(t / 4.0);
    const int total = 8192;
    battery = BatteryStatus(
      level: 78,
      tempC: temp,
      charging: false,
      thermal: 0,
      voltage: 4.1,
      health: 2,
      plugged: 0,
      technology: 'Li-ion',
    );
    memory = MemoryStatus(availMb: (total * (1.0 - ram)).round(), totalMb: total);
    storage = const StorageStatus(freeMb: 70000, totalMb: 128000);
    device = const DeviceInfo(
      model: 'Démo',
      manufacturer: 'iOS',
      brand: 'Apple',
      androidVersion: '-',
      sdk: 0,
      cores: 6,
    );
    _push(tempHistory, temp);
    _push(ramHistory, ram * 100.0);
    _push(batteryHistory, 78.0);
  }

  /// Après un nettoyage : on remplace la mesure de RAM par celle du résultat.
  void applyClean(CleanResult r) {
    if (r.totalMb <= 0) return;
    memory = MemoryStatus(availMb: r.availAfterMb, totalMb: r.totalMb);
    _push(ramHistory, memory!.usedRatio * 100.0);
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
