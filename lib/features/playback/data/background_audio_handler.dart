import 'package:audio_service/audio_service.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_coordinator.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';

final class AttachablePlaybackController implements PlaybackController {
  PlaybackController? _delegate;

  void attach(PlaybackController controller) {
    _delegate = controller;
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

final class PlaybackRuntime {
  const PlaybackRuntime({required this.controller, required this.handler});

  final AttachablePlaybackController controller;
  final NovelAudioHandler handler;
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

  @override
  Future<void> play() async {
    await _controller.resume();
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
    playbackState.add(
      _state(
        playing: false,
      ).copyWith(processingState: AudioProcessingState.idle),
    );
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
