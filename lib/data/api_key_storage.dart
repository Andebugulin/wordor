import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiKeyStorage {
  static const _storage = FlutterSecureStorage();
  static const _apiKeyKey = 'deepl_api_key';
  static const _geminiApiKeyKey = 'gemini_api_key';
  static const _huggingfaceApiKeyKey = 'huggingface_api_key';
  static const _huggingfaceModelKey = 'huggingface_model';

  // DeepL API Key methods
  Future<void> saveApiKey(String apiKey) async {
    await _storage.write(key: _apiKeyKey, value: apiKey);
  }

  Future<String?> getApiKey() async {
    return await _storage.read(key: _apiKeyKey);
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
    await _storage.write(key: _geminiApiKeyKey, value: apiKey);
  }

  Future<String?> getGeminiApiKey() async {
    return await _storage.read(key: _geminiApiKeyKey);
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
    await _storage.write(key: _huggingfaceApiKeyKey, value: apiKey);
  }

  Future<String?> getHuggingFaceApiKey() async {
    return await _storage.read(key: _huggingfaceApiKeyKey);
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
    await _storage.write(key: _huggingfaceModelKey, value: modelId);
  }

  Future<String?> getHuggingFaceModel() async {
    return await _storage.read(key: _huggingfaceModelKey);
  }

  Future<void> deleteHuggingFaceModel() async {
    await _storage.delete(key: _huggingfaceModelKey);
  }
}
