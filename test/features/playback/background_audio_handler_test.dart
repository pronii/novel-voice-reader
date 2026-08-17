import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/features/diagnostics/domain/playback_telemetry.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_handler.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_coordinator.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_timeline.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

import '../../support/test_voice_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lock-screen commands map to paragraph playback controls', () async {
    final controller = FakePlaybackController(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 3),
    );
    final handler = NovelAudioHandler(controller);

    await handler.play();
    await handler.pause();
    await handler.skipToNext();
    await handler.skipToPrevious();

    expect(controller.resumeCalls, 1);
    expect(controller.pauseCalls, 1);
    expect(controller.nextCalls, 1);
    expect(controller.previousCalls, 1);
    expect(controller.cursor?.paragraphIndex, 3);
  });

  test('playback speed is forwarded and published in playback state', () async {
    final controller = FakePlaybackController(null);
    final handler = NovelAudioHandler(controller);

    await handler.setSpeed(1.5);

    expect(controller.speedChanges, [1.5]);
    expect(handler.playbackState.value.speed, 1.5);
  });

  test(
    'does not publish playback speed without an attached delegate',
    () async {
      final controller = AttachablePlaybackController();
      final handler = NovelAudioHandler(controller);

      await expectLater(handler.setSpeed(1.5), throwsStateError);

      expect(handler.playbackState.value.speed, 1);
    },
  );

  test('publishes book and chapter metadata for the lock screen', () async {
    final handler = NovelAudioHandler(FakePlaybackController(null));

    handler.publishNowPlaying(bookId: 7, bookTitle: '测试书', chapterTitle: '第一章');

    expect(handler.mediaItem.value?.id, 'book-7');
    expect(handler.mediaItem.value?.title, '测试书');
    expect(handler.mediaItem.value?.album, '第一章');
    expect(
      handler.playbackState.value.controls,
      containsAll([MediaControl.skipToPrevious, MediaControl.skipToNext]),
    );
  });

  test('runtime serializes global coordinator replacement', () async {
    final firstProvider = RuntimeSpeechProvider(
      disposeCompleter: Completer<void>(),
    );
    final secondProvider = RuntimeSpeechProvider();
    final thirdProvider = RuntimeSpeechProvider();
    final controller = AttachablePlaybackController();
    final runtime = PlaybackRuntime(
      controller: controller,
      handler: NovelAudioHandler(controller),
    );
    final first = createCoordinator(firstProvider);
    final second = createCoordinator(secondProvider);
    final third = createCoordinator(thirdProvider);
    await runtime.replace(first);

    final replaceSecond = runtime.replace(second);
    await pumpEventQueue();
    expect(firstProvider.disposeCalls, 1);

    final replaceThird = runtime.replace(third);
    await pumpEventQueue();
    expect(secondProvider.disposeCalls, 0);

    firstProvider.disposeCompleter!.complete();
    await replaceSecond;
    await replaceThird;
    await controller.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );

    expect(secondProvider.disposeCalls, 1);
    expect(thirdProvider.prepared, hasLength(1));
    await runtime.dispose();
  });

  test('runtime reapplies the effective speed to a replacement', () async {
    final firstProvider = RuntimeSpeechProvider();
    final replacementProvider = RuntimeSpeechProvider();
    final controller = AttachablePlaybackController();
    final handler = NovelAudioHandler(controller);
    final runtime = PlaybackRuntime(controller: controller, handler: handler);
    await runtime.replace(createCoordinator(firstProvider));
    await handler.setSpeed(1.5);

    await runtime.replace(createCoordinator(replacementProvider));

    expect(replacementProvider.speedChanges, [1.5]);
    expect(handler.playbackState.value.speed, 1.5);
    await runtime.dispose();
  });

  test('runtime publishes the active coordinator playback timeline', () async {
    final provider = RuntimeSpeechProvider();
    final controller = AttachablePlaybackController();
    final handler = NovelAudioHandler(controller);
    final runtime = PlaybackRuntime(controller: controller, handler: handler);
    await runtime.replaceAndPlayFrom(
      createCoordinator(provider),
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
      token: runtime.beginReplacement(),
    );

    provider.publishTimeline(
      const PlaybackTimeline(
        position: Duration(seconds: 15),
        duration: Duration(minutes: 1),
      ),
    );

    expect(handler.currentTimeline.position, const Duration(seconds: 15));
    expect(handler.currentTimeline.duration, const Duration(minutes: 1));
    await runtime.dispose();
    expect(handler.currentTimeline, PlaybackTimeline.zero);
  });

  test('skipping after pause republishes the real playing state', () async {
    final provider = RuntimeSpeechProvider();
    final controller = AttachablePlaybackController();
    final handler = NovelAudioHandler(controller);
    final runtime = PlaybackRuntime(controller: controller, handler: handler);
    await runtime.replaceAndPlayFrom(
      createCoordinator(provider, paragraphs: TwoParagraphSource()),
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
      token: runtime.beginReplacement(),
    );

    expect(handler.playbackState.value.playing, isTrue);
    await handler.pause();
    expect(handler.playbackState.value.playing, isFalse);

    await handler.skipToNext();

    expect(handler.playbackState.value.playing, isTrue);
    await runtime.dispose();
  });

  test('natural completion resets playing state and timeline', () async {
    final provider = RuntimeSpeechProvider();
    final controller = AttachablePlaybackController();
    final handler = NovelAudioHandler(controller);
    final runtime = PlaybackRuntime(controller: controller, handler: handler);
    await runtime.replaceAndPlayFrom(
      createCoordinator(provider),
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
      token: runtime.beginReplacement(),
    );
    provider.publishTimeline(
      const PlaybackTimeline(
        position: Duration(seconds: 30),
        duration: Duration(seconds: 30),
      ),
    );

    provider.complete(provider.prepared.single.id);
    await pumpEventQueue();

    expect(handler.playbackState.value.playing, isFalse);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.idle,
    );
    expect(handler.currentTimeline, PlaybackTimeline.zero);
    await runtime.dispose();
  });

  test(
    'an internal speech segment change clears the previous timeline',
    () async {
      final provider = RuntimeSpeechProvider();
      final controller = AttachablePlaybackController();
      final handler = NovelAudioHandler(controller);
      final runtime = PlaybackRuntime(controller: controller, handler: handler);
      await runtime.replaceAndPlayFrom(
        createCoordinator(provider, paragraphs: LongParagraphSource()),
        const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
        token: runtime.beginReplacement(),
      );
      provider.publishTimeline(
        const PlaybackTimeline(
          position: Duration(seconds: 30),
          duration: Duration(seconds: 30),
        ),
      );

      provider.complete(provider.prepared.single.id);
      await pumpEventQueue();

      expect(provider.prepared, hasLength(2));
      expect(handler.currentTimeline, PlaybackTimeline.zero);
      await runtime.dispose();
    },
  );

  test('a sustained speech failure resets the playing state', () async {
    final provider = RuntimeSpeechProvider();
    final failures = <AppFailure>[];
    final controller = AttachablePlaybackController();
    final handler = NovelAudioHandler(controller);
    final runtime = PlaybackRuntime(controller: controller, handler: handler);
    await runtime.replaceAndPlayFrom(
      createCoordinator(provider, onFailure: failures.add),
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
      token: runtime.beginReplacement(),
    );
    provider.publishTimeline(
      const PlaybackTimeline(
        position: Duration(seconds: 5),
        duration: Duration(seconds: 30),
      ),
    );

    // Transient failures are retried; only once retries are exhausted does the
    // failure surface and reset the playing state. Fail the current segment
    // enough times to exceed the retry budget (initial + 2 retries).
    for (var attempt = 0; attempt < 3; attempt++) {
      provider.fail(provider.prepared.last.id);
      await pumpEventQueue();
    }

    expect(handler.playbackState.value.playing, isFalse);
    expect(handler.currentTimeline, PlaybackTimeline.zero);
    expect(failures, hasLength(1));
    await runtime.dispose();
  });

  test('records the activity transition that flips the playing state', () async {
    final provider = RuntimeSpeechProvider();
    final telemetry = _RecordingTelemetry();
    final controller = AttachablePlaybackController();
    final handler = NovelAudioHandler(controller);
    final runtime = PlaybackRuntime(
      controller: controller,
      handler: handler,
      telemetry: telemetry,
    );
    await runtime.replaceAndPlayFrom(
      createCoordinator(provider),
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
      token: runtime.beginReplacement(),
    );

    // Starting playback names the reason the playing flag went true...
    expect(telemetry.activityKinds, contains('playing'));

    // ...and an exhausted failure names why it goes back to false, which is the
    // signal the lock-screen diagnosis was blind to.
    for (var attempt = 0; attempt < 3; attempt++) {
      provider.fail(provider.prepared.last.id);
      await pumpEventQueue();
    }

    expect(telemetry.activityKinds, contains('failed'));
    expect(handler.playbackState.value.playing, isFalse);
    await runtime.dispose();
  });

  test('a stale completion cannot mark newer playback idle', () async {
    final provider = RuntimeSpeechProvider();
    final paragraphs = DelayedCompletionParagraphSource();
    final controller = AttachablePlaybackController();
    final handler = NovelAudioHandler(controller);
    final runtime = PlaybackRuntime(controller: controller, handler: handler);
    await runtime.replaceAndPlayFrom(
      createCoordinator(provider, paragraphs: paragraphs),
      const PlaybackCursor(chapterId: 1, paragraphIndex: 1),
      token: runtime.beginReplacement(),
    );

    provider.complete(provider.prepared.single.id);
    await paragraphs.nextRequested.future;
    await handler.skipToPrevious();
    paragraphs.nextResult.complete(null);
    await pumpEventQueue();

    expect(controller.cursor?.paragraphIndex, 0);
    expect(handler.playbackState.value.playing, isTrue);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.ready,
    );
    await runtime.dispose();
  });

  test(
    'runtime retains cursor on pause and clears it on stop or dispose',
    () async {
      final controller = AttachablePlaybackController();
      final handler = NovelAudioHandler(controller);
      final runtime = PlaybackRuntime(controller: controller, handler: handler);
      final cursors = <PlaybackCursor?>[];
      final subscription = runtime.cursorChanges.listen(cursors.add);
      const firstCursor = PlaybackCursor(chapterId: 1, paragraphIndex: 0);
      const secondCursor = PlaybackCursor(chapterId: 2, paragraphIndex: 3);

      await runtime.replaceAndPlayFrom(
        createCoordinator(RuntimeSpeechProvider()),
        firstCursor,
        token: runtime.beginReplacement(),
      );
      await handler.pause();
      expect(cursors, const [firstCursor]);
      await handler.stop();
      expect(cursors, const [firstCursor, null]);
      await handler.play();
      await runtime.replaceAndPlayFrom(
        createCoordinator(RuntimeSpeechProvider()),
        secondCursor,
        token: runtime.beginReplacement(),
      );
      await runtime.dispose();

      expect(cursors, const [
        firstCursor,
        null,
        firstCursor,
        secondCursor,
        null,
      ]);
      await subscription.cancel();
    },
  );

  test('serializes a speed change with coordinator attachment', () async {
    final firstProvider = RuntimeSpeechProvider();
    final restoreCompleter = Completer<void>();
    final replacementProvider = RuntimeSpeechProvider(
      speedCompleter: restoreCompleter,
    );
    final controller = AttachablePlaybackController();
    final handler = NovelAudioHandler(controller);
    final runtime = PlaybackRuntime(controller: controller, handler: handler);
    await runtime.replace(createCoordinator(firstProvider));
    await handler.setSpeed(1.5);

    final replacement = runtime.replace(createCoordinator(replacementProvider));
    await pumpEventQueue();
    expect(replacementProvider.speedChanges, [1.5]);

    var speedChangeCompleted = false;
    final speedChange = handler.setSpeed(1.25).then((_) {
      speedChangeCompleted = true;
    });
    await pumpEventQueue();

    expect(speedChangeCompleted, isFalse);
    restoreCompleter.complete();
    await replacement;
    await speedChange;

    expect(replacementProvider.speedChanges, [1.5, 1.25]);
    expect(handler.playbackState.value.speed, 1.25);
    await runtime.dispose();
  });

  test(
    'disposes a replacement when speed restoration fails and keeps the old delegate',
    () async {
      final firstProvider = RuntimeSpeechProvider();
      final failedProvider = RuntimeSpeechProvider(
        speedError: StateError('restore failed'),
      );
      final controller = AttachablePlaybackController();
      final handler = NovelAudioHandler(controller);
      final runtime = PlaybackRuntime(controller: controller, handler: handler);
      await runtime.replace(createCoordinator(firstProvider));

      await expectLater(
        runtime.replace(createCoordinator(failedProvider)),
        throwsStateError,
      );

      expect(failedProvider.disposeCalls, 1);
      await handler.setSpeed(1.25);
      expect(firstProvider.speedChanges.last, 1.25);
      expect(handler.playbackState.value.speed, 1.25);
      await runtime.dispose();
    },
  );

  test('runtime keeps the new delegate when previous disposal fails', () async {
    final errors = <Object>[];
    final firstProvider = RuntimeSpeechProvider(
      disposeError: StateError('dispose failed'),
    );
    final secondProvider = RuntimeSpeechProvider();
    final controller = AttachablePlaybackController();
    final runtime = PlaybackRuntime(
      controller: controller,
      handler: NovelAudioHandler(controller),
      onCoordinatorDisposeError: (error, _) => errors.add(error),
    );
    await runtime.replace(createCoordinator(firstProvider));

    await runtime.replace(createCoordinator(secondProvider));
    await controller.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );

    expect(errors, hasLength(1));
    expect(secondProvider.prepared, hasLength(1));
    await runtime.dispose();
  });

  test(
    'a replaced coordinator cannot publish a late playback cursor',
    () async {
      final latePlay = Completer<void>();
      final firstProvider = RuntimeSpeechProvider(playCompleter: latePlay);
      final secondProvider = RuntimeSpeechProvider();
      final first = createCoordinator(firstProvider);
      final second = createCoordinator(secondProvider);
      final controller = AttachablePlaybackController();
      final runtime = PlaybackRuntime(
        controller: controller,
        handler: NovelAudioHandler(controller),
      );
      final cursors = <PlaybackCursor?>[];
      final subscription = runtime.cursorChanges.listen(cursors.add);
      const oldCursor = PlaybackCursor(chapterId: 1, paragraphIndex: 0);
      const currentCursor = PlaybackCursor(chapterId: 2, paragraphIndex: 0);
      await runtime.replace(first);
      final oldStart = first.playFrom(oldCursor);
      await pumpEventQueue();

      await runtime.replace(second);
      await second.playFrom(currentCursor);
      latePlay.complete();
      await oldStart;

      expect(cursors, const [currentCursor]);
      await runtime.dispose();
      await subscription.cancel();
    },
  );

  test(
    'runtime disposes previous playback before starting its replacement',
    () async {
      final firstProvider = RuntimeSpeechProvider(
        disposeCompleter: Completer<void>(),
      );
      final secondProvider = RuntimeSpeechProvider();
      final controller = AttachablePlaybackController();
      final runtime = PlaybackRuntime(
        controller: controller,
        handler: NovelAudioHandler(controller),
      );
      const cursor = PlaybackCursor(chapterId: 1, paragraphIndex: 0);
      await runtime.replaceAndPlayFrom(
        createCoordinator(firstProvider),
        cursor,
        token: runtime.beginReplacement(),
      );

      final replacement = runtime.replaceAndPlayFrom(
        createCoordinator(secondProvider),
        cursor,
        token: runtime.beginReplacement(),
      );
      await pumpEventQueue();

      expect(firstProvider.disposeCalls, 1);
      expect(secondProvider.prepared, isEmpty);

      firstProvider.disposeCompleter!.complete();
      await replacement;

      expect(secondProvider.prepared, hasLength(1));
      await runtime.dispose();
    },
  );

  test('failed playback startup does not block a later replacement', () async {
    final firstProvider = RuntimeSpeechProvider();
    final failedProvider = RuntimeSpeechProvider(
      prepareError: StateError('prepare failed'),
    );
    final nextProvider = RuntimeSpeechProvider();
    final controller = AttachablePlaybackController();
    final runtime = PlaybackRuntime(
      controller: controller,
      handler: NovelAudioHandler(controller),
    );
    const cursor = PlaybackCursor(chapterId: 1, paragraphIndex: 0);
    await runtime.replaceAndPlayFrom(
      createCoordinator(firstProvider),
      cursor,
      token: runtime.beginReplacement(),
    );
    runtime.handler.markPlaying();

    expect(runtime.handler.playbackState.value.playing, isTrue);

    await expectLater(
      runtime.replaceAndPlayFrom(
        createCoordinator(failedProvider),
        cursor,
        token: runtime.beginReplacement(),
      ),
      throwsStateError,
    );

    expect(failedProvider.disposeCalls, 1);
    expect(runtime.handler.playbackState.value.playing, isFalse);
    expect(
      runtime.handler.playbackState.value.processingState,
      AudioProcessingState.idle,
    );

    await runtime.replaceAndPlayFrom(
      createCoordinator(nextProvider),
      cursor,
      token: runtime.beginReplacement(),
    );

    expect(nextProvider.prepared, hasLength(1));
    await runtime.dispose();
  });

  test('stale current replacement resets the playback state', () async {
    final firstProvider = RuntimeSpeechProvider(
      disposeCompleter: Completer<void>(),
    );
    final staleProvider = RuntimeSpeechProvider();
    final controller = AttachablePlaybackController();
    final runtime = PlaybackRuntime(
      controller: controller,
      handler: NovelAudioHandler(controller),
    );
    const cursor = PlaybackCursor(chapterId: 1, paragraphIndex: 0);
    await runtime.replaceAndPlayFrom(
      createCoordinator(firstProvider),
      cursor,
      token: runtime.beginReplacement(),
    );
    runtime.handler.markPlaying();
    final staleToken = runtime.beginReplacement();

    final replacement = runtime.replaceAndPlayFrom(
      createCoordinator(staleProvider),
      cursor,
      token: staleToken,
    );
    await pumpEventQueue();
    runtime.cancelReplacement(staleToken);
    firstProvider.disposeCompleter!.complete();

    expect(await replacement, isFalse);
    expect(staleProvider.disposeCalls, 1);
    expect(runtime.handler.playbackState.value.playing, isFalse);
    expect(
      runtime.handler.playbackState.value.processingState,
      AudioProcessingState.idle,
    );
    await runtime.dispose();
  });

  test('disposing the runtime resets the playback state', () async {
    final provider = RuntimeSpeechProvider();
    final controller = AttachablePlaybackController();
    final runtime = PlaybackRuntime(
      controller: controller,
      handler: NovelAudioHandler(controller),
    );
    const cursor = PlaybackCursor(chapterId: 1, paragraphIndex: 0);
    await runtime.replaceAndPlayFrom(
      createCoordinator(provider),
      cursor,
      token: runtime.beginReplacement(),
    );
    runtime.handler.markPlaying();

    await runtime.dispose();

    expect(runtime.handler.playbackState.value.playing, isFalse);
    expect(
      runtime.handler.playbackState.value.processingState,
      AudioProcessingState.idle,
    );
  });

  test('a stale startup cannot replace the latest playback request', () async {
    final staleProvider = RuntimeSpeechProvider();
    final latestProvider = RuntimeSpeechProvider();
    final controller = AttachablePlaybackController();
    final runtime = PlaybackRuntime(
      controller: controller,
      handler: NovelAudioHandler(controller),
    );
    const cursor = PlaybackCursor(chapterId: 1, paragraphIndex: 0);
    final staleToken = runtime.beginReplacement();
    final latestToken = runtime.beginReplacement();

    final latestStarted = await runtime.replaceAndPlayFrom(
      createCoordinator(latestProvider),
      cursor,
      token: latestToken,
    );
    runtime.handler.markPlaying();
    final staleStarted = await runtime.replaceAndPlayFrom(
      createCoordinator(staleProvider),
      cursor,
      token: staleToken,
    );

    expect(latestStarted, isTrue);
    expect(staleStarted, isFalse);
    expect(staleProvider.disposeCalls, 1);
    expect(staleProvider.prepared, isEmpty);
    await controller.playFrom(cursor);
    expect(latestProvider.prepared, hasLength(2));
    expect(runtime.handler.playbackState.value.playing, isTrue);
    expect(
      runtime.handler.playbackState.value.processingState,
      AudioProcessingState.ready,
    );
    await runtime.dispose();
  });
}

