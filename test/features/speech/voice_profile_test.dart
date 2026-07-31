import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test('normalizes a trailing slash from the base URL', () {
    final profile = VoiceProfile.cloud(
      baseUrl: 'https://example.com/',
      model: 'tts-model',
      voice: 'voice-a',
      speed: 1,
      outputFormat: 'mp3',
    );

    expect(profile.normalizedBaseUrl, 'https://example.com');
  });

  test('rejects a non-positive speech speed', () {
    expect(
      () => VoiceProfile.cloud(
        baseUrl: 'https://example.com',
        model: 'tts-model',
        voice: 'voice-a',
        speed: 0,
        outputFormat: 'mp3',
      ),
      throwsArgumentError,
    );
  });

  test('normalizes an Azure region into the Speech endpoint', () {
    final profile = VoiceProfile.azure(
      region: ' EastAsia ',
      voice: 'zh-CN-XiaoxiaoNeural',
      speed: 1.1,
      outputFormat: 'audio-24khz-48kbitrate-mono-mp3',
    );

    expect(profile.providerType, SpeechProviderType.azure);
    expect(
      profile.normalizedBaseUrl,
      'https://eastasia.tts.speech.microsoft.com',
    );
    expect(profile.voice, 'zh-CN-XiaoxiaoNeural');
  });

  test('uses the fixed official Zhipu speech configuration', () {
    final profile = VoiceProfile.zhipu(voice: 'xiaochen', speed: 1.2);

    expect(profile.providerType, SpeechProviderType.zhipu);
    expect(profile.normalizedBaseUrl, 'https://open.bigmodel.cn/api/paas/v4');
    expect(profile.model, 'glm-tts');
    expect(profile.voice, 'xiaochen');
    expect(profile.speed, 1.2);
    expect(profile.outputFormat, 'wav');
  });

  test('rejects an unsupported Zhipu system voice', () {
    expect(() => VoiceProfile.zhipu(voice: 'unknown'), throwsArgumentError);
  });
}
