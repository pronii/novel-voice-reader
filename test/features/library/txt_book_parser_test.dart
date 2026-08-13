import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/library/data/txt_book_parser.dart';

void main() {
  test('detects Chinese chapter headings and keeps paragraphs', () async {
    final parsed = await const TxtBookParser().parse(
      Uint8List.fromList(
        utf8.encode('第一章 开始\n第一段。\n\n第二段。\n第二章 继续\n第三段。'),
      ),
      '测试.txt',
    );

    expect(parsed.title, '测试');
    expect(
      parsed.chapters.map((chapter) => chapter.title),
      ['第一章 开始', '第二章 继续'],
    );
    expect(parsed.chapters.first.paragraphs, ['第一段。', '第二段。']);
  });

  test('falls back to one chapter when headings are absent', () async {
    final parsed = await const TxtBookParser().parse(
      Uint8List.fromList(utf8.encode('第一段。\n\n第二段。')),
      '无章节.txt',
    );

    expect(parsed.chapters.single.title, '正文');
    expect(parsed.chapters.single.paragraphs, ['第一段。', '第二段。']);
  });

  test('decodes a UTF-8 BOM without leaving it in the title', () async {
    final bytes = Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode('第一章\n正文。'),
    ]);

    final parsed = await const TxtBookParser().parse(bytes, '带BOM.txt');

    expect(parsed.chapters.single.title, '第一章');
  });

  test('decodes UTF-16 little-endian content with a BOM', () async {
    const text = '第一章\n正文。';
    final codeUnits = text.codeUnits;
    final bytes = Uint8List.fromList([
      0xFF,
      0xFE,
      for (final codeUnit in codeUnits) ...[
        codeUnit & 0xFF,
        codeUnit >> 8,
      ],
    ]);

    final parsed = await const TxtBookParser().parse(bytes, 'UTF16.txt');

    expect(parsed.chapters.single.title, '第一章');
    expect(parsed.chapters.single.paragraphs, ['正文。']);
  });
}
