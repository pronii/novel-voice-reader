import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:novel_voice_reader/features/library/domain/book_parser.dart';

final class EpubBookParser implements BookParser {
  const EpubBookParser();

  @override
  Future<ParsedBook> parse(Uint8List bytes, String fileName) async {
    final book = await EpubReader.openBook(bytes);
    final package = book.Schema?.Package;
    final manifestItems = package?.Manifest?.Items ?? const [];
    final manifestById = {
      for (final item in manifestItems)
        if (item.Id != null) item.Id!: item,
    };
    final htmlFiles = book.Content?.Html ?? const {};
    final normalizedHtmlFiles = {
      for (final entry in htmlFiles.entries)
        _normalizeHref(entry.key): entry.value,
    };
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
      final normalizedHref = _normalizeHref(href);
      final contentRef =
          normalizedHtmlFiles[normalizedHref] ??
          normalizedHtmlFiles.entries
              .where(
                (entry) =>
                    entry.key == normalizedHref ||
                    entry.key.endsWith('/$normalizedHref'),
              )
              .map((entry) => entry.value)
              .firstOrNull;
      if (contentRef == null) {
        throw FormatException('EPUB spine document is missing: $href');
      }
      late final String html;
      try {
        html = await contentRef.readContentAsText();
      } catch (error) {
        throw FormatException(
          'EPUB spine document cannot be read: $href',
          error,
        );
      }
      final document = html_parser.parse(html);
      final blocks = _extractBlocks(document);
      if (blocks.isEmpty) {
        continue;
      }
      chapters.add(
        ParsedChapter(title: _chapterTitle(blocks, href), paragraphs: blocks),
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

  List<String> _extractBlocks(html_dom.Document document) {
    final semanticBlocks = document
        .querySelectorAll('h1,h2,h3,h4,h5,h6,p,blockquote,li')
        .map((element) => _normalizeText(element.text))
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    if (semanticBlocks.isNotEmpty) {
      return semanticBlocks;
    }

    const nestedBlockTags = {'div', 'p', 'blockquote', 'li'};
    final divBlocks = document
        .querySelectorAll('body div')
        .where(
          (element) => !element.children.any(
            (child) => nestedBlockTags.contains(child.localName),
          ),
        )
        .map((element) => _normalizeText(element.text))
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    if (divBlocks.isNotEmpty) {
      return divBlocks;
    }

    final bodyText = document.body?.text;
    if (bodyText == null) {
      return const [];
    }
    return bodyText
        .split(RegExp(r'[\r\n]+'))
        .map(_normalizeText)
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
  }

  String _normalizeHref(String href) {
    final withoutFragment = href.split('#').first.replaceAll('\\', '/');
    final decoded = Uri.decodeComponent(withoutFragment);
    return decoded.replaceFirst(RegExp(r'^(\./)+'), '');
  }

  String _normalizeText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
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
