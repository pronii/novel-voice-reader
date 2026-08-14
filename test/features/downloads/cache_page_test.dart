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

  testWidgets('normalizes an unsupported saved cache limit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CachePage(
          chapterCount: 12,
          currentChapterIndex: 3,
          initialPolicy: DownloadPolicy(
            chaptersAhead: 2,
            wholeBook: false,
            wifiOnly: true,
            maxCacheBytes: 300 * 1024 * 1024,
          ),
          onApply: (_) {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('512 MB'), findsOneWidget);
  });

  testWidgets('shows current cache usage and segment count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CachePage(
          chapterCount: 12,
          currentChapterIndex: 3,
          cachedBytes: 64 * 1024 * 1024,
          cachedSegmentCount: 18,
          onApply: (_) {},
        ),
      ),
    );

    expect(find.text('64.0 MB · 18 段'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
