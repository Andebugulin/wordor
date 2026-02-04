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

  // Hint state
  final Set<HintType> _usedHints = {};
  String? _aiExample;
  String? _aiExplanation;
  bool _loadingHint = false;

  void _showNextWord() {
    setState(() {
      _currentIndex++;
      _totalReviewed++;
      _usedHints.clear();
      _aiExample = null;
      _aiExplanation = null;
      _loadingHint = false;
    });
  }

  Future<void> _showHint(HintType type, Word word) async {
    if (_usedHints.contains(type)) return; // Already shown

    setState(() {
      _usedHints.add(type);
      if (type == HintType.aiExample || type == HintType.aiExplanation) {
        _loadingHint = true;
      }
    });

    // Handle AI hints
    if (type == HintType.aiExample || type == HintType.aiExplanation) {
      final aiService = ref.read(aiHintServiceProvider);

      if (aiService == null) {
        setState(() => _loadingHint = false);
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
              _aiExample = example;
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
              _aiExplanation = explanation;
              _loadingHint = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loadingHint = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hint generation failed: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
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
      _usedHints.clear();
      _aiExample = null;
      _aiExplanation = null;
    });
    ref.invalidate(dueWordsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final dueWordsAsync = ref.watch(dueWordsProvider);
    final hasAI = ref.watch(aiHintServiceProvider) != null;

    return Scaffold(
      body: SafeArea(
        child: dueWordsAsync.when(
          data: (words) {
            _sessionTotal ??= words.length;
            final pendingWords = words
                .where((w) => !_reviewedIds.contains(w.word.id))
                .toList();

            // Session complete
            if (pendingWords.isEmpty &&
                _reviewedIds.isNotEmpty &&
                !_sessionComplete) {
              return _buildSessionComplete();
            }

            // No words
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
    final hasUsedHint = _usedHints.isNotEmpty;

    return Column(
      children: [
        // Progress bar at top
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recall',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    '$reviewed / $total',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
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
            ],
          ),
        ),

        // Main content - word at top
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Word card - prominent at top
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        Theme.of(context).colorScheme.surface,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'What does this mean?',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              word.source,
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton.filled(
                            onPressed: () =>
                                TtsService.speak(word.source, word.sourceLang),
                            icon: const Icon(Icons.volume_up, size: 28),
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Hint buttons grid
                _buildHintButtons(word, hasAI),

                const SizedBox(height: 24),

                // Display active hints
                if (_usedHints.isNotEmpty) _buildActiveHints(word),
              ],
            ),
          ),
        ),

        // Action buttons at bottom
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _markUnknown(wordRecall),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 64),
                    side: BorderSide(
                      color: AppTheme.errorColor.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  icon: const Icon(Icons.close, size: 24),
                  label: const Text('Forgot', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: hasUsedHint ? 1 : 2,
                child: hasUsedHint
                    ? OutlinedButton.icon(
                        onPressed: () => _markPartial(wordRecall),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 64),
                          side: BorderSide(
                            color: AppTheme.warningColor.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        icon: const Icon(Icons.lightbulb_outline, size: 24),
                        label: const Text(
                          'Used Hint',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _markKnown(wordRecall),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 64),
                          backgroundColor: AppTheme.successColor,
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.check, size: 24),
                        label: const Text(
                          'I Know',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHintButtons(Word word, bool hasAI) {
    final availableHints = [
      if (hasAI && !_usedHints.contains(HintType.aiExample))
        _HintButton(
          icon: Icons.auto_awesome,
          label: 'Example',
          color: Theme.of(context).colorScheme.primary,
          onPressed: _loadingHint
              ? null
              : () => _showHint(HintType.aiExample, word),
        ),
      if (hasAI && !_usedHints.contains(HintType.aiExplanation))
        _HintButton(
          icon: Icons.info_outline,
          label: 'Explain',
          color: AppTheme.warningColor,
          onPressed: _loadingHint
              ? null
              : () => _showHint(HintType.aiExplanation, word),
        ),
      if (!_usedHints.contains(HintType.firstLetter))
        _HintButton(
          icon: Icons.text_fields,
          label: 'First Letter',
          color: Theme.of(context).colorScheme.secondary,
          onPressed: () => _showHint(HintType.firstLetter, word),
        ),
      if (!_usedHints.contains(HintType.fullAnswer))
        _HintButton(
          icon: Icons.remove_red_eye_outlined,
          label: 'Show Answer',
          color: AppTheme.errorColor,
          onPressed: () => _showHint(HintType.fullAnswer, word),
        ),
    ];

    if (availableHints.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Need a hint?',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: availableHints),
      ],
    );
  }

  Widget _buildActiveHints(Word word) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_usedHints.contains(HintType.aiExample) && _aiExample != null)
          _HintCard(
            icon: Icons.auto_awesome,
            title: 'Example Sentence',
            content: _aiExample!,
            color: Theme.of(context).colorScheme.primary,
            onTap: () => TtsService.speak(_aiExample!, word.sourceLang),
          ),

        if (_usedHints.contains(HintType.aiExplanation) &&
            _aiExplanation != null) ...[
          const SizedBox(height: 12),
          _HintCard(
            icon: Icons.info_outline,
            title: 'Meaning',
            content: _aiExplanation!,
            color: AppTheme.warningColor,
            onTap: () => TtsService.speak(_aiExplanation!, word.targetLang),
          ),
        ],

        if (_usedHints.contains(HintType.firstLetter)) ...[
          const SizedBox(height: 12),
          _HintCard(
            icon: Icons.text_fields,
            title: 'First Letter',
            content: word.translation[0].toUpperCase(),
            color: Theme.of(context).colorScheme.secondary,
            isLarge: true,
          ),
        ],

        if (_usedHints.contains(HintType.fullAnswer)) ...[
          const SizedBox(height: 12),
          _HintCard(
            icon: Icons.check_circle,
            title: 'Answer',
            content: word.translation,
            color: AppTheme.successColor,
            onTap: () => TtsService.speak(word.translation, word.targetLang),
            isLarge: true,
          ),
        ],

        if (_loadingHint) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  Widget _buildSessionComplete() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.celebration_outlined,
                size: 80,
                color: AppTheme.successColor,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Session Complete!',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Reviewed ${_reviewedIds.length} ${_reviewedIds.length == 1 ? 'word' : 'words'}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _completeSession,
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 64)),
              icon: const Icon(Icons.check, size: 24),
              label: const Text('Done', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoWords() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 80,
                color: AppTheme.successColor,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'All caught up!',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'No words to review',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WordLibraryScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 64)),
              icon: const Icon(Icons.library_books, size: 24),
              label: const Text(
                'View All Words',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _HintButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        side: BorderSide(color: color.withOpacity(0.5), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 20, color: color),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;
  final VoidCallback? onTap;
  final bool isLarge;

  const _HintCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
    this.onTap,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (onTap != null)
                  Icon(Icons.volume_up_outlined, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: isLarge
                  ? Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    )
                  : Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
