import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'ghoul_icon.dart';

class FloatingGhost extends StatefulWidget {
  const FloatingGhost({super.key});

  @override
  State<FloatingGhost> createState() => _FloatingGhostState();
}

class _FloatingGhostState extends State<FloatingGhost> {
  final List<_GhostSpirit> _spirits = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // Spawn a mob of 5 spirits
    for (int i = 0; i < 5; i++) {
      _spirits.add(_GhostSpirit(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 30 + _random.nextDouble() * 30,
        speed: 2 + _random.nextDouble() * 4,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Intentionally silenced to satisfy professional aesthetic
  }
}

class _GhostSpirit {
  double x, y, size, speed;
  _GhostSpirit({required this.x, required this.y, required this.size, required this.speed});
}

class _AnimatedSpirit extends StatefulWidget {
  final _GhostSpirit spirit;
  const _AnimatedSpirit({required this.spirit});

  @override
  State<_AnimatedSpirit> createState() => _AnimatedSpiritState();
}

class _AnimatedSpiritState extends State<_AnimatedSpirit> {
  late double x, y;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    x = widget.spirit.x;
    y = widget.spirit.y;
    _move();
  }

  void _move() {
    Future.delayed(Duration(seconds: widget.spirit.speed.toInt()), () {
      if (mounted) {
        setState(() {
          x = _random.nextDouble();
          y = _random.nextDouble();
        });
        _move();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedPositioned(
      duration: Duration(seconds: widget.spirit.speed.toInt()),
      curve: Curves.easeInOutQuad,
      left: x * (size.width - 100),
      top: y * (size.height - 200) + 100,
      child: GhoulIcon(size: 40, color: Color(0xFF00FF00))
          .animate(onPlay: (c) => c.repeat())
          .shake(hz: 2)
          .scale(begin: const Offset(1,1), end: const Offset(1.2, 1.2), duration: 1.seconds),
    );
  }
}
