import 'dart:convert';
import 'package:http/http.dart' as http;

class PhoneticService {
  /// Get phonetic transcription (IPA) for a word
  /// Now uses multiple strategies for better language coverage
  static Future<String?> getPhonetic(String word, String lang) async {
    try {
      // Only fetch for single words (no spaces, reasonable length)
      if (word.contains(' ') || word.length > 30 || word.trim().isEmpty) {
        return null;
      }

      final cleanWord = word.trim().toLowerCase();
      final langUpper = lang.toUpperCase();

      // Try multiple strategies in order
      String? result;

      // Strategy 1: Wiktionary REST API (best for most languages)
      result = await _getWiktionaryIPA(cleanWord, langUpper);
      if (result != null) return _formatTranscription(result);

      // Strategy 2: Free Dictionary API (good for English)
      if (langUpper == 'EN' || langUpper == 'EN-US' || langUpper == 'EN-GB') {
        result = await _getEnglishPhonetic(cleanWord);
        if (result != null) return _formatTranscription(result);
      }

      // Strategy 3: Wiktionary MediaWiki fallback
      result = await _getWiktionaryMediaWiki(cleanWord, langUpper);
      if (result != null) return _formatTranscription(result);

      return null;
    } catch (e) {
      // Fail silently - transcription is optional
      return null;
    }
  }

  /// Strategy 1: Wiktionary REST API (works for many languages)
  static Future<String?> _getWiktionaryIPA(String word, String langCode) async {
    try {
      final wikiLang = _getWiktionaryLangCode(langCode);
      if (wikiLang == null) return null;

      final response = await http
          .get(
            Uri.parse(
              'https://$wikiLang.wiktionary.org/api/rest_v1/page/html/${Uri.encodeComponent(word)}',
            ),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        // Parse HTML to find IPA
        final html = response.body;

        // Look for IPA patterns in the HTML
        final ipaPatterns = [
          RegExp(r'<span class="IPA">([^<]+)</span>', caseSensitive: false),
          RegExp(r'/([^/\s]{3,40})/', caseSensitive: false),
          RegExp(r'\[([^\]\s]{3,40})\]', caseSensitive: false),
        ];

        for (final pattern in ipaPatterns) {
          final match = pattern.firstMatch(html);
          if (match != null && match.groupCount > 0) {
            final ipa = match.group(1)?.trim();
            if (ipa != null && ipa.isNotEmpty && _isValidIPA(ipa)) {
              return ipa;
            }
          }
        }
      }
    } catch (e) {
      // Continue to next strategy
    }
    return null;
  }

