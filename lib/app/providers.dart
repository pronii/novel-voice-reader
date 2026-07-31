import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_handler.dart';
import 'package:novel_voice_reader/features/reader/presentation/reader_page.dart';

final databaseProvider = Provider<AppDatabase?>((ref) => null);
final playbackRuntimeProvider = Provider<PlaybackRuntime?>((ref) => null);

final libraryBooksProvider = StreamProvider<List<BookRecord>>((ref) {
  final database = ref.watch(databaseProvider);
  if (database == null) {
    return Stream.value(const []);
  }
  final query = database.select(database.books)
    ..orderBy([
      (book) => OrderingTerm(
        expression: book.lastReadAt,
        mode: OrderingMode.desc,
        nulls: NullsOrder.last,
      ),
      (book) => OrderingTerm.desc(book.importedAt),
    ]);
  return query.watch();
});

final readerPageDataProvider = FutureProvider.family<ReaderPageData, int>((
  ref,
  bookId,
) async {
  final database = ref.watch(databaseProvider);
  if (database == null) {
    throw StateError('Database is unavailable.');
  }
  final book = await (database.select(
    database.books,
  )..where((row) => row.id.equals(bookId))).getSingle();
  final chapters = await database.chaptersForBook(bookId);
  if (chapters.isEmpty) {
    return ReaderPageData(
      book: book,
      chapter: null,
      paragraphs: const [],
      activeParagraphId: null,
    );
  }
  final progress = await database.progressForBook(bookId);
  final chapter = progress == null
      ? chapters.first
      : chapters.firstWhere(
          (candidate) => candidate.id == progress.chapterId,
          orElse: () => chapters.first,
        );
  final records = await database.paragraphsForChapter(chapter.id);
  final activeIndex = (progress?.paragraphIndex ?? 0).clamp(
    0,
    records.isEmpty ? 0 : records.length - 1,
  );
  return ReaderPageData(
    book: book,
    chapter: chapter,
    paragraphs: [
      for (final record in records)
        ReaderParagraph(
          id: record.id,
          index: record.paragraphIndex,
          text: record.content,
        ),
    ],
    activeParagraphId: records.isEmpty ? null : records[activeIndex].id,
  );
});

final class ReaderPageData {
  const ReaderPageData({
    required this.book,
    required this.chapter,
    required this.paragraphs,
    required this.activeParagraphId,
  });

  final BookRecord book;
  final ChapterRecord? chapter;
  final List<ReaderParagraph> paragraphs;
  final int? activeParagraphId;
}
