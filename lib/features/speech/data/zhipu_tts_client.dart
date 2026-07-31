import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

typedef ZhipuTtsDelay = Future<void> Function(Duration duration);

final class ZhipuTtsClient implements CloudSpeechSynthesizer {
  ZhipuTtsClient({
    required this.dio,
    required this.credentials,
    int maxAttempts = 3,
    ZhipuTtsDelay? delay,
  }) : assert(maxAttempts > 0),
       _maxAttempts = maxAttempts,
       _delay = delay ?? Future<void>.delayed;

  final Dio dio;
  final SecureCredentials credentials;
  final int _maxAttempts;
  final ZhipuTtsDelay _delay;

  @override
  Future<Uint8List> synthesize(
    SpeechSegment segment,
    VoiceProfile profile,
  ) async {
    if (profile.providerType != SpeechProviderType.zhipu) {
      throw ArgumentError.value(profile.providerType, 'profile');
    }
    final apiKey = await credentials.readZhipuApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AppFailure('尚未配置智谱 API Key');
    }

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final response = await dio.post<List<int>>(
          '${profile.normalizedBaseUrl}/audio/speech',
          data: {
            'model': profile.model,
            'input': segment.text,
            'voice': profile.voice,
            'response_format': profile.outputFormat,
            'speed': profile.speed,
          },
          options: Options(
            responseType: ResponseType.bytes,
            headers: {'Authorization': 'Bearer $apiKey'},
          ),
        );
        final bytes = Uint8List.fromList(response.data ?? const []);
        if (bytes.isEmpty) {
          throw const AppFailure('智谱语音服务返回了空音频');
        }
        return bytes;
      } on DioException catch (error) {
        if (attempt < _maxAttempts && _isRetriable(error)) {
          await _delay(Duration(milliseconds: 250 * (1 << (attempt - 1))));
          continue;
        }
        throw _failureFor(error);
      }
    }

    throw const AppFailure('智谱语音服务请求失败');
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

  static AppFailure _failureFor(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      return const AppFailure('智谱语音服务认证失败');
    }
    if (statusCode == 429) {
      return const AppFailure('智谱语音服务请求过于频繁');
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const AppFailure('智谱语音服务连接超时');
    }
    if (error.type == DioExceptionType.connectionError) {
      return const AppFailure('无法连接智谱语音服务');
    }
    if (statusCode != null) {
      return AppFailure('智谱语音服务请求失败（HTTP $statusCode）');
    }
    return const AppFailure('智谱语音服务请求失败');
  }
}
