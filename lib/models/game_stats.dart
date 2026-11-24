/// Statistiques d'un jeu, sauvegardées sur le téléphone.
class GameStats {
  const GameStats({this.launches = 0, this.lastLaunchMs = 0, this.playMs = 0});

  /// Nombre de lancements depuis ce lanceur.
  final int launches;

  /// Date du dernier lancement (millisecondes depuis 1970), 0 = jamais.
  final int lastLaunchMs;

  /// Temps de jeu ESTIMÉ : durée entre le lancement et le retour dans le lanceur.
  final int playMs;

  GameStats copyWith({int? launches, int? lastLaunchMs, int? playMs}) {
    return GameStats(
      launches: launches ?? this.launches,
      lastLaunchMs: lastLaunchMs ?? this.lastLaunchMs,
      playMs: playMs ?? this.playMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'l': launches,
        't': lastLaunchMs,
        'p': playMs,
      };

  factory GameStats.fromJson(Map<String, dynamic> json) {
    return GameStats(
      launches: (json['l'] as num?)?.toInt() ?? 0,
      lastLaunchMs: (json['t'] as num?)?.toInt() ?? 0,
      playMs: (json['p'] as num?)?.toInt() ?? 0,
    );
  }
}
