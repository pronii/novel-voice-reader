import 'package:flutter/foundation.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_content.dart';

typedef ReaderChapterSectionLoader =
    Future<ReaderChapterSection> Function(ReaderChapter chapter);

final class ReaderViewportAnchor {
  const ReaderViewportAnchor({required this.itemKey, required this.alignment});

  final String itemKey;
  final double alignment;
}

final class ReaderWindowMutation {
  const ReaderWindowMutation({
    required this.changed,
    required this.postponed,
    this.anchor,
  });

  final bool changed;
  final bool postponed;
  final ReaderViewportAnchor? anchor;
}

final class ReaderChapterWindowController extends ChangeNotifier {
  ReaderChapterWindowController({
    required List<ReaderChapter> chapters,
    required this.loadSection,
    this.maxSections = 5,
  }) : _chapters = List.unmodifiable(chapters);

  final List<ReaderChapter> _chapters;
  final ReaderChapterSectionLoader loadSection;
  final int maxSections;
  List<ReaderChapterSection> _sections = const [];
  int _navigationGeneration = 0;
  Object? _adjacentLoadError;
  Future<void> _mutationQueue = Future<void>.value();
  Future<ReaderWindowMutation>? _previousLoad;
  Future<ReaderWindowMutation>? _nextLoad;

  List<ReaderChapterSection> get sections => _sections;

  List<ReaderContentItem> get items {
    final result = <ReaderContentItem>[
      for (final section in _sections) ...[
        ReaderChapterHeadingItem(section.chapter),
        for (final paragraph in section.paragraphs)
          ReaderParagraphItem(paragraph),
      ],
    ];
    if (_sections.isNotEmpty &&
        _sections.last.chapter.id == _chapters.last.id) {
      result.add(ReaderBookEndItem(_sections.last.chapter.id));
    }
    return List.unmodifiable(result);
  }

  int get navigationGeneration => _navigationGeneration;

  Object? get adjacentLoadError => _adjacentLoadError;

  Future<void> initialize({required int chapterId}) async {
    _sections = await _loadCentered(chapterId);
    _adjacentLoadError = null;
    notifyListeners();
  }

  Future<List<ReaderChapterSection>> _loadCentered(int chapterId) async {
    final chapterIndex = _chapters.indexWhere(
      (chapter) => chapter.id == chapterId,
    );
    if (chapterIndex < 0) {
      throw ArgumentError.value(chapterId, 'chapterId', 'Unknown chapter.');
    }
    final start = (chapterIndex - 1).clamp(0, _chapters.length - 1);
    final end = (chapterIndex + 2).clamp(0, _chapters.length - 1);
    final loaded = <ReaderChapterSection>[];
    for (var index = start; index <= end; index++) {
      loaded.add(await loadSection(_chapters[index]));
    }
    return List.unmodifiable(loaded.take(maxSections));
  }

  Future<ReaderWindowMutation> loadPrevious({
    required Set<int> visibleChapterIds,
    required ReaderViewportAnchor anchor,
  }) {
    final existing = _previousLoad;
    if (existing != null) {
      return existing;
    }
    final operation = _enqueueMutation(
      () => _loadPreviousNow(
        visibleChapterIds: visibleChapterIds,
        anchor: anchor,
      ),
    );
    _previousLoad = operation;
    operation.then<void>(
      (_) => _clearPreviousLoad(operation),
      onError: (Object _, StackTrace _) => _clearPreviousLoad(operation),
    );
    return operation;
  }

  Future<ReaderWindowMutation> loadNext({
    required Set<int> visibleChapterIds,
    required ReaderViewportAnchor anchor,
  }) {
    final existing = _nextLoad;
    if (existing != null) {
      return existing;
    }
    final operation = _enqueueMutation(
      () => _loadNextNow(
        visibleChapterIds: visibleChapterIds,
        anchor: anchor,
      ),
    );
    _nextLoad = operation;
    operation.then<void>(
      (_) => _clearNextLoad(operation),
      onError: (Object _, StackTrace _) => _clearNextLoad(operation),
    );
    return operation;
  }

  Future<void> centerOn({
    required int chapterId,
    bool resetNavigation = true,
  }) async {
    _sections = await _enqueueMutation(() => _loadCentered(chapterId));
    _adjacentLoadError = null;
    // Playback-driven re-centering must not bump the navigation generation, or
    // the reader treats it as a user jump and yanks the viewport back to the
    // stale navigation cursor instead of following the playing paragraph.
    if (resetNavigation) {
      _navigationGeneration++;
    }
    notifyListeners();
  }

  Future<ReaderWindowMutation> _loadPreviousNow({
    required Set<int> visibleChapterIds,
    required ReaderViewportAnchor anchor,
  }) async {
    if (_sections.isEmpty) {
      return const ReaderWindowMutation(changed: false, postponed: false);
    }
    final firstIndex = _chapterIndex(_sections.first.chapter.id);
    if (firstIndex <= 0) {
      return const ReaderWindowMutation(changed: false, postponed: false);
    }
    final mustEvict = _sections.length >= maxSections;
    if (mustEvict &&
        visibleChapterIds.contains(_sections.last.chapter.id)) {
      return const ReaderWindowMutation(changed: false, postponed: true);
    }
    try {
      final loaded = await loadSection(_chapters[firstIndex - 1]);
      final nextSections = <ReaderChapterSection>[loaded, ..._sections];
      if (mustEvict) {
        nextSections.removeLast();
      }
      _sections = List.unmodifiable(nextSections);
      _adjacentLoadError = null;
      notifyListeners();
      return ReaderWindowMutation(
        changed: true,
        postponed: false,
        anchor: anchor,
      );
    } catch (error) {
      _adjacentLoadError = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<ReaderWindowMutation> _loadNextNow({
    required Set<int> visibleChapterIds,
    required ReaderViewportAnchor anchor,
  }) async {
    if (_sections.isEmpty) {
      return const ReaderWindowMutation(changed: false, postponed: false);
    }
    final lastIndex = _chapterIndex(_sections.last.chapter.id);
    if (lastIndex < 0 || lastIndex + 1 >= _chapters.length) {
      return const ReaderWindowMutation(changed: false, postponed: false);
    }
    final mustEvict = _sections.length >= maxSections;
    if (mustEvict &&
        visibleChapterIds.contains(_sections.first.chapter.id)) {
      return const ReaderWindowMutation(changed: false, postponed: true);
    }
    try {
      final loaded = await loadSection(_chapters[lastIndex + 1]);
      final nextSections = <ReaderChapterSection>[..._sections, loaded];
      ReaderViewportAnchor? restoredAnchor;
      if (mustEvict) {
        nextSections.removeAt(0);
        restoredAnchor = anchor;
      }
      _sections = List.unmodifiable(nextSections);
      _adjacentLoadError = null;
      notifyListeners();
      return ReaderWindowMutation(
        changed: true,
        postponed: false,
        anchor: restoredAnchor,
      );
    } catch (error) {
      _adjacentLoadError = error;
      notifyListeners();
      rethrow;
    }
  }

  int _chapterIndex(int chapterId) {
    return _chapters.indexWhere((chapter) => chapter.id == chapterId);
  }

  Future<T> _enqueueMutation<T>(Future<T> Function() action) {
    final operation = _mutationQueue.then((_) => action());
    _mutationQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  void _clearPreviousLoad(Future<ReaderWindowMutation> operation) {
    if (identical(_previousLoad, operation)) {
      _previousLoad = null;
    }
  }

  void _clearNextLoad(Future<ReaderWindowMutation> operation) {
    if (identical(_nextLoad, operation)) {
      _nextLoad = null;
    }
  }
}
