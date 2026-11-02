import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// A stylised PC tower for hero panels. Decorative, not a picture of any part.
class RigTowerArt extends StatelessWidget {
  const RigTowerArt({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 0.72,
        child: CustomPaint(painter: _TowerPainter()),
      ),
    );
  }
}

class _TowerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const shell = Color(0xFF1B1E16);
    const edge = Color(0xFF3A3F31);
    const glass = Color(0xFF0B0D08);

    RRect box(double l, double t, double r, double b, double radius) =>
        RRect.fromLTRBR(
          l * w,
          t * h,
          r * w,
          b * h,
          Radius.circular(radius * w),
        );

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.965),
        width: w * 0.9,
        height: h * 0.06,
      ),
      Paint()
        ..color = RigPalette.ink.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Feet, side depth, body.
    final feet = Paint()..color = RigPalette.ink;
    canvas.drawRRect(box(0.16, 0.92, 0.3, 0.97, 0.02), feet);
    canvas.drawRRect(box(0.7, 0.92, 0.84, 0.97, 0.02), feet);
    canvas.drawRRect(box(0.1, 0.03, 0.96, 0.95, 0.09), Paint()..color = edge);
    canvas.drawRRect(box(0.05, 0.03, 0.9, 0.95, 0.09), Paint()..color = shell);

    // Glass panel.
    final panel = box(0.11, 0.08, 0.84, 0.9, 0.05);
    canvas.drawRRect(panel, Paint()..color = glass);

    canvas.save();
    canvas.clipRRect(panel);

    // Glow rising from the fans.
    canvas.drawCircle(
      Offset(w * 0.47, h * 0.72),
      w * 0.55,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                RigPalette.volt.withValues(alpha: 0.34),
                RigPalette.volt.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(w * 0.47, h * 0.72),
                radius: w * 0.55,
              ),
            ),
    );

    // Memory sticks.
    for (var i = 0; i < 4; i++) {
      final left = 0.5 + i * 0.07;
      canvas.drawRRect(
        box(left, 0.14, left + 0.045, 0.34, 0.012),
        Paint()..color = i.isEven ? RigPalette.lilac : RigPalette.sky,
      );
    }

    // Processor cooler.
    final coolerCenter = Offset(w * 0.29, h * 0.24);
    canvas.drawCircle(coolerCenter, w * 0.125, Paint()..color = edge);
    _drawFan(canvas, coolerCenter, w * 0.105, RigPalette.tangerine);

    // Graphics card.
    canvas.drawRRect(
      box(0.14, 0.43, 0.82, 0.54, 0.018),
      Paint()..color = const Color(0xFF2A2E22),
    );
    canvas.drawRRect(
      box(0.14, 0.525, 0.82, 0.54, 0.008),
      Paint()..color = RigPalette.tangerine,
    );
    for (final x in [0.3, 0.56]) {
      _drawFan(canvas, Offset(w * x, h * 0.485), w * 0.05, edge);
    }

    // Intake fans.
    for (final x in [0.3, 0.65]) {
      _drawFan(canvas, Offset(w * x, h * 0.73), w * 0.145, RigPalette.volt);
    }

    // A diagonal reflection across the glass.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.52, h * 0.08)
        ..lineTo(w * 0.72, h * 0.08)
        ..lineTo(w * 0.34, h * 0.9)
        ..lineTo(w * 0.14, h * 0.9)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.05),
    );
    canvas.restore();

    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  void _drawFan(Canvas canvas, Offset center, double radius, Color color) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.16
      ..color = color;
    canvas.drawCircle(center, radius, ring);

    final blade = Paint()..color = color.withValues(alpha: 0.75);
    for (var i = 0; i < 6; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * math.pi / 3);
      canvas.drawPath(
        Path()
          ..moveTo(0, -radius * 0.14)
          ..quadraticBezierTo(
            radius * 0.5,
            -radius * 0.74,
            radius * 0.1,
            -radius * 0.8,
          )
          ..quadraticBezierTo(-radius * 0.2, -radius * 0.5, 0, -radius * 0.14)
          ..close(),
        blade,
      );
      canvas.restore();
    }
    canvas.drawCircle(center, radius * 0.17, Paint()..color = RigPalette.ink);
  }

  @override
  bool shouldRepaint(_TowerPainter oldDelegate) => false;
}

/// Blueprint-style grid drawn behind the 3D model.
class BlueprintGrid extends StatelessWidget {
  final Widget child;

  const BlueprintGrid({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter(), child: child);
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = RigPalette.ink);
    final minor = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    const step = 24.0;
    var index = 0;
    for (var x = 0.0; x < size.width; x += step, index++) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        index % 4 == 0 ? major : minor,
      );
    }
    index = 0;
    for (var y = 0.0; y < size.height; y += step, index++) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        index % 4 == 0 ? major : minor,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
