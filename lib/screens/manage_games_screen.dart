import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../models/game.dart';
import '../widgets/neon_panel.dart';

/// « Mes jeux » : choisir quelles applis apparaissent dans la bibliothèque.
/// Utile quand Android ne reconnaît pas un jeu comme tel (il manque alors à
/// l'accueil) ou pour masquer un jeu qu'on ne veut pas voir.
class ManageGamesScreen extends StatefulWidget {
  const ManageGamesScreen({super.key});

  @override
  State<ManageGamesScreen> createState() => _ManageGamesScreenState();
}

class _ManageGamesScreenState extends State<ManageGamesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);

    return Scaffold(
      backgroundColor: Neon.bg,
      appBar: AppBar(
        backgroundColor: Neon.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Neon.cyan),
        title: Text('MES JEUX', style: displayStyle(size: 16, spacing: 3)),
        actions: <Widget>[
          IconButton(
            tooltip: 'Rescanner',
            onPressed: () => app.loadGames(),
            icon: const Icon(Icons.refresh_rounded, color: Neon.cyan),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[app, app.library, app.settings]),
        builder: (BuildContext context, Widget? child) {
          final List<Game> all = app.allApps;
          final List<Game> shown = _query.isEmpty
              ? all
              : all.where((Game g) => g.name.toLowerCase().contains(_query)).toList();

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: TextField(
                  onChanged: (String v) => setState(() => _query = v.trim().toLowerCase()),
                  style: const TextStyle(color: Neon.text),
                  cursorColor: Neon.cyan,
                  decoration: InputDecoration(
                    hintText: 'Rechercher une appli…',
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
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                child: Text(
                  '${app.gamesCount} dans ta bibliothèque  ·  ${all.length} applis trouvées.\n'
                  'Active une appli pour la voir sur l\'accueil.',
                  style: const TextStyle(color: Neon.textDim, fontSize: 12, height: 1.4),
                ),
              ),
              Expanded(
                child: all.isEmpty
                    ? _empty(app)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: shown.length,
                        itemBuilder: (BuildContext context, int i) {
                          final Game g = shown[i];
                          return _AppTile(
                            game: g,
                            inLibrary: app.isInLibrary(g),
                            onChanged: (bool v) => app.setInLibrary(g, v),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _empty(AppState app) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: NeonPanel(
          accent: Neon.amber,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                app.loading ? 'SCAN EN COURS…' : 'AUCUNE APPLI TROUVÉE',
                style: displayStyle(size: 14, color: Neon.amber, spacing: 2),
              ),
              const SizedBox(height: 10),
              const Text(
                "Si le scan échoue, ouvre Réglages › Diagnostic pour voir la cause.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Neon.textDim, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: app.loading ? null : () => app.loadGames(),
                child: const Text('RESCANNER'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.game,
    required this.inLibrary,
    required this.onChanged,
  });

  final Game game;
  final bool inLibrary;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Neon.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: inLibrary ? Neon.fade(Neon.cyan, 0.35) : Neon.fade(Neon.cyan, 0.10),
        ),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(width: 44, height: 44, child: _icon()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  game.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: inLibrary ? Neon.text : Neon.textDim,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  game.isGame ? 'Détecté comme jeu' : 'Application',
                  style: TextStyle(
                    color: game.isGame ? Neon.cyan : Neon.textDim,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: inLibrary, onChanged: onChanged),
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
      child: Center(child: Text(letter, style: displayStyle(size: 18))),
    );
  }
}
