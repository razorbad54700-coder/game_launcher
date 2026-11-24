import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Petite courbe de tendance (historique de température, de RAM…).
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 48,
    this.minY,
    this.maxY,
  });

  final List<double> values;
  final Color color;
  final double height;

  /// Bornes verticales imposées (sinon calculées sur les valeurs).
  final double? minY;
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        // Copie : la liste d'origine est modifiée en place par le moniteur.
        painter: _SparkPainter(List<double>.of(values), color, minY, maxY),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color, this.minY, this.maxY);

  final List<double> values;
  final Color color;
  final double? minY;
  final double? maxY;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Ligne de base discrète.
    canvas.drawLine(
      Offset(0, h - 1),
      Offset(w, h - 1),
      Paint()
        ..strokeWidth = 1
        ..color = Neon.fade(color, 0.18),
    );
    if (values.length < 2) return;

    double lo = minY ?? values.reduce((double a, double b) => a < b ? a : b);
    double hi = maxY ?? values.reduce((double a, double b) => a > b ? a : b);
    if (minY == null) lo -= 0.5;
    if (maxY == null) hi += 0.5;
    if (hi - lo < 0.0001) hi = lo + 1.0;

    final int n = values.length;
    Offset point(int i) {
      final double x = w * i / (n - 1);
      final double v = clampD(values[i], lo, hi);
      final double y = (h - 4) - (v - lo) / (hi - lo) * (h - 8) + 2;
      return Offset(x, y);
    }

    final Path line = Path()..moveTo(point(0).dx, point(0).dy);
    for (int i = 1; i < n; i++) {
      final Offset p = point(i);
      line.lineTo(p.dx, p.dy);
    }

    final Path fill = Path.from(line)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Neon.fade(color, 0.30), Neon.fade(color, 0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    // Point lumineux sur la dernière mesure.
    final Offset last = point(n - 1);
    canvas.drawCircle(
      last,
      6,
      Paint()
        ..color = Neon.fade(color, 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(last, 2.8, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter oldDelegate) => true;
}
