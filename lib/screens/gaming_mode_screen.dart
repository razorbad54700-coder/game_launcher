import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/app_state.dart';
import '../core/settings.dart';
import '../core/status_colors.dart';
import '../core/theme.dart';
import '../models/device_status.dart';
import '../widgets/native_error_banner.dart';
import '../widgets/neon_gauge.dart';
import '../widgets/neon_launch_button.dart';
import '../widgets/neon_panel.dart';
import '../widgets/sparkline.dart';
import 'diagnostic_screen.dart';

/// Tableau de bord du Mode Gaming : jauges, nettoyage de la RAM, « Ne pas
/// déranger », profils de lancement, courbes, batterie, stockage, appareil.
class GamingModeScreen extends StatefulWidget {
  const GamingModeScreen({super.key});

  @override
  State<GamingModeScreen> createState() => _GamingModeScreenState();
}

class _GamingModeScreenState extends State<GamingModeScreen> {
  AppState? _app;
  bool _boosting = false;
  bool _tempWarned = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_app == null) {
      final AppState app = AppScope.of(context);
      _app = app;
      app.monitor.addListener(_checkTemperature);
    }
  }

  @override
  void dispose() {
    _app?.monitor.removeListener(_checkTemperature);
    super.dispose();
  }

  /// Une seule alerte (son + vibration) à chaque dépassement du seuil.
  void _checkTemperature() {
    final AppState? app = _app;
    if (app == null) return;
    final double t = app.monitor.battery.tempC;
    final int warn = app.settings.tempWarn;
    if (t <= 0) return;
    if (t >= warn && !_tempWarned) {
      _tempWarned = true;
      app.sound.warn();
      app.haptics.medium();
    } else if (t < warn - 2) {
      _tempWarned = false;
    }
  }

  // ------------------------------------------------------------ actions

  Future<void> _boost(AppState app) async {
    if (_boosting || app.gaming.cleaning) return;
    setState(() => _boosting = true);
    app.haptics.heavy();
    app.sound.launch();

    final CleanResult? r = await app.gaming.cleanRam();
    bool dndOn = false;
    if (app.gaming.dndGranted && !app.gaming.dndActive) {
      dndOn = await app.gaming.setDndManual(true);
    }
    if (!mounted) return;
    setState(() => _boosting = false);

    if (r == null) {
      app.message.value = 'Nettoyage impossible : ouvre le Diagnostic pour voir pourquoi.';
      return;
    }
    app.sound.success();
    final String freed = r.freedMb > 0
        ? '${formatMb(r.freedMb)} de RAM libérés'
        : 'mémoire déjà propre';
    app.message.value = dndOn ? 'Boost terminé : $freed, « Ne pas déranger » actif.' : 'Boost terminé : $freed.';
  }

  Future<void> _clean(AppState app) async {
    if (_boosting || app.gaming.cleaning) return;
    app.haptics.medium();
    final CleanResult? r = await app.gaming.cleanRam();
    if (!mounted) return;
    if (r == null) {
      app.message.value = 'Nettoyage impossible : ouvre le Diagnostic pour voir pourquoi.';
    } else {
      app.sound.success();
    }
  }

  Future<void> _toggleDnd(AppState app, bool value) async {
    app.haptics.select();
    final bool ok = await app.gaming.setDndManual(value);
    if (!ok && mounted) {
      app.message.value =
          "Autorisation requise : active « Game Launcher » dans la liste qui s'ouvre, puis reviens.";
      await app.gaming.openDndSettings();
    }
  }

  // ------------------------------------------------------------ construction

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);

    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[app.monitor, app.gaming, app.settings]),
        builder: (BuildContext context, Widget? child) {
          final BatteryStatus b = app.monitor.battery;
          final int warn = app.settings.tempWarn;
          final bool hot = b.hasTemp && b.tempC >= warn;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: <Widget>[
              Text('GAME LAUNCHER', style: displayStyle(size: 10, color: Neon.cyan, spacing: 4)),
              const SizedBox(height: 2),
              Text(
                'MODE GAMING',
                style: displayStyle(size: 24, weight: FontWeight.w900, spacing: 3),
              ),
              NativeErrorBanner(
                margin: const EdgeInsets.only(top: 12),
                onDiagnostic: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (BuildContext c) => const DiagnosticScreen()),
                ),
              ),
              if (app.monitor.demo) _demoNote(),
              const SizedBox(height: 18),
              _gauges(app, b, warn),
              if (hot) _hotBanner(b, warn),
              const SizedBox(height: 22),
              Center(
                child: NeonLaunchButton(
                  label: 'BOOST',
                  icon: Icons.bolt_rounded,
                  width: 260,
                  height: 66,
                  fontSize: 22,
                  busy: _boosting || app.gaming.cleaning,
                  onPressed: () => _boost(app),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Libère la RAM + active « Ne pas déranger »',
                  style: TextStyle(color: Neon.textDim, fontSize: 12),
                ),
              ),
              const SectionTitle('OPTIMISATION'),
              _optimisation(app),
              const SectionTitle('PROFIL DE LANCEMENT'),
              _profiles(app),
              const SectionTitle('TENDANCES'),
              _trends(app, b, warn),
              const SectionTitle('BATTERIE'),
              _battery(b),
              const SectionTitle('STOCKAGE'),
              _storage(app),
              const SectionTitle('APPAREIL'),
              _device(app),
              const SizedBox(height: 18),
              const Text(
                "La température affichée est celle de la batterie : Android ne donne pas "
                "celle du processeur aux applis. Le nettoyage demande à Android de libérer "
                "les applis en arrière-plan ; il ne ferme ni l'appli au premier plan ni "
                "les applis système.",
                style: TextStyle(color: Neon.textDim, fontSize: 11.5, height: 1.45),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _demoNote() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: NeonPanel(
        accent: Neon.amber,
        padding: const EdgeInsets.all(12),
        child: const Text(
          "MODE DÉMO : sur iPhone, iOS interdit de lire la RAM, la batterie ou de "
          "fermer des applis. Les valeurs ci-dessous sont simulées.",
          style: TextStyle(color: Neon.amber, fontSize: 12, height: 1.4),
        ),
      ),
    );
  }

  Widget _gauges(AppState app, BatteryStatus b, int warn) {
    final MemoryStatus? m = app.monitor.memory;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double s = clampD((box.maxWidth - 16) / 3, 70.0, 108.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            NeonGauge(
              size: s,
              value: m == null ? 0.0 : m.usedRatio,
              color: m == null ? Neon.textDim : ramColor(m.usedRatio),
              center: m == null ? '--' : '${(m.usedRatio * 100).round()}%',
              label: 'RAM',
            ),
            NeonGauge(
              size: s,
              value: b.hasData ? b.level / 100.0 : 0.0,
              color: batteryColor(b.level, b.charging),
              center: b.hasData ? '${b.level}%' : '--',
              label: b.charging ? 'EN CHARGE' : 'BATTERIE',
            ),
            NeonGauge(
              size: s,
              value: b.hasTemp ? clampD((b.tempC - 20.0) / 40.0, 0.0, 1.0) : 0.0,
              color: tempColor(b.tempC, warn),
              center: b.hasTemp ? '${b.tempC.toStringAsFixed(1)}°' : '--',
              label: 'TEMP',
            ),
          ],
        );
      },
    );
  }

  Widget _hotBanner(BatteryStatus b, int warn) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: NeonPanel(
        accent: Neon.red,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            const Icon(Icons.warning_amber_rounded, color: Neon.red, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'TEMPÉRATURE ÉLEVÉE (${b.tempC.toStringAsFixed(1)} °C, seuil $warn °C). '
                'Fais une pause, retire la coque ou baisse la luminosité.',
                style: const TextStyle(color: Neon.text, fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optimisation(AppState app) {
    final CleanResult? last = app.gaming.lastClean;
    final bool granted = app.gaming.dndGranted;
    final bool busy = app.gaming.cleaning || _boosting;

    String lastText = 'Aucun nettoyage pour le moment.';
    if (last != null) {
      lastText = last.freedMb > 0
          ? 'Dernier nettoyage : ${formatMb(last.freedMb)} libérés '
              '(${formatMb(last.availAfterMb)} disponibles sur ${formatMb(last.totalMb)}).'
          : 'Dernier nettoyage : rien à libérer, la mémoire était déjà propre.';
    }

    return NeonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.cleaning_services_rounded, color: Neon.cyan),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nettoyer la RAM',
                  style: displayStyle(size: 15, spacing: 1),
                ),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => _clean(app),
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Neon.cyan),
                      )
                    : const Text('NETTOYER'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lastText,
            style: const TextStyle(color: Neon.textDim, fontSize: 12, height: 1.4),
          ),
          const Divider(height: 28),
          Row(
            children: <Widget>[
              Icon(
                Icons.do_not_disturb_on_rounded,
                color: app.gaming.dndActive ? Neon.red : Neon.cyan,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Ne pas déranger', style: displayStyle(size: 15, spacing: 1)),
                    const SizedBox(height: 2),
                    Text(
                      !granted
                          ? 'Autorisation requise'
                          : (app.gaming.dndActive ? 'Actif : notifications bloquées' : 'Inactif'),
                      style: TextStyle(
                        color: !granted ? Neon.amber : Neon.textDim,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (granted)
                Switch(
                  value: app.gaming.dndActive,
                  onChanged: (bool v) => _toggleDnd(app, v),
                )
              else
                OutlinedButton(
                  onPressed: () => app.gaming.openDndSettings(),
                  child: const Text('AUTORISER'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profiles(AppState app) {
    final BoostProfile current = app.settings.boostProfile;
    return Column(
      children: <Widget>[
        _ProfileCard(
          icon: Icons.eco_rounded,
          title: 'ÉCO',
          text: 'Lance le jeu sans rien toucher. Idéal pour économiser la batterie.',
          selected: current == BoostProfile.eco,
          onTap: () => app.settings.setBoostProfile(BoostProfile.eco),
        ),
        const SizedBox(height: 10),
        _ProfileCard(
          icon: Icons.tune_rounded,
          title: 'ÉQUILIBRÉ',
          text: 'Libère la RAM juste avant de lancer le jeu.',
          selected: current == BoostProfile.balanced,
          onTap: () => app.settings.setBoostProfile(BoostProfile.balanced),
        ),
        const SizedBox(height: 10),
        _ProfileCard(
          icon: Icons.bolt_rounded,
          title: 'PERFORMANCE',
          text: 'Libère la RAM et active « Ne pas déranger » pendant la partie '
              '(désactivé à ton retour).',
          selected: current == BoostProfile.performance,
          onTap: () => app.settings.setBoostProfile(BoostProfile.performance),
        ),
      ],
    );
  }

  Widget _trends(AppState app, BatteryStatus b, int warn) {
    final MemoryStatus? m = app.monitor.memory;
    return NeonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _trendHeader(
            'Température batterie',
            b.hasTemp ? '${b.tempC.toStringAsFixed(1)} °C' : '--',
            tempColor(b.tempC, warn),
          ),
          Sparkline(
            values: app.monitor.tempHistory,
            color: tempColor(b.tempC, warn),
          ),
          const SizedBox(height: 16),
          _trendHeader(
            'RAM utilisée',
            m == null ? '--' : '${(m.usedRatio * 100).round()} %',
            m == null ? Neon.textDim : ramColor(m.usedRatio),
          ),
          Sparkline(
            values: app.monitor.ramHistory,
            color: m == null ? Neon.textDim : ramColor(m.usedRatio),
            minY: 0,
            maxY: 100,
          ),
          const Divider(height: 28),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  "Seuil d'alerte température",
                  style: TextStyle(color: Neon.textDim, fontSize: 13),
                ),
              ),
              Text('$warn °C', style: displayStyle(size: 14, color: Neon.cyan, spacing: 0.5)),
            ],
          ),
          Slider(
            value: warn.toDouble(),
            min: 36,
            max: 55,
            divisions: 19,
            onChanged: (double v) => app.settings.setTempWarn(v.round()),
          ),
        ],
      ),
    );
  }

  Widget _trendHeader(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: const TextStyle(color: Neon.textDim, fontSize: 13)),
          ),
          Text(value, style: displayStyle(size: 15, color: color, spacing: 0.5)),
        ],
      ),
    );
  }

  Widget _battery(BatteryStatus b) {
    return NeonPanel(
      child: Column(
        children: <Widget>[
          InfoRow('État', b.hasData ? (b.charging ? 'En charge' : 'Décharge') : '--'),
          InfoRow('Alimentation', b.hasData ? b.plugLabel : '--'),
          InfoRow('Tension', b.hasVoltage ? '${b.voltage.toStringAsFixed(2)} V' : '--'),
          InfoRow('Santé', b.hasData ? b.healthLabel : '--'),
          InfoRow('Technologie', b.technology.isEmpty ? '--' : b.technology),
          InfoRow('Statut thermique', b.thermalLabel),
        ],
      ),
    );
  }

  Widget _storage(AppState app) {
    final StorageStatus? s = app.monitor.storage;
    if (s == null || s.totalMb <= 0) {
      return const NeonPanel(
        child: Text('Information indisponible.', style: TextStyle(color: Neon.textDim)),
      );
    }
    final Color c = storageColor(s.usedRatio);
    return NeonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Bar(value: s.usedRatio, color: c),
          const SizedBox(height: 10),
          InfoRow('Utilisé', formatMb(s.usedMb), valueColor: c),
          InfoRow('Libre', formatMb(s.freeMb)),
          InfoRow('Total', formatMb(s.totalMb)),
        ],
      ),
    );
  }

  Widget _device(AppState app) {
    final DeviceInfo? d = app.monitor.device;
    final MemoryStatus? m = app.monitor.memory;
    if (d == null) {
      return const NeonPanel(
        child: Text('Information indisponible.', style: TextStyle(color: Neon.textDim)),
      );
    }
    return NeonPanel(
      child: Column(
        children: <Widget>[
          InfoRow('Modèle', d.title),
          InfoRow('Android', d.sdk > 0 ? '${d.androidVersion} (API ${d.sdk})' : d.androidVersion),
          InfoRow('Cœurs du processeur', '${d.cores}'),
          InfoRow('RAM totale', m == null ? '--' : formatMb(m.totalMb)),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: Neon.fade(color, 0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: clampD(value, 0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
            boxShadow: Neon.glow(color, strength: 0.25),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color c = selected ? Neon.red : Neon.textDim;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? Neon.fade(Neon.red, 0.10) : Neon.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Neon.red : Neon.fade(Neon.cyan, 0.2),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected ? Neon.glow(Neon.red, strength: 0.3) : null,
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: c, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: displayStyle(size: 14, color: selected ? Neon.text : Neon.textDim, spacing: 2),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: const TextStyle(color: Neon.textDim, fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded, color: Neon.red, size: 22),
          ],
        ),
      ),
    );
  }
}
