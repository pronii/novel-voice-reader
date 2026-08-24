import 'package:flutter/material.dart';
import 'package:page_flip/page_flip.dart';
import 'package:novel_voice_reader/features/reader/application/text_paginator.dart';
import 'package:novel_voice_reader/features/reader/application/reader_chapter_window_controller.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_content.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_page_mode.dart';

/// Edge-load callback shape, matching `ReaderEdgeLoadCallback` in reader_page
/// (declared here to avoid importing the reader page and creating a cycle).
typedef PaginatedEdgeLoad =
    Future<ReaderWindowMutation> Function({
      required Set<int> visibleChapterIds,
      required ReaderViewportAnchor anchor,
    });

/// Renders the reader as discrete left/right pages for the [ReaderPageMode.slide]
/// and [ReaderPageMode.curl] modes.
///
/// The current chapter window ([items]) is laid out by [TextPaginator] to fit the
/// available viewport. The view:
///  - opens on the page containing [initialCursor];
///  - reports the first paragraph of each page via [onReadingPositionChanged] as
///    the user turns, reusing the reader's existing progress persistence;
///  - triggers [onLoadPrevious] / [onLoadNext] as it nears an edge, then
///    re-paginates and re-anchors to the same paragraph when the (sliding)
///    window supplies new [items];
///  - re-paginates while preserving the reading position when the font size or
///    viewport changes.
///
/// Tapping to toggle the toolbar is handled by the reader's surrounding pointer
/// listener, not here.
class PaginatedReaderView extends StatefulWidget {
  const PaginatedReaderView({
    super.key,
    required this.mode,
    required this.items,
    required this.textStyle,
    required this.headingStyle,
    this.initialCursor,
    this.playbackCursor,
    this.playbackActive = false,
    this.onReadingPositionChanged,
    this.onLoadPrevious,
    this.onLoadNext,
    this.controller,
  });

  final ReaderPageMode mode;
  final List<ReaderContentItem> items;
  final TextStyle textStyle;
  final TextStyle headingStyle;
  final PlaybackCursor? initialCursor;

  /// The paragraph currently being narrated. When [playbackActive] is true and
  /// this changes, the view flips to the page containing it (best-effort: only
  /// when that paragraph is within the currently paginated window).
  final PlaybackCursor? playbackCursor;

  /// Whether audio is playing; gates the playback-follow behaviour above.
  final bool playbackActive;

  final ValueChanged<ReaderParagraph>? onReadingPositionChanged;
  final PaginatedEdgeLoad? onLoadPrevious;
  final PaginatedEdgeLoad? onLoadNext;

  /// Lets the surrounding reader drive page turns from its left/right tap
  /// zones. Optional — swipe / curl gestures work without it.
  final PaginatedReaderController? controller;

  @override
  State<PaginatedReaderView> createState() => _PaginatedReaderViewState();
}

class _PaginatedReaderViewState extends State<PaginatedReaderView> {
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(24, 24, 24, 24);
  static const double _blockSpacing = 14;
  // A little vertical slack so sub-pixel rounding in measurement can never make
  // a page's content overflow its box (which would be a layout error).
  static const double _safetyMargin = 6;
  // Trigger an edge load when the current page is within this many pages of an
  // end of the loaded window.
  static const int _edgeThreshold = 2;

  final TextPaginator _paginator = const TextPaginator();

  List<ReaderRenderedPage> _pages = const [];
  // The inputs the current [_pages] were computed from, to avoid re-paginating
  // on every build.
  List<ReaderContentItem>? _paginatedItems;
  Size? _paginatedSize;
  TextStyle? _paginatedTextStyle;
  TextScaler? _paginatedScaler;

  PageController? _pageController;
  int _pageGeneration = 0;
  int _currentPage = 0;
  // The paragraph the current page starts on; re-located after a re-pagination
  // so the reader stays put across font / viewport / window changes.
  PlaybackCursor? _anchorCursor;
  bool _loadingPrevious = false;
  bool _loadingNext = false;

  // Drives programmatic page turns for curl mode (playback-follow). The flip
  // widget rebinds this controller to itself on every (re)mount.
  final PageFlipController _flipController = PageFlipController();