PlaybackCoordinator createCoordinator(
  RuntimeSpeechProvider provider, {
  PlaybackParagraphSource? paragraphs,
  void Function(AppFailure failure)? onFailure,
}) {
  return PlaybackCoordinator(
    provider: provider,
    progress: RuntimeProgressRepository(),
    paragraphs: paragraphs ?? RuntimeParagraphSource(),
    voiceProfile: testVoiceProfile(),
    onFailure: onFailure,
    retryDelay: (_) async {},
  );
}

final class _RecordingTelemetry implements PlaybackTelemetry {
  final List<String> activityKinds = [];

  @override
  void record(String name, [Map<String, Object?> fields = const {}]) {
    if (name == 'playback.activity') {
      activityKinds.add(fields['kind'] as String);
    }
  }

  @override
  Future<void> flush() async {}
}

final class DelayedCompletionParagraphSource
    implements PlaybackParagraphSource {
  final nextRequested = Completer<void>();
  final nextResult = Completer<PlaybackParagraph?>();

  @override
  Future<PlaybackParagraph?> at(PlaybackCursor cursor) async =>
      PlaybackParagraph(
        id: cursor.paragraphIndex + 1,
        cursor: cursor,
        text: '正文',
      );

  @override
  Future<PlaybackParagraph?> nextAfter(PlaybackCursor cursor) {
    if (!nextRequested.isCompleted) nextRequested.complete();
    return nextResult.future;
  }
}

