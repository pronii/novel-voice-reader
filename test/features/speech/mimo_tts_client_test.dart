import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/speech/data/mimo_tts_client.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test('posts MiMo chat messages and decodes WAV audio', () async {
    final adapter = MiMoRecordingAdapter([
      MiMoOutcome.success(_audioResponse(testWave)),
    ]);
    final client = MiMoTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeMiMoSecureStore('mimo-secret')),
    );
    final profile = VoiceProfile.mimo(voice: '茉莉', style: '温柔沉稳地讲述，语速稍慢。');

    final bytes = await client.synthesize(testSegment, profile);

    expect(bytes, testWave);
    expect(
      adapter.request?.path,
      'https://api.xiaomimimo.com/v1/chat/completions',
    );
    expect(adapter.request?.headers['api-key'], 'mimo-secret');
    expect(adapter.request?.data, {
      'model': 'mimo-v2.5-tts',
      'messages': [
        {'role': 'user', 'content': '温柔沉稳地讲述，语速稍慢。'},
        {'role': 'assistant', 'content': '正文'},
      ],
      'audio': {'format': 'wav', 'voice': '茉莉'},
    });
  });

  test('uses a stable narration instruction when style is empty', () async {
    final adapter = MiMoRecordingAdapter([
      MiMoOutcome.success(_audioResponse(testWave)),
    ]);
    final client = MiMoTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeMiMoSecureStore('mimo-secret')),
    );

    await client.synthesize(testSegment, VoiceProfile.mimo());

    final data = adapter.request?.data as Map<String, dynamic>;
    final messages = data['messages'] as List<dynamic>;
    expect(messages.first, {
      'role': 'user',
      'content': MiMoTtsClient.defaultNarrationStyle,
    });
  });

  test('requires a configured MiMo API key', () async {
    final client = MiMoTtsClient(
      dio: Dio(),
      credentials: SecureCredentials(FakeMiMoSecureStore(null)),
    );

    await expectLater(
      client.synthesize(testSegment, VoiceProfile.mimo()),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          '尚未配置 MiMo API Key',
        ),
      ),
    );
  });

  test('rejects invalid Base64 or non-WAV audio', () async {
    for (final data in [
      'not-base64',
      base64Encode([1, 2, 3]),
    ]) {
      final adapter = MiMoRecordingAdapter([
        MiMoOutcome.success(_audioResponseData(data)),
      ]);
      final client = MiMoTtsClient(
        dio: Dio()..httpClientAdapter = adapter,
        credentials: SecureCredentials(FakeMiMoSecureStore('mimo-secret')),
      );

      await expectLater(
        client.synthesize(testSegment, VoiceProfile.mimo()),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.message,
            'message',
            'MiMo 语音服务返回了无效音频',
          ),
        ),
      );
    }
  });

  test('retries rate limiting and then succeeds', () async {
    final delays = <Duration>[];
    final adapter = MiMoRecordingAdapter([
      const MiMoOutcome.status(429),
      MiMoOutcome.success(_audioResponse(testWave)),
    ]);
    final client = MiMoTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeMiMoSecureStore('mimo-secret')),
      delay: (duration) async => delays.add(duration),
    );

    final bytes = await client.synthesize(testSegment, VoiceProfile.mimo());

    expect(bytes, testWave);
    expect(adapter.calls, 2);
    expect(delays, [const Duration(milliseconds: 500)]);
  });

  test(
    'maps authentication and exhausted rate limits to safe failures',
    () async {
      for (final scenario in [
        (status: 401, message: 'MiMo 语音服务认证失败'),
        (status: 429, message: 'MiMo 语音服务请求过于频繁'),
      ]) {
        final adapter = MiMoRecordingAdapter([
          MiMoOutcome.status(scenario.status),
        ]);
        final client = MiMoTtsClient(
          dio: Dio()..httpClientAdapter = adapter,
          credentials: SecureCredentials(FakeMiMoSecureStore('mimo-secret')),
          maxAttempts: 1,
        );

        await expectLater(
          client.synthesize(testSegment, VoiceProfile.mimo()),
          throwsA(
            isA<AppFailure>().having(
              (failure) => failure.message,
              'message',
              scenario.message,
            ),
          ),
        );
      }
    },
  );

  test(
    'tests the entered key without reading or saving secure storage',
    () async {
      final adapter = MiMoRecordingAdapter([
        MiMoOutcome.success(_audioResponse(testWave)),
      ]);
      final store = FakeMiMoSecureStore('stored-key');
      final client = MiMoTtsClient(
        dio: Dio()..httpClientAdapter = adapter,
        credentials: SecureCredentials(store),
      );

      await client.testConnection(
        apiKey: '  entered-key  ',
        profile: VoiceProfile.mimo(voice: 'Dean'),
      );

      expect(adapter.request?.headers['api-key'], 'entered-key');
      expect(store.reads, 0);
      expect(store.writes, 0);
    },
  );

  test('connection testing retries a transient rate limit', () async {
    final delays = <Duration>[];
    final adapter = MiMoRecordingAdapter([
      const MiMoOutcome.status(429),
      MiMoOutcome.success(_audioResponse(testWave)),
    ]);
    final client = MiMoTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeMiMoSecureStore('stored-key')),
      delay: (duration) async => delays.add(duration),
    );

    await client.testConnection(
      apiKey: 'entered-key',
      profile: VoiceProfile.mimo(),
    );

    expect(adapter.calls, 2);
    expect(delays, [const Duration(milliseconds: 500)]);
  });
}

Map<String, dynamic> _audioResponse(Uint8List bytes) =>
    _audioResponseData(base64Encode(bytes));

Map<String, dynamic> _audioResponseData(String data) => {
  'choices': [
    {
      'message': {
        'audio': {'data': data},
      },
    },
  ],
};

final testWave = Uint8List.fromList([
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
]);

const testSegment = SpeechSegment(
  id: 'segment-1',
  paragraphId: 1,
  text: '正文',
  partIndex: 0,
);

final class FakeMiMoSecureStore implements SecureKeyValueStore {
  FakeMiMoSecureStore(this.value);

  String? value;
  int reads = 0;
  int writes = 0;

  @override
  Future<void> delete(String key) async => value = null;

  @override
  Future<String?> read(String key) async {
    reads++;
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    this.value = value;
  }
}

final class MiMoRecordingAdapter implements HttpClientAdapter {
  MiMoRecordingAdapter(this.outcomes);

  final List<MiMoOutcome> outcomes;
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
    return ResponseBody.fromString(
      jsonEncode(outcome.body),
      outcome.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class MiMoOutcome {
  const MiMoOutcome.success(this.body) : statusCode = 200;

  const MiMoOutcome.status(this.statusCode) : body = const {};

  final int statusCode;
  final Map<String, dynamic> body;
}
