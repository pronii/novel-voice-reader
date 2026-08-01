import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

final class ReaderChapter {
  const ReaderChapter({
    required this.id,
    required this.index,
    required this.title,
  });

  final int id;
  final int index;
  final String title;
}

final class ReaderParagraph {
  const ReaderParagraph({
    required this.id,
    required this.index,
    required this.text,
  });

  final int id;
  final int index;
  final String text;
}

final class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.chapterTitle,
    required this.paragraphs,
    this.chapters = const [],
    this.currentChapterId,
    this.initialActiveParagraphId,
    this.playbackStarting = false,
    this.onBackToLibrary,
    this.onChapterSelected,
    this.onReadingPositionChanged,
    this.onPlayFrom,
    this.onOpenPlayer,
  });

  final int bookId;
  final String bookTitle;
  final String chapterTitle;
  final List<ReaderChapter> chapters;
  final int? currentChapterId;
  final List<ReaderParagraph> paragraphs;
  final int? initialActiveParagraphId;
  final bool playbackStarting;
  final VoidCallback? onBackToLibrary;
  final ValueChanged<int>? onChapterSelected;
  final ValueChanged<ReaderParagraph>? onReadingPositionChanged;
  final ValueChanged<ReaderParagraph>? onPlayFrom;
  final VoidCallback? onOpenPlayer;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

final class _ReaderPageState extends State<ReaderPage> {
  static const double _nextChapterOverscrollThreshold = 48;

  final ItemPositionsListener _itemPositions = ItemPositionsListener.create();
  Timer? _progressDebounce;
  ReaderParagraph? _pendingProgressParagraph;
  int? _activeParagraphId;
  int? _lastReportedParagraphId;
  bool _scrollMoved = false;
  int _scrollGeneration = 0;
  double _fontSize = 19;
  double _bottomOverscroll = 0;
  bool _nextChapterTransitionLocked = false;

  @override
  void initState() {
    super.initState();
    _activeParagraphId =
        widget.initialActiveParagraphId ?? widget.paragraphs.firstOrNull?.id;
    _lastReportedParagraphId = _activeParagraphId;
  }

  @override
  void didUpdateWidget(covariant ReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentChapterId != widget.currentChapterId) {
      _bottomOverscroll = 0;
      _nextChapterTransitionLocked = false;
      _invalidatePendingProgressReport();
      _scrollMoved = false;
      _activeParagraphId =
          widget.initialActiveParagraphId ?? widget.paragraphs.firstOrNull?.id;
      _lastReportedParagraphId = _activeParagraphId;
    }
  }

  @override
  void dispose() {
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
    return Scaffold(
      appBar: AppBar(
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
            onPressed: widget.chapters.isEmpty ? null : _showChapterList,
            icon: const Icon(Icons.format_list_numbered),
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
            onPressed: widget.playbackStarting ? null : _playActive,
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: ScrollablePositionedList.builder(
          key: ValueKey<int?>(widget.currentChapterId),
          initialScrollIndex: _initialScrollIndex,
          itemPositionsListener: _itemPositions,
          itemCount: widget.paragraphs.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chapterTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (widget.paragraphs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(child: Text('本章没有可朗读内容')),
                      ),
                  ],
                ),
              );
            }
            final paragraph = widget.paragraphs[index - 1];
            final active = paragraph.id == _activeParagraphId;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                index == widget.paragraphs.length ? 48 : 0,
              ),
              child: InkWell(
                key: ValueKey<String>(
                  active
                      ? 'active-paragraph-${paragraph.id}'
                      : 'paragraph-${paragraph.id}',
                ),
                borderRadius: BorderRadius.circular(6),
                onTap: () => _selectParagraph(paragraph),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: active
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
            );
          },
        ),
      ),
    );
  }

  int get _initialScrollIndex {
    final activeIndex = widget.paragraphs.indexWhere(
      (paragraph) => paragraph.id == widget.initialActiveParagraphId,
    );
    return activeIndex < 0 ? 0 : activeIndex + 1;
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is OverscrollNotification &&
        notification.overscroll > 0 &&
        notification.metrics.extentAfter == 0) {
      _bottomOverscroll += notification.overscroll;
      if (!_nextChapterTransitionLocked &&
          _bottomOverscroll >= _nextChapterOverscrollThreshold) {
        _continueToNextChapter();
      }
    } else if (notification.metrics.extentAfter > 0) {
      _bottomOverscroll = 0;
    }

    if (notification is ScrollStartNotification) {
      _scrollMoved = false;
      _invalidatePendingProgressReport();
    } else if (notification is ScrollUpdateNotification) {
      final scrollDelta = notification.scrollDelta;
      if (scrollDelta != null && scrollDelta != 0) {
        _scrollMoved = true;
        _invalidatePendingProgressReport();
      }
    } else if (notification is ScrollEndNotification) {
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

  void _continueToNextChapter() {
    final currentChapterIndex = widget.chapters.indexWhere(
      (chapter) => chapter.id == widget.currentChapterId,
    );
    if (currentChapterIndex < 0 ||
        currentChapterIndex + 1 >= widget.chapters.length) {
      return;
    }
    final onChapterSelected = widget.onChapterSelected;
    if (onChapterSelected == null) {
      return;
    }
    _bottomOverscroll = 0;
    _nextChapterTransitionLocked = true;
    _invalidatePendingProgressReport();
    onChapterSelected(widget.chapters[currentChapterIndex + 1].id);
  }

  void _scheduleVisiblePositionReport() {
    _progressDebounce?.cancel();
    _progressDebounce = null;
    final visible =
        _itemPositions.itemPositions.value
            .where(
              (position) =>
                  position.index > 0 &&
                  position.index <= widget.paragraphs.length &&
                  position.itemTrailingEdge > 0,
            )
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    if (visible.isEmpty) {
      return;
    }
    final paragraph = widget.paragraphs[visible.first.index - 1];
    if (paragraph.id == _lastReportedParagraphId) {
      return;
    }
    _pendingProgressParagraph = paragraph;
    _progressDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) {
        return;
      }
      setState(() => _activeParagraphId = paragraph.id);
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
    widget.onReadingPositionChanged?.call(paragraph);
  }

  void _invalidatePendingProgressReport() {
    _scrollGeneration += 1;
    _progressDebounce?.cancel();
    _progressDebounce = null;
    _pendingProgressParagraph = null;
  }

  void _playActive() {
    final active = widget.paragraphs
        .where((paragraph) => paragraph.id == _activeParagraphId)
        .firstOrNull;
    if (active != null) {
      _play(active);
    }
  }

  void _play(ReaderParagraph paragraph) {
    setState(() => _activeParagraphId = paragraph.id);
    _reportReadingPosition(paragraph);
    widget.onPlayFrom?.call(paragraph);
  }

  Future<void> _showChapterList() async {
    final selectedChapterId = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
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
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = widget.chapters[index];
                    final selected = chapter.id == widget.currentChapterId;
                    return ListTile(
                      title: Text(chapter.title),
                      leading: SizedBox(
                        width: 32,
                        child: Text('${chapter.index + 1}'),
                      ),
                      trailing: selected ? const Icon(Icons.check) : null,
                      selected: selected,
                      onTap: () {
                        if (!selected) {
                          _invalidatePendingProgressReport();
                        }
                        Navigator.of(context).pop(chapter.id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selectedChapterId != null) {
      widget.onChapterSelected?.call(selectedChapterId);
    }
  }

  Future<void> _showReadingSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('字号', style: Theme.of(context).textTheme.titleMedium),
                Slider(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
