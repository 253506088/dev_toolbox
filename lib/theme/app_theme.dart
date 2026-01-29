import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dev_toolbox/constants/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        background: AppColors.background,
        onBackground: AppColors.text,
      ),

      // Background Color
      scaffoldBackgroundColor: AppColors.background,

      // Typography
      textTheme: GoogleFonts.fredokaTextTheme().apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),

      // Card Theme (Standard Cards)
      // For Neo-Brutalism, we prefer NeoBlock, but we style Cards just in case.
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 2.5),
        ),
        margin: const EdgeInsets.all(8),
      ),

      // Navigation Rail Theme
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

      // Button Themes
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

      // Input Decoration Theme
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

      // AppBar Theme
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
}
