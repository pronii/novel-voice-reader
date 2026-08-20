import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:novel_voice_reader/features/diagnostics/domain/playback_telemetry.dart';

// `_telemetry` is initialized from a public named parameter and so cannot be a
// `this._field` initializing formal (named params may not start with `_`).
// ignore_for_file: prefer_initializing_formals

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
    this._activateOnInitialize, {
    PlaybackTelemetry telemetry = const NoopPlaybackTelemetry(),
  }) : _telemetry = telemetry;

  final AudioSessionDelegate _delegate;
  final bool _activateOnInitialize;
  final PlaybackTelemetry _telemetry;

  static Future<BackgroundAudioSession> system({
    PlaybackTelemetry telemetry = const NoopPlaybackTelemetry(),
  }) async {
    final session = await AudioSession.instance;
    return BackgroundAudioSession(
      _PluginAudioSessionDelegate(session),
      Platform.isIOS,
      telemetry: telemetry,
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
  /// The first `setActive` after the OS reclaimed audio focus can transiently
  /// fail, so retry a bounded number of times rather than swallowing a single
  /// failure and leaving background playback dead.
  ///
  /// This never deactivates the session: background playback keeps the session
  /// active across the gaps between spoken segments so iOS does not suspend the
  /// isolate mid-chapter.
  Future<bool> ensureActive() async {
    for (var attempt = 0; attempt < _activationAttempts; attempt++) {
      if (await _delegate.setActive(true)) {
        _telemetry.record('session.ensureActive', {
          'active': true,
          'attempts': attempt + 1,
        });
        return true;
      }
    }
    _telemetry.record('session.ensureActive', {
      'active': false,
      'attempts': _activationAttempts,
    });
    return false;
  }

  /// Deactivates the audio session after playback has been fully stopped
  /// (e.g. the sleep timer expired and the user is done listening).
  ///
  /// While the session stays active iOS keeps the app in a running
  /// background-audio state even after the keep-alive loop has been paused,
  /// which wastes battery. Deactivating lets the OS suspend the app; the next
  /// [ensureActive] on a fresh play request re-activates it.
  Future<void> deactivate() async {
    await _delegate.setActive(false);
    _telemetry.record('session.deactivate');
  }

  static const int _activationAttempts = 3;
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
