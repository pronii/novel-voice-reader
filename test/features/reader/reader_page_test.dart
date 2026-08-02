import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/reader/presentation/reader_page.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

const longParagraphs = [
  ReaderParagraph(id: 10, index: 0, text: '第一段。这是一段足够长的正文，用来验证不同高度段落滚动时的位置判断。'),
  ReaderParagraph(id: 11, index: 1, text: '第二段。正文继续展开，并且需要在较窄的测试视口中自然换行。'),
  ReaderParagraph(
    id: 12,
    index: 2,
    text: '第三段。这一段更长一些，用于确保列表不能一次显示所有内容，滚动后会出现新的顶部可见段落。',
  ),
  ReaderParagraph(id: 13, index: 3, text: '第四段。每一段的高度可以不同。'),
  ReaderParagraph(id: 14, index: 4, text: '第五段。继续提供用于滚动测试的正文内容。'),
  ReaderParagraph(id: 15, index: 5, text: '第六段。这是保存的阅读位置，应当在页面打开时直接恢复为可见段落。'),
  ReaderParagraph(
    id: 16,
    index: 6,
    text: '第七段。点击这个段落时应立即报告新的阅读位置。为了覆盖可变高度正文，这里继续补充内容，让段落在窄视口中占据更多行。',
  ),
  ReaderParagraph(
    id: 17,
    index: 7,
    text: '第八段。滚动列表后它可能成为顶部第一个可见正文段落。这段正文也有不同的长度，用于验证位置判断依赖可见边界而非固定像素高度。',
  ),
  ReaderParagraph(
    id: 18,
    index: 8,
    text: '第九段。用于填充足够长的章节。继续增加正文内容，确保测试视口无法同时容纳剩余的全部段落。',
  ),
  ReaderParagraph(
    id: 19,
    index: 9,
    text: '第十段。章节末尾也必须保持正常布局，并为向下滚动提供足够的可滚动范围。',
  ),
];

