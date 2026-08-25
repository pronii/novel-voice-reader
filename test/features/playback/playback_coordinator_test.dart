import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/features/diagnostics/domain/playback_telemetry.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_coordinator.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_timeline.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

import '../../support/test_voice_profile.dart';

void main() {
  test('records audio prepare-to-play duration without sensitive fields', () async {
    final telemetry = _RecordingTelemetry();
    final coordinator = PlaybackCoordinator(
      provider: FakeSpeechProvider(),
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource(const ['第一段']),
      voiceProfile: testVoiceProfile(),
      telemetry: telemetry,
    );

    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );

    final duration = telemetry.events.singleWhere(
      (event) => event.$1 == 'playback.audio.prepare_to_play',
    );
    expect(duration.$2.keys, unorderedEquals(['elapsed_ms']));
    expect(duration.$2['elapsed_ms'], isA<int>());
    await coordinator.dispose();
  });

  test('telemetry failures do not affect prepare or playback', () async {
    final coordinator = PlaybackCoordinator(
      provider: FakeSpeechProvider(),
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource(const ['第一段']),
      voiceProfile: testVoiceProfile(),
      telemetry: _ThrowingTelemetry(),
    );

    await expectLater(
      coordinator.playFrom(
        const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
      ),
      completes,
    );
    await coordinator.dispose();
  });

  test('publishes the cursor when each paragraph starts playing', () async {
    final provider = FakeSpeechProvider();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource(const ['第一段', '第二段']),
      voiceProfile: testVoiceProfile(),
    );
    final cursors = <PlaybackCursor>[];
    final subscription = coordinator.cursorChanges.listen(cursors.add);

    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    provider.completeCurrent();
    await pumpEventQueue();

    expect(cursors, const [
      PlaybackCursor(chapterId: 1, paragraphIndex: 0),
      PlaybackCursor(chapterId: 1, paragraphIndex: 1),
    ]);
    await subscription.cancel();
    await coordinator.dispose();
  });

  test('advances and confirms progress after paragraph completion', () async {
    final provider = FakeSpeechProvider();
    final progress = FakeProgressRepository();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: progress,
      paragraphs: FakeParagraphSource(const ['第一段', '第二段']),
      voiceProfile: testVoiceProfile(),
    );

    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    provider.completeCurrent();
    await pumpEventQueue();

    expect(provider.prepared.last.text, '第二段');
    expect(
      progress.confirmed,
      const PlaybackCursor(chapterId: 1, paragraphIndex: 1),
    );
    await coordinator.dispose();
  });

  test(
    'retries the current segment when a completion never arrives, then advances',
    () async {
      final provider = FakeSpeechProvider();
      final progress = FakeProgressRepository();
      final callbacks = <void Function()>[];
      final coordinator = PlaybackCoordinator(
        provider: provider,
        progress: progress,
        paragraphs: FakeParagraphSource(const ['第一段', '第二段']),
        voiceProfile: testVoiceProfile(),
        maxSegmentRetries: 1,
        scheduleWatchdog: (duration, onTimeout) {
          callbacks.add(onTimeout);
          return Timer(const Duration(days: 1), () {});
        },
      );

      await coordinator.playFrom(
        const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
      );
      expect(provider.prepared.map((segment) => segment.text), ['第一段']);

      // The completion callback never arrives: the watchdog fires and recovers
      // the remote-audio segment instead of stalling forever.
      callbacks.last();
      await pumpEventQueue();
      expect(provider.prepared.map((segment) => segment.text), [
        '第一段',
        '第一段',
      ]);
      expect(
        coordinator.cursor,
        const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
      );

      // Still no completion: retries are exhausted, so playback advances to the
      // next paragraph rather than freezing.
      callbacks.last();
      await pumpEventQueue();
      expect(provider.prepared.last.text, '第二段');
      expect(
        progress.confirmed,
        const PlaybackCursor(chapterId: 1, paragraphIndex: 1),
      );
      await coordinator.dispose();
    },
  );

  test('watchdog does not replay cloud audio that is still active', () async {
    final provider = FakeSpeechProvider()
      ..playbackStatus = SpeechPlaybackStatus.active;
    final callbacks = <void Function()>[];
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource(const ['第一段', '第二段']),
      voiceProfile: VoiceProfile.mimo(),
      scheduleWatchdog: (duration, onTimeout) {
        callbacks.add(onTimeout);
        return Timer(const Duration(days: 1), () {});
      },
    );

    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    callbacks.last();
    await pumpEventQueue();

    expect(provider.prepared.map((segment) => segment.text), ['第一段']);
    expect(callbacks, hasLength(2));
    await coordinator.dispose();
  });

  test('watchdog advances completed cloud audio without replaying it', () async {
    final provider = FakeSpeechProvider()
      ..playbackStatus = SpeechPlaybackStatus.completed;
    final progress = FakeProgressRepository();
    final callbacks = <void Function()>[];
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: progress,
      paragraphs: FakeParagraphSource(const ['第一段', '第二段']),
      voiceProfile: VoiceProfile.mimo(),
      scheduleWatchdog: (duration, onTimeout) {
        callbacks.add(onTimeout);
        return Timer(const Duration(days: 1), () {});
      },
    );

    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    callbacks.last();
    await pumpEventQueue();

    expect(provider.prepared.map((segment) => segment.text), ['第一段', '第二段']);
    expect(
      progress.confirmed,
      const PlaybackCursor(chapterId: 1, paragraphIndex: 1),
    );
    await coordinator.dispose();
  });

  test('prefetches the next paragraph while the current one plays', () async {
    final provider = FakeSpeechProvider();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource(const ['第一段', '第二段']),
      voiceProfile: testVoiceProfile(),
    );

    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    await pumpEventQueue();

    expect(provider.prefetched.map((segment) => segment.text), ['第二段']);
    expect(provider.prepared.map((segment) => segment.text), ['第一段']);
    await coordinator.dispose();
  });

  test('locking reschedules look-ahead synthesis while audio is active', () async {
    final provider = FakeSpeechProvider();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource(const ['第一段', '第二段']),
      voiceProfile: VoiceProfile.mimo(),
    );

    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    await pumpEventQueue();
    provider.prefetched.clear();

    coordinator.setForeground(false);
    await pumpEventQueue();

    expect(provider.prefetched.map((segment) => segment.text), ['第二段']);
    await coordinator.dispose();
  });

  test('serializes provider takeover and only plays the newest request', () async {
    final provider = ControllablePrepareSpeechProvider();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource(const ['第一段', '第二段']),
      voiceProfile: testVoiceProfile(),
    );

    final first = coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    await provider.waitForPrepares(1);
    final second = coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 1),
    );
    await pumpEventQueue();

    expect(provider.prepared.map((segment) => segment.text), ['第一段']);
    expect(provider.maxActivePrepares, 1);

    provider.completePrepare(0);
    await provider.waitForPrepares(2);
    expect(provider.played, isEmpty);

    provider.completePrepare(1);
    await second;
    await first;

    expect(provider.maxActivePrepares, 1);
    expect(provider.played.map((segment) => segment.text), ['第二段']);
    expect(provider.currentSegment?.text, '第二段');
    expect(
      coordinator.cursor,
      const PlaybackCursor(chapterId: 1, paragraphIndex: 1),
    );
    await coordinator.dispose();
  });

  test('prefetches about three minutes across paragraph boundaries', () async {
    final provider = FakeSpeechProvider();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource([
        '当前段',
        List.filled(360, '甲').join(),
        List.filled(360, '乙').join(),
        List.filled(360, '丙').join(),
      ]),
      voiceProfile: VoiceProfile.mimo(),
    );

    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    await pumpEventQueue();

    expect(provider.prefetched.map((segment) => segment.text.runes.length), [
      360,
      360,
      360,
    ]);
    await coordinator.dispose();
  });

  test('prefetches at least three minutes of upcoming audio', () async {
    final provider = FakeSpeechProvider();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource([
        '当前段',
        for (var i = 0; i < 8; i++) List.filled(360, '甲').join(),
      ]),
      voiceProfile: VoiceProfile.mimo(),
    );

    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    await pumpEventQueue();

    // The target is expressed as wall-clock time, not the old 750-character
    // cap: at ~0.24s/char the prefetched runway must cover at least three
    // minutes, which is more characters than the retired 750 limit allowed.
    final prefetchedCharacters = provider.prefetched.fold<int>(
      0,
      (total, segment) => total + segment.text.runes.length,
    );
    const microsPerCharacter = 240000;
    final prefetchedDuration = Duration(
      microseconds: prefetchedCharacters * microsPerCharacter,
    );
    expect(
      prefetchedDuration,
      greaterThanOrEqualTo(const Duration(minutes: 3)),
    );
    expect(prefetchedCharacters, greaterThan(750));
    await coordinator.dispose();
  });

  test(
    'advances through the native queue without re-preparing while locked',
    () async {
      final provider = PlaylistCacheSpeechProvider();
      final coordinator = PlaybackCoordinator(
        provider: provider,
        progress: FakeProgressRepository(),
        paragraphs: FakeParagraphSource([List.filled(720, '文').join()]),
        voiceProfile: VoiceProfile.mimo(),
      );

      await coordinator.playFrom(
        const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
      );
      await pumpEventQueue();

      // The paragraph split into two 360-char segments; the second is prefetched
      // into the native look-ahead queue.
      expect(provider.prepared.map((segment) => segment.id), ['1:0']);
      expect(provider.queue, ['1:1']);

      coordinator.setForeground(false);
      final preparesBefore = provider.prepared.length;

      // just_audio finishes segment 1:0 and advances into 1:1 by itself. The
      // coordinator must NOT prepare()/prepareCached() again — the audio is
      // already playing from the native queue.
      provider.advanceNative();
      await pumpEventQueue();

      expect(provider.prepared.length, preparesBefore);
      expect(provider.cacheChecked, isEmpty);
      expect(provider.currentSegmentId, '1:1');
      await coordinator.dispose();
    },
  );

  test(
    'locked cache miss at a paragraph boundary falls back to synthesis',
    () async {
      final provider = PlaylistCacheSpeechProvider()..prefetchCaches = false;
      final progress = FakeProgressRepository();
      final failures = <AppFailure>[];
      final coordinator = PlaybackCoordinator(
        provider: provider,
        progress: progress,
        paragraphs: FakeParagraphSource(const ['甲', '乙']),
        voiceProfile: VoiceProfile.mimo(),
        onFailure: failures.add,
        retryDelay: (_) async {},
      );
      final activities = <PlaybackActivity>[];
      final subscription = coordinator.activityChanges.listen(activities.add);

      await coordinator.playFrom(
        const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
      );
      await pumpEventQueue();

      coordinator.setForeground(false);
      // The current segment finishes but the next paragraph was never cached.
      provider.completeCurrent();
      await pumpEventQueue();

      expect(provider.prepared.map((segment) => segment.id), ['1:0', '2:0']);
      expect(provider.cacheChecked.map((segment) => segment.id), ['2:0']);
      expect(failures, isEmpty);
      expect(activities.last, PlaybackActivity.playing);
      expect(
        progress.confirmed,
        const PlaybackCursor(chapterId: 1, paragraphIndex: 1),
      );
      await subscription.cancel();
      await coordinator.dispose();
    },
  );

  test(
    'locked cache miss mid-paragraph falls back to synthesis',
    () async {
      final provider = PlaylistCacheSpeechProvider()..prefetchCaches = false;
      final failures = <AppFailure>[];
      final coordinator = PlaybackCoordinator(
        provider: provider,
        progress: FakeProgressRepository(),
        paragraphs: FakeParagraphSource([List.filled(720, '文').join()]),
        voiceProfile: VoiceProfile.mimo(),
        onFailure: failures.add,
        retryDelay: (_) async {},
      );
      final activities = <PlaybackActivity>[];
      final subscription = coordinator.activityChanges.listen(activities.add);

      await coordinator.playFrom(
        const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
      );
      await pumpEventQueue();
      expect(provider.prepared.map((segment) => segment.id), ['1:0']);

      coordinator.setForeground(false);
      provider.completeCurrent();
      await pumpEventQueue();

      expect(provider.prepared.map((segment) => segment.id), ['1:0', '1:1']);
      expect(provider.cacheChecked.map((segment) => segment.id), ['1:1']);
      expect(failures, isEmpty);
      expect(activities.last, PlaybackActivity.playing);
      await subscription.cancel();
      await coordinator.dispose();
    },
  );

  test('a continuation cannot borrow a newer request generation', () async {
    final provider = ControllablePrepareSpeechProvider();
    final paragraphs = ControllableTakeoverChapterSource(
      activeText: List.filled(361, '旧').join(),
    );
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: paragraphs,
      voiceProfile: VoiceProfile.mimo(),
    );
    const activeCursor = PlaybackCursor(chapterId: 1, paragraphIndex: 0);
    const takeoverCursor = PlaybackCursor(chapterId: 2, paragraphIndex: 0);

    final activeStart = coordinator.playFrom(activeCursor);
    await provider.waitForPrepares(1);
    provider.completePrepare(0);
    await activeStart;

    final takeover = coordinator.playFrom(takeoverCursor);
    await paragraphs.waitForTakeoverCount();
    provider.completeCurrent();
    await provider.waitForPrepares(2);

    paragraphs.completeTakeoverCount();
    await pumpEventQueue();
    provider.completePrepare(1);
    await provider.waitForPrepares(3);
    provider.completePrepare(2);
    await takeover;
    await pumpEventQueue();

    expect(provider.maxActivePrepares, 1);
    expect(
      provider.prepared.where((segment) => segment.text == '新段落'),
      hasLength(1),
    );
    expect(
      provider.played.map((segment) => segment.text),
      [List.filled(360, '旧').join(), '新段落'],
    );
    expect(provider.currentSegment?.text, '新段落');
    expect(coordinator.cursor, takeoverCursor);
    await coordinator.dispose();
  });

  test('serializes prefetches across rapid playback changes', () async {
    final provider = FakeSpeechProvider()..prefetchBlock = Completer<void>();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource(const ['第一段', '第二段', '第三段']),
      voiceProfile: testVoiceProfile(),
    );

    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    await provider.waitForActivePrefetches(1);
    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 1),
    );
    await pumpEventQueue();

    expect(provider.maxActivePrefetches, 1);
    provider.prefetchBlock!.complete();
    await provider.waitForActivePrefetches(0);
    await coordinator.dispose();
  });

  test('dispose waits for the active prefetch', () async {
    final provider = FakeSpeechProvider()..prefetchBlock = Completer<void>();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource(const ['第一段', '第二段']),
      voiceProfile: testVoiceProfile(),
    );
    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    await provider.waitForActivePrefetches(1);
    var disposed = false;

    final disposal = coordinator.dispose().then((_) => disposed = true);
    await pumpEventQueue();

    expect(disposed, isFalse);
    provider.prefetchBlock!.complete();
    await disposal;
    expect(disposed, isTrue);
  });

  test(
    'retries a transient prefetch failure without surfacing a banner',
    () async {
      final provider = FakeSpeechProvider()..prefetchFailuresRemaining = 2;
      final failures = <AppFailure>[];
      final coordinator = PlaybackCoordinator(
        provider: provider,
        progress: FakeProgressRepository(),
        paragraphs: FakeParagraphSource(const ['第一段', '第二段']),
        voiceProfile: testVoiceProfile(),
        onFailure: failures.add,
        retryDelay: (_) async {},
      );

      await coordinator.playFrom(
        const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
      );
      // The prefetch throws twice (a transient locked-screen network blip) and
      // is retried with backoff until it warms the next segment's cache. The
      // failure must never reach _onFailure — prefetch is best-effort work.
      await pumpEventQueue();

      expect(provider.prefetched.map((segment) => segment.text), ['第二段']);
      expect(provider.prefetchFailuresRemaining, 0);
      expect(failures, isEmpty);
      await coordinator.dispose();
    },
  );

  test(
    'retries the same segment after a transient prepare failure, no banner',
    () async {
      final provider = FakeSpeechProvider();
      final failures = <AppFailure>[];
      final coordinator = PlaybackCoordinator(
        provider: provider,
        progress: FakeProgressRepository(),
        paragraphs: FakeParagraphSource(const ['第一段', '第二段']),
        voiceProfile: testVoiceProfile(),
        onFailure: failures.add,
        maxSegmentRetries: 2,
        retryDelay: (_) async {},
      );

      await coordinator.playFrom(
        const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
      );
      expect(provider.prepared.map((segment) => segment.text), ['第一段']);

      // A transient synth/session blip fails the current segment. With backoff,
      // the coordinator replays the SAME segment instead of stopping dead.
      provider.failCurrent();
      await pumpEventQueue();

      expect(provider.prepared.map((segment) => segment.text), [
        '第一段',
        '第一段',
      ]);
      expect(
        coordinator.cursor,
        const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
      );
      expect(failures, isEmpty);

      // The retry now plays through: completion advances to the next paragraph.
      provider.completeCurrent();
      await pumpEventQueue();
      expect(provider.prepared.last.text, '第二段');
      await coordinator.dispose();
    },
  );

  test(
    'surfaces the banner only after prepare retries are exhausted',
    () async {
      final provider = FakeSpeechProvider();
      final failures = <AppFailure>[];
      final coordinator = PlaybackCoordinator(
        provider: provider,
        progress: FakeProgressRepository(),
        paragraphs: FakeParagraphSource(const ['第一段', '第二段']),
        voiceProfile: testVoiceProfile(),
        onFailure: failures.add,
        maxSegmentRetries: 1,
        retryDelay: (_) async {},
      );

      await coordinator.playFrom(
        const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
      );

      // First failure retries the segment (no banner yet).
      provider.failCurrent();
      await pumpEventQueue();
      expect(failures, isEmpty);

      // Second failure exhausts the single retry and finally surfaces the
      // banner via _onFailure.
      provider.failCurrent();
      await pumpEventQueue();
      expect(failures.single.message, '云端语音播放准备失败');
      await coordinator.dispose();
    },
  );

  test('pause persists the current cursor and delegates to provider', () async {
    final provider = FakeSpeechProvider();
    final progress = FakeProgressRepository();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: progress,
      paragraphs: FakeParagraphSource(const ['第一段']),
      voiceProfile: testVoiceProfile(),
    );
    const cursor = PlaybackCursor(chapterId: 1, paragraphIndex: 0);
    await coordinator.playFrom(cursor);

    await coordinator.pause();

    expect(provider.pauseCalls, 1);
    expect(progress.confirmed, cursor);
    await coordinator.dispose();
  });

  test('forwards playback speed to an adjustable provider', () async {
    final provider = FakeSpeechProvider();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource(const ['第一段']),
      voiceProfile: testVoiceProfile(),
    );

    await coordinator.setSpeed(1.25);

    expect(provider.speedChanges, [1.25]);
    await coordinator.dispose();
  });

  test('does not retain a playback speed rejected by the provider', () async {
    final provider = FakeSpeechProvider()..speedFailure = StateError('failed');
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource(const ['第一段']),
      voiceProfile: testVoiceProfile(),
    );

    await expectLater(coordinator.setSpeed(1.25), throwsStateError);
    provider.speedFailure = null;
    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );

    expect(provider.speedChanges, [1.25, 1]);
    await coordinator.dispose();
  });

  test('reapplies playback speed after every segment prepare', () async {
    final provider = FakeSpeechProvider();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource([List.filled(361, '文').join()]),
      voiceProfile: VoiceProfile.mimo(),
    );
    await coordinator.setSpeed(1.25);

    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    provider.completeCurrent();
    await pumpEventQueue();

    expect(provider.speedChanges, [1.25, 1.25, 1.25]);
    await coordinator.dispose();
  });

  test('splits MiMo playback into at most 360 characters', () async {
    final provider = FakeSpeechProvider();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource([List.filled(361, '文').join()]),
      voiceProfile: VoiceProfile.mimo(),
    );

    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    expect(provider.prepared.single.text.runes.length, 360);

    provider.completeCurrent();
    await pumpEventQueue();
    expect(provider.prepared.last.text.runes.length, 1);
    await coordinator.dispose();
  });

  test('estimates chapter remaining time from the timed current segment', () async {
    final provider = FakeSpeechProvider();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: ChapterAwareParagraphSource([
        List.filled(10, '当').join(),
        List.filled(5, '后').join(),
      ]),
      voiceProfile: testVoiceProfile(),
    );
    final timelines = <PlaybackTimeline>[];
    final subscription = coordinator.timelineChanges.listen(timelines.add);

    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    provider.publishTimeline(
      const PlaybackTimeline(
        position: Duration.zero,
        duration: Duration(seconds: 20),
      ),
    );

    expect(timelines.last.chapterElapsed, Duration.zero);
    expect(timelines.last.chapterRemaining, const Duration(seconds: 30));
    await subscription.cancel();
    await coordinator.dispose();
  });

  test('estimates chapter elapsed time from the current segment position', () async {
    final provider = FakeSpeechProvider();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: ChapterAwareParagraphSource([
        List.filled(10, '当').join(),
        List.filled(5, '后').join(),
      ]),
      voiceProfile: testVoiceProfile(),
    );
    final timelines = <PlaybackTimeline>[];
    final subscription = coordinator.timelineChanges.listen(timelines.add);

    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    // 10-char segment over 20s => 2s/char. Halfway through the segment.
    provider.publishTimeline(
      const PlaybackTimeline(
        position: Duration(seconds: 10),
        duration: Duration(seconds: 20),
      ),
    );

    expect(timelines.last.chapterElapsed, const Duration(seconds: 10));
    expect(timelines.last.chapterRemaining, const Duration(seconds: 20));
    await subscription.cancel();
    await coordinator.dispose();
  });

  test('ignores delayed chapter counts from an older play request', () async {
    final provider = FakeSpeechProvider();
    final paragraphs = ControllableChapterParagraphSource();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: paragraphs,
      voiceProfile: testVoiceProfile(),
    );
    final timelines = <PlaybackTimeline>[];
    final subscription = coordinator.timelineChanges.listen(timelines.add);

    final first = coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    await paragraphs.waitForCharacterRequests(1);
    final second = coordinator.playFrom(
      const PlaybackCursor(chapterId: 2, paragraphIndex: 0),
    );
    await paragraphs.waitForCharacterRequests(2);
    paragraphs.completeCharacterRequest(1, 10);
    await second;
    provider.publishTimeline(
      const PlaybackTimeline(
        position: Duration.zero,
        duration: Duration(seconds: 20),
      ),
    );
    paragraphs.completeCharacterRequest(0, 100);
    await first;
    provider.publishTimeline(
      const PlaybackTimeline(
        position: Duration.zero,
        duration: Duration(seconds: 20),
      ),
    );

    expect(coordinator.cursor, const PlaybackCursor(chapterId: 2, paragraphIndex: 0));
    expect(timelines.last.chapterRemaining, const Duration(seconds: 20));
    await subscription.cancel();
    await coordinator.dispose();
  });

  test('ignores an older play request whose paragraph lookup finishes last', () async {
    final provider = FakeSpeechProvider();
    final paragraphs = ControllableLookupChapterParagraphSource();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: paragraphs,
      voiceProfile: testVoiceProfile(),
    );

    final first = coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    await paragraphs.waitForLookups(1);
    final second = coordinator.playFrom(
      const PlaybackCursor(chapterId: 2, paragraphIndex: 0),
    );
    await paragraphs.waitForLookups(2);
    paragraphs.completeLookup(1);
    await second;
    paragraphs.completeLookup(0);
    await first;

    expect(
      coordinator.cursor,
      const PlaybackCursor(chapterId: 2, paragraphIndex: 0),
    );
    await coordinator.dispose();
  });

  test('keeps active playback when a newer paragraph lookup fails', () async {
    final provider = FakeSpeechProvider();
    final paragraphs = FailingTakeoverParagraphSource(
      activeText: List.filled(361, '旧').join(),
      failLookup: true,
    );
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: paragraphs,
      voiceProfile: VoiceProfile.mimo(),
    );
    final timelines = <PlaybackTimeline>[];
    final subscription = coordinator.timelineChanges.listen(timelines.add);
    const activeCursor = PlaybackCursor(chapterId: 1, paragraphIndex: 0);

    await coordinator.playFrom(activeCursor);
    provider.publishTimeline(
      const PlaybackTimeline(
        position: Duration(seconds: 1),
        duration: Duration(seconds: 10),
      ),
    );

    await expectLater(
      coordinator.playFrom(
        const PlaybackCursor(chapterId: 2, paragraphIndex: 0),
      ),
      throwsStateError,
    );
    provider.publishTimeline(
      const PlaybackTimeline(
        position: Duration(seconds: 2),
        duration: Duration(seconds: 10),
      ),
    );

    expect(coordinator.cursor, activeCursor);
    expect(timelines.last.position, const Duration(seconds: 2));

    provider.completeCurrent();
    await pumpEventQueue();

    expect(
      provider.prepared.map((segment) => segment.text.runes.length),
      [360, 1],
    );
    await subscription.cancel();
    await coordinator.dispose();
  });

  test('keeps active playback when a newer chapter count fails', () async {
    final provider = FakeSpeechProvider();
    final paragraphs = FailingTakeoverParagraphSource(
      activeText: List.filled(361, '旧').join(),
      failChapterCount: true,
    );
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: paragraphs,
      voiceProfile: VoiceProfile.mimo(),
    );
    final timelines = <PlaybackTimeline>[];
    final subscription = coordinator.timelineChanges.listen(timelines.add);
    const activeCursor = PlaybackCursor(chapterId: 1, paragraphIndex: 0);

    await coordinator.playFrom(activeCursor);

    await expectLater(
      coordinator.playFrom(
        const PlaybackCursor(chapterId: 2, paragraphIndex: 0),
      ),
      throwsStateError,
    );
    provider.publishTimeline(
      const PlaybackTimeline(
        position: Duration(seconds: 2),
        duration: Duration(seconds: 10),
      ),
    );

    expect(coordinator.cursor, activeCursor);
    expect(timelines.last.position, const Duration(seconds: 2));

    provider.completeCurrent();
    await pumpEventQueue();

    expect(
      provider.prepared.map((segment) => segment.text.runes.length),
      [360, 1],
    );
    await subscription.cancel();
    await coordinator.dispose();
  });
}

