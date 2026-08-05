import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/speech/data/azure_tts_client.dart';
import 'package:novel_voice_reader/features/speech/data/cached_audio_speech_provider.dart';
import 'package:novel_voice_reader/features/speech/data/mimo_tts_client.dart';
import 'package:novel_voice_reader/features/speech/data/speech_provider_factory.dart';
import 'package:novel_voice_reader/features/speech/data/tencent_tts_client.dart';
import 'package:novel_voice_reader/features/speech/data/tencent_tts_usage_repository.dart';
import 'package:novel_voice_reader/features/speech/data/zhipu_tts_client.dart';
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
      tencentUsageCounter: FakeTencentUsageCounter(),
      audioEngineFactory: FakeAudioPlaybackEngine.new,
    );

    final provider = factory.create(VoiceProfile.azure(region: 'eastasia'));

    expect(provider, isA<CachedAudioSpeechProvider>());
    final cached = provider as CachedAudioSpeechProvider;
    expect(cached.cache.synthesizer, isA<AzureTtsClient>());
    await cached.dispose();
  });

  test('creates cached Zhipu playback for a Zhipu profile', () async {
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
      tencentUsageCounter: FakeTencentUsageCounter(),
      audioEngineFactory: FakeAudioPlaybackEngine.new,
    );

    final provider = factory.create(VoiceProfile.zhipu());

    expect(provider, isA<CachedAudioSpeechProvider>());
    final cached = provider as CachedAudioSpeechProvider;
    expect(cached.cache.synthesizer, isA<ZhipuTtsClient>());
    await cached.dispose();
  });

  test('creates cached Tencent playback for a Tencent profile', () async {
    final directory = await Directory.systemTemp.createTemp(
      'provider-factory-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final usageCounter = FakeTencentUsageCounter();
    final factory = SpeechProviderFactory(
      dio: Dio(),
      credentials: SecureCredentials(EmptySecureStore()),
      cacheDirectory: directory,
      tencentUsageCounter: usageCounter,
      audioEngineFactory: FakeAudioPlaybackEngine.new,
    );

    final provider = factory.create(VoiceProfile.tencent());

    expect(provider, isA<CachedAudioSpeechProvider>());
    final cached = provider as CachedAudioSpeechProvider;
    expect(cached.cache.synthesizer, isA<TencentTtsClient>());
    expect(
      (cached.cache.synthesizer as TencentTtsClient).usageCounter,
      same(usageCounter),
    );
    await cached.dispose();
  });

  test('creates cached MiMo playback for a MiMo profile', () async {
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
      tencentUsageCounter: FakeTencentUsageCounter(),
      audioEngineFactory: FakeAudioPlaybackEngine.new,
    );

    final provider = factory.create(VoiceProfile.mimo());

    expect(provider, isA<CachedAudioSpeechProvider>());
    final cached = provider as CachedAudioSpeechProvider;
    expect(cached.cache.synthesizer, isA<MiMoTtsClient>());
    await cached.dispose();
  });
}

final class FakeTencentUsageCounter implements TencentTtsUsageCounter {
  @override
  Future<void> addSuccessfulCharacters(int count) async {}
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
