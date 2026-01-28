import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../data/database.dart';
import '../data/deepl_service.dart';
import '../providers/app_providers.dart';
import '../services/tts_service.dart';
import 'language_picker.dart';

class TranslateScreen extends ConsumerStatefulWidget {
  const TranslateScreen({super.key});

  @override
  ConsumerState<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends ConsumerState<TranslateScreen> {
  final _controller = TextEditingController();
  final _speech = stt.SpeechToText();

  List<String> _recentLanguages = ['FI', 'EN', 'DE'];
  String _sourceLang = 'FI';
  String _targetLang = 'EN';

  TranslationResult? _result;
  bool _isTranslating = false;
  String? _error;
  bool _isListening = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultLanguages();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();

      if (status.isGranted) {
        _speechAvailable = await _speech.initialize(
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
            }
          },
          onError: (error) {
            setState(() => _isListening = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Speech error: ${error.errorMsg}'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              );
            }
          },
        );
      } else {
        _speechAvailable = false;
      }
    } catch (e) {
      _speechAvailable = false;
      debugPrint('Speech initialization error: $e');
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Microphone permission required'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
      return;
    }

    setState(() => _isListening = true);

    final localeId = _getLocaleId(_sourceLang);

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
        });

        // Auto-translate when user stops speaking
        if (result.finalResult && _controller.text.isNotEmpty) {
          _translate();
        }
      },
      localeId: localeId,
      listenMode: stt.ListenMode.confirmation,
      cancelOnError: true,
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  String _getLocaleId(String langCode) {
    const localeMap = {
      'AR': 'ar_SA',
      'BG': 'bg_BG',
      'CS': 'cs_CZ',
      'DA': 'da_DK',
      'DE': 'de_DE',
      'EL': 'el_GR',
      'EN': 'en_US',
      'ES': 'es_ES',
      'ET': 'et_EE',
      'FI': 'fi_FI',
      'FR': 'fr_FR',
      'HU': 'hu_HU',
      'ID': 'id_ID',
      'IT': 'it_IT',
      'JA': 'ja_JP',
      'KO': 'ko_KR',
      'LT': 'lt_LT',
      'LV': 'lv_LV',
      'NB': 'nb_NO',
      'NL': 'nl_NL',
      'PL': 'pl_PL',
      'PT': 'pt_PT',
      'RO': 'ro_RO',
      'RU': 'ru_RU',
      'SK': 'sk_SK',
      'SL': 'sl_SI',
      'SV': 'sv_SE',
      'TR': 'tr_TR',
      'UK': 'uk_UA',
      'ZH': 'zh_CN',
    };
    return localeMap[langCode] ?? 'en_US';
  }

  Future<void> _loadDefaultLanguages() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sourceLang = prefs.getString('default_source_lang') ?? 'FI';
      _targetLang = prefs.getString('default_target_lang') ?? 'EN';
      final recent =
          prefs.getStringList('recent_languages') ?? ['FI', 'EN', 'DE'];
      _recentLanguages = recent;
    });
  }

  Future<void> _saveDefaultLanguages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_source_lang', _sourceLang);
    await prefs.setString('default_target_lang', _targetLang);
    await prefs.setStringList('recent_languages', _recentLanguages);
  }

  @override
  void dispose() {
    _controller.dispose();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _translate() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final service = ref.read(deepLServiceProvider);
    if (service == null) return;

    setState(() {
      _isTranslating = true;
      _error = null;
    });

    try {
      final result = await service.translate(
        text: text,
        sourceLang: _sourceLang,
        targetLang: _targetLang,
      );

      if (!mounted) return;

      setState(() {
        _result = result;
        _error = null;
      });

      // Add to history
      try {
        final db = ref.read(databaseProvider);
        await db.addToHistory(
          TranslationHistoryCompanion.insert(
            source: result.original,
            translation: result.translation,
            sourceLang: result.sourceLang,
            targetLang: result.targetLang,
          ),
        );
      } catch (e) {
        debugPrint('Failed to save to history: $e');
      }

      _updateRecentLanguages(_sourceLang);
      _updateRecentLanguages(_targetLang);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Translation failed';
        _result = null;
      });
      debugPrint('Translation error: $e');
    } finally {
      if (mounted) {
        setState(() => _isTranslating = false);
      }
    }
  }

  void _updateRecentLanguages(String lang) {
    setState(() {
      _recentLanguages.remove(lang);
      _recentLanguages.insert(0, lang);
      if (_recentLanguages.length > 6) {
        _recentLanguages = _recentLanguages.take(6).toList();
      }
    });
    _saveDefaultLanguages();
  }

  Future<void> _saveWord() async {
    if (_result == null) return;

    final db = ref.read(databaseProvider);

    await db.addWord(
      WordsCompanion.insert(
        source: _result!.original,
        translation: _result!.translation,
        sourceLang: _result!.sourceLang,
        targetLang: _result!.targetLang,
      ),
    );

    // Mark in history as saved
    try {
      final historyItems = await db.translationHistory.select()
        ..where(
          (t) =>
              t.source.equals(_result!.original) &
              t.translation.equals(_result!.translation),
        )
        ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)])
        ..limit(1);

      final item = await historyItems.getSingleOrNull();
      if (item != null) {
        await (db.update(db.translationHistory)
              ..where((t) => t.id.equals(item.id)))
            .write(TranslationHistoryCompanion(saved: drift.Value(true)));
      }
    } catch (e) {
      debugPrint('Failed to mark as saved: $e');
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Saved for recall'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );

    ref.invalidate(dueWordCountProvider);

    setState(() {
      _result = null;
      _controller.clear();
    });
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
    });
    _saveDefaultLanguages();
  }

  Future<void> _pickLanguage(bool isSource) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => LanguagePicker(
          selectedLanguage: isSource ? _sourceLang : _targetLang,
          recentLanguages: _recentLanguages,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (isSource) {
          _sourceLang = result;
        } else {
          _targetLang = result;
        }
      });
      _updateRecentLanguages(result);
    }
  }

  void _showHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TranslationHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Translate',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  IconButton(
                    onPressed: _showHistory,
                    icon: const Icon(Icons.history),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _LanguageButton(
                            language: _sourceLang,
                            onTap: () => _pickLanguage(true),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: IconButton(
                            onPressed: _swapLanguages,
                            icon: const Icon(Icons.swap_horiz, size: 28),
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surface,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _LanguageButton(
                            language: _targetLang,
                            onTap: () => _pickLanguage(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Text field with voice input button
                    Stack(
                      children: [
                        TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Enter text or tap mic to speak',
                            errorText: _error,
                            contentPadding: const EdgeInsets.only(
                              left: 20,
                              right: 60,
                              top: 20,
                              bottom: 20,
                            ),
                          ),
                          maxLines: 4,
                          onSubmitted: (_) => _translate(),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: IconButton(
                            onPressed: _isListening
                                ? _stopListening
                                : _startListening,
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: _isListening
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: _isListening
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.error.withOpacity(0.1)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.1),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_isListening) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.mic,
                              color: Theme.of(context).colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Listening... Speak now',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            TextButton(
                              onPressed: _stopListening,
                              child: const Text('Stop'),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: _isTranslating ? null : _translate,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      child: _isTranslating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Translate'),
                    ),

                    if (_result != null) ...[
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _result!.translation,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => TtsService.speak(
                                    _result!.translation,
                                    _result!.targetLang,
                                  ),
                                  icon: const Icon(Icons.volume_up),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.1),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () => TtsService.speak(
                                _result!.original,
                                _result!.sourceLang,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 4,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.volume_up_outlined,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _result!.original,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Remember this word?',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        setState(() => _result = null),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 56),
                                    ),
                                    child: const Text('Skip'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _saveWord,
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(0, 56),
                                    ),
                                    child: const Text('Save'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  final String language;
  final VoidCallback onTap;

  const _LanguageButton({required this.language, required this.onTap});

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
    return names[code] ?? code;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _getLanguageName(language),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_drop_down,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// Translation History Screen remains the same as before
class TranslationHistoryScreen extends ConsumerStatefulWidget {
  const TranslationHistoryScreen({super.key});

  @override
  ConsumerState<TranslationHistoryScreen> createState() =>
      _TranslationHistoryScreenState();
}

class _TranslationHistoryScreenState
    extends ConsumerState<TranslationHistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear History?'),
                  content: const Text(
                    'This will remove all translation history.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                await db.clearHistory();
                setState(() {});
              }
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search history',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<TranslationHistoryData>>(
              future: db.getHistory(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                var history = snapshot.data ?? [];

                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  history = history.where((item) {
                    return item.source.toLowerCase().contains(query) ||
                        item.translation.toLowerCase().contains(query);
                  }).toList();
                }

                if (history.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.history
                              : Icons.search_off,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No translation history'
                              : 'No results found',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: history.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${item.sourceLang} → ${item.targetLang}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                              const Spacer(),
                              if (item.saved)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.bookmark,
                                        size: 14,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Saved',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete from history?'),
                                      content: Text('Remove "${item.source}"?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    await (db.delete(
                                      db.translationHistory,
                                    )..where((t) => t.id.equals(item.id))).go();
                                    setState(() {});
                                  }
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.source,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.translation,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
