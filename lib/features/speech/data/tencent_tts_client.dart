import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/speech/data/tencent_tc3_signer.dart';
import 'package:novel_voice_reader/features/speech/data/tencent_tts_usage_repository.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_credentials_input.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';
import 'package:uuid/uuid.dart';

typedef TencentTtsNow = DateTime Function();
typedef TencentTtsSessionId = String Function();

final class TencentSpeedMapper {
  const TencentSpeedMapper._();

  static double fromMultiplier(double multiplier) {
    const points = <(double, double)>[
      (0.6, -2),
      (0.8, -1),
      (1, 0),
      (1.2, 1),
      (1.5, 2),
    ];
    if (multiplier <= points.first.$1) return points.first.$2;
    if (multiplier >= points.last.$1) return points.last.$2;
    for (var index = 1; index < points.length; index++) {
      final upper = points[index];
      if (multiplier <= upper.$1) {
        final lower = points[index - 1];
        final ratio = (multiplier - lower.$1) / (upper.$1 - lower.$1);
        return lower.$2 + ratio * (upper.$2 - lower.$2);
      }
    }
    return 0;
  }
}

final class TencentTtsClient implements CloudSpeechSynthesizer {
  TencentTtsClient({
    required this.dio,
    required this.credentials,
    required this.usageCounter,
    this.signer = const TencentTc3Signer(),
    TencentTtsNow? now,
    TencentTtsSessionId? sessionId,
  }) : _now = now ?? DateTime.now,
       _sessionId = sessionId ?? _newSessionId;

  final Dio dio;
  final SecureCredentials credentials;
  final TencentTtsUsageCounter usageCounter;
  final TencentTc3Signer signer;
  final TencentTtsNow _now;
  final TencentTtsSessionId _sessionId;

  @override
  Future<Uint8List> synthesize(
    SpeechSegment segment,
    VoiceProfile profile,
  ) async {
    _validateProfile(profile);
    final secretId = (await credentials.readTencentSecretId())?.trim();
    final secretKey = (await credentials.readTencentSecretKey())?.trim();
    if (secretId == null ||
        secretId.isEmpty ||
        secretKey == null ||
        secretKey.isEmpty) {
      throw const AppFailure('尚未配置腾讯云 SecretId 和 SecretKey');
    }
    return _request(
      segment: segment,
      profile: profile,
      secretId: secretId,
      secretKey: secretKey,
    );
  }

  Future<void> testConnection({
    required SpeechCredentialsInput credentials,
    required VoiceProfile profile,
  }) async {
    _validateProfile(profile);
    final secretId = credentials.normalizedSecretId;
    final secretKey = credentials.normalizedSecretKey;
    if (secretId == null || secretKey == null) {
      throw const AppFailure('请输入腾讯云 SecretId 和 SecretKey');
    }
    await _request(
      segment: const SpeechSegment(
        id: 'tencent-connection-test',
        paragraphId: -1,
        text: '测试',
        partIndex: 0,
      ),
      profile: profile,
      secretId: secretId,
      secretKey: secretKey,
    );
  }

