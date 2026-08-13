import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_timeline.dart';
import 'package:novel_voice_reader/features/speech/data/cached_audio_speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test('forwards the audio engine playback timeline', () async {
    final directory = await Directory.systemTemp.createTemp('cached-timeline-');
    final engine = FakeAudioPlaybackEngine();
    final provider = CachedAudioSpeechProvider(
      cache: AudioCacheRepository(
        directory: directory,
        synthesizer: FakeCloudSpeechSynthesizer(),
      ),
      engine: engine,
    );
    final timelines = <PlaybackTimeline>[];
    final subscription = (provider as TimedSpeechProvider).playbackTimeline
        .listen(timelines.add);

    engine.publishTimeline(
      const PlaybackTimeline(
        position: Duration(seconds: 12),
        duration: Duration(seconds: 60),
      ),
    );

    expect(timelines.single.position, const Duration(seconds: 12));
    expect(timelines.single.duration, const Duration(seconds: 60));
    await subscription.cancel();
    await provider.dispose();
    await directory.delete(recursive: true);
  });

  test('forwards playback speed to an adjustable audio engine', () async {
    final directory = await Directory.systemTemp.createTemp('cached-speed-');
    final engine = AdjustableFakeAudioPlaybackEngine();
    final provider = CachedAudioSpeechProvider(
      cache: AudioCacheRepository(
        directory: directory,
        synthesizer: FakeCloudSpeechSynthesizer(),
      ),
      engine: engine,
    );

    await provider.setPlaybackSpeed(1.25);

    expect(engine.speedChanges, [1.25]);
    await provider.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'rejects playback speed when the audio engine is not adjustable',
    () async {
      final directory = await Directory.systemTemp.createTemp('cached-speed-');
      final provider = CachedAudioSpeechProvider(
        cache: AudioCacheRepository(
          directory: directory,
          synthesizer: FakeCloudSpeechSynthesizer(),
        ),
        engine: FakeAudioPlaybackEngine(),
      );

      await expectLater(provider.setPlaybackSpeed(1.25), throwsStateError);

      await provider.dispose();
      await directory.delete(recursive: true);
    },
  );

  test('plays cached audio and exposes speech lifecycle events', () async {
    final directory = await Directory.systemTemp.createTemp('cached-speech-');
    final engine = FakeAudioPlaybackEngine();
    final provider = CachedAudioSpeechProvider(
      cache: AudioCacheRepository(
        directory: directory,
        synthesizer: FakeCloudSpeechSynthesizer(),
      ),
      engine: engine,
    );
    final events = <SpeechEvent>[];
    final subscription = provider.events.listen(events.add);
    const segment = SpeechSegment(
      id: '9:0',
      paragraphId: 9,
      text: '正文',
      partIndex: 0,
    );
    final profile = VoiceProfile.cloud(
      baseUrl: 'https://example.com',
      model: 'tts-model',
      voice: 'voice-a',
      speed: 1,
      outputFormat: 'mp3',
    );

    await provider.prepare(segment, profile);
    await provider.play();
    engine.complete();
    await pumpEventQueue();

    expect(engine.filePath, isNotNull);
    expect(await File(engine.filePath!).exists(), isTrue);
    expect(events.whereType<SpeechStarted>().single.segmentId, '9:0');
    expect(events.whereType<SpeechCompleted>().single.segmentId, '9:0');

    await provider.pause();
    await provider.resume();
    await provider.stop();

    expect(engine.pauseCalls, 1);
    expect(engine.playCalls, 2);
    expect(engine.stopCalls, 1);

    await subscription.cancel();
    await provider.dispose();
    await directory.delete(recursive: true);
  });

  test('prefetch warms the cache without replacing active audio', () async {
    final directory = await Directory.systemTemp.createTemp('cached-prefetch-');
    final engine = FakeAudioPlaybackEngine();
    final synthesizer = FakeCloudSpeechSynthesizer();
    final provider = CachedAudioSpeechProvider(
      cache: AudioCacheRepository(
        directory: directory,
        synthesizer: synthesizer,
      ),
      engine: engine,
    );
    const segment = SpeechSegment(
      id: '10:0',
      paragraphId: 10,
      text: '下一段正文',
      partIndex: 0,
    );
    final profile = VoiceProfile.cloud(
      baseUrl: 'https://example.com',
      model: 'tts-model',
      voice: 'voice-a',
      speed: 1,
      outputFormat: 'mp3',
    );

    final prefetching = provider as PrefetchingSpeechProvider;
    await prefetching.prefetch(segment, profile);

    expect(engine.filePath, isNull);
    expect(synthesizer.calls, 1);
    await provider.prepare(segment, profile);
    expect(engine.filePath, isNotNull);
    expect(synthesizer.calls, 1);

    await provider.dispose();
    await directory.delete(recursive: true);
  });

  test('prefetch queues the next file for native background continuation', () async {
    final directory = await Directory.systemTemp.createTemp('cached-queue-');
    final engine = QueuedFakeAudioPlaybackEngine();
    final provider = CachedAudioSpeechProvider(
      cache: AudioCacheRepository(
        directory: directory,
        synthesizer: FakeCloudSpeechSynthesizer(),
      ),
      engine: engine,
    );
    const current = SpeechSegment(
      id: '20:0',
      paragraphId: 20,
      text: '当前段落',
      partIndex: 0,
    );
    const next = SpeechSegment(
      id: '21:0',
      paragraphId: 21,
      text: '下一段落',
      partIndex: 0,
    );
    final profile = _cloudProfile();

    await provider.prepare(current, profile);
    await provider.play();
    await (provider as PrefetchingSpeechProvider).prefetch(next, profile);

    expect(engine.queuedPaths, hasLength(1));
    engine.advanceToQueued();
    await provider.prepare(next, profile);
    await provider.play();

    expect(engine.filePaths, hasLength(1));
    expect(engine.promotedPaths, [engine.queuedPaths.single]);
    expect(engine.playCalls, 1);

    await provider.dispose();
    await directory.delete(recursive: true);
  });

  test('prefetch appends multiple files to the native queue in order', () async {
    final directory = await Directory.systemTemp.createTemp('cached-multi-queue-');
    final engine = QueuedFakeAudioPlaybackEngine();
    final provider = CachedAudioSpeechProvider(
      cache: AudioCacheRepository(
        directory: directory,
        synthesizer: FakeCloudSpeechSynthesizer(),
      ),
      engine: engine,
    );
    const current = SpeechSegment(id: '60:0', paragraphId: 60, text: '当前', partIndex: 0);
    const first = SpeechSegment(id: '61:0', paragraphId: 61, text: '第一项', partIndex: 0);
    const second = SpeechSegment(id: '62:0', paragraphId: 62, text: '第二项', partIndex: 0);
    final profile = _cloudProfile();

    await provider.prepare(current, profile);
    await provider.play();
    await (provider as PrefetchingSpeechProvider).prefetch(first, profile);
    await provider.prefetch(second, profile);

    expect(engine.queuedPaths, hasLength(2));
    expect(engine.queuedPaths[0], isNot(engine.queuedPaths[1]));

    await provider.dispose();
    await directory.delete(recursive: true);
  });

  test('prepare reuses an in-flight prefetch request', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cached-prefetch-in-flight-',
    );
    final engine = FakeAudioPlaybackEngine();
    final synthesizer = ControllableCloudSpeechSynthesizer();
    final provider = CachedAudioSpeechProvider(
      cache: AudioCacheRepository(
        directory: directory,
        synthesizer: synthesizer,
      ),
      engine: engine,
    );
    const segment = SpeechSegment(
      id: '11:0',
      paragraphId: 11,
      text: '并发预取正文',
      partIndex: 0,
    );
    final profile = _cloudProfile();

    final prefetch = (provider as PrefetchingSpeechProvider).prefetch(
      segment,
      profile,
    );
    await synthesizer.waitForRequests(1);
    final prepare = provider.prepare(segment, profile);
    await pumpEventQueue();

    expect(synthesizer.requests, hasLength(1));
    synthesizer.complete(0);
    await Future.wait([prefetch, prepare]);
    expect(engine.filePaths, hasLength(1));

    await provider.dispose();
    await directory.delete(recursive: true);
  });

  test('stale prefetch cannot queue audio after playback target changes', () async {
    final directory = await Directory.systemTemp.createTemp('cached-stale-queue-');
    final engine = QueuedFakeAudioPlaybackEngine();
    final synthesizer = ControllableCloudSpeechSynthesizer();
    final provider = CachedAudioSpeechProvider(
      cache: AudioCacheRepository(directory: directory, synthesizer: synthesizer),
      engine: engine,
    );
    const current = SpeechSegment(id: '30:0', paragraphId: 30, text: '当前', partIndex: 0);
    const staleNext = SpeechSegment(id: '31:0', paragraphId: 31, text: '旧下一段', partIndex: 0);
    const replacement = SpeechSegment(id: '40:0', paragraphId: 40, text: '跳转目标', partIndex: 0);
    final profile = _cloudProfile();

    final initialPrepare = provider.prepare(current, profile);
    await synthesizer.waitForRequests(1);
    synthesizer.complete(0);
    await initialPrepare;
    final stalePrefetch = (provider as PrefetchingSpeechProvider).prefetch(
      staleNext,
      profile,
    );
    await synthesizer.waitForRequests(2);
    final replacementPrepare = provider.prepare(replacement, profile);
    await synthesizer.waitForRequests(3);
    synthesizer.complete(2);
    await replacementPrepare;
    synthesizer.complete(1);
    await stalePrefetch;

    expect(engine.queuedPaths, isEmpty);

    await provider.dispose();
    await directory.delete(recursive: true);
  });

  test('attributes a queued terminal completion to the promoted segment', () async {
    final directory = await Directory.systemTemp.createTemp('cached-terminal-');
    final engine = QueuedFakeAudioPlaybackEngine();
    final provider = CachedAudioSpeechProvider(
      cache: AudioCacheRepository(
        directory: directory,
        synthesizer: FakeCloudSpeechSynthesizer(),
      ),
      engine: engine,
    );
    final events = <SpeechEvent>[];
    final subscription = provider.events.listen(events.add);
    const current = SpeechSegment(id: '50:0', paragraphId: 50, text: '甲', partIndex: 0);
    const next = SpeechSegment(id: '51:0', paragraphId: 51, text: '乙', partIndex: 0);
    final profile = _cloudProfile();

    await provider.prepare(current, profile);
    await provider.play();
    await (provider as PrefetchingSpeechProvider).prefetch(next, profile);
    engine.advanceToQueued(completed: true);
    await pumpEventQueue();
    await provider.prepare(next, profile);
    await provider.play();
    await pumpEventQueue();

    expect(
      events.whereType<SpeechCompleted>().map((event) => event.segmentId),
      ['50:0', '51:0'],
    );

    await subscription.cancel();
    await provider.dispose();
    await directory.delete(recursive: true);
  });

  test('maps completed file paths to their queued speech segments', () async {
    final directory = await Directory.systemTemp.createTemp('cached-path-events-');
    final engine = QueuedFakeAudioPlaybackEngine();
    final provider = CachedAudioSpeechProvider(
      cache: AudioCacheRepository(
        directory: directory,
        synthesizer: FakeCloudSpeechSynthesizer(),
      ),
      engine: engine,
    );
    final events = <SpeechEvent>[];
    final subscription = provider.events.listen(events.add);
    const current = SpeechSegment(id: '70:0', paragraphId: 70, text: '甲', partIndex: 0);
    const next = SpeechSegment(id: '71:0', paragraphId: 71, text: '乙', partIndex: 0);
    final profile = _cloudProfile();

    await provider.prepare(current, profile);
    await (provider as PrefetchingSpeechProvider).prefetch(next, profile);
    engine.completePath(engine.filePath!);
    engine.completePath(engine.queuedPaths.single);
    await pumpEventQueue();

    expect(
      events.whereType<SpeechCompleted>().map((event) => event.segmentId),
      ['70:0', '71:0'],
    );

    await subscription.cancel();
    await provider.dispose();
    await directory.delete(recursive: true);
  });

  test('a stale prepare cannot replace the newest audio source', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cached-latest-prepare-',
    );
    final engine = FakeAudioPlaybackEngine();
    final synthesizer = ControllableCloudSpeechSynthesizer();
    final provider = CachedAudioSpeechProvider(
      cache: AudioCacheRepository(
        directory: directory,
        synthesizer: synthesizer,
      ),
      engine: engine,
    );
    const firstSegment = SpeechSegment(
      id: '12:0',
      paragraphId: 12,
      text: '旧段落',
      partIndex: 0,
    );
    const secondSegment = SpeechSegment(
      id: '13:0',
      paragraphId: 13,
      text: '新段落',
      partIndex: 0,
    );
    final profile = _cloudProfile();

    final firstPrepare = provider.prepare(firstSegment, profile);
    await synthesizer.waitForRequests(1);
    final secondPrepare = provider.prepare(secondSegment, profile);
    await synthesizer.waitForRequests(2);
    synthesizer.complete(1);
    await secondPrepare;
    synthesizer.complete(0);
    await firstPrepare;

    expect(engine.filePaths, hasLength(1));

    await provider.dispose();
    await directory.delete(recursive: true);
  });
}

