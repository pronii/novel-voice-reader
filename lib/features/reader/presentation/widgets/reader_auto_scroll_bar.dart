import 'package:flutter/material.dart';
import 'package:novel_voice_reader/features/reader/application/auto_scroll_controller.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_page_mode.dart';

/// A compact control bar for the crawl.
///
/// It is not persistent: it rides with the toolbar, appearing only while the
/// toolbar is revealed (tap to show, tap again to hide) so it never sits on top
/// of the text while reading. It is also a scroll-mode affordance only — the
/// paged modes have no continuous crawl to drive.
class ReaderAutoScrollBar extends StatelessWidget {
  const ReaderAutoScrollBar({
    super.key,
    required this.visible,
    required this.pageMode,
    required this.autoScroll,
  });

  final bool visible;
  final ReaderPageMode pageMode;
  final AutoScrollController autoScroll;

  @override
  Widget build(BuildContext context) {
    if (pageMode != ReaderPageMode.scroll) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ListenableBuilder(
        listenable: autoScroll,
        builder: (context, _) {
          if (!visible || autoScroll.status == AutoScrollStatus.idle) {
            return const SizedBox.shrink();
          }
          final theme = Theme.of(context);
          final running = autoScroll.isRunning;
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
                            '${autoScroll.speedLevel}',
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
                            value: autoScroll.speedLevel
                                .clamp(
                                  AutoScrollController.minLevel,
                                  AutoScrollController.maxLevel,
                                )
                                .toDouble(),
                            onChanged: (value) =>
                                autoScroll.speedLevel = value.round(),
                          ),
                        ),
                        const SizedBox(
                          height: 24,
                          child: VerticalDivider(width: 12),
                        ),
                        IconButton(
                          tooltip: running ? '暂停' : '继续',
                          onPressed: autoScroll.toggle,
                          icon: Icon(running ? Icons.pause : Icons.play_arrow),
                        ),
                        IconButton(
                          tooltip: '退出自动滚动',
                          onPressed: autoScroll.stop,
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
}
