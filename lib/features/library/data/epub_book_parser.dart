import 'package:epubx/epubx.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:novel_voice_reader/features/library/domain/book_parser.dart';

final class EpubBookParser implements BookParser {
  const EpubBookParser();

  @override
  Future<ParsedBook> parse(Uint8List bytes, String fileName) async {
    // EPUB parsing is CPU + I/O heavy (zip extraction + per-chapter HTML
    // parse); doing it on the platform isolate freezes the splash screen for
    // multi-megabyte books. Move the whole parse into a background isolate.
    final result = await compute(
      _parseEpubIsolate,
      _ParseArgs(bytes: bytes, fileName: fileName),
    );
    if (result.chapterBlocks.isEmpty) {
      throw const FormatException('EPUB contains no readable chapters.');
    }
    return ParsedBook(
      title: result.bookTitle,
      chapters: [
        for (var i = 0; i < result.chapterBlocks.length; i++)
          ParsedChapter(
            title: _chapterTitle(
              result.chapterBlocks[i],
              result.chapterHrefs[i],
            ),
            paragraphs: result.chapterBlocks[i],
          ),
      ],
    );
  }
}

/// Arguments passed to the background isolate. Records (typed fields) serialize
/// cleanly across the isolate boundary without referring to internal classes.
class _ParseArgs {
  const _ParseArgs({required this.bytes, required this.fileName});
  final Uint8List bytes;
  final String fileName;
}

class _ParseResult {
  const _ParseResult({
    required this.bookTitle,
    required this.chapterHrefs,
    required this.chapterBlocks,
  });
  final String bookTitle;
  final List<String> chapterHrefs;
  final List<List<String>> chapterBlocks;
}

Future<_ParseResult> _parseEpubIsolate(_ParseArgs args) async {
  final book = await EpubReader.openBook(args.bytes);
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
  final chapterHrefs = <String>[];
  final chapterBlocks = <List<String>>[];

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
      // A single missing spine document shouldn't abort the whole import;
      // skip it and keep parsing the remaining chapters.
      continue;
    }
    final String html;
    try {
      html = await contentRef.readContentAsText();
    } catch (_) {
      // Likewise, an unreadable spine document is skipped rather than fatal.
      continue;
    }
    final document = html_parser.parse(html);
    final blocks = _extractBlocks(document);
    if (blocks.isEmpty) {
      continue;
    }
    chapterHrefs.add(href);
    chapterBlocks.add(blocks);
  }

  return _ParseResult(
    bookTitle: _bookTitle(book.Title, args.fileName),
    chapterHrefs: chapterHrefs,
    chapterBlocks: chapterBlocks,
  );
}

List<String> _extractBlocks(html_dom.Document document) {
  const semanticBlockTags = {
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'p',
    'blockquote',
    'li',
  };
  final semanticBlocks = document
      .querySelectorAll('h1,h2,h3,h4,h5,h6,p,blockquote,li')
      // Skip container blocks that wrap another semantic block (e.g. li > p,
      // blockquote > p) so their text isn't emitted twice.
      .where(
        (element) => !element.children.any(
          (child) => semanticBlockTags.contains(child.localName),
        ),
      )
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
