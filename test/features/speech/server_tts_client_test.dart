import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/speech/data/server_tts_client.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test('creates a server job, polls it, and downloads the audio', () async {
    final adapter = _ServerAdapter();
    final client = ServerTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(_Store('secret')),
      delay: (_) async {},
    );
    const segment = SpeechSegment(
      id: '1:0',
      paragraphId: 1,
      text: '正文',
      partIndex: 0,
    );
    final profile = VoiceProfile.server(
      baseUrl: 'https://tts.example.com',
      model: 'tts-model',
      voice: 'voice-a',
      speed: 1.1,
    );

    final audio = await client.synthesize(segment, profile);

    expect(audio, [1, 2, 3]);
    expect(adapter.paths, [
      'https://tts.example.com/v1/jobs',
      'https://tts.example.com/v1/jobs/job-1',
      'https://tts.example.com/v1/jobs/job-1/segments/0',
    ]);
    expect(adapter.authorization, 'Bearer secret');
    expect(adapter.createdJob, {
      'text': '正文',
      'max_characters': 1000,
      'model': 'tts-model',
      'voice': 'voice-a',
      'format': 'wav',
      'speed': 1.1,
    });
  });
}

final class _Store implements SecureKeyValueStore {
  _Store(this.value);
  final String value;
  @override
  Future<void> delete(String key) async {}
  @override
  Future<String?> read(String key) async => value;
  @override
  Future<void> write(String key, String value) async {}
}

final class _ServerAdapter implements HttpClientAdapter {
  final paths = <String>[];
  String? authorization;
  Object? createdJob;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.toString());
    if (options.path.endsWith('/v1/jobs')) {
      authorization = options.headers['Authorization'] as String?;
      createdJob = options.data;
      return _json({'id': 'job-1', 'status': 'running'});
    }
    if (options.path.endsWith('/job-1')) {
      return _json({'id': 'job-1', 'status': 'completed'});
    }
    return ResponseBody.fromBytes(
      [1, 2, 3],
      200,
      headers: {
        Headers.contentTypeHeader: ['audio/mpeg'],
      },
    );
  }

  ResponseBody _json(Map<String, Object?> value) => ResponseBody.fromString(
    jsonEncode(value),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}
