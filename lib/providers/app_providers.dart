import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database.dart';
import '../data/deepl_service.dart';
import '../services/ai_hint_service.dart';
import '../services/theme_settings.dart';
import '../data/api_key_storage.dart';
import '../theme.dart';

// Database provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// API key storage provider
final apiKeyStorageProvider = Provider<ApiKeyStorage>((ref) {
  return ApiKeyStorage();
});

// DeepL API key state provider
final apiKeyProvider = FutureProvider<String?>((ref) async {
  final storage = ref.watch(apiKeyStorageProvider);
  return await storage.getApiKey();
});

// Gemini API key state provider
final geminiApiKeyProvider = FutureProvider<String?>((ref) async {
  final storage = ref.watch(apiKeyStorageProvider);
  return await storage.getGeminiApiKey();
});

// HuggingFace API key state provider
final huggingfaceApiKeyProvider = FutureProvider<String?>((ref) async {
  final storage = ref.watch(apiKeyStorageProvider);
  return await storage.getHuggingFaceApiKey();
});

// HuggingFace model preference provider
final huggingfaceModelProvider = FutureProvider<String?>((ref) async {
  final storage = ref.watch(apiKeyStorageProvider);
  return await storage.getHuggingFaceModel();
});

// AI provider preference
final aiProviderPreferenceProvider = FutureProvider<AIProvider>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final providerName = prefs.getString('ai_provider') ?? 'huggingface';
  return providerName == 'gemini' ? AIProvider.gemini : AIProvider.huggingface;
});

// FIX: Provider that checks if the CURRENTLY SELECTED AI provider has a key
final currentAIProviderHasKeyProvider = FutureProvider<bool>((ref) async {
  // Get the currently selected provider
  final provider = await ref.watch(aiProviderPreferenceProvider.future);
  final storage = ref.watch(apiKeyStorageProvider);

  if (provider == AIProvider.huggingface) {
    final key = await storage.getHuggingFaceApiKey();
    return key != null && key.isNotEmpty;
  } else {
    final key = await storage.getGeminiApiKey();
    return key != null && key.isNotEmpty;
  }
});

// DeepL service provider
final deepLServiceProvider = Provider<DeepLService?>((ref) {
  final apiKeyAsync = ref.watch(apiKeyProvider);
  return apiKeyAsync.when(
    data: (apiKey) => apiKey != null ? DeepLService(apiKey) : null,
    loading: () => null,
    error: (_, __) => null,
  );
});

// AI hint service provider (unified with custom model support)
final aiHintServiceProvider = Provider<AIHintService?>((ref) {
  final provider = ref.watch(aiProviderPreferenceProvider);

  return provider.when(
    data: (aiProvider) {
      if (aiProvider == AIProvider.huggingface) {
        final apiKeyAsync = ref.watch(huggingfaceApiKeyProvider);
        final modelAsync = ref.watch(huggingfaceModelProvider);

        return apiKeyAsync.when(
          data: (apiKey) {
            if (apiKey == null) return null;
            return modelAsync.when(
              data: (model) => AIHintService(
                apiKey,
                AIProvider.huggingface,
                customModel: model,
              ),
              loading: () => AIHintService(apiKey, AIProvider.huggingface),
              error: (_, __) => AIHintService(apiKey, AIProvider.huggingface),
            );
          },
          loading: () => null,
          error: (_, __) => null,
        );
      } else {
        final apiKeyAsync = ref.watch(geminiApiKeyProvider);
        return apiKeyAsync.when(
          data: (apiKey) =>
              apiKey != null ? AIHintService(apiKey, AIProvider.gemini) : null,
          loading: () => null,
          error: (_, __) => null,
        );
      }
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// Due words provider
final dueWordsProvider = FutureProvider<List<WordWithRecall>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getDueWords();
});

// Due word count provider
final dueWordCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getDueWordCount();
});

// ============================================================
// THEME PROVIDERS
// ============================================================

// Theme mode provider
final themeModeProvider = FutureProvider<ThemeMode>((ref) async {
  final settings = ThemeSettings();
  return await settings.getThemeMode();
});

// Dark theme colors provider
final darkThemeColorsProvider = FutureProvider<Map<String, Color>>((ref) async {
  final settings = ThemeSettings();
  return await settings.loadAllColors(true);
});

// Light theme colors provider
final lightThemeColorsProvider = FutureProvider<Map<String, Color>>((
  ref,
) async {
  final settings = ThemeSettings();
  return await settings.loadAllColors(false);
});

// Dark theme provider
final darkThemeProvider = Provider<AppTheme>((ref) {
  final colorsAsync = ref.watch(darkThemeColorsProvider);

  return colorsAsync.when(
    data: (colors) => AppTheme(
      primaryColor: colors['primary']!,
      accentColor: colors['accent']!,
      backgroundColor: colors['background']!,
      surfaceColor: colors['surface']!,
      successColor: colors['success']!,
      warningColor: colors['warning']!,
      errorColor: colors['error']!,
      isDark: true,
    ),
    loading: () => AppTheme(
      primaryColor: ThemeSettings.defaultDarkPrimary,
      accentColor: ThemeSettings.defaultDarkAccent,
      backgroundColor: ThemeSettings.defaultDarkBackground,
      surfaceColor: ThemeSettings.defaultDarkSurface,
      successColor: ThemeSettings.defaultDarkSuccess,
      warningColor: ThemeSettings.defaultDarkWarning,
      errorColor: ThemeSettings.defaultDarkError,
      isDark: true,
    ),
    error: (_, __) => AppTheme(
      primaryColor: ThemeSettings.defaultDarkPrimary,
      accentColor: ThemeSettings.defaultDarkAccent,
      backgroundColor: ThemeSettings.defaultDarkBackground,
      surfaceColor: ThemeSettings.defaultDarkSurface,
      successColor: ThemeSettings.defaultDarkSuccess,
      warningColor: ThemeSettings.defaultDarkWarning,
      errorColor: ThemeSettings.defaultDarkError,
      isDark: true,
    ),
  );
});

// Light theme provider
final lightThemeProvider = Provider<AppTheme>((ref) {
  final colorsAsync = ref.watch(lightThemeColorsProvider);

  return colorsAsync.when(
    data: (colors) => AppTheme(
      primaryColor: colors['primary']!,
      accentColor: colors['accent']!,
      backgroundColor: colors['background']!,
      surfaceColor: colors['surface']!,
      successColor: colors['success']!,
      warningColor: colors['warning']!,
      errorColor: colors['error']!,
      isDark: false,
    ),
    loading: () => AppTheme(
      primaryColor: ThemeSettings.defaultLightPrimary,
      accentColor: ThemeSettings.defaultLightAccent,
      backgroundColor: ThemeSettings.defaultLightBackground,
      surfaceColor: ThemeSettings.defaultLightSurface,
      successColor: ThemeSettings.defaultLightSuccess,
      warningColor: ThemeSettings.defaultLightWarning,
      errorColor: ThemeSettings.defaultLightError,
      isDark: false,
    ),
    error: (_, __) => AppTheme(
      primaryColor: ThemeSettings.defaultLightPrimary,
      accentColor: ThemeSettings.defaultLightAccent,
      backgroundColor: ThemeSettings.defaultLightBackground,
      surfaceColor: ThemeSettings.defaultLightSurface,
      successColor: ThemeSettings.defaultLightSuccess,
      warningColor: ThemeSettings.defaultLightWarning,
      errorColor: ThemeSettings.defaultLightError,
      isDark: false,
    ),
  );
});
