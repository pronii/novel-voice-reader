import 'package:flutter/material.dart';

/// A circular icon button that follows the toolbar: it only appears while the
/// toolbar is visible, sits in the bottom-right corner, and toggles between
/// start (headphones) and stop (square) so the reader can enter or leave
/// listen mode with the same affordance.
class ReaderListenButton extends StatelessWidget {
  const ReaderListenButton({
    super.key,
    required this.visible,
    required this.playing,
    required this.onStart,
    required this.onStop,
  });

  final bool visible;
  final bool playing;
  final VoidCallback onStart;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    return FloatingActionButton(
      key: const Key('reader-listen-button'),
      mini: true,
      // Stop is optional: when the host cannot tear playback down the button
      // still has to stay tappable rather than rendering disabled.
      onPressed: playing ? (onStop ?? () {}) : onStart,
      tooltip: playing ? '退出听书' : '听小说',
      child: Icon(playing ? Icons.stop : Icons.headphones),
    );
  }
}
