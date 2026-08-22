import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_flip/page_flip.dart';
import 'package:novel_voice_reader/features/reader/application/reader_chapter_window_controller.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_content.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_page_mode.dart';
import 'package:novel_voice_reader/features/reader/presentation/paginated_reader_view.dart';

void main() {
  // A paragraph whose text starts with a unique, searchable marker so a page's
  // content can be located regardless of the (fixed-metric) test font.
  ReaderParagraph paragraph(int chapterId, int index) {
    return ReaderParagraph(
      id: chapterId * 1000 + index,
      chapterId: chapterId,
      index: index,
      text: 'CH${chapterId}P$index-${'文' * 60}',
    );
  }

  List<ReaderContentItem> buildItems({int chapters = 5, int perChapter = 4}) {
    final items = <ReaderContentItem>[];
    for (var c = 1; c <= chapters; c++) {
      final chapterId = c * 10;
      items.add(
        ReaderChapterHeadingItem(
          ReaderChapter(id: chapterId, index: c - 1, title: '第$c章'),
        ),
      );
      for (var p = 0; p < perChapter; p++) {
        items.add(ReaderParagraphItem(paragraph(chapterId, p)));
      }
    }
    return items;
  }

  Widget host({
    required List<ReaderContentItem> items,
    ReaderPageMode mode = ReaderPageMode.slide,
    PlaybackCursor? initialCursor,
    ValueChanged<ReaderParagraph>? onReadingPositionChanged,
    PaginatedEdgeLoad? onLoadPrevious,
    PaginatedEdgeLoad? onLoadNext,
    PaginatedReaderController? controller,
    Size size = const Size(300, 400),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: PaginatedReaderView(
              mode: mode,
              items: items,
              textStyle: const TextStyle(fontSize: 20, height: 1.5),
              headingStyle: const TextStyle(fontSize: 24, height: 1.4),
              initialCursor: initialCursor,
              onReadingPositionChanged: onReadingPositionChanged,
              onLoadPrevious: onLoadPrevious,
              onLoadNext: onLoadNext,
              controller: controller,
            ),
          ),
        ),
      ),
    );
  }

  // A host whose playbackCursor can be changed after mount (via [cursor]) so
  // the playback-follow behaviour can be driven from a test.
  Widget followHost({
    required ValueNotifier<PlaybackCursor?> cursor,
    required bool active,
    ReaderPageMode mode = ReaderPageMode.slide,
    ValueChanged<ReaderParagraph>? onReadingPositionChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 400,
            child: ValueListenableBuilder<PlaybackCursor?>(
              valueListenable: cursor,
              builder: (context, value, _) => PaginatedReaderView(
                mode: mode,
                items: buildItems(),
                textStyle: const TextStyle(fontSize: 20, height: 1.5),
                headingStyle: const TextStyle(fontSize: 24, height: 1.4),
                initialCursor: const PlaybackCursor(
                  chapterId: 10,
                  paragraphIndex: 0,
                ),
                playbackCursor: value,
                playbackActive: active,
                onReadingPositionChanged: onReadingPositionChanged,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('opens on the page containing the initial cursor', (tester) async {
    await tester.pumpWidget(
      host(
        items: buildItems(),
        initialCursor: const PlaybackCursor(chapterId: 30, paragraphIndex: 0),
      ),
    );
    await tester.pumpAndSettle();

    // The cursor's paragraph is shown; content from the first chapter (many
    // pages earlier) is not built.
    expect(find.textContaining('CH30P0'), findsOneWidget);
    expect(find.textContaining('CH10P0'), findsNothing);
  });

  testWidgets('reports the new page position when the reader turns a page', (
    tester,
  ) async {
    final reported = <ReaderParagraph>[];
    await tester.pumpWidget(
      host(
        items: buildItems(),
        initialCursor: const PlaybackCursor(chapterId: 10, paragraphIndex: 0),
        onReadingPositionChanged: reported.add,
      ),
    );
    await tester.pumpAndSettle();

    // Opening does not report; turning to the next page does.
    expect(reported, isEmpty);

    await tester.fling(find.byType(PageView), const Offset(-260, 0), 1200);
    await tester.pumpAndSettle();

    expect(reported, isNotEmpty);
  });

  testWidgets(
    'slide mode: controller turns forward on next, back on previous',
    (tester) async {
      final reported = <ReaderParagraph>[];
      final controller = PaginatedReaderController();
      await tester.pumpWidget(
        host(
          items: buildItems(),
          controller: controller,
          initialCursor: const PlaybackCursor(chapterId: 10, paragraphIndex: 0),
          onReadingPositionChanged: reported.add,
        ),
      );
      await tester.pumpAndSettle();

      // Opening the pager reports nothing until a turn happens.
      expect(reported, isEmpty);

      // Right-tap → next page: a new page position is reported.
      controller.nextPage();
      await tester.pumpAndSettle();
      expect(reported, isNotEmpty);
      final afterNext = reported.last;

      // Left-tap → previous page: turns back to the opening page, whose first
      // paragraph is the initial cursor's, reporting a different position.
      controller.previousPage();
      await tester.pumpAndSettle();
      expect(reported.last, isNot(afterNext));
      expect(reported.last.chapterId, 10);
      expect(reported.last.index, 0);
    },
  );

  testWidgets('slide mode: previousPage on the first page is a no-op', (
    tester,
  ) async {
    final reported = <ReaderParagraph>[];
    final controller = PaginatedReaderController();
    await tester.pumpWidget(
      host(
        items: buildItems(),
        controller: controller,
        initialCursor: const PlaybackCursor(chapterId: 10, paragraphIndex: 0),
        onReadingPositionChanged: reported.add,
      ),
    );
    await tester.pumpAndSettle();

    // Already on the first page — a left tap turns nowhere and reports nothing.
    controller.previousPage();
    await tester.pumpAndSettle();
    expect(reported, isEmpty);
  });

  testWidgets('curl mode: controller turns to the next page', (tester) async {
    final reported = <ReaderParagraph>[];
    final controller = PaginatedReaderController();
    await tester.pumpWidget(
      host(
        items: buildItems(),
        mode: ReaderPageMode.curl,
        controller: controller,
        initialCursor: const PlaybackCursor(chapterId: 10, paragraphIndex: 0),
        onReadingPositionChanged: reported.add,
      ),
    );
    await tester.pumpAndSettle();
    expect(reported, isEmpty);

    controller.nextPage();
    await tester.pumpAndSettle();
    expect(reported, isNotEmpty);
  });

  testWidgets('requests the next chapter when opening near the end', (
    tester,
  ) async {
    Set<int>? requestedChapters;
    ReaderViewportAnchor? requestedAnchor;
    await tester.pumpWidget(
      host(
        items: buildItems(),
        initialCursor: const PlaybackCursor(chapterId: 50, paragraphIndex: 3),
        onLoadNext: ({required visibleChapterIds, required anchor}) async {
          requestedChapters = visibleChapterIds;
          requestedAnchor = anchor;
          return const ReaderWindowMutation(changed: false, postponed: false);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedChapters, isNotNull);
    expect(requestedChapters, contains(50));
    expect(requestedAnchor, isNotNull);
    expect(requestedAnchor!.itemKey, isNotEmpty);
  });

  testWidgets('does not request an edge load when opening mid-window', (
    tester,
  ) async {
    var nextCalls = 0;
    var previousCalls = 0;
    await tester.pumpWidget(
      host(
        items: buildItems(chapters: 9),
        initialCursor: const PlaybackCursor(chapterId: 50, paragraphIndex: 0),
        onLoadNext: ({required visibleChapterIds, required anchor}) async {
          nextCalls++;
          return const ReaderWindowMutation(changed: false, postponed: false);
        },
        onLoadPrevious: ({required visibleChapterIds, required anchor}) async {
          previousCalls++;
          return const ReaderWindowMutation(changed: false, postponed: false);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(nextCalls, 0);
    expect(previousCalls, 0);
  });

  testWidgets('curl mode mounts a flip view opened on the cursor page', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        items: buildItems(),
        mode: ReaderPageMode.curl,
        initialCursor: const PlaybackCursor(chapterId: 30, paragraphIndex: 0),
      ),
    );
    // Before the flip effect captures page bitmaps (~100ms), the live page
    // child is still in the tree, so its text is findable; after settling the
    // widget swaps it for a CustomPaint snapshot.
    await tester.pump();

    expect(find.byType(PageFlipWidget), findsOneWidget);
    final flip = tester.widget<PageFlipWidget>(find.byType(PageFlipWidget));
    // The cursor is two chapters in, so it opens well past the first page.
    expect(flip.initialIndex, greaterThan(0));
    expect(find.textContaining('CH30P0'), findsOneWidget);
    expect(find.textContaining('CH10P0'), findsNothing);

    // Drain the flip widget's pending image-capture timers.
    await tester.pumpAndSettle();
  });

  testWidgets('curl mode requests the next chapter when opening near the end', (
    tester,
  ) async {
    var requested = false;
    await tester.pumpWidget(
      host(
        items: buildItems(),
        mode: ReaderPageMode.curl,
        initialCursor: const PlaybackCursor(chapterId: 50, paragraphIndex: 3),
        onLoadNext: ({required visibleChapterIds, required anchor}) async {
          requested = true;
          return const ReaderWindowMutation(changed: false, postponed: false);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(requested, isTrue);
  });

  testWidgets('slide mode flips to the playing page as narration advances', (
    tester,
  ) async {
    final cursor = ValueNotifier<PlaybackCursor?>(
      const PlaybackCursor(chapterId: 10, paragraphIndex: 0),
    );
    addTearDown(cursor.dispose);

    await tester.pumpWidget(followHost(cursor: cursor, active: true));
    await tester.pumpAndSettle();

    // Opens on the initial (playing) paragraph; a much later chapter is not
    // built yet.
    expect(find.textContaining('CH10P0'), findsOneWidget);
    expect(find.textContaining('CH30P0'), findsNothing);

    // The narration advances two chapters ahead → the view follows to it.
    cursor.value = const PlaybackCursor(chapterId: 30, paragraphIndex: 0);
    await tester.pumpAndSettle();

    expect(find.textContaining('CH30P0'), findsOneWidget);
    expect(find.textContaining('CH10P0'), findsNothing);
  });

  testWidgets('does not follow the narration while playback is inactive', (
    tester,
  ) async {
    final cursor = ValueNotifier<PlaybackCursor?>(
      const PlaybackCursor(chapterId: 10, paragraphIndex: 0),
    );
    addTearDown(cursor.dispose);

    await tester.pumpWidget(followHost(cursor: cursor, active: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('CH10P0'), findsOneWidget);

    // Cursor moves, but with playback inactive the view stays where the reader
    // left it (a manual page turn is never undone).
    cursor.value = const PlaybackCursor(chapterId: 30, paragraphIndex: 0);
    await tester.pumpAndSettle();

    expect(find.textContaining('CH10P0'), findsOneWidget);
    expect(find.textContaining('CH30P0'), findsNothing);
  });

  testWidgets('curl mode reports the playing page as narration advances', (
    tester,
  ) async {
    final reported = <ReaderParagraph>[];
    final cursor = ValueNotifier<PlaybackCursor?>(
      const PlaybackCursor(chapterId: 10, paragraphIndex: 0),
    );
    addTearDown(cursor.dispose);

    await tester.pumpWidget(
      followHost(
        cursor: cursor,
        active: true,
        mode: ReaderPageMode.curl,
        onReadingPositionChanged: reported.add,
      ),
    );
    await tester.pumpAndSettle();

    // Opening reports nothing; advancing the narration drives a programmatic
    // flip that reports the new page's position.
    expect(reported, isEmpty);

    cursor.value = const PlaybackCursor(chapterId: 30, paragraphIndex: 0);
    await tester.pumpAndSettle();

    expect(reported, isNotEmpty);
    expect(reported.last.chapterId, 30);
  });
}
