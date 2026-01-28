import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import '../providers/app_providers.dart';
import '../services/tts_service.dart';
import '../theme.dart';
import 'word_library_screen.dart';

class RecallScreen extends ConsumerStatefulWidget {
  const RecallScreen({super.key});

  @override
  ConsumerState<RecallScreen> createState() => _RecallScreenState();
}

class _RecallScreenState extends ConsumerState<RecallScreen> {
  int _currentIndex = 0;
  int _hintLevel = 0;
  int _totalReviewed = 0;
  int? _sessionTotal;
  final List<int> _reviewedIds = [];
  bool _sessionComplete = false;
  String? _exampleSentence;
  String? _explanation;
  bool _loadingHint = false;

  void _showNextWord() {
    setState(() {
      _currentIndex++;
      _hintLevel = 0;
      _totalReviewed++;
      _exampleSentence = null;
      _explanation = null;
      _loadingHint = false;
    });
  }

  Future<void> _showHint(Word word) async {
    final gemini = ref.read(geminiServiceProvider);

    setState(() {
      _hintLevel++;
      _loadingHint = true;
    });

    try {
      if (_hintLevel == 1 && gemini != null) {
        // Hint 1: Example sentence in source language
        final sentence = await gemini.generateExampleSentence(
          word: word.source,
          sourceLang: word.sourceLang,
        );

        if (mounted) {
          setState(() {
            _exampleSentence = sentence;
            _loadingHint = false;
          });
        }
      } else if (_hintLevel == 2 && gemini != null) {
        // Hint 2: Explanation in target language
        final explanation = await gemini.generateExplanation(
          word: word.source,
          translation: word.translation,
          targetLang: word.targetLang,
        );

        if (mounted) {
          setState(() {
            _explanation = explanation;
            _loadingHint = false;
          });
        }
      } else {
        // No AI or hints 3-4 don't need AI
        setState(() => _loadingHint = false);
      }
    } catch (e) {
      // If AI fails, just show the hint without AI content
      if (mounted) {
        setState(() => _loadingHint = false);
      }
    }
  }

  Future<void> _markKnown(WordWithRecall wordRecall) async {
    _reviewedIds.add(wordRecall.word.id);

    final db = ref.read(databaseProvider);
    await db.updateRecall(wordRecall.recall.id, true);

    ref.invalidate(dueWordsProvider);
    ref.invalidate(dueWordCountProvider);

    _showNextWord();
  }

  Future<void> _markPartial(WordWithRecall wordRecall) async {
    _reviewedIds.add(wordRecall.word.id);

    final db = ref.read(databaseProvider);
    final recall = wordRecall.recall;

    final newInterval = (recall.intervalDays * 1.5).round().clamp(1, 100);

    await (db.update(db.recalls)..where((r) => r.id.equals(recall.id))).write(
      RecallsCompanion(
        nextReview: Value(DateTime.now().add(Duration(days: newInterval))),
        intervalDays: Value(newInterval),
        reviewCount: Value(recall.reviewCount + 1),
      ),
    );

    ref.invalidate(dueWordsProvider);
    ref.invalidate(dueWordCountProvider);

    _showNextWord();
  }

  Future<void> _markUnknown(WordWithRecall wordRecall) async {
    _reviewedIds.add(wordRecall.word.id);

    final db = ref.read(databaseProvider);
    await db.updateRecall(wordRecall.recall.id, false);

    ref.invalidate(dueWordsProvider);
    ref.invalidate(dueWordCountProvider);

    _showNextWord();
  }

  void _completeSession() {
    setState(() {
      _sessionComplete = true;
      _currentIndex = 0;
      _totalReviewed = 0;
      _reviewedIds.clear();
      _sessionTotal = null;
      _exampleSentence = null;
      _explanation = null;
    });
    ref.invalidate(dueWordsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final dueWordsAsync = ref.watch(dueWordsProvider);
    final hasGemini = ref.watch(geminiServiceProvider) != null;

    return Scaffold(
      body: SafeArea(
        child: dueWordsAsync.when(
          data: (words) {
            _sessionTotal ??= words.length;

            final pendingWords = words
                .where((w) => !_reviewedIds.contains(w.word.id))
                .toList();

            if (pendingWords.isEmpty &&
                _reviewedIds.isNotEmpty &&
                !_sessionComplete) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Session Complete!',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Reviewed ${_reviewedIds.length} ${_reviewedIds.length == 1 ? 'word' : 'words'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _completeSession,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 56),
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              );
            }

            if (pendingWords.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'All caught up',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No words to review',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WordLibraryScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.library_books),
                      label: const Text('View All Words'),
                    ),
                  ],
                ),
              );
            }

