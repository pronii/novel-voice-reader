import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/library/domain/book_parser.dart';

final class BookImportRepository {
  static const maxFileBytes = 100 * 1024 * 1024;

  const BookImportRepository({
    required this.database,
    required this.txtParser,
    required this.epubParser,
  });

  final AppDatabase database;
  final BookParser txtParser;
  final BookParser epubParser;

  Future<int> importFile(PlatformFile file) async {
    _validateFileSize(file.size);
    final inlineBytes = file.bytes;
    if (inlineBytes != null) {
      return importBytes(inlineBytes, fileName: file.name);
    }
    _validateFileSize(await file.xFile.length());
    final bytes = await file.xFile.readAsBytes();
    return importBytes(bytes, fileName: file.name);
  }

  Future<int> importBytes(Uint8List bytes, {required String fileName}) async {
    _validateFileSize(bytes.length);
    final extension = fileName.split('.').last.toLowerCase();
    final parser = switch (extension) {
      'txt' => txtParser,
      'epub' => epubParser,
      _ => throw UnsupportedError('Unsupported book format: .$extension'),
    };
    final parsed = await parser.parse(bytes, fileName);

    return database.transaction(() async {
      final bookId = await database
          .into(database.books)
          .insert(
            BooksCompanion.insert(
              title: parsed.title,
              sourceType: Value(extension),
              sourceFileName: Value(fileName),
            ),
          );
      for (final chapterEntry in parsed.chapters.indexed) {
        final chapter = chapterEntry.$2;
        final chapterId = await database
            .into(database.chapters)
            .insert(
              ChaptersCompanion.insert(
                bookId: bookId,
                chapterIndex: chapterEntry.$1,
                title: chapter.title,
              ),
            );
        final paragraphs = [
          for (final paragraphEntry in chapter.paragraphs.indexed)
            ParagraphsCompanion.insert(
              chapterId: chapterId,
              paragraphIndex: paragraphEntry.$1,
              content: paragraphEntry.$2,
            ),
        ];
        if (paragraphs.isNotEmpty) {
          await database.batch((batch) {
            batch.insertAll(database.paragraphs, paragraphs);
          });
        }
      }
      return bookId;
    });
  }

  static void _validateFileSize(int bytes) {
    if (bytes > maxFileBytes) {
      throw const AppFailure('图书文件超过 100 MB，请先压缩或拆分');
    }
  }
}
