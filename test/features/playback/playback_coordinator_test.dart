import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_coordinator.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_timeline.dart';
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

  test('serializes provider takeover and only plays the newest request', () async {
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

  test('estimates chapter remaining time from the timed current segment', () async {
    final provider = FakeSpeechProvider();
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: ChapterAwareParagraphSource([
        List.filled(10, '当').join(),
        List.filled(5, '后').join(),
      ]),
      voiceProfile: VoiceProfile.system(),
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

    expect(timelines.last.chapterRemaining, const Duration(seconds: 30));
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
      voiceProfile: VoiceProfile.system(),
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
      voiceProfile: VoiceProfile.system(),
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
      activeText: List.filled(151, '旧').join(),
      failLookup: true,
    );
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: paragraphs,
      voiceProfile: VoiceProfile.tencent(),
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
    provider.completeCurrent();
    await pumpEventQueue();

    expect(coordinator.cursor, activeCursor);
    expect(timelines.last.position, const Duration(seconds: 2));
    expect(
      provider.prepared.map((segment) => segment.text.runes.length),
      [150, 1],
    );
    await subscription.cancel();
    await coordinator.dispose();
  });

  test('keeps active playback when a newer chapter count fails', () async {
    final provider = FakeSpeechProvider();
    final paragraphs = FailingTakeoverParagraphSource(
      activeText: List.filled(151, '旧').join(),
      failChapterCount: true,
    );
    final coordinator = PlaybackCoordinator(
      provider: provider,
      progress: FakeProgressRepository(),
      paragraphs: paragraphs,
      voiceProfile: VoiceProfile.tencent(),
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
    provider.completeCurrent();
    await pumpEventQueue();

    expect(coordinator.cursor, activeCursor);
    expect(timelines.last.position, const Duration(seconds: 2));
    expect(
      provider.prepared.map((segment) => segment.text.runes.length),
      [150, 1],
    );
    await subscription.cancel();
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
        PrefetchingSpeechProvider,
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

  void publishTimeline(PlaybackTimeline timeline) => _timeline.add(timeline);
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
}
