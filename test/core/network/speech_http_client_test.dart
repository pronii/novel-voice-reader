import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/network/speech_http_client.dart';

void main() {
  test('speech requests use bounded timeouts sized for long TTS input', () {
    final dio = createSpeechDio();

    expect(dio.options.connectTimeout, const Duration(seconds: 15));
    expect(dio.options.sendTimeout, const Duration(seconds: 30));
    expect(dio.options.receiveTimeout, const Duration(seconds: 120));
  });
}
