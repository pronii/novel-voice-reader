final class PlaybackTimeline {
  const PlaybackTimeline({
    required this.position,
    required this.duration,
    this.chapterRemaining,
  });

  static const zero = PlaybackTimeline(position: Duration.zero, duration: null);

  final Duration position;
  final Duration? duration;
  final Duration? chapterRemaining;

  @override
  bool operator ==(Object other) =>
      other is PlaybackTimeline &&
      other.position == position &&
      other.duration == duration &&
      other.chapterRemaining == chapterRemaining;

  @override
  int get hashCode => Object.hash(position, duration, chapterRemaining);
}
