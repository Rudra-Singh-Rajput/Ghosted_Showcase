import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/particle_background.dart';
import '../utils/design_system.dart';
import '../widgets/logo_painter.dart';
import 'login_screen.dart';
import '../layout/app_layout.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late List<Particle> particles;
  final Random random = Random();
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _controller.addListener(() => setState(() {}));
    _controller.forward();

    particles = List.generate(50, (index) => Particle(
      x: random.nextDouble() * 450,
      y: random.nextDouble() * 1000,
      size: random.nextDouble() * 3 + 1,
      speed: random.nextDouble() * 2 + 0.5,
      angle: random.nextDouble() * 2 * pi,
    ));

    Future.delayed(const Duration(seconds: 6), () async {
      if (mounted) {
        final user = FirebaseAuth.instance.currentUser;
        
        // SECURITY REINFORCEMENT: Force logout of stale anonymous/bypassed logic
        // Only persistent accounts (University) should skip the login.
        if (user != null && user.isAnonymous) {
           await FirebaseAuth.instance.signOut();
           Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
           return;
        }

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, a, b) => user != null ? const AppLayout() : const LoginScreen(),
            transitionsBuilder: (context, a, b, child) => FadeTransition(opacity: a, child: child),
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });

  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ParticleBackground(),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Cinematic Entry Animation
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF8700).withOpacity(0.1),
                        blurRadius: 100,
                        spreadRadius: 20,
                      )
                    ],
                  ),
                  child: SizedBox(
                    height: 150,
                    width: 150,
                    child: DesignSystem.logo(context: context, size: 150),
                  ).animate()
                   // 1. Approach from the afar (Right + Tiny Scale)
                   .moveX(begin: screenWidth * 0.5, end: 0, duration: 1.8.seconds, curve: Curves.easeOutQuart)
                   .scaleXY(begin: 0.05, end: 1.0, duration: 1.8.seconds, curve: Curves.easeOutQuart)
                   .fadeIn(duration: 1.seconds)
                   // 2. The Intense Stare (Subtle pulse)
                   .then(delay: 1.seconds)
                   .shimmer(duration: 1.5.seconds, color: Colors.white24)
                   // Instead of a nested .animate, use a callback or just chain the pulse
                   .then()
                   .scaleXY(begin: 1.0, end: 1.05, duration: 1.seconds, curve: Curves.easeInOut)
                   .then()
                   .scaleXY(begin: 1.05, end: 1.0, duration: 1.seconds, curve: Curves.easeInOut)
                   // 3. Final Manifestation (Cover screen)
                   .then(delay: 500.ms)
                   .scaleXY(begin: 1.0, end: 60.0, duration: 1.2.seconds, curve: Curves.easeInQuint)
                   .fadeOut(duration: 600.ms),
                ),

              ],
            ),
          ),
          
          // Version Info
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "MANIFEST V8.0 [PURPLE-ORANGE-VIBE]",
                style: GoogleFonts.inconsolata(
                  color: Colors.white.withOpacity(0.05),
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ).animate().fadeIn(delay: 800.ms),
            ),
          ),
        ],
      ),
    );
  }
}

class Particle {
  double x, y, size, speed, angle;
  Particle({required this.x, required this.y, required this.size, required this.speed, required this.angle});
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Color(0xFFFF8700).withOpacity(0.5);
    for (var p in particles) {
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
      p.y -= p.speed; // Moving up
      p.x += cos(p.angle) * 0.5; // slight wave
      if (p.y < 0) p.y = size.height; // Reset
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; 
}

