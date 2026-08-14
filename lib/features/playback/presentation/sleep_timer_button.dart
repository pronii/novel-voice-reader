import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_voice_reader/app/providers.dart';
import 'package:novel_voice_reader/features/playback/application/sleep_timer_controller.dart';

/// AppBar action that arms/cancels the playback sleep timer and shows the
/// remaining time. Reads [sleepTimerControllerProvider] directly so it keeps
/// updating while the countdown ticks.
class SleepTimerButton extends ConsumerWidget {
  const SleepTimerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(sleepTimerControllerProvider);
    return ListenableBuilder(
      listenable: timer,
      builder: (context, _) {
        final active = timer.isActive;
        final remaining = timer.remaining;
        final button = IconButton(
          tooltip: active ? '定时关闭（已开启）' : '定时关闭',
          onPressed: () => _openOptions(context, ref),
          icon: Icon(
            active ? Icons.bedtime : Icons.bedtime_outlined,
            color: active ? Theme.of(context).colorScheme.primary : null,
          ),
        );

        if (active && remaining != null) {
          return _CountdownAction(label: _formatRemaining(remaining), button: button);
        }
        if (active && timer.isEndOfChapter) {
          return _CountdownAction(label: '章', button: button);
        }
        return button;
      },
    );
  }

  Future<void> _openOptions(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(sleepTimerControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('定时关闭', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('到点后停止朗读并关闭通知'),
              ),
              for (final preset in SleepTimerPreset.values)
                ListTile(
                  leading: Icon(
                    preset.isEndOfChapter
                        ? Icons.menu_book_outlined
                        : Icons.timer_outlined,
                  ),
                  title: Text(preset.label),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _select(controller, messenger, preset);
                  },
                ),
              if (controller.isActive)
                ListTile(
                  leading: const Icon(Icons.cancel_outlined),
                  title: const Text('取消定时'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.cancel();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('已取消定时关闭')),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _select(
    SleepTimerController controller,
    ScaffoldMessengerState messenger,
    SleepTimerPreset preset,
  ) {
    if (preset.isEndOfChapter) {
      final armed = controller.startEndOfChapter();
      messenger.showSnackBar(
        SnackBar(
          content: Text(armed ? '将在本章播完后停止' : '请先开始播放'),
        ),
      );
      return;
    }
    controller.startDuration(preset.duration!);
    messenger.showSnackBar(
      SnackBar(content: Text('已设置 ${preset.label}后停止')),
    );
  }

  static String _formatRemaining(Duration remaining) {
    final totalSeconds = remaining.inSeconds.clamp(0, 359999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Shows the sleep-timer countdown as a pill placed *before* the icon so the
/// full `mm:ss` text stays on screen. A right-aligned [Badge] overflowed the
/// screen edge and clipped the label to its first digit.
class _CountdownAction extends StatelessWidget {
  const _CountdownAction({required this.label, required this.button});

  final String label;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        button,
      ],
    );
  }
}
