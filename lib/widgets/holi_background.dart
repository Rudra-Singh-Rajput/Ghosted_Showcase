import 'dart:math';
import 'package:flutter/material.dart';

class HoliBackground extends StatefulWidget {
  const HoliBackground({super.key});

  @override
  State<HoliBackground> createState() => _HoliBackgroundState();
}

class _HoliBackgroundState extends State<HoliBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: HoliPainter(progress: _controller.value),
          child: Container(),
        );
      },
    );
  }
}

class HoliPainter extends CustomPainter {
  final double progress;

  HoliPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final double angle = progress * 2 * pi;

    // Background base color: deep velvet navy/pitch black
    canvas.drawColor(const Color(0xFF020205), BlendMode.srcOver);

    // List of splashes: color, center percentage, base radius, orbital speed, phase shift
    final splashes = [
      _Splash(
        colors: [const Color(0xFFFF007F).withOpacity(0.25), const Color(0xFFFF007F).withOpacity(0.0)],
        xPct: 0.25,
        yPct: 0.3,
        radius: size.width * 0.35,
        orbitRadius: 40,
        speed: 1.0,
        phase: 0.0,
      ),
      _Splash(
        colors: [const Color(0xFF00FFFF).withOpacity(0.20), const Color(0xFF00FFFF).withOpacity(0.0)],
        xPct: 0.75,
        yPct: 0.25,
        radius: size.width * 0.4,
        orbitRadius: 30,
        speed: -0.8,
        phase: pi / 3,
      ),
      _Splash(
        colors: [const Color(0xFFFFE600).withOpacity(0.18), const Color(0xFFFFE600).withOpacity(0.0)],
        xPct: 0.5,
        yPct: 0.65,
        radius: size.width * 0.38,
        orbitRadius: 50,
        speed: 0.6,
        phase: 2 * pi / 3,
      ),
      _Splash(
        colors: [const Color(0xFFA200FF).withOpacity(0.22), const Color(0xFFA200FF).withOpacity(0.0)],
        xPct: 0.3,
        yPct: 0.8,
        radius: size.width * 0.32,
        orbitRadius: 35,
        speed: -1.2,
        phase: pi,
      ),
    ];

    for (final splash in splashes) {
      final double splashAngle = angle * splash.speed + splash.phase;
      final double dx = cos(splashAngle) * splash.orbitRadius;
      final double dy = sin(splashAngle) * splash.orbitRadius;

      final double cx = size.width * splash.xPct + dx;
      final double cy = size.height * splash.yPct + dy;
      final Offset center = Offset(cx, cy);

      // Radial gradient to make the splashes look soft and watercolor-like
      final rect = Rect.fromCircle(center: center, radius: splash.radius);
      paint.shader = RadialGradient(
        colors: splash.colors,
        stops: const [0.0, 1.0],
      ).createShader(rect);

      // Draw main blob
      canvas.drawCircle(center, splash.radius, paint);

      // Add a couple of smaller satellite droplets/splatters around it
      for (int i = 0; i < 3; i++) {
        final double dropAngle = splashAngle * 1.5 + (i * pi / 1.5);
        final double dropDist = splash.radius * 0.7 + (15 * sin(splashAngle + i));
        final double dropX = cx + cos(dropAngle) * dropDist;
        final double dropY = cy + sin(dropAngle) * dropDist;
        final double dropRad = (splash.radius * 0.15) * (1 + 0.2 * sin(splashAngle));

        final dropCenter = Offset(dropX, dropY);
        final dropRect = Rect.fromCircle(center: dropCenter, radius: dropRad);
        
        // Match base color with alpha fade
        final baseColor = splash.colors[0];
        paint.shader = RadialGradient(
          colors: [baseColor.withOpacity(baseColor.opacity * 0.7), baseColor.withOpacity(0)],
        ).createShader(dropRect);
        
        canvas.drawCircle(dropCenter, dropRad, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Splash {
  final List<Color> colors;
  final double xPct;
  final double yPct;
  final double radius;
  final double orbitRadius;
  final double speed;
  final double phase;

  const _Splash({
    required this.colors,
    required this.xPct,
    required this.yPct,
    required this.radius,
    required this.orbitRadius,
    required this.speed,
    required this.phase,
  });
}
