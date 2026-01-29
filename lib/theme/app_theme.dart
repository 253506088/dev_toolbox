import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dev_toolbox/constants/app_colors.dart';

class AppTheme {
  // Shared Color Scheme
  static final ColorScheme _colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    background: AppColors.background,
    onBackground: AppColors.text,
  );

  // Shared Text Theme
  static TextTheme get _textTheme => GoogleFonts.fredokaTextTheme().apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  );

  // --- Neo-Brutalism Theme (Hard Borders/Shadows) ---
  static ThemeData get neoTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _textTheme,

      // Card: Hard border, no default elevation (handled by NeoBlock or Manual)
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 2.5),
        ),
        margin: const EdgeInsets.all(8),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: AppColors.secondary,
        selectedIconTheme: const IconThemeData(color: Colors.white, size: 28),
        unselectedIconTheme: IconThemeData(
          color: AppColors.text.withValues(alpha: 0.6),
        ),
        selectedLabelTextStyle: GoogleFonts.fredoka(
          color: AppColors.text,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        unselectedLabelTextStyle: GoogleFonts.fredoka(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        groupAlignment: -1.0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cta,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border, width: 2.5),
          ),
          textStyle: GoogleFonts.fredoka(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 3),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: AppColors.text.withValues(alpha: 0.5)),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fredoka(
          color: AppColors.text,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
    );
  }

  // --- Standard Theme (Soft Shadows, No Borders) ---
  static ThemeData get standardTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      // Default Typography (No Fredoka, aligned base for interpolation)
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),

      // Card: Default Material Style
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0, // Flat by default in our layout
        margin: const EdgeInsets.all(8),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: AppColors.secondary.withValues(alpha: 0.2),
        selectedIconTheme: const IconThemeData(
          color: AppColors.primary,
          size: 28,
        ),
        unselectedIconTheme: IconThemeData(
          color: AppColors.text.withValues(alpha: 0.6),
        ),
        // Default font
        selectedLabelTextStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: AppColors.text.withValues(alpha: 0.8),
          fontSize: 13,
        ),
        groupAlignment: -1.0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, // Default Primary
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48), // Comfortable touch target
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        hintStyle: TextStyle(color: Colors.grey.shade500),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: AppColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
    );
  }
}
