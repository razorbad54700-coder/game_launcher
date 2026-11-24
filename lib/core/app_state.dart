import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game.dart';
import '../models/game_stats.dart';
import 'achievements.dart';
import 'app_log.dart';
import 'formatters.dart';
import 'gaming_service.dart';
import 'haptics.dart';
import 'library_store.dart';
import 'native_bridge.dart';
import 'settings.dart';
import 'sound_service.dart';
import 'system_monitor.dart';

/// Filtre de la bibliothèque (les puces sous la barre de recherche).
enum LibraryFilter { all, favorites, recent }

/// Résultat d'une tentative de lancement.
class LaunchResult {
  const LaunchResult({required this.ok, required this.report});

  final bool ok;
  final BoostReport report;
}

/// Le « cerveau » de l'appli : réglages, bibliothèque, mesures système, sons,
/// liste des jeux, lancement. Les écrans écoutent les morceaux qui les
/// concernent ([settings], [library], [monitor], [gaming]) et cet objet lui-même
/// (liste des jeux, recherche, filtre).
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState._(
    this.settings,
    this.library,
    this.monitor,
    this.sound,
    this.haptics,
    this.gaming,
  );

  factory AppState.create(SharedPreferences prefs) {
    final SettingsController settings = SettingsController(prefs);
    final LibraryStore library = LibraryStore(prefs);
    final SystemMonitor monitor = SystemMonitor();
    final SoundService sound = SoundService(settings);
    final Haptics haptics = Haptics(settings);
    final GamingService gaming = GamingService(prefs, library, monitor);
    return AppState._(settings, library, monitor, sound, haptics, gaming);
  }

  final SettingsController settings;
  final LibraryStore library;
  final SystemMonitor monitor;
  final SoundService sound;
  final Haptics haptics;
  final GamingService gaming;

  /// Message court à afficher en bas de l'écran (succès, fin de partie…).
  /// L'écran principal l'affiche puis le remet à null.
  final ValueNotifier<String?> message = ValueNotifier<String?>(null);

  // ------------------------------------------------------------ état

  List<Game> _apps = const <Game>[];
  bool _loading = false;
  bool _scanned = false;
  bool _scanFailed = false;
  int _loadToken = 0;
  int _loadedAtMs = 0;

  String _query = '';
  LibraryFilter _filter = LibraryFilter.all;

  bool _started = false;
  bool _disposed = false;
  bool _leftApp = false;
  bool _launching = false;
  bool _lastImmersive = false;

  final Set<String> _knownUnlocked = <String>{};
  bool _achievementsReady = false;

  bool get demo => !NativeBridge.supported;
  bool get loading => _loading;

  /// Vrai quand un scan a déjà eu lieu (réussi ou non).
  bool get scanned => _scanned;

  /// Vrai si le dernier scan a échoué (liaison Android muette).
  bool get scanFailed => _scanFailed;

  String get query => _query;
  LibraryFilter get filter => _filter;

  /// Toutes les applis lançables trouvées sur le téléphone.
  List<Game> get allApps => _apps;

  // ------------------------------------------------------------ démarrage

  /// À appeler une fois, après la création. Lance les mesures et le scan.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    library.addListener(_checkAchievements);
    settings.addListener(_onSettingsChanged);
    _lastImmersive = settings.immersive;
    _applySystemUi();

    monitor.start();
    NativeBridge.ping();
    await gaming.refreshDnd();
    // Si Android a fermé le lanceur pendant une partie : on rattrape.
    await gaming.restoreAfterGame();
    await library.endSession();
    await loadGames();
  }

  void _onSettingsChanged() {
    if (settings.immersive != _lastImmersive) {
      _lastImmersive = settings.immersive;
      _applySystemUi();
    }
    // Le filtrage dépend de « tout afficher » : on prévient les écrans.
    notifyListeners();
  }

  void _applySystemUi() {
    try {
      SystemChrome.setEnabledSystemUIMode(
        settings.immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    } catch (e) {
      AppLog.add('Mode immersif impossible : $e');
    }
  }

  // ------------------------------------------------------------ scan des jeux

  static List<Game> _demoGames() {
    const List<String> names = <String>[
      'Neon Racer',
      'Cyber Arena',
      'Drift Legends',
      'Asphalt Nitro',
      'Void Runner',
      'Space Siege',
      'Turbo Garage',
      'Pixel Kart',
    ];
    return <Game>[
      for (final String n in names)
        Game(name: n, packageName: 'demo.${n.toLowerCase().replaceAll(' ', '')}'),
    ];
  }

  /// (Re)scanne les applis du téléphone.
  Future<void> loadGames() async {
    final int token = ++_loadToken;
    _loading = true;
    notifyListeners();

    List<Game>? found;
    if (demo) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      found = _demoGames();
    } else {
      found = await NativeBridge.getGames(includeAll: true);
    }
    if (_disposed || token != _loadToken) return; // un scan plus récent a pris le relais

    _loading = false;
    _scanned = true;
    _scanFailed = found == null;
    if (found != null) {
      _apps = found;
      _loadedAtMs = DateTime.now().millisecondsSinceEpoch;
    }
    if (!_achievementsReady) {
      _achievementsReady = true;
      _knownUnlocked
        ..clear()
        ..addAll(_unlockedTitles());
    }
    notifyListeners();
  }

  // ------------------------------------------------------------ bibliothèque

  /// Cette appli apparaît-elle dans « Mes jeux » ?
  bool isInLibrary(Game g) {
    if (library.isHidden(g.packageName)) return false;
    if (settings.showAllApps) return true;
    return g.isGame || library.isExtra(g.packageName);
  }

  /// Bascule la présence d'une appli dans « Mes jeux » (écran de gestion).
  Future<void> setInLibrary(Game g, bool inLibrary) async {
    if (g.isGame || settings.showAllApps) {
      await library.setHidden(g.packageName, !inLibrary);
      if (inLibrary && !g.isGame) await library.setExtra(g.packageName, true);
    } else {
      await library.setExtra(g.packageName, inLibrary);
    }
  }

  /// Jeux de la bibliothèque, avant recherche et filtre.
  List<Game> get libraryGames =>
      _apps.where(isInLibrary).toList(growable: false);

  int get gamesCount => libraryGames.length;

  void setQuery(String q) {
    final String clean = q.trim().toLowerCase();
    if (clean == _query) return;
    _query = clean;
    notifyListeners();
  }

  void setFilter(LibraryFilter f) {
    if (f == _filter) return;
    _filter = f;
    notifyListeners();
  }

  /// Jeux à afficher : bibliothèque + recherche + filtre + tri.
  List<Game> get visibleGames {
    List<Game> list = libraryGames.toList();

    if (_query.isNotEmpty) {
      list = list
          .where((Game g) =>
              g.name.toLowerCase().contains(_query) ||
              g.packageName.toLowerCase().contains(_query))
          .toList();
    }

    if (_filter == LibraryFilter.favorites) {
      list = list.where((Game g) => library.isFavorite(g.packageName)).toList();
    } else if (_filter == LibraryFilter.recent) {
      list = list
          .where((Game g) => library.statsFor(g.packageName).lastLaunchMs > 0)
          .toList();
    }

    int byName(Game a, Game b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());

    final SortMode mode =
        _filter == LibraryFilter.recent ? SortMode.recent : settings.sortMode;
    switch (mode) {
      case SortMode.alpha:
        list.sort(byName);
        break;
      case SortMode.recent:
        list.sort((Game a, Game b) {
          final int c = library
              .statsFor(b.packageName)
              .lastLaunchMs
              .compareTo(library.statsFor(a.packageName).lastLaunchMs);
          return c != 0 ? c : byName(a, b);
        });
        break;
      case SortMode.mostPlayed:
        list.sort((Game a, Game b) {
          final GameStats sa = library.statsFor(a.packageName);
          final GameStats sb = library.statsFor(b.packageName);
          int c = sb.playMs.compareTo(sa.playMs);
          if (c == 0) c = sb.launches.compareTo(sa.launches);
          return c != 0 ? c : byName(a, b);
        });
        break;
      case SortMode.favoritesFirst:
        list.sort((Game a, Game b) {
          final bool fa = library.isFavorite(a.packageName);
          final bool fb = library.isFavorite(b.packageName);
          if (fa != fb) return fa ? -1 : 1;
          return byName(a, b);
        });
        break;
    }
    return list;
  }

  // ------------------------------------------------------------ lancement

  /// Optimise selon le profil choisi, puis lance le jeu. [onStep] reçoit un
  /// texte à afficher pour chaque étape.
  Future<LaunchResult> launch(Game g, {void Function(String step)? onStep}) async {
    if (_launching) return const LaunchResult(ok: false, report: BoostReport());
    _launching = true;
    try {
      haptics.heavy();
      sound.launch();

      BoostReport report = const BoostReport();
      try {
        report = await gaming.applyProfile(
          settings.boostProfile,
          keepPackage: g.packageName,
          onStep: onStep,
        );
      } catch (e) {
        AppLog.add("Optimisation avant lancement en échec : $e");
      }

      onStep?.call('Lancement de ${g.name}…');
      bool ok;
      if (demo) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        ok = true;
      } else {
        ok = await NativeBridge.launchGame(g.packageName);
      }

      if (ok) {
        await library.recordLaunch(g.packageName);
        if (!demo) {
          await library.startSession(g.packageName);
          // On attend d'avoir réellement quitté le lanceur avant de réagir à
          // un « retour » (sinon un faux événement ferait tout annuler).
          _leftApp = false;
        }
      } else {
        await gaming.restoreAfterGame();
        haptics.medium();
        sound.warn();
      }
      return LaunchResult(ok: ok, report: report);
    } finally {
      _launching = false;
    }
  }

  // ------------------------------------------------------------ cycle de vie

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _leftApp = true;
      monitor.stop();
    } else if (state == AppLifecycleState.resumed) {
      monitor.start();
      if (_leftApp) {
        _leftApp = false;
        _onReturned();
      }
    }
  }

  Future<void> _onReturned() async {
    try {
      await gaming.restoreAfterGame();
      final int ms = await library.endSession();
      await gaming.refreshDnd();
      if (ms > 0) {
        message.value = 'Bon retour ! Séance : ${formatDuration(ms)}';
      }
      // On rescanne si la dernière liste date de plus d'une minute (une appli
      // a pu être installée ou désinstallée entre-temps).
      final int age = DateTime.now().millisecondsSinceEpoch - _loadedAtMs;
      if (age > 60000) await loadGames();
    } catch (e) {
      AppLog.add('Retour dans le lanceur : $e');
    }
  }

  // ------------------------------------------------------------ succès

  AchievementInput get achievementInput => AchievementInput(
        launches: library.totalLaunches,
        distinctGames: library.distinctGamesLaunched,
        playMs: library.totalPlayMs,
        boosts: library.boostCount,
        freedMb: library.freedMbTotal,
        favorites: library.favoriteCount,
        dndCount: library.dndCount,
        gamesCount: gamesCount,
      );

  Set<String> _unlockedTitles() {
    final AchievementInput input = achievementInput;
    return <String>{
      for (final Achievement a in allAchievements)
        if (a.isUnlocked(input)) a.title,
    };
  }

  void _checkAchievements() {
    if (!_achievementsReady || _disposed) return;
    final Set<String> now = _unlockedTitles();
    final List<String> fresh =
        now.where((String t) => !_knownUnlocked.contains(t)).toList();
    if (fresh.isEmpty) return;
    _knownUnlocked.addAll(fresh);
    sound.success();
    haptics.medium();
    message.value = 'Succès débloqué : ${fresh.join(', ')}';
  }

  // ------------------------------------------------------------ fin

  @override
  void dispose() {
    _disposed = true;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      library.removeListener(_checkAchievements);
      settings.removeListener(_onSettingsChanged);
    }
    monitor.dispose();
    gaming.dispose();
    sound.dispose();
    library.dispose();
    settings.dispose();
    message.dispose();
    super.dispose();
  }
}
