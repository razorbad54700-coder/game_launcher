import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/app_state.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../widgets/neon_panel.dart';
import 'boot_screen.dart';
import 'diagnostic_screen.dart';
import 'manage_games_screen.dart';

/// Réglages : son (dont le Mute), affichage, jeux, système.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (BuildContext c) => page));
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final SettingsController s = app.settings;

    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[s, app.library]),
        builder: (BuildContext context, Widget? child) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: <Widget>[
              Text('GAME LAUNCHER', style: displayStyle(size: 10, color: Neon.cyan, spacing: 4)),
              const SizedBox(height: 2),
              Text(
                'RÉGLAGES',
                style: displayStyle(size: 24, weight: FontWeight.w900, spacing: 3),
              ),

              // -------------------------------------------------- SON
              const SectionTitle('SON'),
              NeonPanel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  children: <Widget>[
                    _SwitchRow(
                      icon: s.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      title: 'Mute',
                      subtitle: 'Coupe la musique et tous les sons',
                      value: s.muted,
                      onChanged: (bool v) {
                        s.setMuted(v);
                        if (v) app.sound.stopBoot();
                      },
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.graphic_eq_rounded, color: s.muted ? Neon.textDim : Neon.cyan),
                          const SizedBox(width: 14),
                          const Text('Volume', style: TextStyle(color: Neon.text, fontSize: 15)),
                          Expanded(
                            child: Slider(
                              value: s.musicVolume,
                              onChanged: s.muted ? null : (double v) => s.setMusicVolume(v),
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${(s.musicVolume * 100).round()}%',
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: Neon.textDim, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    _SwitchRow(
                      icon: Icons.touch_app_rounded,
                      title: "Sons d'interface",
                      subtitle: 'Clics, lancement, succès, alerte',
                      value: s.uiSounds,
                      onChanged: (bool v) => s.setUiSounds(v),
                    ),
                    const Divider(height: 1),
                    _SwitchRow(
                      icon: Icons.vibration_rounded,
                      title: 'Vibrations',
                      subtitle: 'Retour haptique dans les menus',
                      value: s.haptics,
                      onChanged: (bool v) => s.setHaptics(v),
                    ),
                  ],
                ),
              ),

              // -------------------------------------------------- DÉMARRAGE
              const SectionTitle('DÉMARRAGE'),
              NeonPanel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  children: <Widget>[
                    _SwitchRow(
                      icon: Icons.movie_filter_rounded,
                      title: 'Animation de démarrage',
                      subtitle: "Séquence high-tech et musique d'ambiance",
                      value: s.bootIntro,
                      onChanged: (bool v) => s.setBootIntro(v),
                    ),
                    const Divider(height: 1),
                    _NavRow(
                      icon: Icons.play_circle_outline_rounded,
                      title: "Revoir l'animation",
                      subtitle: 'Rejoue la séquence avec la musique',
                      onTap: () => _push(context, const BootScreen(replay: true)),
                    ),
                    const Divider(height: 1),
                    _NavRow(
                      icon: Icons.music_note_rounded,
                      title: 'Écouter la musique',
                      subtitle: s.muted ? 'Désactive le Mute pour l\'entendre' : 'Joue uniquement la musique',
                      onTap: () {
                        app.sound.preview();
                      },
                    ),
                  ],
                ),
              ),

              // -------------------------------------------------- AFFICHAGE
              const SectionTitle('AFFICHAGE'),
              NeonPanel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  children: <Widget>[
                    _SwitchRow(
                      icon: Icons.grid_view_rounded,
                      title: 'Vue en grille',
                      subtitle: 'À la place du carrousel 3D',
                      value: s.gridView,
                      onChanged: (bool v) => s.setGridView(v),
                    ),
                    const Divider(height: 1),
                    _SwitchRow(
                      icon: Icons.fullscreen_rounded,
                      title: 'Mode immersif',
                      subtitle: 'Cache la barre d\'état et de navigation',
                      value: s.immersive,
                      onChanged: (bool v) => s.setImmersive(v),
                    ),
                    const Divider(height: 1),
                    _SwitchRow(
                      icon: Icons.battery_saver_rounded,
                      title: 'Mode économie',
                      subtitle: 'Fond fixe, moins d\'animations',
                      value: s.lowFx,
                      onChanged: (bool v) => s.setLowFx(v),
                    ),
                  ],
                ),
              ),

              // -------------------------------------------------- JEUX
              const SectionTitle('JEUX'),
              NeonPanel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  children: <Widget>[
                    _SwitchRow(
                      icon: Icons.apps_rounded,
                      title: 'Afficher toutes les applis',
                      subtitle: 'Utile si tes jeux ne sont pas détectés',
                      value: s.showAllApps,
                      onChanged: (bool v) => s.setShowAllApps(v),
                    ),
                    const Divider(height: 1),
                    _NavRow(
                      icon: Icons.sports_esports_rounded,
                      title: 'Mes jeux',
                      subtitle: 'Choisir ce qui apparaît dans la bibliothèque',
                      onTap: () => _push(context, const ManageGamesScreen()),
                    ),
                  ],
                ),
              ),

              // -------------------------------------------------- SYSTÈME
              const SectionTitle('SYSTÈME'),
              NeonPanel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  children: <Widget>[
                    _NavRow(
                      icon: Icons.bug_report_rounded,
                      title: 'Diagnostic',
                      subtitle: 'Tester la liaison Android et voir le journal',
                      onTap: () => _push(context, const DiagnosticScreen()),
                    ),
                    const Divider(height: 1),
                    _NavRow(
                      icon: Icons.restart_alt_rounded,
                      title: 'Réinitialiser les réglages',
                      subtitle: 'Les favoris et les stats sont conservés',
                      onTap: () => _confirmReset(context, app),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: Text(
                  'GAME LAUNCHER  ·  v2.0',
                  style: monoStyle(size: 11, color: Neon.textDim, spacing: 2),
                ),
              ),
            ],
          );
        },
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
          'Tous les réglages reviennent à leur valeur d\'origine.',
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
      await app.settings.resetAll();
      app.message.value = 'Réglages réinitialisés.';
    }
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(icon, color: value ? Neon.cyan : Neon.textDim),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(color: Neon.text, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Neon.textDim, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, color: Neon.cyan),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: const TextStyle(color: Neon.text, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Neon.textDim, fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Neon.textDim),
          ],
        ),
      ),
    );
  }
}
