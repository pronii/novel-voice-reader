import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_text_normalizer.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

typedef MiMoTtsDelay = Future<void> Function(Duration duration);

final class MiMoTtsClient implements CloudSpeechSynthesizer {
  MiMoTtsClient({
    required this.dio,
    required this.credentials,
    int maxAttempts = 3,
    MiMoTtsDelay? delay,
  }) : assert(maxAttempts > 0),
       _maxAttempts = maxAttempts,
       _delay = delay ?? Future<void>.delayed;

  static const defaultNarrationStyle =
      '使用自然、沉稳、清晰的小说旁白语气朗读，根据正文情绪自然调整语速、停顿和语气，不要过度夸张。'
      '正文处理规则：'
      '1) 语气词（啊、呀、哦、嗯、唉、哎）和拟声词（轰、砰、咚、啪、嗖、嘶、咻、哧、鸣、呜）一律用平稳、克制的叙述语气带过，不要夸张演绎、拉长音或模拟音效；'
      '2) 叠字描写（如嗖嗖嗖、啊啊啊、哈哈哈、砰砰砰）按字逐个平稳读出，音长一致，禁止拟声化或拉长；'
      '3) 破折号"——"代表正常停顿（约 0.3 至 0.5 秒），不要发出任何音；'
      '4) 遇到长串标点或重复符号按自然停顿处理，不要发出异常噪音或拟声音效。';

  final Dio dio;
  final SecureCredentials credentials;
  final int _maxAttempts;
  final MiMoTtsDelay _delay;

  @override
  Future<Uint8List> synthesize(
    SpeechSegment segment,
    VoiceProfile profile,
  ) async {
    _validateProfile(profile);
    final apiKey = (await credentials.readMiMoApiKey())?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AppFailure('尚未配置 MiMo API Key');
    }

    return _requestWithRetry(segment, profile, apiKey);
  }

  Future<void> testConnection({
    required String apiKey,
    required VoiceProfile profile,
  }) async {
    _validateProfile(profile);
    final normalizedKey = apiKey.trim();
    if (normalizedKey.isEmpty) {
      throw const AppFailure('请输入 MiMo API Key');
    }
    await _requestWithRetry(
      const SpeechSegment(
        id: 'mimo-connection-test',
        paragraphId: -1,
        text: '测试',
        partIndex: 0,
      ),
      profile,
      normalizedKey,
    );
  }

  Future<Uint8List> _requestWithRetry(
    SpeechSegment segment,
    VoiceProfile profile,
    String apiKey,
  ) async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        return await _request(segment, profile, apiKey);
      } on DioException catch (error) {
        if (attempt < _maxAttempts && _isRetriable(error)) {
          await _delay(Duration(milliseconds: 500 * (1 << (attempt - 1))));
          continue;
        }
        throw _failureFor(error);
      }
    }

    throw const AppFailure('MiMo 语音服务请求失败');
  }

  Future<Uint8List> _request(
    SpeechSegment segment,
    VoiceProfile profile,
    String apiKey,
  ) async {
    final response = await dio.post<Map<String, dynamic>>(
      '${profile.normalizedBaseUrl}/v1/chat/completions',
      data: {
        'model': profile.model,
        'messages': [
          {'role': 'user', 'content': profile.style ?? defaultNarrationStyle},
          {
            'role': 'assistant',
            'content': const SpeechTextNormalizer().normalizeForTts(segment.text),
          },
        ],
        'audio': {'format': profile.outputFormat, 'voice': profile.voice},
      },
      options: Options(headers: {'api-key': apiKey}),
    );
    return _decodeWave(response.data);
  }

  static Uint8List _decodeWave(Map<String, dynamic>? response) {
    try {
      final choices = response?['choices'] as List<dynamic>;
      final choice = choices.first as Map<String, dynamic>;
      final message = choice['message'] as Map<String, dynamic>;
      final audio = message['audio'] as Map<String, dynamic>;
      final data = audio['data'] as String;
      final bytes = base64Decode(data);
      if (!_isWave(bytes)) {
        throw const FormatException('Not a WAV file');
      }
      return bytes;
    } on Object {
      throw const AppFailure('MiMo 语音服务返回了无效音频');
    }
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

  static void _validateProfile(VoiceProfile profile) {
    if (profile.providerType != SpeechProviderType.mimo) {
      throw ArgumentError.value(profile.providerType, 'profile');
    }
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
      return const AppFailure('MiMo 语音服务认证失败');
    }
    if (statusCode == 429) {
      return const AppFailure('MiMo 语音服务请求过于频繁');
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const AppFailure('MiMo 语音服务连接超时');
    }
    if (error.type == DioExceptionType.connectionError) {
      return const AppFailure('无法连接 MiMo 语音服务');
    }
    if (statusCode != null) {
      return AppFailure('MiMo 语音服务请求失败（HTTP $statusCode）');
    }
    return const AppFailure('MiMo 语音服务请求失败');
  }
}
