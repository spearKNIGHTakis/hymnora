import 'package:flutter/material.dart';

/// Blue, red, green and white inspired by the supplied colour reference.
class AppColors {
  static const navy = Color(0xFF2E3192);
  static const blue = Color(0xFF3C40AC);
  static const red = Color(0xFFD91F2A);
  static const accent = Color(0xFF147341);
  static const cream = Color(0xFFF8F9FD);
  static const card = Colors.white;
  static const text = Color(0xFF1B2440);
  static const textSoft = Color(0xFF59627A);
  static const border = Color(0xFFDDE0EE);
  static const highlight = Color(0xFFECECF9);
  static const redTint = Color(0xFFFDEDEF);
  static const greenTint = Color(0xFFE8F5ED);
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.cream,
    colorScheme: const ColorScheme.light(
      primary: AppColors.navy,
      onPrimary: Colors.white,
      primaryContainer: AppColors.highlight,
      onPrimaryContainer: AppColors.navy,
      secondary: AppColors.red,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.redTint,
      onSecondaryContainer: AppColors.text,
      tertiary: AppColors.accent,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.greenTint,
      onTertiaryContainer: AppColors.accent,
      error: Color(0xFFBA1A1A),
      surface: AppColors.card,
      onSurface: AppColors.text,
      outline: AppColors.textSoft,
      outlineVariant: AppColors.border,
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
      indicatorColor: AppColors.redTint,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.red
              : AppColors.textSoft,
        ),
      ),
    ),
  );
}
