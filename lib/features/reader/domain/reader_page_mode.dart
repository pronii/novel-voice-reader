/// The reading interaction mode selected from the reader's bottom control bar.
///
/// Persisted globally (not per book) by `ReaderPreferencesStore`. The reader
/// swaps the widget that renders the text area based on the active mode:
/// [scroll] keeps the original continuous vertical list, while [slide] and
/// [curl] paginate the text into discrete left/right pages.
enum ReaderPageMode {
  /// Continuous vertical scrolling — the original reader, no page-turn
  /// animation.
  scroll,

  /// Left/right paged view with a static slide between pages (no 3D curl).
  slide,

  /// Left/right paged view with a simulated 3D book page-curl animation.
  curl;

  /// Short, touch-friendly label shown on the bottom control bar.
  String get label => switch (this) {
    ReaderPageMode.scroll => '滚动',
    ReaderPageMode.slide => '翻页',
    ReaderPageMode.curl => '3D翻页',
  };

  /// Whether this mode paginates the text (as opposed to scrolling it).
  bool get isPaged => this != ReaderPageMode.scroll;

  /// Stable token stored on disk. Kept independent of [name] so renaming the
  /// enum can never silently invalidate a user's saved preference.
  String get storageKey => switch (this) {
    ReaderPageMode.scroll => 'scroll',
    ReaderPageMode.slide => 'slide',
    ReaderPageMode.curl => 'curl',
  };

  /// Parses a persisted [storageKey]; unknown or missing values fall back to
  /// [scroll] so a corrupt preference degrades to the safe default.
  static ReaderPageMode fromStorage(String? value) {
    for (final mode in ReaderPageMode.values) {
      if (mode.storageKey == value) {
        return mode;
      }
    }
    return ReaderPageMode.scroll;
  }
}
