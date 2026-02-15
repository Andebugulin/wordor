import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../data/database.dart';
import '../providers/app_providers.dart';
import '../services/tts_service.dart';

class WordLibraryScreen extends ConsumerStatefulWidget {
  const WordLibraryScreen({super.key});

  @override
  ConsumerState<WordLibraryScreen> createState() => _WordLibraryScreenState();
}

class _WordLibraryScreenState extends ConsumerState<WordLibraryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteWord(int wordId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Word?'),
        content: const Text('This word will be removed from your recall list.'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);

      final word = await (db.select(
        db.words,
      )..where((w) => w.id.equals(wordId))).getSingle();

      await db.deleteWord(wordId);

      await (db.update(db.translationHistory)..where(
            (t) =>
                t.source.equals(word.source) &
                t.translation.equals(word.translation),
          ))
          .write(TranslationHistoryCompanion(saved: drift.Value(false)));

      ref.invalidate(dueWordCountProvider);
      setState(() {});
    }
  }

  String _formatNextReview(DateTime nextReview) {
    final now = DateTime.now();
    final diff = nextReview.difference(now);

    if (diff.isNegative) {
      return 'Due now';
    } else if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return 'Due in ${diff.inMinutes}m';
      }
      return 'Due in ${diff.inHours}h';
    } else if (diff.inDays == 1) {
      return 'Due tomorrow';
    } else {
      return 'Due in ${diff.inDays}d';
    }
  }

  // ── Anki Export (CSV) ────────────────────────────────────────────

  Future<void> _exportCsv() async {
    final db = ref.read(databaseProvider);
    final csv = await db.exportToCsv();

    if (csv.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No words to export')));
      }
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(path.join(dir.path, 'wordor_export.csv'));
      await file.writeAsString(csv);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Export Successful'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saved to:\n${file.path}'),
                const SizedBox(height: 16),
                const Text(
                  'To use in Anki:\n'
                  '1. Copy the .csv file to your computer\n'
                  '2. In Anki: File → Import\n'
                  '3. Select the .csv file\n'
                  '4. Map columns: Field 1 → Front, Field 2 → Back',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: csv));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CSV copied to clipboard')),
                  );
                },
                child: const Text('Copy CSV'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV copied to clipboard')),
        );
      }
    }
  }

  // ── Anki Import (CSV) ────────────────────────────────────────────

  Future<void> _importCsv() async {
    final controller = TextEditingController();
    String sourceLang = 'EN';
    String targetLang = 'EN';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Import from CSV'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste your CSV content below.\n'
                  'Format: front,back or front,back,tags',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Source lang',
                          hintText: 'e.g. FI',
                          isDense: true,
                        ),
                        onChanged: (v) => sourceLang = v.toUpperCase(),
                        controller: TextEditingController(text: sourceLang),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Target lang',
                          hintText: 'e.g. EN',
                          isDense: true,
                        ),
                        onChanged: (v) => targetLang = v.toUpperCase(),
                        controller: TextEditingController(text: targetLang),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'Paste CSV content here...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                Navigator.pop(ctx, {
                  'content': controller.text,
                  'sourceLang': sourceLang,
                  'targetLang': targetLang,
                });
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      final db = ref.read(databaseProvider);
      final count = await db.importFromCsv(
        result['content']!,
        defaultSourceLang: result['sourceLang']!,
        defaultTargetLang: result['targetLang']!,
      );

      ref.invalidate(dueWordCountProvider);
      ref.invalidate(dueWordsProvider);
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? 'Imported $count ${count == 1 ? "word" : "words"}'
                  : 'No new words to import (all duplicates)',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Words'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'import':
                  _importCsv();
                  break;
                case 'export':
                  _exportCsv();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.file_download_outlined),
                  title: Text('Import CSV'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.file_upload_outlined),
                  title: Text('Export CSV'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
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
                hintText: 'Search words',
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
            child: FutureBuilder<List<WordWithRecall>>(
              future: _searchQuery.isEmpty
                  ? db.getAllWords()
                  : db.searchWords(_searchQuery),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final words = snapshot.data ?? [];

                if (words.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.book_outlined
                              : Icons.search_off,
                          size: 64,
                          color: colors.onSurfaceVariant.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No saved words yet'
                              : 'No words found',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: _importCsv,
                            icon: const Icon(Icons.file_download_outlined),
                            label: const Text('Import CSV'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: words.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final wordRecall = words[index];
                    final word = wordRecall.word;
                    final recall = wordRecall.recall;
                    final isDue = recall.nextReview.isBefore(DateTime.now());

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: isDue
                            ? Border.all(
                                color: colors.primary.withOpacity(0.3),
                                width: 2,
                              )
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDue
                                      ? colors.primary.withOpacity(0.1)
                                      : colors.surface,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _formatNextReview(recall.nextReview),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDue
                                        ? colors.primary
                                        : colors.onSurfaceVariant,
                                    fontWeight: isDue
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${word.sourceLang} → ${word.targetLang}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _deleteWord(word.id),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  word.source,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => TtsService.speak(
                                  word.source,
                                  word.sourceLang,
                                ),
                                icon: const Icon(
                                  Icons.volume_up_outlined,
                                  size: 20,
                                ),
                                style: IconButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  word.translation,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              IconButton(
                                onPressed: () => TtsService.speak(
                                  word.translation,
                                  word.targetLang,
                                ),
                                icon: const Icon(
                                  Icons.volume_up_outlined,
                                  size: 20,
                                ),
                                style: IconButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                          if (recall.reviewCount > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Reviewed ${recall.reviewCount} ${recall.reviewCount == 1 ? 'time' : 'times'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant.withOpacity(0.7),
                              ),
                            ),
                          ],
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
