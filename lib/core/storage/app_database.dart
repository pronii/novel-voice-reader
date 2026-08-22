import 'package:drift/drift.dart';

part 'app_database.g.dart';

@DataClassName('BookRecord')
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get sourceType => text().withDefault(const Constant('txt'))();
  TextColumn get sourceFileName => text().nullable()();
  DateTimeColumn get importedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastReadAt => dateTime().nullable()();
}

@DataClassName('ChapterRecord')
class Chapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterIndex => integer()();
  TextColumn get title => text()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {bookId, chapterIndex},
  ];
}

@DataClassName('ParagraphRecord')
class Paragraphs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get chapterId =>
      integer().references(Chapters, #id, onDelete: KeyAction.cascade)();
  IntColumn get paragraphIndex => integer()();
  TextColumn get content => text()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {chapterId, paragraphIndex},
  ];
}

@DataClassName('ReadingProgressRecord')
class ReadingProgresses extends Table {
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterId =>
      integer().references(Chapters, #id, onDelete: KeyAction.cascade)();
  IntColumn get paragraphIndex => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {bookId};
}

@DataClassName('VoiceProfileRecord')
class VoiceProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get providerType => text()();
  TextColumn get baseUrl => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get voice => text().nullable()();
  RealColumn get speed => real().withDefault(const Constant(1))();
  RealColumn get pitch => real().nullable()();
  TextColumn get outputFormat => text().nullable()();
  TextColumn get style => text().nullable()();
}

@DataClassName('DownloadPolicyRecord')
class DownloadPolicies extends Table {
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get chaptersAhead => integer().withDefault(const Constant(0))();
  BoolColumn get wholeBook => boolean().withDefault(const Constant(false))();
  BoolColumn get wifiOnly => boolean().withDefault(const Constant(true))();
  IntColumn get maxCacheBytes => integer()();

  @override
  Set<Column<Object>> get primaryKey => {bookId};
}

@DataClassName('AudioCacheRecord')
class AudioCacheEntries extends Table {
  TextColumn get cacheKey => text()();
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterId =>
      integer().references(Chapters, #id, onDelete: KeyAction.cascade)();
  IntColumn get paragraphId =>
      integer().references(Paragraphs, #id, onDelete: KeyAction.cascade)();
  TextColumn get filePath => text()();
  IntColumn get byteSize => integer()();
  TextColumn get status => text()();
  DateTimeColumn get lastAccessedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {cacheKey};
}

@DataClassName('DownloadJobRecord')
class DownloadJobs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get paragraphId =>
      integer().references(Paragraphs, #id, onDelete: KeyAction.cascade)();
  TextColumn get cacheKey => text()();
  IntColumn get priority => integer()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {cacheKey},
  ];
}

@DataClassName('TencentTtsMonthlyUsageRecord')
class TencentTtsMonthlyUsages extends Table {
  TextColumn get period => text()();
  IntColumn get usedCharacters => integer().withDefault(const Constant(0))();
  IntColumn get quotaCharacters => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {period};
}

@DriftDatabase(
  tables: [
    Books,
    Chapters,
    Paragraphs,
    ReadingProgresses,
    VoiceProfiles,
    DownloadPolicies,
    AudioCacheEntries,
    DownloadJobs,
    TencentTtsMonthlyUsages,
  ],
)
final class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.forTesting(QueryExecutor executor) =>
      AppDatabase(executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createAudioCacheIndexes();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(tencentTtsMonthlyUsages);
      }
      if (from < 3) {
        await migrator.addColumn(voiceProfiles, voiceProfiles.style);
      }
      if (from < 4) {
        await _createAudioCacheIndexes();
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Pruning and cache-size accounting scan cache rows filtered by
  /// `(bookId, status)`; without this index every prune (and it runs after each
  /// synthesized segment) is a full-table scan over the whole cache.
  ///
  /// Guarded by a table-existence check: real installs created
  /// `audio_cache_entries` at v1, but a partially-provisioned database (such as
  /// the minimal fixtures in the migration tests) must not fail to open here.
  Future<void> _createAudioCacheIndexes() async {
    final table = await customSelect(
      "SELECT 1 FROM sqlite_master "
      "WHERE type = 'table' AND name = 'audio_cache_entries'",
    ).get();
    if (table.isEmpty) {
      return;
    }
    await customStatement(
      'CREATE INDEX IF NOT EXISTS audio_cache_entries_book_status '
      'ON audio_cache_entries (book_id, status)',
    );
  }

  Future<int> createBookWithChapter({
    required String title,
    required String chapterTitle,
    required List<String> paragraphs,
  }) {
    return transaction(() async {
      final bookId = await into(
        books,
      ).insert(BooksCompanion.insert(title: title));
      final chapterId = await into(chapters).insert(
        ChaptersCompanion.insert(
          bookId: bookId,
          chapterIndex: 0,
          title: chapterTitle,
        ),
      );
      for (final entry in paragraphs.indexed) {
        await into(this.paragraphs).insert(
          ParagraphsCompanion.insert(
            chapterId: chapterId,
            paragraphIndex: entry.$1,
            content: entry.$2,
          ),
        );
      }
      return bookId;
    });
  }

  Future<void> deleteBookById(int bookId) async {
    await (delete(books)..where((book) => book.id.equals(bookId))).go();
  }

  Future<int> paragraphCountForBook(int bookId) async {
    final count = paragraphs.id.count();
    final query = selectOnly(paragraphs)
      ..addColumns([count])
      ..join([innerJoin(chapters, chapters.id.equalsExp(paragraphs.chapterId))])
      ..where(chapters.bookId.equals(bookId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<ChapterRecord> firstChapterForBook(int bookId) {
    final query = select(chapters)
      ..where((chapter) => chapter.bookId.equals(bookId))
      ..orderBy([(chapter) => OrderingTerm.asc(chapter.chapterIndex)])
      ..limit(1);
    return query.getSingle();
  }

  Future<List<ChapterRecord>> chaptersForBook(int bookId) {
    final query = select(chapters)
      ..where((chapter) => chapter.bookId.equals(bookId))
      ..orderBy([(chapter) => OrderingTerm.asc(chapter.chapterIndex)]);
    return query.get();
  }

  Future<List<ParagraphRecord>> paragraphsForChapter(int chapterId) {
    final query = select(paragraphs)
      ..where((paragraph) => paragraph.chapterId.equals(chapterId))
      ..orderBy([(paragraph) => OrderingTerm.asc(paragraph.paragraphIndex)]);
    return query.get();
  }

  Future<void> upsertProgress({
    required int bookId,
    required int chapterId,
    required int paragraphIndex,
  }) async {
    await into(readingProgresses).insertOnConflictUpdate(
      ReadingProgressesCompanion.insert(
        bookId: Value(bookId),
        chapterId: chapterId,
        paragraphIndex: paragraphIndex,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<ReadingProgressRecord?> progressForBook(int bookId) {
    return (select(
      readingProgresses,
    )..where((progress) => progress.bookId.equals(bookId))).getSingleOrNull();
  }
}
