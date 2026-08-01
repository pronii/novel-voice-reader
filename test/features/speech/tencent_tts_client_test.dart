import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/speech/data/tencent_tts_client.dart';
import 'package:novel_voice_reader/features/speech/data/tencent_tts_usage_repository.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_credentials_input.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test('posts a signed TextToVoice request and counts Unicode text', () async {
    final adapter = TencentRecordingAdapter.success();
    final usage = FakeUsageCounter();
    final client = TencentTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(
        FakeTencentSecureStore(secretId: 'stored-id', secretKey: 'stored-key'),
      ),
      usageCounter: usage,
      now: () => DateTime.utc(2024, 8, 1),
      sessionId: () => 'session-1',
    );
    const segment = SpeechSegment(
      id: '1:0',
      paragraphId: 1,
      text: '正文𠮷',
      partIndex: 0,
    );
    final profile = VoiceProfile.tencent(voiceType: 1001, speed: 1.2);

    final bytes = await client.synthesize(segment, profile);

    expect(bytes, validMp3Bytes);
    expect(adapter.request?.path, 'https://tts.tencentcloudapi.com');
    expect(adapter.request?.method, 'POST');
    expect(adapter.request?.headers['Host'], 'tts.tencentcloudapi.com');
    expect(adapter.request?.headers['X-TC-Action'], 'TextToVoice');
    expect(adapter.request?.headers['X-TC-Version'], '2019-08-23');
    expect(adapter.request?.headers['X-TC-Timestamp'], '1722470400');
    expect(
      adapter.request?.headers['Authorization'],
      startsWith('TC3-HMAC-SHA256 Credential=stored-id/'),
    );
    expect(jsonDecode(adapter.request?.data as String), {
      'Text': '正文𠮷',
      'SessionId': 'session-1',
      'VoiceType': 1001,
      'ModelType': 1,
      'PrimaryLanguage': 1,
      'SampleRate': 16000,
      'Codec': 'mp3',
      'Speed': 1.0,
      'Volume': 0,
    });
    expect(usage.counts, [3]);
  });

  test('requires both stored Tencent credentials', () async {
    final client = TencentTtsClient(
      dio: Dio(),
      credentials: SecureCredentials(
        FakeTencentSecureStore(secretId: 'stored-id', secretKey: null),
      ),
      usageCounter: FakeUsageCounter(),
    );

    await expectLater(
      client.synthesize(testSegment, VoiceProfile.tencent()),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          '尚未配置腾讯云 SecretId 和 SecretKey',
        ),
      ),
    );
  });

  test('tests entered credentials without saving or caching audio', () async {
    final adapter = TencentRecordingAdapter.success();
    final usage = FakeUsageCounter();
    final client = TencentTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(
        FakeTencentSecureStore(secretId: 'stored-id', secretKey: 'stored-key'),
      ),
      usageCounter: usage,
      sessionId: () => 'connection-test',
    );

    await client.testConnection(
      credentials: const SpeechCredentialsInput(
        secretId: ' entered-id ',
        secretKey: ' entered-key ',
      ),
      profile: VoiceProfile.tencent(),
    );

    expect(
      adapter.request?.headers['Authorization'],
      startsWith('TC3-HMAC-SHA256 Credential=entered-id/'),
    );
    expect((jsonDecode(adapter.request?.data as String) as Map)['Text'], '测试');
    expect(usage.counts, [2]);
  });

  test('rejects incomplete entered connection credentials locally', () async {
    final adapter = TencentRecordingAdapter.success();
    final client = TencentTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(
        FakeTencentSecureStore(secretId: 'stored-id', secretKey: 'stored-key'),
      ),
      usageCounter: FakeUsageCounter(),
    );

    await expectLater(
      client.testConnection(
        credentials: const SpeechCredentialsInput(
          secretId: 'entered-id',
          secretKey: ' ',
        ),
        profile: VoiceProfile.tencent(),
      ),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          '请输入腾讯云 SecretId 和 SecretKey',
        ),
      ),
    );
    expect(adapter.calls, 0);
  });

  test(
    'maps Tencent response errors without exposing request secrets',
    () async {
      final cases = <String, String>{
        'AuthFailure.SignatureFailure': '腾讯云语音服务认证失败，请检查 SecretId 和 SecretKey',
        'UnauthorizedOperation': '腾讯云子账号没有语音合成权限',
        'InvalidParameter.VoiceType': '腾讯云音色不可用，请检查 VoiceType',
        'RequestLimitExceeded': '腾讯云语音服务请求过于频繁',
      };
      for (final entry in cases.entries) {
        final adapter = TencentRecordingAdapter.error(entry.key);
        final client = TencentTtsClient(
          dio: Dio()..httpClientAdapter = adapter,
          credentials: SecureCredentials(
            FakeTencentSecureStore(
              secretId: 'sensitive-id',
              secretKey: 'sensitive-key',
            ),
          ),
          usageCounter: FakeUsageCounter(),
        );

        await expectLater(
          client.synthesize(testSegment, VoiceProfile.tencent()),
          throwsA(
            isA<AppFailure>()
                .having((failure) => failure.message, 'message', entry.value)
                .having(
                  (failure) => failure.message,
                  'secret',
                  isNot(
                    anyOf(contains('sensitive-id'), contains('sensitive-key')),
                  ),
                )
                .having(
                  (failure) => failure.message,
                  'text',
                  isNot(contains(testSegment.text)),
                ),
          ),
        );
      }
    },
  );

  test('maps timeout and HTTP authentication failures', () async {
    final timeoutClient = _clientFor(TencentRecordingAdapter.timeout());
    await expectLater(
      timeoutClient.synthesize(testSegment, VoiceProfile.tencent()),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          '腾讯云语音服务连接超时',
        ),
      ),
    );

    final unauthorizedClient = _clientFor(
      TencentRecordingAdapter.httpStatus(403),
    );
    await expectLater(
      unauthorizedClient.synthesize(testSegment, VoiceProfile.tencent()),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          '腾讯云语音服务认证失败，请检查 SecretId 和 SecretKey',
        ),
      ),
    );
  });

  test(
    'rejects invalid Base64 and invalid MP3 without counting usage',
    () async {
      for (final adapter in [
        TencentRecordingAdapter.audio('%%%'),
        TencentRecordingAdapter.audio(base64Encode([1, 2, 3])),
      ]) {
        final usage = FakeUsageCounter();
        final client = _clientFor(adapter, usageCounter: usage);

        await expectLater(
          client.synthesize(testSegment, VoiceProfile.tencent()),
          throwsA(
            isA<AppFailure>().having(
              (failure) => failure.message,
              'message',
              '腾讯云语音服务返回了无效音频',
            ),
          ),
        );
        expect(usage.counts, isEmpty);
      }
    },
  );

  test('returns valid audio when local usage persistence fails', () async {
    final client = _clientFor(
      TencentRecordingAdapter.success(),
      usageCounter: ThrowingUsageCounter(),
    );

    final bytes = await client.synthesize(testSegment, VoiceProfile.tencent());

    expect(bytes, validMp3Bytes);
  });

  test('rejects a non-Tencent profile before sending a request', () async {
    final adapter = TencentRecordingAdapter.success();
    final client = _clientFor(adapter);

    await expectLater(
      client.synthesize(testSegment, VoiceProfile.system()),
      throwsArgumentError,
    );
    expect(adapter.calls, 0);
  });
}