final class TwoParagraphSource implements PlaybackParagraphSource {
  @override
  Future<PlaybackParagraph?> at(PlaybackCursor cursor) async =>
      PlaybackParagraph(
        id: cursor.paragraphIndex + 1,
        cursor: cursor,
        text: '正文',
      );

  @override
  Future<PlaybackParagraph?> nextAfter(PlaybackCursor cursor) async {
    if (cursor.paragraphIndex >= 1) return null;
    final next = PlaybackCursor(
      chapterId: cursor.chapterId,
      paragraphIndex: cursor.paragraphIndex + 1,
    );
    return at(next);
  }
}

final class LongParagraphSource implements PlaybackParagraphSource {
  @override
  Future<PlaybackParagraph?> at(PlaybackCursor cursor) async =>
      PlaybackParagraph(
        id: 1,
        cursor: cursor,
        text: List.filled(1200, '字').join(),
      );

  @override
  Future<PlaybackParagraph?> nextAfter(PlaybackCursor cursor) async => null;
}

final class FakePlaybackController implements PlaybackController {
  FakePlaybackController(this._cursor);

  PlaybackCursor? _cursor;
  int resumeCalls = 0;
  int pauseCalls = 0;
  int nextCalls = 0;
  int previousCalls = 0;
  final List<double> speedChanges = [];

