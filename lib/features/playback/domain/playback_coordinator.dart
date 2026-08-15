import 'dart:async';
import 'dart:math';

import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_timeline.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

/// Schedules a one-shot watchdog timer. Injectable so tests can fire timeouts
/// deterministically instead of waiting on wall-clock time.
typedef WatchdogTimerFactory =
    Timer Function(Duration duration, void Function() onTimeout);

Timer _defaultScheduleWatchdog(Duration duration, void Function() onTimeout) =>
    Timer(duration, onTimeout);

/// Delays a retry attempt. Injectable so tests can make backoff instant instead
/// of waiting on wall-clock time.
typedef PlaybackRetryDelay = Future<void> Function(Duration duration);

Future<void> _defaultRetryDelay(Duration duration) =>
    Future<void>.delayed(duration);


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
    Duration watchdogGrace = const Duration(seconds: 15),
    int maxSegmentRetries = 2,
    WatchdogTimerFactory scheduleWatchdog = _defaultScheduleWatchdog,
    PlaybackRetryDelay retryDelay = _defaultRetryDelay,
  }) {
    return PlaybackCoordinator._(
      provider,
      progress,
      paragraphs,
      voiceProfile,
      segmenter,
      onFailure,
      watchdogGrace,
      maxSegmentRetries,
      scheduleWatchdog,
      retryDelay,
    );
  }

  PlaybackCoordinator._(
    this._provider,
    this._progress,
    this._paragraphs,
    this._voiceProfile,
    this._segmenter,
    this._onFailure,
    this._watchdogGrace,
    this._maxSegmentRetries,
    this._scheduleWatchdog,
    this._retryDelay,
  ) {
    _subscription = _provider.events.listen((event) {
      _speechEventTransactions = _speechEventTransactions.then<void>(
        (_) => _handleSpeechEvent(event),
        onError: (Object _, StackTrace _) => _handleSpeechEvent(event),
      );
      unawaited(_speechEventTransactions);
    });
    final provider = _provider;
    if (provider is TimedSpeechProvider) {
      _timelineSubscription = (provider as TimedSpeechProvider).playbackTimeline
          .listen((timeline) {
            if (_acceptTimeline && !_timelineChanges.isClosed) {
              _timelineChanges.add(_enrichTimeline(timeline));
              _extendWatchdogForTimeline(timeline);
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
  final Duration _watchdogGrace;
  final int _maxSegmentRetries;
  final WatchdogTimerFactory _scheduleWatchdog;
  final PlaybackRetryDelay _retryDelay;
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
  int _continuationEpoch = 0;
  int? _activeContinuationEpoch;
  Future<void> _providerTransactions = Future<void>.value();
  Future<void> _speechEventTransactions = Future<void>.value();
  Future<void>? _activePrefetch;
  int? _queuedPrefetchEpoch;
  bool _disposing = false;
  bool _paused = false;
  bool _acceptTimeline = false;
  int? _chapterCharacters;
  Timer? _watchdog;
  int _segmentRetries = 0;

  @override
  PlaybackCursor? get cursor => _cursor;

  Stream<PlaybackCursor> get cursorChanges => _cursorChanges.stream;

  Stream<PlaybackTimeline> get timelineChanges => _timelineChanges.stream;

  Stream<PlaybackActivity> get activityChanges => _activityChanges.stream;

  @override
  Future<void> playFrom(PlaybackCursor cursor) async {
    _paused = false;
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
    _paused = true;
    _cancelWatchdog();
    final cursor = _cursor;
    if (cursor != null) {
      await _progress.confirm(cursor);
    }
    await _runProviderTransaction(() => _provider.pause());
    _publishActivity(PlaybackActivity.paused);
  }

  @override
  Future<void> resume() async {
    _paused = false;
    await _runProviderTransaction(() => _provider.resume());
    if (_cursor != null) {
      _publishActivity(PlaybackActivity.playing);
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    final provider = _provider;
    if (provider is AdjustableSpeechProvider) {
      await _runProviderTransaction(
        () => (provider as AdjustableSpeechProvider).setPlaybackSpeed(speed),
      );
    }
    // Retain the speed only after the provider accepts it, so a rejected change
    // doesn't leak into the next segment's prepare.
    _speed = speed;
  }

  @override
  Future<void> nextParagraph() async {
    final current = _cursor;
    if (current == null) {
      return;
    }
    _paused = false;
    final next = await _paragraphs.nextAfter(current);
    if (next != null && await _startParagraph(next)) {
      await _progress.confirm(next.cursor);
    }
  }

  @override
  Future<void> previousParagraph() async {
    final current = _cursor;
    if (current == null || current.paragraphIndex == 0) {
      return;
    }
    _paused = false;
    final previous = await _paragraphs.at(
      PlaybackCursor(
        chapterId: current.chapterId,
        paragraphIndex: current.paragraphIndex - 1,
      ),
    );
    if (previous != null && await _startParagraph(previous)) {
      await _progress.confirm(previous.cursor);
    }
  }

  Future<void> dispose() async {
    _disposing = true;
    _acceptTimeline = false;
    _cancelWatchdog();
    _playbackGeneration++;
    _continuationEpoch++;
    _queuedPrefetchEpoch = null;
    try {
      await _subscription.cancel();
      await _speechEventTransactions;
      await _timelineSubscription?.cancel();
      await _activePrefetch;
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

  Future<bool> _startParagraph(
    PlaybackParagraph paragraph, {
    int? generation,
    int? continuationEpoch,
  }) async {
    if (continuationEpoch == null) {
      generation ??= ++_playbackGeneration;
    }
    int? chapterCharacters;
    final paragraphs = _paragraphs;
    if (paragraphs is PlaybackChapterTextSource) {
      chapterCharacters = await (paragraphs as PlaybackChapterTextSource)
          .remainingCharactersInChapter(paragraph.cursor);
    }
    if (continuationEpoch == null
        ? generation != _playbackGeneration
        : !_ownsContinuation(continuationEpoch)) {
      return false;
    }
    final segments = _segmenter.split(
      paragraphId: paragraph.id,
      text: paragraph.text,
      maxCharacters: _voiceProfile.maxSegmentCharacters,
    );
    if (segments.isEmpty) {
      // A paragraph with no speakable text (blank line / whitespace) must not
      // stall playback — skip straight to the next paragraph.
      final next = await _paragraphs.nextAfter(paragraph.cursor);
      if (next == null ||
          (continuationEpoch == null
              ? generation != _playbackGeneration
              : !_ownsContinuation(continuationEpoch))) {
        return false;
      }
      return _startParagraph(
        next,
        generation: generation,
        continuationEpoch: continuationEpoch,
      );
    }
    final takeoverEpoch = continuationEpoch ?? ++_continuationEpoch;
    if (!await _takeOverParagraph(
      segments,
      chapterCharacters,
      generation,
      takeoverEpoch,
    )) {
      return false;
    }
    _cursor = paragraph.cursor;
    if (!_cursorChanges.isClosed) {
      _cursorChanges.add(paragraph.cursor);
    }
    _schedulePrefetch(takeoverEpoch);
    return true;
  }

  Future<bool> _takeOverParagraph(
    List<SpeechSegment> segments,
    int? chapterCharacters,
    int? generation,
    int continuationEpoch,
  ) {
    return _runProviderTransaction(() async {
      if (continuationEpoch != _continuationEpoch ||
          (generation == null
              ? !_ownsContinuation(continuationEpoch)
              : generation != _playbackGeneration)) {
        return false;
      }
      _chapterCharacters = chapterCharacters;
      _segments = segments;
      _segmentIndex = 0;
      _segmentRetries = 0;
      _activeContinuationEpoch = continuationEpoch;
      return _prepareAndPlaySegmentLocked(
        continuationEpoch,
        segments.first,
      );
    });
  }

  Future<bool> _prepareAndPlayContinuation(
    int continuationEpoch,
    int segmentIndex,
    SpeechSegment segment,
  ) {
    return _runProviderTransaction(() async {
      if (!_ownsContinuation(continuationEpoch)) {
        return false;
      }
      _segmentIndex = segmentIndex;
      return _prepareAndPlaySegmentLocked(continuationEpoch, segment);
    });
  }

  Future<bool> _prepareAndPlaySegmentLocked(
    int continuationEpoch,
    SpeechSegment segment,
  ) async {
    if (!_ownsContinuation(continuationEpoch)) {
      return false;
    }
    _cancelWatchdog();
    _acceptTimeline = false;
    _timelineChanges.add(_enrichTimeline(PlaybackTimeline.zero));
    await _provider.prepare(segment, _voiceProfile);
    if (!_ownsContinuation(continuationEpoch)) {
      return false;
    }
    _acceptTimeline = true;
    _timelineChanges.add(_enrichTimeline(PlaybackTimeline.zero));
    final provider = _provider;
    if (provider is AdjustableSpeechProvider) {
      await (provider as AdjustableSpeechProvider).setPlaybackSpeed(_speed);
      if (!_ownsContinuation(continuationEpoch)) {
        return false;
      }
    }
    await _provider.play();
    final current = _ownsContinuation(continuationEpoch);
    if (current) {
      _publishActivity(PlaybackActivity.playing);
      _armWatchdog(continuationEpoch, segment);
    }
    return current;
  }

  bool _ownsContinuation(int continuationEpoch) {
    return continuationEpoch == _continuationEpoch &&
        continuationEpoch == _activeContinuationEpoch;
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
    final continuationEpoch = _activeContinuationEpoch;
    if (continuationEpoch == null ||
        !_ownsContinuation(continuationEpoch)) {
      return;
    }
    if (event is SpeechFailed) {
      if (_segments.isEmpty || event.segmentId != _segments[_segmentIndex].id) {
        return;
      }
      if (!_paused && _segmentRetries < _maxSegmentRetries) {
        _segmentRetries++;
        // A transient synth/playback failure (a momentary network or audio
        // session blip, common right after the screen locks) should retry the
        // current segment rather than stopping playback dead. Back off first so
        // a suspended-network window on a locked screen has time to recover
        // before we burn through the retry budget and surface the banner.
        await _retryDelay(_retryBackoff(_segmentRetries));
        if (_paused || !_ownsContinuation(continuationEpoch)) {
          return;
        }
        if (await _prepareAndPlayContinuation(
          continuationEpoch,
          _segmentIndex,
          _segments[_segmentIndex],
        )) {
          _schedulePrefetch(continuationEpoch);
        }
        return;
      }
      _segmentRetries = 0;
      _cancelWatchdog();
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
    if (_paused) {
      // A completion event that raced with pause() must not silently resume
      // playback by auto-advancing to the next segment/paragraph.
      return;
    }
    _cancelWatchdog();
    await _advanceAfterSegmentCompleted(continuationEpoch);
  }

  /// Advances to the next segment (or paragraph) once the current segment has
  /// finished — either because the provider reported completion or because the
  /// watchdog gave up waiting for a completion that never arrived.
  Future<void> _advanceAfterSegmentCompleted(int continuationEpoch) async {
    _segmentRetries = 0;
    if (_segmentIndex + 1 < _segments.length) {
      final nextSegmentIndex = _segmentIndex + 1;
      final nextSegment = _segments[nextSegmentIndex];
      if (!await _prepareAndPlayContinuation(
        continuationEpoch,
        nextSegmentIndex,
        nextSegment,
      )) {
        return;
      }
      _schedulePrefetch(continuationEpoch);
      return;
    }

    final current = _cursor;
    if (current == null) {
      return;
    }
    final next = await _paragraphs.nextAfter(current);
    if (!_ownsContinuation(continuationEpoch)) {
      return;
    }
    if (next == null) {
      await _progress.confirm(current);
      if (!_ownsContinuation(continuationEpoch)) {
        return;
      }
      _cancelWatchdog();
      _acceptTimeline = false;
      _timelineChanges.add(PlaybackTimeline.zero);
      _publishActivity(PlaybackActivity.completed);
      return;
    }
    if (await _startParagraph(next, continuationEpoch: continuationEpoch)) {
      await _progress.confirm(next.cursor);
    }
  }

  void _armWatchdog(int continuationEpoch, SpeechSegment segment) {
    _cancelWatchdog();
    if (_disposing) {
      return;
    }
    final segmentIndex = _segmentIndex;
    _watchdog = _scheduleWatchdog(_watchdogTimeoutFor(segment), () {
      // Serialise with real speech events so a timeout that races an actual
      // completion (or supersession) is re-checked under the same ownership
      // guards and becomes a no-op if the segment already advanced.
      _speechEventTransactions = _speechEventTransactions.then<void>(
        (_) => _onWatchdogTimeout(continuationEpoch, segmentIndex),
        onError: (Object _, StackTrace _) =>
            _onWatchdogTimeout(continuationEpoch, segmentIndex),
      );
      unawaited(_speechEventTransactions);
    });
  }

  void _cancelWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  Duration _watchdogTimeoutFor(SpeechSegment segment) {
    const microsPerCharacter = 240000;
    final characters = segment.text.runes.length;
    final speed = _speed <= 0 ? 1.0 : _speed;
    final estimate = Duration(
      microseconds: (characters * microsPerCharacter / speed).round(),
    );
    return estimate + _watchdogGrace;
  }

  void _extendWatchdogForTimeline(PlaybackTimeline timeline) {
    // A cloud segment that is genuinely playing but longer than the character
    // estimate must not be falsely retried: while positions keep arriving,
    // push the deadline out to the real remaining duration plus grace.
    if (_watchdog == null) {
      return;
    }
    final continuationEpoch = _activeContinuationEpoch;
    if (continuationEpoch == null || !_ownsContinuation(continuationEpoch)) {
      return;
    }
    final duration = timeline.duration;
    if (duration == null || timeline.position >= duration) {
      return;
    }
    final remaining = duration - timeline.position + _watchdogGrace;
    final segmentIndex = _segmentIndex;
    _cancelWatchdog();
    _watchdog = _scheduleWatchdog(remaining, () {
      _speechEventTransactions = _speechEventTransactions.then<void>(
        (_) => _onWatchdogTimeout(continuationEpoch, segmentIndex),
        onError: (Object _, StackTrace _) =>
            _onWatchdogTimeout(continuationEpoch, segmentIndex),
      );
      unawaited(_speechEventTransactions);
    });
  }

  Future<void> _onWatchdogTimeout(int continuationEpoch, int segmentIndex) async {
    if (_paused ||
        _disposing ||
        _segments.isEmpty ||
        segmentIndex != _segmentIndex ||
        !_ownsContinuation(continuationEpoch)) {
      return;
    }
    if (_segmentRetries < _maxSegmentRetries) {
      _segmentRetries++;
      // The completion callback never arrived — a well-known failure mode for
      // flutter_tts on a locked iOS screen. Replay the current segment so the
      // chapter keeps moving instead of stalling on one sentence forever.
      await _prepareAndPlayContinuation(
        continuationEpoch,
        segmentIndex,
        _segments[segmentIndex],
      );
      return;
    }
    // Retries exhausted: treat the segment as finished and move on rather than
    // freezing here.
    await _advanceAfterSegmentCompleted(continuationEpoch);
  }

  void _schedulePrefetch(int continuationEpoch) {
    final provider = _provider;
    if (provider is! PrefetchingSpeechProvider || _disposing) {
      return;
    }
    _queuedPrefetchEpoch = continuationEpoch;
    if (_activePrefetch == null) {
      _startQueuedPrefetch(provider as PrefetchingSpeechProvider);
    }
  }

  void _startQueuedPrefetch(PrefetchingSpeechProvider provider) {
    final continuationEpoch = _queuedPrefetchEpoch;
    if (continuationEpoch == null || _disposing) {
      return;
    }
    _queuedPrefetchEpoch = null;
    final operation = _prefetchNext(provider, continuationEpoch);
    _activePrefetch = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_activePrefetch, operation)) {
          _activePrefetch = null;
        }
        if (!_disposing && _queuedPrefetchEpoch != null) {
          _startQueuedPrefetch(provider);
        }
      }),
    );
  }

  Future<void> _prefetchNext(
    PrefetchingSpeechProvider provider,
    int continuationEpoch,
  ) async {
    try {
      if (!_ownsContinuation(continuationEpoch)) {
        return;
      }
      const targetCharacters = 750;
      var plannedCharacters = 0;
      var cursor = _cursor;
      var segments = _segments.skip(_segmentIndex + 1).toList();

      while (_ownsContinuation(continuationEpoch) &&
          plannedCharacters < targetCharacters) {
        for (final segment in segments) {
          if (!_ownsContinuation(continuationEpoch)) {
            return;
          }
          // Prefetch happens while the current segment is still playing, so the
          // audio session and network are still alive even on a locked screen.
          // Retrying a failed synth here (rather than swallowing it) is what
          // warms the cache before the segment is needed; if it still fails
          // after backoff, stop this pass — a later advance/retry reschedules
          // prefetch — and let prepare() remain the authoritative fallback.
          if (!await _prefetchSegmentWithRetry(
            provider,
            segment,
            continuationEpoch,
          )) {
            return;
          }
          plannedCharacters += segment.text.runes.length;
          if (plannedCharacters >= targetCharacters) {
            return;
          }
        }
        if (cursor == null) {
          return;
        }
        final next = await _paragraphs.nextAfter(cursor);
        if (next == null || !_ownsContinuation(continuationEpoch)) {
          return;
        }
        cursor = next.cursor;
        segments = _segmenter.split(
          paragraphId: next.id,
          text: next.text,
          maxCharacters: _voiceProfile.maxSegmentCharacters,
        );
      }
    } catch (_) {
      // Normal prepare remains the authoritative fallback and error path.
    }
  }

  /// Attempts to warm a single segment's cache, retrying a transient failure a
  /// few times with exponential backoff. Returns whether the segment was
  /// prefetched. Failures are never surfaced to the user: prepare() is the
  /// authoritative fallback if prefetch ultimately gives up.
  Future<bool> _prefetchSegmentWithRetry(
    PrefetchingSpeechProvider provider,
    SpeechSegment segment,
    int continuationEpoch,
  ) async {
    const maxAttempts = 4;
    for (var attempt = 1; ; attempt++) {
      if (_disposing || !_ownsContinuation(continuationEpoch)) {
        return false;
      }
      try {
        await provider.prefetch(segment, _voiceProfile);
        return true;
      } catch (_) {
        if (attempt >= maxAttempts) {
          return false;
        }
        await _retryDelay(_retryBackoff(attempt));
      }
    }
  }

  Duration _retryBackoff(int attempt) {
    final capped = attempt.clamp(1, 5);
    return Duration(milliseconds: 250 * (1 << (capped - 1)));
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
    final chapterElapsed = Duration(
      microseconds:
          completedCharacters * microsPerCharacter + position.inMicroseconds,
    );
    final chapterRemaining = currentRemaining +
        Duration(microseconds: laterCharacters * microsPerCharacter);
    return PlaybackTimeline(
      position: position,
      duration: duration,
      chapterElapsed: chapterElapsed,
      chapterRemaining: chapterRemaining,
    );
  }
}
