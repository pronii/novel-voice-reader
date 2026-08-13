import 'dart:io';

import 'package:dio/dio.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/speech/data/cached_audio_speech_provider.dart';
import 'package:novel_voice_reader/features/speech/data/cloud_tts_client.dart';
import 'package:novel_voice_reader/features/speech/data/mimo_tts_client.dart';
import 'package:novel_voice_reader/features/speech/data/system_tts_adapter.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

final class SpeechProviderFactory {
  SpeechProviderFactory({
    required this.dio,
    required this.credentials,
    required this.cacheDirectory,
    SystemTtsEngine Function()? systemEngineFactory,
    AudioPlaybackEngine Function()? audioEngineFactory,
  }) : systemEngineFactory = systemEngineFactory ?? FlutterSystemTtsEngine.new,
       audioEngineFactory = audioEngineFactory ?? JustAudioPlaybackEngine.new;

  final Dio dio;
  final SecureCredentials credentials;
  final Directory cacheDirectory;
  final SystemTtsEngine Function() systemEngineFactory;
  final AudioPlaybackEngine Function() audioEngineFactory;

  SpeechProvider create(VoiceProfile profile) {
    return switch (profile.providerType) {
      SpeechProviderType.system => SystemTtsAdapter(systemEngineFactory()),
      SpeechProviderType.cloud => _cached(
        CloudTtsClient(dio: dio, credentials: credentials),
      ),
      SpeechProviderType.mimo => _cached(
        MiMoTtsClient(dio: dio, credentials: credentials),
      ),
    };
  }

  CachedAudioSpeechProvider _cached(CloudSpeechSynthesizer synthesizer) {
    return CachedAudioSpeechProvider(
      cache: AudioCacheRepository(
        directory: cacheDirectory,
        synthesizer: synthesizer,
      ),
      engine: audioEngineFactory(),
    );
  }
}
