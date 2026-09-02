import 'package:flutter/material.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_page_mode.dart';

/// The reader's chrome: a bar that slides out of the top edge on demand.
///
/// It is revealed and hidden by tapping the middle of the body (and hidden
/// again by scrolling), so reading is never interrupted by persistent chrome.
class ReaderToolbar extends StatelessWidget {
  const ReaderToolbar({
    super.key,
    required this.visible,
    required this.title,
    required this.pageMode,
    required this.autoScrollRunning,
    required this.hasChapters,
    required this.onBack,
    required this.onShowChapterList,
    required this.onToggleAutoScroll,
    required this.onShowReadingSettings,
    required this.onOpenPlayer,
  });

  final bool visible;
  final String title;
  final ReaderPageMode pageMode;
  final bool autoScrollRunning;
  final bool hasChapters;
  final VoidCallback? onBack;
  final VoidCallback? onShowChapterList;
  final VoidCallback? onToggleAutoScroll;
  final VoidCallback? onShowReadingSettings;
  final VoidCallback? onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSlide(
        key: const Key('reader-toolbar'),
        offset: visible ? Offset.zero : const Offset(0, -1),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: IgnorePointer(
          ignoring: !visible,
          child: ExcludeSemantics(
            excluding: !visible,
            child: SizedBox(
              height: kToolbarHeight,
              child: AppBar(
                primary: false,
                leading: IconButton(
                  tooltip: '返回书架',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  IconButton(
                    tooltip: '章节目录',
                    onPressed: hasChapters ? onShowChapterList : null,
                    icon: const Icon(Icons.format_list_numbered),
                  ),
                  // Auto-scroll is a scroll-mode affordance; the paged modes
                  // have no continuous crawl to drive.
                  if (pageMode == ReaderPageMode.scroll)
                    IconButton(
                      tooltip: autoScrollRunning ? '暂停自动滚动' : '自动滚动',
                      onPressed: onToggleAutoScroll,
                      icon: Icon(
                        autoScrollRunning
                            ? Icons.pause
                            : Icons.keyboard_double_arrow_down,
                      ),
                    ),
                  IconButton(
                    tooltip: '阅读设置',
                    onPressed: onShowReadingSettings,
                    icon: const Icon(Icons.text_fields),
                  ),
                  IconButton(
                    tooltip: '播放器',
                    onPressed: onOpenPlayer,
                    icon: const Icon(Icons.graphic_eq),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
