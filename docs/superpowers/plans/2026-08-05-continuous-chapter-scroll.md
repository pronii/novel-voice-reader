# Continuous Chapter Scroll Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render adjacent novel chapters as one uninterrupted vertical text stream and keep the currently spoken paragraph highlighted and followed.

**Architecture:** Introduce a pure five-section chapter-window controller fed by an async section loader, then let the reader route own that controller for the lifetime of the open book. `ReaderPage` renders the controller's flattened chapter headings and paragraphs in one `ScrollablePositionedList`, derives the visible chapter from item positions, and preserves a stable item anchor around prepend/eviction mutations. Playback publishes cursor changes through the shared runtime so the reader can maintain a separate playing highlight and optional follow behavior.

**Tech Stack:** Flutter 3.44.8, Dart 3.12.2, Riverpod 2.6.1, Drift, `scrollable_positioned_list` 0.3.8, `flutter_test`.

## Global Constraints

- Ordinary adjacent scrolling must not replace `ReaderPage`, change its list key, reset its offset, or show a full-page loading state.
- Load all chapter metadata, but keep at most five chapter bodies in memory.
- The initial body window is up to one previous chapter, the requested chapter, and up to two following chapters.
- Never evict a visible chapter; postpone a sixth load when there is no fully offscreen opposite section to evict.
- Prepending and opposite-edge eviction must restore the first visible item and its alignment.
- Persist progress from the first visible paragraph using that paragraph's own chapter ID and paragraph index.
- Reading position and playback position are independent states.
- Pausing retains the playing highlight; stopping clears it.
- A deliberate manual scroll suspends playback viewport following; starting playback from a paragraph resumes it.
- Directory title and one-based number search behavior must remain unchanged.
- No new runtime dependency, WebView, EPUB engine, horizontal pagination, or eager whole-book body load.

---

### Task 1: Chapter Content Models And Five-Section Window

**Files:**
- Create: `lib/features/reader/domain/reader_content.dart`
- Create: `lib/features/reader/application/reader_chapter_window_controller.dart`
- Create: `test/features/reader/reader_chapter_window_controller_test.dart`

**Interfaces:**
- Produces: `ReaderChapter`, `ReaderParagraph`, `ReaderChapterSection`, and `ReaderContentItem` domain models.
- Produces: `typedef ReaderChapterSectionLoader = Future<ReaderChapterSection> Function(ReaderChapter chapter)`.
- Produces: `ReaderChapterWindowController`, with `initialize`, `loadPrevious`, `loadNext`, and `centerOn` operations.
- Produces: `ReaderWindowMutation`, which identifies the stable anchor requested by the caller and whether a centered directory jump occurred.

Use these exact controller-facing signatures:

```dart
final class ReaderViewportAnchor {
  const ReaderViewportAnchor({required this.itemKey, required this.alignment});
  final String itemKey;
  final double alignment;
}

final class ReaderWindowMutation {
  const ReaderWindowMutation({
    required this.changed,
    required this.postponed,
    this.anchor,
  });
  final bool changed;
  final bool postponed;
  final ReaderViewportAnchor? anchor;
}

final class ReaderChapterWindowController extends ChangeNotifier {
  ReaderChapterWindowController({
    required List<ReaderChapter> chapters,
    required ReaderChapterSectionLoader loadSection,
    int maxSections = 5,
  });

  List<ReaderChapterSection> get sections;
  List<ReaderContentItem> get items;
  int get navigationGeneration;
  Object? get adjacentLoadError;

  Future<void> initialize({required int chapterId});
  Future<ReaderWindowMutation> loadPrevious({
    required Set<int> visibleChapterIds,
    required ReaderViewportAnchor anchor,
  });
  Future<ReaderWindowMutation> loadNext({
    required Set<int> visibleChapterIds,
    required ReaderViewportAnchor anchor,
  });
  Future<void> centerOn({required int chapterId});
}
```

- [ ] **Step 1: Write failing model and initial-window tests**

Create domain models with the intended public API in the test:

