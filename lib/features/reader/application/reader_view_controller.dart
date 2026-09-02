import 'dart:async';

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:novel_voice_reader/features/reader/application/auto_scroll_controller.dart';
import 'package:novel_voice_reader/features/reader/application/reader_chapter_window_controller.dart';
import 'package:novel_voice_reader/features/reader/application/reader_content_index.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_content.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_page_mode.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Loads the chapters adjacent to the viewport when the reader reaches an edge.
typedef ReaderEdgeLoadCallback =
    Future<ReaderWindowMutation> Function({
      required Set<int> visibleChapterIds,
      required ReaderViewportAnchor anchor,
    });

/// Everything [ReaderPage] is told by its host, bundled into one snapshot so
/// the view controller holds a single reference instead of nine fields.
@immutable
final class ReaderViewInput {
  const ReaderViewInput({
    required this.sections,
    required this.chapters,
    this.initialCursor,
    this.currentChapterId,
    this.playbackCursor,
    this.playbackActive = false,
    this.playbackStarting = false,
    this.navigationGeneration = 0,
  });

  final List<ReaderChapterSection> sections;
  final List<ReaderChapter> chapters;
  final PlaybackCursor? initialCursor;
  final int? currentChapterId;
  final PlaybackCursor? playbackCursor;
  final bool playbackActive;
  final bool playbackStarting;
  final int navigationGeneration;
}

/// Every callback [ReaderPage] exposes to its host, bundled so the view
/// controller holds one reference instead of ten.
final class ReaderViewCallbacks {
  const ReaderViewCallbacks({
    this.onChapterSelected,
    this.onVisibleChapterChanged,
    this.onReadingPositionChanged,
    this.onWarmFrom,
    this.onPlayFrom,
    this.onListenFrom,
    this.onPageModeChanged,
    this.onLoadPrevious,
    this.onLoadNext,
    this.onPlaybackChapterNeeded,
  });

  final ValueChanged<int>? onChapterSelected;
  final ValueChanged<int>? onVisibleChapterChanged;
  final ValueChanged<ReaderParagraph>? onReadingPositionChanged;
  final ValueChanged<ReaderParagraph>? onWarmFrom;
  final ValueChanged<ReaderParagraph>? onPlayFrom;
  final ValueChanged<PlaybackCursor>? onListenFrom;
  final ValueChanged<ReaderPageMode>? onPageModeChanged;
  final ReaderEdgeLoadCallback? onLoadPrevious;
  final ReaderEdgeLoadCallback? onLoadNext;
  final Future<void> Function(int chapterId)? onPlaybackChapterNeeded;
}

/// Owns every piece of reader state that is *not* pure rendering.
///
/// The reader page used to keep this state on its [State] subclass, which
/// bundled eleven unrelated responsibilities — scroll plumbing, auto scroll,
/// playback following, chapter-window edge loading, progress reporting,
/// toolbar visibility, tap zones, paragraph selection, page mode and two
/// bottom sheets — into one 1500-line widget. Moving it here makes the page a
/// thin shell and lets the timing-sensitive parts (the follow heartbeat, the
/// progress debounce) be exercised without a widget tree.
///
/// The controller deliberately does not own the content list build: that lives
/// in [ReaderContentIndex]. It also never touches [BuildContext] except to
/// present the two bottom sheets, which are leaf UI with no state of their own.
class ReaderViewController extends ChangeNotifier {
  ReaderViewController({
    required ReaderViewInput input,
    required ReaderViewCallbacks callbacks,
    required ReaderPageMode initialPageMode,
  }) : _input = input,
       // Named param backs a private mutable field, so an initializing formal
       // won't apply (the host swaps these on every rebuild).
       // ignore: prefer_initializing_formals
       _callbacks = callbacks,
       _pageMode = initialPageMode,
       _index = ReaderContentIndex(
         sections: input.sections,
         chapters: input.chapters,
       ) {
    _autoScroll = AutoScrollController(onAdvance: _advanceAutoScroll);
    _autoScroll.addListener(_onAutoScrollChanged);
    itemPositions.itemPositions.addListener(_onItemPositionsChanged);
    _followPlaybackTimer = Timer.periodic(_followTickInterval, (_) {
      unawaited(_maybeFollowPlaybackCenter());
    });
    _resetNavigationState();
  }

