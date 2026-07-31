import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

abstract interface class AudioPlaybackEngine {
  Stream<void> get completed;

  Future<void> setFilePath(String path);

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> dispose();
}

final class JustAudioPlaybackEngine implements AudioPlaybackEngine {
  JustAudioPlaybackEngine([AudioPlayer? player])
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<void> get completed => _player.processingStateStream
      .where((state) => state == ProcessingState.completed)
      .map<void>((_) {});

  @override
  Future<void> setFilePath(String path) async {
    await _player.setFilePath(path);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

final class CachedAudioSpeechProvider
    implements SpeechProvider, DisposableSpeechProvider {
  CachedAudioSpeechProvider({required this.cache, required this.engine}) {
    _completionSubscription = engine.completed.listen((_) => _onCompleted());
  }

  final AudioCacheRepository cache;
  final AudioPlaybackEngine engine;
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  late final StreamSubscription<void> _completionSubscription;
  SpeechSegment? _segment;
  bool _started = false;

  @override
  Stream<SpeechEvent> get events => _events.stream;

  @override
  Future<void> prepare(SpeechSegment segment, VoiceProfile profile) async {
    _segment = segment;
    _started = false;
    try {
      final file = await cache.obtain(segment, profile);
      await engine.setFilePath(file.path);
    } catch (error) {
      final failure = error is AppFailure
          ? error
          : const AppFailure('云端语音播放准备失败');
      _events.add(SpeechFailed(segmentId: segment.id, failure: failure));
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    final segment = _segment;
    if (segment == null) {
      throw StateError('No speech segment has been prepared.');
    }
    if (!_started) {
      _started = true;
      _events.add(SpeechStarted(segmentId: segment.id));
    }
    unawaited(_playEngine());
  }

  @override
  Future<void> pause() => engine.pause();

  @override
  Future<void> resume() async {
    if (_segment == null) {
      throw StateError('No speech segment has been prepared.');
    }
    unawaited(_playEngine());
  }

  @override
  Future<void> stop() async {
    _started = false;
    await engine.stop();
  }

  @override
  Future<void> dispose() async {
    await _completionSubscription.cancel();
    await engine.dispose();
    await _events.close();
  }

  void _onCompleted() {
    final segment = _segment;
    if (segment != null) {
      _started = false;
      _events.add(SpeechCompleted(segmentId: segment.id));
    }
  }

  Future<void> _playEngine() async {
    try {
      await engine.play();
    } catch (_) {
      final segment = _segment;
      if (segment != null) {
        _events.add(
          SpeechFailed(
            segmentId: segment.id,
            failure: const AppFailure('云端音频播放失败'),
          ),
        );
      }
    }
  }
}
