import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_handler.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_coordinator.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lock-screen commands map to paragraph playback controls', () async {
    final controller = FakePlaybackController(
      const PlaybackCursor(chapterId: 1, paragraphIndex: 3),
    );
    final handler = NovelAudioHandler(controller);

    await handler.play();
    await handler.pause();
    await handler.skipToNext();
    await handler.skipToPrevious();

    expect(controller.resumeCalls, 1);
    expect(controller.pauseCalls, 1);
    expect(controller.nextCalls, 1);
    expect(controller.previousCalls, 1);
    expect(controller.cursor?.paragraphIndex, 3);
  });

  test('publishes book and chapter metadata for the lock screen', () async {
    final handler = NovelAudioHandler(FakePlaybackController(null));

    handler.publishNowPlaying(bookId: 7, bookTitle: '测试书', chapterTitle: '第一章');

    expect(handler.mediaItem.value?.id, 'book-7');
    expect(handler.mediaItem.value?.title, '测试书');
    expect(handler.mediaItem.value?.album, '第一章');
    expect(
      handler.playbackState.value.controls,
      containsAll([MediaControl.skipToPrevious, MediaControl.skipToNext]),
    );
  });
}

final class FakePlaybackController implements PlaybackController {
  FakePlaybackController(this._cursor);

  PlaybackCursor? _cursor;
  int resumeCalls = 0;
  int pauseCalls = 0;
  int nextCalls = 0;
  int previousCalls = 0;

  @override
  PlaybackCursor? get cursor => _cursor;

  @override
  Future<void> nextParagraph() async {
    nextCalls++;
    final value = _cursor;
    if (value != null) {
      _cursor = PlaybackCursor(
        chapterId: value.chapterId,
        paragraphIndex: value.paragraphIndex + 1,
      );
    }
  }

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> playFrom(PlaybackCursor cursor) async => _cursor = cursor;

  @override
  Future<void> previousParagraph() async {
    previousCalls++;
    final value = _cursor;
    if (value != null) {
      _cursor = PlaybackCursor(
        chapterId: value.chapterId,
        paragraphIndex: value.paragraphIndex - 1,
      );
    }
  }

  @override
  Future<void> resume() async => resumeCalls++;
}
