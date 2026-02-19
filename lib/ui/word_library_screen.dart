import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
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

    // Ask for filename
    final filenameController = TextEditingController(text: 'wordor_export');

    final fileName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export CSV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a file name, then pick where to save or share it.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: filenameController,
              decoration: const InputDecoration(
                labelText: 'File name',
                suffixText: '.csv',
                isDense: true,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = filenameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx, name);
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      filenameController.dispose();
    });

    if (fileName == null || !mounted) return;

    try {
      final safeName = '${fileName.replaceAll(RegExp(r'[^\w\-. ]'), '_')}.csv';

      // Write to a temp file, then open the native share sheet
      // so the user can pick: Save to Downloads, Drive, email, etc.
      final dir = await getApplicationCacheDirectory();
      final tempFile = File(path.join(dir.path, safeName));
      await tempFile.writeAsString(csv);

      final xFile = XFile(tempFile.path, mimeType: 'text/csv');
      await Share.shareXFiles([xFile], subject: safeName);
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
    String? csvContent;
    String sourceLang = 'EN';
    String targetLang = 'EN';
    final pasteController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Import from CSV'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Format: front,back or front,back,tags',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Pick file button ──
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['csv', 'txt'],
                        );
                        if (picked != null &&
                            picked.files.single.path != null) {
                          final file = File(picked.files.single.path!);
                          final content = await file.readAsString();
                          setDialogState(() {
                            csvContent = content;
                            pasteController.text = '';
                          });
                        }
                      },
                      icon: const Icon(Icons.file_open_outlined, size: 18),
                      label: Text(
                        csvContent != null
                            ? 'File loaded ✓ (tap to change)'
                            : 'Choose CSV file',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: csvContent != null
                              ? Theme.of(ctx).colorScheme.primary
                              : Theme.of(ctx).dividerColor,
                        ),
                      ),
                    ),
                  ),

                  // ── OR divider ──
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),

                  // ── Paste field (smaller) ──
                  TextField(
                    controller: pasteController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Paste CSV content here...',
                      hintStyle: const TextStyle(fontSize: 13),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.all(12),
                      isDense: true,
                      suffixIcon: pasteController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setDialogState(() {
                                  pasteController.clear();
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (v) {
                      setDialogState(() {
                        if (v.trim().isNotEmpty) {
                          csvContent = null; // prefer paste over file
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // ── Language selectors ──
                  Text(
                    'Languages',
                    style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _LanguageDropdown(
                          label: 'Source',
                          value: sourceLang,
                          onChanged: (v) =>
                              setDialogState(() => sourceLang = v),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Expanded(
                        child: _LanguageDropdown(
                          label: 'Target',
                          value: targetLang,
                          onChanged: (v) =>
                              setDialogState(() => targetLang = v),
                        ),
                      ),
                    ],
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
                  final content = pasteController.text.trim().isNotEmpty
                      ? pasteController.text
                      : csvContent;
                  if (content == null || content.trim().isEmpty) return;
                  Navigator.pop(ctx, {
                    'content': content,
                    'sourceLang': sourceLang,
                    'targetLang': targetLang,
                  });
                },
                child: const Text('Import'),
              ),
            ],
          );
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      pasteController.dispose();
    });

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

// ── Searchable language dropdown for import dialog ───────────────────

class _LanguageDropdown extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  static const Map<String, String> _allLanguages = {
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

  const _LanguageDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final langName = _allLanguages[value] ?? value;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      onTap: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) =>
              _LanguageSearchSheet(selected: value, languages: _allLanguages),
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outline.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$value – $langName',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.expand_more, size: 18, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet with search for language selection ───────────────────

class _LanguageSearchSheet extends StatefulWidget {
  final String selected;
  final Map<String, String> languages;

  const _LanguageSearchSheet({required this.selected, required this.languages});

  @override
  State<_LanguageSearchSheet> createState() => _LanguageSearchSheetState();
}

class _LanguageSearchSheetState extends State<_LanguageSearchSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<MapEntry<String, String>> get _filtered {
    if (_query.isEmpty) return widget.languages.entries.toList();
    final q = _query.toLowerCase();
    return widget.languages.entries.where((e) {
      return e.value.toLowerCase().contains(q) ||
          e.key.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final filtered = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name or code...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),

          // Language list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No languages found',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final entry = filtered[i];
                      final isSelected = entry.key == widget.selected;
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.primary.withOpacity(0.1)
                                : colors.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: isSelected
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          entry.value,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: colors.primary,
                                size: 22,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, entry.key),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
