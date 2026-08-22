import 'package:flutter/widgets.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_content.dart';

/// A single block placed on a rendered page by [TextPaginator].
sealed class ReaderPageBlock {
  const ReaderPageBlock();
}

/// A chapter title heading.
final class ReaderHeadingPageBlock extends ReaderPageBlock {
  const ReaderHeadingPageBlock(this.chapter);

  final ReaderChapter chapter;
}

/// A paragraph or a slice of one. When a paragraph is taller than a page it is
/// split into several consecutive [ReaderTextPageBlock]s across pages; only the
/// first carries [isParagraphStart] `true`.
final class ReaderTextPageBlock extends ReaderPageBlock {
  const ReaderTextPageBlock({
    required this.paragraph,
    required this.text,
    required this.isParagraphStart,
  });

  /// The source paragraph (its `chapterId` / `index` drive progress + anchoring).
  final ReaderParagraph paragraph;

  /// The text actually shown in this block — equals [paragraph.text] when the
  /// whole paragraph fits on one page, otherwise a substring of it.
  final String text;

  /// Whether this block begins its paragraph (false for continuation slices).
  final bool isParagraphStart;
}

/// The "全书读完" end-of-book marker.
final class ReaderEndPageBlock extends ReaderPageBlock {
  const ReaderEndPageBlock(this.chapterId);

  final int chapterId;
}

/// One paginated page: the ordered blocks to render plus anchoring metadata.
final class ReaderRenderedPage {
  const ReaderRenderedPage({
    required this.blocks,
    required this.firstChapterId,
    required this.firstParagraph,
  });

  final List<ReaderPageBlock> blocks;

  /// Chapter the page starts in (used to anchor when only a heading is present).
  final int firstChapterId;

  /// First paragraph appearing on the page, or `null` for a heading/end-only
  /// page. Reported as the reading position when this page is shown.
  final ReaderParagraph? firstParagraph;
}

/// Lays out ordered reader content ([ReaderContentItem]s) into discrete pages
/// that fit a fixed viewport, for the slide / curl page-turn modes.
///
/// Pagination measures each block with a [TextPainter] using the *same* style,
/// width and inter-block spacing the page will render with, so a page whose
/// measured height fits the viewport renders without overflow. Paragraphs taller
/// than a page are split at line boundaries so they flow across pages.
class TextPaginator {
  const TextPaginator();

