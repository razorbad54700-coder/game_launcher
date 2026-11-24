import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/app_state.dart';
import '../core/native_bridge.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import 'main_shell.dart';

/// Durée totale de la séquence de démarrage (en secondes). Elle est calée sur
/// la musique : montée vers 5,6 s, sommet à 7 s, retombée jusqu'à 10 s.
const double _total = 9.5;

/// Avancement 0.0 → 1.0 de l'instant [t] entre [a] et [b] (en secondes).
double _seg(double t, double a, double b) {
  if (b <= a) return t >= b ? 1.0 : 0.0;
  return clampD((t - a) / (b - a), 0.0, 1.0);
}

/// Une ligne du « journal de démarrage ».
class _LogLine {
  const _LogLine(this.at, this.label, this.result);

  final double at;
  final String label;
  final String Function(AppState app) result;
}

String _bridgeResult(AppState a) {
  if (a.demo) return 'DÉMO';
  if (NativeBridge.bridgeVersion != null) return 'OK';
  if (NativeBridge.bridgeError.value != null) return 'ÉCHEC';
  return '...';
}

String _sensorsResult(AppState a) {
  if (a.demo) return 'DÉMO';
  if (a.monitor.battery.hasData) return 'OK';
  if (NativeBridge.bridgeError.value != null) return 'ÉCHEC';
  return '...';
}

String _libraryResult(AppState a) {
  if (!a.scanned) return '...';
  if (a.scanFailed) return 'ÉCHEC';
  final int n = a.gamesCount;
  return n <= 1 ? '$n JEU' : '$n JEUX';
}

String _profileResult(AppState a) {
  switch (a.settings.boostProfile) {
    case BoostProfile.eco:
      return 'ÉCO';
    case BoostProfile.balanced:
      return 'ÉQUILIBRÉ';
    case BoostProfile.performance:
      return 'MAX';
  }
}

final List<_LogLine> _lines = <_LogLine>[
  _LogLine(0.8, 'NOYAU GRAPHIQUE', (AppState a) => 'OK'),
  _LogLine(1.6, 'MOTEUR AUDIO', (AppState a) => a.settings.muted ? 'MUET' : 'OK'),
  _LogLine(2.4, 'LIAISON ANDROID', _bridgeResult),
  _LogLine(3.2, 'CAPTEURS BATTERIE', _sensorsResult),
  _LogLine(4.0, 'BIBLIOTHÈQUE', _libraryResult),
  _LogLine(4.8, 'PROFIL DE LANCEMENT', _profileResult),
  _LogLine(5.6, 'MODE GAMING', (AppState a) => 'PRÊT'),
];

/// Petites étoiles qui dérivent vers le haut : x, y, vitesse, taille.
final List<List<double>> _stars = () {
  final math.Random r = math.Random(11);
  return List<List<double>>.generate(
    46,
    (int i) => <double>[
      r.nextDouble(),
      r.nextDouble(),
      0.02 + r.nextDouble() * 0.05,
      0.6 + r.nextDouble() * 1.4,
    ],
  );
}();

