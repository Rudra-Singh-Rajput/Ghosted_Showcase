import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'space_painter.dart';
import 'ghost_animation.dart';

class VoidEmptyState extends StatefulWidget {
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;
  final VoidCallback? secondaryAction;
  final String? secondaryActionLabel;
  const VoidEmptyState({
    super.key, 
    required this.message,
    this.onAction,
    this.actionLabel,
    this.secondaryAction,
    this.secondaryActionLabel,
  });

  @override
  State<VoidEmptyState> createState() => _VoidEmptyStateState();
}

class _VoidEmptyStateState extends State<VoidEmptyState> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: SpacePainter(animation: _controller),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 16,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 20),
                if (widget.onAction != null && widget.actionLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton(
                      onPressed: widget.onAction,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Color(0xFFFF8700).withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        widget.actionLabel!,
                        style: GoogleFonts.outfit(color: const Color(0xFFFF8700), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
                      ),
                    ),
                  ),
                if (widget.secondaryAction != null && widget.secondaryActionLabel != null)
                   Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: TextButton(
                      onPressed: widget.secondaryAction,
                      child: Text(
                        widget.secondaryActionLabel!,
                        style: GoogleFonts.outfit(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const GhostAnimation(size: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

