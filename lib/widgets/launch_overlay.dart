import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/game.dart';

/// Écran plein cadre affiché pendant l'optimisation puis le lancement.
class LaunchOverlay extends StatefulWidget {
  const LaunchOverlay({super.key, required this.game, required this.step});

  final Game game;

  /// Texte de l'étape en cours (« Libération de la mémoire… »).
  final String step;

  @override
  State<LaunchOverlay> createState() => _LaunchOverlayState();
}

class _LaunchOverlayState extends State<LaunchOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Neon.fade(Neon.bg, 0.94),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  AnimatedBuilder(
                    animation: _spin,
                    builder: (BuildContext context, Widget? child) {
                      return CustomPaint(
                        size: const Size.square(150),
                        painter: _SpinPainter(_spin.value),
                      );
                    },
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      width: 78,
                      height: 78,
                      child: _icon(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                widget.game.name.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: displayStyle(size: 20, spacing: 3),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                widget.step,
                textAlign: TextAlign.center,
                style: monoStyle(size: 13, color: Neon.cyan),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _icon() {
    final icon = widget.game.icon;
    if (icon != null) {
      return Image.memory(icon, fit: BoxFit.cover, gaplessPlayback: true);
    }
    final String letter = widget.game.name.isEmpty
        ? '?'
        : String.fromCharCode(widget.game.name.runes.first).toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Neon.fade(Neon.red, 0.4), Neon.fade(Neon.cyan, 0.3)],
        ),
      ),
      child: Center(child: Text(letter, style: displayStyle(size: 34))),
    );
  }
}

class _SpinPainter extends CustomPainter {
  _SpinPainter(this.v);

  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.shortestSide / 2 - 8;
    final Rect rect = Rect.fromCircle(center: c, radius: r);

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Neon.fade(Neon.cyan, 0.15),
    );
    final double a = v * 2 * math.pi;
    canvas.drawArc(
      rect,
      a,
      math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Neon.red,
    );
    canvas.drawArc(
      rect,
      -a * 1.4 + math.pi,
      math.pi * 0.45,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = Neon.cyan,
    );
  }

  @override
  bool shouldRepaint(_SpinPainter oldDelegate) => oldDelegate.v != v;
}
