import 'dart:async';
import 'dart:collection';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/app/app.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_handler.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_coordinator.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../support/test_voice_profile.dart';

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
    await _showReaderToolbar(tester);
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
    await _showReaderToolbar(tester);

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
    final coordinator = PlaybackCoordinator(
      provider: _NavigationSpeechProvider(),
      progress: _NavigationProgressRepository(),
      paragraphs: _NavigationParagraphSource(),
      voiceProfile: testVoiceProfile(),
      // This test never emits SpeechCompleted, so a live watchdog would keep
      // retrying/advancing and starve the fake-async isolate. Inject an inert,
      // cancellable timer — the watchdog itself is covered in the coordinator
      // unit tests, not here.
      scheduleWatchdog: _inertWatchdog,
    );
    await runtime.replaceAndPlayFrom(
      coordinator,
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

  testWidgets('reads continuously across chapters and restores the position', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final bookId = await _createChapteredBook(
      database,
      title: '连续阅读测试书',
      chapterCount: 7,
      paragraphCount: 6,
    );
    final chapters = await database.chaptersForBook(bookId);
    await database.upsertProgress(
      bookId: bookId,
      chapterId: chapters[2].id,
      paragraphIndex: 0,
    );

    await tester.pumpWidget(NovelVoiceReaderApp(database: database));
    await _pumpUntilFound(tester, find.text('连续阅读测试书'));
    await tester.tap(find.text('连续阅读测试书'));
    await _pumpUntilFound(tester, find.text('第3章第1段正文。'));
    await tester.scrollUntilVisible(
      find.text('第6章第2段正文。'),
      320,
      scrollable: find.descendant(
        of: find.byType(ScrollablePositionedList),
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 40,
    );
    await tester.drag(
      find.byType(ScrollablePositionedList),
      const Offset(0, -300),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('第6章第2段正文。'));
    ReadingProgressRecord? progress;
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      progress = await database.progressForBook(bookId);
      if (progress?.chapterId == chapters[5].id) {
        break;
      }
    }
    expect(progress?.chapterId, chapters[5].id);

    await _showReaderToolbar(tester);
    // Tapping the paragraph above also toggled the toolbar; make sure its
    // slide-in animation has finished before we tap a button inside it.
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回书架'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('连续阅读测试书'));
    await _pumpUntilFound(tester, find.text('第6章第2段正文。'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('jumps from the directory to a distant chapter window', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await _createChapteredBook(
      database,
      title: '目录跳转测试书',
      chapterCount: 7,
      paragraphCount: 2,
    );

    await tester.pumpWidget(NovelVoiceReaderApp(database: database));
    await _pumpUntilFound(tester, find.text('目录跳转测试书'));
    await tester.tap(find.text('目录跳转测试书'));
    await _pumpUntilFound(tester, find.byTooltip('章节目录'));
    await _showReaderToolbar(tester);
    await tester.tap(find.byTooltip('章节目录'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '7');
    await tester.pump();
    await tester.tap(find.widgetWithText(ListTile, '第7章'));
    await _pumpUntilFound(tester, find.text('第7章第1段正文。'));

    expect(find.text('第7章第1段正文。'), findsOneWidget);
    expect(find.text('第3章第1段正文。'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('follows playback into a chapter outside the reading window', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final bookId = await _createChapteredBook(
      database,
      title: '跨章高亮测试书',
      chapterCount: 7,
      paragraphCount: 1,
    );
    final chapters = await database.chaptersForBook(bookId);
    final controller = AttachablePlaybackController();
    final runtime = PlaybackRuntime(
      controller: controller,
      handler: NovelAudioHandler(controller),
    );
    final target = PlaybackCursor(chapterId: chapters[6].id, paragraphIndex: 0);
    final coordinator = PlaybackCoordinator(
      provider: _NavigationSpeechProvider(),
      progress: _NavigationProgressRepository(),
      paragraphs: _NavigationParagraphSource(),
      voiceProfile: testVoiceProfile(),
      // See the highlight test above: no SpeechCompleted is emitted here, so the
      // watchdog is stubbed out to keep the fake-async isolate quiescent.
      scheduleWatchdog: _inertWatchdog,
    );
    await runtime.replaceAndPlayFrom(
      coordinator,
      target,
      token: runtime.beginReplacement(),
    );

    await tester.pumpWidget(
      NovelVoiceReaderApp(database: database, playbackRuntime: runtime),
    );
    await _pumpUntilFound(tester, find.text('跨章高亮测试书'));
    await tester.tap(find.text('跨章高亮测试书'));
    await _pumpUntilFound(
      tester,
      find.byKey(ValueKey<String>('playing-paragraph-${chapters[6].id}-0')),
    );

    expect(find.text('第7章第1段正文。'), findsOneWidget);
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
    await _showReaderToolbar(tester);

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
    await _showReaderToolbar(tester);
    await tester.tap(find.byTooltip('章节目录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('第二章'));
    await _pumpUntilFound(
      tester,
      find.byKey(ValueKey<String>('paragraph-$secondParagraphId')),
    );

    await _showReaderToolbar(tester);
    await tester.tap(find.byTooltip('返回书架'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('切章测试书'));
    await _pumpUntilFound(
      tester,
      find.byKey(ValueKey<String>('paragraph-$secondParagraphId')),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('does not persist MiMo profile when secure key write fails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final secureValues = _FailOnceMap(const {
      'mimo_tts_api_key': 'old-key',
    }, failingKey: 'mimo_tts_api_key');
    FlutterSecureStorage.setMockInitialValues(secureValues);
    addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
    final database = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(NovelVoiceReaderApp(database: database));
    await _openMiMoSettings(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'MiMo API Key'),
      'new-key',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await _pumpUntilFound(tester, find.text('语音设置保存失败'));

    expect(await database.select(database.voiceProfiles).get(), isEmpty);
    expect(secureValues['mimo_tts_api_key'], 'old-key');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('restores saved MiMo style and credential status on reopen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({
      'mimo_tts_api_key': 'stored-secret',
    });
    addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await database
        .into(database.voiceProfiles)
        .insert(
          VoiceProfilesCompanion.insert(
            providerType: 'mimo',
            voice: const Value('Dean'),
            speed: const Value(1.25),
            style: const Value('沉稳自然地朗读'),
          ),
        );

    await tester.pumpWidget(NovelVoiceReaderApp(database: database));
    await _pumpUntilFound(tester, find.byTooltip('语音设置'));
    await tester.tap(find.byTooltip('语音设置'));
    await _pumpUntilFound(tester, find.text('MiMo API Key'));

    expect(find.text('Dean（英文男声）'), findsOneWidget);
    expect(find.text('已保存，留空则保持不变'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '朗读风格（可选）'))
          .controller
          ?.text,
      '沉稳自然地朗读',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('rolls back MiMo key when profile persistence fails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final secureValues = <String, String>{'mimo_tts_api_key': 'old-key'};
    FlutterSecureStorage.setMockInitialValues(secureValues);
    addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.customStatement('''
      CREATE TRIGGER fail_mimo_profile_insert
      BEFORE INSERT ON voice_profiles
      BEGIN
        SELECT RAISE(FAIL, 'profile write failed');
      END;
    ''');

    await tester.pumpWidget(NovelVoiceReaderApp(database: database));
    await _openMiMoSettings(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'MiMo API Key'),
      'new-key',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await _pumpUntilFound(tester, find.text('语音设置保存失败'));

    expect(await database.select(database.voiceProfiles).get(), isEmpty);
    expect(secureValues['mimo_tts_api_key'], 'old-key');

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

// A watchdog factory that never schedules anything: it returns a fake [Timer]
// that is not created through the zone's clock, so the fake-async harness never
// tracks it as a pending timer, and it never fires. These navigation tests do
// not exercise the watchdog (which is covered by the coordinator unit tests);
// stubbing it out keeps the fake-async isolate quiescent.
Timer _inertWatchdog(Duration duration, void Function() onTimeout) =>
    _InertTimer();

final class _InertTimer implements Timer {
  @override
  void cancel() {}

  @override
  bool get isActive => false;

  @override
  int get tick => 0;
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
  Future<void> prepare(SpeechSegment segment, VoiceProfile profile) async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() => _events.close();
}

Future<int> _createChapteredBook(
  AppDatabase database, {
  required String title,
  required int chapterCount,
  required int paragraphCount,
}) async {
  final bookId = await database
      .into(database.books)
      .insert(BooksCompanion.insert(title: title));
  for (var chapterIndex = 0; chapterIndex < chapterCount; chapterIndex++) {
    final chapterId = await database
        .into(database.chapters)
        .insert(
          ChaptersCompanion.insert(
            bookId: bookId,
            chapterIndex: chapterIndex,
            title: '第${chapterIndex + 1}章',
          ),
        );
    for (
      var paragraphIndex = 0;
      paragraphIndex < paragraphCount;
      paragraphIndex++
    ) {
      await database
          .into(database.paragraphs)
          .insert(
            ParagraphsCompanion.insert(
              chapterId: chapterId,
              paragraphIndex: paragraphIndex,
              content: '第${chapterIndex + 1}章第${paragraphIndex + 1}段正文。',
            ),
          );
    }
  }
  return bookId;
}

Future<void> _openMiMoSettings(WidgetTester tester) async {
  await _pumpUntilFound(tester, find.byTooltip('语音设置'));
  await tester.tap(find.byTooltip('语音设置'));
  await _selectVoiceProvider(tester, 'MiMo');
}

Future<void> _selectVoiceProvider(WidgetTester tester, String label) async {
  final dropdown = find.byKey(const Key('tts-provider-dropdown'));
  await _pumpUntilFound(tester, dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _showReaderToolbar(WidgetTester tester) async {
  final toolbar = find.byKey(const Key('reader-toolbar'));
  final pointerGate = find.descendant(
    of: toolbar,
    matching: find.byType(IgnorePointer),
  );
  if (tester.widget<IgnorePointer>(pointerGate).ignoring) {
    final body = find.byKey(const Key('reader-body'));
    await tester.tapAt(tester.getTopLeft(body) + const Offset(2, 2));
    await tester.pumpAndSettle();
  }
  expect(tester.widget<AnimatedSlide>(toolbar).offset, Offset.zero);
  expect(tester.widget<IgnorePointer>(pointerGate).ignoring, isFalse);
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
