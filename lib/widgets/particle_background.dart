import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/design_system.dart';

class ParticleBackground extends StatefulWidget {
  final AppThemeMode mode;
  final Offset mousePosition;
  const ParticleBackground({super.key, this.mode = AppThemeMode.ghosted, this.mousePosition = Offset.zero});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();
  final int _particleCount = 40; // Reduced for performance

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent, 
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                _updateParticles(size);
                return CustomPaint(
                  painter: ParticlePainter(_particles, widget.mousePosition),
                );
              },
            ),
          );
        }
      ),
    );
  }

  void _updateParticles(Size size) {
    if (size.width == 0 || size.height == 0) return;
    if (_particles.isEmpty) {
      for (int i = 0; i < _particleCount; i++) {
        _particles.add(Particle.random(size, _random, widget.mode));
      }
    }
    for (var particle in _particles) {
      particle.update(size);
    }
  }
}

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  double alpha;
  Color color;
  bool isCartoon;
  int cartoonShape; // 0: circle, 1: square, 2: triangle

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.alpha,
    required this.color,
    this.isCartoon = false,
    this.cartoonShape = 0,
  });

  factory Particle.random(Size size, Random random, AppThemeMode mode) {
    Color color;
    bool cartoon = false;
    int shape = 0;

    switch (mode) {
      case AppThemeMode.cosmic:
        // HIGH-FIDELITY COSMIC STARS
        final cosmicColors = [const Color(0xFF00D4FF), const Color(0xFFFF00FF), Colors.white];
        color = cosmicColors[random.nextInt(cosmicColors.length)];
        break;
      case AppThemeMode.aurora:
        color = random.nextDouble() > 0.5 ? DesignSystem.spectralGreen : const Color(0xFF00FFFF);
        break;
      case AppThemeMode.comic:
        final colors = [DesignSystem.comicYellow, DesignSystem.comicCyan, DesignSystem.comicMagenta, DesignSystem.comicRed];
        color = colors[random.nextInt(colors.length)];
        cartoon = true;
        shape = random.nextInt(3);
        break;
      case AppThemeMode.holi:
        final holiColors = [const Color(0xFFFF007F), const Color(0xFF00FFFF), const Color(0xFFFFE600), const Color(0xFFA200FF)];
        color = holiColors[random.nextInt(holiColors.length)];
        break;
      case AppThemeMode.ghosted:
        color = random.nextDouble() > 0.7 ? DesignSystem.ghostOrange : Colors.white;
    }

    return Particle(
      x: random.nextDouble() * size.width,
      y: random.nextDouble() * size.height,
      vx: (random.nextDouble() - 0.5) * (cartoon ? 2.0 : 0.5), 
      vy: (random.nextDouble() - 0.5) * (cartoon ? 2.0 : 0.5) - (cartoon ? 0 : 0.2),
      radius: random.nextDouble() * (cartoon ? 8.0 : 2.0) + 0.5,
      alpha: random.nextDouble() * (cartoon ? 0.8 : 0.5) + 0.1,
      color: color,
      isCartoon: cartoon,
      cartoonShape: shape,
    );
  }

  void update(Size size) {
    x += vx;
    y += vy;

    // Wrap around screen
    if (x < 0) x = size.width;
    if (x > size.width) x = 0;
    if (y < 0) y = size.height;
    if (y > size.height) y = 0;
    
    // Sine wave alpha pulse for breathing/twinkling effect
    alpha = (alpha + (isCartoon ? 0.002 : 0.008)) % 1.0; 
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Offset mousePosition;

  ParticlePainter(this.particles, this.mousePosition);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Removed Grid (as per user request)

    // 2. Draw Interactive Glow at Mouse Position
    if (mousePosition != Offset.zero) {
      final glowPaint = Paint()
        ..color = DesignSystem.ghostOrange.withOpacity(0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
      canvas.drawCircle(mousePosition, 200, glowPaint);
    }

    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withValues(alpha: particle.alpha)
        ..style = PaintingStyle.fill
        ..maskFilter = particle.isCartoon ? null : const MaskFilter.blur(BlurStyle.normal, 1.0);

      if (particle.isCartoon) {
        if (particle.cartoonShape == 0) {
          canvas.drawCircle(Offset(particle.x, particle.y), particle.radius, paint);
        } else if (particle.cartoonShape == 1) {
          canvas.drawRect(Rect.fromCircle(center: Offset(particle.x, particle.y), radius: particle.radius), paint);
        } else {
          final path = Path()
            ..moveTo(particle.x, particle.y - particle.radius)
            ..lineTo(particle.x + particle.radius, particle.y + particle.radius)
            ..lineTo(particle.x - particle.radius, particle.y + particle.radius)
            ..close();
          canvas.drawPath(path, paint);
        }
      } else {
        final path = Path()
          ..moveTo(particle.x, particle.y - particle.radius)
          ..lineTo(particle.x + particle.radius, particle.y)
          ..lineTo(particle.x, particle.y + particle.radius)
          ..lineTo(particle.x - particle.radius, particle.y)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }



  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

