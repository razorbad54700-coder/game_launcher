import 'package:flutter/material.dart';

/// Palette « cyber » : fond quasi noir, rouge et cyan électriques.
class Neon {
  Neon._();

  static const Color bg = Color(0xFF05060B);
  static const Color panel = Color(0xFF0D0F18);
  static const Color panelHi = Color(0xFF171A27);
  static const Color red = Color(0xFFFF1F4B);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color amber = Color(0xFFFFB020);
  static const Color green = Color(0xFF39FF9A);
  static const Color text = Color(0xFFE9ECF5);
  static const Color textDim = Color(0xFF7C8396);

  /// Même couleur avec une opacité de 0.0 à 1.0.
  /// (withAlpha marche sur toutes les versions de Flutter, contrairement à
  /// withOpacity / withValues dont l'API a changé récemment.)
  static Color fade(Color c, double opacity) {
    final double o = opacity < 0 ? 0.0 : (opacity > 1 ? 1.0 : opacity);
    return c.withAlpha((o * 255).round());
  }

  /// Halo lumineux néon (à mettre dans BoxDecoration.boxShadow).
  static List<BoxShadow> glow(Color c, {double strength = 1}) => <BoxShadow>[
        BoxShadow(color: fade(c, 0.55), blurRadius: 16 * strength),
        BoxShadow(
          color: fade(c, 0.25),
          blurRadius: 40 * strength,
          spreadRadius: 2 * strength,
        ),
      ];
}

/// Texte « titre » : gras, très espacé, façon affichage de tableau de bord.
TextStyle displayStyle({
  double size = 18,
  Color color = Neon.text,
  FontWeight weight = FontWeight.w800,
  double spacing = 2,
}) {
  return TextStyle(
    fontSize: size,
    color: color,
    fontWeight: weight,
    letterSpacing: spacing,
  );
}

/// Texte « terminal » à chasse fixe (journal de démarrage, valeurs).
TextStyle monoStyle({
  double size = 12,
  Color color = Neon.cyan,
  FontWeight weight = FontWeight.w500,
  double spacing = 0.5,
}) {
  return TextStyle(
    fontFamily: 'monospace',
    fontSize: size,
    color: color,
    fontWeight: weight,
    letterSpacing: spacing,
  );
}

/// Valeur bornée entre [lo] et [hi] (évite les surprises de num.clamp).
double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

int clampI(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Neon.bg,
    colorScheme: const ColorScheme.dark(
      primary: Neon.cyan,
      secondary: Neon.red,
      surface: Neon.panel,
      error: Neon.red,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? Neon.cyan : Neon.textDim,
      ),
      trackColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? Neon.fade(Neon.cyan, 0.30)
            : Neon.panelHi,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? Neon.cyan
            : const Color(0xFF2A2F42),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: Neon.cyan,
      inactiveTrackColor: Neon.fade(Neon.cyan, 0.20),
      thumbColor: Neon.cyan,
      overlayColor: Neon.fade(Neon.cyan, 0.15),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Neon.panelHi,
      contentTextStyle: TextStyle(color: Neon.text),
      behavior: SnackBarBehavior.floating,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Neon.panelHi,
      textStyle: TextStyle(color: Neon.text),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Neon.panel,
      modalBackgroundColor: Neon.panel,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Neon.cyan,
        side: BorderSide(color: Neon.fade(Neon.cyan, 0.6)),
      ),
    ),
    dividerTheme: DividerThemeData(color: Neon.fade(Neon.cyan, 0.15)),
  );
}
