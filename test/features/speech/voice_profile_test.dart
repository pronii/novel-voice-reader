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
    expect(() => VoiceProfile.system(speed: double.nan), throwsArgumentError);
  });

  test('rejects an invalid cloud endpoint or empty model fields', () {
    expect(
      () => VoiceProfile.cloud(
        baseUrl: 'not-a-url',
        model: 'tts-model',
        voice: 'voice-a',
        speed: 1,
        outputFormat: 'mp3',
      ),
      throwsArgumentError,
    );
    expect(
      () => VoiceProfile.cloud(
        baseUrl: 'https://user:secret@example.com',
        model: 'tts-model',
        voice: 'voice-a',
        speed: 1,
        outputFormat: 'mp3',
      ),
      throwsArgumentError,
    );
    expect(
      () => VoiceProfile.cloud(
        baseUrl: 'https://example.com',
        model: '   ',
        voice: 'voice-a',
        speed: 1,
        outputFormat: 'mp3',
      ),
      throwsArgumentError,
    );
    expect(
      () => VoiceProfile.cloud(
        baseUrl: 'https://example.com',
        model: 'tts-model',
        voice: 'voice-a',
        speed: 1,
        outputFormat: 'zip',
      ),
      throwsArgumentError,
    );
  });

  test('normalizes cloud model, voice, and output format', () {
    final profile = VoiceProfile.cloud(
      baseUrl: ' https://example.com/ ',
      model: ' tts-model ',
      voice: ' voice-a ',
      speed: 1,
      outputFormat: ' MP3 ',
    );

    expect(profile.normalizedBaseUrl, 'https://example.com');
    expect(profile.model, 'tts-model');
    expect(profile.voice, 'voice-a');
    expect(profile.outputFormat, 'mp3');
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

  test('keeps the existing segment limit for non-MiMo providers', () {
    expect(VoiceProfile.system().maxSegmentCharacters, 1000);
    expect(
      VoiceProfile.cloud(
        baseUrl: 'https://example.com',
        model: 'tts-model',
        voice: 'voice-a',
        speed: 1,
        outputFormat: 'mp3',
      ).maxSegmentCharacters,
      1000,
    );
    expect(VoiceProfile.mimo().maxSegmentCharacters, 360);
  });
}
