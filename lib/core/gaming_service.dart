import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/device_status.dart';
import 'library_store.dart';
import 'native_bridge.dart';
import 'settings.dart';
import 'system_monitor.dart';

/// Bilan d'une optimisation avant le lancement d'un jeu.
class BoostReport {
  const BoostReport({
    this.clean,
    this.dndEnabled = false,
    this.dndNeedsPermission = false,
  });

  final CleanResult? clean;
  final bool dndEnabled;
  final bool dndNeedsPermission;
}

/// Mode Gaming : nettoyage de la RAM et « Ne pas déranger ».
class GamingService extends ChangeNotifier {
  GamingService(this._p, this._library, this._monitor) {
    _launcherOwnsDnd = _p.getBool(_kOwnsDnd) ?? false;
  }

  static const String _kOwnsDnd = 'gaming_owns_dnd';

  final SharedPreferences _p;
  final LibraryStore _library;
  final SystemMonitor _monitor;

  bool _launcherOwnsDnd = false;
  bool _disposed = false;

  bool dndGranted = false;
  bool dndActive = false;
  bool cleaning = false;
  CleanResult? lastClean;

  bool get demo => !NativeBridge.supported;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ------------------------------------------------------------ Ne pas déranger

  Future<void> refreshDnd() async {
    if (demo) {
      dndGranted = true;
      _notify();
      return;
    }
    final DndStatus? s = await NativeBridge.dndStatus();
    if (s != null) {
      dndGranted = s.granted;
      dndActive = s.active;
      _notify();
    }
  }

  /// Interrupteur manuel du Mode Gaming. Renvoie false si l'autorisation
  /// manque (l'écran propose alors d'ouvrir les réglages Android).
  Future<bool> setDndManual(bool enabled) async {
    final bool ok = await _applyDnd(enabled);
    if (ok) {
      // Réglage voulu par l'utilisateur : le lanceur ne le défera pas tout seul.
      await _setOwns(false);
    }
    return ok;
  }

  Future<bool> _applyDnd(bool enabled) async {
    if (demo) {
      dndGranted = true;
      dndActive = enabled;
      if (enabled) await _library.recordDnd();
      _notify();
      return true;
    }
    await refreshDnd();
    if (!dndGranted) return false;
    final bool ok = await NativeBridge.setDnd(enabled);
    if (ok) {
      final bool was = dndActive;
      dndActive = enabled;
      if (enabled && !was) await _library.recordDnd();
    }
    await refreshDnd();
    return ok;
  }

  Future<void> openDndSettings() => NativeBridge.openDndSettings();

  Future<void> _setOwns(bool v) async {
    _launcherOwnsDnd = v;
    await _p.setBool(_kOwnsDnd, v);
  }

  /// Après la partie : si c'est le lanceur qui avait activé « Ne pas déranger »,
  /// on le désactive. Le drapeau est sauvegardé : même si Android a fermé le
  /// lanceur pendant la partie, on rattrape le coup au retour.
  Future<void> restoreAfterGame() async {
    if (!_launcherOwnsDnd) return;
    await _applyDnd(false);
    await _setOwns(false);
  }

  // ------------------------------------------------------------ RAM

  /// Demande à Android de libérer la mémoire des applis en arrière-plan.
  Future<CleanResult?> cleanRam({String? keepPackage}) async {
    if (cleaning) return null;
    cleaning = true;
    _notify();
    try {
      CleanResult? r;
      if (demo) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        r = const CleanResult(
          availBeforeMb: 3400,
          availAfterMb: 4100,
          totalMb: 8192,
          processed: 12,
        );
      } else {
        r = await NativeBridge.cleanRam(keepPackage: keepPackage);
      }
      if (r != null) {
        lastClean = r;
        _monitor.applyClean(r);
        await _library.recordBoost(freedMb: r.freedMb);
      }
      return r;
    } finally {
      cleaning = false;
      _notify();
    }
  }

  // ------------------------------------------------------------ profils

  /// Applique le profil choisi juste avant de lancer [keepPackage].
  ///  - Éco : rien.
  ///  - Équilibré : nettoyage de la RAM.
  ///  - Performance : nettoyage de la RAM + « Ne pas déranger ».
  Future<BoostReport> applyProfile(
    BoostProfile profile, {
    String? keepPackage,
    void Function(String step)? onStep,
  }) async {
    CleanResult? clean;
    bool dnd = false;
    bool needsPermission = false;

    if (profile == BoostProfile.eco) {
      onStep?.call('Profil éco : aucun réglage');
      return const BoostReport();
    }

    onStep?.call('Libération de la mémoire…');
    clean = await cleanRam(keepPackage: keepPackage);

    if (profile == BoostProfile.performance) {
      onStep?.call('Activation de « Ne pas déranger »…');
      await refreshDnd();
      if (!dndGranted) {
        needsPermission = true;
      } else if (dndActive) {
        dnd = true; // déjà actif : on n'y touche pas et on ne le défera pas.
      } else {
        final bool ok = await _applyDnd(true);
        if (ok) {
          dnd = true;
          await _setOwns(true);
        }
      }
    }
    return BoostReport(
      clean: clean,
      dndEnabled: dnd,
      dndNeedsPermission: needsPermission,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
