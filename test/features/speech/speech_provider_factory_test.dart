import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/speech/data/azure_tts_client.dart';
import 'package:novel_voice_reader/features/speech/data/cached_audio_speech_provider.dart';
import 'package:novel_voice_reader/features/speech/data/speech_provider_factory.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test('creates cached Azure playback for an Azure profile', () async {
    final directory = await Directory.systemTemp.createTemp(
      'provider-factory-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final factory = SpeechProviderFactory(
      dio: Dio(),
      credentials: SecureCredentials(EmptySecureStore()),
      cacheDirectory: directory,
      audioEngineFactory: FakeAudioPlaybackEngine.new,
    );

    final provider = factory.create(VoiceProfile.azure(region: 'eastasia'));

    expect(provider, isA<CachedAudioSpeechProvider>());
    final cached = provider as CachedAudioSpeechProvider;
    expect(cached.cache.synthesizer, isA<AzureTtsClient>());
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

final class FakeAudioPlaybackEngine implements AudioPlaybackEngine {
  @override
  Stream<void> get completed => const Stream.empty();

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
