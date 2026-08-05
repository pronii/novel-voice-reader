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

  test('uses the fixed Tencent speech configuration and segment limit', () {
    final profile = VoiceProfile.tencent(voiceType: 1001, speed: 1.2);

    expect(profile.providerType, SpeechProviderType.tencent);
    expect(profile.normalizedBaseUrl, 'https://tts.tencentcloudapi.com');
    expect(profile.model, '1');
    expect(profile.voice, '1001');
    expect(profile.speed, 1.2);
    expect(profile.outputFormat, 'mp3');
    expect(profile.maxSegmentCharacters, 150);
  });

  test('rejects a non-positive Tencent voice type', () {
    expect(() => VoiceProfile.tencent(voiceType: 0), throwsArgumentError);
  });

  test('uses the fixed MiMo speech configuration and trims style', () {
    final profile = VoiceProfile.mimo(
      voice: '茉莉',
      style: '  温柔沉稳地讲述，语速稍慢。  ',
      speed: 1.2,
    );

    expect(profile.providerType, SpeechProviderType.mimo);
    expect(profile.normalizedBaseUrl, 'https://api.xiaomimimo.com');
    expect(profile.model, 'mimo-v2.5-tts');
    expect(profile.voice, '茉莉');
    expect(profile.style, '温柔沉稳地讲述，语速稍慢。');
    expect(profile.speed, 1.2);
    expect(profile.outputFormat, 'wav');
  });

  test('defaults MiMo to the Chinese Bingtang voice', () {
    final profile = VoiceProfile.mimo();

    expect(profile.voice, '冰糖');
    expect(profile.style, isNull);
  });

  test('rejects an unsupported MiMo preset voice', () {
    expect(() => VoiceProfile.mimo(voice: 'unknown'), throwsArgumentError);
  });

  test('keeps the existing segment limit for non-Tencent providers', () {
    expect(VoiceProfile.system().maxSegmentCharacters, 1000);
    expect(VoiceProfile.zhipu().maxSegmentCharacters, 1000);
    expect(VoiceProfile.mimo().maxSegmentCharacters, 1000);
  });
}
