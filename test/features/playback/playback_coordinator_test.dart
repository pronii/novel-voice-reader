import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_coordinator.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test('publishes the cursor when each paragraph starts playing', () async {
    final provider = FakeSpeechProvider();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource(const ['第一段', '第二段']),
      voiceProfile: VoiceProfile.system(),
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
      voiceProfile: VoiceProfile.system(),
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

  test('prefetches the next paragraph while the current one plays', () async {
    final provider = FakeSpeechProvider();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource(const ['第一段', '第二段']),
      voiceProfile: VoiceProfile.system(),
    );

    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    await pumpEventQueue();

    expect(provider.prefetched.map((segment) => segment.text), ['第二段']);
    expect(provider.prepared.map((segment) => segment.text), ['第一段']);
    await coordinator.dispose();
  });

  test('only the newest concurrent play request can start audio', () async {
    final provider = ControllablePrepareSpeechProvider();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource(const ['第一段', '第二段']),
      voiceProfile: VoiceProfile.system(),
    );

    final first = coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    await provider.waitForPrepares(1);
    final second = coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 1),
    );
    await provider.waitForPrepares(2);
    provider.completePrepare(1);
    await second;
    provider.completePrepare(0);
    await first;

    expect(provider.playCalls, 1);
    expect(
      coordinator.cursor,
      const PlaybackCursor(chapterId: 1, paragraphIndex: 1),
    );
    await coordinator.dispose();
  });

  test('serializes prefetches across rapid playback changes', () async {
    final provider = FakeSpeechProvider()..prefetchBlock = Completer<void>();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource(const ['第一段', '第二段', '第三段']),
      voiceProfile: VoiceProfile.system(),
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
      voiceProfile: VoiceProfile.system(),
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

  test('pause persists the current cursor and delegates to provider', () async {
    final provider = FakeSpeechProvider();
    final progress = FakeProgressRepository();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: progress,
      paragraphs: FakeParagraphSource(const ['第一段']),
      voiceProfile: VoiceProfile.system(),
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
      voiceProfile: VoiceProfile.system(),
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
      voiceProfile: VoiceProfile.system(),
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
      paragraphs: FakeParagraphSource([List.filled(151, '文').join()]),
      voiceProfile: VoiceProfile.tencent(),
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

  test('splits Tencent playback into at most 150 characters', () async {
    final provider = FakeSpeechProvider();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: FakeParagraphSource([List.filled(151, '文').join()]),
      voiceProfile: VoiceProfile.tencent(),
    );

    await coordinator.playFrom(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 0),
    );
    expect(provider.prepared.single.text.runes.length, 150);

    provider.completeCurrent();
    await pumpEventQueue();
    expect(provider.prepared.last.text.runes.length, 1);
    await coordinator.dispose();
  });
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
        PrefetchingSpeechProvider {
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  final List<SpeechSegment> prepared = [];
  final List<SpeechSegment> prefetched = [];
  int pauseCalls = 0;
  final List<double> speedChanges = [];
  Object? speedFailure;
  Completer<void>? prefetchBlock;
  int activePrefetches = 0;
  int maxActivePrefetches = 0;

  @override
  Stream<SpeechEvent> get events => _events.stream;

  @override
  Future<void> prepare(SpeechSegment segment, VoiceProfile profile) async {
    prepared.add(segment);
  }

  @override
  Future<void> prefetch(SpeechSegment segment, VoiceProfile profile) async {
    prefetched.add(segment);
    activePrefetches++;
    if (activePrefetches > maxActivePrefetches) {
      maxActivePrefetches = activePrefetches;
    }
    try {
      await prefetchBlock?.future;
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
}

final class ControllablePrepareSpeechProvider implements SpeechProvider {
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  final List<Completer<void>> _prepares = [];
  int playCalls = 0;

  @override
  Stream<SpeechEvent> get events => _events.stream;

  @override
  Future<void> prepare(SpeechSegment segment, VoiceProfile profile) async {
    final prepare = Completer<void>();
    _prepares.add(prepare);
    await prepare.future;
  }

  @override
  Future<void> play() async => playCalls++;

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
}
