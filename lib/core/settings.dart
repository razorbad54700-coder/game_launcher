import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart' show clampD, clampI;

/// Ordre d'affichage des jeux.
enum SortMode { alpha, recent, mostPlayed, favoritesFirst }

/// Ce que fait le bouton LANCER avant d'ouvrir un jeu.
enum BoostProfile { eco, balanced, performance }

/// Réglages de l'appli, sauvegardés sur le téléphone.
class SettingsController extends ChangeNotifier {
  SettingsController(this._p) {
    _loadFromPrefs();
  }

  static const String _kMuted = 's_muted';
  static const String _kVolume = 's_volume';
  static const String _kUiSounds = 's_ui_sounds';
  static const String _kHaptics = 's_haptics';
  static const String _kBootIntro = 's_boot_intro';
  static const String _kImmersive = 's_immersive';
  static const String _kLowFx = 's_low_fx';
  static const String _kShowAll = 's_show_all';
  static const String _kGrid = 's_grid';
  static const String _kSort = 's_sort';
  static const String _kProfile = 's_profile';
  static const String _kTempWarn = 's_temp_warn';

  static const List<String> _allKeys = <String>[
    _kMuted, _kVolume, _kUiSounds, _kHaptics, _kBootIntro, _kImmersive,
    _kLowFx, _kShowAll, _kGrid, _kSort, _kProfile, _kTempWarn,
  ];

  final SharedPreferences _p;

  bool _muted = false;
  double _volume = 0.8;
  bool _uiSounds = true;
  bool _haptics = true;
  bool _bootIntro = true;
  bool _immersive = false;
  bool _lowFx = false;
  bool _showAll = false;
  bool _grid = false;
  int _sort = 0;
  int _profile = 2;
  int _tempWarn = 42;

  void _loadFromPrefs() {
    _muted = _p.getBool(_kMuted) ?? false;
    _volume = clampD(_p.getDouble(_kVolume) ?? 0.8, 0.0, 1.0);
    _uiSounds = _p.getBool(_kUiSounds) ?? true;
    _haptics = _p.getBool(_kHaptics) ?? true;
    _bootIntro = _p.getBool(_kBootIntro) ?? true;
    _immersive = _p.getBool(_kImmersive) ?? false;
    _lowFx = _p.getBool(_kLowFx) ?? false;
    _showAll = _p.getBool(_kShowAll) ?? false;
    _grid = _p.getBool(_kGrid) ?? false;
    _sort = clampI(_p.getInt(_kSort) ?? 0, 0, SortMode.values.length - 1);
    _profile = clampI(_p.getInt(_kProfile) ?? 2, 0, BoostProfile.values.length - 1);
    _tempWarn = clampI(_p.getInt(_kTempWarn) ?? 42, 36, 55);
  }

  /// Vrai = tous les sons sont coupés (le « Mute » demandé).
  bool get muted => _muted;

  /// Volume de la musique et des effets, de 0.0 à 1.0.
  double get musicVolume => _volume;

  /// Petits sons d'interface (clics, lancement, succès).
  bool get uiSounds => _uiSounds;

  bool get haptics => _haptics;

  /// Animation + musique de démarrage.
  bool get bootIntro => _bootIntro;

  /// Cache la barre d'état et la barre de navigation.
  bool get immersive => _immersive;

  /// Mode économie : fond fixe, moins d'animations (utile pour la batterie).
  bool get lowFx => _lowFx;

  /// Montre toutes les applis, pas seulement les jeux détectés.
  bool get showAllApps => _showAll;

  /// Vrai = grille, faux = carrousel 3D.
  bool get gridView => _grid;

  SortMode get sortMode => SortMode.values[_sort];
  BoostProfile get boostProfile => BoostProfile.values[_profile];

  /// Seuil d'alerte de température (°C).
  int get tempWarn => _tempWarn;

  Future<void> setMuted(bool v) async {
    _muted = v;
    notifyListeners();
    await _p.setBool(_kMuted, v);
  }

  Future<void> setMusicVolume(double v) async {
    _volume = clampD(v, 0.0, 1.0);
    notifyListeners();
    await _p.setDouble(_kVolume, _volume);
  }

  Future<void> setUiSounds(bool v) async {
    _uiSounds = v;
    notifyListeners();
    await _p.setBool(_kUiSounds, v);
  }

  Future<void> setHaptics(bool v) async {
    _haptics = v;
    notifyListeners();
    await _p.setBool(_kHaptics, v);
  }

  Future<void> setBootIntro(bool v) async {
    _bootIntro = v;
    notifyListeners();
    await _p.setBool(_kBootIntro, v);
  }

  Future<void> setImmersive(bool v) async {
    _immersive = v;
    notifyListeners();
    await _p.setBool(_kImmersive, v);
  }

  Future<void> setLowFx(bool v) async {
    _lowFx = v;
    notifyListeners();
    await _p.setBool(_kLowFx, v);
  }

  Future<void> setShowAllApps(bool v) async {
    _showAll = v;
    notifyListeners();
    await _p.setBool(_kShowAll, v);
  }

  Future<void> setGridView(bool v) async {
    _grid = v;
    notifyListeners();
    await _p.setBool(_kGrid, v);
  }

  Future<void> setSortMode(SortMode m) async {
    _sort = m.index;
    notifyListeners();
    await _p.setInt(_kSort, _sort);
  }

  Future<void> setBoostProfile(BoostProfile p) async {
    _profile = p.index;
    notifyListeners();
    await _p.setInt(_kProfile, _profile);
  }

  Future<void> setTempWarn(int v) async {
    _tempWarn = clampI(v, 36, 55);
    notifyListeners();
    await _p.setInt(_kTempWarn, _tempWarn);
  }

  /// Remet tous les réglages à leur valeur d'origine (les statistiques et
  /// les favoris ne sont pas touchés).
  Future<void> resetAll() async {
    for (final String k in _allKeys) {
      await _p.remove(k);
    }
    _loadFromPrefs();
    notifyListeners();
  }
}
