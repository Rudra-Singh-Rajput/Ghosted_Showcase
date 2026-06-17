import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/design_system.dart';
import 'ghoul_icon.dart';

class GhostTourGuide extends StatefulWidget {
  final VoidCallback onComplete;
  final Function(int)? onStepChanged;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onCloseDrawer;
  const GhostTourGuide({super.key, required this.onComplete, this.onStepChanged, this.onOpenDrawer, this.onCloseDrawer});

  @override
  State<GhostTourGuide> createState() => _GhostTourGuideState();
}

class _GhostTourGuideState extends State<GhostTourGuide> {
  int _currentStep = 0;

  final List<TourStep> _steps = [
    TourStep(
      title: "GREETINGS, SOUL",
      message: "I am your guide. Let me show you how to navigate this void. Ready?",
      alignment: Alignment.center,
      icon: LucideIcons.ghost,
    ),
    TourStep(
      title: "THE VOID",
      message: "The main feed. Use ❤️ (Echoes) to sustain a whisper and 💬 (Resonance) to reply. Whispers fade if ignored.",
      alignment: Alignment.center,
      icon: LucideIcons.layers,
      pageIndex: 1,
    ),
    TourStep(
      title: "THE SANCTUARY",
      message: "Tap 🔮 in the dock. A pit for fleeting thoughts. Tap '+ REACT' to leave your mark on others' secrets.",
      alignment: Alignment.bottomLeft,
      icon: LucideIcons.sparkles,
      pageIndex: 0,
    ),
    TourStep(
      title: "IDENTITY REVEAL",
      message: "Tap ⚡ (SÉANCE) to chat anonymously. After 7 messages, your identity manifests. Magic, right?",
      alignment: Alignment.bottomRight,
      icon: LucideIcons.zap,
      pageIndex: 3,
    ),
    TourStep(
      title: "DIRECT INBOX",
      message: "Your private echoes live in 📩 (INBOX). Check your active SÉANCES and messages here.",
      alignment: Alignment.bottomRight,
      icon: LucideIcons.messageSquare,
      pageIndex: 4,
    ),
    TourStep(
      title: "THE MENU",
      message: "Tap the Ghoul icon or swipe from the left to open the Menu. This is where the deeper features hide.",
      alignment: Alignment.topLeft,
      icon: LucideIcons.menu,
      action: TourAction.openDrawer,
    ),
    TourStep(
      title: "ARCHIVES & VAULT",
      message: "Access THE ARCHIVES to see spirits, or THE VAULT for shared university wisdom and notes.",
      alignment: Alignment.centerLeft,
      icon: LucideIcons.bookOpen,
    ),
    TourStep(
      title: "MULTI-UNIVERSES",
      message: "Tap the floating orb in the top right to shift between COSMIC, AURORA, and COMIC energy modes.",
      alignment: Alignment.topRight,
      icon: LucideIcons.globe,
      action: TourAction.closeDrawer,
    ),
    TourStep(
      title: "ENTER THE VOID",
      message: "You are ready. Go forth and manifest your presence among the spirits. Stay ghosted.",
      alignment: Alignment.center,
      icon: LucideIcons.ghost,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // LIGHTWEIGHT OVERLAY
          if (_currentStep > 0)
            Positioned.fill(
              child: _buildSpotlight(step.alignment),
            ),

          // SPIRIT GUIDE CHARACTER
          AnimatedAlign(
            duration: 800.ms,
            curve: Curves.easeInOutBack,
            alignment: step.alignment,
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // SPEECH BUBBLE
                  Container(
                    width: 280,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: DesignSystem.ghostOrange.withOpacity(0.5), width: 2),
                      boxShadow: [
                        BoxShadow(color: DesignSystem.ghostOrange.withOpacity(0.2), blurRadius: 30),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.title, 
                          style: GoogleFonts.outfit(color: DesignSystem.ghostOrange, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(step.message, 
                          style: GoogleFonts.inconsolata(color: Colors.white, fontSize: 15, height: 1.4)),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: widget.onComplete,
                              child: Text("SKIP", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                if (_currentStep < _steps.length - 1) {
                                  setState(() => _currentStep++);
                                  final nextStep = _steps[_currentStep];
                                  
                                  // PAGE NAVIGATION
                                  if (nextStep.pageIndex != null) {
                                    widget.onStepChanged?.call(nextStep.pageIndex!);
                                  }
                                  
                                  // DRAWER ACTIONS
                                  if (nextStep.action == TourAction.openDrawer) {
                                    widget.onOpenDrawer?.call();
                                  } else if (nextStep.action == TourAction.closeDrawer) {
                                    widget.onCloseDrawer?.call();
                                  }
                                } else {
                                  widget.onComplete();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DesignSystem.ghostOrange,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: Text(_currentStep == _steps.length - 1 ? "MANIFEST" : "NEXT", 
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().scale(delay: 200.ms).fadeIn(),

                  const SizedBox(height: 20),
                  
                  // CHARACTER ICON
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                      border: Border.all(color: DesignSystem.ghostOrange, width: 2),
                    ),
                    child: const Center(child: GhoulIcon(size: 30, color: DesignSystem.ghostOrange)),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                   .moveY(begin: -5, end: 5, duration: 2.seconds)
                   .shimmer(duration: 3.seconds, color: Colors.white24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotlight(Alignment alignment) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: alignment,
          radius: 0.6,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.5),
          ],
          stops: const [0.4, 1.0],
        ),
      ),
    );
  }
}

enum TourAction { openDrawer, closeDrawer }

class TourStep {
  final String title;
  final String message;
  final Alignment alignment;
  final IconData icon;
  final int? pageIndex;
  final TourAction? action;

  TourStep({required this.title, required this.message, required this.alignment, required this.icon, this.pageIndex, this.action});
}