  // ---- Scroll plumbing exposed to the view -------------------------------
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositions = ItemPositionsListener.create();
  final ScrollOffsetController scrollOffsetController =
      ScrollOffsetController();

  ReaderViewInput _input;
  ReaderViewCallbacks _callbacks;
  final ReaderContentIndex _index;

  late final AutoScrollController _autoScroll;
  Timer? _followPlaybackTimer;
  Timer? _progressDebounce;
  bool _disposed = false;

  static const Duration _followTickInterval = Duration(seconds: 1);
  static const Duration _followIdleThreshold = Duration(seconds: 10);
  static const Duration _progressDebounceDuration =
      Duration(milliseconds: 500);

  // ---- View state --------------------------------------------------------
  ReaderPageMode _pageMode;
  double _fontSize = 19;
  bool _toolbarVisible = false;
  int? _activeParagraphId;

  // ---- Navigation / progress --------------------------------------------
  int? _lastReportedParagraphId;
  int? _visibleChapterId;
  bool _scrollMoved = false;
  int _scrollGeneration = 0;
  int? _scrollReentryIndex;
  ReaderParagraph? _pendingProgressParagraph;

  // ---- Chapter window ----------------------------------------------------
  bool _loadingPrevious = false;
  bool _loadingNext = false;

  // ---- Playback following ------------------------------------------------
  bool _playbackFollow = true;
  bool _playbackFollowSuspendedByNavigation = false;
  PlaybackCursor? _pendingPlaybackTarget;
  int? _requestedPlaybackChapterId;
  DateTime? _lastUserScrollAt;

  // ---- Auto scroll -------------------------------------------------------
  bool _autoScrollPausedByToolbar = false;

  // ---- Paragraph tap bookkeeping ----------------------------------------
  int? _pendingParagraphTapId;
  Duration? _pendingParagraphTapAt;
  int? _lastTappedParagraphId;
  Duration? _lastParagraphTapAt;

  // ---- Read-only accessors ----------------------------------------------
  List<ReaderContentItem> get items => _index.items;

  ReaderPageMode get pageMode => _pageMode;

  double get fontSize => _fontSize;

  bool get toolbarVisible => _toolbarVisible;

  int? get activeParagraphId => _activeParagraphId;

  int? get visibleChapterId => _visibleChapterId;

  AutoScrollController get autoScroll => _autoScroll;

  /// True when the playing paragraph is being kept in view.
  bool get playbackFollow => _playbackFollow;

  /// Called after the view controller has rebuilt the list and wants the
  /// scroll view to land on the current position. Null unless the reader is
  /// mid-navigation.
  VoidCallback? pendingInitialJump;

  /// Called when the playing paragraph should be scrolled into view.
  VoidCallback? pendingFollowRequest;

  /// Replaces the host callbacks. The page refreshes these on every rebuild
  /// so the controller always closes over the current widget's handlers.
  set callbacks(ReaderViewCallbacks value) => _callbacks = value;

  /// Applies a fresh snapshot of host input. Returns true when the content
  /// list was rebuilt.
  bool update(ReaderViewInput input) {
    final contentChanged = _index.update(
      sections: input.sections,
      chapters: input.chapters,
    );
    final previous = _input;
    _input = input;
    if (input.navigationGeneration != previous.navigationGeneration) {
      _invalidatePendingProgressReport();
      _scrollMoved = false;
      _resetNavigationState();
      pendingInitialJump = _jumpToInitialPosition;
      _requestFrame();
    }
    if (previous.playbackStarting != input.playbackStarting ||
        previous.playbackCursor != input.playbackCursor ||
        contentChanged) {
      pendingFollowRequest = () => unawaited(followPlayingParagraph());
      _requestFrame();
    }
    return contentChanged;
  }