  /// Strategy 2: Free Dictionary API (English only, high quality)
  static Future<String?> _getEnglishPhonetic(String word) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(word)}',
            ),
          )
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final phonetics = data[0]['phonetics'] as List?;
          if (phonetics != null && phonetics.isNotEmpty) {
            for (final phonetic in phonetics) {
              final text = phonetic['text'];
              if (text != null && text.toString().isNotEmpty) {
                return text.toString();
              }
            }
          }
        }
      }
    } catch (e) {
      // Continue to next strategy
    }
    return null;
  }

  /// Strategy 3: Wiktionary MediaWiki API (fallback)
  static Future<String?> _getWiktionaryMediaWiki(
    String word,
    String langCode,
  ) async {
    try {
      final wikiLang = _getWiktionaryLangCode(langCode);
      if (wikiLang == null) return null;

      final response = await http
          .get(
            Uri.parse(
              'https://$wikiLang.wiktionary.org/w/api.php?'
              'action=query&'
              'format=json&'
              'prop=revisions&'
              'titles=${Uri.encodeComponent(word)}&'
              'rvprop=content&'
              'rvslots=main',
            ),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final pages = data['query']?['pages'] as Map<String, dynamic>?;

        if (pages != null && pages.isNotEmpty) {
          final page = pages.values.first;
          final revisions = page['revisions'] as List?;

          if (revisions != null && revisions.isNotEmpty) {
            final content = revisions[0]['slots']?['main']?['*'] as String?;
            if (content != null) {
              return _extractIPAFromWikitext(content);
            }
          }
        }
      }
    } catch (e) {
      // Final fallback failed
    }
    return null;
  }

  /// Extract IPA from Wiktionary wiki markup
  static String? _extractIPAFromWikitext(String wikitext) {
    final patterns = [
      // Standard IPA template
      RegExp(r'\{\{IPA\|[^|]*\|([^}]+)\}\}', caseSensitive: false),
      RegExp(r'\{\{ipa\|([^}]+)\}\}', caseSensitive: false),
      // Parameter format
      RegExp(r'\|IPA\s*=\s*([^\n|]+)', caseSensitive: false),
      // Direct IPA notation
      RegExp(r'/([^/\n]{3,40})/', caseSensitive: false),
      RegExp(r'\[([^\]\n]{3,40})\]', caseSensitive: false),
      // Language-specific templates
      RegExp(r'\{\{pron\|([^}]+)\}\}', caseSensitive: false),
      RegExp(r'\{\{ääntäminen\|([^}]+)\}\}', caseSensitive: false), // Finnish
      RegExp(r'\{\{Lautschrift\|([^}]+)\}\}', caseSensitive: false), // German
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(wikitext);
      if (match != null && match.groupCount > 0) {
        var ipa = match.group(1)?.trim();
        if (ipa != null && ipa.isNotEmpty) {
          ipa = _cleanIPA(ipa);
          if (ipa.isNotEmpty && _isValidIPA(ipa)) {
            return ipa;
          }
        }
      }
    }

    return null;
  }

  /// Clean up IPA notation
  static String _cleanIPA(String ipa) {
    // Remove wiki markup
    ipa = ipa.replaceAll(RegExp(r'\[\[([^\]]+)\]\]'), r'\1');
    ipa = ipa.replaceAll(RegExp(r'\{\{([^}]+)\}\}'), '');
    ipa = ipa.replaceAll(RegExp(r'<[^>]+>'), '');

    // Remove language codes and parameters
    final parts = ipa.split('|');
    if (parts.length > 1) {
      ipa = parts.last;
    }

    // Clean whitespace
    ipa = ipa.trim();

    // Remove common prefixes
    ipa = ipa.replaceAll(
      RegExp(r'^(lang|en|de|fr|es|it|fi|ru|ja|ko|zh)[-:=]\s*'),
      '',
    );

    return ipa;
  }

  /// Validate that string looks like IPA
  static bool _isValidIPA(String text) {
    if (text.length < 2 || text.length > 50) return false;

    // Reject URLs
    if (text.contains('http') ||
        text.contains('www.') ||
        text.contains('.com')) {
      return false;
    }

    // Reject pure numbers/punctuation
    if (RegExp(r'^[\d\s\-.,;:]+$').hasMatch(text)) {
      return false;
    }

    // Check for IPA markers or characters
    final hasMarkers =
        (text.startsWith('/') && text.endsWith('/')) ||
        (text.startsWith('[') && text.endsWith(']'));

    final hasIPAChars = RegExp(
      r'[əɛɪʊʌɑɔæøœãẽĩõũɐɜɵɤɯɨʉʏɞɘɚɝɹɻɾɺɽʀʁʕʢʡʔˀˤʰʱʷʲˠˁⁿˡʼːˈˌ]',
    ).hasMatch(text);

    // Accept if has markers OR IPA characters
    return hasMarkers || hasIPAChars;
  }

  /// Format transcription for display
  static String _formatTranscription(String ipa) {
    // Ensure proper IPA markers
    if (!ipa.startsWith('/') && !ipa.startsWith('[')) {
      // Use slashes for phonemic, brackets for phonetic
      // Default to slashes
      return '/$ipa/';
    }
    return ipa;
  }

  /// Map language codes to Wiktionary domains
  static String? _getWiktionaryLangCode(String langCode) {
    const map = {
      'AR': 'ar',
      'BG': 'bg',
      'CS': 'cs',
      'DA': 'da',
      'DE': 'de',
      'EL': 'el',
      'EN': 'en',
      'ES': 'es',
      'ET': 'et',
      'FI': 'fi',
      'FR': 'fr',
      'HU': 'hu',
      'ID': 'id',
      'IT': 'it',
      'JA': 'ja',
      'KO': 'ko',
      'LT': 'lt',
      'LV': 'lv',
      'NB': 'no',
      'NL': 'nl',
      'PL': 'pl',
      'PT': 'pt',
      'RO': 'ro',
      'RU': 'ru',
      'SK': 'sk',
      'SL': 'sl',
      'SV': 'sv',
      'TR': 'tr',
      'UK': 'uk',
      'ZH': 'zh',
    };
    return map[langCode];
  }
}
