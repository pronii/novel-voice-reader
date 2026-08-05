final class PlaybackTimeline {
  const PlaybackTimeline({required this.position, required this.duration});

  static const zero = PlaybackTimeline(position: Duration.zero, duration: null);

  final Duration position;
  final Duration? duration;

  @override
  bool operator ==(Object other) =>
      other is PlaybackTimeline &&
      other.position == position &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(position, duration);
}
