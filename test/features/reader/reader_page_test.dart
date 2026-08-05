import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/reader/presentation/reader_page.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

final longParagraphs = List.generate(
  10,
  (index) => ReaderParagraph(
    id: 10 + index,
    chapterId: 10,
    index: index,
    text: '第${index + 1}段。这是一段足够长的正文，用来验证不同高度段落滚动时的位置判断和阅读进度。',
  ),
);

void main() {
  testWidgets('disables playback commands while playback is starting', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _reader(
          paragraphs: _paragraphs(10, ['第一段。']),
          playbackStarting: true,
        ),
      ),
    );

    final playButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == '播放',
    );
    expect(tester.widget<IconButton>(playButton).onPressed, isNull);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '从这里朗读'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('selects one paragraph and exposes read-from-here', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: _reader(paragraphs: _paragraphs(10, ['第一段。', '第二段。']))),
    );

    await tester.tap(find.text('第二段。'));
    await tester.pump();

    expect(find.text('从这里朗读'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('active-paragraph-101')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('active-paragraph-100')),
      findsNothing,
    );
  });

  testWidgets('opens the chapter list and selects a chapter', (tester) async {
    int? selectedChapterId;
    final chapters = const [
      ReaderChapter(id: 10, index: 0, title: '第一章'),
      ReaderChapter(id: 20, index: 1, title: '第二章'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: _reader(
          chapters: chapters,
          onChapterSelected: (chapterId) => selectedChapterId = chapterId,
        ),
      ),
    );

    await tester.tap(find.byTooltip('章节目录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第二章'));

    expect(selectedChapterId, 20);
  });

  testWidgets('opens the chapter directory at the visible chapter', (
    tester,
  ) async {
    final chapters = List.generate(
      100,
      (index) => ReaderChapter(
        id: 1000 + index * 7,
        index: index,
        title: '第${index + 1}章',
      ),
    );
    final current = chapters[80];

    await tester.pumpWidget(
      MaterialApp(
        home: _reader(
          chapters: chapters,
          chapter: current,
          paragraphs: _paragraphs(current.id, ['第一段。']),
          initialCursor: PlaybackCursor(
            chapterId: current.id,
            paragraphIndex: 0,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('章节目录'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, '第81章'), findsOneWidget);
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, '第81章')).selected,
      isTrue,
    );
  });

  testWidgets('filters chapters by title and number', (tester) async {
    const chapters = [
      ReaderChapter(id: 101, index: 0, title: '普通章节'),
      ReaderChapter(id: 700, index: 1, title: '目标章节'),
      ReaderChapter(id: 42, index: 2, title: '尾声'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: _reader(
          chapters: chapters,
          chapter: chapters.first,
          paragraphs: _paragraphs(101, ['第一段。']),
          initialCursor: const PlaybackCursor(
            chapterId: 101,
            paragraphIndex: 0,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('章节目录'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '目标');
    await tester.pump();
    expect(find.widgetWithText(ListTile, '目标章节'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '普通章节'), findsNothing);

    await tester.enterText(find.byType(TextField), '2');
    await tester.pump();
    expect(find.widgetWithText(ListTile, '目标章节'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '尾声'), findsNothing);
  });

  testWidgets('starts at the saved paragraph and reports a new position', (
    tester,
  ) async {
    _useNarrowViewport(tester);
    final reported = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _reader(
          paragraphs: longParagraphs,
          initialCursor: const PlaybackCursor(chapterId: 10, paragraphIndex: 5),
          onReadingPositionChanged: (paragraph) => reported.add(paragraph.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('active-paragraph-15')),
      findsOneWidget,
    );
    await tester.drag(
      find.byType(ScrollablePositionedList),
      const Offset(0, -300),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(reported, isNotEmpty);
    expect(reported.last, isNot(15));
  });

  testWidgets('top play follows the first visible paragraph after scrolling', (
    tester,
  ) async {
    _useNarrowViewport(tester);
    ReaderParagraph? reported;
    ReaderParagraph? played;
    await tester.pumpWidget(
      MaterialApp(
        home: _reader(
          paragraphs: longParagraphs,
          initialCursor: const PlaybackCursor(chapterId: 10, paragraphIndex: 5),
          onReadingPositionChanged: (paragraph) => reported = paragraph,
          onPlayFrom: (paragraph) => played = paragraph,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(ScrollablePositionedList),
      const Offset(0, -300),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final visibleParagraphId = reported?.id;
    await tester.tap(find.byTooltip('播放'));

    expect(visibleParagraphId, isNotNull);
    expect(played?.id, visibleParagraphId);
  });

  testWidgets('flushes a settled position when disposed during debounce', (
    tester,
  ) async {
    _useNarrowViewport(tester);
    final reported = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _reader(
          paragraphs: longParagraphs,
          initialCursor: const PlaybackCursor(chapterId: 10, paragraphIndex: 5),
          onReadingPositionChanged: (paragraph) => reported.add(paragraph.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(ScrollablePositionedList),
      const Offset(0, -300),
    );
    await tester.pump();
    expect(reported, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(reported, isNotEmpty);
    expect(reported.last, isNot(15));
  });

  testWidgets('does not report a stale paragraph after scrolling back', (
    tester,
  ) async {
    _useNarrowViewport(tester);
    final reported = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _reader(
          paragraphs: longParagraphs,
          initialCursor: const PlaybackCursor(chapterId: 10, paragraphIndex: 5),
          onReadingPositionChanged: (paragraph) => reported.add(paragraph.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byType(ScrollablePositionedList);
    await tester.drag(list, const Offset(0, -300));
    await tester.pump();
    await tester.drag(list, const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(reported, isEmpty);
  });

  testWidgets('does not report progress after changing only font size', (
    tester,
  ) async {
    _useNarrowViewport(tester);
    final reported = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _reader(
          paragraphs: longParagraphs,
          initialCursor: const PlaybackCursor(chapterId: 10, paragraphIndex: 5),
          onReadingPositionChanged: (paragraph) => reported.add(paragraph.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('阅读设置'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(reported, isEmpty);
  });

  testWidgets('reports a tapped paragraph immediately', (tester) async {
    _useNarrowViewport(tester);
    final reported = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _reader(
          paragraphs: longParagraphs,
          initialCursor: const PlaybackCursor(chapterId: 10, paragraphIndex: 5),
          onReadingPositionChanged: (paragraph) => reported.add(paragraph.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    reported.clear();

    await tester.tap(find.byKey(const ValueKey<String>('paragraph-16')));

    expect(reported, [16]);
    await tester.pump(const Duration(milliseconds: 600));
    expect(reported, [16]);
  });

  testWidgets('reports a played paragraph immediately', (tester) async {
    final reported = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _reader(
          paragraphs: _paragraphs(10, ['第一段。']),
          onReadingPositionChanged: (paragraph) => reported.add(paragraph.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    reported.clear();

    await tester.tap(find.text('从这里朗读'));

    expect(reported, [100]);
  });

  testWidgets('uses the full screen without a fixed chapter footer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: _reader(paragraphs: longParagraphs)),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(scaffold.bottomNavigationBar, isNull);
    expect(find.textContaining('第1段'), findsOneWidget);
  });
}

ReaderPage _reader({
  List<ReaderChapter>? chapters,
  ReaderChapter chapter = const ReaderChapter(id: 10, index: 0, title: '第一章'),
  List<ReaderParagraph>? paragraphs,
  PlaybackCursor? initialCursor = const PlaybackCursor(
    chapterId: 10,
    paragraphIndex: 0,
  ),
  bool playbackStarting = false,
  ValueChanged<int>? onChapterSelected,
  ValueChanged<ReaderParagraph>? onReadingPositionChanged,
  ValueChanged<ReaderParagraph>? onPlayFrom,
}) {
  return ReaderPage(
    bookId: 1,
    bookTitle: '测试书',
    chapters: chapters ?? [chapter],
    sections: [
      ReaderChapterSection(
        chapter: chapter,
        paragraphs: paragraphs ?? _paragraphs(chapter.id, ['第一段。']),
      ),
    ],
    currentChapterId: chapter.id,
    initialCursor: initialCursor,
    playbackStarting: playbackStarting,
    onChapterSelected: onChapterSelected,
    onReadingPositionChanged: onReadingPositionChanged,
    onPlayFrom: onPlayFrom,
  );
}

List<ReaderParagraph> _paragraphs(int chapterId, List<String> texts) {
  return List.generate(
    texts.length,
    (index) => ReaderParagraph(
      id: chapterId * 10 + index,
      chapterId: chapterId,
      index: index,
      text: texts[index],
    ),
  );
}

void _useNarrowViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 480);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
