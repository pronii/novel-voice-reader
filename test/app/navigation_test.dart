import 'dart:async';
import 'dart:collection';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/app/app.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_handler.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_coordinator.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/speech/data/tencent_tts_usage_repository.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  testWidgets('wires the effective playback speed through the player route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.createBookWithChapter(
      title: '倍速测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。'],
    );
    final controller = AttachablePlaybackController();
    final delegate = _SpeedPlaybackController();
    await controller.attach(delegate);
    final handler = NovelAudioHandler(controller);
    await handler.setSpeed(1.25);
    delegate.speedChanges.clear();
    final runtime = PlaybackRuntime(controller: controller, handler: handler);

    await tester.pumpWidget(
      NovelVoiceReaderApp(database: database, playbackRuntime: runtime),
    );
    await _pumpUntilFound(tester, find.text('倍速测试书'));
    await tester.tap(find.text('倍速测试书'));
    await _pumpUntilFound(tester, find.byTooltip('播放器'));
    tester
        .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.graphic_eq))
        .onPressed!
        .call();
    await _pumpUntilFound(tester, find.text('1.5x'));

    expect(
      tester
          .widget<SegmentedButton<double>>(find.byType(SegmentedButton<double>))
          .selected,
      {1.25},
    );
    await tester.tap(find.text('1.5x'));
    await tester.pump();

    expect(delegate.speedChanges, [1.5]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

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

  testWidgets('shows playback highlight when opening an already playing book', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final bookId = await database.createBookWithChapter(
      title: '高亮测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。'],
    );
    final chapter = (await database.chaptersForBook(bookId)).single;
    final controller = AttachablePlaybackController();
    final runtime = PlaybackRuntime(
      controller: controller,
      handler: NovelAudioHandler(controller),
    );
    final cursor = PlaybackCursor(chapterId: chapter.id, paragraphIndex: 0);
    await runtime.replaceAndPlayFrom(
      PlaybackCoordinator(
        provider: _NavigationSpeechProvider(),
        progress: _NavigationProgressRepository(),
        paragraphs: _NavigationParagraphSource(),
        voiceProfile: VoiceProfile.system(),
      ),
      cursor,
      token: runtime.beginReplacement(),
    );

    await tester.pumpWidget(
      NovelVoiceReaderApp(database: database, playbackRuntime: runtime),
    );
    await _pumpUntilFound(tester, find.text('高亮测试书'));
    await tester.tap(find.text('高亮测试书'));
    await _pumpUntilFound(
      tester,
      find.byKey(ValueKey<String>('playing-paragraph-${chapter.id}-0')),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('opens a book with no chapters without loading forever', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await database
        .into(database.books)
        .insert(BooksCompanion.insert(title: '空书'));

    await tester.pumpWidget(NovelVoiceReaderApp(database: database));
    await _pumpUntilFound(tester, find.text('空书'));
    await tester.tap(find.text('空书'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byTooltip('返回书架'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

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

  testWidgets(
    'rolls back Tencent settings when the second secret write fails',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final secureValues = _FailOnceMap(const {
        'tencent_tts_secret_id': 'old-id',
        'tencent_tts_secret_key': 'old-key',
      }, failingKey: 'tencent_tts_secret_key');
      FlutterSecureStorage.setMockInitialValues(secureValues);
      addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
      final database = AppDatabase.forTesting(NativeDatabase.memory());

      await tester.pumpWidget(NovelVoiceReaderApp(database: database));
      await _openTencentSettings(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'SecretId'),
        'new-id',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'SecretKey'),
        'new-key',
      );
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await _pumpUntilFound(tester, find.text('语音设置保存失败'));

      expect(await database.select(database.voiceProfiles).get(), isEmpty);
      expect(secureValues['tencent_tts_secret_id'], 'old-id');
      expect(secureValues['tencent_tts_secret_key'], 'old-key');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('rolls back the profile when Tencent quota persistence fails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final secureValues = <String, String>{
      'tencent_tts_secret_id': 'old-id',
      'tencent_tts_secret_key': 'old-key',
    };
    FlutterSecureStorage.setMockInitialValues(secureValues);
    addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customStatement('''
      CREATE TRIGGER fail_tencent_quota_insert
      BEFORE INSERT ON tencent_tts_monthly_usages
      BEGIN
        SELECT RAISE(FAIL, 'quota write failed');
      END;
    ''');

    await tester.pumpWidget(NovelVoiceReaderApp(database: database));
    await _openTencentSettings(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'SecretId'),
      'new-id',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'SecretKey'),
      'new-key',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '每月免费额度（字符）'),
      '1000',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(await database.select(database.voiceProfiles).get(), isEmpty);
    expect(secureValues['tencent_tts_secret_id'], 'old-id');
    expect(secureValues['tencent_tts_secret_key'], 'old-key');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });
}

final class _SpeedPlaybackController implements PlaybackController {
  final List<double> speedChanges = [];

  @override
  PlaybackCursor? get cursor => null;

  @override
  Future<void> nextParagraph() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> playFrom(PlaybackCursor cursor) async {}

  @override
  Future<void> previousParagraph() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> setSpeed(double speed) async => speedChanges.add(speed);
}

final class _NavigationParagraphSource implements PlaybackParagraphSource {
  @override
  Future<PlaybackParagraph?> at(PlaybackCursor cursor) async {
    return PlaybackParagraph(id: 1, cursor: cursor, text: '第一段。');
  }

  @override
  Future<PlaybackParagraph?> nextAfter(PlaybackCursor cursor) async => null;
}

final class _NavigationProgressRepository
    implements PlaybackProgressRepository {
  @override
  Future<void> confirm(PlaybackCursor cursor) async {}
}

final class _NavigationSpeechProvider implements SpeechProvider {
  final StreamController<SpeechEvent> _events =
      StreamController<SpeechEvent>.broadcast();

  @override
  Stream<SpeechEvent> get events => _events.stream;

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> prepare(segment, VoiceProfile profile) async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() => _events.close();
}

Future<void> _openTencentSettings(WidgetTester tester) async {
  await _pumpUntilFound(tester, find.byTooltip('语音设置'));
  await tester.tap(find.byTooltip('语音设置'));
  await _pumpUntilFound(tester, find.byType(SingleChildScrollView));
  await tester.drag(find.byType(SingleChildScrollView), const Offset(-500, 0));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('腾讯云'));
  await tester.pump(const Duration(milliseconds: 300));
}

final class _FailOnceMap extends MapBase<String, String> {
  _FailOnceMap(Map<String, String> initialValues, {required this.failingKey})
    : _values = Map.of(initialValues);

  final Map<String, String> _values;
  final String failingKey;
  bool _hasFailed = false;

  @override
  String? operator [](Object? key) => _values[key];

  @override
  void operator []=(String key, String value) {
    if (key == failingKey && !_hasFailed) {
      _hasFailed = true;
      throw StateError('secure write failed');
    }
    _values[key] = value;
  }

  @override
  void clear() => _values.clear();

  @override
  Iterable<String> get keys => _values.keys;

  @override
  String? remove(Object? key) => _values.remove(key);
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
