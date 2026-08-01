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

  test('uses bounded exponential delays when 429 has no Retry-After', () async {
    final delays = <Duration>[];
    final adapter = RecordingHttpClientAdapter(
      outcomes: const [
        HttpOutcome.status(429),
        HttpOutcome.status(429),
        HttpOutcome.status(429),
        HttpOutcome.status(429),
        HttpOutcome.success([4, 5, 6]),
      ],
    );
    final client = ZhipuTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeSecureStore('zhipu-secret')),
      delay: (duration) async => delays.add(duration),
    );

    await client.synthesize(testSegment, testProfile);

    expect(delays, const [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 16),
    ]);
  });

  test('honors Retry-After seconds and caps it at sixty seconds', () async {
    final delays = <Duration>[];
    final adapter = RecordingHttpClientAdapter(
      outcomes: const [
        HttpOutcome.status(
          429,
          headers: {
            'retry-after': ['120'],
          },
        ),
        HttpOutcome.success([4, 5, 6]),
      ],
    );
    final client = ZhipuTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeSecureStore('zhipu-secret')),
      delay: (duration) async => delays.add(duration),
    );

    await client.synthesize(testSegment, testProfile);

    expect(delays, const [Duration(seconds: 60)]);
  });

  test('honors Retry-After HTTP-date relative to the injected clock', () async {
    final delays = <Duration>[];
    final adapter = RecordingHttpClientAdapter(
      outcomes: const [
        HttpOutcome.status(
          429,
          headers: {
            'retry-after': ['Sat, 01 Aug 2026 00:00:30 GMT'],
          },
        ),
        HttpOutcome.success([4, 5, 6]),
      ],
    );
    final client = ZhipuTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeSecureStore('zhipu-secret')),
      delay: (duration) async => delays.add(duration),
      now: () => DateTime.utc(2026, 8, 1),
    );

    await client.synthesize(testSegment, testProfile);

    expect(delays, const [Duration(seconds: 30)]);
  });

  test('tests an entered key with a short real synthesis request', () async {
    final adapter = RecordingHttpClientAdapter(
      outcomes: [const HttpOutcome.success(validWavBytes)],
    );
    final client = ZhipuTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeSecureStore('stored-key')),
    );

    await client.testConnection(apiKey: 'entered-key', profile: testProfile);

    expect(adapter.request?.headers['Authorization'], 'Bearer entered-key');
    expect(adapter.request?.data['input'], '测试');
  });

  test(
    'connection test rejects invalid audio and does not retry 429',
    () async {
      final invalidAdapter = RecordingHttpClientAdapter(
        outcomes: const [
          HttpOutcome.success([1, 2, 3]),
        ],
      );
      final invalidClient = ZhipuTtsClient(
        dio: Dio()..httpClientAdapter = invalidAdapter,
        credentials: SecureCredentials(FakeSecureStore('stored-key')),
      );
      await expectLater(
        invalidClient.testConnection(
          apiKey: 'entered-key',
          profile: testProfile,
        ),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.message,
            'message',
            '智谱语音服务返回了无效音频',
          ),
        ),
      );

      final limitedAdapter = RecordingHttpClientAdapter(
        outcomes: const [HttpOutcome.status(429)],
      );
      final limitedClient = ZhipuTtsClient(
        dio: Dio()..httpClientAdapter = limitedAdapter,
        credentials: SecureCredentials(FakeSecureStore('stored-key')),
      );
      await expectLater(
        limitedClient.testConnection(
          apiKey: 'entered-key',
          profile: testProfile,
        ),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.message,
            'message',
            '智谱语音服务请求过于频繁',
          ),
        ),
      );
      expect(limitedAdapter.calls, 1);
    },
  );

  test('connection test requires an entered API key', () async {
    final client = ZhipuTtsClient(
      dio: Dio(),
      credentials: SecureCredentials(FakeSecureStore('stored-key')),
    );

    await expectLater(
      client.testConnection(apiKey: '  ', profile: testProfile),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          '请输入智谱 API Key',
        ),
      ),
    );
  });

  test('connection test rejects a non-Zhipu voice profile', () async {
    final adapter = RecordingHttpClientAdapter(
      outcomes: [const HttpOutcome.success(validWavBytes)],
    );
    final client = ZhipuTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeSecureStore('stored-key')),
    );

    await expectLater(
      client.testConnection(
        apiKey: 'entered-key',
        profile: VoiceProfile.cloud(
          baseUrl: 'https://example.com',
          model: 'tts-model',
          voice: 'voice-a',
          speed: 1,
          outputFormat: 'mp3',
        ),
      ),
      throwsArgumentError,
    );
    expect(adapter.calls, 0);
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
    expect(adapter.calls, 5);
  });
}

const testSegment = SpeechSegment(
  id: '1:0',
  paragraphId: 1,
  text: '正文',
  partIndex: 0,
);

const validWavBytes = <int>[
  0x52,
  0x49,
  0x46,
  0x46,
  0,
  0,
  0,
  0,
  0x57,
  0x41,
  0x56,
  0x45,
];

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
        ...outcome.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class HttpOutcome {
  const HttpOutcome.success(this.bytes)
    : statusCode = 200,
      timeout = false,
      headers = const {};

  const HttpOutcome.status(this.statusCode, {this.headers = const {}})
    : bytes = const [],
      timeout = false;

  const HttpOutcome.timeout()
    : bytes = const [],
      statusCode = 0,
      timeout = true,
      headers = const {};

  final List<int> bytes;
  final int statusCode;
  final bool timeout;
  final Map<String, List<String>> headers;
}
