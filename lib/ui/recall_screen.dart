import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import '../providers/app_providers.dart';
import '../services/tts_service.dart';
import 'word_library_screen.dart';

enum HintType { aiExample, aiExplanation, firstLetter, fullAnswer }

// StateNotifier to persist recall session state
class RecallSessionState {
  final Map<int, Set<HintType>> usedHintsPerWord;
  final Map<int, Map<HintType, String>> hintContentsPerWord;

  RecallSessionState({
    required this.usedHintsPerWord,
    required this.hintContentsPerWord,
  });

  RecallSessionState copyWith({
    Map<int, Set<HintType>>? usedHintsPerWord,
    Map<int, Map<HintType, String>>? hintContentsPerWord,
  }) {
    return RecallSessionState(
      usedHintsPerWord: usedHintsPerWord ?? this.usedHintsPerWord,
      hintContentsPerWord: hintContentsPerWord ?? this.hintContentsPerWord,
    );
  }
}

class RecallSessionNotifier extends StateNotifier<RecallSessionState> {
  RecallSessionNotifier()
    : super(RecallSessionState(usedHintsPerWord: {}, hintContentsPerWord: {}));

  void addHint(int wordId, HintType type, String content) {
    final newUsedHints = Map<int, Set<HintType>>.from(state.usedHintsPerWord);
    final newContents = Map<int, Map<HintType, String>>.from(
      state.hintContentsPerWord,
    );

    newUsedHints.putIfAbsent(wordId, () => {}).add(type);
    newContents.putIfAbsent(wordId, () => {})[type] = content;

    state = state.copyWith(
      usedHintsPerWord: newUsedHints,
      hintContentsPerWord: newContents,
    );
  }

  void removeHint(int wordId, HintType type) {
    final newUsedHints = Map<int, Set<HintType>>.from(state.usedHintsPerWord);
    final newContents = Map<int, Map<HintType, String>>.from(
      state.hintContentsPerWord,
    );

    newUsedHints[wordId]?.remove(type);
    newContents[wordId]?.remove(type);

    state = state.copyWith(
      usedHintsPerWord: newUsedHints,
      hintContentsPerWord: newContents,
    );
  }

  void clearWord(int wordId) {
    final newUsedHints = Map<int, Set<HintType>>.from(state.usedHintsPerWord);
    final newContents = Map<int, Map<HintType, String>>.from(
      state.hintContentsPerWord,
    );

    newUsedHints.remove(wordId);
    newContents.remove(wordId);

    state = state.copyWith(
      usedHintsPerWord: newUsedHints,
      hintContentsPerWord: newContents,
    );
  }

  void clearSession() {
    state = RecallSessionState(usedHintsPerWord: {}, hintContentsPerWord: {});
  }

  Set<HintType> getUsedHints(int wordId) {
    return state.usedHintsPerWord[wordId] ?? {};
  }

  Map<HintType, String> getHintContents(int wordId) {
    return state.hintContentsPerWord[wordId] ?? {};
  }
}

