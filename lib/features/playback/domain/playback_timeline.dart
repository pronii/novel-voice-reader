final class PlaybackTimeline {
  const PlaybackTimeline({
    required this.position,
    required this.duration,
    this.chapterElapsed,
    this.chapterRemaining,
  });

  static const zero = PlaybackTimeline(position: Duration.zero, duration: null);

  final Duration position;
  final Duration? duration;

  /// Estimated time already played in the current chapter (across all
  /// segments), used to drive the chapter-level progress bar.
  final Duration? chapterElapsed;
  final Duration? chapterRemaining;

  @override
  bool operator ==(Object other) =>
      other is PlaybackTimeline &&
      other.position == position &&
      other.duration == duration &&
      other.chapterElapsed == chapterElapsed &&
      other.chapterRemaining == chapterRemaining;

  @override
  int get hashCode =>
      Object.hash(position, duration, chapterElapsed, chapterRemaining);
}
