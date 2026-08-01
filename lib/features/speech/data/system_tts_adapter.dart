import 'dart:async';

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

final class FlutterSystemTtsEngine
    implements SystemTtsEngine, AdjustableSystemTtsEngine {
  FlutterSystemTtsEngine([FlutterTts? flutterTts])
    : _flutterTts = flutterTts ?? FlutterTts();

  final FlutterTts _flutterTts;

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
  Future<void> configure(VoiceProfile profile) async {
    await _flutterTts.setSpeechRate(profile.speed);
    await _flutterTts.setPitch(profile.pitch ?? 1);
    final voice = profile.voice;
    if (voice != null) {
      await _flutterTts.setVoice({'name': voice});
    }
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    await _flutterTts.setSpeechRate(speed);
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

final class SystemTtsAdapter
    implements
        SpeechProvider,
        DisposableSpeechProvider,
        AdjustableSpeechProvider {
  SystemTtsAdapter(this._engine) {
    _engine.setStartHandler(_onStarted);
    _engine.setCompletionHandler(_onCompleted);
    _engine.setErrorHandler(_onFailed);
  }

  final SystemTtsEngine _engine;
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  SpeechSegment? _segment;

  @override
  Stream<SpeechEvent> get events => _events.stream;

  @override
  Future<void> prepare(SpeechSegment segment, VoiceProfile profile) async {
    _segment = segment;
    await _engine.configure(profile);
  }

  @override
  Future<void> play() => _speakCurrent();

  @override
  Future<void> pause() => _engine.pause();

  @override
  Future<void> resume() => _speakCurrent();

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    final engine = _engine;
    if (engine is AdjustableSystemTtsEngine) {
      await (engine as AdjustableSystemTtsEngine).setPlaybackSpeed(speed);
    }
  }

  @override
  Future<void> stop() => _engine.stop();

  @override
  Future<void> dispose() async {
    await _engine.stop();
    await _events.close();
  }

  Future<void> _speakCurrent() {
    final segment = _segment;
    if (segment == null) {
      throw StateError('No speech segment has been prepared.');
    }
    return _engine.speak(segment.text);
  }

  void _onStarted() {
    final segment = _segment;
    if (segment != null) {
      _events.add(SpeechStarted(segmentId: segment.id));
    }
  }

  void _onCompleted() {
    final segment = _segment;
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
