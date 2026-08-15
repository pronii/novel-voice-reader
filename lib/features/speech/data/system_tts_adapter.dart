import 'dart:async';
import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

abstract interface class SystemTtsEngine {
  void setStartHandler(void Function() handler);

  void setCompletionHandler(void Function() handler);

  void setErrorHandler(void Function(Object error) handler);

  Future<void> configure(VoiceProfile profile);

  Future<void> speak(String text);

  Future<void> pause();

  Future<void> stop();
}

abstract interface class AdjustableSystemTtsEngine {
  Future<void> setPlaybackSpeed(double speed);
}

/// Optional capability: engines that must prepare the platform audio session
/// before speaking. On iOS the synthesizer otherwise defaults to the `ambient`
/// category, which the OS silences once the screen locks — playback dies a
/// minute or two after locking and completion callbacks stop firing.
abstract interface class SessionConfigurableSystemTtsEngine {
  /// Configures the underlying platform audio session for uninterrupted
  /// background playback. Idempotent; called once before the first `speak`.
  Future<void> configureSession();
}

/// Optional capability: engines that report how far into the spoken text
/// playback has progressed, letting [SystemTtsAdapter] resume near the pause
/// point instead of replaying the whole segment.
abstract interface class ProgressReportingSystemTtsEngine {
  void setProgressHandler(void Function(int endOffset) handler);
}

final class FlutterSystemTtsEngine
    implements
        SystemTtsEngine,
        AdjustableSystemTtsEngine,
        SessionConfigurableSystemTtsEngine,
        ProgressReportingSystemTtsEngine {
  FlutterSystemTtsEngine([FlutterTts? flutterTts, bool? isIos])
    : _flutterTts = flutterTts ?? FlutterTts(),
      _isIos = isIos ?? Platform.isIOS;

  final FlutterTts _flutterTts;
  final bool _isIos;

  @override
  void setStartHandler(void Function() handler) {
    _flutterTts.setStartHandler(handler);
  }

  @override
  void setCompletionHandler(void Function() handler) {
    _flutterTts.setCompletionHandler(handler);
  }

  @override
  void setErrorHandler(void Function(Object error) handler) {
    _flutterTts.setErrorHandler((message) => handler(message as Object));
  }

  @override
  void setProgressHandler(void Function(int endOffset) handler) {
    _flutterTts.setProgressHandler(
      (text, start, end, word) => handler(end),
    );
  }

  @override
  Future<void> configureSession() async {
    if (!_isIos) {
      return;
    }
    // AVSpeechSynthesizer defaults to the `ambient` audio category, which iOS
    // silences the moment the screen locks and then stops delivering the
    // completion callback the coordinator relies on to advance. Share the
    // app's AVAudioSession (so we don't fight the just_audio / audio_service
    // session) and force the `playback` category so spoken audio keeps
    // rendering with the screen locked.
    await _flutterTts.setSharedInstance(true);
    await _flutterTts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      const [
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      ],
    );
  }

  @override
  Future<void> configure(VoiceProfile profile) async {
    await _flutterTts.setSpeechRate(_systemSpeechRate(profile.speed));
    await _flutterTts.setPitch(profile.pitch ?? 1);
    final voice = profile.voice;
    if (voice != null) {
      await _flutterTts.setVoice({'name': voice});
    }
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    await _flutterTts.setSpeechRate(_systemSpeechRate(speed));
  }

  @override
  Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }

  @override
  Future<void> pause() async {
    await _flutterTts.pause();
  }

  @override
  Future<void> stop() async {
    await _flutterTts.stop();
  }
}

double _systemSpeechRate(double multiplier) {
  // flutter_tts uses 0.5 as the cross-platform normal system speech rate.
  return (multiplier / 2).clamp(0.0, 1.0).toDouble();
}

final class SystemTtsAdapter
    implements
        SpeechProvider,
        DisposableSpeechProvider,
        AdjustableSpeechProvider {
  SystemTtsAdapter(this._engine) {
    _engine.setStartHandler(_onStarted);
    _engine.setCompletionHandler(_onCompleted);
    _engine.setErrorHandler(_onFailed);
    final engine = _engine;
    if (engine is ProgressReportingSystemTtsEngine) {
      (engine as ProgressReportingSystemTtsEngine).setProgressHandler(
        _onProgress,
      );
    }
  }

  final SystemTtsEngine _engine;
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  SpeechSegment? _segment;
  bool _sessionConfigured = false;
  // Absolute character offset (into the current segment) spoken so far, plus
  // the offset at which the in-flight speak() call began. Together they let
  // resume() continue near the pause point instead of restarting the segment.
  int _playedChars = 0;
  int _speakBase = 0;

  @override
  Stream<SpeechEvent> get events => _events.stream;

  @override
  Future<void> prepare(SpeechSegment segment, VoiceProfile profile) async {
    await _ensureSessionConfigured();
    _segment = segment;
    _playedChars = 0;
    _speakBase = 0;
    await _engine.configure(profile);
  }

  Future<void> _ensureSessionConfigured() async {
    if (_sessionConfigured) {
      return;
    }
    final engine = _engine;
    if (engine is SessionConfigurableSystemTtsEngine) {
      await (engine as SessionConfigurableSystemTtsEngine).configureSession();
    }
    // Set even when the engine is not session-configurable so we don't retry
    // the capability probe on every prepare.
    _sessionConfigured = true;
  }

  @override
  Future<void> play() {
    _playedChars = 0;
    return _speakFrom(0);
  }

  @override
  Future<void> pause() => _engine.pause();

  @override
  Future<void> resume() => _speakFrom(_playedChars);

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    final engine = _engine;
    if (engine is! AdjustableSystemTtsEngine) {
      throw StateError('System TTS engine does not support speed changes.');
    }
    await (engine as AdjustableSystemTtsEngine).setPlaybackSpeed(speed);
  }

  @override
  Future<void> stop() => _engine.stop();

  @override
  Future<void> dispose() async {
    await _engine.stop();
    await _events.close();
  }

  Future<void> _speakFrom(int offset) {
    final segment = _segment;
    if (segment == null) {
      throw StateError('No speech segment has been prepared.');
    }
    final text = segment.text;
    final start = offset.clamp(0, text.length).toInt();
    _speakBase = start;
    return _engine.speak(start == 0 ? text : text.substring(start));
  }

  void _onProgress(int endOffset) {
    _playedChars = _speakBase + endOffset;
  }

  void _onStarted() {
    final segment = _segment;
    if (segment != null) {
      _events.add(SpeechStarted(segmentId: segment.id));
    }
  }

  void _onCompleted() {
    final segment = _segment;
    _playedChars = 0;
    _speakBase = 0;
    if (segment != null) {
      _events.add(SpeechCompleted(segmentId: segment.id));
    }
  }

  void _onFailed(Object error) {
    final segment = _segment;
    if (segment != null) {
      _events.add(
        SpeechFailed(
          segmentId: segment.id,
          failure: AppFailure(error.toString()),
        ),
      );
    }
  }
}
