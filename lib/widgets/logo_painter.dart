import 'package:flutter/material.dart';
import '../utils/design_system.dart';

import 'ghoul_icon.dart';

class LogoPainter extends CustomPainter {
  final Offset mousePosition;
  final AppThemeMode mode;
  final int seed;

  LogoPainter({
    this.mousePosition = Offset.zero,
    this.mode = AppThemeMode.ghosted,
    this.seed = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // We delegate the heavy lifting to GhoulPainter for consistency, 
    // but we can add extra "Logo" flares here.
    final painter = GhoulPainter(
      color: DesignSystem.getThemeColor(mode),
      mode: mode,
      seed: seed,
    );
    
    painter.paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant LogoPainter oldDelegate) => 
    oldDelegate.mode != mode || oldDelegate.seed != seed;
}
