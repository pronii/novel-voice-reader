import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/reader/application/text_paginator.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const paginator = TextPaginator();
  const padding = EdgeInsets.all(20);
  const textStyle = TextStyle(fontSize: 10, height: 1.8);
  const headingStyle = TextStyle(fontSize: 16, height: 1.4);

  List<ReaderRenderedPage> run(
    List<ReaderContentItem> items, {
    Size viewport = const Size(300, 400),
    TextStyle style = textStyle,
  }) {
    return paginator.paginate(
      items: items,
      viewport: viewport,
      padding: padding,
      textStyle: style,
      headingStyle: headingStyle,
      blockSpacing: 12,
    );
  }

  ReaderParagraph paragraph(int index, String text, {int chapterId = 10}) {
    return ReaderParagraph(
      id: chapterId * 1000 + index,
      chapterId: chapterId,
      index: index,
      text: text,
    );
  }

  List<ReaderContentItem> content(List<ReaderChapterSection> sections) {
    return [
      for (final section in sections) ...[
        ReaderChapterHeadingItem(section.chapter),
        for (final p in section.paragraphs) ReaderParagraphItem(p),
      ],
    ];
  }

  // All text blocks belonging to [p], in page order, must re-join to p.text.
  String rejoin(List<ReaderRenderedPage> pages, ReaderParagraph p) {
    final buffer = StringBuffer();
    for (final page in pages) {
      for (final block in page.blocks) {
        if (block is ReaderTextPageBlock && block.paragraph.id == p.id) {
          buffer.write(block.text);
        }
      }
    }
    return buffer.toString();
  }

  test('returns no pages for empty content', () {
    expect(run(const []), isEmpty);
  });

  test('returns no pages for a degenerate viewport', () {
    final items = content([
      ReaderChapterSection(
        chapter: const ReaderChapter(id: 10, index: 0, title: '第一章'),
        paragraphs: [paragraph(0, '文' * 20)],
      ),
    ]);
    expect(run(items, viewport: const Size(10, 10)), isEmpty);
  });

  test('keeps a short chapter on a single page', () {
    final chapter = const ReaderChapter(id: 10, index: 0, title: '第一章');
    final p = paragraph(0, '文' * 30);
    final pages = run(
      content([
        ReaderChapterSection(chapter: chapter, paragraphs: [p]),
      ]),
    );

    expect(pages, hasLength(1));
    expect(pages.single.firstChapterId, 10);
    expect(pages.single.firstParagraph?.id, p.id);
    expect(pages.single.blocks.first, isA<ReaderHeadingPageBlock>());
  });

  test('splits a very long paragraph across pages without losing text', () {
    final chapter = const ReaderChapter(id: 10, index: 0, title: '第一章');
    final longText = '文' * 4000;
    final p = paragraph(0, longText);
    final pages = run(
      content([
        ReaderChapterSection(chapter: chapter, paragraphs: [p]),
      ]),
    );

    expect(pages.length, greaterThan(1));
    // Text is preserved exactly across the slices.
    expect(rejoin(pages, p), longText);

    // Exactly one slice is the paragraph start; the rest are continuations.
    final textBlocks = [
      for (final page in pages)
        for (final block in page.blocks)
          if (block is ReaderTextPageBlock && block.paragraph.id == p.id) block,
    ];
    expect(textBlocks.where((b) => b.isParagraphStart), hasLength(1));
    expect(textBlocks.first.isParagraphStart, isTrue);
  });

  test('produces more pages as the font grows', () {
    final chapter = const ReaderChapter(id: 10, index: 0, title: '第一章');
    final items = content([
      ReaderChapterSection(
        chapter: chapter,
        paragraphs: [for (var i = 0; i < 20; i++) paragraph(i, '文' * 200)],
      ),
    ]);

    final small = run(items, style: const TextStyle(fontSize: 10, height: 1.8));
    final large = run(items, style: const TextStyle(fontSize: 20, height: 1.8));

    expect(large.length, greaterThan(small.length));
  });

  test('maps a cursor to the page where its paragraph starts', () {
    final chapter = const ReaderChapter(id: 10, index: 0, title: '第一章');
    final paragraphs = [for (var i = 0; i < 12; i++) paragraph(i, '文' * 200)];
    final pages = run(
      content([
        ReaderChapterSection(chapter: chapter, paragraphs: paragraphs),
      ]),
    );

    const cursor = PlaybackCursor(chapterId: 10, paragraphIndex: 8);
    final index = pageIndexForCursor(pages, cursor);

    final startsOnPage = pages[index].blocks.any(
      (block) =>
          block is ReaderTextPageBlock &&
          block.isParagraphStart &&
          block.paragraph.index == 8,
    );
    expect(startsOnPage, isTrue);
  });

  test('cursor lookups fall back to the first page when unknown', () {
    final chapter = const ReaderChapter(id: 10, index: 0, title: '第一章');
    final pages = run(
      content([
        ReaderChapterSection(chapter: chapter, paragraphs: [paragraph(0, '文' * 30)]),
      ]),
    );

    expect(
      pageIndexForCursor(pages, const PlaybackCursor(chapterId: 99, paragraphIndex: 3)),
      0,
    );
    expect(pageIndexForCursor(pages, null), 0);
  });
}
