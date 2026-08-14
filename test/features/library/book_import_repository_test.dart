import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
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

  test('rejects oversized files before reading their contents', () async {
    final repository = BookImportRepository(
      database: database,
      txtParser: const FakeBookParser(),
      epubParser: const FakeBookParser(),
    );
    final file = PlatformFile(
      name: 'oversized.txt',
      size: BookImportRepository.maxFileBytes + 1,
      bytes: Uint8List(0),
    );

    await expectLater(repository.importFile(file), throwsA(isA<AppFailure>()));
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
    expect(firstParagraphs.map((paragraph) => paragraph.paragraphIndex), [
      0,
      1,
      2,
    ]);
    expect(firstParagraphs.map((paragraph) => paragraph.content), [
      '第一段',
      '第二段',
      '第三段',
    ]);
  });

  test('writes parsed paragraphs through Drift batches', () async {
    final interceptor = _StatementCountingInterceptor();
    await database.close();
    database = AppDatabase.forTesting(
      NativeDatabase.memory().interceptWith(interceptor),
    );
    final repository = BookImportRepository(
      database: database,
      txtParser: const FakeBookParser(),
      epubParser: const FakeBookParser(),
    );

    final bookId = await repository.importBytes(
      Uint8List(0),
      fileName: '测试.epub',
    );

    final chapters = await database.chaptersForBook(bookId);
    final secondParagraphs = await database.paragraphsForChapter(
      chapters.last.id,
    );
    expect(interceptor.batchedCalls, 2);
    expect(interceptor.insertCalls, 3);
    expect(secondParagraphs.map((paragraph) => paragraph.content), ['第二段']);
  });

  test('rolls back the whole book when a paragraph batch fails', () async {
    final interceptor = _StatementCountingInterceptor(failOnBatch: 2);
    await database.close();
    database = AppDatabase.forTesting(
      NativeDatabase.memory().interceptWith(interceptor),
    );
    final repository = BookImportRepository(
      database: database,
      txtParser: const FakeBookParser(),
      epubParser: const FakeBookParser(),
    );

    await expectLater(
      repository.importBytes(Uint8List(0), fileName: '测试.epub'),
      throwsStateError,
    );

    expect(await database.select(database.books).get(), isEmpty);
    expect(await database.select(database.chapters).get(), isEmpty);
    expect(await database.select(database.paragraphs).get(), isEmpty);
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
    final file = PlatformFile(name: '测试.txt', size: 0, bytes: Uint8List(0));

    final bookId = await repository.importFile(file);

    expect((await database.chaptersForBook(bookId)).length, 2);
  });

  test(
    'imports a mobile picker file when only its path is available',
    () async {
      final repository = BookImportRepository(
        database: database,
        txtParser: const FakeBookParser(),
        epubParser: const FakeBookParser(),
      );
      final directory = await Directory.systemTemp.createTemp(
        'novel-reader-import-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final source = File('${directory.path}${Platform.pathSeparator}测试.epub');
      await source.writeAsBytes(const [1, 2, 3]);
      final file = PlatformFile(
        name: '测试.epub',
        path: source.path,
        size: await source.length(),
      );

      final bookId = await repository.importFile(file);

      expect((await database.chaptersForBook(bookId)).length, 2);
    },
  );
}

final class _StatementCountingInterceptor extends QueryInterceptor {
  _StatementCountingInterceptor({this.failOnBatch});

  final int? failOnBatch;
  int batchedCalls = 0;
  int insertCalls = 0;

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) {
    batchedCalls++;
    if (batchedCalls == failOnBatch) {
      throw StateError('Injected paragraph batch failure.');
    }
    return super.runBatched(executor, statements);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    insertCalls++;
    return super.runInsert(executor, statement, args);
  }
}

final class FakeBookParser implements BookParser {
  const FakeBookParser();

  @override
  Future<ParsedBook> parse(Uint8List bytes, String fileName) async {
    return const ParsedBook(
      title: '测试书',
      chapters: [
        ParsedChapter(title: '第一章', paragraphs: ['第一段', '第二段', '第三段']),
        ParsedChapter(title: '第二章', paragraphs: ['第二段']),
      ],
    );
  }
}
