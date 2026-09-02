import 'package:flutter/material.dart';
import 'package:novel_voice_reader/app/design/paper_tokens.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_content.dart';

/// One paragraph of reading text.
///
/// Visual state derives entirely from [playing] (the paragraph being narrated
/// right now) and [active] (the paragraph the reader tapped). Selection is a
/// paged-mode affordance: in scroll mode taps stay neutral — no highlight, no
/// "从这里朗读" button — because a stray tap while reading should not change
/// what the screen looks like. The playing paragraph is still highlighted in
/// both modes.
///
/// A single tap never starts playback: double-tapping a paragraph starts from
/// it, using the existing chapter and paragraph cursor without introducing a
/// character-offset model.
class ReaderParagraphView extends StatelessWidget {
  const ReaderParagraphView({
    super.key,
    required this.paragraph,
    required this.playing,
    required this.active,
    required this.scrollMode,
    required this.playbackStarting,
    required this.textStyle,
    required this.onPointerDown,
    required this.onTap,
    required this.onPlay,
  });

  final ReaderParagraph paragraph;
  final bool playing;
  final bool active;
  final bool scrollMode;
  final bool playbackStarting;
  final TextStyle textStyle;

  /// Raw pointer-down, recorded so a pair of taps can be recognised as a
  /// double tap. The gesture detector cannot supply this because the reader
  /// body also handles the pointer.
  final void Function(int paragraphId, Duration timeStamp) onPointerDown;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paper = context.paper;
    return KeyedSubtree(
      key: playing
          ? ValueKey<String>(
              'playing-paragraph-${paragraph.chapterId}-${paragraph.index}',
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Listener(
          onPointerDown: (event) => onPointerDown(paragraph.id, event.timeStamp),
          child: InkWell(
            key: ValueKey<String>(
              active
                  ? 'active-paragraph-${paragraph.id}'
                  : 'paragraph-${paragraph.id}',
            ),
            borderRadius: BorderRadius.circular(8),
            splashFactory: scrollMode ? NoSplash.splashFactory : null,
            overlayColor: scrollMode
                ? const WidgetStatePropertyAll<Color>(Colors.transparent)
                : null,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: playing
                    ? paper.highlightWash
                    : active
                    ? scheme.surfaceContainerHigh
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(paragraph.text, style: textStyle),
                  if (active)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: playbackStarting ? null : onPlay,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('从这里朗读'),
                      ),
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
