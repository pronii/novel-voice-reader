import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/app/providers.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';

void main() {
  test('reader data restores the saved paragraph id', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final bookId = await database.createBookWithChapter(
      title: '测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。', '第二段。', '第三段。'],
    );
    final chapter = await database.firstChapterForBook(bookId);
    await database.upsertProgress(
      bookId: bookId,
      chapterId: chapter.id,
      paragraphIndex: 1,
    );
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    final data = await container.read(
      readerPageDataProvider(ReaderPageRequest(bookId)).future,
    );

    expect(data.activeParagraphId, data.paragraphs[1].id);
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
      expect(first.activeParagraphId, first.paragraphs.first.id);

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

      expect(reopened.activeParagraphId, reopened.paragraphs[2].id);
    },
  );
}
