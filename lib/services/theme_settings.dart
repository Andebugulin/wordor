import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeSettings {
  static const String _themeKey = 'app_theme_mode';
  static const String _primaryColorKey = 'primary_color';
  static const String _accentColorKey = 'accent_color';
  static const String _backgroundColorKey = 'background_color';
  static const String _surfaceColorKey = 'surface_color';
  static const String _successColorKey = 'success_color';
  static const String _warningColorKey = 'warning_color';
  static const String _errorColorKey = 'error_color';

  // ── Cherry Blossom Dark ──────────────────────────────────────────
  static const Color defaultDarkPrimary = Color(0xFFF472B6); // sakura pink
  static const Color defaultDarkAccent = Color(0xFFEC4899); // deeper rose
  static const Color defaultDarkBackground = Color(0xFF120A0F); // dark cherry
  static const Color defaultDarkSurface = Color(0xFF1F141C); // dark rose
  static const Color defaultDarkSuccess = Color(0xFF4ADE80); // green
  static const Color defaultDarkWarning = Color(0xFFFBBF24); // warm gold
  static const Color defaultDarkError = Color(0xFFFDA4AF); // soft rose red

  // ── Cherry Blossom Light ─────────────────────────────────────────
  static const Color defaultLightPrimary = Color(0xFFEC4899); // pink
  static const Color defaultLightAccent = Color(0xFFF472B6); // lighter pink
  static const Color defaultLightBackground = Color(0xFFFFF1F2); // blush white
  static const Color defaultLightSurface = Color(0xFFFFFFFF); // white
  static const Color defaultLightSuccess = Color(0xFF4ADE80); // green
  static const Color defaultLightWarning = Color(0xFFFBBF24); // amber
  static const Color defaultLightError = Color(0xFFFDA4AF); // rose red

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.toString());
  }

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString(_themeKey);
    if (modeString == null) return ThemeMode.dark;

    switch (modeString) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.dark;
    }
  }

  Future<void> saveColor(String key, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, color.value);
  }

  Future<Color?> getColor(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(key);
    return colorValue != null ? Color(colorValue) : null;
  }

  // Save all colors at once
  Future<void> saveAllColors({
    required bool isDark,
    required Color primary,
    required Color accent,
    required Color background,
    required Color surface,
    required Color success,
    required Color warning,
    required Color error,
  }) async {
    final prefix = isDark ? 'dark_' : 'light_';
    await saveColor('${prefix}$_primaryColorKey', primary);
    await saveColor('${prefix}$_accentColorKey', accent);
    await saveColor('${prefix}$_backgroundColorKey', background);
    await saveColor('${prefix}$_surfaceColorKey', surface);
    await saveColor('${prefix}$_successColorKey', success);
    await saveColor('${prefix}$_warningColorKey', warning);
    await saveColor('${prefix}$_errorColorKey', error);
  }

  // Load all colors for a theme
  Future<Map<String, Color>> loadAllColors(bool isDark) async {
    final prefix = isDark ? 'dark_' : 'light_';

    // Get defaults based on theme
    final defaults = isDark
        ? {
            'primary': defaultDarkPrimary,
            'accent': defaultDarkAccent,
            'background': defaultDarkBackground,
            'surface': defaultDarkSurface,
            'success': defaultDarkSuccess,
            'warning': defaultDarkWarning,
            'error': defaultDarkError,
          }
        : {
            'primary': defaultLightPrimary,
            'accent': defaultLightAccent,
            'background': defaultLightBackground,
            'surface': defaultLightSurface,
            'success': defaultLightSuccess,
            'warning': defaultLightWarning,
            'error': defaultLightError,
          };

    return {
      'primary':
          await getColor('${prefix}$_primaryColorKey') ?? defaults['primary']!,
      'accent':
          await getColor('${prefix}$_accentColorKey') ?? defaults['accent']!,
      'background':
          await getColor('${prefix}$_backgroundColorKey') ??
          defaults['background']!,
      'surface':
          await getColor('${prefix}$_surfaceColorKey') ?? defaults['surface']!,
      'success':
          await getColor('${prefix}$_successColorKey') ?? defaults['success']!,
      'warning':
          await getColor('${prefix}$_warningColorKey') ?? defaults['warning']!,
      'error': await getColor('${prefix}$_errorColorKey') ?? defaults['error']!,
    };
  }

  // Reset to defaults
  Future<void> resetToDefaults(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = isDark ? 'dark_' : 'light_';

    await prefs.remove('${prefix}$_primaryColorKey');
    await prefs.remove('${prefix}$_accentColorKey');
    await prefs.remove('${prefix}$_backgroundColorKey');
    await prefs.remove('${prefix}$_surfaceColorKey');
    await prefs.remove('${prefix}$_successColorKey');
    await prefs.remove('${prefix}$_warningColorKey');
    await prefs.remove('${prefix}$_errorColorKey');
  }
}
