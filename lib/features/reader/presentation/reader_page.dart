import 'package:flutter/material.dart';

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
    this.onBackToLibrary,
    this.onChapterSelected,
    this.onPreviousChapter,
    this.onNextChapter,
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
  final VoidCallback? onBackToLibrary;
  final ValueChanged<int>? onChapterSelected;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onNextChapter;
  final ValueChanged<ReaderParagraph>? onPlayFrom;
  final VoidCallback? onOpenPlayer;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

final class _ReaderPageState extends State<ReaderPage> {
  int? _activeParagraphId;
  double _fontSize = 19;

  @override
  void initState() {
    super.initState();
    _activeParagraphId =
        widget.initialActiveParagraphId ?? widget.paragraphs.firstOrNull?.id;
  }

  @override
  void didUpdateWidget(covariant ReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentChapterId != widget.currentChapterId) {
      _activeParagraphId =
          widget.initialActiveParagraphId ?? widget.paragraphs.firstOrNull?.id;
    }
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
            onPressed: _playActive,
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                widget.chapterTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          if (widget.paragraphs.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('本章没有可朗读内容')),
            )
          else
            SliverList.builder(
              itemCount: widget.paragraphs.length,
              itemBuilder: (context, index) {
                final paragraph = widget.paragraphs[index];
                final active = paragraph.id == _activeParagraphId;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: InkWell(
                    key: ValueKey<String>(
                      active
                          ? 'active-paragraph-${paragraph.id}'
                          : 'paragraph-${paragraph.id}',
                    ),
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      setState(() => _activeParagraphId = paragraph.id);
                    },
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
                                onPressed: () => _play(paragraph),
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
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: '上一章',
                onPressed: widget.onPreviousChapter,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  widget.chapterTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: '下一章',
                onPressed: widget.onNextChapter,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
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
                      onTap: () => Navigator.of(context).pop(chapter.id),
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
