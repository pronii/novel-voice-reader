import 'dart:async';

import 'package:novel_voice_reader/core/errors/app_failure.dart';
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

abstract interface class PlaybackProgressRepository {
  Future<void> confirm(PlaybackCursor cursor);
}

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
  }

  final SpeechProvider _provider;
  final PlaybackProgressRepository _progress;
  final PlaybackParagraphSource _paragraphs;
  final VoiceProfile _voiceProfile;
  final SpeechSegmenter _segmenter;
  final void Function(AppFailure failure)? _onFailure;
  late final StreamSubscription<SpeechEvent> _subscription;

  PlaybackCursor? _cursor;
  List<SpeechSegment> _segments = const [];
  int _segmentIndex = 0;
  double _speed = 1;

  @override
  PlaybackCursor? get cursor => _cursor;

  @override
  Future<void> playFrom(PlaybackCursor cursor) async {
    final paragraph = await _paragraphs.at(cursor);
    if (paragraph == null) {
      throw StateError('Playback cursor does not point to a paragraph.');
    }
    await _startParagraph(paragraph);
  }

  @override
  Future<void> pause() async {
    final cursor = _cursor;
    if (cursor != null) {
      await _progress.confirm(cursor);
    }
    await _provider.pause();
  }

  @override
  Future<void> resume() => _provider.resume();

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    final provider = _provider;
    if (provider is AdjustableSpeechProvider) {
      await (provider as AdjustableSpeechProvider).setPlaybackSpeed(speed);
    }
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
    await _subscription.cancel();
    final provider = _provider;
    if (provider is DisposableSpeechProvider) {
      await (provider as DisposableSpeechProvider).dispose();
    } else {
      await provider.stop();
    }
  }

  Future<void> _startParagraph(PlaybackParagraph paragraph) async {
    _cursor = paragraph.cursor;
    _segments = _segmenter.split(
      paragraphId: paragraph.id,
      text: paragraph.text,
      maxCharacters: _voiceProfile.maxSegmentCharacters,
    );
    _segmentIndex = 0;
    await _prepareAndPlayCurrentSegment();
  }

  Future<void> _prepareAndPlayCurrentSegment() async {
    await _provider.prepare(_segments[_segmentIndex], _voiceProfile);
    final provider = _provider;
    if (provider is AdjustableSpeechProvider) {
      await (provider as AdjustableSpeechProvider).setPlaybackSpeed(_speed);
    }
    await _provider.play();
  }

  Future<void> _handleSpeechEvent(SpeechEvent event) async {
    if (event is SpeechFailed) {
      _onFailure?.call(event.failure);
      return;
    }
    if (event is! SpeechCompleted ||
        _segments.isEmpty ||
        event.segmentId != _segments[_segmentIndex].id) {
      return;
    }
    if (_segmentIndex + 1 < _segments.length) {
      _segmentIndex++;
      await _prepareAndPlayCurrentSegment();
      return;
    }

    final current = _cursor;
    if (current == null) {
      return;
    }
    final next = await _paragraphs.nextAfter(current);
    if (next == null) {
      await _progress.confirm(current);
      return;
    }
    await _progress.confirm(next.cursor);
    await _startParagraph(next);
  }
}
