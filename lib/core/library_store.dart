import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_stats.dart';
import 'app_log.dart';

/// Tout ce que l'utilisateur personnalise dans sa bibliothèque : favoris, jeux
/// masqués, applis ajoutées à la main, statistiques de jeu, compteurs.
class LibraryStore extends ChangeNotifier {
  LibraryStore(this._p) {
    _load();
  }

  static const String _kFav = 'lib_fav';
  static const String _kHidden = 'lib_hidden';
  static const String _kExtra = 'lib_extra';
  static const String _kStats = 'lib_stats';
  static const String _kSessionPkg = 'lib_session_pkg';
  static const String _kSessionStart = 'lib_session_start';
  static const String _kBoosts = 'lib_boosts';
  static const String _kFreed = 'lib_freed_mb';
  static const String _kDnd = 'lib_dnd_count';

  /// Une « partie » plus longue que ça est considérée comme un oubli.
  static const int _maxSessionMs = 8 * 60 * 60 * 1000;

  /// Une « partie » plus courte que ça = lancement raté, on ne la compte pas.
  static const int _minSessionMs = 5000;

  final SharedPreferences _p;

  final Set<String> _fav = <String>{};
  final Set<String> _hidden = <String>{};
  final Set<String> _extra = <String>{};
  final Map<String, GameStats> _stats = <String, GameStats>{};

  String? _sessionPkg;
  int _sessionStartMs = 0;
  int _boosts = 0;
  int _freedMb = 0;
  int _dndCount = 0;

  void _load() {
    _fav.addAll(_p.getStringList(_kFav) ?? const <String>[]);
    _hidden.addAll(_p.getStringList(_kHidden) ?? const <String>[]);
    _extra.addAll(_p.getStringList(_kExtra) ?? const <String>[]);
    _boosts = _p.getInt(_kBoosts) ?? 0;
    _freedMb = _p.getInt(_kFreed) ?? 0;
    _dndCount = _p.getInt(_kDnd) ?? 0;
    _sessionPkg = _p.getString(_kSessionPkg);
    _sessionStartMs = _p.getInt(_kSessionStart) ?? 0;

    final String? raw = _p.getString(_kStats);
    if (raw != null && raw.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((Object? key, Object? value) {
            if (key is String && value is Map) {
              _stats[key] =
                  GameStats.fromJson(Map<String, dynamic>.from(value));
            }
          });
        }
      } catch (e) {
        AppLog.add('Statistiques illisibles, remises à zéro : $e');
      }
    }
  }

  // ------------------------------------------------------------ favoris

  bool isFavorite(String pkg) => _fav.contains(pkg);
  int get favoriteCount => _fav.length;

  Future<void> toggleFavorite(String pkg) async {
    if (!_fav.remove(pkg)) _fav.add(pkg);
    notifyListeners();
    await _p.setStringList(_kFav, _fav.toList());
  }

  // ------------------------------------------------------------ masqués

  bool isHidden(String pkg) => _hidden.contains(pkg);
  int get hiddenCount => _hidden.length;

  Future<void> setHidden(String pkg, bool hidden) async {
    final bool changed = hidden ? _hidden.add(pkg) : _hidden.remove(pkg);
    if (!changed) return;
    notifyListeners();
    await _p.setStringList(_kHidden, _hidden.toList());
  }

  // ------------------------------------------------------------ ajoutées à la main

  /// Applis (non détectées comme jeux) que l'utilisateur a ajoutées à « Mes jeux ».
  bool isExtra(String pkg) => _extra.contains(pkg);
  int get extraCount => _extra.length;

  Future<void> setExtra(String pkg, bool extra) async {
    final bool changed = extra ? _extra.add(pkg) : _extra.remove(pkg);
    if (!changed) return;
    notifyListeners();
    await _p.setStringList(_kExtra, _extra.toList());
  }

  // ------------------------------------------------------------ statistiques

  GameStats statsFor(String pkg) => _stats[pkg] ?? const GameStats();

  int get totalLaunches {
    int sum = 0;
    for (final GameStats s in _stats.values) {
      sum += s.launches;
    }
    return sum;
  }

  int get totalPlayMs {
    int sum = 0;
    for (final GameStats s in _stats.values) {
      sum += s.playMs;
    }
    return sum;
  }

  /// Nombre de jeux différents lancés au moins une fois.
  int get distinctGamesLaunched {
    int n = 0;
    for (final GameStats s in _stats.values) {
      if (s.launches > 0) n++;
    }
    return n;
  }

  int get boostCount => _boosts;
  int get freedMbTotal => _freedMb;
  int get dndCount => _dndCount;

  Future<void> _saveStats() async {
    final Map<String, dynamic> out = <String, dynamic>{};
    _stats.forEach((String k, GameStats v) => out[k] = v.toJson());
    await _p.setString(_kStats, jsonEncode(out));
  }

  Future<void> recordLaunch(String pkg) async {
    final GameStats s = statsFor(pkg);
    _stats[pkg] = s.copyWith(
      launches: s.launches + 1,
      lastLaunchMs: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
    await _saveStats();
  }

  Future<void> recordBoost({required int freedMb}) async {
    _boosts += 1;
    _freedMb += freedMb < 0 ? 0 : freedMb;
    notifyListeners();
    await _p.setInt(_kBoosts, _boosts);
    await _p.setInt(_kFreed, _freedMb);
  }

  Future<void> recordDnd() async {
    _dndCount += 1;
    notifyListeners();
    await _p.setInt(_kDnd, _dndCount);
  }

  // ------------------------------------------------------------ séances de jeu

  /// Mémorise « le jeu [pkg] vient d'être lancé » (sauvegardé : survit si
  /// Android ferme le lanceur pendant la partie).
  Future<void> startSession(String pkg) async {
    _sessionPkg = pkg;
    _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
    await _p.setString(_kSessionPkg, pkg);
    await _p.setInt(_kSessionStart, _sessionStartMs);
  }

  /// Appelée quand on revient dans le lanceur : ajoute la durée écoulée au
  /// temps de jeu du jeu concerné. Renvoie la durée comptée (0 si rien).
  Future<int> endSession() async {
    final String? pkg = _sessionPkg;
    if (pkg == null) return 0;
    final int elapsed = DateTime.now().millisecondsSinceEpoch - _sessionStartMs;
    _sessionPkg = null;
    _sessionStartMs = 0;
    await _p.remove(_kSessionPkg);
    await _p.remove(_kSessionStart);

    if (elapsed < _minSessionMs) return 0;
    final int counted = elapsed > _maxSessionMs ? _maxSessionMs : elapsed;
    final GameStats s = statsFor(pkg);
    _stats[pkg] = s.copyWith(playMs: s.playMs + counted);
    notifyListeners();
    await _saveStats();
    return counted;
  }

  /// Efface toutes les statistiques (pas les favoris).
  Future<void> resetStats() async {
    _stats.clear();
    _boosts = 0;
    _freedMb = 0;
    _dndCount = 0;
    notifyListeners();
    await _p.remove(_kStats);
    await _p.remove(_kBoosts);
    await _p.remove(_kFreed);
    await _p.remove(_kDnd);
  }
}
