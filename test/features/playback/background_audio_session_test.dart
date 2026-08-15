import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_session.dart';

void main() {
  test('configures music playback before activating the audio session', () async {
    final delegate = RecordingAudioSessionDelegate();

    await BackgroundAudioSession(
      delegate,
      true,
    ).initialize();

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

  test('does not claim audio focus during startup on other platforms', () async {
    final delegate = RecordingAudioSessionDelegate();

    await BackgroundAudioSession(
      delegate,
      false,
    ).initialize();

    expect(delegate.events, ['configure']);
  });

  test('ensureActive re-activates the session without deactivating', () async {
    final delegate = RecordingAudioSessionDelegate();
    final session = BackgroundAudioSession(delegate, false);

    final active = await session.ensureActive();

    expect(active, isTrue);
    expect(delegate.events, ['activate']);
    expect(delegate.deactivations, 0);
  });
}

final class RecordingAudioSessionDelegate implements AudioSessionDelegate {
  final events = <String>[];
  final interruptionController =
      StreamController<AudioInterruption>.broadcast();
  final devicesController = StreamController<void>.broadcast();
  AudioSessionConfiguration? configuration;
  int deactivations = 0;

  @override
  Future<void> configure(AudioSessionConfiguration configuration) async {
    events.add('configure');
    this.configuration = configuration;
  }

  @override
  Future<bool> setActive(bool active) async {
    events.add(active ? 'activate' : 'deactivate');
    if (!active) {
      deactivations++;
    }
    return active;
  }

  @override
  Stream<AudioInterruption> get interruptions => interruptionController.stream;

  @override
  Stream<void> get devicesChanged => devicesController.stream;
}