/// Séquence de démarrage : anneaux HUD, journal système, barre de progression,
/// flash puis apparition du titre, le tout sur une musique d'ambiance douce.
/// Un toucher passe l'animation.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key, this.replay = false});

  /// Vrai quand on rejoue l'animation depuis les réglages : à la fin on
  /// revient simplement à l'écran précédent.
  final bool replay;

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_total * 1000).round()),
  );

  AppState? _app;
  bool _begun = false;
  bool _done = false;
  bool _flashed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_begun) return;
    _begun = true;
    _app = AppScope.of(context);
    _controller.addListener(_onTick);
    _controller.addStatusListener((AnimationStatus s) {
      if (s == AnimationStatus.completed) _finish(skipped: false);
    });
    // On démarre après la première image pour que le son et l'animation
    // partent ensemble.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      _app?.sound.playBoot();
      _controller.forward();
    });
  }

  void _onTick() {
    if (_flashed) return;
    if (_controller.value * _total >= 7.0) {
      _flashed = true;
      _app?.haptics.heavy();
    }
  }

  void _finish({required bool skipped}) {
    if (_done || !mounted) return;
    _done = true;
    if (skipped) _app?.sound.stopBoot();
    _controller.stop();
    if (widget.replay) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (BuildContext c, Animation<double> a, Animation<double> s) =>
            const MainShell(),
        transitionsBuilder:
            (BuildContext c, Animation<double> a, Animation<double> s, Widget child) =>
                FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  void dispose() {
    // Sortie anticipée (bouton retour) : on coupe la musique.
    if (!_done) _app?.sound.stopBoot();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);

    return Scaffold(
      backgroundColor: Neon.bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _finish(skipped: true),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            final double t = _controller.value * _total;
            final double fadeOut = 1.0 - _seg(t, 8.7, 9.5);
            final double flash = t < 7.0 ? 0.0 : 1.0 - _seg(t, 7.0, 7.6);
            final double progress =
                Curves.easeInOutSine.transform(_seg(t, 0.4, 7.0));

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (!app.settings.lowFx)
                  RepaintBoundary(
                    child: CustomPaint(painter: _StarsPainter(t)),
                  ),
                Opacity(
                  opacity: fadeOut,
                  child: SafeArea(
                    child: Column(
                      children: <Widget>[
                        _header(t),
                        Expanded(child: _hud(t, progress)),
                        _log(t, app),
                        _progressBar(progress),
                        _skipHint(t),
                      ],
                    ),
                  ),
                ),
                if (flash > 0)
                  IgnorePointer(
                    child: ColoredBox(
                      color: Neon.fade(const Color(0xFFD8FBFF), flash * 0.85),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------ morceaux

  Widget _header(double t) {
    final double a = _seg(t, 0.0, 0.8);
    return Opacity(
      opacity: a,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('SYS // BOOT SEQUENCE', style: monoStyle(size: 11, color: Neon.cyan)),
            Text('v2.0', style: monoStyle(size: 11, color: Neon.textDim)),
          ],
        ),
      ),
    );
  }

  Widget _hud(double t, double progress) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double side = math.min(box.maxWidth, box.maxHeight) * 0.96;
        final double reveal = Curves.easeOutCubic.transform(_seg(t, 7.0, 8.2));
        final double sub = _seg(t, 7.6, 8.4);
        final double spacing = 26.0 - 20.0 * reveal;

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CustomPaint(
                  size: Size.square(side),
                  painter: _HudPainter(t: t, progress: progress),
                ),
                if (reveal > 0)
                  SizedBox(
                    width: side * 0.62,
                    height: side * 0.40,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Opacity(
                        opacity: reveal,
                        child: Transform.scale(
                          scale: 1.15 - 0.15 * reveal,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'GAME',
                                style: displayStyle(
                                  size: 40,
                                  weight: FontWeight.w900,
                                  spacing: spacing,
                                ),
                              ),
                              Text(
                                'LAUNCHER',
                                style: displayStyle(
                                  size: 24,
                                  color: Neon.cyan,
                                  weight: FontWeight.w800,
                                  spacing: spacing,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Opacity(
                                opacity: sub,
                                child: Text(
                                  'SYSTÈME DE LANCEMENT',
                                  style: displayStyle(
                                    size: 10,
                                    color: Neon.textDim,
                                    weight: FontWeight.w600,
                                    spacing: 3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _log(double t, AppState app) {
    final List<Widget> rows = <Widget>[];
    for (final _LogLine l in _lines) {
      if (t < l.at) break;
      rows.add(_logRow(l, t, app));
    }
    return Container(
      height: 7 * 18.0 + 4,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _logRow(_LogLine l, double t, AppState app) {
    final double k = _seg(t, l.at, l.at + 0.5);
    final String head = '> ${l.label} ';
    final int shown = clampI((head.length * k).floor(), 0, head.length);
    final bool done = k >= 1.0;
    final String result = l.result(app);
    final int dotCount = math.max(2, 36 - head.length - result.length - 1);
    final String dots = '.' * dotCount;

    Color resultColor = Neon.green;
    if (result == 'ÉCHEC') resultColor = Neon.red;
    if (result == '...' || result == 'MUET' || result == 'DÉMO') resultColor = Neon.amber;

    return SizedBox(
      height: 18,
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: head.substring(0, shown),
              style: monoStyle(size: 11.5, color: Neon.fade(Neon.cyan, 0.9)),
            ),
            if (done)
              TextSpan(
                text: '$dots ',
                style: monoStyle(size: 11.5, color: Neon.textDim),
              ),
            if (done)
              TextSpan(
                text: result,
                style: monoStyle(
                  size: 11.5,
                  color: resultColor,
                  weight: FontWeight.w800,
                ),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.clip,
      ),
    );
  }

  Widget _progressBar(double progress) {
    final int pct = (progress * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('CHARGEMENT', style: monoStyle(size: 10.5, color: Neon.textDim)),
              Text('$pct %', style: monoStyle(size: 10.5, color: Neon.cyan)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Neon.fade(Neon.cyan, 0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: clampD(progress, 0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: const LinearGradient(
                    colors: <Color>[Neon.cyan, Neon.red],
                  ),
                  boxShadow: Neon.glow(Neon.cyan, strength: 0.35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skipHint(double t) {
    final double a = _seg(t, 1.0, 2.0) * (0.35 + 0.25 * math.sin(t * 3.0));
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 2),
      child: Opacity(
        opacity: clampD(a, 0.0, 1.0),
        child: Text(
          'TOUCHER POUR PASSER',
          style: monoStyle(size: 10, color: Neon.textDim, spacing: 2),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dessins
// ---------------------------------------------------------------------------

class _StarsPainter extends CustomPainter {
  _StarsPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final double appear = _seg(t, 0.0, 1.5);
    if (appear <= 0) return;
    final Paint p = Paint();
    for (int i = 0; i < _stars.length; i++) {
      final List<double> s = _stars[i];
      final double x = s[0] * size.width;
      final double y = ((s[1] - t * s[2]) % 1.0) * size.height;
      final double twinkle = 0.5 + 0.5 * math.sin(t * 2.0 + i);
      p.color = Neon.fade(Neon.cyan, (0.10 + 0.30 * twinkle) * appear);
      canvas.drawCircle(Offset(x, y), s[3], p);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter oldDelegate) => oldDelegate.t != t;
}

class _HudPainter extends CustomPainter {
  _HudPainter({required this.t, required this.progress});

  final double t;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double rad = size.shortestSide / 2;

    final double appear = Curves.easeOutCubic.transform(_seg(t, 0.0, 1.4));
    if (appear <= 0) return;

    final double riser = _seg(t, 5.6, 7.0);
    final double spin = t * 0.35 + riser * riser * 2.2;
    final double r0 = rad * (0.82 + 0.18 * appear);

    // Halo central qui grandit pendant la montée de la musique.
    if (riser > 0) {
      final double gr = r0 * (0.35 + 0.55 * riser);
      canvas.drawCircle(
        c,
        gr,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            gr,
            <Color>[
              Neon.fade(Neon.cyan, 0.30 * riser * appear),
              Neon.fade(Neon.cyan, 0.0),
            ],
            <double>[0.0, 1.0],
          ),
      );
    }

    final Paint thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Neon.fade(Neon.cyan, 0.28 * appear);

    // Anneau extérieur et sa graduation.
    canvas.drawCircle(c, r0 * 0.98, thin);
    final Paint tick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 72; i++) {
      final double a = i * 2 * math.pi / 72 + spin * 0.4;
      final bool major = i % 6 == 0;
      final double r1 = r0 * 0.98;
      final double r2 = r0 * (major ? 0.90 : 0.945);
      tick
        ..strokeWidth = major ? 2.0 : 1.0
        ..color = Neon.fade(Neon.cyan, (major ? 0.65 : 0.30) * appear);
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * r1, c.dy + math.sin(a) * r1),
        Offset(c.dx + math.cos(a) * r2, c.dy + math.sin(a) * r2),
        tick,
      );
    }

    // Trois arcs épais qui tournent en sens inverse.
    final Rect arcRect = Rect.fromCircle(center: c, radius: r0 * 0.80);
    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Neon.fade(Neon.cyan, 0.75 * appear);
    for (int k = 0; k < 3; k++) {
      canvas.drawArc(
        arcRect,
        k * 2 * math.pi / 3 - spin * 0.9,
        2 * math.pi / 3 * 0.6,
        false,
        arc,
      );
    }

    // Balayage radar.
    final Rect radar = Rect.fromCircle(center: c, radius: r0 * 0.78);
    canvas.drawCircle(
      c,
      r0 * 0.78,
      Paint()
        ..shader = SweepGradient(
          colors: <Color>[
            Neon.fade(Neon.cyan, 0.0),
            Neon.fade(Neon.cyan, 0.0),
            Neon.fade(Neon.cyan, 0.34 * appear),
          ],
          stops: const <double>[0.0, 0.7, 1.0],
          transform: GradientRotation(spin * 2.0),
        ).createShader(radar),
    );

    // Anneau de progression rouge.
    final Rect progRect = Rect.fromCircle(center: c, radius: r0 * 0.64);
    canvas.drawCircle(
      c,
      r0 * 0.64,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Neon.fade(Neon.red, 0.14 * appear),
    );
    if (progress > 0) {
      final double sweep = 2 * math.pi * progress;
      canvas.drawArc(
        progRect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..color = Neon.fade(Neon.red, 0.45 * appear)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawArc(
        progRect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = Neon.fade(Neon.red, appear),
      );
    }

    // Petit anneau intérieur avec huit points qui tournent.
    canvas.drawCircle(c, r0 * 0.50, thin);
    final Paint dot = Paint()..color = Neon.fade(Neon.cyan, 0.9 * appear);
    for (int i = 0; i < 8; i++) {
      final double a = i * 2 * math.pi / 8 + spin * 1.5;
      canvas.drawCircle(
        Offset(c.dx + math.cos(a) * r0 * 0.50, c.dy + math.sin(a) * r0 * 0.50),
        2.6,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_HudPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.progress != progress;
}
