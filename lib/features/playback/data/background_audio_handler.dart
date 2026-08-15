import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_coordinator.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_timeline.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';

final class AttachablePlaybackController implements PlaybackController {
  PlaybackController? _delegate;
  Future<void> _updates = Future<void>.value();
  double _speed = 1;

  Future<void> attach(PlaybackController controller) {
    return _enqueueUpdate(() async {
      await controller.setSpeed(_speed);
      _delegate = controller;
    });
  }

  void detach(PlaybackController controller) {
    if (identical(_delegate, controller)) {
      _delegate = null;
    }
  }

  @override
  PlaybackCursor? get cursor => _delegate?.cursor;

  @override
  Future<void> nextParagraph() async => _delegate?.nextParagraph();

  @override
  Future<void> pause() async => _delegate?.pause();

  @override
  Future<void> playFrom(PlaybackCursor cursor) async =>
      _delegate?.playFrom(cursor);

  @override
  Future<void> previousParagraph() async => _delegate?.previousParagraph();

  @override
  Future<void> resume() async => _delegate?.resume();

  @override
  Future<void> setSpeed(double speed) {
    return _enqueueUpdate(() async {
      final delegate = _delegate;
      if (delegate == null) {
        throw StateError('No playback controller is attached.');
      }
      await delegate.setSpeed(speed);
      _speed = speed;
    });
  }

  Future<T> _enqueueUpdate<T>(Future<T> Function() action) {
    final operation = _updates.then((_) => action());
    _updates = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}

final class PlaybackReplacementToken {
  const PlaybackReplacementToken._(this.generation);

  final int generation;
}

final class PlaybackRuntime {
  PlaybackRuntime({
    required this.controller,
    required this.handler,
    void Function(Object error, StackTrace stackTrace)?
    onCoordinatorDisposeError,
  }) : _onCoordinatorDisposeError =
           onCoordinatorDisposeError ?? _reportCoordinatorDisposeError {
    _playbackStateSubscription = handler.playbackState.listen((state) {
      if (state.processingState == AudioProcessingState.idle) {
        _publishCursor(null);
      } else if (state.playing && _currentCursor == null) {
        _publishCursor(controller.cursor);
      }
    });
  }

  final AttachablePlaybackController controller;
  final NovelAudioHandler handler;
  final void Function(Object error, StackTrace stackTrace)
  _onCoordinatorDisposeError;
  final StreamController<PlaybackCursor?> _cursorChanges =
      StreamController<PlaybackCursor?>.broadcast(sync: true);
  PlaybackCoordinator? _coordinator;
  StreamSubscription<PlaybackCursor>? _cursorSubscription;
  StreamSubscription<PlaybackTimeline>? _timelineSubscription;
  StreamSubscription<PlaybackActivity>? _activitySubscription;
  late final StreamSubscription<PlaybackState> _playbackStateSubscription;
  Future<void> _replacement = Future<void>.value();
  Future<void>? _disposeFuture;
  int _replacementGeneration = 0;
  int _coordinatorGeneration = 0;
  PlaybackCursor? _currentCursor;

  Stream<PlaybackCursor?> get cursorChanges => _cursorChanges.stream;

  PlaybackCursor? get currentCursor => _currentCursor;

  PlaybackReplacementToken beginReplacement() {
    return PlaybackReplacementToken._(++_replacementGeneration);
  }

  void cancelReplacement(PlaybackReplacementToken token) {
    if (_isCurrent(token)) {
      _replacementGeneration++;
    }
  }

  Future<void> replace(PlaybackCoordinator next) {
    return _enqueue(() => _replaceNow(next));
  }

  Future<bool> replaceAndPlayFrom(
    PlaybackCoordinator next,
    PlaybackCursor cursor, {
    required PlaybackReplacementToken token,
  }) {
    return _enqueue(() async {
      if (!_isCurrent(token)) {
        await _dispose(next);
        return false;
      }
      await _replaceNow(next);
      if (!_isCurrent(token)) {
        await _removeCurrent(next);
        return false;
      }
      try {
        await next.playFrom(cursor);
      } catch (_) {
        await _removeCurrent(next);
        rethrow;
      }
      if (!_isCurrent(token)) {
        await _removeCurrent(next);
        return false;
      }
      return true;
    });
  }

