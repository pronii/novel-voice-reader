import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';

// The private field is initialized from a public named parameter, which cannot
// be a `this._field` initializing formal (named params may not be private).
// ignore_for_file: prefer_initializing_formals

/// Local file that stores a book's fetched cover image, mirroring the layout of
/// `audioCacheDirectoryForBook`: one predictable path per book under the app's
/// support directory.
File coverImageFile(Directory supportDirectory, int bookId) {
  return File(
    '${supportDirectory.path}${Platform.pathSeparator}covers'
    '${Platform.pathSeparator}book-$bookId',
  );
}

typedef SupportDirectoryLoader = Future<Directory> Function();

/// Fetches book covers from the self-hosted cover proxy (`{baseUrl}/cover`) and
/// stores them on disk, so imported novels can show real artwork instead of the
/// generated placeholder `BookCover`.
///
/// Every step is best-effort: a miss (HTTP 404) or any network/IO error simply
/// stamps the attempt time via [AppDatabase.markBookCoverFetched], so the book
/// is not re-requested until the retry window elapses and the UI keeps showing
/// the placeholder. Only a real image is persisted, via
/// [AppDatabase.setBookCover].
final class CoverRepository {
  CoverRepository({
    required this.database,
    required this.dio,
    required SupportDirectoryLoader supportDirectory,
  }) : _supportDirectory = supportDirectory;

  final AppDatabase database;
  final Dio dio;
  final SupportDirectoryLoader _supportDirectory;

  /// Guards against overlapping runs: the library page triggers a fetch on
  /// every load, but a run already in flight already covers the same books.
  bool _running = false;

  /// Fetches covers for every book that has none yet and whose last attempt (if
  /// any) is older than [retryWindow]. Books are processed serially to avoid
  /// hammering the server. Safe to call repeatedly; a concurrent call is a
  /// no-op.
  Future<void> fetchMissingCovers({
    required String baseUrl,
    Duration retryWindow = const Duration(days: 7),
  }) async {
    if (_running || baseUrl.isEmpty) {
      return;
    }
    _running = true;
    try {
      final cutoff = DateTime.now().subtract(retryWindow);
      final pending =
          await (database.select(database.books)..where(
                (book) =>
                    book.coverImagePath.isNull() &
                    (book.coverFetchedAt.isNull() |
                        book.coverFetchedAt.isSmallerThanValue(cutoff)),
              ))
              .get();
      for (final book in pending) {
        await _fetchOne(book, baseUrl);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _fetchOne(BookRecord book, String baseUrl) async {
    try {
      final response = await dio.get<List<int>>(
        '$baseUrl/cover',
        queryParameters: {'title': book.title},
        options: Options(
          responseType: ResponseType.bytes,
          // A missing cover is a normal 404; accept any <500 status as a real
          // response so a miss falls through to markBookCoverFetched below
          // rather than throwing.
          validateStatus: (status) => status != null && status < 500,
          // Covers are small; no need for the long synthesis receive timeout.
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final bytes = response.data;
      if (response.statusCode == 200 && bytes != null && bytes.isNotEmpty) {
        final support = await _supportDirectory();
        final file = coverImageFile(support, book.id);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
        await database.setBookCover(bookId: book.id, path: file.path);
        return;
      }
    } catch (_) {
      // Network / timeout / IO failure: fall through to stamp the attempt so we
      // back off until the retry window elapses.
    }
    await database.markBookCoverFetched(book.id);
  }
}
