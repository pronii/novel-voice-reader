import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/reader/data/reading_progress_repository.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';

void main() {
  test(
    'restores the last confirmed cursor after a simulated restart',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final bookId = await database.createBookWithChapter(
        title: '测试书',
        chapterTitle: '第一章',
        paragraphs: const ['第一段。', '第二段。'],
      );
      final chapter = await database.firstChapterForBook(bookId);
      final firstSession = DriftPlaybackProgressRepository(
        database: database,
        bookId: bookId,
      );
      const cursor = PlaybackCursor(chapterId: 1, paragraphIndex: 1);

      await firstSession.confirm(
        PlaybackCursor(
          chapterId: chapter.id,
          paragraphIndex: cursor.paragraphIndex,
        ),
      );
      final restartedSession = DriftPlaybackProgressRepository(
        database: database,
        bookId: bookId,
      );

      expect(
        await restartedSession.restore(),
        PlaybackCursor(chapterId: chapter.id, paragraphIndex: 1),
      );
    },
  );

  test('counts remaining text only through the current chapter end', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final bookId = await database.createBookWithChapter(
      title: '测试书',
      chapterTitle: '第一章',
      paragraphs: const ['跳过', '当前', '末段三字'],
    );
    final firstChapter = await database.firstChapterForBook(bookId);
    final secondChapterId = await database.into(database.chapters).insert(
      ChaptersCompanion.insert(
        bookId: bookId,
        chapterIndex: 1,
        title: '第二章',
      ),
    );
    await database.into(database.paragraphs).insert(
      ParagraphsCompanion.insert(
        chapterId: secondChapterId,
        paragraphIndex: 0,
        content: '不计入下一章',
      ),
    );
    final source = DriftPlaybackParagraphSource(database);

    final characters = await source.remainingCharactersInChapter(
      PlaybackCursor(chapterId: firstChapter.id, paragraphIndex: 1),
    );

    expect(characters, 6);
  });
}