final class _RecordingTelemetry implements PlaybackTelemetry {
  final List<(String, Map<String, Object?>)> events = [];

  @override
  void record(String name, [Map<String, Object?> fields = const {}]) {
    events.add((name, fields));
  }

  @override
  Future<void> flush() async {}
}

final class _ThrowingTelemetry implements PlaybackTelemetry {
  @override
  void record(String name, [Map<String, Object?> fields = const {}]) {
    throw StateError('telemetry failed');
  }

  @override
  Future<void> flush() async {}
}

final class FakeParagraphSource implements PlaybackParagraphSource {
  FakeParagraphSource(this.values);

  final List<String> values;

  @override
  Future<PlaybackParagraph?> at(PlaybackCursor cursor) async {
    if (cursor.paragraphIndex < 0 || cursor.paragraphIndex >= values.length) {
      return null;
    }
    return PlaybackParagraph(
      id: cursor.paragraphIndex + 1,
      cursor: cursor,
      text: values[cursor.paragraphIndex],
    );
  }

  @override
  Future<PlaybackParagraph?> nextAfter(PlaybackCursor cursor) {
    return at(
      PlaybackCursor(
        chapterId: cursor.chapterId,
        paragraphIndex: cursor.paragraphIndex + 1,
      ),
    );
  }
}

