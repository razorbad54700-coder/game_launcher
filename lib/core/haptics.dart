import 'package:flutter/services.dart';

import 'settings.dart';

/// Vibrations de l'interface, désactivables dans les réglages.
class Haptics {
  Haptics(this._settings);

  final SettingsController _settings;

  Future<void> _run(Future<void> Function() action) async {
    if (!_settings.haptics) return;
    try {
      await action();
    } catch (_) {
      // Pas de vibreur ou refus du système : on ignore.
    }
  }

  Future<void> select() => _run(HapticFeedback.selectionClick);
  Future<void> light() => _run(HapticFeedback.lightImpact);
  Future<void> medium() => _run(HapticFeedback.mediumImpact);
  Future<void> heavy() => _run(HapticFeedback.heavyImpact);
}
