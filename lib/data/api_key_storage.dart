import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiKeyStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _apiKeyKey = 'deepl_api_key';
  static const _geminiApiKeyKey = 'gemini_api_key';
  static const _huggingfaceApiKeyKey = 'huggingface_api_key';
  static const _huggingfaceModelKey = 'huggingface_model';

  /// Safely read a key. On corruption (BadPaddingException), wipe all
  /// secure storage so the app can start fresh instead of crashing.
  static Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      if (e.toString().contains('BadPaddingException') ||
          e.toString().contains('PlatformException')) {
        // KeyStore corrupted — nuke everything so the app can boot
        await _storage.deleteAll();
        return null;
      }
      rethrow;
    }
  }

  /// Safely write a key. On corruption, wipe and retry once.
  static Future<void> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      if (e.toString().contains('BadPaddingException') ||
          e.toString().contains('PlatformException')) {
        await _storage.deleteAll();
        // Retry after clearing corrupted data
        await _storage.write(key: key, value: value);
      } else {
        rethrow;
      }
    }
  }

  // DeepL API Key methods
  Future<void> saveApiKey(String apiKey) async {
    await _safeWrite(_apiKeyKey, apiKey);
  }

  Future<String?> getApiKey() async {
    return await _safeRead(_apiKeyKey);
  }

  Future<void> deleteApiKey() async {
    await _storage.delete(key: _apiKeyKey);
  }

  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  // Gemini API Key methods
  Future<void> saveGeminiApiKey(String apiKey) async {
    await _safeWrite(_geminiApiKeyKey, apiKey);
  }

  Future<String?> getGeminiApiKey() async {
    return await _safeRead(_geminiApiKeyKey);
  }

  Future<void> deleteGeminiApiKey() async {
    await _storage.delete(key: _geminiApiKeyKey);
  }

  Future<bool> hasGeminiApiKey() async {
    final key = await getGeminiApiKey();
    return key != null && key.isNotEmpty;
  }

  // HuggingFace API Key methods
  Future<void> saveHuggingFaceApiKey(String apiKey) async {
    await _safeWrite(_huggingfaceApiKeyKey, apiKey);
  }

  Future<String?> getHuggingFaceApiKey() async {
    return await _safeRead(_huggingfaceApiKeyKey);
  }

  Future<void> deleteHuggingFaceApiKey() async {
    await _storage.delete(key: _huggingfaceApiKeyKey);
  }

  Future<bool> hasHuggingFaceApiKey() async {
    final key = await getHuggingFaceApiKey();
    return key != null && key.isNotEmpty;
  }

  // HuggingFace Model preference methods
  Future<void> saveHuggingFaceModel(String modelId) async {
    await _safeWrite(_huggingfaceModelKey, modelId);
  }

  Future<String?> getHuggingFaceModel() async {
    return await _safeRead(_huggingfaceModelKey);
  }

  Future<void> deleteHuggingFaceModel() async {
    await _storage.delete(key: _huggingfaceModelKey);
  }
}
