import 'package:flutter/material.dart';

class AppTheme {
  // Theme colors - will be customizable
  final Color primaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color successColor;
  final Color warningColor;
  final Color errorColor;

  // Text colors - derived from theme mode
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final bool isDark;

  AppTheme({
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.successColor,
    required this.warningColor,
    required this.errorColor,
    required this.isDark,
  }) : textPrimary = isDark ? const Color(0xFFF8F8FB) : const Color(0xFF1A1A1A),
       textSecondary = isDark
           ? const Color(0xFFA1A1B0)
           : const Color(0xFF6B7280),
       textTertiary = isDark
           ? const Color(0xFF6E6E80)
           : const Color(0xFF9CA3AF);

  ThemeData get themeData {
    final primaryDark = Color.lerp(primaryColor, Colors.black, 0.2)!;
    final surfaceElevated = isDark
        ? Color.lerp(surfaceColor, Colors.white, 0.05)!
        : Color.lerp(surfaceColor, Colors.black, 0.02)!;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: backgroundColor,

      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
        onSecondary: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
        onSurface: textPrimary,
        onError: const Color(0xFFFFFFFF),
        onSurfaceVariant: textSecondary,
      ),

      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),

      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -1.5,
          height: 1.1,
        ),
        displayMedium: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -1,
          height: 1.2,
        ),
        displaySmall: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.8,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          height: 1.6,
          letterSpacing: 0,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.6,
          letterSpacing: 0,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textTertiary,
          height: 1.5,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
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
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2A2A38) : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: errorColor, width: 2),
        ),
        labelStyle: TextStyle(
          color: textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: textTertiary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: isDark
              ? const Color(0xFF000000)
              : const Color(0xFFFFFFFF),
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

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(
            color: isDark ? const Color(0xFF2A2A38) : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
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

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        elevation: 0,
        height: 68,
        indicatorColor: primaryColor.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: primaryColor,
              letterSpacing: 0.3,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textTertiary,
            letterSpacing: 0.3,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primaryColor, size: 26);
          }
          return IconThemeData(color: textTertiary, size: 26);
        }),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        contentTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.6,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF2A2A38) : const Color(0xFFE5E7EB),
        thickness: 1,
        space: 1,
      ),

      iconTheme: IconThemeData(color: textSecondary, size: 24),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: isDark
            ? const Color(0xFF2A2A38)
            : const Color(0xFFE5E7EB),
      ),
    );
  }

  // Additional utility colors for direct access
  Color get borderColor =>
      isDark ? const Color(0xFF2A2A38) : const Color(0xFFE5E7EB);
  Color get dividerColor =>
      isDark ? const Color(0xFF2A2A38) : const Color(0xFFE5E7EB);
}