  @override
  PlaybackCursor? get cursor => _cursor;

  @override
  Future<void> nextParagraph() async {
    nextCalls++;
    final value = _cursor;
    if (value != null) {
      _cursor = PlaybackCursor(
        chapterId: value.chapterId,
        paragraphIndex: value.paragraphIndex + 1,
      );
    }
  }

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> playFrom(PlaybackCursor cursor) async => _cursor = cursor;

  @override
  Future<void> previousParagraph() async {
    previousCalls++;
    final value = _cursor;
    if (value != null) {
      _cursor = PlaybackCursor(
        chapterId: value.chapterId,
        paragraphIndex: value.paragraphIndex - 1,
      );
    }
  }

  @override
  Future<void> resume() async => resumeCalls++;

  @override
  Future<void> setSpeed(double speed) async => speedChanges.add(speed);
}

final class RuntimeParagraphSource implements PlaybackParagraphSource {
  @override
  Future<PlaybackParagraph?> at(PlaybackCursor cursor) async {
    return PlaybackParagraph(id: 1, cursor: cursor, text: '第一段');
  }

  @override
  Future<PlaybackParagraph?> nextAfter(PlaybackCursor cursor) async => null;
}

final class RuntimeProgressRepository implements PlaybackProgressRepository {
  @override
  Future<void> confirm(PlaybackCursor cursor) async {}
}

