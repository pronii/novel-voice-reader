import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/downloads/domain/cache_key.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_timeline.dart';
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

abstract interface class TimedAudioPlaybackEngine {
  Stream<PlaybackTimeline> get playbackTimeline;
}

abstract interface class AdjustableAudioPlaybackEngine {
  Future<void> setSpeed(double speed);
}

abstract interface class QueuedAudioPlaybackEngine {
  Future<void> queueNextFilePath(String path);

  Future<bool> promoteQueuedFilePath(String path);
}

final class JustAudioPlaybackEngine
    implements
        AudioPlaybackEngine,
        AdjustableAudioPlaybackEngine,
        QueuedAudioPlaybackEngine,
        TimedAudioPlaybackEngine {
  JustAudioPlaybackEngine([AudioPlayer? player])
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  String? _queuedPath;

  @override
  Stream<void> get completed => Stream<void>.multi((controller) {
    var previousIndex = _player.currentIndex ?? 0;
    final indexSubscription = _player.currentIndexStream.listen((index) {
      if (index != null && index > previousIndex) {
        controller.add(null);
      }
      if (index != null) {
        previousIndex = index;
      }
    }, onError: controller.addError);
    final stateSubscription = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        controller.add(null);
      }
    }, onError: controller.addError);
    controller.onCancel = () async {
      await indexSubscription.cancel();
      await stateSubscription.cancel();
    };
  });

  @override
  Stream<PlaybackTimeline> get playbackTimeline => _player.positionStream.map(
    (position) =>
        PlaybackTimeline(position: position, duration: _player.duration),
  );

  @override
  Future<void> setFilePath(String path) async {
    _queuedPath = null;
    await _player.setFilePath(path);
  }

  @override
  Future<void> queueNextFilePath(String path) async {
    if (_queuedPath == path) {
      return;
    }
    await _player.addAudioSource(AudioSource.file(path));
    _queuedPath = path;
  }

  @override
  Future<bool> promoteQueuedFilePath(String path) async {
    if (_queuedPath != path || _player.currentIndex != 1) {
      return false;
    }
    await _player.removeAudioSourceAt(0);
    _queuedPath = null;
    return true;
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

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
    implements
        SpeechProvider,
        DisposableSpeechProvider,
        AdjustableSpeechProvider,
        PrefetchingSpeechProvider,
        TimedSpeechProvider {
  CachedAudioSpeechProvider({required this.cache, required this.engine}) {
    _completionSubscription = engine.completed.listen((_) => _onCompleted());
  }

  final AudioCacheRepository cache;
  final AudioPlaybackEngine engine;
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  late final StreamSubscription<void> _completionSubscription;
  final Map<String, Future<File>> _inFlight = {};
  Future<void> _sourceUpdates = Future<void>.value();
  SpeechSegment? _segment;
  bool _started = false;
  int _prepareGeneration = 0;
  String? _queuedSegmentId;
  bool _nativePlaybackActive = false;

  @override
  Stream<SpeechEvent> get events => _events.stream;

  @override
  Stream<PlaybackTimeline> get playbackTimeline {
    final playbackEngine = engine;
    return playbackEngine is TimedAudioPlaybackEngine
        ? (playbackEngine as TimedAudioPlaybackEngine).playbackTimeline
        : const Stream<PlaybackTimeline>.empty();
  }

  @override
  Future<void> prepare(SpeechSegment segment, VoiceProfile profile) async {
    final generation = ++_prepareGeneration;
    try {
      final file = await _obtain(segment, profile);
      if (generation != _prepareGeneration) {
        return;
      }
      await _enqueueSourceUpdate(() async {
        if (generation != _prepareGeneration) {
          return;
        }
        final playbackEngine = engine;
        final promoted = playbackEngine is QueuedAudioPlaybackEngine &&
            _queuedSegmentId == segment.id &&
            await playbackEngine.promoteQueuedFilePath(file.path);
        if (!promoted) {
          await engine.setFilePath(file.path);
        }
        if (generation == _prepareGeneration) {
          _segment = segment;
          _started = false;
          _nativePlaybackActive = promoted;
          _queuedSegmentId = null;
        }
      });
    } catch (error) {
      if (generation != _prepareGeneration) {
        return;
      }
      final failure = error is AppFailure
          ? error
          : const AppFailure('云端语音播放准备失败');
      _events.add(SpeechFailed(segmentId: segment.id, failure: failure));
      rethrow;
    }
  }

  @override
  Future<void> prefetch(SpeechSegment segment, VoiceProfile profile) async {
    final file = await _obtain(segment, profile);
    final playbackEngine = engine;
    if (_segment != null && playbackEngine is QueuedAudioPlaybackEngine) {
      await _enqueueSourceUpdate(() async {
        await playbackEngine.queueNextFilePath(file.path);
        _queuedSegmentId = segment.id;
      });
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
    if (_nativePlaybackActive) {
      _nativePlaybackActive = false;
      return;
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
  Future<void> setPlaybackSpeed(double speed) async {
    final playbackEngine = engine;
    if (playbackEngine is! AdjustableAudioPlaybackEngine) {
      throw StateError('Audio playback engine does not support speed changes.');
    }
    await (playbackEngine as AdjustableAudioPlaybackEngine).setSpeed(speed);
  }

  @override
  Future<void> stop() async {
    _started = false;
    _nativePlaybackActive = false;
    await engine.stop();
  }

  @override
  Future<void> dispose() async {
    _prepareGeneration++;
    await _completionSubscription.cancel();
    await _sourceUpdates;
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

  Future<File> _obtain(SpeechSegment segment, VoiceProfile profile) {
    final key = CacheKey.forSegment(segment, profile);
    final existing = _inFlight[key];
    if (existing != null) {
      return existing;
    }

    late final Future<File> operation;
    operation = cache.obtain(segment, profile).whenComplete(() {
      if (identical(_inFlight[key], operation)) {
        _inFlight.remove(key);
      }
    });
    _inFlight[key] = operation;
    return operation;
  }

  Future<void> _enqueueSourceUpdate(Future<void> Function() update) {
    final operation = _sourceUpdates.then((_) => update());
    _sourceUpdates = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}
