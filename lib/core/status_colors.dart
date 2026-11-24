import 'package:flutter/material.dart';

import 'theme.dart';

/// Couleur de la température de la batterie selon le seuil d'alerte [warn].
Color tempColor(double tempC, int warn) {
  if (tempC <= 0) return Neon.textDim;
  if (tempC >= warn) return Neon.red;
  if (tempC >= warn - 4) return Neon.amber;
  return Neon.cyan;
}

/// Couleur de l'occupation de la RAM (0.0 à 1.0).
Color ramColor(double usedRatio) {
  if (usedRatio >= 0.85) return Neon.red;
  if (usedRatio >= 0.70) return Neon.amber;
  return Neon.cyan;
}

/// Couleur du niveau de batterie.
Color batteryColor(int level, bool charging) {
  if (level < 0) return Neon.textDim;
  if (charging) return Neon.green;
  if (level <= 15) return Neon.red;
  if (level <= 30) return Neon.amber;
  return Neon.cyan;
}

/// Couleur du remplissage du stockage (0.0 à 1.0).
Color storageColor(double usedRatio) {
  if (usedRatio >= 0.92) return Neon.red;
  if (usedRatio >= 0.80) return Neon.amber;
  return Neon.cyan;
}
