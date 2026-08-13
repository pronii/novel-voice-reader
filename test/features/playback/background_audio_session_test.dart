import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_session.dart';

void main() {
  test('configures music playback before activating the audio session', () async {
    final delegate = RecordingAudioSessionDelegate();

    await BackgroundAudioSession(delegate).initialize();

    expect(delegate.events, ['configure', 'activate']);
    final configuration = delegate.configuration!;
    expect(
      configuration.avAudioSessionCategory,
      AVAudioSessionCategory.playback,
    );
    expect(configuration.avAudioSessionMode, AVAudioSessionMode.defaultMode);
    expect(
      configuration.androidAudioAttributes?.contentType,
      AndroidAudioContentType.music,
    );
    expect(
      configuration.androidAudioAttributes?.usage,
      AndroidAudioUsage.media,
    );
    expect(
      configuration.androidAudioFocusGainType,
      AndroidAudioFocusGainType.gain,
    );
  });
}

final class RecordingAudioSessionDelegate implements AudioSessionDelegate {
  final events = <String>[];
  AudioSessionConfiguration? configuration;

  @override
  Future<void> configure(AudioSessionConfiguration configuration) async {
    events.add('configure');
    this.configuration = configuration;
  }

  @override
  Future<bool> setActive(bool active) async {
    events.add('activate');
    return active;
  }
}
