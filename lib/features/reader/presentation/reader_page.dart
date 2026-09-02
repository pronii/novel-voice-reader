import 'package:flutter/material.dart';
import 'package:novel_voice_reader/app/design/paper_tokens.dart';
import 'package:novel_voice_reader/features/reader/application/reader_view_controller.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_content.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_page_mode.dart';
import 'package:novel_voice_reader/features/reader/presentation/paginated_reader_view.dart';
import 'package:novel_voice_reader/features/reader/presentation/sheets/reader_chapter_directory_sheet.dart';
import 'package:novel_voice_reader/features/reader/presentation/sheets/reader_settings_sheet.dart';
import 'package:novel_voice_reader/features/reader/presentation/widgets/reader_auto_scroll_bar.dart';
import 'package:novel_voice_reader/features/reader/presentation/widgets/reader_chapter_heading.dart';
import 'package:novel_voice_reader/features/reader/presentation/widgets/reader_listen_button.dart';
import 'package:novel_voice_reader/features/reader/presentation/widgets/reader_paragraph_view.dart';
import 'package:novel_voice_reader/features/reader/presentation/widgets/reader_tap_zone.dart';
import 'package:novel_voice_reader/features/reader/presentation/widgets/reader_toolbar.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

export 'package:novel_voice_reader/features/reader/application/reader_view_controller.dart'
    show ReaderEdgeLoadCallback;
export 'package:novel_voice_reader/features/reader/domain/reader_content.dart';
export 'package:novel_voice_reader/features/reader/domain/reader_page_mode.dart';

typedef ReaderPlaybackChapterCallback = Future<void> Function(int chapterId);
typedef ReaderListenCallback = void Function(PlaybackCursor start);

/// The reading surface: renders the loaded chapter window in either a
/// continuous scroll or a paged view, and exposes the gestures that drive it.
///
/// This widget is deliberately a shell. Every piece of durable state — scroll
/// plumbing, auto scroll, playback following, chapter-window edge loading,
/// progress reporting, toolbar visibility and page mode — lives in
/// [ReaderViewController], so this class keeps only the pointer bookkeeping
/// that is genuinely part of the gesture itself.
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
    this.onWarmFrom,
    this.onPlayFrom,
    this.onListenFrom,
    this.onStopPlayback,
    this.onOpenPlayer,
    this.onLoadPrevious,
    this.onLoadNext,
    this.onPlaybackChapterNeeded,
    this.initialPageMode = ReaderPageMode.scroll,
    this.onPageModeChanged,
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
  final ValueChanged<ReaderParagraph>? onWarmFrom;
  final ValueChanged<ReaderParagraph>? onPlayFrom;

  /// Starts listening from the given position. The reader page shows a
  /// dedicated "listen" entry (instead of auto-entering playback) and lets
  /// the user pick where to start; the actual playback is kicked off here.
  final ReaderListenCallback? onListenFrom;

  /// Stops the active listen session. The toolbar's circular listen/stop
  /// button calls this when the user wants to leave listen mode; the
  /// router is responsible for tearing the runtime down.
  final VoidCallback? onStopPlayback;
  final VoidCallback? onOpenPlayer;
  final ReaderEdgeLoadCallback? onLoadPrevious;
  final ReaderEdgeLoadCallback? onLoadNext;
  final ReaderPlaybackChapterCallback? onPlaybackChapterNeeded;

  /// The page-turn mode the reader opens in. Seeds the internal mode state on
  /// first build; later changes to this prop are ignored so the user's in-app
  /// selection (via the bottom bar) stays authoritative.
  final ReaderPageMode initialPageMode;

  /// Invoked immediately when the user picks a different mode in the bottom
  /// bar, so the caller can persist it. Not called for programmatic changes.
  final ValueChanged<ReaderPageMode>? onPageModeChanged;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

final class _ReaderPageState extends State<ReaderPage> {
  late ReaderViewController _controller;

