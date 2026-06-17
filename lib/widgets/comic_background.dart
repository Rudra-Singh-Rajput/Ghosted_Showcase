import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/design_system.dart';

class ComicBackground extends StatelessWidget {
  const ComicBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Aged Paper Base
        Positioned.fill(
          child: Container(color: DesignSystem.comicPaper),
        ),
      ],
    );
  }
}

class HalftonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = DesignSystem.comicInk.withOpacity(0.03);
    const double spacing = 15;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PanelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DesignSystem.comicInk.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Draw some random comic panel lines
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.35, size.height), paint);
    canvas.drawLine(Offset(0, size.height * 0.4), Offset(size.width, size.height * 0.45), paint);
    canvas.drawLine(Offset(size.width * 0.7, 0), Offset(size.width * 0.65, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
