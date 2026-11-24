import 'package:flutter/material.dart';

/// Les chiffres sur lesquels les succès sont calculés.
class AchievementInput {
  const AchievementInput({
    required this.launches,
    required this.distinctGames,
    required this.playMs,
    required this.boosts,
    required this.freedMb,
    required this.favorites,
    required this.dndCount,
    required this.gamesCount,
  });

  final int launches;
  final int distinctGames;
  final int playMs;
  final int boosts;
  final int freedMb;
  final int favorites;
  final int dndCount;
  final int gamesCount;
}

/// Un succès : débloqué quand [value] atteint [target].
class Achievement {
  const Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.target,
    required this.value,
  });

  final String title;
  final String description;
  final IconData icon;
  final int target;
  final int Function(AchievementInput input) value;

  bool isUnlocked(AchievementInput input) => value(input) >= target;

  double progress(AchievementInput input) {
    if (target <= 0) return 1.0;
    final double p = value(input) / target;
    return p < 0.0 ? 0.0 : (p > 1.0 ? 1.0 : p);
  }
}

const int _hour = 60 * 60 * 1000;

final List<Achievement> allAchievements = <Achievement>[
  Achievement(
    title: 'Contact',
    description: 'Lance un premier jeu depuis le lanceur.',
    icon: Icons.rocket_launch_rounded,
    target: 1,
    value: (AchievementInput i) => i.launches,
  ),
  Achievement(
    title: 'Habitué',
    description: 'Fais 10 lancements.',
    icon: Icons.local_fire_department_rounded,
    target: 10,
    value: (AchievementInput i) => i.launches,
  ),
  Achievement(
    title: 'Pilote',
    description: 'Fais 50 lancements.',
    icon: Icons.speed_rounded,
    target: 50,
    value: (AchievementInput i) => i.launches,
  ),
  Achievement(
    title: 'Explorateur',
    description: 'Lance 5 jeux différents.',
    icon: Icons.explore_rounded,
    target: 5,
    value: (AchievementInput i) => i.distinctGames,
  ),
  Achievement(
    title: 'Marathon',
    description: 'Cumule 2 h de jeu.',
    icon: Icons.timer_rounded,
    target: 2 * _hour,
    value: (AchievementInput i) => i.playMs,
  ),
  Achievement(
    title: 'Insomniaque',
    description: 'Cumule 10 h de jeu.',
    icon: Icons.hourglass_bottom_rounded,
    target: 10 * _hour,
    value: (AchievementInput i) => i.playMs,
  ),
  Achievement(
    title: 'Nettoyeur',
    description: 'Fais ton premier nettoyage de RAM.',
    icon: Icons.cleaning_services_rounded,
    target: 1,
    value: (AchievementInput i) => i.boosts,
  ),
  Achievement(
    title: 'Turbo',
    description: 'Fais 10 nettoyages de RAM.',
    icon: Icons.bolt_rounded,
    target: 10,
    value: (AchievementInput i) => i.boosts,
  ),
  Achievement(
    title: 'Libérateur',
    description: 'Libère 1 Go de RAM au total.',
    icon: Icons.memory_rounded,
    target: 1024,
    value: (AchievementInput i) => i.freedMb,
  ),
  Achievement(
    title: 'Zen',
    description: 'Active « Ne pas déranger » une fois.',
    icon: Icons.do_not_disturb_on_rounded,
    target: 1,
    value: (AchievementInput i) => i.dndCount,
  ),
  Achievement(
    title: 'Fan',
    description: 'Mets 3 jeux en favoris.',
    icon: Icons.star_rounded,
    target: 3,
    value: (AchievementInput i) => i.favorites,
  ),
  Achievement(
    title: 'Collectionneur',
    description: 'Aie 10 jeux dans ta bibliothèque.',
    icon: Icons.collections_bookmark_rounded,
    target: 10,
    value: (AchievementInput i) => i.gamesCount,
  ),
];
