abstract final class DownloadWindow {
  static List<int> calculate({
    required int currentChapterIndex,
    required int chaptersAhead,
    required bool wholeBook,
    required int chapterCount,
  }) {
    if (chapterCount < 0) {
      throw ArgumentError.value(
        chapterCount,
        'chapterCount',
        'Must not be negative.',
      );
    }
    if (chaptersAhead < 0) {
      throw ArgumentError.value(
        chaptersAhead,
        'chaptersAhead',
        'Must not be negative.',
      );
    }
    if (chapterCount == 0) {
      return const [];
    }
    if (currentChapterIndex < 0 || currentChapterIndex >= chapterCount) {
      throw ArgumentError.value(
        currentChapterIndex,
        'currentChapterIndex',
        'Must point to a chapter in the book.',
      );
    }

    final lastIndex = wholeBook
        ? chapterCount - 1
        : (currentChapterIndex + chaptersAhead).clamp(
            currentChapterIndex,
            chapterCount - 1,
          );
    return [
      for (var index = currentChapterIndex; index <= lastIndex; index++) index,
    ];
  }
}
