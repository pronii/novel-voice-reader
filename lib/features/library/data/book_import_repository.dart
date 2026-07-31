import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/library/domain/book_parser.dart';

final class BookImportRepository {
  const BookImportRepository({
    required this.database,
    required this.txtParser,
    required this.epubParser,
  });

  final AppDatabase database;
  final BookParser txtParser;
  final BookParser epubParser;

  Future<int> importFile(PlatformFile file) {
    return importBytes(file.bytes!, fileName: file.name);
  }

  Future<int> importBytes(
    Uint8List bytes, {
    required String fileName,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();
    final parser = switch (extension) {
      'txt' => txtParser,
      'epub' => epubParser,
      _ => throw UnsupportedError('Unsupported book format: .$extension'),
    };
    final parsed = await parser.parse(bytes, fileName);

    return database.transaction(() async {
      final bookId = await database.into(database.books).insert(
        BooksCompanion.insert(
          title: parsed.title,
          sourceType: Value(extension),
          sourceFileName: Value(fileName),
        ),
      );
      for (final chapterEntry in parsed.chapters.indexed) {
        final chapter = chapterEntry.$2;
        final chapterId = await database.into(database.chapters).insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            chapterIndex: chapterEntry.$1,
            title: chapter.title,
          ),
        );
        for (final paragraphEntry in chapter.paragraphs.indexed) {
          await database.into(database.paragraphs).insert(
            ParagraphsCompanion.insert(
              chapterId: chapterId,
              paragraphIndex: paragraphEntry.$1,
              content: paragraphEntry.$2,
            ),
          );
        }
      }
      return bookId;
    });
  }
}
