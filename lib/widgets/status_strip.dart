import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/status_colors.dart';
import '../core/theme.dart';
import '../models/device_status.dart';

/// Bandeau d'état de l'accueil : batterie, température, RAM. Un toucher ouvre
/// le Mode Gaming.
class StatusStrip extends StatelessWidget {
  const StatusStrip({super.key, required this.app, this.onTap});

  final AppState app;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[app.monitor, app.settings]),
      builder: (BuildContext context, Widget? child) {
        final BatteryStatus b = app.monitor.battery;
        final MemoryStatus? m = app.monitor.memory;
        final int warn = app.settings.tempWarn;

        final String batt = b.hasData ? '${b.level}%' : '--';
        final String temp = b.hasTemp ? '${b.tempC.toStringAsFixed(1)}°' : '--';
        final String ram = m == null ? '--' : '${(m.usedRatio * 100).round()}%';

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Neon.fade(Neon.panel, 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Neon.fade(Neon.cyan, 0.22)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _Chip(
                  icon: b.charging ? Icons.battery_charging_full_rounded : Icons.battery_full_rounded,
                  label: 'BATT',
                  value: batt,
                  color: batteryColor(b.level, b.charging),
                ),
                _Chip(
                  icon: Icons.thermostat_rounded,
                  label: 'TEMP',
                  value: temp,
                  color: tempColor(b.tempC, warn),
                ),
                _Chip(
                  icon: Icons.memory_rounded,
                  label: 'RAM',
                  value: ram,
                  color: m == null ? Neon.textDim : ramColor(m.usedRatio),
                ),
                if (app.monitor.demo)
                  Text('DÉMO', style: displayStyle(size: 10, color: Neon.amber, spacing: 2)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                color: Neon.textDim,
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              style: displayStyle(size: 14, color: color, spacing: 0.5),
            ),
          ],
        ),
      ],
    );
  }
}
