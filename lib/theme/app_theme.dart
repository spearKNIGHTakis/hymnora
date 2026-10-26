import 'package:flutter/material.dart';

/// All our colours in one place, so we never type a hex code twice.
class AppColors {
  static const navy = Color(0xFF183B56);
  static const blue = Color(0xFF285F82);
  static const accent = Color(0xFF5B8FA8);
  static const cream = Color(0xFFFFF8E7);
  static const card = Color(0xFFF5EBD5);
  static const text = Color(0xFF203040);
  static const textSoft = Color(0xFF64748B);
  static const border = Color(0xFFE5D8BF);
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: const ColorScheme.light(
        primary: AppColors.navy,
        secondary: AppColors.blue,
        tertiary: AppColors.accent,
        surface: AppColors.cream,
        onPrimary: Colors.white,
        onSurface: AppColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerColor: AppColors.border,
            navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.accent.withValues(alpha: 0.35),
      ),
    );
  }
}