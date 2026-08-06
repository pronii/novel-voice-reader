import 'dart:async';
import 'dart:math';

import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_timeline.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

abstract interface class PlaybackController {
  PlaybackCursor? get cursor;

  Future<void> playFrom(PlaybackCursor cursor);

  Future<void> pause();

  Future<void> resume();

  Future<void> setSpeed(double speed);

  Future<void> nextParagraph();

  Future<void> previousParagraph();
}

final class PlaybackParagraph {
  const PlaybackParagraph({
    required this.id,
    required this.cursor,
    required this.text,
  });

  final int id;
  final PlaybackCursor cursor;
  final String text;
}

abstract interface class PlaybackParagraphSource {
  Future<PlaybackParagraph?> at(PlaybackCursor cursor);

  Future<PlaybackParagraph?> nextAfter(PlaybackCursor cursor);
}

abstract interface class PlaybackChapterTextSource {
  Future<int> remainingCharactersInChapter(PlaybackCursor cursor);
}

abstract interface class PlaybackProgressRepository {
  Future<void> confirm(PlaybackCursor cursor);
}

enum PlaybackActivity { playing, paused, completed, failed }

final class PlaybackCoordinator implements PlaybackController {
  factory PlaybackCoordinator({
    required SpeechProvider provider,
    required PlaybackProgressRepository progress,
    required PlaybackParagraphSource paragraphs,
    required VoiceProfile voiceProfile,
    SpeechSegmenter segmenter = const SpeechSegmenter(),
    void Function(AppFailure failure)? onFailure,
  }) {
    return PlaybackCoordinator._(
      provider,
      progress,
      paragraphs,
      voiceProfile,
      segmenter,
      onFailure,
    );
  }

  PlaybackCoordinator._(
    this._provider,
    this._progress,
    this._paragraphs,
    this._voiceProfile,
    this._segmenter,
    this._onFailure,
  ) {
    _subscription = _provider.events.listen((event) {
      unawaited(_handleSpeechEvent(event));
    });
    final provider = _provider;
    if (provider is TimedSpeechProvider) {
      _timelineSubscription = (provider as TimedSpeechProvider).playbackTimeline
          .listen((timeline) {
            if (_acceptTimeline && !_timelineChanges.isClosed) {
              _timelineChanges.add(_enrichTimeline(timeline));
            }
          });
    }
  }

  final SpeechProvider _provider;
  final PlaybackProgressRepository _progress;
  final PlaybackParagraphSource _paragraphs;
  final VoiceProfile _voiceProfile;
  final SpeechSegmenter _segmenter;
  final void Function(AppFailure failure)? _onFailure;
  late final StreamSubscription<SpeechEvent> _subscription;
  StreamSubscription<PlaybackTimeline>? _timelineSubscription;
  final StreamController<PlaybackCursor> _cursorChanges =
      StreamController<PlaybackCursor>.broadcast(sync: true);
  final StreamController<PlaybackTimeline> _timelineChanges =
      StreamController<PlaybackTimeline>.broadcast(sync: true);
  final StreamController<PlaybackActivity> _activityChanges =
      StreamController<PlaybackActivity>.broadcast(sync: true);

  PlaybackCursor? _cursor;
  List<SpeechSegment> _segments = const [];
  int _segmentIndex = 0;
  double _speed = 1;
  int _playbackGeneration = 0;
  Future<void> _providerTransactions = Future<void>.value();
  Future<void>? _activePrefetch;
  int? _queuedPrefetchGeneration;
  bool _disposing = false;
  bool _acceptTimeline = false;
  int? _chapterCharacters;

  @override
  PlaybackCursor? get cursor => _cursor;

  Stream<PlaybackCursor> get cursorChanges => _cursorChanges.stream;

  Stream<PlaybackTimeline> get timelineChanges => _timelineChanges.stream;

  Stream<PlaybackActivity> get activityChanges => _activityChanges.stream;

  @override
  Future<void> playFrom(PlaybackCursor cursor) async {
    final generation = ++_playbackGeneration;
    final paragraph = await _paragraphs.at(cursor);
    if (generation != _playbackGeneration) {
      return;
    }
    if (paragraph == null) {
      throw StateError('Playback cursor does not point to a paragraph.');
    }
    await _startParagraph(paragraph, generation: generation);
  }

  @override
  Future<void> pause() async {
    final cursor = _cursor;
    if (cursor != null) {
      await _progress.confirm(cursor);
    }
    await _provider.pause();
    _publishActivity(PlaybackActivity.paused);
  }

