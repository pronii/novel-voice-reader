import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/library/data/book_import_repository.dart';
import 'package:novel_voice_reader/features/library/domain/book_parser.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('imports every parsed chapter and paragraph in one book', () async {
    final repository = BookImportRepository(
      database: database,
      txtParser: const FakeBookParser(),
      epubParser: const FakeBookParser(),
    );

    final bookId = await repository.importBytes(
      Uint8List(0),
      fileName: '测试.txt',
    );

    final chapters = await database.chaptersForBook(bookId);
    final firstParagraphs = await database.paragraphsForChapter(
      chapters.first.id,
    );
    expect(chapters.map((chapter) => chapter.title), ['第一章', '第二章']);
    expect(firstParagraphs.map((paragraph) => paragraph.content), ['第一段']);
  });

  test('rejects unsupported file extensions before parsing', () async {
    final repository = BookImportRepository(
      database: database,
      txtParser: const FakeBookParser(),
      epubParser: const FakeBookParser(),
    );

    expect(
      () => repository.importBytes(Uint8List(0), fileName: '测试.pdf'),
      throwsUnsupportedError,
    );
  });

  test('imports bytes supplied by the system file picker', () async {
    final repository = BookImportRepository(
      database: database,
      txtParser: const FakeBookParser(),
      epubParser: const FakeBookParser(),
    );
    final file = PlatformFile(
      name: '测试.txt',
      size: 0,
      bytes: Uint8List(0),
    );

    final bookId = await repository.importFile(file);

    expect((await database.chaptersForBook(bookId)).length, 2);
  });
}

final class FakeBookParser implements BookParser {
  const FakeBookParser();

  @override
  Future<ParsedBook> parse(Uint8List bytes, String fileName) async {
    return const ParsedBook(
      title: '测试书',
      chapters: [
        ParsedChapter(title: '第一章', paragraphs: ['第一段']),
        ParsedChapter(title: '第二章', paragraphs: ['第二段']),
      ],
    );
  }
}
