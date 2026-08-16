import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

VoiceProfile testVoiceProfile() => VoiceProfile.cloud(
  baseUrl: 'https://api.example.com',
  model: 'tts-test',
  voice: 'test-voice',
  speed: 1,
  outputFormat: 'mp3',
);
