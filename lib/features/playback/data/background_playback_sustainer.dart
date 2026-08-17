import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:novel_voice_reader/features/diagnostics/domain/playback_telemetry.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_session.dart';
import 'package:novel_voice_reader/features/playback/data/background_keep_alive.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_handler.dart';

/// Bridges the audio session, the keep-alive loop, and the media handler so
/// background playback survives inter-segment gaps and audio interruptions.
///
/// While playback intends to produce audio it keeps the session active and the
/// keep-alive loop running; on an interruption it re-activates the session and
/// resumes if we were playing; on an output-route change it re-activates the
/// session. It never deactivates the session or pauses in response to app
/// lifecycle transitions, so locking the screen does not stop playback.
final class BackgroundPlaybackSustainer {
  BackgroundPlaybackSustainer({
    required BackgroundAudioSession session,
    required KeepAlivePlayer keepAlive,
    required NovelAudioHandler handler,
    PlaybackTelemetry telemetry = const NoopPlaybackTelemetry(),
  }) : _session = session,
       // ignore: prefer_initializing_formals
       _keepAlive = keepAlive,
       _handler = handler,
       _telemetry = telemetry {
    _playbackSubscription = handler.playbackState.listen(_onPlaybackState);
    _interruptionSubscription = session.interruptions.listen(_onInterruption);
    _devicesSubscription = session.devicesChanged.listen(
      (_) => _onDevicesChanged(),
    );
    _onPlaybackState(handler.playbackState.value);
  }

  final BackgroundAudioSession _session;
  final KeepAlivePlayer _keepAlive;
  final NovelAudioHandler _handler;
  final PlaybackTelemetry _telemetry;

  late final StreamSubscription<PlaybackState> _playbackSubscription;
  late final StreamSubscription<AudioInterruption> _interruptionSubscription;
  late final StreamSubscription<void> _devicesSubscription;

  Future<void> _operations = Future<void>.value();
  bool _engaged = false;
  bool _resumeAfterInterruption = false;

  static bool _shouldRender(PlaybackState state) =>
      state.playing && state.processingState != AudioProcessingState.idle;

  void _onPlaybackState(PlaybackState state) {
    final shouldRender = _shouldRender(state);
    if (shouldRender == _engaged) {
      return;
    }
    _engaged = shouldRender;
    _telemetry.record('sustainer.render', {
      'shouldRender': shouldRender,
      'playing': state.playing,
      'processingState': state.processingState.name,
    });
    _enqueue(() async {
      if (shouldRender) {
        await _session.ensureActive();
        await _keepAlive.start();
      } else {
        // Stop the inaudible loop, but leave the session active so a quick
        // resume (and the lock-screen transport) stays responsive.
        await _keepAlive.stop();
      }
    });
  }

  // Residual real-device risk (no device available to verify): iOS only posts
  // an interruption for a genuine external focus-loss (phone call, Siri, another
  // app claiming the session) — not for our own players starting/stopping within
  // the shared session. Because cached remote audio and the keep-alive loop
  // render into one AVAudioSession, swapping between them mid-chapter should not
  // surface here, so
  // pausing on `began` should never fire against our own audio-chain switches.
  // audio_session cannot introspect the interruption's origin, so if this proves
  // false on device the fix is native (AVAudioSession delegate), not here.
  void _onInterruption(AudioInterruption interruption) {
    _telemetry.record('sustainer.interruption', {
      'kind': interruption.name,
    });
    switch (interruption) {
      case AudioInterruption.began:
        _resumeAfterInterruption = _shouldRender(_handler.playbackState.value);
        if (_resumeAfterInterruption) {
          _enqueue(() => _handler.pause());
        }
      case AudioInterruption.endedShouldResume:
        if (!_resumeAfterInterruption) {
          return;
        }
        _resumeAfterInterruption = false;
        _enqueue(() async {
          await _session.ensureActive();
          await _handler.play();
        });
      case AudioInterruption.endedShouldStay:
        _resumeAfterInterruption = false;
        _enqueue(() => _session.ensureActive());
    }
  }

  void _onDevicesChanged() {
    if (!_engaged) {
      return;
    }
    _telemetry.record('sustainer.devicesChanged');
    _enqueue(() async {
      await _session.ensureActive();
      // iOS may stop an AudioPlayer when its output route changes without
      // reporting a playback error. Restart the loop after re-activating the
      // shared session so background execution is not lost silently.
      await _keepAlive.start();
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _operations.then((_) => action());
    _operations = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace _) {
        _telemetry.record('sustainer.operation.error', {
          'error': error.runtimeType.toString(),
          'message': error.toString(),
        });
      },
    );
    return operation;
  }

  Future<void> dispose() async {
    await _playbackSubscription.cancel();
    await _interruptionSubscription.cancel();
    await _devicesSubscription.cancel();
    await _operations;
    await _keepAlive.dispose();
  }
}
