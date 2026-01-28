import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  final String apiKey;
  static const String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  GeminiService(this.apiKey);

  /// Generate an example sentence in the source language using the word
  Future<String> generateExampleSentence({
    required String word,
    required String sourceLang,
  }) async {
    final langName = _getLanguageName(sourceLang);

    final prompt =
        '''Create a natural sentence in $langName using the word "$word".
           Please, output only the result sentence! Thank you! Don't output more than 8 words! If the result is more than 8 words, create another sentence that would be less 8 words''';

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {'temperature': 0.9, 'maxOutputTokens': 400},
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to generate sentence: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final text =
          data['candidates'][0]['content']['parts'][0]['text'] as String;

      return text.trim();
    } catch (e) {
      throw Exception('Error generating sentence: $e');
    }
  }

  /// Generate explanation in target language without revealing the word
  Future<String> generateExplanation({
    required String word,
    required String translation,
    required String targetLang,
  }) async {
    final langName = _getLanguageName(targetLang);

    final prompt =
        '''Describe what "$translation" means in $langName without using the word "$translation".
        If the word is inappropriate, output message "The word is inappropriate", otherwise output only the result sentence! Thank you! Don't output more than 8 words! If the result is more than 8 words, create another sentence that would be less 8 words''';

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {'temperature': 0.9, 'maxOutputTokens': 400},
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to generate explanation: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final text =
          data['candidates'][0]['content']['parts'][0]['text'] as String;

      return text.trim();
    } catch (e) {
      throw Exception('Error generating explanation: $e');
    }
  }

  /// Validate API key
  Future<Map<String, dynamic>> validateApiKey() async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'test'},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        return {'valid': true, 'message': 'API key is valid'};
      } else {
        return {
          'valid': false,
          'message': 'Status ${response.statusCode}: ${response.body}',
        };
      }
    } catch (e) {
      return {'valid': false, 'message': 'Error: $e'};
    }
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
