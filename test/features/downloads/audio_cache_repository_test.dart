import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/downloads/domain/cache_key.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test('writes cloud audio atomically and reuses the final file', () async {
    final directory = await Directory.systemTemp.createTemp('voice-cache-test');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final synthesizer = FakeCloudSpeechSynthesizer(validMp3Bytes);
    final repository = AudioCacheRepository(
      directory: directory,
      synthesizer: synthesizer,
    );

    final first = await repository.obtain(testSegment, testProfile);
    final second = await repository.obtain(testSegment, testProfile);

    expect(first.path, second.path);
    expect(await first.readAsBytes(), validMp3Bytes);
    expect(synthesizer.calls, 1);
    expect(
      directory.listSync().where((entry) => entry.path.endsWith('.partial')),
      isEmpty,
    );
  });

  test('rejects corrupt audio without publishing a cache file', () async {
    final directory = await Directory.systemTemp.createTemp('voice-cache-test');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final repository = AudioCacheRepository(
      directory: directory,
      synthesizer: FakeCloudSpeechSynthesizer(Uint8List.fromList([1, 2, 3])),
    );

    await expectLater(
      repository.obtain(testSegment, testProfile),
      throwsA(isA<FormatException>()),
    );

    expect(directory.listSync(), isEmpty);
  });

  test('removes a stale partial file when synthesis fails', () async {
    final directory = await Directory.systemTemp.createTemp('voice-cache-test');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final key = CacheKey.forSegment(testSegment, testProfile);
    final partial = File(
      '${directory.path}${Platform.pathSeparator}$key.mp3.partial',
    );
    await partial.writeAsBytes([9, 9, 9]);
    final repository = AudioCacheRepository(
      directory: directory,
      synthesizer: FailingCloudSpeechSynthesizer(),
    );

    await expectLater(
      repository.obtain(testSegment, testProfile),
      throwsA(isA<StateError>()),
    );

    expect(await partial.exists(), isFalse);
    expect(directory.listSync(), isEmpty);
  });

  test('stores cloud MP3 output formats with an mp3 extension', () async {
    final directory = await Directory.systemTemp.createTemp('voice-cache-test');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final repository = AudioCacheRepository(
      directory: directory,
      synthesizer: FakeCloudSpeechSynthesizer(validMp3Bytes),
    );
    final profile = VoiceProfile.cloud(
      baseUrl: 'https://example.com',
      model: 'tts-model',
      voice: 'voice-a',
      speed: 1,
      outputFormat: 'mp3',
    );

    final file = await repository.obtain(testSegment, profile);

    expect(file.path, endsWith('.mp3'));
    expect(await file.readAsBytes(), validMp3Bytes);
  });

  test('stores MiMo WAV output with a wav extension', () async {
    final directory = await Directory.systemTemp.createTemp('voice-cache-test');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final repository = AudioCacheRepository(
      directory: directory,
      synthesizer: FakeCloudSpeechSynthesizer(validWavBytes),
    );

    final file = await repository.obtain(testSegment, VoiceProfile.mimo());

    expect(file.path, endsWith('.wav'));
    expect(await file.readAsBytes(), validWavBytes);
  });
}

final class FakeCloudSpeechSynthesizer implements CloudSpeechSynthesizer {
  FakeCloudSpeechSynthesizer(this.bytes);

  final Uint8List bytes;
  int calls = 0;

  @override
  Future<Uint8List> synthesize(
    SpeechSegment segment,
    VoiceProfile profile,
  ) async {
    calls++;
    return bytes;
  }
}

final class FailingCloudSpeechSynthesizer implements CloudSpeechSynthesizer {
  @override
  Future<Uint8List> synthesize(
    SpeechSegment segment,
    VoiceProfile profile,
  ) async {
    throw StateError('network unavailable');
  }
}

const testSegment = SpeechSegment(
  id: '1:0',
  paragraphId: 1,
  text: '正文',
  partIndex: 0,
);

final testProfile = VoiceProfile.cloud(
  baseUrl: 'https://example.com',
  model: 'tts-model',
  voice: 'voice-a',
  speed: 1,
  outputFormat: 'mp3',
);

final validMp3Bytes = Uint8List.fromList([
  0x49,
  0x44,
  0x33,
  0x04,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
]);

final validWavBytes = Uint8List.fromList([
  0x52,
  0x49,
  0x46,
  0x46,
  0x04,
  0x00,
  0x00,
  0x00,
  0x57,
  0x41,
  0x56,
  0x45,
]);
