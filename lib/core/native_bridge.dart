import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/device_status.dart';
import '../models/game.dart';
import 'app_log.dart';

/// Liaison avec le code Android (plugin local `game_launcher_native`).
///
/// Règle d'or : AUCUNE méthode ne lève d'exception. En cas de problème, elle
/// renvoie null et enregistre la raison dans [bridgeError], que l'interface
/// affiche dans un bandeau et dans l'écran Diagnostic.
class NativeBridge {
  NativeBridge._();

  static const MethodChannel _channel = MethodChannel('gamelauncher/native');

  /// Dernière erreur de liaison (null = tout va bien).
  static final ValueNotifier<String?> bridgeError = ValueNotifier<String?>(null);

  /// Version du code Android, renvoyée par [ping] (null tant que non lue).
  static String? bridgeVersion;

  /// Vrai sur Android. Sur iOS (et ailleurs) l'appli tourne en mode démo.
  static bool get supported => defaultTargetPlatform == TargetPlatform.android;

  // ------------------------------------------------------------ appel brut

  static Future<Object?> _invoke(String method, [Object? args]) async {
    if (!supported) return null;
    try {
      final Object? out = await _channel.invokeMethod<Object?>(method, args);
      if (bridgeError.value != null) bridgeError.value = null;
      return out;
    } on MissingPluginException catch (e) {
      final String msg =
          "Le code Android n'est pas branché (MissingPluginException sur « $method »). "
          'Arrête complètement l\'appli puis relance « flutter run ».';
      AppLog.add('$msg ${e.message ?? ''}');
      bridgeError.value = msg;
      return null;
    } on PlatformException catch (e) {
      AppLog.add('Erreur Android sur « $method » : ${e.code} ${e.message ?? ''}');
      return null;
    } catch (e) {
      AppLog.add('Erreur sur « $method » : $e');
      return null;
    }
  }

  // ------------------------------------------------------------ conversions

  static int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

  static double _double(Object? v, [double fallback = 0.0]) =>
      v is num ? v.toDouble() : fallback;

  static bool _bool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;

  static String _string(Object? v, [String fallback = '']) =>
      v is String ? v : fallback;

  static Map<String, Object?>? _map(Object? v) {
    if (v is! Map) return null;
    final Map<String, Object?> out = <String, Object?>{};
    v.forEach((Object? key, Object? value) {
      out[key.toString()] = value;
    });
    return out;
  }

  // ------------------------------------------------------------ diagnostic

  /// Renvoie la version du code Android, ou null si la liaison ne répond pas.
  static Future<String?> ping() async {
    final Object? out = await _invoke('ping');
    if (out is String) {
      bridgeVersion = out;
      return out;
    }
    return null;
  }

  // ------------------------------------------------------------ applis

  /// Liste des applis lançables. Renvoie null en cas d'échec (pour ne pas
  /// confondre « aucune appli » et « liaison cassée »).
  static Future<List<Game>?> getGames({bool includeAll = true}) async {
    final Object? out =
        await _invoke('getGames', <String, Object?>{'includeAll': includeAll});
    if (out is! List) return null;
    final List<Game> games = <Game>[];
    for (final Object? item in out) {
      final Map<String, Object?>? m = _map(item);
      if (m == null) continue;
      final String pkg = _string(m['package']);
      if (pkg.isEmpty) continue;
      final Object? rawIcon = m['icon'];
      Uint8List? icon;
      if (rawIcon is Uint8List) {
        icon = rawIcon;
      } else if (rawIcon is List) {
        icon = Uint8List.fromList(rawIcon.whereType<int>().toList());
      }
      games.add(Game(
        name: _string(m['name'], pkg),
        packageName: pkg,
        icon: (icon == null || icon.isEmpty) ? null : icon,
        isGame: _bool(m['isGame'], true),
      ));
    }
    return games;
  }

  static Future<bool> launchGame(String packageName) async {
    final Object? out =
        await _invoke('launchGame', <String, Object?>{'package': packageName});
    return _bool(out);
  }

  static Future<bool> openAppInfo(String packageName) async {
    final Object? out =
        await _invoke('openAppInfo', <String, Object?>{'package': packageName});
    return _bool(out);
  }

  // ------------------------------------------------------------ système

  static Future<BatteryStatus?> getBattery() async {
    final Map<String, Object?>? m = _map(await _invoke('getBattery'));
    if (m == null) return null;
    return BatteryStatus(
      level: _int(m['level'], -1),
      tempC: _double(m['tempC']),
      charging: _bool(m['charging']),
      thermal: _int(m['thermal'], -1),
      voltage: _double(m['voltage']),
      health: _int(m['health'], 1),
      plugged: _int(m['plugged']),
      technology: _string(m['technology']),
    );
  }

  static Future<MemoryStatus?> getMemory() async {
    final Map<String, Object?>? m = _map(await _invoke('getMemory'));
    if (m == null) return null;
    return MemoryStatus(availMb: _int(m['availMb']), totalMb: _int(m['totalMb']));
  }

  static Future<StorageStatus?> getStorage() async {
    final Map<String, Object?>? m = _map(await _invoke('getStorage'));
    if (m == null) return null;
    return StorageStatus(freeMb: _int(m['freeMb']), totalMb: _int(m['totalMb']));
  }

  static Future<DeviceInfo?> getDeviceInfo() async {
    final Map<String, Object?>? m = _map(await _invoke('getDeviceInfo'));
    if (m == null) return null;
    return DeviceInfo(
      model: _string(m['model'], 'Android'),
      manufacturer: _string(m['manufacturer']),
      brand: _string(m['brand']),
      androidVersion: _string(m['androidVersion'], '?'),
      sdk: _int(m['sdk']),
      cores: _int(m['cores']),
    );
  }

  // ------------------------------------------------------------ optimisation

  /// Demande à Android de libérer la mémoire des applis en arrière-plan,
  /// sauf [keepPackage] (le jeu qu'on s'apprête à lancer).
  static Future<CleanResult?> cleanRam({String? keepPackage}) async {
    final Map<String, Object?>? m =
        _map(await _invoke('cleanRam', <String, Object?>{'keep': keepPackage}));
    if (m == null) return null;
    return CleanResult(
      availBeforeMb: _int(m['availBeforeMb']),
      availAfterMb: _int(m['availAfterMb']),
      totalMb: _int(m['totalMb']),
      processed: _int(m['processed']),
    );
  }

  // ------------------------------------------------------------ Ne pas déranger

  static Future<DndStatus?> dndStatus() async {
    final Map<String, Object?>? m = _map(await _invoke('dndStatus'));
    if (m == null) return null;
    return DndStatus(granted: _bool(m['granted']), active: _bool(m['active']));
  }

  static Future<void> openDndSettings() async {
    await _invoke('openDndSettings');
  }

  static Future<bool> setDnd(bool enabled) async {
    final Object? out = await _invoke('setDnd', <String, Object?>{'enabled': enabled});
    return _bool(out);
  }
}