```dart
final chapters = List.generate(
  8,
  (index) => ReaderChapter(id: 100 + index, index: index, title: '第${index + 1}章'),
);
final controller = ReaderChapterWindowController(
  chapters: chapters,
  loadSection: fakeLoader,
);

await controller.initialize(chapterId: 103);

expect(controller.sections.map((section) => section.chapter.id), [102, 103, 104, 105]);
expect(controller.sections.expand((section) => section.paragraphs).every(
  (paragraph) => paragraph.chapterId >= 102 && paragraph.chapterId <= 105,
), isTrue);
```

Add a separate test proving `ReaderContentItem` keys are stable and globally unique for chapter headings, paragraphs, and the terminal row.

- [ ] **Step 2: Run the tests and verify RED**

Run:

```powershell
flutter test --no-pub test/features/reader/reader_chapter_window_controller_test.dart
```

Expected: compilation fails because the new models and controller do not exist.

- [ ] **Step 3: Implement minimal immutable models and initialization**

Create exact model responsibilities:

```dart
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
  const ReaderChapterSection({required this.chapter, required this.paragraphs});

  final ReaderChapter chapter;
  final List<ReaderParagraph> paragraphs;
}
```

Model flattened item variants as sealed classes with stable keys:

```dart
sealed class ReaderContentItem {
  const ReaderContentItem();
  String get key;
  int get chapterId;
}

final class ReaderChapterHeadingItem extends ReaderContentItem {
  const ReaderChapterHeadingItem(this.chapter);
  final ReaderChapter chapter;
  @override String get key => 'chapter-${chapter.id}';
  @override int get chapterId => chapter.id;
}

final class ReaderParagraphItem extends ReaderContentItem {
  const ReaderParagraphItem(this.paragraph);
  final ReaderParagraph paragraph;
  @override String get key => 'paragraph-${paragraph.id}';
  @override int get chapterId => paragraph.chapterId;
}

final class ReaderBookEndItem extends ReaderContentItem {
  const ReaderBookEndItem(this.chapterId);
  @override final int chapterId;
  @override String get key => 'book-end-$chapterId';
}
```

Implement `initialize` by loading indices `[requested - 1, requested, requested + 1, requested + 2]`, clamped to the chapter list, in reading order.

- [ ] **Step 4: Write failing edge-load, coalescing, retry, and eviction tests**

Cover all state transitions explicitly:

```dart
final firstLoad = controller.loadNext(
  visibleChapterIds: {103, 104},
  anchor: const ReaderViewportAnchor(itemKey: 'paragraph-501', alignment: 0.2),
);
final duplicateLoad = controller.loadNext(
  visibleChapterIds: {103, 104},
  anchor: const ReaderViewportAnchor(itemKey: 'paragraph-501', alignment: 0.2),
);
await Future.wait([firstLoad, duplicateLoad]);

expect(loadCalls.where((id) => id == 106), hasLength(1));
expect(controller.sections, hasLength(5));
```

Add tests proving:

- loading a sixth next chapter evicts only the first fully offscreen section;
- loading a sixth previous chapter evicts only the last fully offscreen section;
- when every opposite section is visible, the load is postponed and remains retryable;
- loader failure keeps the prior sections and clears the direction's in-flight flag;
- the next call retries successfully;
- `centerOn(chapterId)` rebuilds the initial centered window and increments `navigationGeneration`.

- [ ] **Step 5: Run and verify RED**

Run the same controller test file. Expected: the new mutation and edge methods are missing or fail the state assertions.

- [ ] **Step 6: Implement serialized edge mutations**

Use one queued mutation future and per-direction in-flight futures. `loadNext` and `loadPrevious` return the existing in-flight future when called repeatedly. Before inserting a sixth section, choose a fully offscreen section on the opposite side; return `ReaderWindowMutation.postponed()` when no legal eviction exists. On failure, leave `_sections` unchanged and clear the in-flight field in `whenComplete`.

Every successful prepend or eviction returns the caller-provided `ReaderViewportAnchor` unchanged so the widget can restore it after rebuilding.

- [ ] **Step 7: Verify and commit**

Run:

```powershell
flutter test --no-pub test/features/reader/reader_chapter_window_controller_test.dart
flutter analyze --no-pub
git diff --check
```

Commit:

```powershell
git add lib/features/reader/domain/reader_content.dart lib/features/reader/application/reader_chapter_window_controller.dart test/features/reader/reader_chapter_window_controller_test.dart
git commit -m "feat: manage a bounded reader chapter window"
```

---

### Task 2: Continuous Reader Data Flow And Layout

**Files:**
- Modify: `lib/app/providers.dart`
- Modify: `lib/app/router.dart`
- Modify: `lib/features/reader/presentation/reader_page.dart`
- Modify: `test/app/reader_page_data_provider_test.dart`
- Modify: `test/app/navigation_test.dart`
- Modify: `test/features/reader/reader_page_test.dart`

**Interfaces:**
- Consumes: Task 1 models and `ReaderChapterWindowController`.
- Produces: `ReaderPageData.chapters`, `ReaderPageData.savedCursor`, and a route-owned initialized chapter window.
- Produces: `ReaderPage.sections`, `ReaderPage.navigationGeneration`, `ReaderPage.onLoadPrevious`, and `ReaderPage.onLoadNext`.
- Produces: progress callbacks containing a chapter-owned `ReaderParagraph`.

- [ ] **Step 1: Write failing provider tests for metadata-only bootstrap**

Change provider expectations so bootstrap data includes all chapter metadata and saved cursor, but does not expose a single page-level paragraph list:

```dart
final data = await container.read(
  readerPageDataProvider(ReaderPageRequest(bookId)).future,
);

expect(data.chapters.map((chapter) => chapter.id), [firstId, secondId, thirdId]);
expect(data.savedCursor, PlaybackCursor(chapterId: secondId, paragraphIndex: 1));
```

Add a loader test for `loadReaderChapterSection(database, chapter)` that proves every paragraph carries `chapter.id`.

- [ ] **Step 2: Run provider tests and verify RED**

Run:

```powershell
flutter test --no-pub test/app/reader_page_data_provider_test.dart
```

Expected: assertions fail against the single-chapter `ReaderPageData` API.

- [ ] **Step 3: Refactor the provider and route ownership**

Move `ReaderChapter` and `ReaderParagraph` imports to Task 1's domain file. Make `ReaderPageData` a bootstrap object:

```dart
final class ReaderPageData {
  const ReaderPageData({
    required this.book,
    required this.chapters,
    required this.savedCursor,
  });

  final BookRecord book;
  final List<ReaderChapter> chapters;
  final PlaybackCursor? savedCursor;
}
```

Add:

```dart
Future<ReaderChapterSection> loadReaderChapterSection(
  AppDatabase database,
  ReaderChapter chapter,
) async {
  final records = await database.paragraphsForChapter(chapter.id);
  return ReaderChapterSection(
    chapter: chapter,
    paragraphs: [
      for (final record in records)
        ReaderParagraph(
          id: record.id,
          chapterId: chapter.id,
          index: record.paragraphIndex,
          text: record.content,
        ),
    ],
  );
}
```

In `_ReaderRoutePageState`, create exactly one controller per `bookId`, listen to it, initialize it with the requested/saved chapter, and dispose it with the route. Directory selection calls `centerOn` instead of changing `_selectedChapterId` and rebuilding the provider.

- [ ] **Step 4: Write failing continuous-layout widget tests**

Replace the overscroll transition tests with section-based tests:

```dart
await tester.pumpWidget(readerWithSections([
  section(chapterId: 10, title: '第一章', paragraphs: ['第一章末尾']),
  section(chapterId: 11, title: '第二章', paragraphs: ['第二章开头']),
]));

expect(find.text('第一章末尾'), findsOneWidget);
await tester.scrollUntilVisible(find.text('第二章开头'), 240);
expect(find.text('第二章'), findsOneWidget);
expect(find.text('第二章开头'), findsOneWidget);
expect(readerStateCreations, 1);
```

Add tests for:

- edge proximity invokes `onLoadNext` before overscroll;
- the final section renders `全书读完` and performs no next load;
- an empty chapter heading flows into the adjacent chapter;
- progress from the first visible next-chapter paragraph reports its own chapter ID;
- opening the directory after scrolling marks the visible chapter;
- `navigationGeneration` change jumps to the selected heading or saved paragraph.

- [ ] **Step 5: Run reader tests and verify RED**

Run:

```powershell
flutter test --no-pub test/features/reader/reader_page_test.dart
flutter test --no-pub test/app/navigation_test.dart
```

Expected: compilation or behavioral failures because `ReaderPage` still accepts one chapter and replaces its keyed list.

- [ ] **Step 6: Implement one flattened virtualized list**

Flatten loaded sections into heading and paragraph items plus a terminal item only when the final chapter is loaded. Remove `_nextChapterOverscrollThreshold`, `_bottomOverscroll`, `_nextChapterTransitionLocked`, `_continueToNextChapter`, the chapter-specific list key, and their tests.

Use `ItemScrollController` plus `ItemPositionsListener`. Before a prepend/eviction callback, capture:

```dart
ReaderViewportAnchor(
  itemKey: visibleItems.first.item.key,
  alignment: visibleItems.first.position.itemLeadingEdge,
)
```

After sections change, find the same key and call `jumpTo(index: newIndex, alignment: anchor.alignment)` in a post-frame callback. Appending without start-side eviction needs no jump.

Derive the current visible chapter and progress paragraph from the flattened item at the smallest visible index with a positive trailing edge. Trigger edge loads when the first/last visible index is within three items of the loaded boundary.

- [ ] **Step 7: Verify and commit**

Run:

```powershell
flutter test --no-pub test/app/reader_page_data_provider_test.dart test/features/reader/reader_page_test.dart test/app/navigation_test.dart
flutter analyze --no-pub
git diff --check
```

Commit:

```powershell
git add lib/app/providers.dart lib/app/router.dart lib/features/reader/presentation/reader_page.dart test/app/reader_page_data_provider_test.dart test/app/navigation_test.dart test/features/reader/reader_page_test.dart
git commit -m "feat: render chapters as a continuous reading stream"
```

---

### Task 3: Playback Cursor Publication And Paragraph Highlight

**Files:**
- Modify: `lib/features/playback/domain/playback_coordinator.dart`
- Modify: `lib/features/playback/data/background_audio_handler.dart`
- Modify: `lib/app/router.dart`
- Modify: `lib/features/reader/presentation/reader_page.dart`
- Modify: `test/features/playback/playback_coordinator_test.dart`
- Modify: `test/features/playback/background_audio_handler_test.dart`
- Modify: `test/features/reader/reader_page_test.dart`
- Modify: `test/app/navigation_test.dart`

**Interfaces:**
- Produces: `PlaybackCoordinator.cursorChanges` emitting each started paragraph cursor.
- Produces: `PlaybackRuntime.cursorChanges` forwarding only the attached coordinator and publishing `null` on stop/removal.
- Consumes: Task 2 chapter-owned paragraphs and window edge/center operations.
- Produces: `ReaderPage.playbackCursor`, `ReaderPage.playbackActive`, and `ReaderPage.onResumePlaybackFollow` behavior.

- [ ] **Step 1: Write failing coordinator/runtime cursor tests**

Add tests proving cursor publication on manual start, automatic paragraph advance, and automatic chapter advance:

```dart
final cursors = <PlaybackCursor?>[];
final subscription = coordinator.cursorChanges.listen(cursors.add);

await coordinator.playFrom(const PlaybackCursor(chapterId: 10, paragraphIndex: 0));
provider.completeCurrent();
await pumpEventQueue();

expect(cursors, [
  const PlaybackCursor(chapterId: 10, paragraphIndex: 0),
  const PlaybackCursor(chapterId: 10, paragraphIndex: 1),
]);
```

Runtime tests must prove an old replaced coordinator can no longer publish, the replacement can publish, pause does not publish `null`, and `dispose`/failed removal publishes `null`.

- [ ] **Step 2: Run playback tests and verify RED**

Run:

```powershell
flutter test --no-pub test/features/playback/playback_coordinator_test.dart test/features/playback/background_audio_handler_test.dart
```

Expected: `cursorChanges` does not exist.

- [ ] **Step 3: Implement cursor streams with lifecycle cleanup**

Add a synchronous broadcast controller to `PlaybackCoordinator`, emit the paragraph cursor only after `prepare`, speed restoration, and `play` succeed, and close it during `dispose`.

In `PlaybackRuntime`, subscribe during successful replacement, cancel the previous subscription before disposing the old coordinator, ignore stale generation events, forward cursor events through one runtime broadcast stream, and emit `null` when the active coordinator is removed or the runtime is disposed.

- [ ] **Step 4: Write failing playing-highlight and follow tests**

Widget tests must distinguish reading selection from playback:

```dart
await pumpReader(playbackCursor: const PlaybackCursor(chapterId: 11, paragraphIndex: 0));
expect(find.byKey(const ValueKey('playing-paragraph-11-0')), findsOneWidget);

await scrollReaderManually();
await rebuildWithPlaybackCursor(const PlaybackCursor(chapterId: 11, paragraphIndex: 1));
expect(find.byKey(const ValueKey('playing-paragraph-11-1')), findsOneWidget);
expect(itemScrollJumpCalls, isEmpty);
```

Also prove:

- cursor advancement while follow is active keeps the paragraph visible;
- entering an unloaded adjacent chapter requests the window load before following;
- reading-progress callbacks do not move the playing highlight;
- pausing retains the highlight and stopping clears it;
- starting playback from a paragraph resumes follow.

- [ ] **Step 5: Run reader/navigation tests and verify RED**

Run:

```powershell
flutter test --no-pub test/features/reader/reader_page_test.dart test/app/navigation_test.dart
```

Expected: no playback cursor input or playing-paragraph key exists.

- [ ] **Step 6: Implement separate playing state and conservative follow**

Pass the runtime cursor stream into `_ReaderRoutePageState`, rebuild only cursor-dependent reader properties, and ensure the cursor's owning chapter is loaded before following.

In `ReaderPage`, keep `_activeParagraphId` for reading interaction and derive playing decoration solely from `playbackCursor`. Use key `playing-paragraph-<chapterId>-<paragraphIndex>`. A user `ScrollStartNotification` with drag details sets `_playbackFollow = false`; the programmatic follow does not. `_play` sets it true before invoking the callback. When follow is true and the playing item is outside the current visible range, use `ItemScrollController.scrollTo` with a short duration and center alignment.

- [ ] **Step 7: Verify and commit**

Run:

```powershell
flutter test --no-pub test/features/playback/playback_coordinator_test.dart test/features/playback/background_audio_handler_test.dart test/features/reader/reader_page_test.dart test/app/navigation_test.dart
flutter analyze --no-pub
git diff --check
```

Commit:

```powershell
git add lib/features/playback/domain/playback_coordinator.dart lib/features/playback/data/background_audio_handler.dart lib/app/router.dart lib/features/reader/presentation/reader_page.dart test/features/playback/playback_coordinator_test.dart test/features/playback/background_audio_handler_test.dart test/features/reader/reader_page_test.dart test/app/navigation_test.dart
git commit -m "feat: follow the currently spoken paragraph"
```

---

### Task 4: Continuous Reader Integration And Failure Recovery

**Files:**
- Modify: `test/app/navigation_test.dart`
- Modify: `test/features/reader/reader_page_test.dart`
- Modify: implementation files from Tasks 1-3 only when a failing integration test proves a gap.

**Interfaces:**
- Consumes: all Tasks 1-3 interfaces.
- Produces: end-to-end guarantees for adjacent prefetch, retry, directory jumps, progress, playback, and bounded memory.

- [ ] **Step 1: Add failing route-level integration scenarios**

Use the in-memory Drift database and actual providers to cover:

```dart
testWidgets('reads continuously across chapters and restores the new position', (tester) async {
  tester.view.physicalSize = const Size(320, 480);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  final bookId = await database.createBookWithChapter(
    title: '连续阅读测试书',
    chapterTitle: '第1章',
    paragraphs: List.generate(8, (index) => '第1章第${index + 1}段正文。'),
  );
  final firstChapter = (await database.chaptersForBook(bookId)).single;
  for (var chapterIndex = 1; chapterIndex < 7; chapterIndex++) {
    final chapterId = await database.into(database.chapters).insert(
      ChaptersCompanion.insert(
        bookId: bookId,
        chapterIndex: chapterIndex,
        title: '第${chapterIndex + 1}章',
      ),
    );
    for (var paragraphIndex = 0; paragraphIndex < 8; paragraphIndex++) {
      await database.into(database.paragraphs).insert(
        ParagraphsCompanion.insert(
          chapterId: chapterId,
          paragraphIndex: paragraphIndex,
          content: '第${chapterIndex + 1}章第${paragraphIndex + 1}段正文。',
        ),
      );
    }
  }
  final thirdChapter = (await database.chaptersForBook(bookId))[2];
  await database.upsertProgress(
    bookId: bookId,
    chapterId: thirdChapter.id,
    paragraphIndex: 0,
  );

  await tester.pumpWidget(NovelVoiceReaderApp(database: database));
  await _pumpUntilFound(tester, find.text('连续阅读测试书'));
  await tester.tap(find.text('连续阅读测试书'));
  await _pumpUntilFound(tester, find.text('第3章'));
  await tester.scrollUntilVisible(find.text('第6章第2段正文。'), 320);
  await tester.pump(const Duration(milliseconds: 600));
  await tester.tap(find.byTooltip('返回书架'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('连续阅读测试书'));
  await _pumpUntilFound(tester, find.text('第6章第2段正文。'));

  final progress = await database.progressForBook(bookId);
  expect(progress?.chapterId, isNot(firstChapter.id));
  expect(find.text('第6章第2段正文。'), findsOneWidget);
});
```

Add separate route tests proving:

- a directory jump to chapter 7 rebuilds a centered window and does not leave stale chapter 3 text;
- an injected one-time section load failure leaves current text visible and a later edge approach retries;
- repeated edge notifications create one DB body query per chapter;
- playback automatically crosses from chapter 4 into chapter 5, highlights chapter 5, and keeps no more than five bodies loaded.

- [ ] **Step 2: Run integration tests and verify RED**

Run:

```powershell
flutter test --no-pub test/app/navigation_test.dart --plain-name "reads continuously"
flutter test --no-pub test/app/navigation_test.dart --plain-name "retries an adjacent chapter load"
flutter test --no-pub test/app/navigation_test.dart --plain-name "follows playback into the next chapter"
```

Expected: at least one new scenario fails against the composed implementation for a specific missing integration behavior.

- [ ] **Step 3: Apply only integration-proven fixes**

Fix the concrete failing boundaries without adding new abstractions: route/controller lifetime, anchor scheduling, loader retry wiring, or cursor-to-window sequencing. Do not change unrelated TTS, imports, caching, or player UI.

- [ ] **Step 4: Run focused and full verification**

Run:

```powershell
flutter test --no-pub test/app/reader_page_data_provider_test.dart test/features/reader/reader_chapter_window_controller_test.dart test/features/reader/reader_page_test.dart test/features/playback/playback_coordinator_test.dart test/features/playback/background_audio_handler_test.dart test/app/navigation_test.dart
flutter analyze --no-pub
flutter test --no-pub
dart run build_runner build
git diff --check
git status --short --branch
```

Expected: zero analysis issues, all tests pass, generated files remain stable, and only intended Task 4 changes are present.

- [ ] **Step 5: Commit**

```powershell
git add test/app/navigation_test.dart test/features/reader/reader_page_test.dart lib/app/providers.dart lib/app/router.dart lib/features/reader/presentation/reader_page.dart lib/features/reader/application/reader_chapter_window_controller.dart lib/features/playback/domain/playback_coordinator.dart lib/features/playback/data/background_audio_handler.dart
git commit -m "test: verify continuous cross-chapter reading"
```
