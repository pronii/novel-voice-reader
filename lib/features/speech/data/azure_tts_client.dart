import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

final class AzureTtsClient implements CloudSpeechSynthesizer {
  const AzureTtsClient({required this.dio, required this.credentials});

  final Dio dio;
  final SecureCredentials credentials;

  @override
  Future<Uint8List> synthesize(
    SpeechSegment segment,
    VoiceProfile profile,
  ) async {
    if (profile.providerType != SpeechProviderType.azure) {
      throw ArgumentError.value(profile.providerType, 'profile');
    }
    final subscriptionKey = await credentials.readAzureSubscriptionKey();
    if (subscriptionKey == null || subscriptionKey.trim().isEmpty) {
      throw const AppFailure('尚未配置 Azure Speech Subscription Key');
    }
    final voice = profile.voice;
    if (voice == null || voice.isEmpty) {
      throw const AppFailure('尚未配置 Azure Speech 音色');
    }

    try {
      final response = await dio.post<List<int>>(
        '${profile.normalizedBaseUrl}/cognitiveservices/v1',
        data: _ssml(segment.text, voice, profile.speed),
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Ocp-Apim-Subscription-Key': subscriptionKey,
            'Content-Type': 'application/ssml+xml',
            'X-Microsoft-OutputFormat':
                profile.outputFormat ?? VoiceProfile.defaultAzureOutputFormat,
            'User-Agent': 'NovelVoiceReader',
          },
        ),
      );
      final bytes = Uint8List.fromList(response.data ?? const []);
      if (bytes.isEmpty) {
        throw const AppFailure('Azure Speech 返回了空音频');
      }
      return bytes;
    } on DioException catch (error) {
      throw _failureFor(error);
    }
  }

  static String _ssml(String text, String voice, double speed) {
    final language = voice.split('-').take(2).join('-');
    final ratePercent = ((speed - 1) * 100).round();
    return '<speak version="1.0" '
        'xmlns="http://www.w3.org/2001/10/synthesis" '
        'xml:lang="${_escapeXml(language)}">'
        '<voice name="${_escapeXml(voice)}">'
        '<prosody rate="$ratePercent%">${_escapeXml(text)}</prosody>'
        '</voice></speak>';
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static AppFailure _failureFor(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      return const AppFailure('Azure Speech 认证失败，请检查 Region 和 Key');
    }
    if (statusCode == 429) {
      return const AppFailure('Azure Speech 请求过于频繁');
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const AppFailure('Azure Speech 连接超时');
    }
    if (error.type == DioExceptionType.connectionError) {
      return const AppFailure('无法连接 Azure Speech');
    }
    if (statusCode != null) {
      return AppFailure('Azure Speech 请求失败（HTTP $statusCode）');
    }
    return const AppFailure('Azure Speech 请求失败');
  }
}