final class RuntimeSpeechProvider
    implements
        SpeechProvider,
        DisposableSpeechProvider,
        AdjustableSpeechProvider,
        TimedSpeechProvider {
  RuntimeSpeechProvider({
    this.disposeCompleter,
    this.disposeError,
    this.prepareError,
    this.playCompleter,
    this.speedCompleter,
    this.speedError,
  });

  final StreamController<SpeechEvent> _events =
      StreamController<SpeechEvent>.broadcast();
  final StreamController<PlaybackTimeline> _timeline =
      StreamController<PlaybackTimeline>.broadcast(sync: true);
  final Completer<void>? disposeCompleter;
  final Object? disposeError;
  final Object? prepareError;
  final Completer<void>? playCompleter;
  final Completer<void>? speedCompleter;
  final Object? speedError;
  final List<SpeechSegment> prepared = [];
  final List<double> speedChanges = [];
  int disposeCalls = 0;

  @override
  Stream<SpeechEvent> get events => _events.stream;

  @override
  Stream<PlaybackTimeline> get playbackTimeline => _timeline.stream;

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await disposeCompleter?.future;
    final error = disposeError;
    if (error != null) {
      throw error;
    }
    await _events.close();
    await _timeline.close();
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async => playCompleter?.future;

  @override
  Future<void> prepare(SpeechSegment segment, VoiceProfile profile) async {
    final error = prepareError;
    if (error != null) {
      throw error;
    }
    prepared.add(segment);
  }

  @override
  Future<void> resume() async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    speedChanges.add(speed);
    await speedCompleter?.future;
    final error = speedError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> stop() async {}

  void publishTimeline(PlaybackTimeline timeline) => _timeline.add(timeline);

  void complete(String segmentId) =>
      _events.add(SpeechCompleted(segmentId: segmentId));

  void fail(String segmentId) => _events.add(
    SpeechFailed(segmentId: segmentId, failure: const AppFailure('播放失败')),
  );
}
