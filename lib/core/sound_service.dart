import 'package:audioplayers/audioplayers.dart';

import 'app_log.dart';
import 'settings.dart';

/// Musique d'ambiance de démarrage et petits sons d'interface.
///
/// Toutes les méthodes sont « sûres » : si le son échoue (pas de haut-parleur,
/// fichier absent…), on note l'erreur dans le journal et l'appli continue.
class SoundService {
  SoundService(this._settings);

  final SettingsController _settings;

  AudioPlayer? _music;
  AudioPlayer? _ui;
  bool _musicPlaying = false;

  /// Réglage commun : on se mélange aux autres sons (la musique de
  /// l'utilisateur n'est pas coupée par le démarrage de l'appli).
  AudioContext _context() {
    return AudioContextConfig(
      focus: AudioContextConfigFocus.mixWithOthers,
    ).build();
  }

  Future<AudioPlayer?> _ensureMusic() async {
    if (_music != null) return _music;
    try {
      final AudioPlayer p = AudioPlayer();
      await p.setAudioContext(_context());
      _music = p;
    } catch (e) {
      AppLog.add('Son (musique) indisponible : $e');
    }
    return _music;
  }

  Future<AudioPlayer?> _ensureUi() async {
    if (_ui != null) return _ui;
    try {
      final AudioPlayer p = AudioPlayer();
      await p.setAudioContext(_context());
      _ui = p;
    } catch (e) {
      AppLog.add('Son (interface) indisponible : $e');
    }
    return _ui;
  }

  /// Musique d'ambiance du démarrage (environ 10 s).
  Future<void> playBoot() async {
    if (_settings.muted) return;
    try {
      final AudioPlayer? p = await _ensureMusic();
      if (p == null) return;
      await p.stop();
      await p.play(
        AssetSource('audio/boot_music.wav'),
        volume: _settings.musicVolume,
      );
      _musicPlaying = true;
    } catch (e) {
      AppLog.add('Lecture de la musique impossible : $e');
    }
  }

  /// Coupe la musique de démarrage si elle joue encore.
  Future<void> stopBoot() async {
    if (!_musicPlaying) return;
    _musicPlaying = false;
    try {
      await _music?.stop();
    } catch (e) {
      AppLog.add('Arrêt de la musique impossible : $e');
    }
  }

  Future<void> _playUi(String asset, double gain) async {
    if (_settings.muted || !_settings.uiSounds) return;
    try {
      final AudioPlayer? p = await _ensureUi();
      if (p == null) return;
      await p.stop();
      double v = _settings.musicVolume * gain;
      if (v > 1.0) v = 1.0;
      await p.play(AssetSource('audio/$asset'), volume: v);
    } catch (e) {
      AppLog.add('Son « $asset » impossible : $e');
    }
  }

  Future<void> tick() => _playUi('tick.wav', 0.9);
  Future<void> launch() => _playUi('launch.wav', 1.0);
  Future<void> success() => _playUi('success.wav', 1.0);
  Future<void> warn() => _playUi('warn.wav', 1.0);

  /// Joue la musique de démarrage même si les sons d'interface sont coupés
  /// (bouton « Écouter » des réglages). Respecte quand même le mute.
  Future<void> preview() => playBoot();

  Future<void> dispose() async {
    try {
      await _music?.dispose();
      await _ui?.dispose();
    } catch (_) {}
    _music = null;
    _ui = null;
  }
}
