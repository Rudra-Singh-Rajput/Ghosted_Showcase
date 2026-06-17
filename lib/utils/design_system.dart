import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/ghost_theme.dart';
import '../widgets/logo_painter.dart';

enum AppThemeMode { ghosted, cosmic, aurora, comic, holi }

class DesignSystem {
  // --- ACCENTS ---
  static const Color ghostOrange = Color(0xFFFF8000); // More vibrant professional orange
  static const Color voidMagenta = Color(0xFFFF00FF); // More vibrant
  static const Color astralCyan = Color(0xFF00FFFF); // Max cyan
  static const Color pulseRed = Color(0xFFFF3300);
  static const Color spectralGreen = Color(0xFF00FFCC); // Slightly more teal/colorful
  static const Color hyperLemon = Color(0xFFCCFF00);
  static const Color neonPurple = Color(0xFFA200FF);
  static const Color arcadeBlue = Color(0xFF00D4FF);
  static const Color candyPink = Color(0xFFFF006E);
  static const Color deepSpace = Color(0xFF010101); // Sober Black
  static const Color voidDeepBlue = Color(0xFF05050A);
  static const Color voidGlowPurple = Color(0xFF7000FF);
  static const Color slimeGreen = Color(0xFF32CD32); // Retro Comic Slime
  static const Color bubblegumPink = Color(0xFFFF69B4); // Retro Comic Pink
  
  // --- COMIC AESTHETIC (RETRO PALETTE) ---
  static const Color comicInk = Color(0xFF121212);
  static const Color comicPaper = Color(0xFFFFF9E6); // More aged/yellowish paper
  static const Color comicYellow = Color(0xFFFFE100);
  static const Color comicRed = Color(0xFFFF0000);
  static const Color comicCyan = Color(0xFF00FFFF);
  static const Color comicMagenta = Color(0xFFFF00FF);

  // --- THEME: SOLAR VOID (LIGHT) ---
  static const Color lightBackground = Color(0xFFF5F5F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFE8E8E8);
  static const Color lightTextPrimary = Color(0xFF1D1D1F);
  static const Color lightTextSecondary = Color(0xFF424245);
  static const Color lightTextMuted = Color(0xFF86868B);