  // Drives page turns for the paged modes from the body's left/right tap zones.
  // A turn is a no-op unless a PaginatedReaderView is currently mounted.
  final PaginatedReaderController _paginatedController =
      PaginatedReaderController();

  // Pointer bookkeeping for the body tap: a tap only counts if the pointer
  // stayed within a small radius between down and up, so a swipe or a scroll
  // never toggles the chrome.
  int? _bodyPointerId;
  Offset? _bodyPointerDownPosition;
  bool _bodyPointerTapEligible = false;

  @override
  void initState() {
    super.initState();
    _controller = ReaderViewController(
      input: _inputFromWidget(),
      callbacks: _callbacksFromWidget(),
      initialPageMode: widget.initialPageMode,
    );
    if (widget.playbackCursor != null) {
      _controller.requestFollowOnNextFrame();
    }
  }

  @override
  void didUpdateWidget(covariant ReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.callbacks = _callbacksFromWidget();
    _controller.update(_inputFromWidget());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ReaderViewInput _inputFromWidget() => ReaderViewInput(
    sections: widget.sections,
    chapters: widget.chapters,
    initialCursor: widget.initialCursor,
    currentChapterId: widget.currentChapterId,
    playbackCursor: widget.playbackCursor,
    playbackActive: widget.playbackActive,
    playbackStarting: widget.playbackStarting,
    navigationGeneration: widget.navigationGeneration,
  );

  ReaderViewCallbacks _callbacksFromWidget() => ReaderViewCallbacks(
    onChapterSelected: widget.onChapterSelected,
    onVisibleChapterChanged: widget.onVisibleChapterChanged,
    onReadingPositionChanged: widget.onReadingPositionChanged,
    onWarmFrom: widget.onWarmFrom,
    onPlayFrom: widget.onPlayFrom,
    onListenFrom: widget.onListenFrom,
    onPageModeChanged: widget.onPageModeChanged,
    onLoadPrevious: widget.onLoadPrevious,
    onLoadNext: widget.onLoadNext,
    onPlaybackChapterNeeded: widget.onPlaybackChapterNeeded,
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final items = _controller.items;
    return Scaffold(
      floatingActionButton: ReaderListenButton(
        visible: _controller.toolbarVisible,
        playing: widget.playbackActive,
        onStart: _controller.startListening,
        onStop: widget.onStopPlayback,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                  : _controller.pageMode == ReaderPageMode.scroll
                  ? NotificationListener<ScrollNotification>(
                      onNotification: _controller.handleScrollNotification,
                      child: ScrollablePositionedList.builder(
                        initialScrollIndex: _controller.initialScrollIndex,
                        itemScrollController: _controller.itemScrollController,
                        scrollOffsetController:
                            _controller.scrollOffsetController,
                        itemPositionsListener: _controller.itemPositions,
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            _buildItem(context, items[index]),
                      ),
                    )
                  : PaginatedReaderView(
                      // Explicit chapter navigation must discard the pager's
                      // old anchor. Adjacent window loads keep the generation
                      // stable and continue to preserve the current page.
                      key: ValueKey<String>(
                        'reader-pager-${_controller.pageMode.storageKey}-'
                        '${widget.navigationGeneration}',
                      ),
                      mode: _controller.pageMode,
                      items: items,
                      textStyle: _readingTextStyle(context),
                      headingStyle:
                          Theme.of(context).textTheme.headlineSmall ??
                          const TextStyle(fontSize: 24),
                      initialCursor: _controller.pagedInitialCursor,
                      playbackCursor: _controller.playbackFollow
                          ? widget.playbackCursor
                          : null,
                      playbackActive: widget.playbackActive,
                      onReadingPositionChanged:
                          _controller.reportReadingPosition,
                      onLoadPrevious: widget.onLoadPrevious,
                      onLoadNext: widget.onLoadNext,
                      controller: _paginatedController,
                    ),
            ),
            ReaderToolbar(
              visible: _controller.toolbarVisible,
              title: widget.bookTitle,
              pageMode: _controller.pageMode,
              autoScrollRunning: _controller.autoScroll.isRunning,
              hasChapters: widget.chapters.isNotEmpty,
              onBack: widget.onBackToLibrary,
              onShowChapterList: _showChapterList,
              onToggleAutoScroll: _controller.toggleAutoScroll,
              onShowReadingSettings: _showReadingSettings,
              onOpenPlayer: widget.onOpenPlayer,
            ),
            ReaderAutoScrollBar(
              visible: _controller.toolbarVisible,
              pageMode: _controller.pageMode,
              autoScroll: _controller.autoScroll,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, ReaderContentItem item) {
    return switch (item) {
      ReaderChapterHeadingItem(:final chapter) => ReaderChapterHeading(
        chapter: chapter,
        isEmpty: _paragraphsOf(chapter.id)?.isEmpty ?? false,
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

  List<ReaderParagraph>? _paragraphsOf(int chapterId) {
    for (final section in widget.sections) {
      if (section.chapter.id == chapterId) {
        return section.paragraphs;
      }
    }
    return null;
  }

  // The base style for flowing reading text: the serif "book" face at the
  // reader's chosen size. Shared by the scroll and paged views so the two
  // reading modes stay visually identical.
  TextStyle _readingTextStyle(BuildContext context) => TextStyle(
    fontFamily: PaperFonts.serif,
    fontSize: _controller.fontSize,
    height: 1.8,
    color: Theme.of(context).colorScheme.onSurface,
  );

  Widget _buildParagraph(BuildContext context, ReaderParagraph paragraph) {
    final scrollMode = _controller.pageMode == ReaderPageMode.scroll;
    final playing =
        widget.playbackActive &&
        widget.playbackCursor?.chapterId == paragraph.chapterId &&
        widget.playbackCursor?.paragraphIndex == paragraph.index;
    final allowSelection = !scrollMode;
    final active =
        allowSelection &&
        widget.playbackActive &&
        paragraph.id == _controller.activeParagraphId;
    return ReaderParagraphView(
      paragraph: paragraph,
      playing: playing,
      active: active,
      scrollMode: scrollMode,
      playbackStarting: widget.playbackStarting,
      textStyle: _readingTextStyle(context),
      onPointerDown: _controller.noteParagraphPointerDown,
      onTap: () => _controller.handleParagraphTap(paragraph),
      onPlay: () => _controller.play(paragraph),
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
    final tapPosition = event.position;
    final wasTap = _bodyPointerTapEligible;
    _clearBodyPointer();
    if (!wasTap) {
      return;
    }
    // The central third toggles the chrome in every mode. The left/right thirds
    // turn the page in the paged modes (left = previous, right = next); in
    // scroll mode they stay inert, so a stray tap while reading does nothing
    // ("滚动模式下点击左右不翻页，避免误触").
    final zone = readerTapZoneFor(context.findRenderObject(), tapPosition);
    switch (zone) {
      case ReaderTapZone.middle:
        _controller.toggleToolbar();
      case ReaderTapZone.left:
        if (_controller.pageMode != ReaderPageMode.scroll) {
          _paginatedController.previousPage();
        }
      case ReaderTapZone.right:
        if (_controller.pageMode != ReaderPageMode.scroll) {
          _paginatedController.nextPage();
        }
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

  Future<void> _showChapterList() async {
    final selectedChapterId = await showChapterDirectorySheet(
      context: context,
      chapters: widget.chapters,
      currentChapterId:
          _controller.visibleChapterId ??
          widget.currentChapterId ??
          widget.initialCursor?.chapterId,
    );
    if (selectedChapterId != null) {
      _controller.selectChapter(selectedChapterId);
    }
  }

  Future<void> _showReadingSettings() async {
    await showReaderSettingsSheet(
      context: context,
      initialFontSize: _controller.fontSize,
      initialPageMode: _controller.pageMode,
      autoScroll: _controller.autoScroll,
      hasContent: _controller.items.isNotEmpty,
      onFontSizeChanged: _controller.setFontSize,
      onPageModeSelected: _controller.selectPageMode,
    );
  }
}
