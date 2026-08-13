import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_credentials_input.dart';

void main() {
  test('normalizes provider credentials without joining Tencent secrets', () {
    const input = SpeechCredentialsInput(
      apiKey: ' cloud-key ',
      secretId: ' tencent-id ',
      secretKey: ' tencent-key ',
    );

    expect(input.normalizedApiKey, 'cloud-key');
    expect(input.normalizedSecretId, 'tencent-id');
    expect(input.normalizedSecretKey, 'tencent-key');
  });
}
