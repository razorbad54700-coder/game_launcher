import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_log.dart';
import '../core/app_scope.dart';
import '../core/app_state.dart';
import '../core/native_bridge.dart';
import '../core/theme.dart';
import '../models/device_status.dart';
import '../models/game.dart';
import '../widgets/neon_panel.dart';

class _TestRow {
  const _TestRow(this.name, this.ok, this.detail);

  final String name;
  final bool ok;
  final String detail;
}

/// Diagnostic : teste chaque fonction du code Android, affiche le résultat et
/// le journal d'erreurs, et permet de copier un rapport complet.
class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  List<_TestRow> _results = const <_TestRow>[];
  bool _running = false;
  bool _ranOnce = false;

  Future<void> _runTests() async {
    if (_running) return;
    setState(() {
      _running = true;
      _results = const <_TestRow>[];
    });
    final List<_TestRow> out = <_TestRow>[];

    Future<void> step(String name, Future<String?> Function() run) async {
      try {
        final String? detail = await run();
        out.add(_TestRow(name, detail != null, detail ?? 'aucune réponse'));
      } catch (e) {
        out.add(_TestRow(name, false, '$e'));
      }
      if (mounted) setState(() => _results = List<_TestRow>.of(out));
    }

    await step('ping', () async {
      final String? v = await NativeBridge.ping();
      return v == null ? null : 'version du code Android : $v';
    });
    await step('getGames', () async {
      final List<Game>? g = await NativeBridge.getGames(includeAll: true);
      if (g == null) return null;
      final int games = g.where((Game x) => x.isGame).length;
      return '${g.length} applis lançables, dont $games jeux';
    });
    await step('getBattery', () async {
      final BatteryStatus? b = await NativeBridge.getBattery();
      if (b == null) return null;
      return '${b.level} %, ${b.tempC.toStringAsFixed(1)} °C, thermique ${b.thermalLabel}';
    });
    await step('getMemory', () async {
      final MemoryStatus? m = await NativeBridge.getMemory();
      if (m == null) return null;
      return '${formatMb(m.availMb)} libres sur ${formatMb(m.totalMb)}';
    });
    await step('getStorage', () async {
      final StorageStatus? s = await NativeBridge.getStorage();
      if (s == null) return null;
      return '${formatMb(s.freeMb)} libres sur ${formatMb(s.totalMb)}';
    });
    await step('getDeviceInfo', () async {
      final DeviceInfo? d = await NativeBridge.getDeviceInfo();
      if (d == null) return null;
      return '${d.title}, Android ${d.androidVersion} (API ${d.sdk})';
    });
    await step('dndStatus', () async {
      final DndStatus? s = await NativeBridge.dndStatus();
      if (s == null) return null;
      return s.granted
          ? 'autorisé, ${s.active ? 'actif' : 'inactif'}'
          : "non autorisé (à activer dans l'onglet Gaming)";
    });

    if (!mounted) return;
    setState(() {
      _running = false;
      _ranOnce = true;
    });
  }

  String _report(AppState app) {
    final StringBuffer b = StringBuffer()
      ..writeln('GAME LAUNCHER v2.0 : rapport de diagnostic')
      ..writeln('Plateforme : ${NativeBridge.supported ? 'Android' : 'démo (non Android)'}')
      ..writeln('Version du code Android : ${NativeBridge.bridgeVersion ?? 'inconnue'}')
      ..writeln('Erreur de liaison : ${NativeBridge.bridgeError.value ?? 'aucune'}')
      ..writeln('Applis scannées : ${app.allApps.length}');
    if (_results.isNotEmpty) {
      b.writeln('--- Tests ---');
      for (final _TestRow r in _results) {
        b.writeln('${r.ok ? 'OK    ' : 'ECHEC '} ${r.name} : ${r.detail}');
      }
    }
    b.writeln('--- Journal ---');
    if (AppLog.entries.isEmpty) {
      b.writeln('(vide)');
    } else {
      for (final String e in AppLog.entries) {
        b.writeln(e);
      }
    }
    return b.toString();
  }

  Future<void> _copy(AppState app) async {
    await Clipboard.setData(ClipboardData(text: _report(app)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rapport copié dans le presse-papiers.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);

    return Scaffold(
      backgroundColor: Neon.bg,
      appBar: AppBar(
        backgroundColor: Neon.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Neon.cyan),
        title: Text('DIAGNOSTIC', style: displayStyle(size: 16, spacing: 3)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: <Widget>[
          const SectionTitle('LIAISON ANDROID'),
          ValueListenableBuilder<String?>(
            valueListenable: NativeBridge.bridgeError,
            builder: (BuildContext context, String? error, Widget? child) {
              final bool supported = NativeBridge.supported;
              final String state = !supported
                  ? 'Mode démo (pas Android)'
                  : (error != null
                      ? 'ÉCHEC'
                      : (NativeBridge.bridgeVersion != null ? 'Connectée' : 'Pas encore testée'));
              final Color c = !supported
                  ? Neon.amber
                  : (error != null
                      ? Neon.red
                      : (NativeBridge.bridgeVersion != null ? Neon.green : Neon.amber));
              return NeonPanel(
                accent: c,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    InfoRow('État', state, valueColor: c),
                    InfoRow('Version du code Android', NativeBridge.bridgeVersion ?? '--'),
                    InfoRow('Applis scannées', '${app.allApps.length}'),
                    if (error != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        error,
                        style: const TextStyle(color: Neon.text, fontSize: 12.5, height: 1.4),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          if (!NativeBridge.supported)
            const NeonPanel(
              accent: Neon.amber,
              child: Text(
                "Sur iPhone, iOS n'autorise pas ces fonctions : l'appli tourne en mode démo "
                "avec des jeux et des mesures simulés.",
                style: TextStyle(color: Neon.amber, fontSize: 12.5, height: 1.4),
              ),
            )
          else
            Center(
              child: OutlinedButton.icon(
                onPressed: _running ? null : _runTests,
                icon: _running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Neon.cyan),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(_running ? 'TEST EN COURS…' : 'TESTER TOUTES LES FONCTIONS'),
              ),
            ),
          if (_results.isNotEmpty) ...<Widget>[
            const SectionTitle('RÉSULTATS'),
            NeonPanel(
              child: Column(
                children: <Widget>[
                  for (final _TestRow r in _results) _ResultRow(row: r),
                ],
              ),
            ),
          ],
          if (_ranOnce &&
              _results.isNotEmpty &&
              _results.every((_TestRow r) => !r.ok)) ...<Widget>[
            const SizedBox(height: 12),
            const NeonPanel(
              accent: Neon.red,
              child: Text(
                "Aucune fonction ne répond : le code Android n'est pas dans l'appli installée. "
                "Arrête l'appli, puis relance « flutter run » (pas un simple hot reload). "
                "Si ça persiste, copie le rapport ci-dessous.",
                style: TextStyle(color: Neon.text, fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
          SectionTitle(
            'JOURNAL',
            trailing: GestureDetector(
              onTap: () => setState(AppLog.entries.clear),
              child: const Text(
                'VIDER',
                style: TextStyle(color: Neon.textDim, fontSize: 11, letterSpacing: 1.5),
              ),
            ),
          ),
          NeonPanel(
            child: AppLog.entries.isEmpty
                ? const Text(
                    'Aucune erreur enregistrée.',
                    style: TextStyle(color: Neon.textDim, fontSize: 13),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final String e in AppLog.entries.reversed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            e,
                            style: monoStyle(size: 11, color: Neon.text),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _copy(app),
              icon: const Icon(Icons.content_copy_rounded, size: 18),
              label: const Text('COPIER LE RAPPORT'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.row});

  final _TestRow row;

  @override
  Widget build(BuildContext context) {
    final Color c = row.ok ? Neon.green : Neon.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(row.ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: c, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(row.name, style: monoStyle(size: 12.5, color: Neon.text, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  row.detail,
                  style: const TextStyle(color: Neon.textDim, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
