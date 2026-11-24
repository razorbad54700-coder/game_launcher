import 'package:flutter/material.dart';

import '../core/achievements.dart';
import '../core/app_scope.dart';
import '../core/app_state.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/device_status.dart';
import '../models/game.dart';
import '../models/game_stats.dart';
import '../widgets/neon_panel.dart';

/// Statistiques de jeu et succès.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);

    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[app, app.library]),
        builder: (BuildContext context, Widget? child) {
          final AchievementInput input = app.achievementInput;
          final int unlocked =
              allAchievements.where((Achievement a) => a.isUnlocked(input)).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: <Widget>[
              Text('GAME LAUNCHER', style: displayStyle(size: 10, color: Neon.cyan, spacing: 4)),
              const SizedBox(height: 2),
              Text(
                'STATISTIQUES',
                style: displayStyle(size: 24, weight: FontWeight.w900, spacing: 3),
              ),
              const SizedBox(height: 18),
              _summary(app),
              const SectionTitle('JEUX LES PLUS JOUÉS'),
              _topGames(app),
              SectionTitle(
                'SUCCÈS  $unlocked/${allAchievements.length}',
              ),
              for (final Achievement a in allAchievements) ...<Widget>[
                _AchievementTile(achievement: a, input: input),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 10),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmReset(context, app),
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('RÉINITIALISER LES STATS'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Le temps de jeu est une estimation : c'est la durée entre le moment où tu "
                "lances un jeu depuis ce lanceur et celui où tu reviens dans le lanceur.",
                style: TextStyle(color: Neon.textDim, fontSize: 11.5, height: 1.45),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summary(AppState app) {
    final int launches = app.library.totalLaunches;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            _Tile(label: 'LANCEMENTS', value: '$launches', color: Neon.red),
            const SizedBox(width: 10),
            _Tile(
              label: 'TEMPS DE JEU',
              value: formatDuration(app.library.totalPlayMs),
              color: Neon.cyan,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            _Tile(
              label: 'JEUX LANCÉS',
              value: '${app.library.distinctGamesLaunched}',
              color: Neon.cyan,
            ),
            const SizedBox(width: 10),
            _Tile(
              label: 'RAM LIBÉRÉE',
              value: formatMb(app.library.freedMbTotal),
              color: Neon.green,
            ),
          ],
        ),
      ],
    );
  }

  Widget _topGames(AppState app) {
    final List<Game> played = app.allApps
        .where((Game g) => app.library.statsFor(g.packageName).launches > 0)
        .toList();
    played.sort((Game a, Game b) {
      final GameStats sa = app.library.statsFor(a.packageName);
      final GameStats sb = app.library.statsFor(b.packageName);
      int c = sb.playMs.compareTo(sa.playMs);
      if (c == 0) c = sb.launches.compareTo(sa.launches);
      return c;
    });

    if (played.isEmpty) {
      return const NeonPanel(
        child: Text(
          'Lance un jeu depuis ici pour voir apparaître ton classement.',
          style: TextStyle(color: Neon.textDim, fontSize: 13, height: 1.4),
        ),
      );
    }

    final List<Game> top = played.take(5).toList();
    final GameStats first = app.library.statsFor(top.first.packageName);
    // La barre se règle sur le temps de jeu, ou sur les lancements s'il n'y a
    // encore aucun temps compté.
    final bool byTime = first.playMs > 0;
    final int maxValue = byTime ? first.playMs : first.launches;

    return NeonPanel(
      child: Column(
        children: <Widget>[
          for (int i = 0; i < top.length; i++)
            _RankRow(
              rank: i + 1,
              game: top[i],
              stats: app.library.statsFor(top[i].packageName),
              ratio: maxValue <= 0
                  ? 0.0
                  : (byTime
                          ? app.library.statsFor(top[i].packageName).playMs
                          : app.library.statsFor(top[i].packageName).launches) /
                      maxValue,
            ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, AppState app) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: Neon.panelHi,
        title: Text('Réinitialiser ?', style: displayStyle(size: 16, spacing: 1)),
        content: const Text(
          'Les lancements, le temps de jeu et les compteurs seront remis à zéro. '
          'Tes favoris sont conservés.',
          style: TextStyle(color: Neon.textDim),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ANNULER'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('RÉINITIALISER', style: TextStyle(color: Neon.red)),
          ),
        ],
      ),
    );
    if (yes == true) {
      await app.library.resetStats();
      app.message.value = 'Statistiques remises à zéro.';
    }
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Neon.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Neon.fade(color, 0.35)),
        ),
        child: Column(
          children: <Widget>[
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: displayStyle(size: 24, color: color, spacing: 0.5)),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Neon.textDim,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.game,
    required this.stats,
    required this.ratio,
  });

  final int rank;
  final Game game;
  final GameStats stats;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final String plural = stats.launches > 1 ? 's' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 26,
            child: Text(
              '$rank',
              style: displayStyle(size: 18, color: rank == 1 ? Neon.amber : Neon.textDim),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 38, height: 38, child: _icon()),
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
                  style: const TextStyle(
                    color: Neon.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDuration(stats.playMs)}  ·  ${stats.launches} lancement$plural',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Neon.textDim, fontSize: 11.5),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: clampD(ratio, 0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: Neon.fade(Neon.cyan, 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(Neon.cyan),
                  ),
                ),
              ],
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
      child: Center(child: Text(letter, style: displayStyle(size: 16))),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.input});

  final Achievement achievement;
  final AchievementInput input;

  @override
  Widget build(BuildContext context) {
    final bool done = achievement.isUnlocked(input);
    final double p = achievement.progress(input);
    final Color c = done ? Neon.amber : Neon.textDim;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: done ? Neon.fade(Neon.amber, 0.07) : Neon.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: done ? Neon.fade(Neon.amber, 0.6) : Neon.fade(Neon.cyan, 0.15)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Neon.fade(c, 0.14),
              border: Border.all(color: Neon.fade(c, 0.6)),
            ),
            child: Icon(achievement.icon, color: c, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  achievement.title.toUpperCase(),
                  style: displayStyle(size: 13, color: done ? Neon.text : Neon.textDim, spacing: 2),
                ),
                const SizedBox(height: 3),
                Text(
                  achievement.description,
                  style: const TextStyle(color: Neon.textDim, fontSize: 12, height: 1.3),
                ),
                if (!done) ...<Widget>[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: p,
                      minHeight: 4,
                      backgroundColor: Neon.fade(Neon.cyan, 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(Neon.cyan),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (done) const Icon(Icons.check_circle_rounded, color: Neon.amber),
        ],
      ),
    );
  }
}
