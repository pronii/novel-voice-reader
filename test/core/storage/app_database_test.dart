import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('deleting a book cascades to chapters and paragraphs', () async {
    final bookId = await database.createBookWithChapter(
      title: '测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段', '第二段'],
    );

    await database.deleteBookById(bookId);

    expect(await database.paragraphCountForBook(bookId), 0);
  });

  test('upserting progress keeps only the latest cursor', () async {
    final bookId = await database.createBookWithChapter(
      title: '测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段', '第二段'],
    );
    final chapter = await database.firstChapterForBook(bookId);

    await database.upsertProgress(
      bookId: bookId,
      chapterId: chapter.id,
      paragraphIndex: 0,
    );
    await database.upsertProgress(
      bookId: bookId,
      chapterId: chapter.id,
      paragraphIndex: 1,
    );

    final progress = await database.progressForBook(bookId);
    expect(progress?.paragraphIndex, 1);
  });
}
