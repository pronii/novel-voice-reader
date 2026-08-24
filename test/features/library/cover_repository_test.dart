import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/library/data/cover_repository.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late AppDatabase database;
  late _MockDio dio;
  late Directory tempDir;
  late CoverRepository repository;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    dio = _MockDio();
    tempDir = Directory.systemTemp.createTempSync('cover_repository_test');
    repository = CoverRepository(
      database: database,
      dio: dio,
      supportDirectory: () async => tempDir,
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<int> insertBook(String title) {
    return database
        .into(database.books)
        .insert(BooksCompanion.insert(title: title));
  }

  Future<BookRecord> fetchBook(int id) {
    return (database.select(database.books)
          ..where((book) => book.id.equals(id)))
        .getSingle();
  }

  void stubResponse(int statusCode, List<int> body) {
    when(
      () => dio.get<List<int>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<List<int>>(
        requestOptions: RequestOptions(path: '/cover'),
        statusCode: statusCode,
        data: body,
      ),
    );
  }

  test('stores a fetched cover and stamps the fetch time', () async {
    final bookId = await insertBook('三体');
    stubResponse(200, const [1, 2, 3, 4]);

    await repository.fetchMissingCovers(baseUrl: 'http://server.test');

    final book = await fetchBook(bookId);
    expect(book.coverImagePath, isNotNull);
    expect(book.coverFetchedAt, isNotNull);
    final file = File(book.coverImagePath!);
    expect(file.existsSync(), isTrue);
    expect(file.readAsBytesSync(), const [1, 2, 3, 4]);
  });

  test('marks the attempt but stores no cover on a 404 miss', () async {
    final bookId = await insertBook('冷门小说');
    stubResponse(404, const []);

    await repository.fetchMissingCovers(baseUrl: 'http://server.test');

    final book = await fetchBook(bookId);
    expect(book.coverImagePath, isNull);
    expect(book.coverFetchedAt, isNotNull);
  });

  test('marks the attempt when the request throws', () async {
    final bookId = await insertBook('网络故障');
    when(
      () => dio.get<List<int>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    ).thenThrow(
      DioException(requestOptions: RequestOptions(path: '/cover')),
    );

    await repository.fetchMissingCovers(baseUrl: 'http://server.test');

    final book = await fetchBook(bookId);
    expect(book.coverImagePath, isNull);
    expect(book.coverFetchedAt, isNotNull);
  });

  test('skips books whose last attempt is within the retry window', () async {
    final bookId = await insertBook('最近试过');
    // Stamps coverFetchedAt to "now", putting the book inside the window.
    await database.markBookCoverFetched(bookId);

    await repository.fetchMissingCovers(
      baseUrl: 'http://server.test',
      retryWindow: const Duration(days: 7),
    );

    verifyNever(
      () => dio.get<List<int>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    );
  });

  test('does nothing when the base URL is empty', () async {
    await insertBook('无服务器');

    await repository.fetchMissingCovers(baseUrl: '');

    verifyNever(
      () => dio.get<List<int>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        options: any(named: 'options'),
      ),
    );
  });
}
