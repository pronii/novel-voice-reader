import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_text_normalizer.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

typedef CloudTtsDelay = Future<void> Function(Duration duration);

final class CloudTtsClient implements CloudSpeechSynthesizer {
  CloudTtsClient({
    required this.dio,
    required this.credentials,
    int maxAttempts = 3,
    CloudTtsDelay? delay,
  }) : assert(maxAttempts > 0),
       _maxAttempts = maxAttempts,
       _delay = delay ?? Future<void>.delayed;

  final Dio dio;
  final SecureCredentials credentials;
  final int _maxAttempts;
  final CloudTtsDelay _delay;

  @override
  Future<Uint8List> synthesize(
    SpeechSegment segment,
    VoiceProfile profile,
  ) async {
    final apiKey = await credentials.readApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AppFailure('尚未配置云端语音 API Key');
    }

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final baseUrl = profile.normalizedBaseUrl;
        final endpoint = baseUrl.endsWith('/v1')
            ? '$baseUrl/audio/speech'
            : '$baseUrl/v1/audio/speech';
        final response = await dio.post<List<int>>(
          endpoint,
          data: {
            'model': profile.model,
            'voice': profile.voice,
            'input': const SpeechTextNormalizer().normalizeForTts(segment.text),
            'response_format': profile.outputFormat,
            'speed': profile.speed,
          },
          options: Options(
            responseType: ResponseType.bytes,
            headers: {'Authorization': 'Bearer $apiKey'},
          ),
        );
        return Uint8List.fromList(response.data ?? const []);
      } on DioException catch (error) {
        if (attempt < _maxAttempts && _isRetriable(error)) {
          await _delay(Duration(milliseconds: 250 * (1 << (attempt - 1))));
          continue;
        }
        throw _toFailure(error);
      }
    }

    throw const AppFailure('云端语音服务请求失败');
  }

  static bool _isRetriable(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 429 || (statusCode != null && statusCode >= 500)) {
      return true;
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      _ => false,
    };
  }

  static AppFailure _toFailure(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      return const AppFailure('云端语音服务认证失败');
    }
    if (statusCode == 429) {
      return const AppFailure('云端语音服务请求过于频繁');
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const AppFailure('云端语音服务连接超时');
    }
    if (error.type == DioExceptionType.connectionError) {
      return const AppFailure('无法连接云端语音服务');
    }
    if (statusCode != null) {
      return AppFailure('云端语音服务请求失败（HTTP $statusCode）');
    }
    return const AppFailure('云端语音服务请求失败');
  }
}
