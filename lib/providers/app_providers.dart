import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import '../data/deepl_service.dart';
import '../services/gemini_service.dart';
import '../data/api_key_storage.dart';

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

// DeepL service provider
final deepLServiceProvider = Provider<DeepLService?>((ref) {
  final apiKeyAsync = ref.watch(apiKeyProvider);

  return apiKeyAsync.when(
    data: (apiKey) => apiKey != null ? DeepLService(apiKey) : null,
    loading: () => null,
    error: (_, __) => null,
  );
});

// Gemini service provider
final geminiServiceProvider = Provider<GeminiService?>((ref) {
  final apiKeyAsync = ref.watch(geminiApiKeyProvider);

  return apiKeyAsync.when(
    data: (apiKey) => apiKey != null ? GeminiService(apiKey) : null,
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