void main() {
  testWidgets('disables playback commands while playback is starting', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapterTitle: '第一章',
          playbackStarting: true,
          paragraphs: [ReaderParagraph(id: 10, index: 0, text: '第一段。')],
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
      const MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapterTitle: '第一章',
          paragraphs: [
            ReaderParagraph(id: 10, index: 0, text: '第一段。'),
            ReaderParagraph(id: 11, index: 1, text: '第二段。'),
          ],
        ),
      ),
    );

    await tester.tap(find.text('第二段。'));
    await tester.pump();

    expect(find.text('从这里朗读'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('active-paragraph-11')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('active-paragraph-10')),
      findsNothing,
    );
  });

  testWidgets('opens the chapter list and selects a chapter', (tester) async {
    int? selectedChapterId;
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapterTitle: '第一章',
          chapters: const [
            ReaderChapter(id: 10, index: 0, title: '第一章'),
            ReaderChapter(id: 20, index: 1, title: '第二章'),
          ],
          currentChapterId: 10,
          paragraphs: const [ReaderParagraph(id: 100, index: 0, text: '第一段。')],
          onChapterSelected: (chapterId) {
            selectedChapterId = chapterId;
          },
        ),
      ),
    );

    await tester.tap(find.byTooltip('章节目录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第二章'));

    expect(selectedChapterId, 20);
  });

  testWidgets('opens the chapter directory at the current chapter', (
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

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapterTitle: '当前正文',
          chapters: chapters,
          currentChapterId: chapters[80].id,
          paragraphs: const [ReaderParagraph(id: 100, index: 0, text: '第一段。')],
        ),
      ),
    );

    await tester.tap(find.byTooltip('章节目录'));
    await tester.pumpAndSettle();

    expect(find.text('第81章'), findsOneWidget);
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, '第81章')).selected,
      isTrue,
    );
  });

  testWidgets('filters chapters by title and number', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapterTitle: '当前正文',
          chapters: [
            ReaderChapter(id: 101, index: 0, title: '普通章节'),
            ReaderChapter(id: 700, index: 1, title: '目标章节'),
            ReaderChapter(id: 42, index: 2, title: '尾声'),
          ],
          currentChapterId: 101,
          paragraphs: [ReaderParagraph(id: 100, index: 0, text: '第一段。')],
        ),
      ),
    );

    await tester.tap(find.byTooltip('章节目录'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '目标');
    await tester.pump();
    expect(find.text('目标章节'), findsOneWidget);
    expect(find.text('普通章节'), findsNothing);

    await tester.enterText(find.byType(TextField), '2');
    await tester.pump();
    expect(find.text('目标章节'), findsOneWidget);
    expect(find.text('普通章节'), findsNothing);
    expect(find.text('尾声'), findsNothing);
  });

  testWidgets(
    'clearing chapter search restores and repositions the current chapter',
    (tester) async {
      final chapters = List.generate(
        100,
        (index) => ReaderChapter(
          id: 2000 + index * 11,
          index: index,
          title: index == 4 ? '目标章节' : '第${index + 1}章',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReaderPage(
            bookId: 1,
            bookTitle: '测试书',
            chapterTitle: '当前正文',
            chapters: chapters,
            currentChapterId: chapters[80].id,
            paragraphs: const [
              ReaderParagraph(id: 100, index: 0, text: '第一段。'),
            ],
          ),
        ),
      );

      await tester.tap(find.byTooltip('章节目录'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(ScrollablePositionedList).last,
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();
      expect(find.text('第81章'), findsNothing);
      await tester.enterText(find.byType(TextField), '目标');
      await tester.pumpAndSettle();
      expect(find.text('目标章节'), findsOneWidget);
      expect(find.text('第81章'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      expect(find.text('第81章'), findsOneWidget);
      expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, '第81章')).selected,
        isTrue,
      );
    },
  );

  testWidgets('continues to the next chapter after bottom overscroll', (
    tester,
  ) async {
    final selectedChapterIds = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapterTitle: '第一章',
          chapters: const [
            ReaderChapter(id: 1, index: 0, title: '第一章'),
            ReaderChapter(id: 2, index: 1, title: '第二章'),
          ],
          currentChapterId: 1,
          paragraphs: longParagraphs,
          onChapterSelected: selectedChapterIds.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byType(ScrollablePositionedList);
    await tester.drag(list, const Offset(0, -600));
    await tester.drag(list, const Offset(0, -120));

    expect(selectedChapterIds, [2]);
  });

  testWidgets('locks at 48 pixels and unlocks after the chapter changes', (
    tester,
  ) async {
    final selectedChapterIds = <int>[];
    var currentChapterId = 1;
    late StateSetter setReaderState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setReaderState = setState;
            return ReaderPage(
              bookId: 1,
              bookTitle: '测试书',
              chapterTitle: '第$currentChapterId章',
              chapters: const [
                ReaderChapter(id: 1, index: 0, title: '第一章'),
                ReaderChapter(id: 2, index: 1, title: '第二章'),
                ReaderChapter(id: 3, index: 2, title: '第三章'),
              ],
              currentChapterId: currentChapterId,
              paragraphs: longParagraphs,
              onChapterSelected: selectedChapterIds.add,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    void dispatchBottomOverscroll(double amount) {
      final listContext = tester.element(find.byType(ScrollablePositionedList));
      OverscrollNotification(
        metrics: FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 100,
          pixels: 100,
          viewportDimension: 100,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1,
        ),
        context: listContext,
        overscroll: amount,
      ).dispatch(listContext);
    }

    dispatchBottomOverscroll(47);
    expect(selectedChapterIds, isEmpty);

    dispatchBottomOverscroll(1);
    expect(selectedChapterIds, [2]);

    dispatchBottomOverscroll(48);
    expect(selectedChapterIds, [2]);

    setReaderState(() => currentChapterId = 2);
    await tester.pump();

    dispatchBottomOverscroll(47);
    expect(selectedChapterIds, [2]);

    dispatchBottomOverscroll(1);
    expect(selectedChapterIds, [2, 3]);
  });

  testWidgets('does not continue past the last chapter', (tester) async {
    final selectedChapterIds = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapterTitle: '第二章',
          chapters: const [
            ReaderChapter(id: 1, index: 0, title: '第一章'),
            ReaderChapter(id: 2, index: 1, title: '第二章'),
          ],
          currentChapterId: 2,
          paragraphs: longParagraphs,
          onChapterSelected: selectedChapterIds.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byType(ScrollablePositionedList);
    await tester.drag(list, const Offset(0, -600));
    await tester.drag(list, const Offset(0, -120));

    expect(selectedChapterIds, isEmpty);
  });

  testWidgets(
    'starts at the saved paragraph and reports a new visible paragraph',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final reported = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: ReaderPage(
            bookId: 1,
            bookTitle: '测试书',
            chapterTitle: '第一章',
            currentChapterId: 10,
            initialActiveParagraphId: 15,
            paragraphs: longParagraphs,
            onReadingPositionChanged: (paragraph) => reported.add(paragraph.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('active-paragraph-15')),
        findsOneWidget,
      );
      expect(find.byTooltip('上一章'), findsNothing);
      expect(find.byTooltip('下一章'), findsNothing);
      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, -300),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(reported, isNotEmpty);
      expect(reported.last, isNot(15));
    },
  );

  testWidgets('top play follows the first visible paragraph after scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ReaderParagraph? reported;
    ReaderParagraph? played;

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapterTitle: '第一章',
          currentChapterId: 10,
          initialActiveParagraphId: 15,
          paragraphs: longParagraphs,
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
    expect(reported?.id, isNot(15));
    final scrolledParagraphId = reported?.id;

    await tester.tap(find.byTooltip('播放'));

    expect(played?.id, scrolledParagraphId);
  });

  testWidgets(
    'flushes a settled visible paragraph when disposed during debounce',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final reported = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: ReaderPage(
            bookId: 1,
            bookTitle: '测试书',
            chapterTitle: '第一章',
            currentChapterId: 10,
            initialActiveParagraphId: 15,
            paragraphs: longParagraphs,
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
    },
  );

  testWidgets('does not flush an old paragraph when switching chapters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reported = <int>[];
    int? selectedChapterId;
    var showReader = true;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => showReader
              ? ReaderPage(
                  bookId: 1,
                  bookTitle: '测试书',
                  chapterTitle: '第一章',
                  chapters: const [
                    ReaderChapter(id: 10, index: 0, title: '第一章'),
                    ReaderChapter(id: 20, index: 1, title: '第二章'),
                  ],
                  currentChapterId: 10,
                  initialActiveParagraphId: 15,
                  paragraphs: longParagraphs,
                  onReadingPositionChanged: (paragraph) =>
                      reported.add(paragraph.id),
                  onChapterSelected: (chapterId) {
                    selectedChapterId = chapterId;
                    setState(() => showReader = false);
                  },
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(ScrollablePositionedList),
      const Offset(0, -300),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('章节目录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('第二章'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));

    expect(selectedChapterId, 20);
    expect(reported, isEmpty);
  });

  testWidgets('does not report a stale paragraph after scrolling back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reported = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapterTitle: '第一章',
          currentChapterId: 10,
          initialActiveParagraphId: 15,
          paragraphs: longParagraphs,
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

  testWidgets('does not report progress after changing only the font size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reported = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapterTitle: '第一章',
          currentChapterId: 10,
          initialActiveParagraphId: 15,
          paragraphs: longParagraphs,
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

  testWidgets('does not replace a tap after an unmoved boundary overscroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reported = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapterTitle: '第一章',
          currentChapterId: 10,
          paragraphs: longParagraphs,
          onReadingPositionChanged: (paragraph) => reported.add(paragraph.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('paragraph-11')));
    expect(reported, [11]);

    await tester.drag(
      find.byType(ScrollablePositionedList),
      const Offset(0, 200),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(reported, [11]);
  });

  testWidgets('reports a tapped paragraph immediately', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reported = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapterTitle: '第一章',
          currentChapterId: 10,
          initialActiveParagraphId: 15,
          paragraphs: longParagraphs,
          onReadingPositionChanged: (paragraph) => reported.add(paragraph.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    reported.clear();

    await tester.tap(find.byKey(const ValueKey<String>('paragraph-16')));

    expect(reported, [16]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(reported, [16]);
  });

  testWidgets('reports a played paragraph immediately', (tester) async {
    final reported = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapterTitle: '第一章',
          initialActiveParagraphId: 10,
          paragraphs: const [ReaderParagraph(id: 10, index: 0, text: '第一段。')],
          onReadingPositionChanged: (paragraph) => reported.add(paragraph.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    reported.clear();

    await tester.tap(find.text('从这里朗读'));

    expect(reported, [10]);
  });

  testWidgets('uses the full screen without a fixed chapter footer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapterTitle: '第一章',
          currentChapterId: 10,
          paragraphs: longParagraphs,
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(scaffold.bottomNavigationBar, isNull);
    expect(find.text('第一章'), findsOneWidget);
  });
}