            if (_currentIndex >= pendingWords.length) {
              _currentIndex = 0;
            }

            final wordRecall = pendingWords[_currentIndex];
            final word = wordRecall.word;

            final total = _sessionTotal!;
            final reviewed = _totalReviewed.clamp(0, total);
            final progress = total == 0 ? 0.0 : reviewed / total;

            final hasUsedHint = _hintLevel > 0;
            final maxHints = hasGemini ? 4 : 2; // 4 with AI, 2 without

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recall',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: AppTheme.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '$reviewed / $total',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'What does this mean?',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      word.source,
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium
                                          ?.copyWith(height: 1.2),
                                      textAlign: TextAlign.center,
                                      softWrap: true,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    onPressed: () => TtsService.speak(
                                      word.source,
                                      word.sourceLang,
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
                              if (_hintLevel > 0) ...[
                                const SizedBox(height: 32),
                                Container(
                                  width: double.infinity,
                                  height: 1,
                                  color: AppTheme.surfaceVariant.withOpacity(
                                    0.5,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildHint(context, word, hasGemini),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_hintLevel < maxHints)
                          OutlinedButton.icon(
                            onPressed: _loadingHint
                                ? null
                                : () => _showHint(word),
                            icon: _loadingHint
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lightbulb_outline, size: 20),
                            label: Text(
                              _loadingHint
                                  ? 'Loading...'
                                  : 'Show Hint ${_hintLevel + 1}/$maxHints',
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _markUnknown(wordRecall),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 56),
                            side: BorderSide(
                              color: AppTheme.errorColor.withOpacity(0.3),
                            ),
                          ),
                          child: const Text('Forgot'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (hasUsedHint)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _markPartial(wordRecall),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 56),
                              side: BorderSide(
                                color: AppTheme.warningColor.withOpacity(0.3),
                              ),
                            ),
                            child: const Text('Hint Helped'),
                          ),
                        )
                      else
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _markKnown(wordRecall),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 56),
                              backgroundColor: AppTheme.successColor,
                              foregroundColor: const Color(0xFF000000),
                            ),
                            child: const Text('I Know'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHint(BuildContext context, Word word, bool hasGemini) {
    if (hasGemini) {
      // With AI: 4-level hint system
      switch (_hintLevel) {
        case 1:
          // Hint 1: Example sentence in source language
          if (_loadingHint) {
            return const Column(
              children: [
                SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(height: 8),
                Text('Generating example...'),
              ],
            );
          }

          if (_exampleSentence != null) {
            return Column(
              children: [
                Text(
                  'Example Sentence',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () =>
                      TtsService.speak(_exampleSentence!, word.sourceLang),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _exampleSentence!,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.volume_up_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return const SizedBox.shrink();

        case 2:
          // Hint 2: Explanation in target language
          if (_loadingHint) {
            return const Column(
              children: [
                SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(height: 8),
                Text('Generating explanation...'),
              ],
            );
          }

          if (_explanation != null) {
            return Column(
              children: [
                Text(
                  'Meaning',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => TtsService.speak(_explanation!, word.targetLang),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.warningColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _explanation!,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: AppTheme.warningColor,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.volume_up_outlined,
                          size: 20,
                          color: AppTheme.warningColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return const SizedBox.shrink();

        case 3:
          // Hint 3: First letter
          return Column(
            children: [
              Text(
                'First Letter',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                word.translation[0].toUpperCase(),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          );

        case 4:
          // Hint 4: Full answer
          return Column(
            children: [
              InkWell(
                onTap: () =>
                    TtsService.speak(word.translation, word.targetLang),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          word.translation,
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(color: AppTheme.successColor),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.volume_up_outlined,
                        color: AppTheme.successColor,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${word.sourceLang} → ${word.targetLang}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );
      }
    } else {
      // Without AI: 2-level hint system
      switch (_hintLevel) {
        case 1:
          // Hint 1: First letter
          return Column(
            children: [
              Text(
                'First Letter',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                word.translation[0].toUpperCase(),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          );

        case 2:
          // Hint 2: Full answer
          return Column(
            children: [
              InkWell(
                onTap: () =>
                    TtsService.speak(word.translation, word.targetLang),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          word.translation,
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(color: AppTheme.successColor),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.volume_up_outlined,
                        color: AppTheme.successColor,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${word.sourceLang} → ${word.targetLang}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );
      }
    }

    return const SizedBox.shrink();
  }
}