final class FakeProgressRepository implements PlaybackProgressRepository {
  PlaybackCursor? confirmed;

  @override
  Future<void> confirm(PlaybackCursor cursor) async {
    confirmed = cursor;
  }
}

final class FakeSpeechProvider
    implements
        SpeechProvider,
        AdjustableSpeechProvider,
        PrefetchingSpeechProvider,
        PlaybackStatusSpeechProvider,
        TimedSpeechProvider {
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  final _timeline = StreamController<PlaybackTimeline>.broadcast(sync: true);
  final List<SpeechSegment> prepared = [];
  final List<SpeechSegment> prefetched = [];
  int pauseCalls = 0;
  final List<double> speedChanges = [];
  Object? speedFailure;
  Completer<void>? prefetchBlock;
  int activePrefetches = 0;
  int maxActivePrefetches = 0;
  int prefetchFailuresRemaining = 0;

  @override
  SpeechPlaybackStatus playbackStatus = SpeechPlaybackStatus.unknown;

  @override
  Stream<SpeechEvent> get events => _events.stream;

  @override
  Stream<PlaybackTimeline> get playbackTimeline => _timeline.stream;

  @override
  Future<void> prepare(SpeechSegment segment, VoiceProfile profile) async {
    prepared.add(segment);
  }

  @override
  Future<void> prefetch(SpeechSegment segment, VoiceProfile profile) async {
    activePrefetches++;
    if (activePrefetches > maxActivePrefetches) {
      maxActivePrefetches = activePrefetches;
    }
    try {
      await prefetchBlock?.future;
      if (prefetchFailuresRemaining > 0) {
        prefetchFailuresRemaining--;
        throw StateError('transient prefetch failure');
      }
      prefetched.add(segment);
    } finally {
      activePrefetches--;
    }
  }

  Future<void> waitForActivePrefetches(int count) async {
    while (activePrefetches != count) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    speedChanges.add(speed);
    final failure = speedFailure;
    if (failure != null) {
      throw failure;
    }
  }

  void completeCurrent() {
    _events.add(SpeechCompleted(segmentId: prepared.last.id));
  }

  void failCurrent() {
    _events.add(
      SpeechFailed(
        segmentId: prepared.last.id,
        failure: const AppFailure('云端语音播放准备失败'),
      ),
    );
  }

  void publishTimeline(PlaybackTimeline timeline) => _timeline.add(timeline);
}

