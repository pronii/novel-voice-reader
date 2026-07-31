import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/speech/data/azure_tts_client.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test('posts escaped SSML to the regional Azure Speech endpoint', () async {
    final adapter = RecordingAzureHttpClientAdapter();
    final client = AzureTtsClient(
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(FakeAzureSecureStore('azure-secret')),
    );
    const segment = SpeechSegment(
      id: '8:0',
      paragraphId: 8,
      text: '5 < 7 & "双引号" \'单引号\'',
      partIndex: 0,
    );
    final profile = VoiceProfile.azure(
      region: 'eastasia',
      voice: 'zh-CN-XiaoxiaoNeural',
      speed: 1,
      outputFormat: 'audio-24khz-48kbitrate-mono-mp3',
    );

    final bytes = await client.synthesize(segment, profile);

    expect(bytes, Uint8List.fromList([0x49, 0x44, 0x33, 0x04]));
    expect(
      adapter.request?.path,
      'https://eastasia.tts.speech.microsoft.com/cognitiveservices/v1',
    );
    expect(
      adapter.request?.headers['Ocp-Apim-Subscription-Key'],
      'azure-secret',
    );
    expect(
      adapter.request?.headers['X-Microsoft-OutputFormat'],
      'audio-24khz-48kbitrate-mono-mp3',
    );
    expect(adapter.request?.headers['Content-Type'], 'application/ssml+xml');
    expect(adapter.request?.data, contains('name="zh-CN-XiaoxiaoNeural"'));
    expect(adapter.request?.data, contains('rate="0%"'));
    expect(
      adapter.request?.data,
      contains('5 &lt; 7 &amp; &quot;双引号&quot; &apos;单引号&apos;'),
    );
    expect(adapter.request?.data, isNot(contains('azure-secret')));
  });
}

final class FakeAzureSecureStore implements SecureKeyValueStore {
  FakeAzureSecureStore(this.value);

  final String value;

  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async {}
}

final class RecordingAzureHttpClientAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromBytes(
      const [0x49, 0x44, 0x33, 0x04],
      200,
      headers: {
        Headers.contentTypeHeader: ['audio/mpeg'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
