import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_handler.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_session.dart';
import 'package:novel_voice_reader/features/playback/data/background_keep_alive.dart';
import 'package:novel_voice_reader/features/playback/data/background_playback_sustainer.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_coordinator.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_timeline.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'keeps the session rendering across a segment gap without deactivating',
    () async {
      final harness = _Harness();

      harness.handler.markPlaying();
      await pumpEventQueue();

      expect(harness.keepAlive.startCalls, 1);
      expect(harness.delegate.activations, greaterThanOrEqualTo(1));

      // Simulate the gap between two spoken segments: the coordinator resets
      // the timeline and re-announces playing, but never reports paused.
      harness.handler.publishTimeline(PlaybackTimeline.zero);
      harness.handler.markPlaying();
      await pumpEventQueue();

      // The inaudible loop stays running through the gap.
      expect(harness.keepAlive.startCalls, 1);
      expect(harness.keepAlive.stopCalls, 0);
      expect(harness.delegate.deactivations, 0);

      await harness.dispose();
    },
  );

  test('stops the keep-alive loop on pause but never deactivates', () async {
    final harness = _Harness();

    harness.handler.markPlaying();
    await pumpEventQueue();
    harness.handler.markPaused();
    await pumpEventQueue();

    expect(harness.keepAlive.startCalls, 1);
    expect(harness.keepAlive.stopCalls, 1);
    expect(harness.delegate.deactivations, 0);

    await harness.dispose();
  });

  test('re-activates and resumes after an interruption ends', () async {
    final harness = _Harness();

    harness.handler.markPlaying();
    await pumpEventQueue();
    final activationsBeforeInterruption = harness.delegate.activations;

    harness.delegate.emitInterruption(AudioInterruption.began);
    await pumpEventQueue();
    expect(harness.controller.pauseCalls, 1);
    expect(harness.handler.playbackState.value.playing, isFalse);
    expect(harness.keepAlive.stopCalls, 1);

    harness.delegate.emitInterruption(AudioInterruption.endedShouldResume);
    await pumpEventQueue();

    expect(harness.controller.resumeCalls, 1);
    expect(harness.handler.playbackState.value.playing, isTrue);
    expect(harness.keepAlive.startCalls, 2);
    expect(
      harness.delegate.activations,
      greaterThan(activationsBeforeInterruption),
    );
    expect(harness.delegate.deactivations, 0);

    await harness.dispose();
  });

  test('does not resume when playback was paused before the interruption', () async {
    final harness = _Harness();

    harness.delegate.emitInterruption(AudioInterruption.began);
    await pumpEventQueue();
    harness.delegate.emitInterruption(AudioInterruption.endedShouldResume);
    await pumpEventQueue();

    expect(harness.controller.resumeCalls, 0);
    expect(harness.handler.playbackState.value.playing, isFalse);

    await harness.dispose();
  });

  test('stays paused when an interruption ends without a resume hint', () async {
    final harness = _Harness();

    harness.handler.markPlaying();
    await pumpEventQueue();

    harness.delegate.emitInterruption(AudioInterruption.began);
    await pumpEventQueue();
    harness.delegate.emitInterruption(AudioInterruption.endedShouldStay);
    await pumpEventQueue();

    expect(harness.controller.resumeCalls, 0);
    expect(harness.handler.playbackState.value.playing, isFalse);
    expect(harness.delegate.deactivations, 0);

    await harness.dispose();
  });

  test('re-activates the session on route changes while playing', () async {
    final harness = _Harness();

    harness.handler.markPlaying();
    await pumpEventQueue();
    final activationsBeforeRouteChange = harness.delegate.activations;

    harness.delegate.emitDevicesChanged();
    await pumpEventQueue();

    expect(
      harness.delegate.activations,
      greaterThan(activationsBeforeRouteChange),
    );
    expect(harness.delegate.deactivations, 0);

    await harness.dispose();
  });

  test('ignores route changes while playback is idle', () async {
    final harness = _Harness();

    harness.delegate.emitDevicesChanged();
    await pumpEventQueue();

    expect(harness.delegate.activations, 0);

    await harness.dispose();
  });
}

final class _Harness {
  _Harness() {
    session = BackgroundAudioSession(delegate, false);
    handler = NovelAudioHandler(controller);
    sustainer = BackgroundPlaybackSustainer(
      session: session,
      keepAlive: keepAlive,
      handler: handler,
    );
  }

  final delegate = _FakeAudioSessionDelegate();
  final keepAlive = _RecordingKeepAlivePlayer();
  final controller = _FakePlaybackController(
    const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
  );
  late final BackgroundAudioSession session;
  late final NovelAudioHandler handler;
  late final BackgroundPlaybackSustainer sustainer;

  Future<void> dispose() => sustainer.dispose();
}

final class _FakeAudioSessionDelegate implements AudioSessionDelegate {
  final _interruptions = StreamController<AudioInterruption>.broadcast();
  final _devices = StreamController<void>.broadcast();
  int activations = 0;
  int deactivations = 0;

  void emitInterruption(AudioInterruption interruption) =>
      _interruptions.add(interruption);

  void emitDevicesChanged() => _devices.add(null);

  @override
  Future<void> configure(AudioSessionConfiguration configuration) async {}

  @override
  Future<bool> setActive(bool active) async {
    if (active) {
      activations++;
    } else {
      deactivations++;
    }
    return active;
  }

  @override
  Stream<AudioInterruption> get interruptions => _interruptions.stream;

  @override
  Stream<void> get devicesChanged => _devices.stream;
}

final class _RecordingKeepAlivePlayer implements KeepAlivePlayer {
  int startCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> start() async => startCalls++;

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> dispose() async => disposeCalls++;
}

final class _FakePlaybackController implements PlaybackController {
  _FakePlaybackController([this._cursor]);

  PlaybackCursor? _cursor;
  int resumeCalls = 0;
  int pauseCalls = 0;

  @override
  PlaybackCursor? get cursor => _cursor;

  @override
  Future<void> nextParagraph() async {}

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> playFrom(PlaybackCursor cursor) async => _cursor = cursor;

  @override
  Future<void> previousParagraph() async {}

  @override
  Future<void> resume() async => resumeCalls++;

  @override
  Future<void> setSpeed(double speed) async {}
}