  Future<void> dispose() {
    return _disposeFuture ??= _enqueue(() async {
      await _disposeCurrent();
      await _playbackStateSubscription.cancel();
      await _cursorChanges.close();
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final operation = _replacement.then((_) => action());
    _replacement = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  bool _isCurrent(PlaybackReplacementToken token) {
    return token.generation == _replacementGeneration;
  }

  Future<void> _replaceNow(PlaybackCoordinator next) async {
    final previous = _coordinator;
    if (identical(previous, next)) {
      return;
    }
    try {
      await controller.attach(next);
    } catch (_) {
      await _dispose(next);
      rethrow;
    }
    await _cursorSubscription?.cancel();
    await _timelineSubscription?.cancel();
    await _activitySubscription?.cancel();
    final generation = ++_coordinatorGeneration;
    _coordinator = next;
    handler.publishTimeline(PlaybackTimeline.zero);
    _cursorSubscription = next.cursorChanges.listen((cursor) {
      if (generation == _coordinatorGeneration &&
          identical(_coordinator, next) &&
          !_cursorChanges.isClosed) {
        _publishCursor(cursor);
      }
    });
    _timelineSubscription = next.timelineChanges.listen((timeline) {
      if (generation == _coordinatorGeneration &&
          identical(_coordinator, next)) {
        handler.publishTimeline(timeline);
      }
    });
    _activitySubscription = next.activityChanges.listen((activity) {
      if (generation != _coordinatorGeneration ||
          !identical(_coordinator, next)) {
        return;
      }
      switch (activity) {
        case PlaybackActivity.playing:
          handler.markPlaying();
        case PlaybackActivity.paused:
          handler.markPaused();
        case PlaybackActivity.completed:
          handler.markIdle();
        case PlaybackActivity.failed:
          handler.publishTimeline(PlaybackTimeline.zero);
          handler.markPaused();
      }
    });
    if (previous != null) {
      await _dispose(previous);
    }
  }

  Future<void> _disposeCurrent() async {
    final current = _coordinator;
    _coordinator = null;
    _coordinatorGeneration++;
    await _cursorSubscription?.cancel();
    _cursorSubscription = null;
    await _timelineSubscription?.cancel();
    _timelineSubscription = null;
    await _activitySubscription?.cancel();
    _activitySubscription = null;
    handler.markIdle();
    _publishCursor(null);
    if (current == null) {
      return;
    }
    controller.detach(current);
    await _dispose(current);
  }

  Future<void> _removeCurrent(PlaybackCoordinator coordinator) async {
    if (identical(_coordinator, coordinator)) {
      _coordinator = null;
      _coordinatorGeneration++;
      await _cursorSubscription?.cancel();
      _cursorSubscription = null;
      await _timelineSubscription?.cancel();
      _timelineSubscription = null;
      await _activitySubscription?.cancel();
      _activitySubscription = null;
      controller.detach(coordinator);
      handler.markIdle();
      _publishCursor(null);
    }
    await _dispose(coordinator);
  }

  Future<void> _dispose(PlaybackCoordinator coordinator) async {
    try {
      await coordinator.dispose();
    } catch (error, stackTrace) {
      _onCoordinatorDisposeError(error, stackTrace);
    }
  }

  void _publishCursor(PlaybackCursor? cursor) {
    if (_currentCursor == cursor) {
      return;
    }
    _currentCursor = cursor;
    if (!_cursorChanges.isClosed) {
      _cursorChanges.add(cursor);
    }
  }

  static void _reportCoordinatorDisposeError(
    Object error,
    StackTrace stackTrace,
  ) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        context: ErrorDescription('while disposing a playback coordinator'),
      ),
    );
  }
}

final class NovelAudioHandler extends BaseAudioHandler {
  NovelAudioHandler(this._controller) {
    playbackState.add(_state(playing: false));
  }

  final PlaybackController _controller;
  final StreamController<PlaybackTimeline> _timelineChanges =
      StreamController<PlaybackTimeline>.broadcast(sync: true);
  PlaybackTimeline _currentTimeline = PlaybackTimeline.zero;
  double _speed = 1;

  Stream<PlaybackTimeline> get timelineChanges => _timelineChanges.stream;

  PlaybackTimeline get currentTimeline => _currentTimeline;

  void publishNowPlaying({
    required int bookId,
    required String bookTitle,
    required String chapterTitle,
  }) {
    mediaItem.add(
      MediaItem(
        id: 'book-$bookId',
        title: bookTitle,
        album: chapterTitle,
        duration: _currentTimeline.duration,
      ),
    );
  }

  void publishTimeline(PlaybackTimeline timeline) {
    if (_currentTimeline == timeline) return;
    _currentTimeline = timeline;
    _timelineChanges.add(timeline);
    final item = mediaItem.value;
    if (item != null && item.duration != timeline.duration) {
      mediaItem.add(item.copyWith(duration: timeline.duration));
    }
    playbackState.add(
      _state(
        playing: playbackState.value.playing,
        updatePosition: timeline.position,
      ),
    );
  }

  void markPlaying() {
    playbackState.add(_state(playing: true));
  }

  void markPaused() {
    playbackState.add(_state(playing: false));
  }

  void markIdle() {
    publishTimeline(PlaybackTimeline.zero);
    playbackState.add(
      _state(
        playing: false,
      ).copyWith(processingState: AudioProcessingState.idle),
    );
  }

  @override
  Future<void> play() async {
    await _controller.resume();
    if (_controller.cursor == null) {
      return;
    }
    playbackState.add(_state(playing: true));
  }

  @override
  Future<void> pause() async {
    await _controller.pause();
    playbackState.add(_state(playing: false));
  }

  @override
  Future<void> skipToNext() => _controller.nextParagraph();

  @override
  Future<void> skipToPrevious() => _controller.previousParagraph();

  @override
  Future<void> setSpeed(double speed) async {
    await _controller.setSpeed(speed);
    _speed = speed;
    playbackState.add(_state(playing: playbackState.value.playing));
  }

  @override
  Future<void> stop() async {
    await _controller.pause();
    markIdle();
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    // Swiping the app out of Android recents must not kill playback that is
    // still running on the lock screen / media notification. Only tear down
    // when nothing is actively playing.
    if (playbackState.value.playing) {
      return;
    }
    await stop();
  }

  PlaybackState _state({required bool playing, Duration? updatePosition}) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.ready,
      playing: playing,
      speed: _speed,
      updatePosition: updatePosition ?? _currentTimeline.position,
    );
  }
}
