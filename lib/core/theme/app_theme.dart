import 'package:flutter/material.dart';

/// Centralized theme configuration for the Purpose app
/// Based on Graphite + Signal Blue design system
class AppTheme {
  // ========== PRIMARY COLORS ==========
  
  /// Primary action color - Signal Blue
  static const Color primary = Color(0xFF1E6BFF);
  
  /// Lighter accent blue for hover states and highlights
  static const Color primaryLight = Color(0xFF4D90FE);
  
  /// Darker primary for pressed states
  static const Color primaryDark = Color(0xFF0052D9);
  
  // ========== NEUTRAL COLORS ==========
  
  /// Dark graphite for headers and text
  static const Color graphite = Color(0xFF121417);
  
  /// Medium gray for secondary text
  static const Color grayMedium = Color(0xFF6B7280);
  
  /// Light gray for borders and dividers
  static const Color grayLight = Color(0xFFD1D5DB);
  
  // ========== BACKGROUND COLORS ==========
  
  /// Main app background - light gray
  static const Color background = Color(0xFFF5F5F7);
  
  /// Card and surface background - white
  static const Color surface = Color(0xFFFFFFFF);
  
  /// Dark background for dark theme
  static const Color backgroundDark = Color(0xFF0A0A0A);
  
  // ========== SEMANTIC COLORS ==========
  
  /// Success green
  static const Color success = Color(0xFF10B981);
  
  /// Warning amber
  static const Color warning = Color(0xFFF59E0B);
  
  /// Error red
  static const Color error = Color(0xFFEF4444);
  
  /// Info blue (same as primary)
  static const Color info = primary;
  
  // ========== TINTED BACKGROUNDS ==========
  
  /// Light primary tint for info boxes and highlights
  static const Color primaryTint = Color(0xFFE8F0FE);
  
  /// Very light primary tint for subtle backgrounds
  static const Color primaryTintLight = Color(0xFFF4F8FF);
  
  /// Success tint
  static const Color successTint = Color(0xFFD1FAE5);
  
  /// Warning tint
  static const Color warningTint = Color(0xFFFEF3C7);
  
  /// Error tint
  static const Color errorTint = Color(0xFFFEE2E2);
  
  // ========== GRADIENT COLORS ==========
  
  /// Primary gradient start (darker blue)
  static const Color gradientStart = Color(0xFF0052D9);
  
  /// Primary gradient end (Signal Blue)
  static const Color gradientEnd = Color(0xFF1E6BFF);
  
  /// Create primary gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // ========== TEXT STYLES ==========
  
  /// Heading 1 style
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: graphite,
  );
  
  /// Heading 2 style
  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: graphite,
  );
  
  /// Heading 3 style
  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: graphite,
  );
  
  /// Body text style
  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: graphite,
  );
  
  /// Secondary text style
  static const TextStyle bodySecondary = TextStyle(
    fontSize: 16,
    color: grayMedium,
  );
  
  /// Caption text style
  static const TextStyle caption = TextStyle(
    fontSize: 14,
    color: grayMedium,
  );
  
  // ========== SPACING ==========
  
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;
  
  // ========== BORDER RADIUS ==========
  
  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  static const double radiusFull = 999.0;
  
  // ========== THEME DATA ==========
  
  /// Get light theme configuration
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: primaryLight,
        surface: surface,
        background: background,
        error: error,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: graphite,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
    );
  }
  
  /// Get dark theme configuration
  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: primary,
        secondary: primaryLight,
        surface: graphite,
        background: backgroundDark,
        error: error,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: graphite,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: graphite,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
    );
  }
}