final recallSessionProvider =
    StateNotifierProvider<RecallSessionNotifier, RecallSessionState>((ref) {
      return RecallSessionNotifier();
    });

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
  bool _loadingHint = false;

  /// Reset to a clean state so new due words are always shown.
  void _resetSession() {
    _currentIndex = 0;
    _totalReviewed = 0;
    _sessionTotal = null;
    _reviewedIds.clear();
    _sessionComplete = false;
    _loadingHint = false;
    ref.read(recallSessionProvider.notifier).clearSession();
  }

  void _showNextWord() {
    setState(() {
      _currentIndex++;
      _totalReviewed++;
      _loadingHint = false;
    });
  }

  Future<void> _showHint(HintType type, Word word) async {
    final sessionNotifier = ref.read(recallSessionProvider.notifier);
    final usedHints = sessionNotifier.getUsedHints(word.id);

    if (usedHints.contains(type)) return; // Already shown

    setState(() {
      _loadingHint = true;
    });

    // Handle AI hints
    if (type == HintType.aiExample || type == HintType.aiExplanation) {
      final aiService = ref.read(aiHintServiceProvider);

      if (aiService == null) {
        setState(() => _loadingHint = false);
        return;
      }

      try {
        String content;
        if (type == HintType.aiExample) {
          content = await aiService.generateExample(
            word: word.source,
            sourceLang: word.sourceLang,
          );
        } else {
          content = await aiService.generateExplanation(
            word: word.source,
            translation: word.translation,
            targetLang: word.targetLang,
          );
        }

        if (mounted) {
          sessionNotifier.addHint(word.id, type, content);
          setState(() => _loadingHint = false);
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
    } else {
      // For non-AI hints, set content immediately
      String content;
      if (type == HintType.firstLetter) {
        content = word.translation[0].toUpperCase();
      } else {
        content = word.translation;
      }
      sessionNotifier.addHint(word.id, type, content);
      setState(() => _loadingHint = false);
    }
  }

  Future<void> _reloadHint(HintType type, Word word) async {
    final sessionNotifier = ref.read(recallSessionProvider.notifier);

    // Remove the existing hint first
    sessionNotifier.removeHint(word.id, type);

    // Show the hint again (which will regenerate it)
    await _showHint(type, word);
  }

  // Calculate interval multiplier based on hint type
  double _getHintMultiplier(Set<HintType> usedHints) {
    if (usedHints.isEmpty) {
      return 2.5; // No hints used - full multiplier
    }

    // Worst hint used determines the multiplier
    if (usedHints.contains(HintType.fullAnswer)) {
      return 0.5; // Saw full answer - reset to very short interval
    }
    if (usedHints.contains(HintType.firstLetter)) {
      return 1.0; // Used first letter - same interval
    }
    if (usedHints.contains(HintType.aiExplanation)) {
      return 1.5; // Used explanation - slightly longer
    }
    if (usedHints.contains(HintType.aiExample)) {
      return 2.0; // Used example - good progress
    }

    return 2.5; // Fallback
  }

  Future<void> _markKnown(WordWithRecall wordRecall) async {
    final sessionNotifier = ref.read(recallSessionProvider.notifier);
    final usedHints = sessionNotifier.getUsedHints(wordRecall.word.id);

    _reviewedIds.add(wordRecall.word.id);
    final db = ref.read(databaseProvider);
    final recall = wordRecall.recall;

    // Calculate new interval based on hints used
    final multiplier = _getHintMultiplier(usedHints);
    final newInterval = (recall.intervalDays * multiplier).round().clamp(
      1,
      365,
    );

    await (db.update(db.recalls)..where((r) => r.id.equals(recall.id))).write(
      RecallsCompanion(
        nextReview: Value(DateTime.now().add(Duration(days: newInterval))),
        intervalDays: Value(newInterval),
        reviewCount: Value(recall.reviewCount + 1),
      ),
    );

    // Clear hints for this word
    sessionNotifier.clearWord(wordRecall.word.id);

    ref.invalidate(dueWordsProvider);
    ref.invalidate(dueWordCountProvider);
    _showNextWord();
  }

  Future<void> _markPartial(WordWithRecall wordRecall) async {
    final sessionNotifier = ref.read(recallSessionProvider.notifier);
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

    // Clear hints for this word
    sessionNotifier.clearWord(wordRecall.word.id);

    ref.invalidate(dueWordsProvider);
    ref.invalidate(dueWordCountProvider);
    _showNextWord();
  }

  Future<void> _markUnknown(WordWithRecall wordRecall) async {
    final sessionNotifier = ref.read(recallSessionProvider.notifier);
    _reviewedIds.add(wordRecall.word.id);
    final db = ref.read(databaseProvider);
    await db.updateRecall(wordRecall.recall.id, false);

    // Clear hints for this word
    sessionNotifier.clearWord(wordRecall.word.id);

    ref.invalidate(dueWordsProvider);
    ref.invalidate(dueWordCountProvider);
    _showNextWord();
  }

  void _completeSession() {
    setState(() {
      _resetSession();
    });
    ref.invalidate(dueWordsProvider);
    ref.invalidate(dueWordCountProvider);
  }

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
    final currentAIKeyAsync = ref.watch(currentAIProviderHasKeyProvider);
    final hasAIKey = currentAIKeyAsync.value ?? false;

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 24,
        title: Row(
          children: [
            const Text('Recall'),
            const SizedBox(width: 12),
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
            // ── KEY FIX: auto-reset session when new words appear ──
            // If we previously completed a session (or had no words) but the
            // provider now returns fresh due words, start a brand-new session
            // so those words actually display.
            final pendingWords = words
                .where((w) => !_reviewedIds.contains(w.word.id))
                .toList();

            if (_sessionComplete && pendingWords.isNotEmpty) {
              // New words arrived after session was completed — reset
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _resetSession());
                }
              });
              return const Center(child: CircularProgressIndicator());
            }

            _sessionTotal ??= words.length;

            if (pendingWords.isEmpty &&
                _reviewedIds.isNotEmpty &&
                !_sessionComplete) {
              _sessionComplete = true;
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
                Icon(Icons.error_outline, size: 64, color: colors.error),
                const SizedBox(height: 16),
                Text('Something went wrong', style: theme.textTheme.titleLarge),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = _sessionTotal!;
    final reviewed = _totalReviewed.clamp(0, total);
    final progress = total == 0 ? 0.0 : reviewed / total;

    final sessionNotifier = ref.read(recallSessionProvider.notifier);
    final shownHints = sessionNotifier.getUsedHints(word.id);
    final hintContents = sessionNotifier.getHintContents(word.id);
    final hasUsedHint = shownHints.isNotEmpty;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$reviewed / $total',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${((progress * 100).toInt())}%',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
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
                  backgroundColor: theme.dividerTheme.color,
                  valueColor: AlwaysStoppedAnimation(colors.primary),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: theme.scaffoldBackgroundColor,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Column(
                    children: [
                      Text(
                        word.source,
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontSize: _calculateWordFontSize(word.source),
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      IconButton.outlined(
                        onPressed: () =>
                            TtsService.speak(word.source, word.sourceLang),
                        icon: const Icon(Icons.volume_up_outlined, size: 24),
                        style: IconButton.styleFrom(
                          side: BorderSide(
                            color: theme.dividerTheme.color ?? colors.outline,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${word.sourceLang} → ${word.targetLang}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant.withOpacity(0.6),
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  if (shownHints.isNotEmpty) ...[
                    _buildAllHints(word, shownHints, hintContents),
                    const SizedBox(height: 32),
                  ],
                  _buildHintButtons(word, hasAI, shownHints),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: theme.dividerTheme.color ?? colors.outline,
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _markUnknown(wordRecall),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      side: BorderSide(
                        color: colors.error.withOpacity(0.3),
                        width: 1.5,
                      ),
                      foregroundColor: colors.error,
                    ),
                    child: const Text('Forgot'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: hasUsedHint
                      ? OutlinedButton(
                          onPressed: () => _markPartial(wordRecall),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 56),
                            side: BorderSide(
                              color: colors.secondary.withOpacity(0.3),
                              width: 1.5,
                            ),
                            foregroundColor: colors.secondary,
                          ),
                          child: const Text('Used Hint'),
                        )
                      : ElevatedButton(
                          onPressed: () => _markKnown(wordRecall),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 56),
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

  Widget _buildHintButtons(Word word, bool hasAI, Set<HintType> shownHints) {
    final availableHints = <Widget>[];

    if (hasAI && !shownHints.contains(HintType.aiExample)) {
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

    if (hasAI && !shownHints.contains(HintType.aiExplanation)) {
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

    if (!shownHints.contains(HintType.firstLetter)) {
      availableHints.add(
        _MinimalHintButton(
          label: 'First Letter',
          icon: Icons.text_fields_outlined,
          onPressed: () => _showHint(HintType.firstLetter, word),
        ),
      );
    }

    if (!shownHints.contains(HintType.fullAnswer)) {
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
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withOpacity(0.6),
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

  Widget _buildAllHints(
    Word word,
    Set<HintType> shownHints,
    Map<HintType, String> hintContents,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shownHints.contains(HintType.aiExample) &&
            hintContents.containsKey(HintType.aiExample))
          _MinimalHintCard(
            label: 'Example',
            content: hintContents[HintType.aiExample]!,
            onTap: () => TtsService.speak(
              hintContents[HintType.aiExample]!,
              word.sourceLang,
            ),
            onReload: () => _reloadHint(HintType.aiExample, word),
          ),
        if (shownHints.contains(HintType.aiExplanation) &&
            hintContents.containsKey(HintType.aiExplanation)) ...[
          const SizedBox(height: 12),
          _MinimalHintCard(
            label: 'Meaning',
            content: hintContents[HintType.aiExplanation]!,
            onTap: () => TtsService.speak(
              hintContents[HintType.aiExplanation]!,
              word.targetLang,
            ),
            onReload: () => _reloadHint(HintType.aiExplanation, word),
          ),
        ],
        if (shownHints.contains(HintType.firstLetter) &&
            hintContents.containsKey(HintType.firstLetter)) ...[
          const SizedBox(height: 12),
          _MinimalHintCard(
            label: 'First Letter',
            content: hintContents[HintType.firstLetter]!,
            isLarge: true,
          ),
        ],
        if (shownHints.contains(HintType.fullAnswer) &&
            hintContents.containsKey(HintType.fullAnswer)) ...[
          const SizedBox(height: 12),
          _MinimalHintCard(
            label: 'Answer',
            content: hintContents[HintType.fullAnswer]!,
            isAnswer: true,
            accentColor: colors.primary,
            onTap: () => TtsService.speak(
              hintContents[HintType.fullAnswer]!,
              word.targetLang,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSessionComplete() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: colors.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 32),
            Text('Session Complete', style: theme.textTheme.displaySmall),
            const SizedBox(height: 12),
            Text(
              'Reviewed ${_reviewedIds.length} ${_reviewedIds.length == 1 ? 'word' : 'words'}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: colors.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 32),
            Text('All Caught Up', style: theme.textTheme.displaySmall),
            const SizedBox(height: 12),
            Text(
              'No words to review right now',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
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

  // Match translate_screen indicator colors for consistency
  static const _green = Color(0xFF4ADEAA);
  static const _red = Color(0xFFFF6B7A);

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _green : _red;

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: color),
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
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
  final VoidCallback? onReload;
  final bool isLarge;
  final bool isAnswer;
  final Color? accentColor;

  const _MinimalHintCard({
    required this.label,
    required this.content,
    this.onTap,
    this.onReload,
    this.isLarge = false,
    this.isAnswer = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final effectiveAccent = accentColor ?? colors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAnswer
                ? effectiveAccent.withOpacity(0.2)
                : theme.dividerTheme.color ?? colors.outline,
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (onReload != null)
                  IconButton(
                    onPressed: onReload,
                    icon: const Icon(Icons.refresh, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Regenerate hint',
                    color: colors.onSurfaceVariant.withOpacity(0.6),
                  ),
                if (onTap != null) ...[
                  if (onReload != null) const SizedBox(width: 8),
                  Icon(
                    Icons.volume_up_outlined,
                    size: 16,
                    color: colors.onSurfaceVariant.withOpacity(0.6),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: isLarge
                  ? theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isAnswer ? effectiveAccent : null,
                    )
                  : theme.textTheme.bodyLarge?.copyWith(
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
