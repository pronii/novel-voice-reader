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
  Stream<String> get completed;

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
  /// Appends [path] to the native playlist so the player advances into it by
  /// itself when the current item ends. The playlist may hold many look-ahead
  /// items — this is what keeps lock-screen playback continuous without a
  /// per-segment prepare() round-trip.
  Future<void> queueNextFilePath(String path);
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
  final List<String> _queuedPaths = [];

  @override
  Stream<String> get completed => Stream<String>.multi((controller) {
    var previousIndex = _player.currentIndex ?? 0;
    final indexSubscription = _player.currentIndexStream.listen((index) {
      if (index != null && index > previousIndex) {
        final sequence = _player.sequence;
        for (
          var completedIndex = previousIndex;
          completedIndex < index && completedIndex < sequence.length;
          completedIndex++
        ) {
          final uri = sequence[completedIndex].tag as String?;
          if (uri != null) {
            controller.add(uri);
          }
        }
      }
      if (index != null) {
        previousIndex = index;
      }
    }, onError: controller.addError);
    final stateSubscription = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        final index = _player.currentIndex ?? 0;
        final sequence = _player.sequence;
        if (index < sequence.length) {
          final path = sequence[index].tag as String?;
          if (path != null) {
            controller.add(path);
          }
        }
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
    // A hard (re)start: replace the whole native playlist with this one file.
    // Prefetch re-appends look-ahead items afterwards.
    _queuedPaths.clear();
    await _player.setAudioSource(AudioSource.file(path, tag: path));
  }

  @override
  Future<void> queueNextFilePath(String path) async {
    if (_queuedPaths.contains(path)) {
      return;
    }
    await _player.addAudioSource(AudioSource.file(path, tag: path));
    _queuedPaths.add(path);
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

class _PlaylistItem {
  const _PlaylistItem({required this.segment, required this.path});

  final SpeechSegment segment;
  final String path;
}

final class CachedAudioSpeechProvider
    implements
        SpeechProvider,
        DisposableSpeechProvider,
        AdjustableSpeechProvider,
        PrefetchingSpeechProvider,
        PlaylistSpeechProvider,
        CacheOnlySpeechProvider,
        TimedSpeechProvider {
  CachedAudioSpeechProvider({required this.cache, required this.engine}) {
    _completionSubscription = engine.completed.listen(_onCompleted);
  }

  final SpeechAudioCache cache;
  final AudioPlaybackEngine engine;
  final _events = StreamController<SpeechEvent>.broadcast(sync: true);
  late final StreamSubscription<String> _completionSubscription;
  final Map<String, Future<File>> _inFlight = {};
  Future<void> _sourceUpdates = Future<void>.value();

  /// The segment currently loaded in the native player. After a native
  /// auto-advance this points at the segment the player advanced into; once the
  /// queue fully drains it stays on the last-played segment so resume() can
  /// replay it and so the coordinator sees the next target as a fresh prepare.
  _PlaylistItem? _current;

  /// Look-ahead segments appended to the native playlist, in play order. The
  /// native player advances into these by itself; Dart never calls prepare()
  /// to start them, keeping lock-screen playback continuous.
  final List<_PlaylistItem> _queued = [];
  final Map<String, SpeechSegment> _segmentsByPath = {};
  bool _started = false;
  int _prepareGeneration = 0;

  @override
  Stream<SpeechEvent> get events => _events.stream;

  @override
  String? get currentSegmentId => _current?.segment.id;

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
      _rememberSegment(file.path, segment);
      if (generation != _prepareGeneration) {
        return;
      }
      await _enqueueSourceUpdate(() async {
        if (generation != _prepareGeneration) {
          return;
        }
        await engine.setFilePath(file.path);
        _current = _PlaylistItem(segment: segment, path: file.path);
        _queued.clear();
        _started = false;
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
  Future<bool> prepareCached(SpeechSegment segment, VoiceProfile profile) async {
    final audioCache = cache;
    if (audioCache is! LookupSpeechAudioCache) {
      // The active cache can't answer a lookup without synthesizing, so treat
      // this as a miss rather than reaching the network on a locked screen.
      return false;
    }
    final generation = ++_prepareGeneration;
    final file = await (audioCache as LookupSpeechAudioCache).lookup(
      segment,
      profile,
    );
    if (file == null || generation != _prepareGeneration) {
      return false;
    }
    _rememberSegment(file.path, segment);
    var ready = false;
    await _enqueueSourceUpdate(() async {
      if (generation != _prepareGeneration) {
        return;
      }
      await engine.setFilePath(file.path);
      _current = _PlaylistItem(segment: segment, path: file.path);
      _queued.clear();
      _started = false;
      ready = true;
    });
    return ready;
  }

  @override
  Future<void> prefetch(SpeechSegment segment, VoiceProfile profile) async {
    final generation = _prepareGeneration;
    final file = await _obtain(segment, profile);
    if (generation != _prepareGeneration) {
      return;
    }
    final playbackEngine = engine;
    if (_current == null || playbackEngine is! QueuedAudioPlaybackEngine) {
      // Nothing is playing yet (or the engine can't queue): the fetch above
      // already warmed the audio cache, which is all prefetch owes when there
      // is no active native playlist to append to.
      return;
    }
    final queuedEngine = playbackEngine as QueuedAudioPlaybackEngine;
    await _enqueueSourceUpdate(() async {
      if (generation != _prepareGeneration || _current == null) {
        return;
      }
      // Deep look-ahead: append every prefetched segment to the native
      // playlist so just_audio advances through them by itself while the
      // screen is locked. No 1-deep cap — the coordinator bounds how far
      // ahead it prefetches by wall-clock time.
      if (_current!.segment.id == segment.id ||
          _queued.any((item) => item.segment.id == segment.id)) {
        return;
      }
      _rememberSegment(file.path, segment);
      await queuedEngine.queueNextFilePath(file.path);
      _queued.add(_PlaylistItem(segment: segment, path: file.path));
    });
  }

  @override
  Future<void> play() async {
    final current = _current;
    if (current == null) {
      throw StateError('No speech segment has been prepared.');
    }
    if (!_started) {
      _started = true;
      _events.add(SpeechStarted(segmentId: current.segment.id));
    }
    unawaited(_playEngine());
  }

  @override
  Future<void> pause() => engine.pause();

  @override
  Future<void> resume() async {
    if (_current == null) {
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
    _current = null;
    _queued.clear();
    _segmentsByPath.clear();
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

  void _onCompleted([String? path]) {
    final _PlaylistItem? finished;
    if (path == null || (_current != null && _current!.path == path)) {
      finished = _current;
    } else {
      // A path that isn't the current head (e.g. a duplicate terminal signal
      // for an already-advanced item): attribute the completion via the map so
      // the coordinator still hears it, but leave the native cursor untouched.
      final segment = _segmentsByPath[path];
      if (segment != null) {
        _events.add(SpeechCompleted(segmentId: segment.id));
      }
      return;
    }
    if (finished == null) {
      return;
    }
    _started = false;
    _events.add(SpeechCompleted(segmentId: finished.segment.id));
    if (_queued.isNotEmpty) {
      // just_audio has already advanced into the next queued file. Promote it
      // to current — no prepare() round-trip — and announce it started so the
      // coordinator's progress/prefetch bookkeeping tracks the native cursor.
      _current = _queued.removeAt(0);
      _started = true;
      _events.add(SpeechStarted(segmentId: _current!.segment.id));
    }
    // When the queue is empty we keep _current on the finished segment: resume()
    // can replay it, and the coordinator's next target differs from it, so it
    // performs a fresh (cache-only when locked) prepare instead of skipping.
  }

  void _rememberSegment(String path, SpeechSegment segment) {
    _segmentsByPath[path] = segment;
    while (_segmentsByPath.length > 8) {
      _segmentsByPath.remove(_segmentsByPath.keys.first);
    }
  }

  Future<void> _playEngine() async {
    try {
      await engine.play();
    } catch (_) {
      final current = _current;
      if (current != null) {
        _events.add(
          SpeechFailed(
            segmentId: current.segment.id,
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
