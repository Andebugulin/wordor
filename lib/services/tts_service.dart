import 'package:flutter/services.dart';

class TtsService {
  static const MethodChannel _channel = MethodChannel('word_recall/tts');
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  static Future<void> speak(String text, String languageCode) async {
    try {
      final ttsLanguage = _mapLanguageCode(languageCode);
      await _channel.invokeMethod('speak', {
        'text': text,
        'language': ttsLanguage,
      });
    } catch (e) {
      // TTS not available, silently fail
      print('TTS error: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      // Ignore
    }
  }

  static String _mapLanguageCode(String deeplCode) {
    const languageMap = {
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
      'NB': 'nb',
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

    return languageMap[deeplCode] ?? 'en';
  }
}
