import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/app/providers.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_content.dart';

void main() {
  test('reader data restores all chapter metadata and the saved cursor', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final bookId = await database.createBookWithChapter(
      title: '测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。', '第二段。', '第三段。'],
    );
    final firstChapter = await database.firstChapterForBook(bookId);
    final secondChapterId = await database
        .into(database.chapters)
        .insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            chapterIndex: 1,
            title: '第二章',
          ),
        );
    await database
        .into(database.paragraphs)
        .insert(
          ParagraphsCompanion.insert(
            chapterId: secondChapterId,
            paragraphIndex: 0,
            content: '第二章第一段。',
          ),
        );
    await database.upsertProgress(
      bookId: bookId,
      chapterId: secondChapterId,
      paragraphIndex: 0,
    );
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    final data = await container.read(
      readerPageDataProvider(ReaderPageRequest(bookId)).future,
    );

    expect(data.chapters.map((chapter) => chapter.id), [
      firstChapter.id,
      secondChapterId,
    ]);
    expect(
      data.savedCursor,
      PlaybackCursor(chapterId: secondChapterId, paragraphIndex: 0),
    );
  });

  test(
    'reader data reloads progress after its last listener is released',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final bookId = await database.createBookWithChapter(
        title: '测试书',
        chapterTitle: '第一章',
        paragraphs: const ['第一段。', '第二段。', '第三段。'],
      );
      final chapter = await database.firstChapterForBook(bookId);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);
      final provider = readerPageDataProvider(ReaderPageRequest(bookId));
      final firstListener = container.listen(provider, (_, _) {});

      final first = await container.read(provider.future);
      expect(
        first.savedCursor,
        PlaybackCursor(chapterId: chapter.id, paragraphIndex: 0),
      );

      await database.upsertProgress(
        bookId: bookId,
        chapterId: chapter.id,
        paragraphIndex: 2,
      );
      firstListener.close();
      await container.pump();

      final secondListener = container.listen(provider, (_, _) {});
      addTearDown(secondListener.close);
      final reopened = await container.read(provider.future);

      expect(
        reopened.savedCursor,
        PlaybackCursor(chapterId: chapter.id, paragraphIndex: 2),
      );
    },
  );

  test('loads a chapter section with chapter-owned paragraphs', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final bookId = await database.createBookWithChapter(
      title: '测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。', '第二段。'],
    );
    final record = await database.firstChapterForBook(bookId);
    final chapter = ReaderChapter(
      id: record.id,
      index: record.chapterIndex,
      title: record.title,
    );

    final section = await loadReaderChapterSection(database, chapter);

    expect(section.chapter, same(chapter));
    expect(section.paragraphs.map((paragraph) => paragraph.chapterId), [
      chapter.id,
      chapter.id,
    ]);
    expect(section.paragraphs.map((paragraph) => paragraph.index), [0, 1]);
  });
}
