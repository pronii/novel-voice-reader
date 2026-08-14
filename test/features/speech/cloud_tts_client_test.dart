import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/speech/data/cloud_tts_client.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test('posts the compatible speech request with bearer auth', () async {
    final adapter = RecordingHttpClientAdapter(
      outcomes: [
        const HttpOutcome.success([1, 2, 3]),
      ],
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final client = CloudTtsClient(
      dio: dio,
      credentials: SecureCredentials(FakeSecureStore('secret')),
    );
    const segment = SpeechSegment(
      id: '1:0',
      paragraphId: 1,
      text: '正文',
      partIndex: 0,
    );
    final profile = VoiceProfile.cloud(
      baseUrl: 'https://example.com/',
      model: 'tts-model',
      voice: 'voice-a',
      speed: 1,
      outputFormat: 'mp3',
    );

    final bytes = await client.synthesize(segment, profile);

    expect(bytes, Uint8List.fromList([1, 2, 3]));
    expect(adapter.request?.path, 'https://example.com/v1/audio/speech');
    expect(adapter.request?.headers['Authorization'], 'Bearer secret');
    expect(adapter.request?.data, {
      'model': 'tts-model',
      'voice': 'voice-a',
      'input': '正文',
      'response_format': 'mp3',
      'speed': 1.0,
    });
  });

  test('does not duplicate v1 when it is already in the base URL', () async {
    final adapter = RecordingHttpClientAdapter(
      outcomes: [
        const HttpOutcome.success([1, 2, 3]),
      ],
    );
    final client = CloudTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeSecureStore('secret')),
    );
    final profile = VoiceProfile.cloud(
      baseUrl: 'https://example.com/v1',
      model: 'tts-model',
      voice: 'voice-a',
      speed: 1,
      outputFormat: 'mp3',
    );

    await client.synthesize(testSegment, profile);

    expect(adapter.request?.path, 'https://example.com/v1/audio/speech');
  });

  test('retries a rate-limited request and then succeeds', () async {
    final adapter = RecordingHttpClientAdapter(
      outcomes: [
        const HttpOutcome.status(429),
        const HttpOutcome.success([4, 5, 6]),
      ],
    );
    final client = CloudTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeSecureStore('secret')),
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
    final client = CloudTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeSecureStore('secret')),
      delay: (_) async {},
    );

    await expectLater(
      client.synthesize(testSegment, testProfile),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          '云端语音服务认证失败',
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
    final client = CloudTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeSecureStore('secret')),
      delay: (_) async {},
    );

    await expectLater(
      client.synthesize(testSegment, testProfile),
      throwsA(
        isA<AppFailure>()
            .having((failure) => failure.message, 'message', '云端语音服务连接超时')
            .having(
              (failure) => failure.message,
              'message',
              isNot(contains('secret')),
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

final testProfile = VoiceProfile.cloud(
  baseUrl: 'https://example.com/',
  model: 'tts-model',
  voice: 'voice-a',
  speed: 1,
  outputFormat: 'mp3',
);

final class FakeSecureStore implements SecureKeyValueStore {
  FakeSecureStore(this.apiKey);

  final String apiKey;

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
        Headers.contentTypeHeader: ['audio/mpeg'],
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
