import 'package:flutter/material.dart';

class AppTheme {
  // Modern minimal dark palette inspired by Nord and Catppuccin
  // Primary: Soft blue-purple for focus and interaction
  static const _primaryColor = Color(0xFF7C94FF);
  static const _primaryDark = Color(0xFF5A75E8);

  // Accent: Complementary purple for highlights
  static const _accentColor = Color(0xFFA78BFA);

  // Backgrounds: Deep, rich blacks with subtle variations
  static const _backgroundColor = Color(0xFF0D0D12);
  static const _surfaceColor = Color(0xFF18181F);
  static const _surfaceElevated = Color(0xFF242430);

  // Text: High contrast whites with subtle grays
  static const _textPrimary = Color(0xFFF8F8FB);
  static const _textSecondary = Color(0xFFA1A1B0);
  static const _textTertiary = Color(0xFF6E6E80);

  // Semantic colors
  static const _successColor = Color(0xFF4ADEAA);
  static const _warningColor = Color(0xFFFFB86C);
  static const _errorColor = Color(0xFFFF6B7A);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _backgroundColor,

      colorScheme: const ColorScheme.dark(
        primary: _primaryColor,
        secondary: _accentColor,
        surface: _surfaceColor,
        error: _errorColor,
        onPrimary: Color(0xFF000000),
        onSurface: _textPrimary,
        onSurfaceVariant: _textSecondary,
      ),

      // Card theme - clean elevated surface
      cardTheme: CardThemeData(
        color: _surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // AppBar - transparent, minimal
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
      ),

      // Typography - modern, legible
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.w800,
          color: _textPrimary,
          letterSpacing: -1.5,
          height: 1.1,
        ),
        displayMedium: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
          letterSpacing: -1,
          height: 1.2,
        ),
        displaySmall: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
          letterSpacing: -0.8,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _textPrimary,
          letterSpacing: -0.2,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: _textPrimary,
          height: 1.6,
          letterSpacing: 0,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: _textSecondary,
          height: 1.6,
          letterSpacing: 0,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: _textTertiary,
          height: 1.5,
        ),
      ),

      // Input fields - clean and focused
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2A2A38), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _errorColor, width: 2),
        ),
        labelStyle: const TextStyle(
          color: _textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: _textTertiary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Elevated buttons - primary action
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: const Color(0xFF000000),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // Outlined buttons - secondary action
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _textPrimary,
          side: const BorderSide(color: Color(0xFF2A2A38), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Navigation bar - subtle and clean
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceColor,
        elevation: 0,
        height: 68,
        indicatorColor: _primaryColor.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _primaryColor,
              letterSpacing: 0.3,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _textTertiary,
            letterSpacing: 0.3,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _primaryColor, size: 26);
          }
          return const IconThemeData(color: _textTertiary, size: 26);
        }),
      ),

      // Dialogs - elevated surface
      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceElevated,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
          letterSpacing: -0.5,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: _textSecondary,
          height: 1.6,
        ),
      ),

      // Dividers - subtle separation
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A38),
        thickness: 1,
        space: 1,
      ),

      // Icon theme
      iconTheme: const IconThemeData(color: _textSecondary, size: 24),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _surfaceElevated,
        contentTextStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _primaryColor,
        linearTrackColor: Color(0xFF2A2A38),
      ),
    );
  }

  // Custom colors for specific use cases
  static const successColor = _successColor;
  static const warningColor = _warningColor;
  static const errorColor = _errorColor;
  static const surfaceVariant = _surfaceElevated;
  static const surfaceColor = _surfaceColor;

  // Additional utility colors
  static const borderColor = Color(0xFF2A2A38);
  static const dividerColor = Color(0xFF2A2A38);
}
