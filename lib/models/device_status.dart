/// État de la batterie et de la chauffe du téléphone.
class BatteryStatus {
  const BatteryStatus({
    required this.level,
    required this.tempC,
    required this.charging,
    required this.thermal,
    this.voltage = 0,
    this.health = 1,
    this.plugged = 0,
    this.technology = '',
  });

  static const BatteryStatus unknown =
      BatteryStatus(level: -1, tempC: 0, charging: false, thermal: -1);

  /// Pourcentage 0..100, ou -1 si inconnu.
  final int level;

  /// Température de la BATTERIE en °C (0 si inconnue). Ce n'est pas la
  /// température du processeur : Android ne la donne pas aux applis.
  final double tempC;

  final bool charging;

  /// Niveau thermique Android (API 29+) : 0 normal … 6 arrêt, -1 inconnu.
  final int thermal;

  /// Tension en volts (0 si inconnue).
  final double voltage;

  /// Code « santé » Android : 2 bonne, 3 surchauffe, 4 défaillante, 7 froide…
  final int health;

  /// Bits : 1 secteur, 2 USB, 4 sans fil, 0 sur batterie.
  final int plugged;

  final String technology;

  bool get hasData => level >= 0;
  bool get hasTemp => tempC > 0;
  bool get hasVoltage => voltage > 0;

  String get thermalLabel {
    switch (thermal) {
      case 0:
        return 'Normal';
      case 1:
        return 'Léger';
      case 2:
        return 'Modéré';
      case 3:
        return 'Sévère';
      case 4:
        return 'Critique';
      case 5:
        return 'Urgence';
      case 6:
        return 'Arrêt imminent';
      default:
        return 'n/d';
    }
  }

  String get healthLabel {
    switch (health) {
      case 2:
        return 'Bonne';
      case 3:
        return 'Surchauffe';
      case 4:
        return 'Défaillante';
      case 5:
        return 'Surtension';
      case 6:
        return 'Erreur';
      case 7:
        return 'Trop froide';
      default:
        return 'Inconnue';
    }
  }

  String get plugLabel {
    if ((plugged & 1) != 0) return 'Secteur';
    if ((plugged & 2) != 0) return 'USB';
    if ((plugged & 4) != 0) return 'Sans fil';
    return 'Sur batterie';
  }
}

/// Mémoire vive (en Mo).
class MemoryStatus {
  const MemoryStatus({required this.availMb, required this.totalMb});

  final int availMb;
  final int totalMb;

  int get usedMb => totalMb - availMb;

  double get usedRatio {
    if (totalMb <= 0) return 0.0;
    final double r = usedMb / totalMb;
    return r < 0.0 ? 0.0 : (r > 1.0 ? 1.0 : r);
  }
}

/// Stockage interne (en Mo).
class StorageStatus {
  const StorageStatus({required this.freeMb, required this.totalMb});

  final int freeMb;
  final int totalMb;

  int get usedMb => totalMb - freeMb;

  double get usedRatio {
    if (totalMb <= 0) return 0.0;
    final double r = usedMb / totalMb;
    return r < 0.0 ? 0.0 : (r > 1.0 ? 1.0 : r);
  }
}

/// Résultat d'un nettoyage de la RAM.
class CleanResult {
  const CleanResult({
    required this.availBeforeMb,
    required this.availAfterMb,
    required this.totalMb,
    this.processed = 0,
  });

  final int availBeforeMb;
  final int availAfterMb;
  final int totalMb;

  /// Nombre d'applis auxquelles on a demandé de libérer leur mémoire.
  final int processed;

  int get freedMb =>
      availAfterMb > availBeforeMb ? availAfterMb - availBeforeMb : 0;
}

/// État du mode « Ne pas déranger ».
class DndStatus {
  const DndStatus({required this.granted, required this.active});

  /// L'utilisateur a-t-il autorisé l'appli à piloter « Ne pas déranger » ?
  final bool granted;

  /// « Ne pas déranger » est-il actif en ce moment ?
  final bool active;
}

/// Identité du téléphone.
class DeviceInfo {
  const DeviceInfo({
    required this.model,
    required this.manufacturer,
    required this.brand,
    required this.androidVersion,
    required this.sdk,
    required this.cores,
  });

  final String model;
  final String manufacturer;
  final String brand;
  final String androidVersion;
  final int sdk;
  final int cores;

  String get title {
    final String m = manufacturer.isEmpty
        ? ''
        : manufacturer[0].toUpperCase() + manufacturer.substring(1);
    return m.isEmpty ? model : '$m $model';
  }
}

/// 1536 -> « 1.5 Go », 800 -> « 800 Mo ».
String formatMb(int mb) {
  if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} Go';
  return '$mb Mo';
}
