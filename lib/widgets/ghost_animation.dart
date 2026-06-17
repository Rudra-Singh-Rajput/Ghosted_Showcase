import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../utils/design_system.dart';

class GhostAnimation extends StatelessWidget {
  final double size;
  final Color? color;

  const GhostAnimation({
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Icon(
        LucideIcons.ghost,
        color: color ?? DesignSystem.ghostOrange,
        size: size,
      )
      .animate(onPlay: (controller) => controller.repeat())
      .moveY(begin: -5, end: 5, duration: 1500.ms, curve: Curves.easeInOut)
      .then()
      .moveY(begin: 5, end: -5, duration: 1500.ms, curve: Curves.easeInOut)
      .animate(onPlay: (controller) => controller.repeat())
      .shimmer(duration: 3.seconds, color: Colors.white24)
      .shake(hz: 0.5, rotation: 0.05),
    );
  }
}
