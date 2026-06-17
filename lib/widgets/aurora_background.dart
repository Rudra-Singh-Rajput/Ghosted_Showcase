import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/design_system.dart';

class AuroraBackground extends StatefulWidget {
  final AppThemeMode mode;
  const AuroraBackground({super.key, this.mode = AppThemeMode.aurora});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: AuroraPainter(_controller.value, widget.mode),
          size: Size.infinite,
        );
      },
    );
  }
}

class AuroraPainter extends CustomPainter {
  final double animationValue;
  final AppThemeMode mode;
  AuroraPainter(this.animationValue, this.mode);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    
    // Deep Space Base
    canvas.drawRect(rect, Paint()..color = const Color(0xFF02040A));

    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);

    for (int i = 0; i < 3; i++) {
      final double phase = (animationValue + (i * 0.33)) % 1.0;
      final double x = size.width * (0.2 + (i * 0.3) + (sin(phase * pi * 2) * 0.1));
      
      final Path path = Path();
      path.moveTo(x, 0);
      
      for (double y = 0; y <= size.height; y += 20) {
        final double wave = sin((y / size.height * pi * 2) + (phase * pi * 4)) * 40;
        path.lineTo(x + wave, y);
      }
      
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
      path.close();

      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _getAuroraColor(i).withOpacity(0.0),
          _getAuroraColor(i).withOpacity(0.15),
          _getAuroraColor(i).withOpacity(0.0),
        ],
      ).createShader(rect);

      canvas.drawPath(path, paint);
    }
  }

  Color _getAuroraColor(int index) {
    if (mode == AppThemeMode.ghosted) {
      switch (index) {
        case 0: return const Color(0xFFFF8000); // Ghost Orange
        case 1: return const Color(0xFFFF4500); // Orange Red
        case 2: return const Color(0xFFFFB300); // Amber Orange
        default: return Colors.orange;
      }
    }
    switch (index) {
      case 0: return const Color(0xFF00FF88); // Spectral Green
      case 1: return const Color(0xFFBF00FF); // Neon Purple
      case 2: return const Color(0xFF00D4FF); // Arcade Blue
      default: return Colors.green;
    }
  }

  @override
  bool shouldRepaint(covariant AuroraPainter oldDelegate) => true;
}
