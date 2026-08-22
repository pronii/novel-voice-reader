import 'dart:convert';

import 'package:charset_converter/charset_converter.dart';
import 'package:flutter/foundation.dart';
import 'package:novel_voice_reader/features/library/domain/book_parser.dart';

final class TxtBookParser implements BookParser {
  const TxtBookParser();

  @override
  Future<ParsedBook> parse(Uint8List bytes, String fileName) async {
    // Decoding stays on the platform isolate: the GB18030 fallback goes through
    // charset_converter's platform channel, which is unavailable in a plain
    // `compute` background isolate. The heavy part — normalising newlines,
    // splitting the whole book into lines, and running the chapter-heading
    // regex over every line — is pure Dart, so it moves to a background isolate
    // to keep large imports from freezing the UI (mirrors the EPUB parser).
    final text = await _decode(bytes);
    return compute(
      _parseDecodedText,
      _TxtParseArgs(text: text, fileName: fileName),
    );
  }

  Future<String> _decode(Uint8List bytes) async {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: false);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: false);
    }
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return CharsetConverter.decode('GB18030', bytes);
    }
  }

  String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
    if (bytes.length.isOdd) {
      throw const FormatException('UTF-16 byte length must be even.');
    }
    final codeUnits = <int>[];
    for (var index = 0; index < bytes.length; index += 2) {
      final first = bytes[index];
      final second = bytes[index + 1];
      codeUnits.add(
        littleEndian ? first | (second << 8) : (first << 8) | second,
      );
    }
    return String.fromCharCodes(codeUnits);
  }
}

/// Arguments passed to the background isolate. Plain typed fields serialize
/// cleanly across the isolate boundary.
class _TxtParseArgs {
  const _TxtParseArgs({required this.text, required this.fileName});
  final String text;
  final String fileName;
}

final _chapterHeading = RegExp(
  r'^\s*((?:第[0-9零一二三四五六七八九十百千万两]+[章节回卷部篇])|(?:卷[0-9零一二三四五六七八九十百千万两]+)).*$',
);

/// Splits already-decoded book text into chapters. Runs in a background isolate
/// via [compute]; must stay a top-level function with sendable arguments.
ParsedBook _parseDecodedText(_TxtParseArgs args) {
  final lines = args.text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) => line.trim())
      .toList(growable: false);

  final chapters = <ParsedChapter>[];
  String? currentTitle;
  var currentParagraphs = <String>[];

  void commitChapter() {
    final title = currentTitle;
    if (title == null) {
      return;
    }
    chapters.add(
      ParsedChapter(title: title, paragraphs: currentParagraphs),
    );
    currentParagraphs = <String>[];
  }

  for (final line in lines) {
    if (line.isEmpty) {
      continue;
    }
    if (_chapterHeading.hasMatch(line)) {
      if (currentTitle == null && currentParagraphs.isNotEmpty) {
        // Text that appears before the first chapter heading becomes its own
        // synthetic leading chapter instead of being merged into chapter 1.
        chapters.add(
          ParsedChapter(title: '前言', paragraphs: currentParagraphs),
        );
        currentParagraphs = <String>[];
      }
      commitChapter();
      currentTitle = line;
    } else {
      currentParagraphs.add(line);
    }
  }
  commitChapter();

  if (chapters.isEmpty) {
    chapters.add(
      ParsedChapter(
        title: '正文',
        paragraphs: lines.where((line) => line.isNotEmpty).toList(),
      ),
    );
  }

  return ParsedBook(
    title: _titleFromFileName(args.fileName),
    chapters: chapters,
  );
}

String _titleFromFileName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot <= 0 ? fileName : fileName.substring(0, dot);
}
