import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/design_system.dart';
import 'ghost_theme.dart';

class GhoulIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final int seed;

  const GhoulIcon({
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
      height: size, // Adjusted from 2.0 to 1.0 for better proportions
      child: CustomPaint(
        painter: GhoulPainter(
          color: themeColor,
          mode: mode,
          seed: seed,
        ),
      ),
    );
  }
}

class GhoulPainter extends CustomPainter {
  final Color color;
  final AppThemeMode mode;
  final int seed;

  GhoulPainter({required this.color, required this.mode, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _paintGhoulLogo(canvas, w, h);
  }

  void _paintGhoulLogo(Canvas canvas, double w, double h) {
    final centerX = w * 0.5;
    final centerY = h * 0.5;

    final headRadius = w * 0.35;
    final startX = centerX - headRadius;
    final startY = centerY - headRadius * 0.2;
    final bottomY = centerY + headRadius * 0.8;

    final bodyPath = Path();
    // Head semi-circle
    bodyPath.moveTo(startX, startY);
    bodyPath.arcTo(
      Rect.fromCircle(center: Offset(centerX, startY), radius: headRadius),
      pi,
      pi,
      false,
    );
    // Right side down
    bodyPath.lineTo(centerX + headRadius, bottomY);
    // Pacman bottom wiggles (3 peaks pointing down)
    final step = (headRadius * 2) / 6;
    bodyPath.lineTo(centerX + headRadius - step * 1, bottomY + headRadius * 0.15); // Peak 1
    bodyPath.lineTo(centerX + headRadius - step * 2, bottomY); // Valley 1
    bodyPath.lineTo(centerX + headRadius - step * 3, bottomY + headRadius * 0.15); // Peak 2
    bodyPath.lineTo(centerX + headRadius - step * 4, bottomY); // Valley 2
    bodyPath.lineTo(centerX + headRadius - step * 5, bottomY + headRadius * 0.15); // Peak 3
    bodyPath.lineTo(startX, bottomY); // Left side bottom
    bodyPath.close();

    // Paint the thick outline
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
      
    // Small glow shadow for the logo
    canvas.drawPath(bodyPath, Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    canvas.drawPath(bodyPath, borderPaint);

    // Two solid filled eye dots
    final eyePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
      
    final eyeRadius = headRadius * 0.18;
    final eyeY = startY + headRadius * 0.15;
    canvas.drawCircle(Offset(centerX - headRadius * 0.35, eyeY), eyeRadius, eyePaint);
    canvas.drawCircle(Offset(centerX + headRadius * 0.35, eyeY), eyeRadius, eyePaint);
  }

  @override
  bool shouldRepaint(covariant GhoulPainter oldDelegate) => oldDelegate.seed != seed || oldDelegate.mode != mode;
}

