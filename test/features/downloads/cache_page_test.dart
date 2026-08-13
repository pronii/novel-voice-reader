import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/downloads/domain/download_policy.dart';
import 'package:novel_voice_reader/features/downloads/presentation/cache_page.dart';

void main() {
  testWidgets('accepts an arbitrary valid chapter-ahead count', (tester) async {
    DownloadPolicy? applied;
    await tester.pumpWidget(
      MaterialApp(
        home: CachePage(
          chapterCount: 80,
          currentChapterIndex: 10,
          onApply: (policy) => applied = policy,
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('chaptersAhead')), '37');
    await tester.tap(find.text('应用'));
    await tester.pump();

    expect(find.text('将缓存当前章节及后续 37 章'), findsOneWidget);
    expect(applied?.chaptersAhead, 37);
  });

  testWidgets('whole-book mode disables the chapter count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CachePage(
          chapterCount: 12,
          currentChapterIndex: 3,
          onApply: (_) {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('wholeBook')));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byKey(const Key('chaptersAhead'))).enabled,
      isFalse,
    );
    expect(find.text('将缓存所有未读章节'), findsOneWidget);
  });
}
