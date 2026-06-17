import 'dart:math';
import 'package:flutter/material.dart';

class SpacePainter extends CustomPainter {
  final Animation<double> animation;
  final List<Star> _stars = List.generate(200, (i) => Star());
  final List<ShootingStar> _shootingStars = List.generate(4, (i) => ShootingStar());

  SpacePainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    
    // Background Stars
    for (var star in _stars) {
      final pos = Offset(star.x * size.width, star.y * size.height);
      final twinkle = (0.2 + 0.8 * sin(animation.value * 2 * pi + star.offset)).clamp(0.1, 1.0);
      paint.color = star.color.withValues(alpha: twinkle * star.opacity);
      canvas.drawCircle(pos, star.size, paint);
    }

    // Shooting Stars
    for (var ss in _shootingStars) {
      final progress = (animation.value + ss.offset) % 1.0;
      if (progress < 0.2) { // Only visible for part of the cycle
        final p = progress / 0.2;
        final start = Offset(ss.startX * size.width, ss.startY * size.height);
        final end = Offset(ss.endX * size.width, ss.endY * size.height);
        final current = Offset.lerp(start, end, p)!;
        
        final ssPaint = Paint()
          ..shader = LinearGradient(
            colors: [ss.color.withOpacity(0), ss.color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Rect.fromPoints(current.translate(-20, -20), current));

        canvas.drawLine(
          current.translate(-30 * ss.dirX, -30 * ss.dirY),
          current,
          ssPaint
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(SpacePainter oldDelegate) => true;
}

class Star {
  final double x = Random().nextDouble();
  final double y = Random().nextDouble();
  final double size = 0.5 + Random().nextDouble() * 2.0;
  final double offset = Random().nextDouble() * 10;
  final double opacity = 0.3 + Random().nextDouble() * 0.7;
  final Color color = Random().nextDouble() > 0.8 
    ? (Random().nextBool() ? const Color(0xFF00FFFF).withOpacity(0.5) : const Color(0xFFFF8700).withOpacity(0.5))
    : Colors.white;
}

class ShootingStar {
  double startX = Random().nextDouble();
  double startY = Random().nextDouble();
  double endX = 0;
  double endY = 0;
  double dirX = 0;
  double dirY = 0;
  double offset = Random().nextDouble();
  Color color = Colors.primaries[Random().nextInt(Colors.primaries.length)];

  ShootingStar() {
    dirX = 0.5 + Random().nextDouble();
    dirY = 0.2 + Random().nextDouble();
    endX = startX + dirX * 0.3;
    endY = startY + dirY * 0.3;
  }
}
