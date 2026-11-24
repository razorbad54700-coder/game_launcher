import 'dart:typed_data';

/// Une appli lançable détectée sur le téléphone (jeu ou non).
class Game {
  const Game({
    required this.name,
    required this.packageName,
    this.icon,
    this.isGame = true,
  });

  final String name;

  /// Identifiant Android (ex. com.supercell.clashofclans).
  final String packageName;

  /// Icône au format PNG, ou null (on affiche alors une initiale stylisée).
  final Uint8List? icon;

  /// Vrai si Android classe l'appli comme un jeu.
  final bool isGame;
}
