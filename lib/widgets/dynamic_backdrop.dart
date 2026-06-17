import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/design_system.dart';
import 'ghost_theme.dart';

class DynamicBackdrop extends StatefulWidget {
  final AppThemeMode mode;
  const DynamicBackdrop({super.key, required this.mode});

  @override
  State<DynamicBackdrop> createState() => _DynamicBackdropState();
}

class _DynamicBackdropState extends State<DynamicBackdrop> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Blob> _blobs = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    
    // Initialize blobs based on theme
    _initBlobs();
  }

  void _initBlobs() {
    _blobs.clear();
    final color = DesignSystem.getThemeColor(widget.mode);
    
    if (widget.mode == AppThemeMode.comic) {
      final comicColors = [DesignSystem.comicYellow, DesignSystem.comicCyan, DesignSystem.comicMagenta];
      for (int i = 0; i < 4; i++) {
        _blobs.add(Blob(
          color: comicColors[i % comicColors.length],
          position: Offset(_random.nextDouble(), _random.nextDouble()),
          size: 0.1 + _random.nextDouble() * 0.1, // Small dots for halftone feel
          speed: 0.0002 + _random.nextDouble() * 0.0005,
        ));
      }
    } else if (widget.mode == AppThemeMode.cosmic) {
      // HIGH-FIDELITY NEBULA BLOBS
      final cosmicColors = [
        const Color(0xFF00D4FF), // Electric Cyan
        const Color(0xFFFF00FF), // Vivid Magenta
        const Color(0xFF4B0082), // Indigo
        const Color(0xFFFFD700).withOpacity(0.3), // Cosmic Gold Dust
      ];
      for (int i = 0; i < 5; i++) {
        _blobs.add(Blob(
          color: cosmicColors[i % cosmicColors.length],
          position: Offset(_random.nextDouble(), _random.nextDouble()),
          size: 0.7 + _random.nextDouble() * 0.5, 
          speed: 0.0003 + _random.nextDouble() * 0.0006,
        ));
      }
    } else {
      // GHOSTED / AURORA
      final themeColor = DesignSystem.getThemeColor(widget.mode);
      final colors = widget.mode == AppThemeMode.ghosted 
        ? [
            DesignSystem.ghostOrange,
            DesignSystem.neonPurple,
            DesignSystem.voidMagenta.withOpacity(0.5),
            Colors.white.withOpacity(0.2),
          ]
        : [
            DesignSystem.spectralGreen,
            DesignSystem.astralCyan,
            Colors.white.withOpacity(0.2),
          ];
          
      for (int i = 0; i < (widget.mode == AppThemeMode.ghosted ? 6 : 4); i++) {
        _blobs.add(Blob(
          color: colors[i % colors.length],
          position: Offset(_random.nextDouble(), _random.nextDouble()),
          size: 0.5 + _random.nextDouble() * 0.5,
          speed: 0.001 + _random.nextDouble() * 0.003,
        ));
      }
    }
  }

  @override
  void didUpdateWidget(DynamicBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _initBlobs();
    }
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
        for (var blob in _blobs) {
          blob.update();
        }
        return CustomPaint(
          painter: BackdropPainter(_blobs, widget.mode),
          size: Size.infinite,
        );
      },
    );
  }
}

class Blob {
  Color color;
  Offset position;
  double size;
  double speed;
  double angle;

  Blob({required this.color, required this.position, required this.size, required this.speed})
      : angle = Random().nextDouble() * pi * 2;

  void update() {
    position += Offset(cos(angle) * speed, sin(angle) * speed);
    if (position.dx < 0 || position.dx > 1) angle = pi - angle;
    if (position.dy < 0 || position.dy > 1) angle = -angle;
  }
}

class BackdropPainter extends CustomPainter {
  final List<Blob> blobs;
  final AppThemeMode mode;

  BackdropPainter(this.blobs, this.mode);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    
    // Background color
    canvas.drawRect(Offset.zero & size, Paint()..color = mode == AppThemeMode.comic ? DesignSystem.comicPaper : Colors.black);

    if (mode == AppThemeMode.cosmic) {
      _drawNebulaClouds(canvas, size);
    }

    for (var blob in blobs) {
      final blobSize = blob.size * size.shortestSide;
      final offset = Offset(blob.position.dx * size.width, blob.position.dy * size.height);
      
      canvas.drawCircle(
        offset, 
        blobSize, 
        paint..color = blob.color.withOpacity(mode == AppThemeMode.comic ? 0.2 : (mode == AppThemeMode.cosmic ? 0.3 : 0.4)),
      );
    }
  }

  void _drawHalftone(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = DesignSystem.comicInk.withOpacity(0.05);
    const double spacing = 12.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  void _drawNebulaClouds(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);
    final time = DateTime.now().millisecondsSinceEpoch / 8000.0;

    for (int i = 0; i < 4; i++) {
      final double x = size.width * (0.5 + 0.4 * sin(time + i * 1.5));
      final double y = size.height * (0.5 + 0.4 * cos(time * 0.7 + i * 2.0));
      final double radius = size.shortestSide * 0.8;

      final colors = [
        const Color(0xFF00D4FF).withOpacity(0.15),
        const Color(0xFFA200FF).withOpacity(0.15),
        const Color(0xFFFF006E).withOpacity(0.1),
        const Color(0xFFFFD700).withOpacity(0.05),
      ];

      paint.shader = RadialGradient(
        colors: [colors[i % colors.length], Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(x, y), radius: radius));

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
