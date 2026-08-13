import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_credentials_input.dart';

void main() {
  test('normalizes the API key by trimming whitespace', () {
    const input = SpeechCredentialsInput(apiKey: ' cloud-key ');

    expect(input.normalizedApiKey, 'cloud-key');
  });

  test('treats a blank API key as null', () {
    const input = SpeechCredentialsInput(apiKey: '   ');

    expect(input.normalizedApiKey, isNull);
  });

  test('treats a missing API key as null', () {
    const input = SpeechCredentialsInput();

    expect(input.normalizedApiKey, isNull);
  });
}
