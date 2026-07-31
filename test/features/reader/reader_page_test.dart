import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/reader/presentation/reader_page.dart';

void main() {
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
          paragraphs: const [
            ReaderParagraph(id: 100, index: 0, text: '第一段。'),
          ],
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

  testWidgets('invokes previous and next chapter callbacks', (tester) async {
    var previousCount = 0;
    var nextCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          bookId: 1,
          bookTitle: '测试书',
          chapterTitle: '第二章',
          chapters: const [
            ReaderChapter(id: 10, index: 0, title: '第一章'),
            ReaderChapter(id: 20, index: 1, title: '第二章'),
            ReaderChapter(id: 30, index: 2, title: '第三章'),
          ],
          currentChapterId: 20,
          paragraphs: const [
            ReaderParagraph(id: 200, index: 0, text: '第二章第一段。'),
          ],
          onPreviousChapter: () => previousCount += 1,
          onNextChapter: () => nextCount += 1,
        ),
      ),
    );

    await tester.tap(find.byTooltip('上一章'));
    await tester.tap(find.byTooltip('下一章'));

    expect(previousCount, 1);
    expect(nextCount, 1);
  });
}
