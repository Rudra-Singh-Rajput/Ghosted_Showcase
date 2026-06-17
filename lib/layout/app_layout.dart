import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:ui' as ui; // For ImageFilter
import '../screens/swipe_deck_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/yearbook_screen.dart';
import '../screens/activity_screen.dart'; 
import '../screens/settings_screen.dart';
import '../screens/happy_watch_screen.dart';
import '../screens/hauwa_confession_screen.dart';
import '../screens/group_chat_screen.dart'; // Import GroupChatScreen
import '../widgets/logo_painter.dart';
import '../widgets/particle_background.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/ghost_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../screens/direct_chat_screen.dart';
import '../screens/chat_inbox_screen.dart';
import '../services/limit_service.dart';
import '../widgets/aurora_background.dart';
import '../widgets/comic_background.dart';
import '../widgets/holi_background.dart';
import '../services/cleanup_service.dart';
import '../widgets/ghost_tour_guide.dart';
import '../services/auth_service.dart';
import '../utils/design_system.dart';
import '../services/resonance_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/ghost_animation.dart';
import '../widgets/ghoul_icon.dart';
import '../widgets/floating_ghost.dart';
import '../widgets/dynamic_backdrop.dart';
import '../widgets/ghost_theme.dart';
import '../widgets/hauwa_icon.dart';

class AppLayout extends StatefulWidget {
  const AppLayout({super.key});

  static void navigateTo(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_AppLayoutState>();
    state?.animateToPage(index);
  }

