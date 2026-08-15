import 'dart:io';

import 'package:audio_session/audio_session.dart';

/// A normalised audio-session interruption signal, decoupled from the plugin so
/// the sustaining logic can be exercised without a platform channel.
enum AudioInterruption {
  /// The OS took audio focus (an incoming call, another app). Our audio has
  /// already been silenced by the system.
  began,

  /// The interruption ended and the OS indicated that we may resume playback.
  endedShouldResume,

  /// The interruption ended but we should remain paused.
  endedShouldStay,
}

abstract interface class AudioSessionDelegate {
  Future<void> configure(AudioSessionConfiguration configuration);

  Future<bool> setActive(bool active);

  /// Normalised interruption notifications (calls, other apps grabbing focus).
  Stream<AudioInterruption> get interruptions;

  /// Emits whenever the active output route changes (headphones un/plugged,
  /// Bluetooth connect/disconnect). iOS deactivates our session across some of
  /// these transitions, so listeners re-activate it.
  Stream<void> get devicesChanged;
}

final class BackgroundAudioSession {
  const BackgroundAudioSession(
    this._delegate,
    this._activateOnInitialize,
  );

  final AudioSessionDelegate _delegate;
  final bool _activateOnInitialize;

  static Future<BackgroundAudioSession> system() async {
    final session = await AudioSession.instance;
    return BackgroundAudioSession(
      _PluginAudioSessionDelegate(session),
      Platform.isIOS,
    );
  }

  Stream<AudioInterruption> get interruptions => _delegate.interruptions;

  Stream<void> get devicesChanged => _delegate.devicesChanged;

  Future<void> initialize() async {
    await _delegate.configure(AudioSessionConfiguration.music());
    if (!_activateOnInitialize) {
      return;
    }
    final activated = await _delegate.setActive(true);
    if (!activated) {
      throw StateError('Unable to activate the background audio session.');
    }
  }

  /// Re-activates the session after the OS deactivated it (following an
  /// interruption or an output-route change). Returns whether it is now active.
  ///
  /// This never deactivates the session: background playback keeps the session
  /// active across the gaps between spoken segments so iOS does not suspend the
  /// isolate mid-chapter.
  Future<bool> ensureActive() => _delegate.setActive(true);
}

final class _PluginAudioSessionDelegate implements AudioSessionDelegate {
  const _PluginAudioSessionDelegate(this._session);

  final AudioSession _session;

  @override
  Future<void> configure(AudioSessionConfiguration configuration) =>
      _session.configure(configuration);

  @override
  Future<bool> setActive(bool active) => _session.setActive(active);

  @override
  Stream<AudioInterruption> get interruptions =>
      _session.interruptionEventStream.map((event) {
        if (event.begin) {
          return AudioInterruption.began;
        }
        // audio_session reports `pause` on the end event only when the OS set
        // its `shouldResume` option, which is our cue to resume.
        return event.type == AudioInterruptionType.pause
            ? AudioInterruption.endedShouldResume
            : AudioInterruption.endedShouldStay;
      });

  @override
  Stream<void> get devicesChanged =>
      _session.devicesChangedEventStream.map((_) {});
}
