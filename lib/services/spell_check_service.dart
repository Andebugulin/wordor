import 'dart:convert';
import 'package:http/http.dart' as http;

class SpellCheckService {
  // Cache to avoid repeated API calls for the same text
  static final Map<String, SpellCheckResult> _cache = {};
  static const int _maxCacheSize = 50;

  /// Check if language is supported for spell checking
  static bool isLanguageSupported(String langCode) {
    final converted = _convertLangCode(langCode);
    return converted != 'en-US' || langCode.toUpperCase() == 'EN';
  }

  /// Check spelling using LanguageTool API (free tier)
  /// Returns suggestions if spelling errors are found
  static Future<SpellCheckResult> checkSpelling(
    String text,
    String langCode,
  ) async {
    try {
      // Don't check very short or very long text
      if (text.trim().length < 2 || text.length > 500) {
        return SpellCheckResult(hasErrors: false);
      }

      // Check cache first
      final cacheKey = '$langCode:$text';
      if (_cache.containsKey(cacheKey)) {
        return _cache[cacheKey]!;
      }

      // Check if language is supported
      final languageCode = _convertLangCode(langCode);
      if (!isLanguageSupported(langCode)) {
        return SpellCheckResult(hasErrors: false, isLanguageSupported: false);
      }

      final response = await http
          .post(
            Uri.parse('https://api.languagetool.org/v2/check'),
            body: {
              'text': text,
              'language': languageCode,
              'enabledOnly': 'false',
            },
          )
          .timeout(const Duration(seconds: 2)); // Faster timeout

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final matches = data['matches'] as List;

        if (matches.isEmpty) {
          final result = SpellCheckResult(
            hasErrors: false,
            isLanguageSupported: true,
          );
          _cacheResult(cacheKey, result);
          return result;
        }

        // Get spelling/typo errors (filter out style suggestions)
        final spellingErrors = matches.where((match) {
          final issueType = match['rule']?['issueType'] as String?;
          final categoryId = match['rule']?['category']?['id'] as String?;
          return issueType == 'misspelling' ||
              issueType == 'typographical' ||
              categoryId == 'TYPOS';
        }).toList();

        if (spellingErrors.isEmpty) {
          final result = SpellCheckResult(
            hasErrors: false,
            isLanguageSupported: true,
          );
          _cacheResult(cacheKey, result);
          return result;
        }

        // Get first spelling error
        final firstMatch = spellingErrors[0];
        final replacements = firstMatch['replacements'] as List? ?? [];
        final offset = firstMatch['offset'] as int? ?? 0;
        final length = firstMatch['length'] as int? ?? 0;

        final result = SpellCheckResult(
          hasErrors: true,
          isLanguageSupported: true,
          originalText: text,
          suggestions: replacements
              .take(3)
              .map((r) => r['value'] as String)
              .where((s) => s.isNotEmpty)
              .toList(),
          message:
              firstMatch['message'] as String? ?? 'Possible spelling error',
          offset: offset,
          length: length,
        );

        _cacheResult(cacheKey, result);
        return result;
      }
    } catch (e) {
      // Fail silently - spell check is optional
    }

    return SpellCheckResult(hasErrors: false, isLanguageSupported: true);
  }

  /// Cache result with size limit
  static void _cacheResult(String key, SpellCheckResult result) {
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entry
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = result;
  }

  /// Clear cache
  static void clearCache() {
    _cache.clear();
  }

  /// Convert app language codes to LanguageTool format
  static String _convertLangCode(String code) {
    const map = {
      'AR': 'ar',
      'BG': 'bg-BG',
      'CS': 'cs-CZ',
      'DA': 'da-DK',
      'DE': 'de-DE',
      'EL': 'el-GR',
      'EN': 'en-US',
      'ES': 'es',
      'FR': 'fr',
      'IT': 'it',
      'JA': 'ja-JP',
      'LT': 'lt-LT',
      'NB': 'no',
      'NL': 'nl',
      'PL': 'pl-PL',
      'PT': 'pt',
      'RO': 'ro-RO',
      'RU': 'ru-RU',
      'SK': 'sk-SK',
      'SL': 'sl-SI',
      'SV': 'sv',
      'UK': 'uk-UA',
      'ZH': 'zh-CN',
      // Unsupported languages default to English
      'ET': 'en-US',
      'FI': 'en-US',
      'HU': 'en-US',
      'ID': 'en-US',
      'KO': 'en-US',
      'LV': 'en-US',
      'TR': 'en-US',
    };
    return map[code.toUpperCase()] ?? 'en-US';
  }
}

class SpellCheckResult {
  final bool hasErrors;
  final bool isLanguageSupported;
  final String? originalText;
  final List<String> suggestions;
  final String? message;
  final int offset;
  final int length;

  SpellCheckResult({
    required this.hasErrors,
    this.isLanguageSupported = true,
    this.originalText,
    this.suggestions = const [],
    this.message,
    this.offset = 0,
    this.length = 0,
  });

  /// Apply a suggestion by replacing only the misspelled word
  String applySuggestion(String suggestion) {
    if (originalText == null || !hasErrors) {
      return suggestion;
    }

    // Replace only the specific misspelled portion
    final before = originalText!.substring(0, offset);
    final after = originalText!.substring(offset + length);
    return before + suggestion + after;
  }
}
