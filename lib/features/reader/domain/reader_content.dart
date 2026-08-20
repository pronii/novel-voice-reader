/// Page rendering style for the reader.
///
/// * [scroll] keeps the existing long-form vertical list — the reader scrolls
///   naturally and paragraphs flow continuously.
/// * [horizontal] paginates per chapter so a horizontal swipe advances to the
///   next chapter (or back) like turning a section.
/// * [curl] keeps the same per-chapter pagination but applies a 3D rotation on
///   the active page so the swipe feels like flipping a real page.
enum ReaderPageMode { scroll, horizontal, curl }

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
    required this.chapterId,
    required this.index,
    required this.text,
  });

  final int id;
  final int chapterId;
  final int index;
  final String text;
}

final class ReaderChapterSection {
  const ReaderChapterSection({
    required this.chapter,
    required this.paragraphs,
  });

  final ReaderChapter chapter;
  final List<ReaderParagraph> paragraphs;
}

sealed class ReaderContentItem {
  const ReaderContentItem();

  String get key;

  int get chapterId;
}

final class ReaderChapterHeadingItem extends ReaderContentItem {
  const ReaderChapterHeadingItem(this.chapter);

  final ReaderChapter chapter;

  @override
  String get key => 'chapter-${chapter.id}';

  @override
  int get chapterId => chapter.id;
}

final class ReaderParagraphItem extends ReaderContentItem {
  const ReaderParagraphItem(this.paragraph);

  final ReaderParagraph paragraph;

  @override
  String get key => 'paragraph-${paragraph.id}';

  @override
  int get chapterId => paragraph.chapterId;
}

final class ReaderBookEndItem extends ReaderContentItem {
  const ReaderBookEndItem(this.chapterId);

  @override
  final int chapterId;

  @override
  String get key => 'book-end-$chapterId';
}