VoiceProfile _cloudProfile() => VoiceProfile.cloud(
  baseUrl: 'https://example.com',
  model: 'tts-model',
  voice: 'voice-a',
  speed: 1,
  outputFormat: 'mp3',
);

final class FakeCloudSpeechSynthesizer implements CloudSpeechSynthesizer {
  int calls = 0;

  @override
  Future<Uint8List> synthesize(
    SpeechSegment segment,
    VoiceProfile profile,
  ) async {
    calls++;
    return Uint8List.fromList(const [0x49, 0x44, 0x33, 0x04]);
  }
}

final class ControllableCloudSpeechSynthesizer
    implements CloudSpeechSynthesizer {
  final List<Completer<Uint8List>> requests = [];

  @override
  Future<Uint8List> synthesize(SpeechSegment segment, VoiceProfile profile) {
    final request = Completer<Uint8List>();
    requests.add(request);
    return request.future;
  }

  void complete(int index) {
    requests[index].complete(
      Uint8List.fromList(const [0x49, 0x44, 0x33, 0x04]),
    );
  }

  Future<void> waitForRequests(int count) async {
    while (requests.length < count) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

class FakeAudioPlaybackEngine
    implements AudioPlaybackEngine, TimedAudioPlaybackEngine {
  final _completed = StreamController<String>.broadcast(sync: true);
  final _timeline = StreamController<PlaybackTimeline>.broadcast(sync: true);
  String? filePath;
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  final List<String> filePaths = [];

  @override
  Stream<String> get completed => _completed.stream;

  @override
  Stream<PlaybackTimeline> get playbackTimeline => _timeline.stream;

  @override
  Future<void> setFilePath(String path) async {
    filePath = path;
    filePaths.add(path);
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _completed.close();
    await _timeline.close();
  }

  void complete() {
    final path = filePath;
    if (path != null) {
      _completed.add(path);
    }
  }

  void completePath(String path) => _completed.add(path);

  void publishTimeline(PlaybackTimeline timeline) => _timeline.add(timeline);
}

final class AdjustableFakeAudioPlaybackEngine extends FakeAudioPlaybackEngine
    implements AdjustableAudioPlaybackEngine {
  final List<double> speedChanges = [];

  @override
  Future<void> setSpeed(double speed) async => speedChanges.add(speed);
}

final class QueuedFakeAudioPlaybackEngine extends FakeAudioPlaybackEngine
    implements QueuedAudioPlaybackEngine {
  final List<String> queuedPaths = [];
  final List<String> promotedPaths = [];
  String? _activeQueuedPath;
  bool _queuedCompleted = false;

  @override
  Future<void> queueNextFilePath(String path) async => queuedPaths.add(path);

  void advanceToQueued({bool completed = false}) {
    _activeQueuedPath = queuedPaths.first;
    _queuedCompleted = completed;
    final currentPath = filePath;
    if (currentPath != null) {
      _completed.add(currentPath);
    }
  }

  @override
  Future<QueuedAudioPromotion> promoteQueuedFilePath(String path) async {
    promotedPaths.add(path);
    if (path != _activeQueuedPath) {
      return QueuedAudioPromotion.notPromoted;
    }
    return _queuedCompleted
        ? QueuedAudioPromotion.completed
        : QueuedAudioPromotion.playing;
  }
}
