import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import '../providers/app_providers.dart';
import '../services/tts_service.dart';
import '../theme.dart';
import 'word_library_screen.dart';

enum HintType { aiExample, aiExplanation, firstLetter, fullAnswer }

class RecallScreen extends ConsumerStatefulWidget {
  const RecallScreen({super.key});

  @override
  ConsumerState<RecallScreen> createState() => _RecallScreenState();
}

class _RecallScreenState extends ConsumerState<RecallScreen> {
  int _currentIndex = 0;
  int _totalReviewed = 0;
  int? _sessionTotal;
  final List<int> _reviewedIds = [];
  bool _sessionComplete = false;

  // Hint state - now tracks which hints are shown, not just used
  final Set<HintType> _shownHints = {};
  final Map<HintType, String> _hintContents = {};
  bool _loadingHint = false;

  void _showNextWord() {
    setState(() {
      _currentIndex++;
      _totalReviewed++;
      _shownHints.clear();
      _hintContents.clear();
      _loadingHint = false;
    });
  }

  Future<void> _showHint(HintType type, Word word) async {
    if (_shownHints.contains(type)) return; // Already shown

    setState(() {
      _shownHints.add(type);
      if (type == HintType.aiExample || type == HintType.aiExplanation) {
        _loadingHint = true;
      }
    });

    // Handle AI hints
    if (type == HintType.aiExample || type == HintType.aiExplanation) {
      final aiService = ref.read(aiHintServiceProvider);

      if (aiService == null) {
        setState(() {
          _loadingHint = false;
          _shownHints.remove(type);
        });
        return;
      }

      try {
        if (type == HintType.aiExample) {
          final example = await aiService.generateExample(
            word: word.source,
            sourceLang: word.sourceLang,
          );
          if (mounted) {
            setState(() {
              _hintContents[type] = example;
              _loadingHint = false;
            });
          }
        } else if (type == HintType.aiExplanation) {
          final explanation = await aiService.generateExplanation(
            word: word.source,
            translation: word.translation,
            targetLang: word.targetLang,
          );
          if (mounted) {
            setState(() {
              _hintContents[type] = explanation;
              _loadingHint = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _loadingHint = false;
            _shownHints.remove(type);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hint generation failed: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      // For non-AI hints, set content immediately
      if (type == HintType.firstLetter) {
        _hintContents[type] = word.translation[0].toUpperCase();
      } else if (type == HintType.fullAnswer) {
        _hintContents[type] = word.translation;
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
      _shownHints.clear();
      _hintContents.clear();
    });
    ref.invalidate(dueWordsProvider);
  }

  // Smart font size calculation based on word length
  double _calculateWordFontSize(String word) {
    if (word.length <= 8) return 56;
    if (word.length <= 12) return 48;
    if (word.length <= 16) return 40;
    if (word.length <= 20) return 36;
    return 32;
  }

  @override
  Widget build(BuildContext context) {
    final dueWordsAsync = ref.watch(dueWordsProvider);
    final hasAI = ref.watch(aiHintServiceProvider) != null;

    final deeplKeyAsync = ref.watch(apiKeyProvider);
    final hasDeepLKey = deeplKeyAsync.value != null;

    // Use the provider that checks the CURRENT AI provider's key status
    final currentAIKeyAsync = ref.watch(currentAIProviderHasKeyProvider);
    final hasAIKey = currentAIKeyAsync.value ?? false;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        titleSpacing: 24,
        title: Row(
          children: [
            const Text('Recall'),
            const SizedBox(width: 12),
            // Key status indicators
            _KeyStatusIndicator(
              icon: Icons.key,
              isActive: hasDeepLKey,
              tooltip: hasDeepLKey
                  ? 'DeepL key configured'
                  : 'DeepL key missing',
            ),
            const SizedBox(width: 8),
            _KeyStatusIndicator(
              icon: Icons.auto_awesome,
              isActive: hasAIKey,
              tooltip: hasAIKey ? 'AI key configured' : 'AI key missing',
            ),
          ],
        ),
      ),
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
              return _buildSessionComplete();
            }

            if (pendingWords.isEmpty) {
              return _buildNoWords();
            }

            if (_currentIndex >= pendingWords.length) {
              _currentIndex = 0;
            }

            final wordRecall = pendingWords[_currentIndex];
            final word = wordRecall.word;

            return _buildRecallInterface(word, wordRecall, hasAI);
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

  Widget _buildRecallInterface(
    Word word,
    WordWithRecall wordRecall,
    bool hasAI,
  ) {
    final total = _sessionTotal!;
    final reviewed = _totalReviewed.clamp(0, total);
    final progress = total == 0 ? 0.0 : reviewed / total;
    final hasUsedHint = _shownHints.isNotEmpty;

    return Column(
      children: [
        // Minimalistic progress header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          color: AppTheme.backgroundColor,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$reviewed / $total',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${((progress * 100).toInt())}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: const Color(0xFF2A2A38),
                  valueColor: const AlwaysStoppedAnimation(
                    AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Main word display - centered and prominent
        Expanded(
          child: Container(
            color: AppTheme.backgroundColor,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // The word itself - hero element with smart sizing
                  Column(
                    children: [
                      Text(
                        word.source,
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              fontSize: _calculateWordFontSize(word.source),
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2,
                              height: 1.1,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Pronunciation button
                      IconButton.outlined(
                        onPressed: () =>
                            TtsService.speak(word.source, word.sourceLang),
                        icon: const Icon(Icons.volume_up_outlined, size: 24),
                        style: IconButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF2A2A38),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.all(16),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Language indicator
                      Text(
                        '${word.sourceLang} → ${word.targetLang}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textTertiary,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Active hints display - ALL hints shown together
                  if (_shownHints.isNotEmpty) ...[
                    _buildAllHints(word),
                    const SizedBox(height: 32),
                  ],

                  // Hint buttons - always visible unless all used
                  _buildHintButtons(word, hasAI),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),

        // Action buttons - clean bottom bar
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            border: Border(
              top: BorderSide(color: const Color(0xFF2A2A38), width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Forgot button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _markUnknown(wordRecall),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      side: BorderSide(
                        color: AppTheme.errorColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                      foregroundColor: AppTheme.errorColor,
                    ),
                    child: const Text('Forgot'),
                  ),
                ),

                const SizedBox(width: 12),

                // Hint or Know button
                Expanded(
                  flex: 2,
                  child: hasUsedHint
                      ? OutlinedButton(
                          onPressed: () => _markPartial(wordRecall),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 56),
                            side: BorderSide(
                              color: AppTheme.warningColor.withOpacity(0.3),
                              width: 1.5,
                            ),
                            foregroundColor: AppTheme.warningColor,
                          ),
                          child: const Text('Used Hint'),
                        )
                      : ElevatedButton(
                          onPressed: () => _markKnown(wordRecall),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 56),
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text(
                            'I Know',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHintButtons(Word word, bool hasAI) {
    final availableHints = <Widget>[];

    if (hasAI && !_shownHints.contains(HintType.aiExample)) {
      availableHints.add(
        _MinimalHintButton(
          label: 'Example',
          icon: Icons.auto_awesome_outlined,
          onPressed: _loadingHint
              ? null
              : () => _showHint(HintType.aiExample, word),
        ),
      );
    }

    if (hasAI && !_shownHints.contains(HintType.aiExplanation)) {
      availableHints.add(
        _MinimalHintButton(
          label: 'Explain',
          icon: Icons.info_outlined,
          onPressed: _loadingHint
              ? null
              : () => _showHint(HintType.aiExplanation, word),
        ),
      );
    }

    if (!_shownHints.contains(HintType.firstLetter)) {
      availableHints.add(
        _MinimalHintButton(
          label: 'First Letter',
          icon: Icons.text_fields_outlined,
          onPressed: () => _showHint(HintType.firstLetter, word),
        ),
      );
    }

    if (!_shownHints.contains(HintType.fullAnswer)) {
      availableHints.add(
        _MinimalHintButton(
          label: 'Show Answer',
          icon: Icons.remove_red_eye_outlined,
          onPressed: () => _showHint(HintType.fullAnswer, word),
        ),
      );
    }

    if (availableHints.isEmpty && !_loadingHint) return const SizedBox.shrink();

    return Column(
      children: [
        if (_loadingHint)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Generating hint...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: availableHints,
          ),
      ],
    );
  }

  Widget _buildAllHints(Word word) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // AI Example
        if (_shownHints.contains(HintType.aiExample) &&
            _hintContents.containsKey(HintType.aiExample))
          _MinimalHintCard(
            label: 'Example',
            content: _hintContents[HintType.aiExample]!,
            onTap: () => TtsService.speak(
              _hintContents[HintType.aiExample]!,
              word.sourceLang,
            ),
          ),

        // AI Explanation
        if (_shownHints.contains(HintType.aiExplanation) &&
            _hintContents.containsKey(HintType.aiExplanation)) ...[
          const SizedBox(height: 12),
          _MinimalHintCard(
            label: 'Meaning',
            content: _hintContents[HintType.aiExplanation]!,
            onTap: () => TtsService.speak(
              _hintContents[HintType.aiExplanation]!,
              word.targetLang,
            ),
          ),
        ],

        // First Letter
        if (_shownHints.contains(HintType.firstLetter) &&
            _hintContents.containsKey(HintType.firstLetter)) ...[
          const SizedBox(height: 12),
          _MinimalHintCard(
            label: 'First Letter',
            content: _hintContents[HintType.firstLetter]!,
            isLarge: true,
          ),
        ],

        // Full Answer
        if (_shownHints.contains(HintType.fullAnswer) &&
            _hintContents.containsKey(HintType.fullAnswer)) ...[
          const SizedBox(height: 12),
          _MinimalHintCard(
            label: 'Answer',
            content: _hintContents[HintType.fullAnswer]!,
            isAnswer: true,
            onTap: () => TtsService.speak(
              _hintContents[HintType.fullAnswer]!,
              word.targetLang,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSessionComplete() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: AppTheme.successColor.withOpacity(0.5),
            ),
            const SizedBox(height: 32),
            Text(
              'Session Complete',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Reviewed ${_reviewedIds.length} ${_reviewedIds.length == 1 ? 'word' : 'words'}',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _completeSession,
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 56)),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoWords() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: AppTheme.successColor.withOpacity(0.5),
            ),
            const SizedBox(height: 32),
            Text(
              'All Caught Up',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'No words to review right now',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WordLibraryScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 56)),
              child: const Text('View Library'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyStatusIndicator extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final String tooltip;

  const _KeyStatusIndicator({
    required this.icon,
    required this.isActive,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF4ADEAA).withOpacity(0.15)
              : const Color(0xFFFF6B7A).withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 14,
          color: isActive ? const Color(0xFF4ADEAA) : const Color(0xFFFF6B7A),
        ),
      ),
    );
  }
}

class _MinimalHintButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _MinimalHintButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        foregroundColor: AppTheme.textSecondary,
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _MinimalHintCard extends StatelessWidget {
  final String label;
  final String content;
  final VoidCallback? onTap;
  final bool isLarge;
  final bool isAnswer;

  const _MinimalHintCard({
    required this.label,
    required this.content,
    this.onTap,
    this.isLarge = false,
    this.isAnswer = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAnswer
                ? AppTheme.successColor.withOpacity(0.2)
                : const Color(0xFF2A2A38),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textTertiary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (onTap != null)
                  Icon(
                    Icons.volume_up_outlined,
                    size: 16,
                    color: AppTheme.textTertiary,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: isLarge
                  ? Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isAnswer ? AppTheme.successColor : null,
                    )
                  : Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.6,
                    ),
              textAlign: isLarge ? TextAlign.center : TextAlign.left,
            ),
          ],
        ),
      ),
    );
  }
}
