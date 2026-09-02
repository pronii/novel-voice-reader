import 'package:flutter/material.dart';
import 'package:novel_voice_reader/features/reader/application/auto_scroll_controller.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_page_mode.dart';

/// Shows the reading settings sheet: text size, page-turn mode and the
/// auto-scroll controls.
///
/// The slider and the mode picker keep their values in local state so dragging
/// only moves the thumb (cheap) instead of triggering a full page rebuild —
/// and, in the paged modes, a full synchronous re-pagination — on every
/// division tick. Values are applied once, on release.
Future<void> showReaderSettingsSheet({
  required BuildContext context,
  required double initialFontSize,
  required ReaderPageMode initialPageMode,
  required AutoScrollController autoScroll,
  required bool hasContent,
  required ValueChanged<double> onFontSizeChanged,
  required ValueChanged<ReaderPageMode> onPageModeSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      var pendingFontSize = initialFontSize;
      var pendingMode = initialPageMode;
      return StatefulBuilder(
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
                  value: pendingFontSize,
                  min: 15,
                  max: 30,
                  divisions: 15,
                  label: pendingFontSize.round().toString(),
                  onChanged: (value) {
                    setSheetState(() => pendingFontSize = value);
                  },
                  onChangeEnd: (value) {
                    if (value != initialFontSize) {
                      onFontSizeChanged(value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '翻页模式',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SegmentedButton<ReaderPageMode>(
                  showSelectedIcon: false,
                  segments: [
                    for (final mode in ReaderPageMode.values)
                      ButtonSegment<ReaderPageMode>(
                        value: mode,
                        label: Text(
                          switch (mode) {
                            ReaderPageMode.scroll => '滚动',
                            ReaderPageMode.slide => '翻页',
                            ReaderPageMode.curl => '3D',
                          },
                          key: ValueKey('page-mode-option-${mode.storageKey}'),
                        ),
                      ),
                  ],
                  selected: {pendingMode},
                  onSelectionChanged: (selection) {
                    final mode = selection.first;
                    setSheetState(() => pendingMode = mode);
                    onPageModeSelected(mode);
                  },
                ),
                const SizedBox(height: 8),
                _AutoScrollSettings(
                  autoScroll: autoScroll,
                  hasContent: hasContent,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// The crawl controls: a speed dial and start/pause/stop actions.
///
/// Bound directly to the [AutoScrollController] so the buttons reflect live
/// status while the sheet is open.
class _AutoScrollSettings extends StatelessWidget {
  const _AutoScrollSettings({
    required this.autoScroll,
    required this.hasContent,
  });

  final AutoScrollController autoScroll;
  final bool hasContent;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: autoScroll,
      builder: (context, _) {
        final running = autoScroll.isRunning;
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
                  '速度：${autoScroll.speedLevel}',
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
                    value: autoScroll.speedLevel
                        .clamp(
                          AutoScrollController.minLevel,
                          AutoScrollController.maxLevel,
                        )
                        .toDouble(),
                    label: '${autoScroll.speedLevel}',
                    onChanged: (value) => autoScroll.speedLevel = value.round(),
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
                    onPressed: hasContent ? autoScroll.toggle : null,
                    icon: Icon(running ? Icons.pause : Icons.play_arrow),
                    label: Text(running ? '暂停' : '开始'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: autoScroll.status == AutoScrollStatus.idle
                      ? null
                      : autoScroll.stop,
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
