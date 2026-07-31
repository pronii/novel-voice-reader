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
}
