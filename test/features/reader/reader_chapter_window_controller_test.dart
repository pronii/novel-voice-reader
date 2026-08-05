import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/reader/application/reader_chapter_window_controller.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_content.dart';

void main() {
  test('initializes one previous and two following chapters', () async {
    final chapters = _chapters(8);
    final loader = _RecordingSectionLoader();
    final controller = ReaderChapterWindowController(
      chapters: chapters,
      loadSection: loader.call,
    );

    await controller.initialize(chapterId: 103);

    expect(
      controller.sections.map((section) => section.chapter.id),
      [102, 103, 104, 105],
    );
    expect(loader.chapterIds, [102, 103, 104, 105]);
    expect(
      controller.sections
          .expand((section) => section.paragraphs)
          .map((paragraph) => paragraph.chapterId),
      [102, 103, 104, 105],
    );
  });

  test('flattens sections into globally unique stable item keys', () async {
    final chapters = _chapters(2);
    final controller = ReaderChapterWindowController(
      chapters: chapters,
      loadSection: _RecordingSectionLoader().call,
    );

    await controller.initialize(chapterId: 100);

    expect(
      controller.items.map((item) => item.key),
      [
        'chapter-100',
        'paragraph-1000',
        'chapter-101',
        'paragraph-1010',
        'book-end-101',
      ],
    );
    expect(
      controller.items.map((item) => item.key).toSet(),
      hasLength(controller.items.length),
    );
  });

  test('loads next and evicts only the farthest offscreen first section', () async {
    final loader = _RecordingSectionLoader();
    final controller = ReaderChapterWindowController(
      chapters: _chapters(8),
      loadSection: loader.call,
    );
    const anchor = ReaderViewportAnchor(
      itemKey: 'paragraph-1040',
      alignment: 0.2,
    );
    await controller.initialize(chapterId: 103);
    await controller.loadNext(
      visibleChapterIds: {103, 104, 105},
      anchor: anchor,
    );

    final mutation = await controller.loadNext(
      visibleChapterIds: {104, 105, 106},
      anchor: anchor,
    );

    expect(
      controller.sections.map((section) => section.chapter.id),
      [103, 104, 105, 106, 107],
    );
    expect(mutation.changed, isTrue);
    expect(mutation.postponed, isFalse);
    expect(mutation.anchor, same(anchor));
  });

  test('loads previous and evicts only the farthest offscreen last section', () async {
    final controller = ReaderChapterWindowController(
      chapters: _chapters(8),
      loadSection: _RecordingSectionLoader().call,
    );
    const anchor = ReaderViewportAnchor(
      itemKey: 'paragraph-1030',
      alignment: 0.1,
    );
    await controller.initialize(chapterId: 104);
    await controller.loadPrevious(
      visibleChapterIds: {103, 104, 105},
      anchor: anchor,
    );

    final mutation = await controller.loadPrevious(
      visibleChapterIds: {102, 103, 104},
      anchor: anchor,
    );

    expect(
      controller.sections.map((section) => section.chapter.id),
      [101, 102, 103, 104, 105],
    );
    expect(mutation.anchor, same(anchor));
  });

  test('postpones a sixth load when every opposite section is visible', () async {
    final loader = _RecordingSectionLoader();
    final controller = ReaderChapterWindowController(
      chapters: _chapters(8),
      loadSection: loader.call,
    );
    const anchor = ReaderViewportAnchor(itemKey: 'chapter-104', alignment: 0);
    await controller.initialize(chapterId: 103);
    await controller.loadNext(
      visibleChapterIds: {103, 104, 105},
      anchor: anchor,
    );

    final mutation = await controller.loadNext(
      visibleChapterIds: {102, 103, 104, 105, 106},
      anchor: anchor,
    );

    expect(mutation.changed, isFalse);
    expect(mutation.postponed, isTrue);
    expect(loader.chapterIds.where((id) => id == 107), isEmpty);
    expect(controller.sections, hasLength(5));
  });

  test('coalesces duplicate next loads', () async {
    final loader = _RecordingSectionLoader();
    final controller = ReaderChapterWindowController(
      chapters: _chapters(8),
      loadSection: loader.call,
    );
    const anchor = ReaderViewportAnchor(itemKey: 'chapter-104', alignment: 0);
    await controller.initialize(chapterId: 103);
    loader.blockChapter(106);

    final first = controller.loadNext(
      visibleChapterIds: {103, 104, 105},
      anchor: anchor,
    );
    final duplicate = controller.loadNext(
      visibleChapterIds: {103, 104, 105},
      anchor: anchor,
    );
    await Future<void>.delayed(Duration.zero);

    expect(loader.chapterIds.where((id) => id == 106), hasLength(1));
    loader.releaseChapter(106);
    await Future.wait([first, duplicate]);
    expect(controller.sections.last.chapter.id, 106);
  });

  test('keeps sections after failure and retries the edge load', () async {
    final loader = _RecordingSectionLoader()..failOnce(106);
    final controller = ReaderChapterWindowController(
      chapters: _chapters(8),
      loadSection: loader.call,
    );
    const anchor = ReaderViewportAnchor(itemKey: 'chapter-104', alignment: 0);
    await controller.initialize(chapterId: 103);
    final before = controller.sections;

    await expectLater(
      controller.loadNext(
        visibleChapterIds: {103, 104, 105},
        anchor: anchor,
      ),
      throwsStateError,
    );

    expect(controller.sections, before);
    expect(controller.adjacentLoadError, isA<StateError>());
    final mutation = await controller.loadNext(
      visibleChapterIds: {103, 104, 105},
      anchor: anchor,
    );
    expect(mutation.changed, isTrue);
    expect(controller.sections.last.chapter.id, 106);
    expect(controller.adjacentLoadError, isNull);
  });

  test('centers a new window and increments navigation generation', () async {
    final controller = ReaderChapterWindowController(
      chapters: _chapters(8),
      loadSection: _RecordingSectionLoader().call,
    );
    await controller.initialize(chapterId: 101);
    final generation = controller.navigationGeneration;

    await controller.centerOn(chapterId: 106);

    expect(controller.navigationGeneration, generation + 1);
    expect(
      controller.sections.map((section) => section.chapter.id),
      [105, 106, 107],
    );
  });
}

List<ReaderChapter> _chapters(int count) => List.generate(
  count,
  (index) => ReaderChapter(
    id: 100 + index,
    index: index,
    title: '第${index + 1}章',
  ),
);

final class _RecordingSectionLoader {
  final List<int> chapterIds = [];
  final Map<int, Completer<void>> _blocked = {};
  final Set<int> _failures = {};

  void blockChapter(int chapterId) {
    _blocked[chapterId] = Completer<void>();
  }

  void releaseChapter(int chapterId) {
    _blocked.remove(chapterId)?.complete();
  }

  void failOnce(int chapterId) {
    _failures.add(chapterId);
  }

  Future<ReaderChapterSection> call(ReaderChapter chapter) async {
    chapterIds.add(chapter.id);
    await _blocked[chapter.id]?.future;
    if (_failures.remove(chapter.id)) {
      throw StateError('load ${chapter.id} failed');
    }
    return ReaderChapterSection(
      chapter: chapter,
      paragraphs: [
        ReaderParagraph(
          id: chapter.id * 10,
          chapterId: chapter.id,
          index: 0,
          text: '${chapter.title}正文',
        ),
      ],
    );
  }
}
