import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:novel_voice_reader/features/library/domain/book_parser.dart';

final class EpubBookParser implements BookParser {
  const EpubBookParser();

  @override
  Future<ParsedBook> parse(Uint8List bytes, String fileName) async {
    final book = await EpubReader.readBook(bytes);
    final package = book.Schema?.Package;
    final manifestItems = package?.Manifest?.Items ?? const [];
    final manifestById = {
      for (final item in manifestItems)
        if (item.Id != null) item.Id!: item,
    };
    final htmlFiles = book.Content?.Html ?? const {};
    final chapters = <ParsedChapter>[];

    for (final itemRef in package?.Spine?.Items ?? const []) {
      if (itemRef.IsLinear == false) {
        continue;
      }
      final manifestItem = manifestById[itemRef.IdRef];
      final href = manifestItem?.Href;
      if (href == null) {
        continue;
      }
      final contentFile =
          htmlFiles[href] ??
          htmlFiles.entries
              .where((entry) => entry.key.endsWith(href))
              .map((entry) => entry.value)
              .firstOrNull;
      final html = contentFile?.Content;
      if (html == null) {
        continue;
      }
      final document = html_parser.parse(html);
      final blocks = document
          .querySelectorAll('h1,h2,h3,p,blockquote,li')
          .map((element) => element.text.trim())
          .where((text) => text.isNotEmpty)
          .toList(growable: false);
      if (blocks.isEmpty) {
        continue;
      }
      chapters.add(
        ParsedChapter(
          title: _chapterTitle(blocks, href),
          paragraphs: blocks,
        ),
      );
    }

    if (chapters.isEmpty) {
      throw const FormatException('EPUB contains no readable chapters.');
    }
    return ParsedBook(
      title: _bookTitle(book.Title, fileName),
      chapters: chapters,
    );
  }

  String _chapterTitle(List<String> blocks, String href) {
    final first = blocks.first;
    if (first.length <= 80) {
      return first;
    }
    final slash = href.lastIndexOf('/');
    final fileName = slash < 0 ? href : href.substring(slash + 1);
    final dot = fileName.lastIndexOf('.');
    return dot <= 0 ? fileName : fileName.substring(0, dot);
  }

  String _bookTitle(String? title, String fileName) {
    if (title != null && title.trim().isNotEmpty) {
      return title.trim();
    }
    final dot = fileName.lastIndexOf('.');
    return dot <= 0 ? fileName : fileName.substring(0, dot);
  }
}
