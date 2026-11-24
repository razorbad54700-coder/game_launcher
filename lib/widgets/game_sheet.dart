import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/app_state.dart';
import '../core/formatters.dart';
import '../core/native_bridge.dart';
import '../core/theme.dart';
import '../models/game.dart';
import '../models/game_stats.dart';
import 'neon_launch_button.dart';

/// Fiche d'un jeu : statistiques, favori, masquer, infos Android, lancer.
Future<void> showGameSheet(
  BuildContext context,
  Game game, {
  required void Function(Game game) onLaunch,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Neon.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (BuildContext sheetContext) {
      return _GameSheet(game: game, onLaunch: onLaunch);
    },
  );
}

class _GameSheet extends StatelessWidget {
  const _GameSheet({required this.game, required this.onLaunch});

  final Game game;
  final void Function(Game game) onLaunch;

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);

    return SafeArea(
      child: ListenableBuilder(
        listenable: app.library,
        builder: (BuildContext context, Widget? child) {
          final GameStats stats = app.library.statsFor(game.packageName);
          final bool fav = app.library.isFavorite(game.packageName);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Neon.fade(Neon.cyan, 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(width: 64, height: 64, child: _icon()),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            game.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: displayStyle(size: 19, spacing: 1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            game.packageName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: monoStyle(size: 10.5, color: Neon.textDim),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    _Stat(label: 'LANCEMENTS', value: '${stats.launches}'),
                    const SizedBox(width: 10),
                    _Stat(label: 'TEMPS DE JEU', value: formatDuration(stats.playMs)),
                    const SizedBox(width: 10),
                    _Stat(label: 'DERNIER', value: formatAgo(stats.lastLaunchMs)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Action(
                        icon: fav ? Icons.star_rounded : Icons.star_border_rounded,
                        label: fav ? 'FAVORI' : 'FAVORIS',
                        color: fav ? Neon.amber : Neon.cyan,
                        onTap: () {
                          app.haptics.select();
                          app.library.toggleFavorite(game.packageName);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Action(
                        icon: Icons.visibility_off_rounded,
                        label: 'MASQUER',
                        color: Neon.cyan,
                        onTap: () {
                          app.library.setHidden(game.packageName, true);
                          app.message.value =
                              'Jeu masqué. Retrouve-le dans Réglages › Mes jeux.';
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Action(
                        icon: Icons.info_outline_rounded,
                        label: 'INFOS',
                        color: Neon.cyan,
                        onTap: () async {
                          final bool ok =
                              await NativeBridge.openAppInfo(game.packageName);
                          if (!ok) {
                            app.message.value = app.demo
                                ? "Indisponible en mode démo."
                                : "Impossible d'ouvrir les infos de l'appli.";
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: NeonLaunchButton(
                    label: 'LANCER',
                    width: 280,
                    height: 62,
                    fontSize: 22,
                    onPressed: () {
                      Navigator.of(context).pop();
                      onLaunch(game);
                    },
                  ),
                ),
              ],
            ),
          );
        },
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
          colors: <Color>[Neon.fade(Neon.red, 0.4), Neon.fade(Neon.cyan, 0.3)],
        ),
      ),
      child: Center(child: Text(letter, style: displayStyle(size: 26))),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Neon.panelHi,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: <Widget>[
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: displayStyle(size: 16, color: Neon.cyan, spacing: 0.5)),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Neon.textDim,
                fontSize: 9,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Neon.fade(color, 0.5)),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
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
