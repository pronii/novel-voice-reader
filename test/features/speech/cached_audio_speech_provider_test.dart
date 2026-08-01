import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/speech/data/cached_audio_speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
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
}

final class FakeCloudSpeechSynthesizer implements CloudSpeechSynthesizer {
  @override
  Future<Uint8List> synthesize(
    SpeechSegment segment,
    VoiceProfile profile,
  ) async {
    return Uint8List.fromList(const [0x49, 0x44, 0x33, 0x04]);
  }
}

class FakeAudioPlaybackEngine implements AudioPlaybackEngine {
  final _completed = StreamController<void>.broadcast(sync: true);
  String? filePath;
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<void> get completed => _completed.stream;

  @override
  Future<void> setFilePath(String path) async {
    filePath = path;
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
  }

  void complete() => _completed.add(null);
}

final class AdjustableFakeAudioPlaybackEngine extends FakeAudioPlaybackEngine
    implements AdjustableAudioPlaybackEngine {
  final List<double> speedChanges = [];

  @override
  Future<void> setSpeed(double speed) async => speedChanges.add(speed);
}
