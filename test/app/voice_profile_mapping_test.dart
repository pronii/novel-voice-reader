import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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

  test('loads the most recently saved profile for reader playback', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database
        .into(database.voiceProfiles)
        .insert(VoiceProfilesCompanion.insert(providerType: 'system'));
    await database
        .into(database.voiceProfiles)
        .insert(
          VoiceProfilesCompanion.insert(
            providerType: 'azure',
            baseUrl: const Value('https://eastasia.tts.speech.microsoft.com'),
            voice: const Value('zh-CN-XiaoxiaoNeural'),
            speed: const Value(1.1),
            outputFormat: const Value('audio-24khz-48kbitrate-mono-mp3'),
          ),
        );

    final profile = await loadActiveVoiceProfile(database);

    expect(profile.providerType, SpeechProviderType.azure);
    expect(profile.speed, 1.1);
  });

  test('maps a stored Zhipu profile for active reader playback', () {
    const record = VoiceProfileRecord(
      id: 5,
      providerType: 'zhipu',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      model: 'glm-tts',
      voice: 'luodo',
      speed: 0.9,
      outputFormat: 'wav',
    );

    final profile = voiceProfileFromRecord(record);

    expect(profile.providerType, SpeechProviderType.zhipu);
    expect(profile.normalizedBaseUrl, record.baseUrl);
    expect(profile.model, 'glm-tts');
    expect(profile.voice, 'luodo');
    expect(profile.speed, 0.9);
    expect(profile.outputFormat, 'wav');
  });

  test('maps a stored Tencent profile for active reader playback', () {
    const record = VoiceProfileRecord(
      id: 6,
      providerType: 'tencent',
      baseUrl: 'https://tts.tencentcloudapi.com',
      model: '1',
      voice: '1001',
      speed: 1.2,
      outputFormat: 'mp3',
    );

    final profile = voiceProfileFromRecord(record);

    expect(profile.providerType, SpeechProviderType.tencent);
    expect(profile.normalizedBaseUrl, VoiceProfile.tencentBaseUrl);
    expect(profile.voice, '1001');
    expect(profile.speed, 1.2);
    expect(profile.outputFormat, 'mp3');
  });

  test('falls back to system speech for a corrupt Tencent voice type', () {
    const record = VoiceProfileRecord(
      id: 7,
      providerType: 'tencent',
      voice: 'not-a-number',
      speed: 1,
    );

    final profile = voiceProfileFromRecord(record);

    expect(profile.providerType, SpeechProviderType.system);
  });
}
