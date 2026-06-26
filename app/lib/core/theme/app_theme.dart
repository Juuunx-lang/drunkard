import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  static const _fontFallback = <String>[
    'Microsoft YaHei',
    'PingFang SC',
    'Heiti SC',
    'SimHei',
    'Arial Unicode MS',
  ];

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamilyFallback: _fontFallback,
      scaffoldBackgroundColor: BarColors.background,
      primaryColor: BarColors.neonPink,
      colorScheme: const ColorScheme.dark(
        primary: BarColors.neonPink,
        secondary: BarColors.neonBlue,
        surface: BarColors.surface,
        error: BarColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: BarColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          fontFamilyFallback: _fontFallback,
        ),
      ),
      cardTheme: CardThemeData(
        color: BarColors.surface.withValues(alpha: 0.8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: BarColors.glassBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BarColors.neonPink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BarColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BarColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BarColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BarColors.neonBlue, width: 2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: BarColors.surface,
        selectedItemColor: BarColors.neonPink,
        unselectedItemColor: BarColors.textSecondary,
      ),
    );
  }
}
