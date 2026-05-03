import 'package:flutter/material.dart';

/// The Flow logo mark — a rounded green square with two dark wave lines.
class FlowLogo extends StatelessWidget {
  final double size;

  const FlowLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FlowLogoPainter(size: size),
      ),
    );
  }
}

class _FlowLogoPainter extends CustomPainter {
  final double size;

  const _FlowLogoPainter({required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final s = size / 48;

    // Rounded rect background — new brand green
    final bgPaint = Paint()
      ..color = const Color(0xFF4ADE80)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size, size),
        Radius.circular(size * 0.27),
      ),
      bgPaint,
    );

    // Wave stroke — dark lines on bright green background
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.052
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Wave 1 — full opacity dark
    wavePaint.color = const Color(0xFF0A0A0C);
    final wave1 = Path()
      ..moveTo(14 * s, 26 * s)
      ..cubicTo(14 * s, 26 * s, 17 * s, 20 * s, 24 * s, 20 * s)
      ..cubicTo(31 * s, 20 * s, 34 * s, 26 * s, 34 * s, 26 * s);
    canvas.drawPath(wave1, wavePaint);

    // Wave 2 — 50 % opacity dark
    wavePaint.color = const Color(0xFF0A0A0C).withValues(alpha: 0.5);
    final wave2 = Path()
      ..moveTo(14 * s, 32 * s)
      ..cubicTo(14 * s, 32 * s, 17 * s, 26 * s, 24 * s, 26 * s)
      ..cubicTo(31 * s, 26 * s, 34 * s, 32 * s, 34 * s, 32 * s);
    canvas.drawPath(wave2, wavePaint);
  }

  @override
  bool shouldRepaint(_FlowLogoPainter oldDelegate) =>
      oldDelegate.size != size;
}