  List<ReaderRenderedPage> paginate({
    required List<ReaderContentItem> items,
    required Size viewport,
    required EdgeInsets padding,
    required TextStyle textStyle,
    required TextStyle headingStyle,
    required double blockSpacing,
    TextScaler textScaler = TextScaler.noScaling,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final maxWidth = viewport.width - padding.horizontal;
    final maxHeight = viewport.height - padding.vertical;
    if (items.isEmpty || maxWidth <= 0 || maxHeight <= 0) {
      return const <ReaderRenderedPage>[];
    }

    final pages = <ReaderRenderedPage>[];
    var current = <ReaderPageBlock>[];
    var currentHeight = 0.0;

    void flush() {
      if (current.isEmpty) {
        return;
      }
      final blocks = current;
      pages.add(
        ReaderRenderedPage(
          blocks: blocks,
          firstChapterId: _firstChapterId(blocks),
          firstParagraph: _firstParagraph(blocks),
        ),
      );
      current = <ReaderPageBlock>[];
      currentHeight = 0.0;
    }

    double measureHeight(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout(maxWidth: maxWidth);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    // Places a whole block that is not expected to exceed a page (heading /
    // end marker): starts a new page first if it would not fit on the current.
    void placeAtomic(ReaderPageBlock block, double height) {
      if (current.isNotEmpty &&
          currentHeight + blockSpacing + height > maxHeight) {
        flush();
      }
      final gap = current.isEmpty ? 0.0 : blockSpacing;
      current.add(block);
      currentHeight += gap + height;
    }

    // Places a paragraph, splitting it across pages when it does not fit.
    void placeParagraph(ReaderParagraph paragraph) {
      var text = paragraph.text;
      var isStart = true;
      if (text.isEmpty) {
        // Keep empty paragraphs addressable for anchoring; they add no height.
        final gap = current.isEmpty ? 0.0 : blockSpacing;
        current.add(
          ReaderTextPageBlock(
            paragraph: paragraph,
            text: '',
            isParagraphStart: true,
          ),
        );
        currentHeight += gap;
        return;
      }
      while (text.isNotEmpty) {
        final gap = current.isEmpty ? 0.0 : blockSpacing;
        final available = maxHeight - currentHeight - gap;
        if (available <= 0) {
          if (current.isEmpty) {
            // Degenerate viewport: force the remainder onto one page so we
            // never loop forever.
            current.add(
              ReaderTextPageBlock(
                paragraph: paragraph,
                text: text,
                isParagraphStart: isStart,
              ),
            );
            currentHeight = maxHeight;
            return;
          }
          flush();
          continue;
        }
        final fit = _fitText(
          text: text,
          style: textStyle,
          maxWidth: maxWidth,
          maxHeight: current.isEmpty ? maxHeight : available,
          textScaler: textScaler,
          textDirection: textDirection,
        );
        if (fit.end <= 0) {
          // Nothing fits in the remaining space; move to a fresh page. On a
          // fresh page [maxHeight] was used above, so `end > 0` there.
          flush();
          continue;
        }
        final slice = text.substring(0, fit.end);
        current.add(
          ReaderTextPageBlock(
            paragraph: paragraph,
            text: slice,
            isParagraphStart: isStart,
          ),
        );
        currentHeight += gap + fit.height;
        text = text.substring(fit.end);
        isStart = false;
        if (text.isNotEmpty) {
          flush();
        }
      }
    }

    for (final item in items) {
      switch (item) {
        case ReaderChapterHeadingItem(:final chapter):
          placeAtomic(
            ReaderHeadingPageBlock(chapter),
            measureHeight(chapter.title, headingStyle),
          );
        case ReaderParagraphItem(:final paragraph):
          placeParagraph(paragraph);
        case ReaderBookEndItem(:final chapterId):
          placeAtomic(
            ReaderEndPageBlock(chapterId),
            measureHeight('全书读完', textStyle) + 48,
          );
      }
    }
    flush();
    return pages;
  }

  static int _firstChapterId(List<ReaderPageBlock> blocks) {
    for (final block in blocks) {
      switch (block) {
        case ReaderHeadingPageBlock(:final chapter):
          return chapter.id;
        case ReaderTextPageBlock(:final paragraph):
          return paragraph.chapterId;
        case ReaderEndPageBlock(:final chapterId):
          return chapterId;
      }
    }
    return 0;
  }

  static ReaderParagraph? _firstParagraph(List<ReaderPageBlock> blocks) {
    for (final block in blocks) {
      if (block is ReaderTextPageBlock) {
        return block.paragraph;
      }
    }
    return null;
  }

  // Finds how much of [text] fits within [maxHeight] at [maxWidth], returning
  // the code-unit end offset of the fitting slice and its rendered height.
  static ({int end, double height}) _fitText({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required double maxHeight,
    required TextScaler textScaler,
    required TextDirection textDirection,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    final lines = painter.computeLineMetrics();
    if (lines.isEmpty) {
      painter.dispose();
      return (end: text.length, height: 0);
    }
    var cumulative = 0.0;
    var fitting = 0;
    for (final line in lines) {
      // Small epsilon so a line whose height lands exactly on the boundary is
      // kept rather than pushed to the next page by float noise.
      if (cumulative + line.height > maxHeight + 0.5) {
        break;
      }
      cumulative += line.height;
      fitting++;
    }
    if (fitting >= lines.length) {
      final height = painter.height;
      painter.dispose();
      return (end: text.length, height: height);
    }
    if (fitting == 0) {
      painter.dispose();
      return (end: 0, height: 0);
    }
    // The first character of the first non-fitting line is the slice end.
    final position = painter.getPositionForOffset(Offset(0, cumulative + 0.5));
    painter.dispose();
    var end = position.offset;
    if (end < 0) {
      end = 0;
    } else if (end > text.length) {
      end = text.length;
    }
    return (end: end, height: cumulative);
  }
}

/// Returns the index of the page that should be shown for [cursor], preferring
/// the page where that paragraph starts, then any page containing it, then the
/// paragraph's chapter heading page, and finally the first page.
int pageIndexForCursor(
  List<ReaderRenderedPage> pages,
  PlaybackCursor? cursor,
) {
  if (cursor == null || pages.isEmpty) {
    return 0;
  }
  for (var i = 0; i < pages.length; i++) {
    for (final block in pages[i].blocks) {
      if (block is ReaderTextPageBlock &&
          block.isParagraphStart &&
          block.paragraph.chapterId == cursor.chapterId &&
          block.paragraph.index == cursor.paragraphIndex) {
        return i;
      }
    }
  }
  for (var i = 0; i < pages.length; i++) {
    for (final block in pages[i].blocks) {
      if (block is ReaderTextPageBlock &&
          block.paragraph.chapterId == cursor.chapterId &&
          block.paragraph.index == cursor.paragraphIndex) {
        return i;
      }
    }
  }
  for (var i = 0; i < pages.length; i++) {
    if (pages[i].firstChapterId == cursor.chapterId) {
      return i;
    }
  }
  return 0;
}
