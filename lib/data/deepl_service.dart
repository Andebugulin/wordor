import 'dart:convert';
import 'package:http/http.dart' as http;

class DeepLService {
  final String apiKey;
  static const String baseUrl = 'https://api-free.deepl.com/v2';

  DeepLService(this.apiKey);

  Future<TranslationResult> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/translate'),
      headers: {
        'Authorization': 'DeepL-Auth-Key $apiKey',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'text': text,
        'source_lang': sourceLang.toUpperCase(),
        'target_lang': targetLang.toUpperCase(),
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Translation failed: ${response.body}');
    }

    final data = json.decode(response.body);
    final translation = data['translations'][0]['text'] as String;

    return TranslationResult(
      original: text,
      translation: translation,
      sourceLang: sourceLang,
      targetLang: targetLang,
    );
  }

  Future<String> generateExample({
    required String word,
    required String targetLang,
  }) async {
    // Simple example: translate a generic sentence
    // In production, you might use an LLM API for better examples
    final examplePrompt = 'Use "$word" in a simple sentence.';

    final response = await translate(
      text: examplePrompt,
      sourceLang: 'EN',
      targetLang: targetLang,
    );

    return response.translation;
  }

  Future<bool> validateApiKey() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/translate'),
        headers: {
          'Authorization': 'DeepL-Auth-Key $apiKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'text': 'test', 'target_lang': 'EN'},
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}

class TranslationResult {
  final String original;
  final String translation;
  final String sourceLang;
  final String targetLang;

  TranslationResult({
    required this.original,
    required this.translation,
    required this.sourceLang,
    required this.targetLang,
  });
}
