import 'dart:typed_data';

abstract interface class BookParser {
  Future<ParsedBook> parse(Uint8List bytes, String fileName);
}

final class ParsedBook {
  const ParsedBook({required this.title, required this.chapters});

  final String title;
  final List<ParsedChapter> chapters;
}

final class ParsedChapter {
  const ParsedChapter({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;
}
