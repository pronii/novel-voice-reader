import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/speech/data/cached_audio_speech_provider.dart';
import 'package:novel_voice_reader/features/speech/data/cloud_tts_client.dart';
import 'package:novel_voice_reader/features/speech/data/mimo_tts_client.dart';
import 'package:novel_voice_reader/features/speech/data/server_tts_client.dart';
import 'package:novel_voice_reader/features/speech/data/speech_provider_factory.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  Future<Directory> createTempCacheDirectory() async {
    final directory = await Directory.systemTemp.createTemp(
      'provider-factory-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    return directory;
  }

  SpeechProviderFactory buildFactory(Directory directory) {
    return SpeechProviderFactory(
      dio: Dio(),
      credentials: SecureCredentials(EmptySecureStore()),
      cacheDirectory: directory,
      audioEngineFactory: FakeAudioPlaybackEngine.new,
    );
  }

  test('creates cached cloud playback for a cloud profile', () async {
    final directory = await createTempCacheDirectory();
    final factory = buildFactory(directory);

    final provider = factory.create(
      VoiceProfile.cloud(
        baseUrl: 'https://api.example.com',
        model: 'tts-1',
        voice: 'alloy',
        speed: 1,
        outputFormat: 'mp3',
      ),
    );

    expect(provider, isA<CachedAudioSpeechProvider>());
    final cached = provider as CachedAudioSpeechProvider;
    expect(
      (cached.cache as AudioCacheRepository).synthesizer,
      isA<CloudTtsClient>(),
    );
    await cached.dispose();
  });

  test('creates cached MiMo playback for a MiMo profile', () async {
    final directory = await createTempCacheDirectory();
    final factory = buildFactory(directory);

    final provider = factory.create(VoiceProfile.mimo());

    expect(provider, isA<CachedAudioSpeechProvider>());
    final cached = provider as CachedAudioSpeechProvider;
    expect(
      (cached.cache as AudioCacheRepository).synthesizer,
      isA<MiMoTtsClient>(),
    );
    await cached.dispose();
  });

  test('creates cached server playback for a server profile', () async {
    final directory = await createTempCacheDirectory();
    final factory = buildFactory(directory);

    final provider = factory.create(
      VoiceProfile.server(
        baseUrl: 'https://tts.example.com',
        model: 'tts-1',
        voice: 'alloy',
        speed: 1,
      ),
    );

    final cached = provider as CachedAudioSpeechProvider;
    expect(
      (cached.cache as AudioCacheRepository).synthesizer,
      isA<ServerTtsClient>(),
    );
    await cached.dispose();
  });

  test(
    'uses a shared cache without requiring another network client',
    () async {
      final directory = await createTempCacheDirectory();
      final sharedCache = FakeSpeechAudioCache();
      final factory = SpeechProviderFactory(
        cacheDirectory: directory,
        audioCache: sharedCache,
        audioEngineFactory: FakeAudioPlaybackEngine.new,
      );

      final provider =
          factory.create(
                VoiceProfile.cloud(
                  baseUrl: 'https://api.example.com',
                  model: 'tts-1',
                  voice: 'alloy',
                  speed: 1,
                  outputFormat: 'mp3',
                ),
              )
              as CachedAudioSpeechProvider;

      expect(provider.cache, same(sharedCache));
      await provider.dispose();
    },
  );
}

final class FakeSpeechAudioCache implements SpeechAudioCache {
  @override
  Future<File> obtain(SpeechSegment segment, VoiceProfile profile) {
    throw UnimplementedError();
  }
}

final class EmptySecureStore implements SecureKeyValueStore {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}

final class FakeAudioPlaybackEngine implements AudioPlaybackEngine {
  @override
  Stream<String> get completed => const Stream.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> setFilePath(String path) async {}

  @override
  Future<void> stop() async {}
}
