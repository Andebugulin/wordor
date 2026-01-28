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
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get saved => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Words, Recalls, TranslationHistory])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Create translation_history table if it doesn't exist
          await m.createTable(translationHistory);
        }
      },
      beforeOpen: (details) async {
        // Enable foreign keys
        await customStatement('PRAGMA foreign_keys = ON');

        // Check if translation_history exists, if not create it
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
              created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
              saved INTEGER NOT NULL DEFAULT 0
            )
          ''');
        }
      },
    );
  }

  // Get words due for review
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

  // Add new word with initial recall
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

  // Update recall after review
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

  // Get count of due words
  Future<int> getDueWordCount() async {
    final query = selectOnly(recalls)
      ..addColumns([recalls.id.count()])
      ..where(recalls.nextReview.isSmallerOrEqualValue(DateTime.now()));

    final result = await query.getSingle();
    return result.read(recalls.id.count()) ?? 0;
  }

  // Add translation to history
  Future<void> addToHistory(TranslationHistoryCompanion history) async {
    await into(translationHistory).insert(history);
  }

  // Get translation history
  Future<List<TranslationHistoryData>> getHistory({int limit = 50}) async {
    return (select(translationHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  // Check if a word is saved for recall
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

  // Clear history
  Future<void> clearHistory() async {
    await delete(translationHistory).go();
  }

  // Get all saved words
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

  // Search words
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

  // Delete word
  Future<void> deleteWord(int wordId) async {
    await (delete(words)..where((w) => w.id.equals(wordId))).go();
  }

  // Make all words due now (for testing)
  Future<void> makeAllWordsDueNow() async {
    await (update(recalls)).write(
      RecallsCompanion(
        nextReview: Value(DateTime.now().subtract(const Duration(hours: 1))),
      ),
    );
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
