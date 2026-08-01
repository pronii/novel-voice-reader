import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

typedef ZhipuTtsDelay = Future<void> Function(Duration duration);
typedef ZhipuTtsNow = DateTime Function();

final class ZhipuTtsClient implements CloudSpeechSynthesizer {
  ZhipuTtsClient({
    required this.dio,
    required this.credentials,
    int maxAttempts = 5,
    ZhipuTtsDelay? delay,
    ZhipuTtsNow? now,
  }) : assert(maxAttempts > 0),
       _maxAttempts = maxAttempts,
       _delay = delay ?? Future<void>.delayed,
       _now = now ?? DateTime.now;

  final Dio dio;
  final SecureCredentials credentials;
  final int _maxAttempts;
  final ZhipuTtsDelay _delay;
  final ZhipuTtsNow _now;

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
        final bytes = await _request(segment, profile, apiKey);
        if (bytes.isEmpty) {
          throw const AppFailure('智谱语音服务返回了空音频');
        }
        return bytes;
      } on DioException catch (error) {
        if (attempt < _maxAttempts && _isRetriable(error)) {
          await _delay(_retryDelay(error, attempt));
          continue;
        }
        throw _failureFor(error);
      }
    }

    throw const AppFailure('智谱语音服务请求失败');
  }

  Future<void> testConnection({
    required String apiKey,
    required VoiceProfile profile,
  }) async {
    if (profile.providerType != SpeechProviderType.zhipu) {
      throw ArgumentError.value(profile.providerType, 'profile');
    }
    if (apiKey.trim().isEmpty) {
      throw const AppFailure('请输入智谱 API Key');
    }
    try {
      final bytes = await _request(
        const SpeechSegment(
          id: 'zhipu-connection-test',
          paragraphId: -1,
          text: '测试',
          partIndex: 0,
        ),
        profile,
        apiKey.trim(),
      );
      if (!_isWave(bytes)) {
        throw const AppFailure('智谱语音服务返回了无效音频');
      }
    } on DioException catch (error) {
      throw _failureFor(error);
    }
  }

  Future<Uint8List> _request(
    SpeechSegment segment,
    VoiceProfile profile,
    String apiKey,
  ) async {
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
    return Uint8List.fromList(response.data ?? const []);
  }

  static bool _isWave(List<int> bytes) {
    return bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x41 &&
        bytes[10] == 0x56 &&
        bytes[11] == 0x45;
  }

  Duration _retryDelay(DioException error, int attempt) {
    if (error.response?.statusCode == 429) {
      final header = error.response?.headers.value('retry-after');
      final seconds = int.tryParse(header ?? '');
      if (seconds != null && seconds >= 0) {
        return Duration(seconds: seconds.clamp(0, 60));
      }
      if (header != null && header.isNotEmpty) {
        try {
          final date = HttpDate.parse(header);
          final duration = date.difference(_now().toUtc());
          if (duration.isNegative) {
            return Duration.zero;
          }
          return duration > const Duration(seconds: 60)
              ? const Duration(seconds: 60)
              : duration;
        } on FormatException {
          // Fall back to exponential backoff for an invalid HTTP date.
        } on HttpException {
          // HttpDate.parse throws HttpException on current Dart SDKs.
        }
      }
    }
    return Duration(seconds: 1 << attempt);
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
