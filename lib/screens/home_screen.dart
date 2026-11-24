import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/app_state.dart';
import '../core/formatters.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../models/game.dart';
import '../models/game_stats.dart';
import '../widgets/game_carousel.dart';
import '../widgets/game_sheet.dart';
import '../widgets/launch_overlay.dart';
import '../widgets/native_error_banner.dart';
import '../widgets/neon_launch_button.dart';
import '../widgets/neon_panel.dart';
import '../widgets/status_strip.dart';
import 'diagnostic_screen.dart';
import 'manage_games_screen.dart';

/// Accueil : carrousel 3D (ou grille) des jeux, recherche, filtres, tri,
/// bandeau d'état et gros bouton LANCER.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenGaming});

  /// Appelé quand on touche le bandeau d'état (ouvre l'onglet Mode Gaming).
  final VoidCallback onOpenGaming;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchCtl = TextEditingController();

  AppState? _app;
  List<Game> _visible = const <Game>[];
  String _signature = '';
  String? _selectedPkg;
  int _selected = 0;
  bool _searching = false;
  Game? _launching;
  String _step = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app ??= AppScope.of(context);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ sélection

  /// Garde la sélection sur le même jeu quand la liste change (tri, filtre…).
  void _syncSelection(List<Game> visible) {
    _visible = visible;
    final String sig = visible.map((Game g) => g.packageName).join('|');
    if (sig == _signature) return;
    _signature = sig;
    int idx = -1;
    final String? keep = _selectedPkg;
    if (keep != null) {
      idx = visible.indexWhere((Game g) => g.packageName == keep);
    }
    if (idx < 0) idx = 0;
    if (visible.isEmpty) {
      _selected = 0;
      _selectedPkg = null;
    } else {
      _selected = idx;
      _selectedPkg = visible[idx].packageName;
    }
  }

  Game? get _current =>
      (_selected >= 0 && _selected < _visible.length) ? _visible[_selected] : null;

  void _onPageChanged(int i) {
    if (i < 0 || i >= _visible.length) return;
    if (i == _selected) return;
    _app?.haptics.select();
    setState(() {
      _selected = i;
      _selectedPkg = _visible[i].packageName;
    });
  }

  void _selectIndex(int i) {
    if (i < 0 || i >= _visible.length) return;
    _app?.haptics.select();
    _app?.sound.tick();
    setState(() {
      _selected = i;
      _selectedPkg = _visible[i].packageName;
    });
  }

  // ------------------------------------------------------------ actions

  Future<void> _launch(Game g) async {
    final AppState? app = _app;
    if (app == null || _launching != null) return;
    setState(() {
      _launching = g;
      _step = 'Préparation…';
    });

    final LaunchResult r = await app.launch(g, onStep: (String s) {
      if (mounted) setState(() => _step = s);
    });
    if (!mounted) return;

    if (r.ok && !app.demo) {
      // On laisse l'écran de lancement visible jusqu'à ce que le jeu apparaisse.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
    }
    setState(() => _launching = null);

    if (!r.ok) {
      app.message.value = "Impossible de lancer « ${g.name} ».";
    } else if (r.report.dndNeedsPermission) {
      app.message.value =
          "Profil Performance : autorise « Ne pas déranger » dans l'onglet Gaming.";
    } else if (app.demo) {
      app.message.value = 'Mode démo : aucun vrai jeu n\'est lancé.';
    }
  }

  void _openSheet(Game g) {
    showGameSheet(context, g, onLaunch: _launch);
  }

  void _openDiagnostic() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext c) => const DiagnosticScreen()),
    );
  }

  void _openManage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext c) => const ManageGamesScreen()),
    );
  }

  void _toggleSearch(AppState app) {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchCtl.clear();
        app.setQuery('');
      }
    });
  }

  // ------------------------------------------------------------ construction

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[app, app.library, app.settings]),
      builder: (BuildContext context, Widget? child) {
        final List<Game> visible = app.visibleGames;
        _syncSelection(visible);
        final Game? current = _current;
        final bool grid = app.settings.gridView;

        return Stack(
          children: <Widget>[
            SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  NativeErrorBanner(onDiagnostic: _openDiagnostic),
                  _header(app, visible.length),
                  if (_searching) _searchField(app),
                  _filters(app),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: StatusStrip(app: app, onTap: widget.onOpenGaming),
                  ),
                  Expanded(child: _body(app, visible, grid)),
                  if (current != null) _selectedInfo(app, current),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 14),
                    child: NeonLaunchButton(
                      label: 'LANCER',
                      onPressed: current == null ? null : () => _launch(current),
                      busy: _launching != null,
                    ),
                  ),
                ],
              ),
            ),
            if (_launching != null)
              Positioned.fill(
                child: LaunchOverlay(game: _launching!, step: _step),
              ),
          ],
        );
      },
    );
  }

  Widget _header(AppState app, int count) {
    final bool grid = app.settings.gridView;
    final String plural = count > 1 ? 'JEUX' : 'JEU';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 6, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'GAME LAUNCHER  ·  $count $plural',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: displayStyle(size: 10, color: Neon.cyan, spacing: 3),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'MON GARAGE',
                    style: displayStyle(size: 24, weight: FontWeight.w900, spacing: 3),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Rechercher',
            onPressed: () => _toggleSearch(app),
            icon: Icon(
              _searching ? Icons.close_rounded : Icons.search_rounded,
              color: Neon.cyan,
            ),
          ),
          IconButton(
            tooltip: grid ? 'Carrousel 3D' : 'Grille',
            onPressed: () => app.settings.setGridView(!grid),
            icon: Icon(
              grid ? Icons.view_carousel_rounded : Icons.grid_view_rounded,
              color: Neon.cyan,
            ),
          ),
          PopupMenuButton<SortMode>(
            tooltip: 'Trier',
            icon: const Icon(Icons.sort_rounded, color: Neon.cyan),
            onSelected: (SortMode m) => app.settings.setSortMode(m),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortMode>>[
              _sortItem(app, SortMode.alpha, 'Alphabétique'),
              _sortItem(app, SortMode.recent, 'Joués récemment'),
              _sortItem(app, SortMode.mostPlayed, 'Les plus joués'),
              _sortItem(app, SortMode.favoritesFirst, "Favoris d'abord"),
            ],
          ),
          IconButton(
            tooltip: 'Rescanner',
            onPressed: app.loading ? null : () => app.loadGames(),
            icon: Icon(
              Icons.refresh_rounded,
              color: app.loading ? Neon.textDim : Neon.cyan,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<SortMode> _sortItem(AppState app, SortMode m, String label) {
    final bool on = app.settings.sortMode == m;
    return PopupMenuItem<SortMode>(
      value: m,
      child: Row(
        children: <Widget>[
          Icon(
            on ? Icons.check_rounded : Icons.circle_outlined,
            size: 18,
            color: on ? Neon.cyan : Neon.textDim,
          ),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }

  Widget _searchField(AppState app) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: TextField(
        controller: _searchCtl,
        autofocus: true,
        onChanged: app.setQuery,
        style: const TextStyle(color: Neon.text),
        cursorColor: Neon.cyan,
        decoration: InputDecoration(
          hintText: 'Rechercher un jeu…',
          hintStyle: const TextStyle(color: Neon.textDim),
          prefixIcon: const Icon(Icons.search_rounded, color: Neon.cyan),
          filled: true,
          fillColor: Neon.panel,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Neon.fade(Neon.cyan, 0.35)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Neon.cyan),
          ),
        ),
      ),
    );
  }

  Widget _filters(AppState app) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: <Widget>[
          _FilterChip(
            label: 'TOUS',
            selected: app.filter == LibraryFilter.all,
            onTap: () => app.setFilter(LibraryFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'FAVORIS',
            icon: Icons.star_rounded,
            selected: app.filter == LibraryFilter.favorites,
            onTap: () => app.setFilter(LibraryFilter.favorites),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'RÉCENTS',
            icon: Icons.history_rounded,
            selected: app.filter == LibraryFilter.recent,
            onTap: () => app.setFilter(LibraryFilter.recent),
          ),
        ],
      ),
    );
  }

  Widget _body(AppState app, List<Game> visible, bool grid) {
    if (app.loading && !app.scanned) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3, color: Neon.cyan),
            ),
            const SizedBox(height: 14),
            Text('SCAN EN COURS…', style: monoStyle(size: 12)),
          ],
        ),
      );
    }

    if (app.scanFailed && app.allApps.isEmpty) {
      return _notePanel(
        title: 'LECTURE DES APPLIS IMPOSSIBLE',
        text: "Le scan a échoué. Ouvre le diagnostic pour voir pourquoi, "
            "puis réessaie.",
        actions: <Widget>[
          OutlinedButton(onPressed: () => app.loadGames(), child: const Text('RÉESSAYER')),
          OutlinedButton(onPressed: _openDiagnostic, child: const Text('DIAGNOSTIC')),
        ],
      );
    }

    if (visible.isEmpty) {
      final bool noGamesAtAll = app.libraryGames.isEmpty;
      if (noGamesAtAll) {
        return _notePanel(
          title: 'AUCUN JEU DÉTECTÉ',
          text: "Android ne classe pas toujours les jeux comme « jeux ». "
              "Affiche toutes les applis, ou ajoute tes jeux à la main.",
          actions: <Widget>[
            OutlinedButton(
              onPressed: () => app.settings.setShowAllApps(true),
              child: const Text('TOUT AFFICHER'),
            ),
            OutlinedButton(onPressed: _openManage, child: const Text('MES JEUX')),
          ],
        );
      }
      return _notePanel(
        title: 'AUCUN RÉSULTAT',
        text: 'Aucun jeu ne correspond à ta recherche ou à ce filtre.',
        actions: <Widget>[
          OutlinedButton(
            onPressed: () {
              _searchCtl.clear();
              app.setQuery('');
              app.setFilter(LibraryFilter.all);
            },
            child: const Text('RÉINITIALISER'),
          ),
        ],
      );
    }

    if (grid) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.80,
        ),
        itemCount: visible.length,
        itemBuilder: (BuildContext context, int i) {
          final Game g = visible[i];
          return _GridTile(
            game: g,
            selected: i == _selected,
            favorite: app.library.isFavorite(g.packageName),
            onTap: () => _selectIndex(i),
            onLongPress: () => _openSheet(g),
          );
        },
      );
    }

    return _CarouselHost(
      games: visible,
      selected: _selected,
      signature: _signature,
      onPageChanged: _onPageChanged,
      isFavorite: (Game g) => app.library.isFavorite(g.packageName),
      onLongPress: _openSheet,
    );
  }

  Widget _notePanel({
    required String title,
    required String text,
    required List<Widget> actions,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: NeonPanel(
          accent: Neon.red,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                textAlign: TextAlign.center,
                style: displayStyle(size: 14, color: Neon.red, spacing: 2),
              ),
              const SizedBox(height: 10),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Neon.textDim, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectedInfo(AppState app, Game g) {
    final GameStats s = app.library.statsFor(g.packageName);
    final bool fav = app.library.isFavorite(g.packageName);
    final String plural = s.launches > 1 ? 's' : '';
    final String sub = s.launches == 0
        ? 'Jamais lancé'
        : '${s.launches} lancement$plural  ·  ${formatDuration(s.playMs)} de jeu';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
            onPressed: () {
              app.haptics.select();
              app.library.toggleFavorite(g.packageName);
            },
            icon: Icon(
              fav ? Icons.star_rounded : Icons.star_border_rounded,
              color: fav ? Neon.amber : Neon.textDim,
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openSheet(g),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: displayStyle(size: 19, spacing: 1.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Neon.textDim, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Détails',
            onPressed: () => _openSheet(g),
            icon: const Icon(Icons.info_outline_rounded, color: Neon.cyan),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Petits composants de l'accueil
// ---------------------------------------------------------------------------

/// Héberge le carrousel avec son propre PageController, créé à la bonne page
/// et recalé quand la liste change (recherche, tri, filtre).
class _CarouselHost extends StatefulWidget {
  const _CarouselHost({
    required this.games,
    required this.selected,
    required this.signature,
    required this.onPageChanged,
    required this.isFavorite,
    required this.onLongPress,
  });

  final List<Game> games;
  final int selected;
  final String signature;
  final ValueChanged<int> onPageChanged;
  final bool Function(Game game) isFavorite;
  final ValueChanged<Game> onLongPress;

  @override
  State<_CarouselHost> createState() => _CarouselHostState();
}

class _CarouselHostState extends State<_CarouselHost> {
  late final PageController _controller = PageController(
    viewportFraction: 0.62,
    initialPage: widget.selected,
  );

  @override
  void didUpdateWidget(_CarouselHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signature != widget.signature) {
      final int target = widget.selected;
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (!mounted) return;
        if (!_controller.hasClients) return;
        if (!_controller.position.hasContentDimensions) return;
        if (target < 0 || target >= widget.games.length) return;
        _controller.jumpToPage(target);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameCarousel(
      games: widget.games,
      controller: _controller,
      onPageChanged: widget.onPageChanged,
      isFavorite: widget.isFavorite,
      onLongPress: widget.onLongPress,
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color c = selected ? Neon.red : Neon.textDim;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Neon.fade(Neon.red, 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Neon.fade(c, selected ? 0.9 : 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 14, color: c),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: c,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.game,
    required this.selected,
    required this.favorite,
    required this.onTap,
    required this.onLongPress,
  });

  final Game game;
  final bool selected;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final Color border = selected ? Neon.red : Neon.fade(Neon.cyan, 0.3);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Neon.panel,
                border: Border.all(color: border, width: selected ? 2 : 1),
                boxShadow: selected ? Neon.glow(Neon.red, strength: 0.6) : null,
              ),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _icon(),
                    ),
                  ),
                  if (favorite)
                    const Positioned(
                      top: 2,
                      right: 2,
                      child: Icon(Icons.star_rounded, size: 18, color: Neon.amber),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: Text(
                game.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Neon.text : Neon.textDim,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _icon() {
    final icon = game.icon;
    if (icon != null) {
      return Image.memory(icon, fit: BoxFit.cover, gaplessPlayback: true);
    }
    final String letter = game.name.isEmpty
        ? '?'
        : String.fromCharCode(game.name.runes.first).toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Neon.fade(Neon.red, 0.35), Neon.fade(Neon.cyan, 0.25)],
        ),
      ),
      child: Center(child: Text(letter, style: displayStyle(size: 28))),
    );
  }
}
