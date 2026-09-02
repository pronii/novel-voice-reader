import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_timeline.dart';

/// The player's progress readout: the bar value plus the two labels beside it.
///
/// Lives in the domain layer (rather than inline in the player widget) because
/// the arithmetic has to reconcile two imperfect sources — a chapter-level
/// estimate that may be absent, and a segment duration that may be unknown —
/// and that is worth testing without building a widget tree.
@immutable
final class PlaybackProgress {
  const PlaybackProgress({
    required this.value,
    required this.elapsedLabel,
    required this.remainingLabel,
  });

  /// Derives the readout for [timeline], scaling the time labels by [speed] so
  /// they show wall-clock listening time rather than audio time.
  factory PlaybackProgress.of(
    PlaybackTimeline timeline, {
    double speed = 1,
  }) {
    return PlaybackProgress(
      value: _progressOf(timeline),
      elapsedLabel: '已听 ${_format(_elapsedOf(timeline, speed))}',
      remainingLabel: '本章剩余 ${_format(_remainingOf(timeline, speed))}',
    );
  }

  /// A readout taken before any timeline arrives: an indeterminate bar and
  /// placeholder labels.
  factory PlaybackProgress.unknown() => const PlaybackProgress(
    value: null,
    elapsedLabel: '已听 --:--',
    remainingLabel: '本章剩余 --:--',
  );

  /// Bar position in 0..1, or null when the total length is unknown.
  ///
  /// Chapter-level progress is preferred so the bar reflects the whole chapter
  /// rather than the short current TTS segment.
  final double? value;

  final String elapsedLabel;
  final String remainingLabel;

  static double? _progressOf(PlaybackTimeline timeline) {
    final elapsed = timeline.chapterElapsed;
    final chapterRemaining = timeline.chapterRemaining;
    if (elapsed != null && chapterRemaining != null) {
      final total = elapsed + chapterRemaining;
      if (total > Duration.zero) {
        return (elapsed.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
      }
    }
    final duration = timeline.duration;
    if (duration == null || duration <= Duration.zero) {
      return null;
    }
    return (timeline.position.inMicroseconds / duration.inMicroseconds)
        .clamp(0.0, 1.0);
  }

  static Duration? _elapsedOf(PlaybackTimeline timeline, double speed) {
    final elapsed = timeline.chapterElapsed;
    if (elapsed != null) {
      return _atSpeed(elapsed, speed);
    }
    final duration = timeline.duration;
    if (duration == null || duration <= Duration.zero) {
      return null;
    }
    // The position is returned unscaled: it is the segment's own playhead,
    // not an estimate of chapter listening time.
    return timeline.position;
  }

  static Duration? _remainingOf(PlaybackTimeline timeline, double speed) {
    final duration = timeline.duration;
    final chapterRemaining = timeline.chapterRemaining;
    if (chapterRemaining == null &&
        (duration == null || duration <= Duration.zero)) {
      return null;
    }
    return _atSpeed(chapterRemaining ?? duration! - timeline.position, speed);
  }

  static Duration _atSpeed(Duration value, double speed) {
    // Guard against a zero rate so a bad preference can never divide by zero;
    // the speed selector only offers non-zero values.
    final rate = speed > 0 ? speed : 1;
    return Duration(
      microseconds: (max(0, value.inMicroseconds) / rate).round(),
    );
  }

  /// Formats a duration as mm:ss, or `--:--` when it is unknown. Clamped to
  /// just under 100 hours so the label can never overflow its row.
  static String _format(Duration? duration) {
    if (duration == null) {
      return '--:--';
    }
    final totalSeconds = duration.inSeconds.clamp(0, 359999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
