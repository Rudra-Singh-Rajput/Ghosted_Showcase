import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'utils/design_system.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/ghost_theme.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';

import 'services/cleanup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final prefs = await SharedPreferences.getInstance();
  final themeStr = prefs.getString('selected_theme');
  AppThemeMode initialTheme = AppThemeMode.ghosted;
  if (themeStr != null) {
    initialTheme = AppThemeMode.values.firstWhere(
      (e) => e.name == themeStr,
      orElse: () => AppThemeMode.ghosted,
    );
  }
  
  runApp(GhostedApp(initialTheme: initialTheme));
}

class GhostedApp extends StatefulWidget {
  final AppThemeMode initialTheme;
  const GhostedApp({super.key, this.initialTheme = AppThemeMode.ghosted});

  @override
  State<GhostedApp> createState() => _GhostedAppState();
}

class _GhostedAppState extends State<GhostedApp> {
  late AppThemeMode _currentTheme;

  @override
  void initState() {
    super.initState();
    _currentTheme = widget.initialTheme;
  }

  Future<void> _saveTheme(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_theme', mode.name);
  }

  @override
  Widget build(BuildContext context) {
    return GhostTheme(
      themeMode: _currentTheme,
      onThemeChanged: (mode) {
        setState(() => _currentTheme = mode);
        _saveTheme(mode);
      },
      child: MaterialApp(
        title: 'GHOSTED',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: DesignSystem.lightBackground,
          colorScheme: ColorScheme.light(
            primary: DesignSystem.ghostOrange,
            surface: DesignSystem.lightSurface,
          ),
          textTheme: GoogleFonts.interTextTheme(),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: DesignSystem.darkBackground,
          colorScheme: ColorScheme.dark(
            primary: DesignSystem.ghostOrange,
            surface: DesignSystem.darkSurface,
          ),
          textTheme: GoogleFonts.interTextTheme().apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
          scrollbarTheme: ScrollbarThemeData(
            thumbColor: WidgetStateProperty.all(DesignSystem.ghostOrange.withOpacity(0.2)),
            radius: const Radius.circular(10),
            thickness: WidgetStateProperty.all(6),
          ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: DesignSystem.ghostOrange,
            selectionColor: DesignSystem.ghostOrange,
            selectionHandleColor: DesignSystem.ghostOrange,
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
        routes: {
          '/login': (context) => LoginScreen(),
        },
      ),
    );
  }
}
