import 'dart:io';

import 'package:dio/dio.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/speech/data/cached_audio_speech_provider.dart';
import 'package:novel_voice_reader/features/speech/data/cloud_tts_client.dart';
import 'package:novel_voice_reader/features/speech/data/mimo_tts_client.dart';
import 'package:novel_voice_reader/features/speech/data/server_tts_client.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

final class SpeechProviderFactory {
  SpeechProviderFactory({
    this.dio,
    this.credentials,
    required this.cacheDirectory,
    this.audioCache,
    AudioPlaybackEngine Function()? audioEngineFactory,
  }) : audioEngineFactory = audioEngineFactory ?? JustAudioPlaybackEngine.new;

  final Dio? dio;
  final SecureCredentials? credentials;
  final Directory cacheDirectory;
  final SpeechAudioCache? audioCache;
  final AudioPlaybackEngine Function() audioEngineFactory;

  SpeechProvider create(VoiceProfile profile) {
    return switch (profile.providerType) {
      SpeechProviderType.cloud => _cached(
        () => CloudTtsClient(
          dio: _requiredDio,
          credentials: _requiredCredentials,
        ),
      ),
      SpeechProviderType.server => _cached(
        () => ServerTtsClient(
          dio: _requiredDio,
          credentials: _requiredCredentials,
        ),
      ),
      SpeechProviderType.mimo => _cached(
        () =>
            MiMoTtsClient(dio: _requiredDio, credentials: _requiredCredentials),
      ),
    };
  }

  Dio get _requiredDio =>
      dio ?? (throw StateError('A Dio client is required for cloud speech.'));

  SecureCredentials get _requiredCredentials =>
      credentials ??
      (throw StateError('Secure credentials are required for cloud speech.'));

  CachedAudioSpeechProvider _cached(
    CloudSpeechSynthesizer Function() createSynthesizer,
  ) {
    return CachedAudioSpeechProvider(
      cache:
          audioCache ??
          AudioCacheRepository(
            directory: cacheDirectory,
            synthesizer: createSynthesizer(),
          ),
      engine: audioEngineFactory(),
    );
  }
}