  static void openDrawer(BuildContext context) {
    final state = context.findAncestorStateOfType<_AppLayoutState>();
    state?._scaffoldKey.currentState?.openDrawer();
  }

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isAuthorized = false;
  int _versionTapCount = 0;
  bool _ghostMode = false;
  bool _showTour = false; // Local state for tour stability

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(
      'meme-video-iframe',
      (int viewId) => html.IFrameElement()
        ..src = 'https://www.youtube.com/embed/J---aiyznGQ?autoplay=1'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%',
    );
    _checkAuthorization();
    LimitService.checkAndResetDailyLimits();
    ResonanceService.updateStreak();
    _startGlobalDowntimeClock();
  }

  Future<void> _checkAuthorization() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final email = user.email?.trim().toLowerCase();
    if (mounted) {
      setState(() {
        _isAuthorized = AuthService.isAuthorized(email);
      });
      // Run cleanup services
      CleanupService.pruneExpiredContent().catchError((e) => print("Cleanup Error in AppLayout: $e"));
      CleanupService.resetSeanceDaily().catchError((e) => print("Seance Reset Error in AppLayout: $e"));
    }
  }

  bool _isGlobalDowntime = false;
  Timer? _globalDowntimeTimer; 

  void _startGlobalDowntimeClock() {
    _checkGlobalDowntime();
    _globalDowntimeTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) _checkGlobalDowntime();
    });
  }

  void _checkGlobalDowntime() {
    final now = DateTime.now();
    if (now.hour == 23 && now.minute >= 50) {
      if (!_isGlobalDowntime) {
        setState(() => _isGlobalDowntime = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text("THE VEIL IS DISSOLVING. THE VOID RESETS AT 00:00.", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
              duration: const Duration(seconds: 10),
            ),
          );
        });
      }
    } else if (_isGlobalDowntime) {
      setState(() => _isGlobalDowntime = false);
    }
    
    // Check for first login to show tour
    _initTour();
  }

  Future<void> _initTour() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && (doc.data() as Map<String, dynamic>?)?['isFirstLogin'] == true) {
      if (mounted) setState(() => _showTour = true);
    }
  }

  List<Widget> get _pages => [
    const HappyWatchScreen(),
    const YearbookScreen(),
    const SizedBox.shrink(), // Placeholder for Manifest action
    const SwipeDeckScreen(),
    const ChatInboxScreen(),
  ];

  void _onPageChanged(int index) {
     setState(() {
        _currentIndex = index;
     });
  }

  void animateToPage(int index) {
     if (index == 2) return; // Don't animate to the placeholder
     _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic
     );
  }

  void _onNavTapped(int index) async {
    HapticFeedback.lightImpact();
    if (index == 2) {
      _showCentralMenu();
      return;
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    animateToPage(index);
  }

  void _showCentralMenu() {
    final parentContext = context;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "CentralMenu",
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (dialogContext, anim1, anim2) {
        return _buildCentralMenuOverlay(dialogContext, parentContext);
      },
      transitionBuilder: (dialogContext, anim1, anim2, child) {
        final slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic));
        final fade = Tween<double>(begin: 0.0, end: 1.0)
            .animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildCentralMenuOverlay(BuildContext dialogContext, BuildContext parentContext) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.4),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const GhoulIcon(size: 80, color: Color(0xFFFF8000))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 1.seconds),
                const SizedBox(height: 20),
                Text(
                  "HAUWA",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "CHOOSE YOUR CONCURRENCY WITH THE VOID",
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildPortalChoice(
                        iconWidget: const Icon(LucideIcons.messageSquare, color: Color(0xFFFF8000), size: 28),
                        title: "OPEN CHAT",
                        subtitle: "Enter university global chat",
                        color: const Color(0xFFFF8000),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          Navigator.push(
                            parentContext,
                            MaterialPageRoute(
                              builder: (_) => const GroupChatScreen(
                                chatId: 'global_void_chat',
                                groupName: 'THE VOID CHAT',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildPortalChoice(
                        iconWidget: const HauwaIcon(size: 28, color: Color(0xFFFFB300)),
                        title: "CONFESSIONS",
                        subtitle: "Speak anonymous secrets",
                        color: const Color(0xFFFFB300),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          Navigator.push(
                            parentContext,
                            PageRouteBuilder(
                              pageBuilder: (c, a, b) => const HauwaConfessionScreen(),
                              transitionsBuilder: (c, a, b, child) {
                                return SlideTransition(
                                  position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
                                      .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                                  child: FadeTransition(opacity: a, child: child),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, color: Colors.white54, size: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortalChoice({
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: iconWidget,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 9, height: 1.3),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack);
  }

  void _playMemeVideo() {
    // Left empty since it was replaced by direct chat
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux;
    final theme = GhostTheme.of(context);
    final mode = theme?.themeMode ?? AppThemeMode.ghosted;

    return Scaffold(
        key: _scaffoldKey,
        backgroundColor: mode == AppThemeMode.ghosted ? Colors.black : (mode == AppThemeMode.comic ? DesignSystem.comicPaper : Colors.black),
        drawer: _buildDrawer(mode),
        body: Stack(
          children: [
            _buildThemeBackground(mode),
            // SlimeOverlay removed as per user request for subtle Cartoon theme

            // --- MAIN CONTENT ---
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.only(bottom: 100), // Protect content from dock
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: PageView(
                  controller: _pageController,
                  physics: isDesktop ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                  onPageChanged: _onPageChanged,
                  children: _pages,
                ),
              ),
            ),


            // --- SPECTRAL DOCK (BOTTOM NAV) ---
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  height: 84,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Main Bar
                      Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: DesignSystem.hyperDock(context: context, mode: mode),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNavIcon(LucideIcons.tv, 0, "HAPPY WATCH", mode),
                            _buildNavIcon(LucideIcons.archive, 1, "ARCHIVE", mode),
                            const SizedBox(width: 60), // Space for Manifest button
                            _buildNavIcon(LucideIcons.zap, 3, "SEANCE", mode),
                            _buildNavIcon(LucideIcons.messageSquare, 4, "INBOX", mode),
                          ],
                        ),
                      ),
                      
                      // Central Manifest Button
                      Positioned(
                        top: 0,
                        child: _buildManifestButton(mode),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
              ),
            ),

            // Floating Ghost removed as per user request (was colliding/too bright)


            // Ghost Tour Overlay (Magic Navigation)
            if (_showTour)
              Positioned.fill(
                child: GhostTourGuide(
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  onCloseDrawer: () => Navigator.pop(context),
                  onStepChanged: (index) {
                    setState(() => _currentIndex = index);
                    _pageController.animateToPage(index, duration: 500.ms, curve: Curves.easeInOutCubic);
                  },
                  onComplete: () {
                    setState(() => _showTour = false);
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      FirebaseFirestore.instance.collection('users').doc(uid).update({'isFirstLogin': false});
                    }
                  },
                ),
              ),
          ],
        ),
    );
  }

  Widget _buildDrawer(AppThemeMode mode) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Use hard current user as fallback if stream is taking its time
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;
        final email = user?.email?.trim().toLowerCase();
        final bool hardcodedAuth = AuthService.isAuthorized(email);



        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid ?? 'NON_EXISTENT').snapshots(),
          builder: (context, userDocSnap) {
            final userData = userDocSnap.data?.data() as Map<String, dynamic>?;
            final bool isDbAdmin = userData?['isAdmin'] ?? false;
            final bool isDbSubMod = userData?['role'] == 'sub-mod';
            final bool isAuthorized = hardcodedAuth || isDbAdmin || isDbSubMod;
            
            // Failsafe for Sub-Mod specifically if Firestore is laggy but hardcoded exists
            final bool showAdmin = isAuthorized || AuthService.isSubMod(email);

            return Drawer(
              backgroundColor: const Color(0xFF0A0A0A),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                      decoration: const BoxDecoration(color: Colors.black),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _cycleTheme,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getThemeColor(mode).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _getThemeColor(mode).withOpacity(0.3)),
                              ),
                              child: Text(
                                mode.name.toUpperCase(),
                                style: GoogleFonts.outfit(color: _getThemeColor(mode), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                              ),
                            ),
                          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds),
                          if (email != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              email,
                              style: GoogleFonts.inconsolata(color: Colors.white24, fontSize: 10),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: DesignSystem.glass(context: context, opacity: 0.1, radius: 20),
                              child: Column(
                                children: [
                                   Row(
                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                     children: [
                                       Text(
                                        "LEVEL ${userData?['level'] ?? 1}",
                                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        (userData?['spectralTitle'] ?? "PHANTOM").toString().toUpperCase(),
                                        style: GoogleFonts.outfit(color: DesignSystem.ghostOrange, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2),
                                      ),
                                     ],
                                   ),
                                  const SizedBox(height: 12),
                                  // XP Progress Bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: ((userData?['resonance'] ?? 0) % 100) / 100.0,
                                      backgroundColor: Colors.white10,
                                      color: DesignSystem.ghostOrange,
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(LucideIcons.flame, color: Colors.redAccent, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        "${userData?['streak'] ?? 0} DAY STREAK",
                                        style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                                      ),
                                    ],
                                  ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white10, indent: 24, endIndent: 24),
                    const SizedBox(height: 12),
                    _buildDrawerItem(
                      LucideIcons.bookOpen,
                      "RULES",
                      "University void conduct guidelines",
                      () {
                        Navigator.pop(context);
                        _showRulesDialog();
                      },
                    ),
                    _buildDrawerItem(
                      LucideIcons.lock,
                      "CHANGE PASSWORD",
                      "Update your spectral key",
                      () => _showChangePasswordDialog(),
                    ),
                    _buildDrawerItem(
                      LucideIcons.logOut,
                      "LEAVE THE VOID",
                      "Sever your connection",
                      () async {
                        await FirebaseAuth.instance.signOut();
                        if (mounted) Navigator.pushReplacementNamed(context, '/login');
                      },
                    ),
              const Divider(color: Colors.white10, indent: 24, endIndent: 24),
              _buildRitualTimer(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _versionTapCount++);
                    if (_versionTapCount >= 5) {
                      setState(() {
                        _ghostMode = !_ghostMode;
                        _versionTapCount = 0;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_ghostMode ? "GHOST MODE ACTIVATED" : "GHOST MODE DEACTIVATED", 
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          backgroundColor: DesignSystem.voidMagenta,
                        ),
                      );
                    }
                  },
                  child: Text(
                    "V3.5.0-GHOSTED",
                    style: GoogleFonts.inconsolata(
                      color: _ghostMode ? DesignSystem.voidMagenta : Colors.white.withOpacity(0.02), 
                      fontSize: 8, 
                      letterSpacing: 2
                    ),
                  ),
                ),
              ),
                ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: const Color(0xFFFF8700), size: 20),
      title: Text(
        title,
        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index, String label, AppThemeMode mode) {
    final isSelected = _currentIndex == index;
    final themeColor = DesignSystem.getThemeColor(mode);
    final color = isSelected 
        ? themeColor 
        : (mode == AppThemeMode.comic ? Colors.black54 : Colors.white.withOpacity(0.4));
    
    return GestureDetector(
      onTap: () => _onNavTapped(index),
      child: Container(
        width: 75,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, 
              color: color, 
              size: isSelected ? 24 : 22,
            ).animate(target: isSelected ? 1 : 0)
             .scale(begin: const Offset(1,1), end: const Offset(1.1, 1.1), curve: Curves.easeOutBack)
             .shimmer(duration: 3.seconds, color: themeColor.withOpacity(0.2)),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: DesignSystem.sub(
                color: color, 
                size: 7, 
                weight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 2,
                width: 12,
                decoration: BoxDecoration(
                  color: themeColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(color: themeColor.withOpacity(0.5), blurRadius: 4),
                  ],
                ),
              ).animate().scaleX(begin: 0, end: 1, duration: 200.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildManifestButton(AppThemeMode mode) {
    final themeColor = DesignSystem.getThemeColor(mode);
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => _onNavTapped(2),
        child: Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            color: themeColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: themeColor.withOpacity(0.4),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
            gradient: LinearGradient(
              colors: [themeColor, themeColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(12.0),
            child: GhoulIcon(size: 32, color: Colors.black),
          ),
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true))
       .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 2.seconds, curve: Curves.easeInOut),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onNavTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFFFF8700) : Colors.white.withOpacity(0.65),
          size: 28,
        ),
      ),
    );
  }

  Future<void> _resetRitual() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F0F),
        title: Text("RE-MANIFEST?", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text("This will reset your onboarding and manifestation status. You will need to join the Archives again.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("RESET", style: TextStyle(color: Color(0xFFFF8700)))),
        ],
      ),
    );
    
    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'isFirstLogin': true,
        'joinedArchives': false,
      });
      if (mounted) {
        Navigator.pop(context); // Close drawer
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("RITUAL RESET. LOG IN AGAIN TO BEGIN.")));
        FirebaseAuth.instance.signOut();
      }
    }
  }



  void _showChangePasswordDialog() {
    Navigator.pop(context);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F0F),
        title: Text("UPDATE SPECTRAL KEY", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your new password below.", style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "New Password",
                hintStyle: const TextStyle(color: Colors.white12),
                filled: true,
                fillColor: Colors.white.withOpacity(0.02),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () async {
              final newPass = controller.text.trim();
              if (newPass.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PASSWORD TOO WEAK (MIN 6 CHARS)")));
                return;
              }
              try {
                await FirebaseAuth.instance.currentUser?.updatePassword(newPass);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("KEY UPDATED."), backgroundColor: Color(0xFF00FF88)));
                }
              } catch (e) {
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("RE-AUTH REQUIRED: Log out and back in to change password."), backgroundColor: Colors.redAccent));
                }
              }
            }, 
            child: const Text("UPDATE", style: TextStyle(color: Color(0xFFFF8700)))
          ),
        ],
      ),
    );
  }

  void _showRulesDialog() {
    final mode = GhostTheme.of(context)?.themeMode ?? AppThemeMode.ghosted;
    final isComic = mode == AppThemeMode.comic;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isComic ? DesignSystem.comicPaper : const Color(0xFF0F0F0F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isComic ? 4 : 24),
          side: BorderSide(
            color: isComic ? DesignSystem.comicInk : Colors.white10,
            width: isComic ? 3 : 1,
          ),
        ),
        title: Text(
          "VOID CONDUCT RULES",
          style: isComic 
              ? GoogleFonts.bangers(color: DesignSystem.comicInk, fontSize: 24, letterSpacing: 1.5)
              : GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRuleRow("1. ANONYMITY IS SACRED", "Do not post real names, phone numbers, or personal identifier data of other students.", isComic),
              const SizedBox(height: 12),
              _buildRuleRow("2. NO TARGETED HARASSMENT", "Whispering is fine, but targeted bullying, hate speech, or public defamation will lead to a soul ban.", isComic),
              const SizedBox(height: 12),
              _buildRuleRow("3. KEEP IT CLEAN", "Pornographic content, explicit violence, or illegal activities are strictly banished.", isComic),
              const SizedBox(height: 12),
              _buildRuleRow("4. BE AN ACTIVE SPIRIT", "Contribute genuinely. Spamming the chat deck or botting responses disrupts connection resonance.", isComic),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "UNDERSTOOD",
              style: isComic
                  ? GoogleFonts.bangers(color: DesignSystem.comicInk, fontSize: 18)
                  : const TextStyle(color: Color(0xFFFF8700), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleRow(String title, String desc, bool isComic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: isComic
              ? GoogleFonts.comicNeue(fontWeight: FontWeight.bold, fontSize: 13, color: DesignSystem.comicInk)
              : GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFFFF8700), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          desc,
          style: isComic
              ? GoogleFonts.comicNeue(fontSize: 12, color: Colors.black87)
              : GoogleFonts.inter(color: Colors.white70, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }
  
  Widget _buildRitualTimer() {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final tomorrow = DateTime(now.year, now.month, now.day + 1);
        final diff = tomorrow.difference(now);
        
        final h = diff.inHours.toString().padLeft(2, '0');
        final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final s = (diff.inSeconds % 60).toString().padLeft(2, '0');

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.moon, color: Color(0xFF00FF88), size: 14),
                  const SizedBox(width: 8),
                  Text(
                    "MIDNIGHT RITUAL",
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "$h:$m:$s",
                style: GoogleFonts.inconsolata(color: const Color(0xFF00FF88), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
              const SizedBox(height: 8),
              Text(
                "UNTIL VOID PURGE",
                style: GoogleFonts.outfit(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeBackground(AppThemeMode mode) {
    return Stack(
      children: [
        DynamicBackdrop(mode: mode),
        if (mode == AppThemeMode.cosmic)
          const ParticleBackground(mode: AppThemeMode.cosmic),
        if (mode == AppThemeMode.aurora || mode == AppThemeMode.ghosted)
          AuroraBackground(mode: mode),
        if (mode == AppThemeMode.comic)
          const ComicBackground(),
        if (mode == AppThemeMode.holi)
          const HoliBackground(),
        if (mode == AppThemeMode.ghosted)
          const ParticleBackground(mode: AppThemeMode.ghosted),
        if (mode == AppThemeMode.ghosted && _ghostMode)
          const ColorFiltered(
            colorFilter: ColorFilter.mode(DesignSystem.voidMagenta, BlendMode.hue),
            child: ParticleBackground(mode: AppThemeMode.ghosted),
          ),
        
      ],
    );
  }

  void _cycleTheme() {
    final theme = GhostTheme.of(context);
    final currentMode = theme?.themeMode ?? AppThemeMode.ghosted;
    final nextMode = AppThemeMode.values[(currentMode.index + 1) % AppThemeMode.values.length];
    
    theme?.onThemeChanged(nextMode);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("THEME: ${nextMode.name.toUpperCase()}", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: DesignSystem.getThemeColor(nextMode),
        duration: const Duration(milliseconds: 1000),
      ),
    );
  }

  void _showGuideDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F0F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white10)),
        title: Text("VOID GUIDE", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: DesignSystem.ghostOrange, letterSpacing: 2)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGuideSection(LucideIcons.sparkles, "THE SANCTUARY", "An anonymous sanctuary to whisper secrets. Confessions float through the void, heard but never traced. Speak your truth without fear."),
              const SizedBox(height: 16),
              _buildGuideSection(LucideIcons.ghost, "THE VOID", "The main board for anonymous text whispers. Every whisper is ephemeral and will fade over time unless sustained by echoes (likes) and replies."),
              const SizedBox(height: 16),
              _buildGuideSection(LucideIcons.bookOpen, "THE VAULT", "A sanctuary for knowledge. Here you can find and share University notes across different departments."),
              const SizedBox(height: 16),
              _buildGuideSection(LucideIcons.zap, "SEANCE", "Manifest direct connections with other spirits. Swipe through active souls and start a conversation."),
              const SizedBox(height: 16),
              _buildGuideSection(LucideIcons.archive, "THE ARCHIVE", "Preserve your whispers and explore the echoes of the past. A vault for eternalized essence."),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _startGhostTour();
                  },
                  icon: const Icon(LucideIcons.navigation, size: 16),
                  label: const Text("EXPLORE IN DETAIL"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignSystem.ghostOrange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("I UNDERSTAND", style: GoogleFonts.outfit(color: DesignSystem.ghostOrange, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _startGhostTour() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      pageBuilder: (context, anim1, anim2) => GhostTourGuide(
        onComplete: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildGuideSection(IconData icon, String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: DesignSystem.ghostOrange, size: 18),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 4),
        Text(description, style: GoogleFonts.inter(color: Colors.white60, fontSize: 12, height: 1.4)),
      ],
    );
  }

  Color _getThemeColor(AppThemeMode mode) {
    return DesignSystem.getThemeColor(mode);
  }
}

class _SlimeOverlay extends StatelessWidget {
  const _SlimeOverlay();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(4, (index) => _SlimeDrop(index: index)),
    );
  }
}

class _SlimeDrop extends StatelessWidget {
  final int index;
  const _SlimeDrop({required this.index});

  @override
  Widget build(BuildContext context) {
    final Random random = Random(index);
    return Positioned(
      top: -20,
      left: 40.0 + (index * 100),
      child: Container(
        width: 40.0 + random.nextDouble() * 40.0,
        height: 100.0 + random.nextDouble() * 200.0,
        decoration: BoxDecoration(
          color: DesignSystem.slimeGreen,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), offset: const Offset(4, 4)),
          ],
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true))
       .slideY(begin: -0.8, end: 0, duration: (3 + random.nextInt(3)).seconds, curve: Curves.easeInOutSine),
    );
  }
}


class _ComicActionLines extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ActionLinesPainter(),
      size: Size.infinite,
    );
  }
}

class ActionLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DesignSystem.comicInk.withOpacity(0.03)
      ..strokeWidth = 1.5;
    
    final center = Offset(size.width / 2, size.height / 2);
    final random = Random(42);
    
    for (int i = 0; i < 40; i++) {
      final double angle = (i * pi / 20) + (random.nextDouble() * 0.1);
      final double length = size.longestSide;
      canvas.drawLine(
        center,
        center + Offset(cos(angle) * length, sin(angle) * length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
