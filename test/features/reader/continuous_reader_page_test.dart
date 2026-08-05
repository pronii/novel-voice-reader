import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/reader/application/reader_chapter_window_controller.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/reader/presentation/reader_page.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  testWidgets('renders adjacent chapter text in one continuous list', (
    tester,
  ) async {
    final sections = [_section(1), _section(2)];

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapters: sections.map((section) => section.chapter).toList(),
          sections: sections,
          currentChapterId: 1,
          initialCursor: const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
        ),
      ),
    );

    expect(find.byType(ScrollablePositionedList), findsOneWidget);
    await tester.scrollUntilVisible(find.text('第2章第1段正文。'), 240);
    expect(find.text('第2章'), findsOneWidget);
    expect(find.text('第2章第1段正文。'), findsOneWidget);
  });

  testWidgets('appending a section keeps the existing list state', (
    tester,
  ) async {
    var sections = [_section(1)];
    late StateSetter setHostState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return ReaderPage(
              bookId: 1,
              bookTitle: '测试书',
              chapters: const [
                ReaderChapter(id: 1, index: 0, title: '第1章'),
                ReaderChapter(id: 2, index: 1, title: '第2章'),
              ],
              sections: sections,
              currentChapterId: 1,
              initialCursor: const PlaybackCursor(
                chapterId: 1,
                paragraphIndex: 0,
              ),
            );
          },
        ),
      ),
    );
    final originalListState = tester.state(
      find.byType(ScrollablePositionedList),
    );

    setHostState(() => sections = [...sections, _section(2)]);
    await tester.pump();

    expect(
      tester.state(find.byType(ScrollablePositionedList)),
      same(originalListState),
    );
  });

  testWidgets('requests the next section before bottom overscroll', (
    tester,
  ) async {
    var loadCalls = 0;
    final sections = [_section(1, paragraphCount: 8)];

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapters: const [
            ReaderChapter(id: 1, index: 0, title: '第1章'),
            ReaderChapter(id: 2, index: 1, title: '第2章'),
          ],
          sections: sections,
          currentChapterId: 1,
          initialCursor: const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
          onLoadNext: ({required visibleChapterIds, required anchor}) async {
            loadCalls++;
            return const ReaderWindowMutation(changed: false, postponed: false);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('第1章第7段正文。'), 240);
    await tester.pump();

    expect(loadCalls, greaterThan(0));
  });

  testWidgets('reports progress with the visible paragraph chapter id', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ReaderParagraph? reported;
    final sections = [
      _section(1, paragraphCount: 8),
      _section(2, paragraphCount: 8),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapters: sections.map((section) => section.chapter).toList(),
          sections: sections,
          currentChapterId: 1,
          initialCursor: const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
          onReadingPositionChanged: (paragraph) => reported = paragraph,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('第2章第2段正文。'), 320);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(reported?.chapterId, 2);
  });

  testWidgets('shows book completion only when the final section is loaded', (
    tester,
  ) async {
    final sections = [_section(2)];

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapters: const [
            ReaderChapter(id: 1, index: 0, title: '第1章'),
            ReaderChapter(id: 2, index: 1, title: '第2章'),
          ],
          sections: sections,
          currentChapterId: 2,
          initialCursor: const PlaybackCursor(chapterId: 2, paragraphIndex: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('全书读完'), 240);

    expect(find.text('全书读完'), findsOneWidget);
  });
}

ReaderChapterSection _section(int chapterId, {int paragraphCount = 3}) {
  final chapter = ReaderChapter(
    id: chapterId,
    index: chapterId - 1,
    title: '第$chapterId章',
  );
  return ReaderChapterSection(
    chapter: chapter,
    paragraphs: List.generate(
      paragraphCount,
      (index) => ReaderParagraph(
        id: chapterId * 100 + index,
        chapterId: chapterId,
        index: index,
        text: '第$chapterId章第${index + 1}段正文。',
      ),
    ),
  );
}
