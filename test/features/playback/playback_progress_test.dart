import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_progress.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_timeline.dart';

void main() {
  group('chapter-level progress', () {
    test('prefers the chapter estimate over the segment duration', () {
      const timeline = PlaybackTimeline(
        position: Duration(seconds: 5),
        duration: Duration(seconds: 10),
        chapterElapsed: Duration(seconds: 30),
        chapterRemaining: Duration(seconds: 70),
      );

      final progress = PlaybackProgress.of(timeline);

      expect(progress.value, 0.3);
    });

    test('falls back to segment progress when the chapter total is zero', () {
      const timeline = PlaybackTimeline(
        position: Duration.zero,
        duration: Duration(seconds: 10),
        chapterElapsed: Duration.zero,
        chapterRemaining: Duration.zero,
      );

      // A zero-length chapter estimate is unusable, so the readout falls back
      // to the segment: 0 s of 10 s.
      expect(PlaybackProgress.of(timeline).value, 0.0);
    });
  });

  group('segment fallback', () {
    test('falls back to position over duration without a chapter estimate', () {
      const timeline = PlaybackTimeline(
        position: Duration(seconds: 25),
        duration: Duration(seconds: 100),
      );

      expect(PlaybackProgress.of(timeline).value, 0.25);
    });

    test('is indeterminate when the duration is unknown', () {
      const timeline = PlaybackTimeline(
        position: Duration(seconds: 25),
        duration: null,
      );

      expect(PlaybackProgress.of(timeline).value, isNull);
    });

    test('uses placeholder labels when nothing is known', () {
      final progress = PlaybackProgress.of(PlaybackTimeline.zero);

      expect(progress.elapsedLabel, '已听 --:--');
      expect(progress.remainingLabel, '本章剩余 --:--');
    });
  });

  group('speed adjustment', () {
    test('scales the chapter remaining by the playback speed', () {
      const timeline = PlaybackTimeline(
        position: Duration.zero,
        duration: null,
        chapterElapsed: Duration.zero,
        chapterRemaining: Duration(minutes: 10),
      );

      expect(
        PlaybackProgress.of(timeline, speed: 2).remainingLabel,
        '本章剩余 05:00',
      );
      expect(
        PlaybackProgress.of(timeline, speed: 1).remainingLabel,
        '本章剩余 10:00',
      );
    });

    test('scales the chapter elapsed by the playback speed', () {
      const timeline = PlaybackTimeline(
        position: Duration.zero,
        duration: null,
        chapterElapsed: Duration(minutes: 6),
        chapterRemaining: Duration(minutes: 6),
      );

      expect(
        PlaybackProgress.of(timeline, speed: 1.5).elapsedLabel,
        '已听 04:00',
      );
    });

    test('never divides by a zero speed', () {
      const timeline = PlaybackTimeline(
        position: Duration.zero,
        duration: null,
        chapterElapsed: Duration.zero,
        chapterRemaining: Duration(minutes: 3),
      );

      expect(
        PlaybackProgress.of(timeline, speed: 0).remainingLabel,
        '本章剩余 03:00',
      );
    });

    test('clamps a negative remaining to zero', () {
      const timeline = PlaybackTimeline(
        position: Duration.zero,
        duration: null,
        chapterElapsed: Duration.zero,
        chapterRemaining: Duration(seconds: -30),
      );

      expect(
        PlaybackProgress.of(timeline).remainingLabel,
        '本章剩余 00:00',
      );
    });
  });

  group('label formatting', () {
    test('pads minutes and seconds to two digits', () {
      const timeline = PlaybackTimeline(
        position: Duration.zero,
        duration: null,
        chapterElapsed: Duration(seconds: 65),
        chapterRemaining: Duration(seconds: 5),
      );

      expect(PlaybackProgress.of(timeline).elapsedLabel, '已听 01:05');
    });

    test('caps the label below one hundred hours', () {
      const timeline = PlaybackTimeline(
        position: Duration.zero,
        duration: null,
        chapterElapsed: Duration.zero,
        chapterRemaining: Duration(days: 30),
      );

      // 359999 s is the clamp ceiling, which renders as 5999 minutes and 59
      // seconds — long, but still short enough to fit the row.
      expect(PlaybackProgress.of(timeline).remainingLabel, '本章剩余 5999:59');
    });
  });

  test('the unknown readout matches a timeline with no data', () {
    final unknown = PlaybackProgress.unknown();

    expect(unknown.value, isNull);
    expect(unknown.elapsedLabel, '已听 --:--');
    expect(unknown.remainingLabel, '本章剩余 --:--');
  });
}
