import 'dart:convert';
import 'package:http/http.dart' as http;

enum AIProvider { huggingface, gemini }

class AIHintService {
  final String apiKey;
  final AIProvider provider;

  static const String hfBaseUrl = 'https://router.huggingface.co/v1';
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  AIHintService(this.apiKey, this.provider);

  /// Generate an example sentence using the word
  Future<String> generateExample({
    required String word,
    required String sourceLang,
  }) async {
    final langName = _getLanguageName(sourceLang);

    final prompt = '''Create one natural sentence in $langName using "$word". 
Requirements:
- Maximum 8 words
- Natural and simple
- Only the sentence, no extra text''';

    return _callAI(prompt);
  }

  /// Generate explanation without revealing the word
  Future<String> generateExplanation({
    required String word,
    required String translation,
    required String targetLang,
  }) async {
    final langName = _getLanguageName(targetLang);

    final prompt =
        '''Describe "$translation" in $langName without using the word itself.
Requirements:
- Maximum 10 words
- Simple definition or synonym
- Only the description, no extra text''';

    return _callAI(prompt);
  }

  /// Validate API key
  Future<Map<String, dynamic>> validateApiKey() async {
    try {
      final result = await _callAI('test');
      return {'valid': true, 'message': 'API key is valid'};
    } catch (e) {
      return {'valid': false, 'message': e.toString()};
    }
  }

  Future<String> _callAI(String prompt) async {
    switch (provider) {
      case AIProvider.huggingface:
        return _callHuggingFace(prompt);
      case AIProvider.gemini:
        return _callGemini(prompt);
    }
  }

  Future<String> _callHuggingFace(String prompt) async {
    // Using Mistral-7B-Instruct - best for short, focused responses
    // Format: provider/model or just model for auto-provider selection
    const model = 'mistralai/Mistral-7B-Instruct-v0.2:featherless-ai';

    try {
      final response = await http.post(
        Uri.parse('$hfBaseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 50,
          'temperature': 0.7,
          'top_p': 0.9,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'HuggingFace API error: ${response.statusCode} - ${response.body}',
        );
      }

      final data = jsonDecode(response.body);

      // OpenAI-compatible response format
      if (data['choices'] != null && data['choices'].isNotEmpty) {
        final message = data['choices'][0]['message'];
        final text = message['content'] as String;
        return _cleanResponse(text);
      }

      throw Exception('Unexpected response format');
    } catch (e) {
      throw Exception('Error calling HuggingFace: $e');
    }
  }

  Future<String> _callGemini(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse(geminiBaseUrl),
        headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 100},
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Gemini API error: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final text =
          data['candidates'][0]['content']['parts'][0]['text'] as String;
      return _cleanResponse(text);
    } catch (e) {
      throw Exception('Error calling Gemini: $e');
    }
  }

  String _cleanResponse(String text) {
    // Remove common unwanted patterns
    return text
        .trim()
        .replaceAll(
          RegExp(r"^(Here's|Here is|Output:|Result:)\s*", caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'^"|"$'), '') // Remove surrounding quotes
        .trim();
  }

  String _getLanguageName(String code) {
    const names = {
      'AR': 'Arabic',
      'BG': 'Bulgarian',
      'CS': 'Czech',
      'DA': 'Danish',
      'DE': 'German',
      'EL': 'Greek',
      'EN': 'English',
      'ES': 'Spanish',
      'ET': 'Estonian',
      'FI': 'Finnish',
      'FR': 'French',
      'HU': 'Hungarian',
      'ID': 'Indonesian',
      'IT': 'Italian',
      'JA': 'Japanese',
      'KO': 'Korean',
      'LT': 'Lithuanian',
      'LV': 'Latvian',
      'NB': 'Norwegian',
      'NL': 'Dutch',
      'PL': 'Polish',
      'PT': 'Portuguese',
      'RO': 'Romanian',
      'RU': 'Russian',
      'SK': 'Slovak',
      'SL': 'Slovenian',
      'SV': 'Swedish',
      'TR': 'Turkish',
      'UK': 'Ukrainian',
      'ZH': 'Chinese',
    };
    return names[code] ?? 'English';
  }
}
