import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// Words table
class Words extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get source => text()();
  TextColumn get translation => text()();
  TextColumn get sourceLang => text()();
  TextColumn get targetLang => text()();
  TextColumn get example => text().nullable()();
  TextColumn get exampleTranslation => text().nullable()();
  TextColumn get sourceTranscription => text().nullable()();
  TextColumn get targetTranscription => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Recalls table
class Recalls extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get wordId =>
      integer().references(Words, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get nextReview => dateTime()();
  IntColumn get intervalDays => integer().withDefault(const Constant(1))();
  RealColumn get ease => real().withDefault(const Constant(2.5))();
  IntColumn get reviewCount => integer().withDefault(const Constant(0))();
}

// Translation history table
class TranslationHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get source => text()();
  TextColumn get translation => text()();
  TextColumn get sourceLang => text()();
  TextColumn get targetLang => text()();
  TextColumn get sourceTranscription => text().nullable()();
  TextColumn get targetTranscription => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get saved => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Words, Recalls, TranslationHistory])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(translationHistory);
        }
        if (from < 3) {
          await m.addColumn(words, words.sourceTranscription);
          await m.addColumn(
            translationHistory,
            translationHistory.sourceTranscription,
          );
        }
        if (from < 4) {
          await m.addColumn(words, words.targetTranscription);
          await m.addColumn(
            translationHistory,
            translationHistory.targetTranscription,
          );
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');

        final result = await customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='translation_history'",
        ).get();

        if (result.isEmpty) {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS translation_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              source TEXT NOT NULL,
              translation TEXT NOT NULL,
              source_lang TEXT NOT NULL,
              target_lang TEXT NOT NULL,
              source_transcription TEXT,
              target_transcription TEXT,
              created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
              saved INTEGER NOT NULL DEFAULT 0
            )
          ''');
        }

        // Add columns if they don't exist (safe idempotent migration)
        for (final stmt in [
          'ALTER TABLE words ADD COLUMN source_transcription TEXT',
          'ALTER TABLE words ADD COLUMN target_transcription TEXT',
          'ALTER TABLE translation_history ADD COLUMN source_transcription TEXT',
          'ALTER TABLE translation_history ADD COLUMN target_transcription TEXT',
        ]) {
          try {
            await customStatement(stmt);
          } catch (_) {}
        }
      },
    );
  }

  // ── Core CRUD ──────────────────────────────────────────────────────

  /// Get words due for review right now.
  Future<List<WordWithRecall>> getDueWords() async {
    final query = select(words).join([
      innerJoin(recalls, recalls.wordId.equalsExp(words.id)),
    ])..where(recalls.nextReview.isSmallerOrEqualValue(DateTime.now()));

    final results = await query.get();
    return results.map((row) {
      return WordWithRecall(
        word: row.readTable(words),
        recall: row.readTable(recalls),
      );
    }).toList();
  }

  /// Add new word with initial recall (due in 1 day).
  Future<int> addWord(WordsCompanion word) async {
    return transaction(() async {
      final wordId = await into(words).insert(word);

      await into(recalls).insert(
        RecallsCompanion.insert(
          wordId: wordId,
          nextReview: DateTime.now().add(const Duration(days: 1)),
        ),
      );

      return wordId;
    });
  }

  /// Update recall after review.
  Future<void> updateRecall(int recallId, bool success) async {
    final recall = await (select(
      recalls,
    )..where((r) => r.id.equals(recallId))).getSingle();

    final newInterval = success ? (recall.intervalDays * 2.5).round() : 1;

    await (update(recalls)..where((r) => r.id.equals(recallId))).write(
      RecallsCompanion(
        nextReview: Value(DateTime.now().add(Duration(days: newInterval))),
        intervalDays: Value(newInterval),
        reviewCount: Value(recall.reviewCount + 1),
      ),
    );
  }

  /// Get count of due words.
  Future<int> getDueWordCount() async {
    final query = selectOnly(recalls)
      ..addColumns([recalls.id.count()])
      ..where(recalls.nextReview.isSmallerOrEqualValue(DateTime.now()));

    final result = await query.getSingle();
    return result.read(recalls.id.count()) ?? 0;
  }

  // ── History ────────────────────────────────────────────────────────

  Future<void> addToHistory(TranslationHistoryCompanion history) async {
    await into(translationHistory).insert(history);
  }

  Future<List<TranslationHistoryData>> getHistory({int limit = 50}) async {
    return (select(translationHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<bool> isWordSaved(String source, String translation) async {
    final result =
        await (select(words)
              ..where(
                (w) =>
                    w.source.equals(source) & w.translation.equals(translation),
              )
              ..limit(1))
            .getSingleOrNull();
    return result != null;
  }

  Future<void> clearHistory() async {
    await delete(translationHistory).go();
  }

  // ── Library ────────────────────────────────────────────────────────

  Future<List<WordWithRecall>> getAllWords() async {
    final query = select(words).join([
      innerJoin(recalls, recalls.wordId.equalsExp(words.id)),
    ])..orderBy([OrderingTerm.desc(words.createdAt)]);

    final results = await query.get();
    return results.map((row) {
      return WordWithRecall(
        word: row.readTable(words),
        recall: row.readTable(recalls),
      );
    }).toList();
  }

  Future<List<WordWithRecall>> searchWords(String query) async {
    final searchQuery =
        select(
            words,
          ).join([innerJoin(recalls, recalls.wordId.equalsExp(words.id))])
          ..where(
            words.source.contains(query) | words.translation.contains(query),
          )
          ..orderBy([OrderingTerm.desc(words.createdAt)]);

    final results = await searchQuery.get();
    return results.map((row) {
      return WordWithRecall(
        word: row.readTable(words),
        recall: row.readTable(recalls),
      );
    }).toList();
  }

  Future<void> deleteWord(int wordId) async {
    await (delete(words)..where((w) => w.id.equals(wordId))).go();
  }

  Future<void> makeAllWordsDueNow() async {
    await (update(recalls)).write(
      RecallsCompanion(
        nextReview: Value(DateTime.now().subtract(const Duration(hours: 1))),
      ),
    );
  }

  // ── Anki Import / Export ───────────────────────────────────────────

  /// Export all saved words as CSV (compatible with Anki import).
  ///
  /// Format: `front,back,tags`
  /// where tags = `lang:SOURCE-TARGET`
  ///
  /// This can be imported into Anki via File → Import → select .csv.
  Future<String> exportToCsv() async {
    final allWords = await getAllWords();
    final buffer = StringBuffer();

    for (final wr in allWords) {
      final w = wr.word;
      final front = _escapeCsv(w.source);
      final back = _escapeCsv(w.translation);
      final tags = 'lang:${w.sourceLang}-${w.targetLang}';
      buffer.writeln('$front,$back,$tags');
    }

    return buffer.toString();
  }

  /// Import words from CSV text.
  ///
  /// Accepts `front,back` (2 columns) or `front,back,tags` (3+ columns).
  /// Tags like `lang:FI-EN` are parsed for language pair; if absent,
  /// [defaultSourceLang] and [defaultTargetLang] are used.
  ///
  /// Returns the number of words imported (duplicates are skipped).
  Future<int> importFromCsv(
    String csvContent, {
    String defaultSourceLang = 'EN',
    String defaultTargetLang = 'EN',
  }) async {
    final lines = csvContent
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();

    int imported = 0;

    for (final line in lines) {
      // Simple CSV parse: split on comma, but respect quoted fields
      final parts = _parseCsvLine(line);
      if (parts.length < 2) continue;

      final front = parts[0].trim();
      final back = parts[1].trim();

      if (front.isEmpty || back.isEmpty) continue;

      // Parse language from tags column if present
      String sourceLang = defaultSourceLang;
      String targetLang = defaultTargetLang;

      if (parts.length >= 3) {
        final tags = parts[2];
        final langMatch = RegExp(r'lang:(\w+)-(\w+)').firstMatch(tags);
        if (langMatch != null) {
          sourceLang = langMatch.group(1)!.toUpperCase();
          targetLang = langMatch.group(2)!.toUpperCase();
        }
      }

      // Skip duplicates
      final exists = await isWordSaved(front, back);
      if (exists) continue;

      await addWord(
        WordsCompanion(
          source: Value(front),
          translation: Value(back),
          sourceLang: Value(sourceLang),
          targetLang: Value(targetLang),
        ),
      );
      imported++;
    }

    return imported;
  }

  /// Escape a value for CSV: wrap in quotes if it contains comma, quote, or newline.
  static String _escapeCsv(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// Parse a single CSV line, respecting quoted fields.
  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++; // skip escaped quote
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(c);
        }
      } else {
        if (c == '"') {
          inQuotes = true;
        } else if (c == ',') {
          result.add(buffer.toString());
          buffer.clear();
        } else {
          buffer.write(c);
        }
      }
    }
    result.add(buffer.toString());
    return result;
  }
}

// Helper class for joined queries
class WordWithRecall {
  final Word word;
  final Recall recall;

  WordWithRecall({required this.word, required this.recall});
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'word_recall.sqlite'));
    return NativeDatabase(file);
  });
}
