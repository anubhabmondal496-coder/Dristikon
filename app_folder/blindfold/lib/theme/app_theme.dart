import 'package:flutter/material.dart';

class AppTheme {
  // ============================================================
  // Tactile Clarity Light Mode Palette (WCAG AAA Compliant)
  // Minimalist, high-contrast, zero visual noise, large borders
  // ============================================================
  static const Color background = Color(0xFFF8FAFC);          // Crisp light slate canvas
  static const Color cardBackground = Color(0xFFFFFFFF);      // Pure white card
  static const Color cardBackgroundAlt = Color(0xFFF1F5F9);   // Surface container high
  static const Color cardBorder = Color(0xFF0F172A);          // 3px solid slate black border
  static const Color textPrimary = Color(0xFF0F172A);         // Pitch slate black typography
  static const Color textSecondary = Color(0xFF475569);       // Deep slate secondary
  
  // High-Visibility Tactical Accents
  static const Color accentAmber = Color(0xFFF59E0B);         // Warm tactile amber
  static const Color accentAmberLight = Color(0xFFFEF3C7);    // Amber background tint
  static const Color accentBlue = Color(0xFF0284C7);          // Ocean tactical blue
  static const Color accentBlueLight = Color(0xFFE0F2FE);     // Blue background tint
  static const Color alertCritical = Color(0xFFDC2626);       // High-visibility hazard red
  static const Color alertCriticalLight = Color(0xFFFEE2E2);  // Hazard red tint
  static const Color alertSafe = Color(0xFF16A34A);           // Safe path green

  // ============================================================
  // Shape-Aware Tactile Shadow & Border Helpers
  // Ensures shadows perfectly follow widget shapes (no rectangular artifacts)
  // ============================================================
  static BoxDecoration tactileCardDecoration({
    double radius = 22,
    Color backgroundColor = cardBackground,
    Color borderColor = cardBorder,
    double borderWidth = 3.0,
    double offsetY = 4.0,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: [
        BoxShadow(
          color: cardBorder,
          offset: Offset(0, offsetY),
          blurRadius: 0,
        ),
      ],
    );
  }

  static BoxDecoration tactileButtonDecoration({
    double radius = 16,
    Color backgroundColor = cardBackground,
    Color borderColor = cardBorder,
    double borderWidth = 2.5,
    double offsetY = 3.0,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: [
        BoxShadow(
          color: cardBorder,
          offset: Offset(0, offsetY),
          blurRadius: 0,
        ),
      ],
    );
  }

  static BoxDecoration tactileCircleDecoration({
    Color backgroundColor = cardBackground,
    Color borderColor = cardBorder,
    double borderWidth = 2.5,
    double offsetY = 3.0,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      shape: BoxShape.circle,
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: [
        BoxShadow(
          color: cardBorder,
          offset: Offset(0, offsetY),
          blurRadius: 0,
        ),
      ],
    );
  }

  static ThemeData get lightTactileTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: accentAmber,
      colorScheme: const ColorScheme.light(
        surface: cardBackground,
        primary: cardBorder,
        secondary: accentAmber,
        error: alertCritical,
        onSurface: textPrimary,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
