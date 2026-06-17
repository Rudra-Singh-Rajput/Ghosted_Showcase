import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/design_system.dart';
import 'ghost_theme.dart';

class HauwaIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final int seed;

  const HauwaIcon({
    super.key,
    this.size = 24,
    this.color,
    this.seed = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = GhostTheme.of(context);
    final mode = theme?.themeMode ?? AppThemeMode.ghosted;
    final themeColor = color ?? DesignSystem.getThemeColor(mode);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: HauwaPainter(
          color: themeColor,
          mode: mode,
          seed: seed,
        ),
      ),
    );
  }
}

class HauwaPainter extends CustomPainter {
  final Color color;
  final AppThemeMode mode;
  final int seed;

  HauwaPainter({required this.color, required this.mode, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w * 0.5;
    final centerY = h * 0.5;
    final isComic = mode == AppThemeMode.comic;

    // 1. Concentric Confidentiality Telemetry rings
    if (!isComic) {
      final ringPaint = Paint()
        ..color = color.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.01;
      
      canvas.drawCircle(Offset(centerX, centerY), w * 0.45, ringPaint);
      
      // Dashed inner telemetry ring
      final dashedPaint = Paint()
        ..color = color.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.008;
      
      _drawDashedArc(canvas, Offset(centerX, centerY), w * 0.38, dashedPaint, 8);
    }

    // 2. Anonymous Hood Shape
    final hoodPaint = Paint()
      ..color = isComic ? DesignSystem.comicRed : color
      ..style = PaintingStyle.fill;

    final headW = w * 0.44;
    final headH = h * 0.5;
    final topY = centerY - headH * 0.45;
    final bottomY = centerY + headH * 0.55;

    final hoodPath = Path();
    // Start at top center peak
    hoodPath.moveTo(centerX, topY);
    // Left shoulder curve
    hoodPath.quadraticBezierTo(centerX - headW * 0.8, topY + headH * 0.1, centerX - headW, bottomY);
    // Base waves / digital whisper ripples
    hoodPath.lineTo(centerX - headW * 0.5, bottomY - headH * 0.1);
    hoodPath.lineTo(centerX, bottomY);
    hoodPath.lineTo(centerX + headW * 0.5, bottomY - headH * 0.1);
    hoodPath.lineTo(centerX + headW, bottomY);
    // Right shoulder curve
    hoodPath.quadraticBezierTo(centerX + headW * 0.8, topY + headH * 0.1, centerX, topY);
    hoodPath.close();

    // 3. Neon Eye Slits Cutout (Sleek tilted triangles pointing down)
    final eyePath = Path();
    final eyeY = topY + headH * 0.35;
    
    // Left eye
    eyePath.moveTo(centerX - headW * 0.45, eyeY);
    eyePath.lineTo(centerX - headW * 0.1, eyeY + headH * 0.12);
    eyePath.lineTo(centerX - headW * 0.35, eyeY + headH * 0.16);
    eyePath.close();

    // Right eye
    eyePath.moveTo(centerX + headW * 0.45, eyeY);
    eyePath.lineTo(centerX + headW * 0.1, eyeY + headH * 0.12);
    eyePath.lineTo(centerX + headW * 0.35, eyeY + headH * 0.16);
    eyePath.close();

    final finalHood = Path.combine(PathOperation.difference, hoodPath, eyePath);

    if (!isComic) {
      canvas.drawPath(finalHood, Paint()
        ..color = color.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }

    canvas.drawPath(finalHood, hoodPaint);

    if (isComic) {
      canvas.drawPath(finalHood, Paint()
        ..color = DesignSystem.comicInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05);
    }

    // 4. Whisper Ripple lines at bottom
    if (!isComic && w >= 40) {
      final ripplePaint = Paint()
        ..color = color.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.015;

      final rippleY = bottomY + w * 0.05;
      canvas.drawArc(
        Rect.fromLTRB(centerX - w * 0.25, rippleY - w * 0.05, centerX + w * 0.25, rippleY + w * 0.05),
        0.1, pi - 0.2, false, ripplePaint,
      );
      canvas.drawArc(
        Rect.fromLTRB(centerX - w * 0.15, rippleY, centerX + w * 0.15, rippleY + w * 0.05),
        0.1, pi - 0.2, false, ripplePaint..strokeWidth = w * 0.01,
      );
    }
  }

  void _drawDashedArc(Canvas canvas, Offset center, double radius, Paint paint, int dashCount) {
    final double dashAngle = pi / dashCount;
    for (int i = 0; i < dashCount; i++) {
      final double startAngle = pi + (i * 2 * dashAngle);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HauwaPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.mode != mode || oldDelegate.color != color;
}