  Future<Uint8List> _request({
    required SpeechSegment segment,
    required VoiceProfile profile,
    required String secretId,
    required String secretKey,
  }) async {
    final voiceType = int.tryParse(profile.voice ?? '');
    if (voiceType == null || voiceType <= 0) {
      throw const AppFailure('腾讯云音色不可用，请检查 VoiceType');
    }
    final payload = jsonEncode({
      'Text': segment.text,
      'SessionId': _sessionId(),
      'VoiceType': voiceType,
      'ModelType': 1,
      'PrimaryLanguage': 1,
      'SampleRate': 16000,
      'Codec': 'mp3',
      'Speed': TencentSpeedMapper.fromMultiplier(profile.speed),
      'Volume': 0,
    });
    final signature = signer.sign(
      secretId: secretId,
      secretKey: secretKey,
      payload: payload,
      now: _now(),
    );

    try {
      final response = await dio.post<Map<String, dynamic>>(
        profile.normalizedBaseUrl,
        data: payload,
        options: Options(
          contentType: signature.contentType,
          headers: {
            'Authorization': signature.authorization,
            'Host': signature.host,
            'X-TC-Action': 'TextToVoice',
            'X-TC-Timestamp': signature.timestamp.toString(),
            'X-TC-Version': '2019-08-23',
          },
        ),
      );
      final envelope = response.data?['Response'];
      if (envelope is! Map) {
        throw const AppFailure('腾讯云语音服务返回了无效响应');
      }
      final requestId = envelope['RequestId']?.toString();
      final error = envelope['Error'];
      if (error is Map) {
        throw _failureForTencentCode(
          error['Code']?.toString(),
          requestId: requestId,
        );
      }
      final audio = envelope['Audio'];
      if (audio is! String || audio.isEmpty) {
        throw const AppFailure('腾讯云语音服务返回了无效音频');
      }
      late final Uint8List bytes;
      try {
        bytes = base64Decode(audio);
      } on FormatException {
        throw const AppFailure('腾讯云语音服务返回了无效音频');
      }
      if (!_isMp3(bytes)) {
        throw const AppFailure('腾讯云语音服务返回了无效音频');
      }
      try {
        await usageCounter.addSuccessfulCharacters(segment.text.runes.length);
      } catch (_) {
        // Audio remains usable even if the local estimate cannot be updated.
      }
      return bytes;
    } on DioException catch (error) {
      throw _failureForDio(error);
    }
  }

  static void _validateProfile(VoiceProfile profile) {
    if (profile.providerType != SpeechProviderType.tencent) {
      throw ArgumentError.value(profile.providerType, 'profile');
    }
  }

  static bool _isMp3(List<int> bytes) {
    final hasId3Header =
        bytes.length >= 3 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33;
    final hasFrameSync =
        bytes.length >= 2 && bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0;
    return hasId3Header || hasFrameSync;
  }

  static AppFailure _failureForTencentCode(String? code, {String? requestId}) {
    final normalized = code ?? '';
    if (normalized.startsWith('AuthFailure') ||
        normalized.contains('Signature')) {
      return const AppFailure('腾讯云语音服务认证失败，请检查 SecretId 和 SecretKey');
    }
    if (normalized.startsWith('UnauthorizedOperation')) {
      return const AppFailure('腾讯云子账号没有语音合成权限');
    }
    if (normalized.contains('VoiceType') ||
        normalized.startsWith('InvalidParameter')) {
      return const AppFailure('腾讯云音色不可用，请检查 VoiceType');
    }
    if (normalized.contains('RequestLimitExceeded') ||
        normalized.contains('LimitExceeded')) {
      return const AppFailure('腾讯云语音服务请求过于频繁');
    }
    final safeRequestId = _safeRequestId(requestId);
    return safeRequestId == null
        ? const AppFailure('腾讯云语音服务请求失败')
        : AppFailure('腾讯云语音服务请求失败（RequestId: $safeRequestId）');
  }

  static AppFailure _failureForDio(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      return const AppFailure('腾讯云语音服务认证失败，请检查 SecretId 和 SecretKey');
    }
    if (statusCode == 429) {
      return const AppFailure('腾讯云语音服务请求过于频繁');
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const AppFailure('腾讯云语音服务连接超时');
    }
    if (error.type == DioExceptionType.connectionError) {
      return const AppFailure('无法连接腾讯云语音服务');
    }
    if (statusCode != null && statusCode >= 500) {
      return const AppFailure('腾讯云语音服务暂时不可用');
    }
    return const AppFailure('腾讯云语音服务请求失败');
  }

  static String? _safeRequestId(String? value) {
    if (value == null || !RegExp(r'^[A-Za-z0-9-]{1,128}$').hasMatch(value)) {
      return null;
    }
    return value;
  }

  static String _newSessionId() => const Uuid().v4();
}