  @override
  Future<void> resume() async {
    await _provider.resume();
    if (_cursor != null) {
      _publishActivity(PlaybackActivity.playing);
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    final provider = _provider;
    if (provider is AdjustableSpeechProvider) {
      await (provider as AdjustableSpeechProvider).setPlaybackSpeed(speed);
    }
    _speed = speed;
  }

  @override
  Future<void> nextParagraph() async {
    final current = _cursor;
    if (current == null) {
      return;
    }
    final next = await _paragraphs.nextAfter(current);
    if (next != null) {
      await _progress.confirm(next.cursor);
      await _startParagraph(next);
    }
  }

  @override
  Future<void> previousParagraph() async {
    final current = _cursor;
    if (current == null || current.paragraphIndex == 0) {
      return;
    }
    final previous = await _paragraphs.at(
      PlaybackCursor(
        chapterId: current.chapterId,
        paragraphIndex: current.paragraphIndex - 1,
      ),
    );
    if (previous != null) {
      await _progress.confirm(previous.cursor);
      await _startParagraph(previous);
    }
  }

  Future<void> dispose() async {
    _disposing = true;
    _acceptTimeline = false;
    _playbackGeneration++;
    _queuedPrefetchGeneration = null;
    try {
      await _subscription.cancel();
      await _timelineSubscription?.cancel();
      await _activePrefetch;
      await _providerTransactions;
      final provider = _provider;
      if (provider is DisposableSpeechProvider) {
        await (provider as DisposableSpeechProvider).dispose();
      } else {
        await provider.stop();
      }
    } finally {
      await _cursorChanges.close();
      await _timelineChanges.close();
      await _activityChanges.close();
    }
  }

  Future<void> _startParagraph(
    PlaybackParagraph paragraph, {
    int? generation,
  }) async {
    generation ??= ++_playbackGeneration;
    int? chapterCharacters;
    final paragraphs = _paragraphs;
    if (paragraphs is PlaybackChapterTextSource) {
      chapterCharacters = await (paragraphs as PlaybackChapterTextSource)
          .remainingCharactersInChapter(paragraph.cursor);
      if (generation != _playbackGeneration) {
        return;
      }
    }
    final segments = _segmenter.split(
      paragraphId: paragraph.id,
      text: paragraph.text,
      maxCharacters: _voiceProfile.maxSegmentCharacters,
    );
    if (!await _takeOverParagraph(
      segments,
      chapterCharacters,
      generation,
    )) {
      return;
    }
    _cursor = paragraph.cursor;
    if (!_cursorChanges.isClosed) {
      _cursorChanges.add(paragraph.cursor);
    }
    _schedulePrefetch(generation);
  }

  Future<bool> _takeOverParagraph(
    List<SpeechSegment> segments,
    int? chapterCharacters,
    int generation,
  ) {
    return _runProviderTransaction(() async {
      if (generation != _playbackGeneration) {
        return false;
      }
      _chapterCharacters = chapterCharacters;
      _segments = segments;
      _segmentIndex = 0;
      return _prepareAndPlayCurrentSegmentLocked(generation);
    });
  }

  Future<bool> _prepareAndPlayCurrentSegment(int generation) {
    return _runProviderTransaction(
      () => _prepareAndPlayCurrentSegmentLocked(generation),
    );
  }

  Future<bool> _prepareAndPlayCurrentSegmentLocked(int generation) async {
    if (generation != _playbackGeneration) {
      return false;
    }
    _acceptTimeline = false;
    _timelineChanges.add(_enrichTimeline(PlaybackTimeline.zero));
    final segment = _segments[_segmentIndex];
    await _provider.prepare(segment, _voiceProfile);
    if (generation != _playbackGeneration) {
      return false;
    }
    _acceptTimeline = true;
    _timelineChanges.add(_enrichTimeline(PlaybackTimeline.zero));
    final provider = _provider;
    if (provider is AdjustableSpeechProvider) {
      await (provider as AdjustableSpeechProvider).setPlaybackSpeed(_speed);
      if (generation != _playbackGeneration) {
        return false;
      }
    }
    await _provider.play();
    final current = generation == _playbackGeneration;
    if (current) {
      _publishActivity(PlaybackActivity.playing);
    }
    return current;
  }

  Future<T> _runProviderTransaction<T>(Future<T> Function() operation) {
    final result = _providerTransactions.then((_) => operation());
    _providerTransactions = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _handleSpeechEvent(SpeechEvent event) async {
    if (event is SpeechFailed) {
      if (_segments.isEmpty || event.segmentId != _segments[_segmentIndex].id) {
        return;
      }
      _acceptTimeline = false;
      _timelineChanges.add(PlaybackTimeline.zero);
      _publishActivity(PlaybackActivity.failed);
      _onFailure?.call(event.failure);
      return;
    }
    if (event is! SpeechCompleted ||
        _segments.isEmpty ||
        event.segmentId != _segments[_segmentIndex].id) {
      return;
    }
    final generation = _playbackGeneration;
    if (_segmentIndex + 1 < _segments.length) {
      _segmentIndex++;
      if (!await _prepareAndPlayCurrentSegment(generation)) {
        return;
      }
      _schedulePrefetch(generation);
      return;
    }

    final current = _cursor;
    if (current == null) {
      return;
    }
    final next = await _paragraphs.nextAfter(current);
    if (generation != _playbackGeneration) {
      return;
    }
    if (next == null) {
      await _progress.confirm(current);
      if (generation != _playbackGeneration) {
        return;
      }
      _acceptTimeline = false;
      _timelineChanges.add(PlaybackTimeline.zero);
      _publishActivity(PlaybackActivity.completed);
      return;
    }
    await _progress.confirm(next.cursor);
    if (generation != _playbackGeneration) {
      return;
    }
    await _startParagraph(next);
  }

  void _schedulePrefetch(int generation) {
    final provider = _provider;
    if (provider is! PrefetchingSpeechProvider || _disposing) {
      return;
    }
    _queuedPrefetchGeneration = generation;
    if (_activePrefetch == null) {
      _startQueuedPrefetch(provider as PrefetchingSpeechProvider);
    }
  }

  void _startQueuedPrefetch(PrefetchingSpeechProvider provider) {
    final generation = _queuedPrefetchGeneration;
    if (generation == null || _disposing) {
      return;
    }
    _queuedPrefetchGeneration = null;
    final operation = _prefetchNext(provider, generation);
    _activePrefetch = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_activePrefetch, operation)) {
          _activePrefetch = null;
        }
        if (!_disposing && _queuedPrefetchGeneration != null) {
          _startQueuedPrefetch(provider);
        }
      }),
    );
  }

  Future<void> _prefetchNext(
    PrefetchingSpeechProvider provider,
    int generation,
  ) async {
    try {
      SpeechSegment? segment;
      if (_segmentIndex + 1 < _segments.length) {
        segment = _segments[_segmentIndex + 1];
      } else {
        final current = _cursor;
        if (current == null) {
          return;
        }
        final next = await _paragraphs.nextAfter(current);
        if (next == null || generation != _playbackGeneration) {
          return;
        }
        final segments = _segmenter.split(
          paragraphId: next.id,
          text: next.text,
          maxCharacters: _voiceProfile.maxSegmentCharacters,
        );
        if (segments.isNotEmpty) {
          segment = segments.first;
        }
      }
      if (segment != null && generation == _playbackGeneration) {
        await provider.prefetch(segment, _voiceProfile);
      }
    } catch (_) {
      // Normal prepare remains the authoritative fallback and error path.
    }
  }

  void _publishActivity(PlaybackActivity activity) {
    if (!_activityChanges.isClosed) {
      _activityChanges.add(activity);
    }
  }

  PlaybackTimeline _enrichTimeline(PlaybackTimeline timeline) {
    final chapterCharacters = _chapterCharacters;
    if (chapterCharacters == null || _segments.isEmpty) {
      return timeline;
    }
    const fallbackMicrosPerCharacter = 240000;
    final completedCharacters = _segments
        .take(_segmentIndex)
        .fold<int>(0, (total, segment) => total + segment.text.runes.length);
    final currentCharacters = _segments[_segmentIndex].text.runes.length;
    final laterCharacters = max(
      0,
      chapterCharacters - completedCharacters - currentCharacters,
    );
    final duration = timeline.duration;
    final position = timeline.position;
    final microsPerCharacter = duration == null || currentCharacters == 0
        ? fallbackMicrosPerCharacter
        : duration.inMicroseconds ~/ currentCharacters;
    final currentRemaining = duration == null
        ? Duration(microseconds: currentCharacters * microsPerCharacter)
        : Duration(
            microseconds: max(
              0,
              duration.inMicroseconds - position.inMicroseconds,
            ),
          );
    final chapterRemaining = currentRemaining +
        Duration(microseconds: laterCharacters * microsPerCharacter);
    return PlaybackTimeline(
      position: position,
      duration: duration,
      chapterRemaining: chapterRemaining,
    );
  }
}