TencentTtsClient _clientFor(
  TencentRecordingAdapter adapter, {
  TencentTtsUsageCounter? usageCounter,
}) {
  return TencentTtsClient(
    dio: Dio()..httpClientAdapter = adapter,
    credentials: SecureCredentials(
      FakeTencentSecureStore(secretId: 'stored-id', secretKey: 'stored-key'),
    ),
    usageCounter: usageCounter ?? FakeUsageCounter(),
    now: () => DateTime.utc(2024, 8, 1),
    sessionId: () => 'session-1',
  );
}

const testSegment = SpeechSegment(
  id: '1:0',
  paragraphId: 1,
  text: '正文',
  partIndex: 0,
);

const validMp3Bytes = <int>[0x49, 0x44, 0x33, 0x04];

final class FakeTencentSecureStore implements SecureKeyValueStore {
  FakeTencentSecureStore({required this.secretId, required this.secretKey});

  final String? secretId;
  final String? secretKey;

  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async {
    if (key == 'tencent_tts_secret_id') return secretId;
    if (key == 'tencent_tts_secret_key') return secretKey;
    return null;
  }

  @override
  Future<void> write(String key, String value) async {}
}

final class FakeUsageCounter implements TencentTtsUsageCounter {
  final List<int> counts = [];

  @override
  Future<void> addSuccessfulCharacters(int count) async {
    counts.add(count);
  }
}

final class ThrowingUsageCounter implements TencentTtsUsageCounter {
  @override
  Future<void> addSuccessfulCharacters(int count) async {
    throw StateError('local database unavailable');
  }
}

final class TencentRecordingAdapter implements HttpClientAdapter {
  TencentRecordingAdapter._(
    this.response, {
    this.timeout = false,
    this.statusCode = 200,
  });

  factory TencentRecordingAdapter.success() =>
      TencentRecordingAdapter.audio(base64Encode(validMp3Bytes));

  factory TencentRecordingAdapter.audio(String audio) {
    return TencentRecordingAdapter._({
      'Response': {'Audio': audio, 'RequestId': 'request-1'},
    });
  }

  factory TencentRecordingAdapter.error(String code) {
    return TencentRecordingAdapter._({
      'Response': {
        'Error': {'Code': code, 'Message': 'raw server details'},
        'RequestId': 'request-1',
      },
    });
  }

  factory TencentRecordingAdapter.httpStatus(int statusCode) {
    return TencentRecordingAdapter._(const {}, statusCode: statusCode);
  }

  factory TencentRecordingAdapter.timeout() {
    return TencentRecordingAdapter._(const {}, timeout: true);
  }

  final Map<String, Object?> response;
  final bool timeout;
  final int statusCode;
  RequestOptions? request;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    calls++;
    if (timeout) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      );
    }
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(response)),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
