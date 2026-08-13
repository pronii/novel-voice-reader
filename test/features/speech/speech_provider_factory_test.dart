import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/speech/data/cached_audio_speech_provider.dart';
import 'package:novel_voice_reader/features/speech/data/cloud_tts_client.dart';
import 'package:novel_voice_reader/features/speech/data/mimo_tts_client.dart';
import 'package:novel_voice_reader/features/speech/data/speech_provider_factory.dart';
import 'package:novel_voice_reader/features/speech/data/system_tts_adapter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  Future<Directory> createTempCacheDirectory() async {
    final directory = await Directory.systemTemp.createTemp('provider-factory-');
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
      systemEngineFactory: FakeSystemTtsEngine.new,
      audioEngineFactory: FakeAudioPlaybackEngine.new,
    );
  }

  test('creates a system adapter for a system profile', () async {
    final directory = await createTempCacheDirectory();
    final factory = buildFactory(directory);

    final provider = factory.create(VoiceProfile.system());

    expect(provider, isA<SystemTtsAdapter>());
    await (provider as SystemTtsAdapter).dispose();
  });

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
    expect(cached.cache.synthesizer, isA<CloudTtsClient>());
    await cached.dispose();
  });

  test('creates cached MiMo playback for a MiMo profile', () async {
    final directory = await createTempCacheDirectory();
    final factory = buildFactory(directory);

    final provider = factory.create(VoiceProfile.mimo());

    expect(provider, isA<CachedAudioSpeechProvider>());
    final cached = provider as CachedAudioSpeechProvider;
    expect(cached.cache.synthesizer, isA<MiMoTtsClient>());
    await cached.dispose();
  });
}

final class EmptySecureStore implements SecureKeyValueStore {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}

final class FakeSystemTtsEngine implements SystemTtsEngine {
  @override
  Future<void> configure(VoiceProfile profile) async {}

  @override
  Future<void> pause() async {}

  @override
  void setCompletionHandler(void Function() handler) {}

  @override
  void setErrorHandler(void Function(Object error) handler) {}

  @override
  void setStartHandler(void Function() handler) {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
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