  void _requestFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) {
        return;
      }
      final jump = pendingInitialJump;
      final follow = pendingFollowRequest;
      pendingInitialJump = null;
      pendingFollowRequest = null;
      jump?.call();
      follow?.call();
    });
  }

  /// Requests a follow pass on the next frame, used when the page first opens
  /// on a playing paragraph.
  void requestFollowOnNextFrame() {
    pendingFollowRequest = () => unawaited(followPlayingParagraph());
    _requestFrame();
  }

  @override
  void dispose() {
    _disposed = true;
    itemPositions.itemPositions.removeListener(_onItemPositionsChanged);
    // Leaving the reader must stop the crawl so it never keeps scrolling in the
    // background after the page is gone.
    _autoScroll.removeListener(_onAutoScrollChanged);
    _autoScroll.dispose();
    _followPlaybackTimer?.cancel();
    _followPlaybackTimer = null;
    final pendingParagraph = _pendingProgressParagraph;
    _progressDebounce?.cancel();
    _progressDebounce = null;
    _pendingProgressParagraph = null;
    if (pendingParagraph != null &&
        pendingParagraph.id != _lastReportedParagraphId) {
      _lastReportedParagraphId = pendingParagraph.id;
      _callbacks.onReadingPositionChanged?.call(pendingParagraph);
    }
    super.dispose();
  }

  // ---- Page mode ---------------------------------------------------------

  /// Applies a mode picked from the reading-settings sheet. Switching takes
  /// effect immediately and notifies the host so it can persist.
  void selectPageMode(ReaderPageMode mode) {
    if (mode == _pageMode) {
      return;
    }
    // Preserve the reading place across the switch. Going to a paged mode, the
    // pager opens on [pagedInitialCursor] (current position). Coming back to
    // scroll, seed the freshly-mounted list to the same paragraph so it opens
    // there without a visible jump.
    if (mode == ReaderPageMode.scroll) {
      _scrollReentryIndex = currentReadingItemIndex;
    } else {
      _scrollReentryIndex = null;
      // Leaving scroll: stop the crawl so it can't keep running unseen behind
      // the pager (its button is hidden in paged modes).
      _autoScroll.stop();
    }
    _pageMode = mode;
    notifyListeners();
    _callbacks.onPageModeChanged?.call(mode);
  }

  // ---- Reading settings --------------------------------------------------

  void setFontSize(double value) {
    if (value == _fontSize) {
      return;
    }
    _fontSize = value;
    notifyListeners();
  }

  // ---- Toolbar -----------------------------------------------------------

  /// Reveals or hides the menu bar. Bringing up the menu while the crawl is
  /// running pauses it so the text stops moving under the menu; hiding the menu
  /// then resumes the crawl, giving a "tap to peek, tap to continue" feel. If
  /// the reader stopped or paused the crawl themselves while the menu was up,
  /// we leave it alone.
  void setToolbarVisible(bool visible) {
    if (visible == _toolbarVisible) {
      return;
    }
    _toolbarVisible = visible;
    notifyListeners();
    if (visible) {
      if (_autoScroll.isRunning) {
        _autoScroll.pause();
        _autoScrollPausedByToolbar = true;
      }
    } else if (_autoScrollPausedByToolbar) {
      _autoScrollPausedByToolbar = false;
      if (_autoScroll.isPaused) {
        _autoScroll.start();
      }
    }
  }

  void toggleToolbar() => setToolbarVisible(!_toolbarVisible);

  // ---- Auto scroll -------------------------------------------------------

  void toggleAutoScroll() {
    if (_index.isEmpty) {
      return;
    }
    _autoScroll.toggle();
  }

  void _onAutoScrollChanged() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Fired on every auto-scroll tick: nudge the list down by [offset] pixels
  /// over [duration]. Chaining these short linear animations yields a steady
  /// crawl the reader does not have to swipe for.
  void _advanceAutoScroll(double offset, Duration duration) {
    if (_disposed || !itemScrollController.isAttached) {
      return;
    }
    unawaited(
      scrollOffsetController.animateScroll(
        offset: offset,
        duration: duration,
        curve: Curves.linear,
      ),
    );
  }

  // ---- Scroll observation ------------------------------------------------

  bool handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _playbackFollow = false;
      // A user swipe to read clears the chrome, matching mainstream readers:
      // reveal by tapping the middle, hide by scrolling ("滑动滚动阅读内容，
      // 自动隐藏顶部、底部工具栏").
      setToolbarVisible(false);
      // A manual swipe should not fight the crawl, so suspend it for the
      // gesture — but keep it armed. It picks back up on its own once the drag
      // settles, so a manual nudge no longer drops the reader out of auto
      // scroll (matching how mainstream novel apps handle "auto read").
      _autoScroll.notifyUserInteractionStart();
    } else if (notification is ScrollUpdateNotification) {
      final scrollDelta = notification.scrollDelta;
      if (scrollDelta != null && scrollDelta != 0) {
        _scrollMoved = true;
        _invalidatePendingProgressReport();
        // Only a drag actually driven by the user counts as a manual
        // interaction. Programmatic scrolls (the follow-heartbeat's
        // scrollTo) must NOT refresh the timestamp, otherwise the heartbeat
        // would think the user is engaged and stop re-centring.
        if (notification.dragDetails != null) {
          _lastUserScrollAt = DateTime.now();
        }
      }
    } else if (notification is ScrollEndNotification) {
      // The gesture is over. Re-arm the playback-follow heartbeat so it
      // starts re-centring the playing paragraph again (it is suspended
      // during a drag to avoid fighting the swipe).
      if (!_playbackFollowSuspendedByNavigation) {
        _playbackFollow = true;
      }
      // Let the crawl resume after the swipe (and any fling) has stopped.
      _autoScroll.notifyUserInteractionEnd();
      final scrollMoved = _scrollMoved;
      _scrollMoved = false;
      if (scrollMoved) {
        final generation = ++_scrollGeneration;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed && generation == _scrollGeneration) {
            _scheduleVisiblePositionReport();
          }
        });
      }
    }
    return false;
  }

  void _onItemPositionsChanged() {
    if (_disposed) {
      return;
    }
    _updateVisibleChapter();
    _maybeLoadEdges();
  }

  List<ItemPosition> visiblePositions() {
    return itemPositions.itemPositions.value
        .where(
          (position) =>
              position.index >= 0 &&
              position.index < _index.length &&
              position.itemTrailingEdge > 0 &&
              position.itemLeadingEdge < 1,
        )
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));
  }

  void _updateVisibleChapter() {
    final visible = visiblePositions();
    if (visible.isEmpty) {
      return;
    }
    final chapterId = _index[visible.first.index].chapterId;
    if (chapterId != _visibleChapterId) {
      _visibleChapterId = chapterId;
      _callbacks.onVisibleChapterChanged?.call(chapterId);
    }
  }

  void _maybeLoadEdges() {
    final visible = visiblePositions();
    if (visible.isEmpty || _index.isEmpty) {
      return;
    }
    final first = visible.first;
    final last = visible.last;
    final anchor = ReaderViewportAnchor(
      itemKey: _index[first.index].key,
      alignment: first.itemLeadingEdge,
    );
    final visibleChapterIds = <int>{
      for (final position in visible) _index[position.index].chapterId,
    };
    if (first.index <= 3 &&
        _callbacks.onLoadPrevious != null &&
        !_loadingPrevious) {
      unawaited(
        _loadPrevious(visibleChapterIds: visibleChapterIds, anchor: anchor),
      );
    }
    if (_index.length - 1 - last.index <= 3 &&
        _callbacks.onLoadNext != null &&
        !_loadingNext) {
      unawaited(_loadNext(visibleChapterIds: visibleChapterIds, anchor: anchor));
    }
  }

  Future<void> _loadPrevious({
    required Set<int> visibleChapterIds,
    required ReaderViewportAnchor anchor,
  }) async {
    final callback = _callbacks.onLoadPrevious;
    if (callback == null || _loadingPrevious) {
      return;
    }
    _loadingPrevious = true;
    try {
      final mutation = await callback(
        visibleChapterIds: visibleChapterIds,
        anchor: anchor,
      );
      _restoreAnchor(mutation.anchor);
    } catch (_) {
      // Existing text remains readable; the next edge approach retries.
    } finally {
      _loadingPrevious = false;
    }
  }

  Future<void> _loadNext({
    required Set<int> visibleChapterIds,
    required ReaderViewportAnchor anchor,
  }) async {
    final callback = _callbacks.onLoadNext;
    if (callback == null || _loadingNext) {
      return;
    }
    _loadingNext = true;
    try {
      final mutation = await callback(
        visibleChapterIds: visibleChapterIds,
        anchor: anchor,
      );
      _restoreAnchor(mutation.anchor);
    } catch (_) {
      // Existing text remains readable; the next edge approach retries.
    } finally {
      _loadingNext = false;
    }
  }

  void _restoreAnchor(ReaderViewportAnchor? anchor) {
    if (anchor == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !itemScrollController.isAttached) {
        return;
      }
      final index = _index.indexOfKey(anchor.itemKey);
      if (index >= 0) {
        itemScrollController.jumpTo(index: index, alignment: anchor.alignment);
      }
    });
  }

  // ---- Reading position --------------------------------------------------

  void _scheduleVisiblePositionReport() {
    _progressDebounce?.cancel();
    _progressDebounce = null;
    final visible = visiblePositions();
    if (visible.isEmpty) {
      return;
    }
    ReaderParagraph? firstParagraph;
    for (final position in visible) {
      final item = _index[position.index];
      if (item is ReaderParagraphItem) {
        firstParagraph = item.paragraph;
        break;
      }
    }
    if (firstParagraph == null) {
      return;
    }
    final paragraph = firstParagraph;
    if (paragraph.id == _lastReportedParagraphId) {
      return;
    }
    _pendingProgressParagraph = paragraph;
    _progressDebounce = Timer(_progressDebounceDuration, () {
      if (_disposed) {
        return;
      }
      // Scrolling only records the reading position (for progress saving and
      // chapter tracking). It must NOT mark the paragraph as active: that is
      // what highlights a paragraph and reveals its "从这里朗读" button, and it
      // should only happen on an explicit tap.
      reportReadingPosition(paragraph);
    });
  }

  void reportReadingPosition(ReaderParagraph paragraph) {
    _invalidatePendingProgressReport();
    _lastReportedParagraphId = paragraph.id;
    _visibleChapterId = paragraph.chapterId;
    _callbacks.onVisibleChapterChanged?.call(paragraph.chapterId);
    _callbacks.onReadingPositionChanged?.call(paragraph);
  }

  void _invalidatePendingProgressReport() {
    _scrollGeneration += 1;
    _progressDebounce?.cancel();
    _progressDebounce = null;
    _pendingProgressParagraph = null;
  }

  // ---- Paragraph interaction ---------------------------------------------

  /// Records the pointer-down that may become one half of a double tap. The
  /// raw timestamp is captured here because [GestureDetector] would consume
  /// the gesture that the reader body also needs.
  void noteParagraphPointerDown(int paragraphId, Duration timeStamp) {
    _pendingParagraphTapId = paragraphId;
    _pendingParagraphTapAt = timeStamp;
  }

  void handleParagraphTap(ReaderParagraph paragraph) {
    final now = _pendingParagraphTapId == paragraph.id
        ? _pendingParagraphTapAt
        : null;
    _pendingParagraphTapId = null;
    _pendingParagraphTapAt = null;
    final previousTapAt = _lastParagraphTapAt;
    final elapsed = now != null && previousTapAt != null
        ? now - previousTapAt
        : null;
    final doubleTap = _lastTappedParagraphId == paragraph.id &&
        elapsed != null &&
        !elapsed.isNegative &&
        elapsed <= kDoubleTapTimeout;
    if (doubleTap) {
      _lastTappedParagraphId = null;
      _lastParagraphTapAt = null;
      if (!_input.playbackStarting) {
        play(paragraph);
      }
      return;
    }
    _lastTappedParagraphId = now == null ? null : paragraph.id;
    _lastParagraphTapAt = now;
    if (_pageMode == ReaderPageMode.scroll && now != null) {
      _callbacks.onWarmFrom?.call(paragraph);
    }
    selectParagraph(paragraph);
  }

  void selectParagraph(ReaderParagraph paragraph) {
    // In scroll mode paragraph taps must not produce a selection (no highlight,
    // no "从这里朗读" button). Preserve the existing reading-position report,
    // but never promote the tapped paragraph to active visual state.
    if (_pageMode == ReaderPageMode.scroll) {
      reportReadingPosition(paragraph);
      return;
    }
    _activeParagraphId = paragraph.id;
    notifyListeners();
    reportReadingPosition(paragraph);
  }

  void play(ReaderParagraph paragraph) {
    _pendingPlaybackTarget = PlaybackCursor(
      chapterId: paragraph.chapterId,
      paragraphIndex: paragraph.index,
    );
    _playbackFollowSuspendedByNavigation = false;
    _playbackFollow = true;
    _activeParagraphId = paragraph.id;
    notifyListeners();
    reportReadingPosition(paragraph);
    _callbacks.onPlayFrom?.call(paragraph);
  }

  /// Starts listening without asking where to begin:
  /// 1. the currently visible top paragraph (what the user is reading now), or
  ///    the paragraph they last tapped if it is still on screen;
  /// 2. otherwise the last saved position;
  /// 3. otherwise the very start of the book.
  void startListening() {
    if (_input.chapters.isEmpty) {
      return;
    }
    _lastUserScrollAt = null;
    _playbackFollowSuspendedByNavigation = false;
    _playbackFollow = true;
    final active = _index.paragraphForId(_activeParagraphId ?? -1);
    final target =
        (active != null && isParagraphVisible(active.id))
            ? active
            : topVisibleParagraph();
    if (target != null) {
      play(target);
      return;
    }
    // Nothing visible yet (still loading / empty window): fall back to the
    // saved position, then the first paragraph of chapter one. onListenFrom
    // resolves the chapter window if the target chapter is not loaded.
    final start =
        _input.initialCursor ??
        PlaybackCursor(
          chapterId: _input.chapters.first.id,
          paragraphIndex: 0,
        );
    _callbacks.onListenFrom?.call(start);
  }

  bool isParagraphVisible(int paragraphId) {
    for (final position in visiblePositions()) {
      final item = _index[position.index];
      if (item is ReaderParagraphItem && item.paragraph.id == paragraphId) {
        return true;
      }
    }
    return false;
  }

  ReaderParagraph? topVisibleParagraph() {
    for (final position in visiblePositions()) {
      final item = _index[position.index];
      if (item is ReaderParagraphItem) {
        return item.paragraph;
      }
    }
    return null;
  }

  // ---- Playback following ------------------------------------------------

  Future<void> followPlayingParagraph() async {
    // Scroll-follow only. In the paged modes, PaginatedReaderView flips to the
    // playing page itself (via its playbackCursor), and the scrollTo machinery
    // below (including the chapter-load side effect) does not apply.
    if (_pageMode != ReaderPageMode.scroll) {
      return;
    }
    final cursor = _input.playbackCursor;
    final pendingTarget = _pendingPlaybackTarget;
    if (pendingTarget != null) {
      if (cursor == pendingTarget) {
        _pendingPlaybackTarget = null;
      } else {
        if (!_input.playbackStarting) {
          _pendingPlaybackTarget = null;
        }
        return;
      }
    }
    if (!_playbackFollow || cursor == null || !_input.playbackActive) {
      return;
    }
    var index = _index.indexOfCursor(cursor);
    if (index < 0) {
      final callback = _callbacks.onPlaybackChapterNeeded;
      if (callback == null || _requestedPlaybackChapterId == cursor.chapterId) {
        return;
      }
      _requestedPlaybackChapterId = cursor.chapterId;
      try {
        await callback(cursor.chapterId);
      } finally {
        if (_requestedPlaybackChapterId == cursor.chapterId) {
          _requestedPlaybackChapterId = null;
        }
      }
      if (_disposed ||
          !_playbackFollow ||
          _input.playbackCursor != cursor) {
        return;
      }
      index = _index.indexOfCursor(cursor);
    }
    if (index < 0 || !itemScrollController.isAttached) {
      return;
    }
    if (_isVisibleIndex(index)) {
      return;
    }
    await _centerOn(index);
  }

  /// Heartbeat invoked every [_followTickInterval] while the reader page is
  /// alive. Re-centers the playing paragraph in the viewport whenever:
  ///  - auto-scroll is off, or
  ///  - the user has not scrolled manually for at least [_followIdleThreshold].
  /// The check is cheap (one position lookup) and a no-op when the paragraph
  /// is already inside the central band of the viewport, so the heartbeat is
  /// safe to run on a 1 Hz interval without any visible "snapping".
  Future<void> _maybeFollowPlaybackCenter() async {
    if (_disposed) return;
    if (_pageMode != ReaderPageMode.scroll) return;
    if (!_playbackFollow) return;
    final cursor = _input.playbackCursor;
    if (cursor == null || !_input.playbackActive) return;
    final index = _index.indexOfCursor(cursor);
    if (index < 0 || !itemScrollController.isAttached) return;

    final last = _lastUserScrollAt;
    final idle =
        last == null || DateTime.now().difference(last) > _followIdleThreshold;
    if (_autoScroll.isRunning) {
      // Auto-scroll is actively paging the screen: it drives the viewport
      // itself, so the heartbeat leaves it alone.
      return;
    }
    if (!idle) {
      // The user scrolled manually within the idle threshold: give them the
      // screen. Only re-centre once they stop interacting for a while.
      return;
    }
    if (_isVisibleIndex(index)) {
      return;
    }
    await _centerOn(index);
  }

  bool _isVisibleIndex(int index) {
    for (final position in visiblePositions()) {
      if (position.index == index) {
        return true;
      }
    }
    return false;
  }

  Future<void> _centerOn(int index) async {
    await itemScrollController.scrollTo(
      index: index,
      alignment: 0.5,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  // ---- Place keeping -----------------------------------------------------

  /// The index the scroll list should open on: a pending re-entry index (set
  /// when switching back from a paged mode) takes precedence, then the saved
  /// cursor, then the current chapter's heading.
  int get initialScrollIndex {
    final reentry = _scrollReentryIndex;
    if (reentry != null) {
      final maxIndex = _index.length - 1;
      return reentry < 0 ? 0 : (reentry > maxIndex ? maxIndex : reentry);
    }
    final cursor = _input.initialCursor;
    if (cursor != null) {
      final paragraphIndex = _index.indexOfCursor(cursor);
      if (paragraphIndex >= 0) {
        return paragraphIndex;
      }
    }
    final chapterId =
        _input.currentChapterId ?? cursor?.chapterId ?? _visibleChapterId;
    final headingIndex =
        chapterId == null ? -1 : _index.indexOfChapterHeading(chapterId);
    return headingIndex < 0 ? 0 : headingIndex;
  }

  /// Where the paged view should open: the current reading position if the
  /// reader has one, else the initial cursor, else the current chapter start.
  PlaybackCursor? get pagedInitialCursor {
    final cursor = _index.cursorForParagraphId(_lastReportedParagraphId ?? -1);
    if (cursor != null) {
      return cursor;
    }
    final initial = _input.initialCursor;
    if (initial != null) {
      return initial;
    }
    final chapterId = _input.currentChapterId ?? _visibleChapterId;
    if (chapterId != null) {
      return PlaybackCursor(chapterId: chapterId, paragraphIndex: 0);
    }
    return null;
  }

  int? get currentReadingItemIndex {
    final id = _lastReportedParagraphId;
    if (id == null) {
      return null;
    }
    final index = _index.indexOfParagraphId(id);
    return index >= 0 ? index : null;
  }

  void _resetNavigationState() {
    // A navigation target overrides any pending paged-mode re-entry seed.
    _scrollReentryIndex = null;
    final cursor = _input.initialCursor;
    _visibleChapterId = cursor?.chapterId ?? _input.currentChapterId;
    final paragraphs = _index.paragraphs;
    _activeParagraphId = cursor == null
        ? paragraphs.firstOrNull?.id
        : paragraphs
              .where(
                (paragraph) =>
                    paragraph.chapterId == cursor.chapterId &&
                    paragraph.index == cursor.paragraphIndex,
              )
              .firstOrNull
              ?.id;
    _lastReportedParagraphId = _activeParagraphId;
  }

  void _jumpToInitialPosition() {
    if (itemScrollController.isAttached && !_index.isEmpty) {
      itemScrollController.jumpTo(index: initialScrollIndex);
    }
  }

  // ---- Chapter navigation ------------------------------------------------

  /// Applies a chapter picked from the directory sheet. Playback following is
  /// suspended so the jump is not immediately undone by the heartbeat.
  void selectChapter(int chapterId) {
    _invalidatePendingProgressReport();
    _playbackFollowSuspendedByNavigation = true;
    _playbackFollow = false;
    notifyListeners();
    _callbacks.onChapterSelected?.call(chapterId);
  }
}
