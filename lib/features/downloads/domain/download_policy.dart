final class DownloadPolicy {
  factory DownloadPolicy({
    required int chaptersAhead,
    required bool wholeBook,
    required bool wifiOnly,
    required int maxCacheBytes,
  }) {
    if (chaptersAhead < 0) {
      throw ArgumentError.value(
        chaptersAhead,
        'chaptersAhead',
        'Must not be negative.',
      );
    }
    if (maxCacheBytes <= 0) {
      throw ArgumentError.value(
        maxCacheBytes,
        'maxCacheBytes',
        'Must be positive.',
      );
    }
    return DownloadPolicy._(
      chaptersAhead: chaptersAhead,
      wholeBook: wholeBook,
      wifiOnly: wifiOnly,
      maxCacheBytes: maxCacheBytes,
    );
  }

  const DownloadPolicy._({
    required this.chaptersAhead,
    required this.wholeBook,
    required this.wifiOnly,
    required this.maxCacheBytes,
  });

  final int chaptersAhead;
  final bool wholeBook;
  final bool wifiOnly;
  final int maxCacheBytes;
}
