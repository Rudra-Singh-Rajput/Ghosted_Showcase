import 'package:flutter/material.dart';
import '../utils/design_system.dart';

class GhostTheme extends InheritedWidget {
  final AppThemeMode themeMode;
  final Function(AppThemeMode) onThemeChanged;

  const GhostTheme({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required super.child,
  });

  static GhostTheme? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GhostTheme>();
  }

  @override
  bool updateShouldNotify(GhostTheme oldWidget) {
    return oldWidget.themeMode != themeMode;
  }
}
