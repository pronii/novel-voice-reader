import 'dart:async';

import 'package:flutter/material.dart';
import 'package:novel_voice_reader/features/reader/application/auto_scroll_controller.dart';
import 'package:novel_voice_reader/features/reader/application/reader_chapter_window_controller.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_content.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

export 'package:novel_voice_reader/features/reader/domain/reader_content.dart';

typedef ReaderEdgeLoadCallback =
    Future<ReaderWindowMutation> Function({
      required Set<int> visibleChapterIds,
      required ReaderViewportAnchor anchor,
    });

typedef ReaderPlaybackChapterCallback = Future<void> Function(int chapterId);
typedef ReaderListenCallback = void Function(PlaybackCursor start);

final class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.chapters,
    required this.sections,
    this.currentChapterId,
    this.initialCursor,
    this.navigationGeneration = 0,
    this.playbackStarting = false,
    this.playbackCursor,
    this.playbackActive = false,
    this.onBackToLibrary,
    this.onChapterSelected,
    this.onVisibleChapterChanged,
    this.onReadingPositionChanged,
    this.onPlayFrom,
    this.onListenFrom,
    this.onOpenPlayer,
    this.onLoadPrevious,
    this.onLoadNext,
    this.onPlaybackChapterNeeded,
  });

  final int bookId;
  final String bookTitle;
  final List<ReaderChapter> chapters;
  final List<ReaderChapterSection> sections;
  final int? currentChapterId;
  final PlaybackCursor? initialCursor;
  final int navigationGeneration;
  final bool playbackStarting;
  final PlaybackCursor? playbackCursor;
  final bool playbackActive;
  final VoidCallback? onBackToLibrary;
  final ValueChanged<int>? onChapterSelected;
  final ValueChanged<int>? onVisibleChapterChanged;
  final ValueChanged<ReaderParagraph>? onReadingPositionChanged;
  final ValueChanged<ReaderParagraph>? onPlayFrom;
  /// Starts listening from the given position. The reader page shows a
  /// dedicated "listen" entry (instead of auto-entering playback) and lets
  /// the user pick where to start; the actual playback is kicked off here.
  final ReaderListenCallback? onListenFrom;
  final VoidCallback? onOpenPlayer;
  final ReaderEdgeLoadCallback? onLoadPrevious;
  final ReaderEdgeLoadCallback? onLoadNext;
  final ReaderPlaybackChapterCallback? onPlaybackChapterNeeded;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

final class _ReaderPageState extends State<ReaderPage> {
  final ItemPositionsListener _itemPositions = ItemPositionsListener.create();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ScrollOffsetController _scrollOffsetController =
      ScrollOffsetController();
  late final AutoScrollController _autoScroll = AutoScrollController(
    onAdvance: _advanceAutoScroll,
  );
  Timer? _progressDebounce;
  ReaderParagraph? _pendingProgressParagraph;
  int? _activeParagraphId;
  int? _lastReportedParagraphId;
  int? _visibleChapterId;
  bool _scrollMoved = false;
  bool _loadingPrevious = false;
  bool _loadingNext = false;
  bool _playbackFollow = true;
  PlaybackCursor? _pendingPlaybackTarget;
  int? _requestedPlaybackChapterId;
  int _scrollGeneration = 0;
  double _fontSize = 19;
  bool _toolbarVisible = false;
  // True when revealing the menu bar auto-paused a running crawl, so hiding the
  // menu can resume it — but only if the reader didn't stop/pause it meanwhile.
  bool _autoScrollPausedByToolbar = false;
  // Wall-clock time of the most recent user-driven scroll. Null while the user
  // has never scrolled in this page session; the follow timer treats null the
  // same as "idle for a very long time" so a fresh reader page re-centres
  // playback immediately when auto-scroll is off.
  DateTime? _lastUserScrollAt;
  // 1 Hz re-centering heartbeat. While auto-scroll is off, or the user has
  // been idle for more than [_followIdleThreshold], the playing paragraph is
  // recentred every tick if it drifts off-screen.
  Timer? _followPlaybackTimer;
  static const Duration _followTickInterval = Duration(seconds: 1);
  static const Duration _followIdleThreshold = Duration(seconds: 10);
  int? _bodyPointerId;
  Offset? _bodyPointerDownPosition;
  bool _bodyPointerTapEligible = false;

