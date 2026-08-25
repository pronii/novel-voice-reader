import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/diagnostics/domain/playback_telemetry.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_text_normalizer.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

typedef ServerTtsDelay = Future<void> Function(Duration duration);

final class ServerTtsClient implements CloudSpeechSynthesizer {
  ServerTtsClient({
    required this.dio,
    required this.credentials,
    ServerTtsDelay? delay,
    this.pollIntervals = const [
      Duration(milliseconds: 150),
      Duration(milliseconds: 250),
      Duration(milliseconds: 500),
    ],
    this.maxPolls = 360,
    this.telemetry = const NoopPlaybackTelemetry(),
  }) : assert(maxPolls > 0),
       assert(pollIntervals.isNotEmpty),
       assert(pollIntervals.every((interval) => interval > Duration.zero)),
       _delay = delay ?? Future<void>.delayed;

  final Dio dio;
  final SecureCredentials credentials;
  final List<Duration> pollIntervals;
  final int maxPolls;
  final PlaybackTelemetry telemetry;
  final ServerTtsDelay _delay;

  Duration _pollDelay(int poll) {
    final index = poll < pollIntervals.length ? poll : pollIntervals.length - 1;
    return pollIntervals[index];
  }

  @override
  Future<Uint8List> synthesize(
    SpeechSegment segment,
    VoiceProfile profile,
  ) async {
    // The self-hosted server can hold the upstream key itself, so a local key
    // is optional: send Authorization only when the user configured one, and
    // otherwise let the server fall back to its stored key.
    final apiKey = (await credentials.readMiMoApiKey())?.trim();
    final baseUrl = profile.normalizedBaseUrl;
    try {
      final created = await dio.post<Map<String, dynamic>>(
        '$baseUrl/v1/jobs',
        data: {
          'text': const SpeechTextNormalizer().normalizeForTts(segment.text),
          'max_characters': profile.maxSegmentCharacters,
          'model': profile.model,
          'voice': profile.voice,
          'format': profile.outputFormat,
          'speed': profile.speed,
        },
        options: (apiKey != null && apiKey.isNotEmpty)
            ? Options(headers: {'Authorization': 'Bearer $apiKey'})
            : null,
      );
      final jobId = created.data?['id'] as String?;
      if (jobId == null || jobId.isEmpty) {
        throw const AppFailure('自建语音服务返回了无效任务');
      }
      final readyTimer = Stopwatch()..start();
      for (var poll = 0; poll < maxPolls; poll++) {
        final status = await dio.get<Map<String, dynamic>>(
          '$baseUrl/v1/jobs/$jobId',
        );
        final data = status.data;
        final state = data?['status'] as String?;
        if (state == 'completed') {
          recordPlaybackTelemetrySafely(
            telemetry,
            'speech.server.job.ready',
            {
              'elapsed_ms': readyTimer.elapsedMilliseconds,
              'poll_count': poll + 1,
            },
          );
          final response = await dio.get<List<int>>(
            '$baseUrl/v1/jobs/$jobId/segments/0',
            options: Options(responseType: ResponseType.bytes),
          );
          return Uint8List.fromList(response.data ?? const []);
        }
        if (state == 'failed') {
          final reason = data?['error'] as String?;
          throw AppFailure(_failureMessage(reason));
        }
        await _delay(_pollDelay(poll));
      }
      throw const AppFailure('自建语音服务合成超时');
    } on DioException catch (error) {
      throw _toFailure(error);
    }
  }

  Future<void> testConnection(String baseUrl) async {
    try {
      await dio.get<Map<String, dynamic>>('$baseUrl/healthz');
    } on DioException catch (error) {
      throw _toFailure(error);
    }
  }

  static AppFailure _toFailure(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return const AppFailure('自建语音服务认证失败');
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const AppFailure('自建语音服务连接超时');
    }
    if (error.type == DioExceptionType.connectionError) {
      return const AppFailure('无法连接自建语音服务');
    }
    if (status != null) {
      return AppFailure('自建语音服务请求失败（HTTP $status）');
    }
    return const AppFailure('自建语音服务请求失败');
  }

  static String _failureMessage(String? reason) {
    switch (reason) {
      case 'upstream authentication failed':
        return '自建语音服务的 MiMo API Key 无效或已过期，请重新配置';
      case 'upstream rate limited the request':
        return 'MiMo 语音服务请求过于频繁，请稍后重试';
      case final value
          when value != null && value.startsWith('upstream server error'):
        return 'MiMo 语音服务暂时不可用，请稍后重试';
      default:
        return '自建语音服务合成失败';
    }
  }
}
