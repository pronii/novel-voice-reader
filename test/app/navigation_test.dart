import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/app/app.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/speech/data/tencent_tts_usage_repository.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  testWidgets('opens a book and exposes reader playback controls', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.createBookWithChapter(
      title: '测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。', '第二段。'],
    );

    await tester.pumpWidget(NovelVoiceReaderApp(database: database));
    await _pumpUntilFound(tester, find.text('测试书'));
    await tester.tap(find.text('测试书'));
    await _pumpUntilFound(tester, find.text('第一章'));

    expect(find.text('第一章'), findsWidgets);
    expect(find.byTooltip('返回书架'), findsOneWidget);
    expect(find.byTooltip('播放'), findsOneWidget);
    expect(find.byTooltip('播放器'), findsOneWidget);

    await tester.tap(find.byTooltip('返回书架'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('导入小说'), findsOneWidget);
    expect(find.byTooltip('返回书架'), findsNothing);
    expect(find.text('测试书'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('reopens the newly selected chapter after a pending scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final bookId = await database.createBookWithChapter(
      title: '切章测试书',
      chapterTitle: '第一章',
      paragraphs: List<String>.generate(
        10,
        (index) => '第一章第${index + 1}段。这是一段足够长的正文，用于产生可保存的滚动位置。',
      ),
    );
    final secondChapterId = await database
        .into(database.chapters)
        .insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            chapterIndex: 1,
            title: '第二章',
          ),
        );
    final secondParagraphId = await database
        .into(database.paragraphs)
        .insert(
          ParagraphsCompanion.insert(
            chapterId: secondChapterId,
            paragraphIndex: 0,
            content: '第二章第一段。',
          ),
        );

    await tester.pumpWidget(NovelVoiceReaderApp(database: database));
    await _pumpUntilFound(tester, find.text('切章测试书'));
    await tester.tap(find.text('切章测试书'));
    await _pumpUntilFound(tester, find.byTooltip('章节目录'));

    await tester.drag(
      find.byType(ScrollablePositionedList),
      const Offset(0, -300),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('章节目录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('第二章'));
    await _pumpUntilFound(
      tester,
      find.byKey(ValueKey<String>('active-paragraph-$secondParagraphId')),
    );

    await tester.tap(find.byTooltip('返回书架'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('切章测试书'));
    await _pumpUntilFound(
      tester,
      find.byKey(ValueKey<String>('active-paragraph-$secondParagraphId')),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('persists Tencent voice and local monthly quota from settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(NovelVoiceReaderApp(database: database));
    await _pumpUntilFound(tester, find.byTooltip('语音设置'));
    await tester.tap(find.byTooltip('语音设置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-500, 0),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('腾讯云'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.widgetWithText(TextField, '每月免费额度（字符）'),
      '1000000',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await _pumpUntilFound(tester, find.text('语音设置已保存'));

    final profiles = await database.select(database.voiceProfiles).get();
    final usage = await TencentTtsUsageRepository(database).current();
    expect(profiles.single.providerType, 'tencent');
    expect(profiles.single.voice, '1001');
    expect(usage.quotaCharacters, 1000000);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .toList();
  fail('Timed out waiting for the expected widget. Visible text: $visibleText');
}
