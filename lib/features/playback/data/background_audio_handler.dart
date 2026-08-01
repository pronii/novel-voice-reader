import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_coordinator.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';

final class AttachablePlaybackController implements PlaybackController {
  PlaybackController? _delegate;

  void attach(PlaybackController controller) {
    _delegate = controller;
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
           onCoordinatorDisposeError ?? _reportCoordinatorDisposeError;

  final AttachablePlaybackController controller;
  final NovelAudioHandler handler;
  final void Function(Object error, StackTrace stackTrace)
  _onCoordinatorDisposeError;
  PlaybackCoordinator? _coordinator;
  Future<void> _replacement = Future<void>.value();
  int _replacementGeneration = 0;

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
    return _enqueue(_disposeCurrent);
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
    _coordinator = next;
    controller.attach(next);
    if (previous != null) {
      await _dispose(previous);
    }
  }

  Future<void> _disposeCurrent() async {
    final current = _coordinator;
    _coordinator = null;
    handler.markIdle();
    if (current == null) {
      return;
    }
    controller.detach(current);
    await _dispose(current);
  }

  Future<void> _removeCurrent(PlaybackCoordinator coordinator) async {
    if (identical(_coordinator, coordinator)) {
      _coordinator = null;
      controller.detach(coordinator);
      handler.markIdle();
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

  void publishNowPlaying({
    required int bookId,
    required String bookTitle,
    required String chapterTitle,
  }) {
    mediaItem.add(
      MediaItem(id: 'book-$bookId', title: bookTitle, album: chapterTitle),
    );
  }

  void markPlaying() {
    playbackState.add(_state(playing: true));
  }

  void markIdle() {
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
  Future<void> stop() async {
    await _controller.pause();
    markIdle();
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() => pause();

  PlaybackState _state({required bool playing}) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.ready,
      playing: playing,
    );
  }
}
