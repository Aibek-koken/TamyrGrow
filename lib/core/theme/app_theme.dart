import 'package:flutter/material.dart';

class AppTheme {
  static const Color _emerald = Color(0xFF00E676);
  static const Color _bg = Color(0xFF0B0F14);
  static const Color _surface = Color(0xFF121826);
  static const Color _surface2 = Color(0xFF151D2D);

  static ThemeData darkTech(TextTheme textTheme) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _emerald,
      brightness: Brightness.dark,
      primary: _emerald,
      surface: _surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _bg,
      textTheme: textTheme.apply(
        bodyColor: Colors.white.withValues(alpha: 0.92),
        displayColor: Colors.white.withValues(alpha: 0.92),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: _surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _surface2,
        selectedItemColor: _emerald,
        unselectedItemColor: Colors.white.withValues(alpha: 0.65),
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surface2,
        selectedColor: _emerald.withValues(alpha: 0.18),
        labelStyle: textTheme.labelMedium ?? const TextStyle(),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        shape: const StadiumBorder(),
      ),
      dividerColor: Colors.white.withValues(alpha: 0.10),
    );
  }
}

