import 'package:drift/drift.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_coordinator.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';

final class DriftPlaybackProgressRepository
    implements PlaybackProgressRepository {
  const DriftPlaybackProgressRepository({
    required this.database,
    required this.bookId,
  });

  final AppDatabase database;
  final int bookId;

  @override
  Future<void> confirm(PlaybackCursor cursor) {
    return database.upsertProgress(
      bookId: bookId,
      chapterId: cursor.chapterId,
      paragraphIndex: cursor.paragraphIndex,
    );
  }

  Future<PlaybackCursor?> restore() async {
    final progress = await database.progressForBook(bookId);
    if (progress == null) {
      return null;
    }
    return PlaybackCursor(
      chapterId: progress.chapterId,
      paragraphIndex: progress.paragraphIndex,
    );
  }
}

final class DriftPlaybackParagraphSource implements PlaybackParagraphSource {
  const DriftPlaybackParagraphSource(this._database);

  final AppDatabase _database;

  @override
  Future<PlaybackParagraph?> at(PlaybackCursor cursor) async {
    final record =
        await (_database.select(_database.paragraphs)..where(
              (paragraph) =>
                  paragraph.chapterId.equals(cursor.chapterId) &
                  paragraph.paragraphIndex.equals(cursor.paragraphIndex),
            ))
            .getSingleOrNull();
    if (record == null) {
      return null;
    }
    return PlaybackParagraph(
      id: record.id,
      cursor: cursor,
      text: record.content,
    );
  }

  @override
  Future<PlaybackParagraph?> nextAfter(PlaybackCursor cursor) async {
    final sameChapter = await at(
      PlaybackCursor(
        chapterId: cursor.chapterId,
        paragraphIndex: cursor.paragraphIndex + 1,
      ),
    );
    if (sameChapter != null) {
      return sameChapter;
    }
    final currentChapter =
        await (_database.select(_database.chapters)
              ..where((chapter) => chapter.id.equals(cursor.chapterId)))
            .getSingleOrNull();
    if (currentChapter == null) {
      return null;
    }
    final nextChapter =
        await (_database.select(_database.chapters)..where(
              (chapter) =>
                  chapter.bookId.equals(currentChapter.bookId) &
                  chapter.chapterIndex.equals(currentChapter.chapterIndex + 1),
            ))
            .getSingleOrNull();
    if (nextChapter == null) {
      return null;
    }
    return at(PlaybackCursor(chapterId: nextChapter.id, paragraphIndex: 0));
  }
}
