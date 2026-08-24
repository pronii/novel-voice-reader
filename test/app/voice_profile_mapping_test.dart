import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/app/providers.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test('falls back to the default self-hosted server when no profile exists', (
    ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final profile = await loadActiveVoiceProfile(database);

    expect(profile.providerType, SpeechProviderType.server);
    expect(profile.baseUrl, kDefaultServerBaseUrl);
  });

  test('ignores a legacy system profile', () {
    const record = VoiceProfileRecord(
      id: 3,
      providerType: 'system',
      voice: 'zh-CN',
      speed: 1.2,
      pitch: 1.1,
    );

    final profile = voiceProfileFromRecord(record);

    expect(profile, isA<Null>());
  });

  test('maps a stored cloud profile for active reader playback', () {
    const record = VoiceProfileRecord(
      id: 4,
      providerType: 'cloud',
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-4o-mini-tts',
      voice: 'alloy',
      speed: 0.9,
      outputFormat: 'mp3',
    );

    final profile = voiceProfileFromRecord(record);

    expect(profile?.providerType, SpeechProviderType.cloud);
    expect(profile?.normalizedBaseUrl, record.baseUrl);
    expect(profile?.model, 'gpt-4o-mini-tts');
    expect(profile?.voice, 'alloy');
    expect(profile?.speed, 0.9);
    expect(profile?.outputFormat, 'mp3');
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
            providerType: 'cloud',
            baseUrl: const Value('https://api.openai.com/v1'),
            model: const Value('gpt-4o-mini-tts'),
            voice: const Value('alloy'),
            speed: const Value(1.1),
            outputFormat: const Value('mp3'),
          ),
        );

    final profile = await loadActiveVoiceProfile(database);

    expect(profile.providerType, SpeechProviderType.cloud);
    expect(profile.speed, 1.1);
  });

  test('maps a stored server profile', () {
    const record = VoiceProfileRecord(
      id: 5,
      providerType: 'server',
      baseUrl: 'https://tts.ll.993209.xyz:888',
      model: 'gpt-4o-mini-tts',
      voice: 'alloy',
      speed: 1,
      outputFormat: 'mp3',
    );

    final profile = voiceProfileFromRecord(record);

    expect(profile?.providerType, SpeechProviderType.server);
    expect(profile?.normalizedBaseUrl, record.baseUrl);
  });

  test('ignores an unknown provider type', () {
    const record = VoiceProfileRecord(
      id: 6,
      providerType: 'legacy-provider',
      voice: '1001',
      speed: 1,
    );

    final profile = voiceProfileFromRecord(record);

    expect(profile, isA<Null>());
  });

  test('ignores a corrupt MiMo voice', () {
    const record = VoiceProfileRecord(
      id: 7,
      providerType: 'mimo',
      voice: 'not-a-real-voice',
      speed: 1,
    );

    final profile = voiceProfileFromRecord(record);

    expect(profile, isA<Null>());
  });

  test('ignores a corrupt cloud profile', () {
    const record = VoiceProfileRecord(
      id: 9,
      providerType: 'cloud',
      baseUrl: 'not-a-url',
      model: 'tts-model',
      voice: 'voice-a',
      speed: 1,
      outputFormat: 'mp3',
    );

    final profile = voiceProfileFromRecord(record);

    expect(profile, isA<Null>());
  });

  test('maps a stored MiMo profile including narration style', () {
    const record = VoiceProfileRecord(
      id: 8,
      providerType: 'mimo',
      baseUrl: 'https://api.xiaomimimo.com',
      model: 'mimo-v2.5-tts',
      voice: '茉莉',
      speed: 1.1,
      outputFormat: 'wav',
      style: '温柔沉稳地讲述',
    );

    final profile = voiceProfileFromRecord(record);

    expect(profile?.providerType, SpeechProviderType.mimo);
    expect(profile?.voice, '茉莉');
    expect(profile?.style, '温柔沉稳地讲述');
    expect(profile?.speed, 1.1);
  });
}