  @override
  void initState() {
    super.initState();
    _anchorCursor = widget.initialCursor;
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant PaginatedReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    // When the narration advances to a new paragraph, flip to its page once the
    // current build settles. Guarded to genuine cursor changes (value equality)
    // so manual page turns — which never move the playback cursor — are not
    // undone by an unrelated rebuild.
    final cursor = widget.playbackCursor;
    if (widget.playbackActive &&
        cursor != null &&
        cursor != oldWidget.playbackCursor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _followPlayback(cursor);
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size.width <= 0 || size.height <= 0) {
          return const SizedBox.shrink();
        }
        _ensurePagination(context, size);
        if (_pages.isEmpty) {
          return const Center(child: Text('图书没有可阅读内容'));
        }
        // Curl renders the 3D page-flip animation; slide uses a plain
        // horizontal PageView. Both page through the same paginated content.
        if (widget.mode == ReaderPageMode.curl) {
          return _buildCurl(context);
        }
        return PageView.builder(
          key: ValueKey<int>(_pageGeneration),
          controller: _pageController!,
          itemCount: _pages.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) => _buildPage(_pages[index]),
        );
      },
    );
  }

  // The 3D page-curl view. PageFlipWidget has no didUpdateWidget, keeps global
  // per-instance state, and consumes its children only at mount — so it is
  // remounted (via the [_pageGeneration] key) whenever pagination changes,
  // opening on the restored page. A fresh children list is passed each build
  // because the widget may mutate the list it is given.
  Widget _buildCurl(BuildContext context) {
    final target = _currentPage.clamp(0, _pages.length - 1);
    return PageFlipWidget(
      key: ValueKey<int>(_pageGeneration),
      controller: _flipController,
      initialIndex: target,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      onPageFlipped: _onPageChanged,
      children: <Widget>[for (final page in _pages) _buildPage(page)],
    );
  }

  // Recomputes pagination when the content, viewport, font, or text scale
  // changes, preserving the reading position and re-seating the PageController.
  void _ensurePagination(BuildContext context, Size size) {
    final scaler = MediaQuery.textScalerOf(context);
    final unchanged =
        identical(_paginatedItems, widget.items) &&
        _paginatedSize == size &&
        _paginatedTextStyle == widget.textStyle &&
        _paginatedScaler == scaler;
    if (unchanged) {
      return;
    }

    final anchor = _anchorCursor ?? widget.initialCursor;
    final pages = _paginator.paginate(
      items: widget.items,
      viewport: Size(size.width, size.height - _safetyMargin),
      padding: _padding,
      textStyle: widget.textStyle,
      headingStyle: widget.headingStyle,
      blockSpacing: _blockSpacing,
      textScaler: scaler,
      textDirection: Directionality.of(context),
    );

    _pages = pages;
    _paginatedItems = widget.items;
    _paginatedSize = size;
    _paginatedTextStyle = widget.textStyle;
    _paginatedScaler = scaler;

    final target = pages.isEmpty
        ? 0
        : pageIndexForCursor(pages, anchor).clamp(0, pages.length - 1);
    _currentPage = target;
    _anchorCursor = pages.isEmpty ? anchor : _cursorForPage(pages[target]);

    // Recreate the controller so the (possibly remounted) PageView opens on the
    // restored page with no visible jump. The old one is disposed after the
    // frame, once its PageView has detached.
    final old = _pageController;
    _pageController = PageController(initialPage: target);
    _pageGeneration++;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }

    // If we opened (or landed) near an edge, prefetch the adjacent chapter.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeLoadEdges();
      }
    });
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= _pages.length) {
      return;
    }
    _currentPage = index;
    final page = _pages[index];
    _anchorCursor = _cursorForPage(page);
    final paragraph = page.firstParagraph;
    if (paragraph != null) {
      widget.onReadingPositionChanged?.call(paragraph);
    }
    _maybeLoadEdges();
  }

  // Fires edge-load callbacks when near either end. The load completing makes
  // the parent rebuild with new [items]; [_ensurePagination] then re-paginates
  // and re-anchors so the reader stays on the same paragraph.
  void _maybeLoadEdges() {
    if (_pages.isEmpty) {
      return;
    }
    final page = _pages[_currentPage];
    final visibleChapterIds = _chapterIdsOnPage(page);
    final anchor = ReaderViewportAnchor(
      itemKey: _itemKeyForPage(page),
      alignment: 0,
    );

    final loadPrevious = widget.onLoadPrevious;
    if (loadPrevious != null &&
        !_loadingPrevious &&
        _currentPage <= _edgeThreshold) {
      _loadingPrevious = true;
      () async {
        try {
          await loadPrevious(
            visibleChapterIds: visibleChapterIds,
            anchor: anchor,
          );
        } catch (_) {
          // Existing pages stay readable; the next turn retries.
        } finally {
          _loadingPrevious = false;
        }
      }();
    }

    final loadNext = widget.onLoadNext;
    if (loadNext != null &&
        !_loadingNext &&
        _currentPage >= _pages.length - 1 - _edgeThreshold) {
      _loadingNext = true;
      () async {
        try {
          await loadNext(visibleChapterIds: visibleChapterIds, anchor: anchor);
        } catch (_) {
          // Existing pages stay readable; the next turn retries.
        } finally {
          _loadingNext = false;
        }
      }();
    }
  }

  // Flips to the page containing [cursor] when it is within the current
  // pagination. Best-effort: if that paragraph is not in the loaded window
  // (e.g. audio jumped far ahead), no flip happens — the reader keeps its page
  // and edge loading brings the content in as the user pages toward it.
  void _followPlayback(PlaybackCursor cursor) {
    if (_pages.isEmpty) {
      return;
    }
    final target = _pageContaining(cursor);
    if (target < 0 || target == _currentPage) {
      return;
    }
    switch (widget.mode) {
      case ReaderPageMode.slide:
        final controller = _pageController;
        if (controller != null && controller.hasClients) {
          // Fires onPageChanged when it settles, so progress + edge loads run
          // through the normal path.
          controller.animateToPage(
            target,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      case ReaderPageMode.curl:
        // goToPage does not fire onPageFlipped, so mirror the bookkeeping a
        // user turn would trigger (progress report + edge prefetch).
        _flipController.goToPage(target);
        _onPageChanged(target);
      case ReaderPageMode.scroll:
        break;
    }
  }

  // Turns one page in [direction] (+1 = next / right tap, -1 = previous / left
  // tap) using the active mode's native animation. Bookkeeping — progress
  // report and edge prefetch — flows through the same onPageChanged /
  // onPageFlipped path a swipe takes, so nothing extra is needed here.
  void _turnPage(int direction) {
    if (_pages.isEmpty) {
      return;
    }
    switch (widget.mode) {
      case ReaderPageMode.slide:
        final controller = _pageController;
        if (controller == null || !controller.hasClients) {
          return;
        }
        final target = (_currentPage + direction).clamp(0, _pages.length - 1);
        if (target == _currentPage) {
          return;
        }
        controller.animateToPage(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
        );
      case ReaderPageMode.curl:
        // nextPage/previousPage animate the flip and fire onPageFlipped
        // (→ _onPageChanged); each no-ops at its own boundary.
        if (direction > 0) {
          _flipController.nextPage();
        } else {
          _flipController.previousPage();
        }
      case ReaderPageMode.scroll:
        break;
    }
  }

  // Index of the first loaded page whose blocks include [cursor]'s paragraph,
  // or -1 when it is not in the current window.
  int _pageContaining(PlaybackCursor cursor) {
    for (var i = 0; i < _pages.length; i++) {
      for (final block in _pages[i].blocks) {
        if (block is ReaderTextPageBlock &&
            block.paragraph.chapterId == cursor.chapterId &&
            block.paragraph.index == cursor.paragraphIndex) {
          return i;
        }
      }
    }
    return -1;
  }

  PlaybackCursor _cursorForPage(ReaderRenderedPage page) {
    final paragraph = page.firstParagraph;
    if (paragraph != null) {
      return PlaybackCursor(
        chapterId: paragraph.chapterId,
        paragraphIndex: paragraph.index,
      );
    }
    return PlaybackCursor(chapterId: page.firstChapterId, paragraphIndex: 0);
  }

  Set<int> _chapterIdsOnPage(ReaderRenderedPage page) {
    final ids = <int>{page.firstChapterId};
    for (final block in page.blocks) {
      switch (block) {
        case ReaderHeadingPageBlock(:final chapter):
          ids.add(chapter.id);
        case ReaderTextPageBlock(:final paragraph):
          ids.add(paragraph.chapterId);
        case ReaderEndPageBlock(:final chapterId):
          ids.add(chapterId);
      }
    }
    return ids;
  }

  // The stable key of the page's first content item, matching
  // [ReaderContentItem.key] so the window controller's postpone-if-visible logic
  // recognises it.
  String _itemKeyForPage(ReaderRenderedPage page) {
    final block = page.blocks.first;
    return switch (block) {
      ReaderHeadingPageBlock(:final chapter) => 'chapter-${chapter.id}',
      ReaderTextPageBlock(:final paragraph) => 'paragraph-${paragraph.id}',
      ReaderEndPageBlock(:final chapterId) => 'book-end-$chapterId',
    };
  }

  Widget _buildPage(ReaderRenderedPage page) {
    return Padding(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < page.blocks.length; i++) ...[
            if (i > 0) const SizedBox(height: _blockSpacing),
            _buildBlock(page.blocks[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildBlock(ReaderPageBlock block) {
    return switch (block) {
      ReaderHeadingPageBlock(:final chapter) => Text(
        chapter.title,
        style: widget.headingStyle,
      ),
      ReaderTextPageBlock(:final text) => Text(text, style: widget.textStyle),
      ReaderEndPageBlock() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('全书读完', style: widget.textStyle)),
      ),
    };
  }
}

/// Drives page turns in a [PaginatedReaderView] from outside its subtree — the
/// reader binds this to its left/right tap zones. The view attaches itself
/// while mounted and detaches on dispose, so a turn is a no-op when no paged
/// view is on screen (e.g. in scroll mode).
class PaginatedReaderController {
  _PaginatedReaderViewState? _view;

  void _attach(_PaginatedReaderViewState view) => _view = view;

  void _detach(_PaginatedReaderViewState view) {
    if (identical(_view, view)) {
      _view = null;
    }
  }

  /// Turns to the next page (right tap). No-op at the last loaded page.
  void nextPage() => _view?._turnPage(1);

  /// Turns to the previous page (left tap). No-op at the first loaded page.
  void previousPage() => _view?._turnPage(-1);
}