  List<ReaderContentItem> get _items {
    final items = <ReaderContentItem>[
      for (final section in widget.sections) ...[
        ReaderChapterHeadingItem(section.chapter),
        for (final paragraph in section.paragraphs)
          ReaderParagraphItem(paragraph),
      ],
    ];
    if (widget.sections.isNotEmpty &&
        widget.chapters.isNotEmpty &&
        widget.sections.last.chapter.id == widget.chapters.last.id) {
      items.add(ReaderBookEndItem(widget.sections.last.chapter.id));
    }
    return items;
  }

  @override
  void initState() {
    super.initState();
    _resetNavigationState();
    _itemPositions.itemPositions.addListener(_onItemPositionsChanged);
    _autoScroll.addListener(_onAutoScrollChanged);
    _followPlaybackTimer = Timer.periodic(
      _followTickInterval,
      (_) {
        _maybeFollowPlaybackCenter();
      },
    );
    if (widget.playbackCursor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_followPlayingParagraph());
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationGeneration != widget.navigationGeneration) {
      _invalidatePendingProgressReport();
      _scrollMoved = false;
      _resetNavigationState();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _jumpToInitialPosition();
        }
      });
    }
    if (oldWidget.playbackStarting != widget.playbackStarting ||
        oldWidget.playbackCursor != widget.playbackCursor ||
        !identical(oldWidget.sections, widget.sections)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_followPlayingParagraph());
        }
      });
    }
  }

  @override
  void dispose() {
    _itemPositions.itemPositions.removeListener(_onItemPositionsChanged);
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
      widget.onReadingPositionChanged?.call(pendingParagraph);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      floatingActionButton: _buildListenButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: Stack(
          children: [
            Listener(
              key: const Key('reader-body'),
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onBodyPointerDown,
              onPointerMove: _onBodyPointerMove,
              onPointerUp: _onBodyPointerUp,
              onPointerCancel: _onBodyPointerCancel,
              child: items.isEmpty
                  ? const Center(child: Text('图书没有可阅读内容'))
                  : NotificationListener<ScrollNotification>(
                      onNotification: _onScrollNotification,
                      child: ScrollablePositionedList.builder(
                        initialScrollIndex: _initialScrollIndex,
                        itemScrollController: _itemScrollController,
                        scrollOffsetController: _scrollOffsetController,
                        itemPositionsListener: _itemPositions,
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            _buildItem(context, items[index]),
                      ),
                    ),
            ),
            ClipRect(
              child: AnimatedSlide(
                key: const Key('reader-toolbar'),
                offset: _toolbarVisible ? Offset.zero : const Offset(0, -1),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: IgnorePointer(
                  ignoring: !_toolbarVisible,
                  child: ExcludeSemantics(
                    excluding: !_toolbarVisible,
                    child: SizedBox(
                      height: kToolbarHeight,
                      child: AppBar(
                        primary: false,
                        leading: IconButton(
                          tooltip: '返回书架',
                          onPressed: widget.onBackToLibrary,
                          icon: const Icon(Icons.arrow_back),
                        ),
                        title: Text(
                          widget.bookTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        actions: [
                          IconButton(
                            tooltip: '章节目录',
                            onPressed: widget.chapters.isEmpty
                                ? null
                                : _showChapterList,
                            icon: const Icon(Icons.format_list_numbered),
                          ),
                          IconButton(
                            tooltip: _autoScroll.isRunning
                                ? '暂停自动滚动'
                                : '自动滚动',
                            onPressed: _toggleAutoScroll,
                            icon: Icon(
                              _autoScroll.isRunning
                                  ? Icons.pause
                                  : Icons.keyboard_double_arrow_down,
                            ),
                          ),
                          IconButton(
                            tooltip: '阅读设置',
                            onPressed: _showReadingSettings,
                            icon: const Icon(Icons.text_fields),
                          ),
                          IconButton(
                            tooltip: '播放器',
                            onPressed: widget.onOpenPlayer,
                            icon: const Icon(Icons.graphic_eq),
                          ),
                          IconButton(
                            tooltip: '播放',
                            onPressed: widget.playbackStarting
                                ? null
                                : _playActive,
                            icon: const Icon(Icons.play_arrow),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildAutoScrollOverlay(context),
          ],
        ),
      ),
    );
  }

  // A compact control bar for the crawl. It is not persistent: it rides with
  // the toolbar, appearing only while the toolbar is revealed (tap to show,
  // tap again to hide) so it never sits on top of the text while reading.
  Widget _buildAutoScrollOverlay(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ListenableBuilder(
        listenable: _autoScroll,
        builder: (context, _) {
          if (!_toolbarVisible || _autoScroll.status == AutoScrollStatus.idle) {
            return const SizedBox.shrink();
          }
          final theme = Theme.of(context);
          final running = _autoScroll.isRunning;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Material(
                  key: const Key('auto-scroll-overlay'),
                  elevation: 6,
                  borderRadius: BorderRadius.circular(28),
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('速度', style: theme.textTheme.labelLarge),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${_autoScroll.speedLevel}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        SizedBox(
                          width: 168,
                          child: Slider(
                            key: const Key('auto-scroll-speed-slider'),
                            min: AutoScrollController.minLevel.toDouble(),
                            max: AutoScrollController.maxLevel.toDouble(),
                            value: _autoScroll.speedLevel
                                .clamp(
                                  AutoScrollController.minLevel,
                                  AutoScrollController.maxLevel,
                                )
                                .toDouble(),
                            onChanged: (value) =>
                                _autoScroll.speedLevel = value.round(),
                          ),
                        ),
                        const SizedBox(
                          height: 24,
                          child: VerticalDivider(width: 12),
                        ),
                        IconButton(
                          tooltip: running ? '暂停' : '继续',
                          onPressed: _autoScroll.toggle,
                          icon: Icon(running ? Icons.pause : Icons.play_arrow),
                        ),
                        IconButton(
                          tooltip: '退出自动滚动',
                          onPressed: _autoScroll.stop,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onBodyPointerDown(PointerDownEvent event) {
    if (_bodyPointerId != null) {
      return;
    }
    _bodyPointerId = event.pointer;
    _bodyPointerDownPosition = event.position;
    _bodyPointerTapEligible = true;
  }

  void _onBodyPointerMove(PointerMoveEvent event) {
    if (event.pointer != _bodyPointerId || !_bodyPointerTapEligible) {
      return;
    }
    final origin = _bodyPointerDownPosition;
    if (origin != null && (event.position - origin).distance > 8) {
      _bodyPointerTapEligible = false;
    }
  }

  void _onBodyPointerUp(PointerUpEvent event) {
    if (event.pointer != _bodyPointerId) {
      return;
    }
    final shouldToggle = _bodyPointerTapEligible;
    _clearBodyPointer();
    if (shouldToggle) {
      _setToolbarVisible(!_toolbarVisible);
    }
  }

  void _onBodyPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _bodyPointerId) {
      _clearBodyPointer();
    }
  }

  void _clearBodyPointer() {
    _bodyPointerId = null;
    _bodyPointerDownPosition = null;
    _bodyPointerTapEligible = false;
  }

  // Reveals or hides the menu bar. Bringing up the menu while the crawl is
  // running pauses it so the text stops moving under the menu; hiding the menu
  // then resumes the crawl, giving a "tap to peek, tap to continue" feel. If
  // the reader stopped or paused the crawl themselves while the menu was up, we
  // leave it alone.
  void _setToolbarVisible(bool visible) {
    if (visible == _toolbarVisible) {
      return;
    }
    setState(() => _toolbarVisible = visible);
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

  void _toggleAutoScroll() {
    if (_items.isEmpty) {
      return;
    }
    _autoScroll.toggle();
  }

  // Rebuild so the toolbar's auto-scroll button reflects the current status.
  void _onAutoScrollChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // Fired on every auto-scroll tick: nudge the list down by [offset] pixels
  // over [duration]. Chaining these short linear animations yields a steady
  // crawl the reader does not have to swipe for.
  void _advanceAutoScroll(double offset, Duration duration) {
    if (!mounted || !_itemScrollController.isAttached) {
      return;
    }
    unawaited(
      _scrollOffsetController.animateScroll(
        offset: offset,
        duration: duration,
        curve: Curves.linear,
      ),
    );
  }

  Widget _buildItem(BuildContext context, ReaderContentItem item) {
    return switch (item) {
      ReaderChapterHeadingItem(:final chapter) => _buildChapterHeading(
        context,
        chapter,
      ),
      ReaderParagraphItem(:final paragraph) => _buildParagraph(
        context,
        paragraph,
      ),
      ReaderBookEndItem() => const Padding(
        padding: EdgeInsets.fromLTRB(20, 36, 20, 52),
        child: Center(child: Text('全书读完')),
      ),
    };
  }

  Widget _buildChapterHeading(BuildContext context, ReaderChapter chapter) {
    final section = widget.sections
        .where((candidate) => candidate.chapter.id == chapter.id)
        .firstOrNull;
    return Padding(
      key: ValueKey<String>('chapter-heading-${chapter.id}'),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(chapter.title, style: Theme.of(context).textTheme.headlineSmall),
          if (section != null && section.paragraphs.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24, bottom: 12),
              child: Center(child: Text('本章没有可朗读内容')),
            ),
        ],
      ),
    );
  }

  Widget _buildParagraph(BuildContext context, ReaderParagraph paragraph) {
    // Only light up paragraphs once the user is actually listening. Before
    // entering listen mode the page is pure text: tapping a paragraph does
    // not show an active highlight or a "从这里朗读" button — the only way
    // into listening is the dedicated 听小说 button (which then shows the
    // start-position picker). Inside listen mode, the active selection and
    // its read-from-here button are how the user re-targets playback.
    final playing =
        widget.playbackActive &&
        widget.playbackCursor?.chapterId == paragraph.chapterId &&
        widget.playbackCursor?.paragraphIndex == paragraph.index;
    final active = widget.playbackActive && paragraph.id == _activeParagraphId;
    return KeyedSubtree(
      key: playing
          ? ValueKey<String>(
              'playing-paragraph-${paragraph.chapterId}-${paragraph.index}',
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: InkWell(
          key: ValueKey<String>(
            active
                ? 'active-paragraph-${paragraph.id}'
                : 'paragraph-${paragraph.id}',
          ),
          borderRadius: BorderRadius.circular(6),
          onTap: () => _selectParagraph(paragraph),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: playing
                  ? Theme.of(context).colorScheme.primaryContainer
                  : active
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paragraph.text,
                  style: TextStyle(fontSize: _fontSize, height: 1.8),
                ),
                if (active)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: widget.playbackStarting
                          ? null
                          : () => _play(paragraph),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('从这里朗读'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int get _initialScrollIndex {
    final items = _items;
    final cursor = widget.initialCursor;
    if (cursor != null) {
      final paragraphIndex = items.indexWhere(
        (item) =>
            item is ReaderParagraphItem &&
            item.paragraph.chapterId == cursor.chapterId &&
            item.paragraph.index == cursor.paragraphIndex,
      );
      if (paragraphIndex >= 0) {
        return paragraphIndex;
      }
    }
    final chapterId =
        widget.currentChapterId ?? cursor?.chapterId ?? _visibleChapterId;
    final headingIndex = items.indexWhere(
      (item) => item is ReaderChapterHeadingItem && item.chapterId == chapterId,
    );
    return headingIndex < 0 ? 0 : headingIndex;
  }

  void _resetNavigationState() {
    final cursor = widget.initialCursor;
    _visibleChapterId = cursor?.chapterId ?? widget.currentChapterId;
    final paragraphs = widget.sections.expand((section) => section.paragraphs);
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
    if (_itemScrollController.isAttached && _items.isNotEmpty) {
      _itemScrollController.jumpTo(index: _initialScrollIndex);
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _playbackFollow = false;
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
      // during a drag to avoid fighting the swipe). The comment in
      // ScrollStart promised "picks back up on its own once the drag
      // settles" - this is where that promise is kept.
      _playbackFollow = true;
      // Let the crawl resume after the swipe (and any fling) has stopped.
      _autoScroll.notifyUserInteractionEnd();
      final scrollMoved = _scrollMoved;
      _scrollMoved = false;
      if (scrollMoved) {
        final generation = ++_scrollGeneration;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && generation == _scrollGeneration) {
            _scheduleVisiblePositionReport();
          }
        });
      }
    }
    return false;
  }

  void _onItemPositionsChanged() {
    if (!mounted) {
      return;
    }
    _updateVisibleChapter();
    _maybeLoadEdges();
  }

  List<ItemPosition> _visiblePositions() {
    return _itemPositions.itemPositions.value
        .where(
          (position) =>
              position.index >= 0 &&
              position.index < _items.length &&
              position.itemTrailingEdge > 0 &&
              position.itemLeadingEdge < 1,
        )
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));
  }

  void _updateVisibleChapter() {
    final visible = _visiblePositions();
    if (visible.isEmpty) {
      return;
    }
    final chapterId = _items[visible.first.index].chapterId;
    if (chapterId != _visibleChapterId) {
      _visibleChapterId = chapterId;
      widget.onVisibleChapterChanged?.call(chapterId);
    }
  }

  void _maybeLoadEdges() {
    final visible = _visiblePositions();
    final items = _items;
    if (visible.isEmpty || items.isEmpty) {
      return;
    }
    final first = visible.first;
    final last = visible.last;
    final anchor = ReaderViewportAnchor(
      itemKey: items[first.index].key,
      alignment: first.itemLeadingEdge,
    );
    final visibleChapterIds = {
      for (final position in visible) items[position.index].chapterId,
    };
    if (first.index <= 3 &&
        widget.onLoadPrevious != null &&
        !_loadingPrevious) {
      unawaited(
        _loadPrevious(visibleChapterIds: visibleChapterIds, anchor: anchor),
      );
    }
    if (items.length - 1 - last.index <= 3 &&
        widget.onLoadNext != null &&
        !_loadingNext) {
      unawaited(
        _loadNext(visibleChapterIds: visibleChapterIds, anchor: anchor),
      );
    }
  }

  Future<void> _loadPrevious({
    required Set<int> visibleChapterIds,
    required ReaderViewportAnchor anchor,
  }) async {
    final callback = widget.onLoadPrevious;
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
    final callback = widget.onLoadNext;
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
      if (!mounted || !_itemScrollController.isAttached) {
        return;
      }
      final index = _items.indexWhere((item) => item.key == anchor.itemKey);
      if (index >= 0) {
        _itemScrollController.jumpTo(index: index, alignment: anchor.alignment);
      }
    });
  }

  void _scheduleVisiblePositionReport() {
    _progressDebounce?.cancel();
    _progressDebounce = null;
    final visible = _visiblePositions();
    if (visible.isEmpty) {
      return;
    }
    final visibleItems = [
      for (final position in visible) _items[position.index],
    ];
    final firstParagraph = visibleItems
        .whereType<ReaderParagraphItem>()
        .firstOrNull;
    if (firstParagraph == null) {
      return;
    }
    final paragraph = firstParagraph.paragraph;
    if (paragraph.id == _lastReportedParagraphId) {
      return;
    }
    _pendingProgressParagraph = paragraph;
    _progressDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) {
        return;
      }
      // Scrolling only records the reading position (for progress saving and
      // chapter tracking). It must NOT mark the paragraph as active: that is
      // what highlights a paragraph and reveals its "从这里朗读" button, and it
      // should only happen on an explicit tap.
      _reportReadingPosition(paragraph);
    });
  }

  void _selectParagraph(ReaderParagraph paragraph) {
    setState(() => _activeParagraphId = paragraph.id);
    _reportReadingPosition(paragraph);
  }

  void _reportReadingPosition(ReaderParagraph paragraph) {
    _invalidatePendingProgressReport();
    _lastReportedParagraphId = paragraph.id;
    _visibleChapterId = paragraph.chapterId;
    widget.onVisibleChapterChanged?.call(paragraph.chapterId);
    widget.onReadingPositionChanged?.call(paragraph);
  }

  void _invalidatePendingProgressReport() {
    _scrollGeneration += 1;
    _progressDebounce?.cancel();
    _progressDebounce = null;
    _pendingProgressParagraph = null;
  }

  // A prominent "listen" entry point. Opening a book no longer drops the user
  // straight into playback; tapping 听小说 starts listening immediately,
  // matching how mainstream novel apps (起点读书 / 番茄小说 / 微信读书) behave:
  // no "where to start" picker — it resumes from where the user is currently
  // reading, or from the last saved position, or from the top of the book.
  Widget _buildListenButton(BuildContext context) {
    if (widget.playbackActive) {
      // Already listening — the toolbar play/pause controls take over.
      return const SizedBox.shrink();
    }
    return FloatingActionButton.extended(
      key: const Key('reader-listen-button'),
      onPressed: _startListening,
      icon: const Icon(Icons.headphones),
      label: const Text('听小说'),
    );
  }

  /// Starts listening immediately without asking where to begin:
  /// 1. the currently visible top paragraph (what the user is reading now), or
  ///    the paragraph they last tapped if it is still on screen;
  /// 2. otherwise the last saved position;
  /// 3. otherwise the very start of the book.
  void _startListening() {
    if (widget.chapters.isEmpty) {
      return;
    }
    _lastUserScrollAt = null;
    _playbackFollow = true;
    final active = widget.sections
        .expand((section) => section.paragraphs)
        .where((paragraph) => paragraph.id == _activeParagraphId)
        .firstOrNull;
    final target = (active != null && _isParagraphVisible(active.id))
        ? active
        : _topVisibleParagraph();
    if (target != null) {
      _play(target);
      return;
    }
    // Nothing visible yet (still loading / empty window): fall back to the
    // saved position, then the first paragraph of chapter one. onListenFrom
    // resolves the chapter window if the target chapter is not loaded.
    final start = widget.initialCursor ??
        PlaybackCursor(
          chapterId: widget.chapters.first.id,
          paragraphIndex: 0,
        );
    widget.onListenFrom?.call(start);
  }

  void _playActive() {
    final active = widget.sections
        .expand((section) => section.paragraphs)
        .where((paragraph) => paragraph.id == _activeParagraphId)
        .firstOrNull;
    // If the tapped paragraph is still on screen, play it. Otherwise the reader
    // has scrolled away (scrolling no longer changes the selection), so start
    // from the top of what they are currently reading instead of a stale,
    // off-screen selection.
    final target = (active != null && _isParagraphVisible(active.id))
        ? active
        : (_topVisibleParagraph() ?? active);
    if (target != null) {
      _play(target);
    }
  }

  bool _isParagraphVisible(int paragraphId) {
    for (final position in _visiblePositions()) {
      final item = _items[position.index];
      if (item is ReaderParagraphItem && item.paragraph.id == paragraphId) {
        return true;
      }
    }
    return false;
  }

  ReaderParagraph? _topVisibleParagraph() {
    for (final position in _visiblePositions()) {
      final item = _items[position.index];
      if (item is ReaderParagraphItem) {
        return item.paragraph;
      }
    }
    return null;
  }

  void _play(ReaderParagraph paragraph) {
    _pendingPlaybackTarget = PlaybackCursor(
      chapterId: paragraph.chapterId,
      paragraphIndex: paragraph.index,
    );
    _playbackFollow = true;
    setState(() => _activeParagraphId = paragraph.id);
    _reportReadingPosition(paragraph);
    widget.onPlayFrom?.call(paragraph);
  }

  Future<void> _followPlayingParagraph() async {
    final cursor = widget.playbackCursor;
    final pendingTarget = _pendingPlaybackTarget;
    if (pendingTarget != null) {
      if (cursor == pendingTarget) {
        _pendingPlaybackTarget = null;
      } else {
        if (!widget.playbackStarting) {
          _pendingPlaybackTarget = null;
        }
        return;
      }
    }
    if (!_playbackFollow || cursor == null || !widget.playbackActive) {
      return;
    }
    var index = _playingParagraphIndex(cursor);
    if (index < 0) {
      final callback = widget.onPlaybackChapterNeeded;
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
      if (!mounted || !_playbackFollow || widget.playbackCursor != cursor) {
        return;
      }
      index = _playingParagraphIndex(cursor);
    }
    if (index < 0 || !_itemScrollController.isAttached) {
      return;
    }
    final visible = _visiblePositions();
    if (visible.any((position) => position.index == index)) {
      return;
    }
    await _itemScrollController.scrollTo(
      index: index,
      alignment: 0.5,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  /// Heartbeat invoked every [_followTickInterval] while the reader page is
  /// alive. Re-centers the playing paragraph in the viewport whenever:
  ///  - auto-scroll is off, or
  ///  - the user has not scrolled manually for at least
  ///    [_followIdleThreshold].
  /// The check is cheap (one position lookup) and a no-op when the paragraph
  /// is already inside the central band of the viewport, so the heartbeat is
  /// safe to run on a 1 Hz interval without any visible "snapping".
  Future<void> _maybeFollowPlaybackCenter() async {
    if (!mounted) return;
    if (!_playbackFollow) return;
    final cursor = widget.playbackCursor;
    if (cursor == null || !widget.playbackActive) return;
    final index = _playingParagraphIndex(cursor);
    if (index < 0 || !_itemScrollController.isAttached) return;

    final autoScrollOn = _autoScroll.isRunning;
    final last = _lastUserScrollAt;
    final idle =
        last == null || DateTime.now().difference(last) > _followIdleThreshold;
    if (autoScrollOn) {
      // Auto-scroll is actively paging the screen: it drives the viewport
      // itself, so the heartbeat leaves it alone.
      return;
    }
    if (!idle) {
      // The user scrolled manually within the idle threshold: give them the
      // screen. Only re-centre once they stop interacting for a while.
      return;
    }

    final visible = _visiblePositions();
    ItemPosition? pos;
    for (final p in visible) {
      if (p.index == index) {
        pos = p;
        break;
      }
    }
    if (pos == null) {
      // Paragraph isn't even on screen — re-centre it.
      await _itemScrollController.scrollTo(
        index: index,
        alignment: 0.5,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
      return;
    }
    // Treat only a narrow band around the viewport middle (≈ ±5%) as
    // "already centred" - the heartbeat should snap any meaningful drift
    // back to the centre, not leave the paragraph sitting in the top
    // quarter of the screen.
    const nearCenter = 0.05;
    final leading = pos.itemLeadingEdge;
    final trailing = pos.itemTrailingEdge;
    if (leading > 0.5 - nearCenter && trailing < 0.5 + nearCenter) {
      return;
    }
    await _itemScrollController.scrollTo(
      index: index,
      alignment: 0.5,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  int _playingParagraphIndex(PlaybackCursor cursor) {
    return _items.indexWhere(
      (item) =>
          item is ReaderParagraphItem &&
          item.paragraph.chapterId == cursor.chapterId &&
          item.paragraph.index == cursor.paragraphIndex,
    );
  }

  Future<void> _showChapterList() async {
    var query = '';
    final selectedChapterId = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final normalizedQuery = query.trim().toLowerCase();
          final filteredChapters = widget.chapters.where((chapter) {
            return chapter.title.toLowerCase().contains(normalizedQuery) ||
                '${chapter.index + 1}'.contains(normalizedQuery);
          }).toList();
          final currentChapterId =
              _visibleChapterId ??
              widget.currentChapterId ??
              widget.initialCursor?.chapterId;
          final currentChapterIndex = filteredChapters.indexWhere(
            (chapter) => chapter.id == currentChapterId,
          );

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      '章节目录',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: '搜索章节',
                      ),
                      onChanged: (value) {
                        setSheetState(() => query = value);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filteredChapters.isEmpty
                        ? const Center(child: Text('没有匹配的章节'))
                        : PageStorage(
                            bucket: PageStorageBucket(),
                            child: ScrollablePositionedList.builder(
                              key: PageStorageKey<String>(
                                'chapter-directory-$query',
                              ),
                              initialScrollIndex:
                                  (currentChapterIndex < 0 ||
                                      currentChapterIndex >=
                                          filteredChapters.length)
                                  ? 0
                                  : currentChapterIndex,
                              itemCount: filteredChapters.length,
                              itemBuilder: (context, index) {
                                final chapter = filteredChapters[index];
                                final selected =
                                    chapter.id == currentChapterId;
                                return ListTile(
                                  title: Text(chapter.title),
                                  leading: SizedBox(
                                    width: 32,
                                    child: Text('${chapter.index + 1}'),
                                  ),
                                  trailing: selected
                                      ? const Icon(Icons.check)
                                      : null,
                                  selected: selected,
                                  onTap: () =>
                                      Navigator.of(context).pop(chapter.id),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (selectedChapterId != null) {
      _invalidatePendingProgressReport();
      widget.onChapterSelected?.call(selectedChapterId);
    }
  }

  Future<void> _showReadingSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('字号', style: Theme.of(context).textTheme.titleMedium),
                Slider(
                  key: const Key('reader-font-size-slider'),
                  value: _fontSize,
                  min: 15,
                  max: 30,
                  divisions: 15,
                  label: _fontSize.round().toString(),
                  onChanged: (value) {
                    setState(() => _fontSize = value);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 8),
                _buildAutoScrollSettings(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutoScrollSettings(BuildContext context) {
    return ListenableBuilder(
      listenable: _autoScroll,
      builder: (context, _) {
        final running = _autoScroll.isRunning;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '自动滚动',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '速度：${_autoScroll.speedLevel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.directions_walk, size: 20),
                Expanded(
                  child: Slider(
                    min: AutoScrollController.minLevel.toDouble(),
                    max: AutoScrollController.maxLevel.toDouble(),
                    value: _autoScroll.speedLevel
                        .clamp(
                          AutoScrollController.minLevel,
                          AutoScrollController.maxLevel,
                        )
                        .toDouble(),
                    label: '${_autoScroll.speedLevel}',
                    onChanged: (value) =>
                        _autoScroll.speedLevel = value.round(),
                  ),
                ),
                const Icon(Icons.directions_run, size: 20),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _items.isEmpty ? null : _autoScroll.toggle,
                    icon: Icon(running ? Icons.pause : Icons.play_arrow),
                    label: Text(running ? '暂停' : '开始'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _autoScroll.status == AutoScrollStatus.idle
                      ? null
                      : _autoScroll.stop,
                  icon: const Icon(Icons.stop),
                  label: const Text('停止'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