  // --- THEME: ETHEREAL NIGHT (DARK) ---
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF0F0F0F);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Colors.white70;
  static const Color darkTextMuted = Colors.white24;

  // --- GLASSMORPHISM ---
  static BoxDecoration glass({
    required BuildContext context,
    double opacity = 0.03,
    double blur = 20,
    double radius = 24,
    bool showBorder = true,
  }) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final themeColor = getThemeColor(mode);
    final isComic = mode == AppThemeMode.comic;

    if (isComic) {
      return BoxDecoration(
        color: comicPaper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: comicInk, width: 3),
        boxShadow: const [BoxShadow(color: comicInk, offset: Offset(4, 4))],
      );
    }

    return BoxDecoration(
      color: Colors.black.withOpacity(0.6),
      borderRadius: BorderRadius.circular(radius),
      border: showBorder 
        ? Border.all(color: themeColor.withOpacity(0.18), width: 1.2)
        : null,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.04),
          themeColor.withOpacity(0.01),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: themeColor.withOpacity(0.05),
          blurRadius: blur,
          spreadRadius: -4,
        ),
      ],
    );
  }

  // --- TYPOGRAPHY ---
  static TextStyle heading({required BuildContext context, Color? color, double size = 20, FontWeight weight = FontWeight.w900, double letterSpacing = 2}) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    if (mode == AppThemeMode.comic) {
      return GoogleFonts.bangers(color: color ?? comicInk, fontSize: size * 1.35, letterSpacing: 1.5);
    }
    if (mode == AppThemeMode.cosmic) {
      return GoogleFonts.orbitron(
        color: color ?? Colors.white,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing * 1.2,
      );
    }
    if (mode == AppThemeMode.aurora) {
      return GoogleFonts.quicksand(
        color: color ?? Colors.white,
        fontSize: size,
        fontWeight: FontWeight.bold,
        letterSpacing: letterSpacing,
      );
    }
    final themeColor = getThemeColor(mode);
    return GoogleFonts.outfit(
      color: color ?? Colors.white,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      shadows: [
        Shadow(
          color: themeColor.withOpacity(0.4),
          blurRadius: 10,
        ),
      ],
    );
  }

  static TextStyle body({required BuildContext context, Color? color, double size = 14, FontWeight weight = FontWeight.w400, double height = 1.5}) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final defaultColor = mode == AppThemeMode.comic ? comicInk.withOpacity(0.9) : Colors.white.withOpacity(0.9);
    
    if (mode == AppThemeMode.comic) {
      return GoogleFonts.comicNeue(
        color: color ?? defaultColor,
        fontSize: size,
        fontWeight: FontWeight.bold,
        height: height,
      );
    }
    return GoogleFonts.inter(color: color ?? defaultColor, fontSize: size, fontWeight: weight, height: height);
  }

  static TextStyle sub({Color? color, double size = 10, FontWeight weight = FontWeight.w800, double letterSpacing = 1.5}) {
    return GoogleFonts.outfit(color: color ?? Colors.white38, fontSize: size, fontWeight: weight, letterSpacing: letterSpacing);
  }

  // --- CARDS ---
  static BoxDecoration voidCard({required BuildContext context, double radius = 24}) {
    final themeMode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final themeColor = getThemeColor(themeMode);
    
    if (themeMode == AppThemeMode.comic) {
      return BoxDecoration(
        color: comicPaper,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: comicInk, width: 4.0),
        boxShadow: const [
          BoxShadow(color: comicInk, offset: Offset(6, 6)),
        ],
      );
    }

    if (themeMode == AppThemeMode.aurora) {
      return BoxDecoration(
        color: const Color(0xFF020E0A),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: themeColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.1),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      );
    }

    if (themeMode == AppThemeMode.cosmic) {
      return BoxDecoration(
        color: const Color(0xFF05030E),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: themeColor.withOpacity(0.25), width: 1.2),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A061E),
            Color(0xFF03010A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      );
    }

    if (themeMode == AppThemeMode.holi) {
      return BoxDecoration(
        color: const Color(0xFF0E0308),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withOpacity(0.35), width: 1.5),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF140209),
            Color(0xFF0B0112),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFF007F).withOpacity(0.12),
            blurRadius: 18,
            spreadRadius: -1,
          ),
        ],
      );
    }

    return BoxDecoration(
      color: const Color(0xFF07070C),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: themeColor.withOpacity(0.12), width: 1.2),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0B0B12),
          Color(0xFF040407),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: themeColor.withOpacity(0.02),
          blurRadius: 24,
          spreadRadius: 2,
        ),
      ],
    );
  }

  // --- HYPER DOCK ---
  static BoxDecoration hyperDock({required BuildContext context, required AppThemeMode mode}) {
    if (mode == AppThemeMode.comic) {
      return BoxDecoration(
        color: comicPaper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: comicInk, width: 3),
        boxShadow: const [BoxShadow(color: comicInk, offset: Offset(4, 4))],
      );
    }
    final themeColor = getThemeColor(mode);
    return BoxDecoration(
      color: Colors.black.withOpacity(0.85),
      borderRadius: BorderRadius.circular(32),
      border: Border.all(color: themeColor.withOpacity(0.25), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: themeColor.withOpacity(0.08),
          blurRadius: 16,
          spreadRadius: 2,
        ),
      ],
    );
  }

  // --- BUTTONS ---
  static Widget themeButton({
    required BuildContext context,
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    bool isUrgent = false,
  }) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final color = getThemeColor(mode);

    if (mode == AppThemeMode.comic) {
      return GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: isUrgent ? comicRed : comicYellow,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: comicInk, width: 3),
            boxShadow: const [
              BoxShadow(
                color: comicInk,
                offset: Offset(4, 4),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, color: comicInk, size: 18), const SizedBox(width: 8)],
              Text(label, style: GoogleFonts.bangers(color: comicInk, fontSize: 18, letterSpacing: 1.5)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(mode == AppThemeMode.aurora ? 32 : 16),
        boxShadow: [
          BoxShadow(
            color: (isUrgent ? candyPink : color).withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
        label: Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            fontSize: 12,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isUrgent ? candyPink : Colors.black,
          foregroundColor: isUrgent ? Colors.white : color,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(mode == AppThemeMode.aurora ? 32 : 16),
            side: BorderSide(
              color: (isUrgent ? candyPink : color).withOpacity(0.4),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // --- LOGO ---
  static Widget logo({required BuildContext context, double size = 120, int seed = 0}) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: LogoPainter(mode: mode, seed: seed)),
    );
  }

  // --- INPUTS ---
  static InputDecoration themeInput({required BuildContext context, required String hint, IconData? icon}) {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final color = getThemeColor(mode);

    if (mode == AppThemeMode.comic) {
      return InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(color: comicInk.withOpacity(0.3)),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: icon != null ? Icon(icon, color: comicInk) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: comicInk, width: 2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: comicInk, width: 2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: comicInk, width: 4)),
      );
    }

    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
      filled: true,
      fillColor: Colors.black.withOpacity(0.4),
      prefixIcon: icon != null ? Icon(icon, color: color.withOpacity(0.6), size: 18) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color.withOpacity(0.15), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color.withOpacity(0.15), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: 1.5),
      ),
    );
  }

  static Color getThemeColor(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.cosmic: return const Color(0xFF00D4FF);
      case AppThemeMode.aurora: return spectralGreen;
      case AppThemeMode.comic: return comicYellow;
      case AppThemeMode.holi: return const Color(0xFFFF007F);
      default: return ghostOrange;
    }
  }
  static Widget responsiveWidth({required Widget child, double? maxWidth}) {
    if (maxWidth == null) {
      return SizedBox(
        width: double.infinity,
        child: child,
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
