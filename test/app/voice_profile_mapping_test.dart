import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/app/providers.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test('maps a stored Azure profile for active reader playback', () {
    const record = VoiceProfileRecord(
      id: 4,
      providerType: 'azure',
      baseUrl: 'https://eastasia.tts.speech.microsoft.com',
      voice: 'zh-CN-XiaoxiaoNeural',
      speed: 1.2,
      outputFormat: 'audio-24khz-48kbitrate-mono-mp3',
    );

    final profile = voiceProfileFromRecord(record);

    expect(profile.providerType, SpeechProviderType.azure);
    expect(profile.normalizedBaseUrl, record.baseUrl);
    expect(profile.voice, record.voice);
    expect(profile.speed, record.speed);
  });
}