/// A speech provider that models a native look-ahead playlist plus a local
/// cache, so the coordinator's lock-screen behaviour (native auto-advance and
/// cache-first prepare) can be exercised without a real audio engine.
final class PlaylistCacheSpeechProvider
    implements
        SpeechProvider,
        PrefetchingSpeechProvider,
        AdjustableSpeechProvider,
        PlaylistSpeechProvider,
        CacheOnlySpeechProvider {
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  final List<SpeechSegment> prepared = [];
  final List<SpeechSegment> prefetched = [];
  final List<SpeechSegment> cacheChecked = [];
  final Set<String> cached = {};
  final List<String> queue = [];
  final List<double> speedChanges = [];
  int playCalls = 0;
  int pauseCalls = 0;
  bool prefetchCaches = true;
  String? _currentSegmentId;

  @override
  Stream<SpeechEvent> get events => _events.stream;

  @override
  String? get currentSegmentId => _currentSegmentId;

  @override
  Future<void> prepare(SpeechSegment segment, VoiceProfile profile) async {
    prepared.add(segment);
    cached.add(segment.id);
    queue.clear();
    _currentSegmentId = segment.id;
  }

  @override
  Future<bool> prepareCached(
    SpeechSegment segment,
    VoiceProfile profile,
  ) async {
    cacheChecked.add(segment);
    if (!cached.contains(segment.id)) {
      return false;
    }
    queue.clear();
    _currentSegmentId = segment.id;
    return true;
  }

  @override
  Future<void> prefetch(SpeechSegment segment, VoiceProfile profile) async {
    if (!prefetchCaches) {
      return;
    }
    prefetched.add(segment);
    cached.add(segment.id);
    queue.add(segment.id);
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async => speedChanges.add(speed);

  @override
  Future<void> play() async => playCalls++;

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {
    queue.clear();
    _currentSegmentId = null;
  }

  /// Simulates just_audio finishing the current segment and auto-advancing into
  /// the head of the native queue before the coordinator sees the completion.
  void advanceNative() {
    final finished = _currentSegmentId;
    if (queue.isNotEmpty) {
      _currentSegmentId = queue.removeAt(0);
    }
    if (finished != null) {
      _events.add(SpeechCompleted(segmentId: finished));
    }
  }

  /// Simulates the current segment finishing with nothing left in the queue.
  void completeCurrent() {
    final id = _currentSegmentId;
    if (id != null) {
      _events.add(SpeechCompleted(segmentId: id));
    }
  }
}

final class ChapterAwareParagraphSource
    implements PlaybackParagraphSource, PlaybackChapterTextSource {
  ChapterAwareParagraphSource(this.values);

  final List<String> values;

  @override
  Future<PlaybackParagraph?> at(PlaybackCursor cursor) async {
    if (cursor.paragraphIndex < 0 || cursor.paragraphIndex >= values.length) {
      return null;
    }
    return PlaybackParagraph(
      id: cursor.paragraphIndex + 1,
      cursor: cursor,
      text: values[cursor.paragraphIndex],
    );
  }

  @override
  Future<PlaybackParagraph?> nextAfter(PlaybackCursor cursor) => at(
    PlaybackCursor(
      chapterId: cursor.chapterId,
      paragraphIndex: cursor.paragraphIndex + 1,
    ),
  );

  @override
  Future<int> remainingCharactersInChapter(PlaybackCursor cursor) async =>
      values
          .skip(cursor.paragraphIndex)
          .fold<int>(0, (total, value) => total + value.runes.length);
}

final class ControllableChapterParagraphSource
    implements PlaybackParagraphSource, PlaybackChapterTextSource {
  final List<Completer<int>> _characterRequests = [];

  @override
  Future<PlaybackParagraph?> at(PlaybackCursor cursor) async => PlaybackParagraph(
    id: cursor.chapterId,
    cursor: cursor,
    text: List.filled(10, '文').join(),
  );

  @override
  Future<PlaybackParagraph?> nextAfter(PlaybackCursor cursor) async => null;

  @override
  Future<int> remainingCharactersInChapter(PlaybackCursor cursor) {
    final request = Completer<int>();
    _characterRequests.add(request);
    return request.future;
  }

  Future<void> waitForCharacterRequests(int count) async {
    while (_characterRequests.length < count) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void completeCharacterRequest(int index, int characters) {
    _characterRequests[index].complete(characters);
  }
}

final class ControllableLookupChapterParagraphSource
    implements PlaybackParagraphSource, PlaybackChapterTextSource {
  final List<PlaybackCursor> _cursors = [];
  final List<Completer<PlaybackParagraph?>> _lookups = [];

  @override
  Future<PlaybackParagraph?> at(PlaybackCursor cursor) {
    _cursors.add(cursor);
    final lookup = Completer<PlaybackParagraph?>();
    _lookups.add(lookup);
    return lookup.future;
  }

  @override
  Future<PlaybackParagraph?> nextAfter(PlaybackCursor cursor) async => null;

  @override
  Future<int> remainingCharactersInChapter(PlaybackCursor cursor) async => 10;

  Future<void> waitForLookups(int count) async {
    while (_lookups.length < count) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void completeLookup(int index) {
    final cursor = _cursors[index];
    _lookups[index].complete(
      PlaybackParagraph(
        id: cursor.chapterId,
        cursor: cursor,
        text: List.filled(10, '文').join(),
      ),
    );
  }
}

final class FailingTakeoverParagraphSource
    implements PlaybackParagraphSource, PlaybackChapterTextSource {
  FailingTakeoverParagraphSource({
    required this.activeText,
    this.failLookup = false,
    this.failChapterCount = false,
  });

  final String activeText;
  final bool failLookup;
  final bool failChapterCount;

  @override
  Future<PlaybackParagraph?> at(PlaybackCursor cursor) async {
    if (cursor.chapterId == 2 && failLookup) {
      throw StateError('paragraph lookup failed');
    }
    return PlaybackParagraph(
      id: cursor.chapterId,
      cursor: cursor,
      text: cursor.chapterId == 1 ? activeText : '新段落',
    );
  }

  @override
  Future<PlaybackParagraph?> nextAfter(PlaybackCursor cursor) async => null;

  @override
  Future<int> remainingCharactersInChapter(PlaybackCursor cursor) async {
    if (cursor.chapterId == 2 && failChapterCount) {
      throw StateError('chapter count failed');
    }
    return cursor.chapterId == 1 ? activeText.runes.length : 3;
  }
}

final class ControllableTakeoverChapterSource
    implements PlaybackParagraphSource, PlaybackChapterTextSource {
  ControllableTakeoverChapterSource({required this.activeText});

  final String activeText;
  final Completer<void> _takeoverCountRequested = Completer<void>();
  final Completer<int> _takeoverCount = Completer<int>();

  @override
  Future<PlaybackParagraph?> at(PlaybackCursor cursor) async {
    return PlaybackParagraph(
      id: cursor.chapterId,
      cursor: cursor,
      text: cursor.chapterId == 1 ? activeText : '新段落',
    );
  }

  @override
  Future<PlaybackParagraph?> nextAfter(PlaybackCursor cursor) async => null;

  @override
  Future<int> remainingCharactersInChapter(PlaybackCursor cursor) {
    if (cursor.chapterId == 1) {
      return Future<int>.value(activeText.runes.length);
    }
    if (!_takeoverCountRequested.isCompleted) {
      _takeoverCountRequested.complete();
    }
    return _takeoverCount.future;
  }

  Future<void> waitForTakeoverCount() => _takeoverCountRequested.future;

  void completeTakeoverCount() => _takeoverCount.complete(3);
}

final class ControllablePrepareSpeechProvider implements SpeechProvider {
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  final List<Completer<void>> _prepares = [];
  final List<SpeechSegment> prepared = [];
  final List<SpeechSegment> played = [];
  SpeechSegment? currentSegment;
  int activePrepares = 0;
  int maxActivePrepares = 0;

  @override
  Stream<SpeechEvent> get events => _events.stream;

  @override
  Future<void> prepare(SpeechSegment segment, VoiceProfile profile) async {
    final prepare = Completer<void>();
    _prepares.add(prepare);
    prepared.add(segment);
    activePrepares++;
    if (activePrepares > maxActivePrepares) {
      maxActivePrepares = activePrepares;
    }
    try {
      await prepare.future;
      currentSegment = segment;
    } finally {
      activePrepares--;
    }
  }

  @override
  Future<void> play() async {
    final segment = currentSegment;
    if (segment == null) {
      throw StateError('No speech segment has been prepared.');
    }
    played.add(segment);
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  Future<void> waitForPrepares(int count) async {
    while (_prepares.length < count) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void completePrepare(int index) => _prepares[index].complete();

  void completeCurrent() {
    final segment = currentSegment;
    if (segment == null) {
      throw StateError('No speech segment has been prepared.');
    }
    _events.add(SpeechCompleted(segmentId: segment.id));
  }
}
