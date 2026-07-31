import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/speech/data/zhipu_tts_client.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test('posts the official Zhipu speech request with bearer auth', () async {
    final adapter = RecordingHttpClientAdapter(
      outcomes: [
        const HttpOutcome.success([1, 2, 3]),
      ],
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ZhipuTtsClient(
      dio: dio,
      credentials: SecureCredentials(FakeSecureStore('zhipu-secret')),
    );

    final bytes = await client.synthesize(testSegment, testProfile);

    expect(bytes, Uint8List.fromList([1, 2, 3]));
    expect(
      adapter.request?.path,
      'https://open.bigmodel.cn/api/paas/v4/audio/speech',
    );
    expect(adapter.request?.headers['Authorization'], 'Bearer zhipu-secret');
    expect(adapter.request?.data, {
      'model': 'glm-tts',
      'input': '正文',
      'voice': 'tongtong',
      'response_format': 'wav',
      'speed': 1.0,
    });
  });

  test('rejects a non-Zhipu voice profile', () async {
    final client = ZhipuTtsClient(
      dio: Dio(),
      credentials: SecureCredentials(FakeSecureStore('zhipu-secret')),
    );

    await expectLater(
      client.synthesize(
        testSegment,
        VoiceProfile.cloud(
          baseUrl: 'https://example.com',
          model: 'tts-model',
          voice: 'voice-a',
          speed: 1,
          outputFormat: 'mp3',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('requires a configured Zhipu API key', () async {
    final client = ZhipuTtsClient(
      dio: Dio(),
      credentials: SecureCredentials(FakeSecureStore(null)),
    );

    await expectLater(
      client.synthesize(testSegment, testProfile),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          '尚未配置智谱 API Key',
        ),
      ),
    );
  });

  test('rejects an empty successful response', () async {
    final adapter = RecordingHttpClientAdapter(
      outcomes: [const HttpOutcome.success([])],
    );
    final client = ZhipuTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeSecureStore('zhipu-secret')),
    );

    await expectLater(
      client.synthesize(testSegment, testProfile),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          '智谱语音服务返回了空音频',
        ),
      ),
    );
  });

  test('retries a rate-limited request and then succeeds', () async {
    final adapter = RecordingHttpClientAdapter(
      outcomes: [
        const HttpOutcome.status(429),
        const HttpOutcome.success([4, 5, 6]),
      ],
    );
    final client = ZhipuTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeSecureStore('zhipu-secret')),
      delay: (_) async {},
    );

    final bytes = await client.synthesize(testSegment, testProfile);

    expect(bytes, [4, 5, 6]);
    expect(adapter.calls, 2);
  });

  test('does not retry unauthorized responses', () async {
    final adapter = RecordingHttpClientAdapter(
      outcomes: [const HttpOutcome.status(401)],
    );
    final client = ZhipuTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeSecureStore('zhipu-secret')),
      delay: (_) async {},
    );

    await expectLater(
      client.synthesize(testSegment, testProfile),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          '智谱语音服务认证失败',
        ),
      ),
    );
    expect(adapter.calls, 1);
  });

  test('retries timeouts and returns a sanitized failure', () async {
    final adapter = RecordingHttpClientAdapter(
      outcomes: const [
        HttpOutcome.timeout(),
        HttpOutcome.timeout(),
        HttpOutcome.timeout(),
      ],
    );
    final client = ZhipuTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeSecureStore('zhipu-secret')),
      delay: (_) async {},
    );

    await expectLater(
      client.synthesize(testSegment, testProfile),
      throwsA(
        isA<AppFailure>()
            .having((failure) => failure.message, 'message', '智谱语音服务连接超时')
            .having(
              (failure) => failure.message,
              'message',
              isNot(contains('zhipu-secret')),
            )
            .having(
              (failure) => failure.message,
              'message',
              isNot(contains(testSegment.text)),
            ),
      ),
    );
    expect(adapter.calls, 3);
  });
}

const testSegment = SpeechSegment(
  id: '1:0',
  paragraphId: 1,
  text: '正文',
  partIndex: 0,
);

final testProfile = VoiceProfile.zhipu();

final class FakeSecureStore implements SecureKeyValueStore {
  FakeSecureStore(this.apiKey);

  final String? apiKey;

  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => apiKey;

  @override
  Future<void> write(String key, String value) async {}
}

final class RecordingHttpClientAdapter implements HttpClientAdapter {
  RecordingHttpClientAdapter({required this.outcomes});

  final List<HttpOutcome> outcomes;
  RequestOptions? request;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    final outcome = outcomes[calls.clamp(0, outcomes.length - 1)];
    calls++;
    if (outcome.timeout) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      );
    }
    return ResponseBody.fromBytes(
      outcome.bytes,
      outcome.statusCode,
      headers: {
        Headers.contentTypeHeader: ['audio/wav'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class HttpOutcome {
  const HttpOutcome.success(this.bytes) : statusCode = 200, timeout = false;

  const HttpOutcome.status(this.statusCode) : bytes = const [], timeout = false;

  const HttpOutcome.timeout()
    : bytes = const [],
      statusCode = 0,
      timeout = true;

  final List<int> bytes;
  final int statusCode;
  final bool timeout;
}
