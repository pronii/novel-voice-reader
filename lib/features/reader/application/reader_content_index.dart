import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_content.dart';

/// The flat list of content items both reading modes render, plus every
/// "where is this?" lookup the reader has to answer about it.
///
/// The list is rebuilt only when the source sections or chapters change
/// identity: recomputing it per access allocated the whole list on hot scroll,
/// auto-scroll and 1 Hz heartbeat paths.
final class ReaderContentIndex {
  ReaderContentIndex({
    required List<ReaderChapterSection> sections,
    required List<ReaderChapter> chapters,
  }) : _sections = sections,
       _chapters = chapters,
       _items = _buildItems(sections, chapters);

  List<ReaderChapterSection> _sections;
  List<ReaderChapter> _chapters;
  List<ReaderContentItem> _items;

  /// The current items, in reading order.
  List<ReaderContentItem> get items => _items;

  bool get isEmpty => _items.isEmpty;

  int get length => _items.length;

  ReaderContentItem operator [](int index) => _items[index];

  /// Rebuilds the list, but only when [sections] or [chapters] changed
  /// identity. Returns whether a rebuild happened.
  bool update({
    required List<ReaderChapterSection> sections,
    required List<ReaderChapter> chapters,
  }) {
    if (identical(_sections, sections) && identical(_chapters, chapters)) {
      return false;
    }
    _sections = sections;
    _chapters = chapters;
    _items = _buildItems(sections, chapters);
    return true;
  }

  static List<ReaderContentItem> _buildItems(
    List<ReaderChapterSection> sections,
    List<ReaderChapter> chapters,
  ) {
    final items = <ReaderContentItem>[
      for (final section in sections) ...[
        ReaderChapterHeadingItem(section.chapter),
        for (final paragraph in section.paragraphs)
          ReaderParagraphItem(paragraph),
      ],
    ];
    if (sections.isNotEmpty &&
        chapters.isNotEmpty &&
        sections.last.chapter.id == chapters.last.id) {
      items.add(ReaderBookEndItem(sections.last.chapter.id));
    }
    return items;
  }

  /// Index of the paragraph [cursor] points at, or -1 when it is not loaded.
  int indexOfCursor(PlaybackCursor cursor) => _items.indexWhere(
    (item) =>
        item is ReaderParagraphItem &&
        item.paragraph.chapterId == cursor.chapterId &&
        item.paragraph.index == cursor.paragraphIndex,
  );

  /// Index of the paragraph with [paragraphId], or -1 when it is not loaded.
  int indexOfParagraphId(int paragraphId) => _items.indexWhere(
    (item) => item is ReaderParagraphItem && item.paragraph.id == paragraphId,
  );

  /// Index of the heading for [chapterId], or -1 when it is not loaded.
  int indexOfChapterHeading(int chapterId) => _items.indexWhere(
    (item) => item is ReaderChapterHeadingItem && item.chapterId == chapterId,
  );

  /// Index of the item carrying [key], or -1. Used to restore a viewport
  /// anchor after the chapter window shifts.
  int indexOfKey(String key) => _items.indexWhere((item) => item.key == key);

  /// The paragraph with [paragraphId], or null when it is not loaded.
  ReaderParagraph? paragraphForId(int paragraphId) {
    for (final item in _items) {
      if (item is ReaderParagraphItem && item.paragraph.id == paragraphId) {
        return item.paragraph;
      }
    }
    return null;
  }

  /// The [PlaybackCursor] addressing the paragraph with [paragraphId].
  PlaybackCursor? cursorForParagraphId(int paragraphId) {
    final paragraph = paragraphForId(paragraphId);
    if (paragraph == null) {
      return null;
    }
    return PlaybackCursor(
      chapterId: paragraph.chapterId,
      paragraphIndex: paragraph.index,
    );
  }

  /// Every loaded paragraph in reading order.
  Iterable<ReaderParagraph> get paragraphs sync* {
    for (final item in _items) {
      if (item is ReaderParagraphItem) {
        yield item.paragraph;
      }
    }
  }
}
