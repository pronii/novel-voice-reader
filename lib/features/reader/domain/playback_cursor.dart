final class PlaybackCursor {
  const PlaybackCursor({
    required this.chapterId,
    required this.paragraphIndex,
  });

  final int chapterId;
  final int paragraphIndex;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaybackCursor &&
            chapterId == other.chapterId &&
            paragraphIndex == other.paragraphIndex;
  }

  @override
  int get hashCode => Object.hash(chapterId, paragraphIndex);
}
