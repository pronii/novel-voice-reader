# Reader Playback UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent read-from-here playback from jumping to the old cursor, display estimated current-chapter remaining time, and provide a tap-controlled immersive reader toolbar.

**Architecture:** Preserve immutable chapter-window identity and hold a pending playback target in `ReaderPage` until the runtime confirms it. Enrich provider segment timelines in `PlaybackCoordinator` with a chapter estimate sourced from Drift paragraph character counts. Render reader controls as an overlay whose visibility is toggled by stationary pointer taps.

**Tech Stack:** Flutter, Dart, Riverpod, Drift, `scrollable_positioned_list`, `flutter_test`, GitHub Actions.

## Global Constraints

- Preserve continuous chapter loading, reading-position persistence, paragraph selection, and normal playback following.
- Do not pre-generate or download a whole chapter to calculate duration.
- Keep the progress bar and left elapsed/total label scoped to the current audio segment.
- Render the right label as `本章剩余 mm:ss` and apply the effective playback speed.
- Hide only the app toolbar; keep the operating-system status area unchanged.
- Showing or hiding the toolbar must not change reader body geometry.

---

### Task 1: Playback Target Handoff

**Files:**
- Modify: `test/features/reader/reader_page_test.dart`
- Modify: `test/features/reader/reader_chapter_window_controller_test.dart`
- Modify: `lib/features/reader/application/reader_chapter_window_controller.dart`
- Modify: `lib/features/reader/presentation/reader_page.dart`

**Interfaces:**
- Consumes: `PlaybackCursor`, `ReaderChapterWindowController.sections`, `ReaderPage.onPlayFrom`.
- Produces: stable `sections` list identity and a private pending requested cursor in `ReaderPage`.

- [ ] **Step 1: Write failing regressions**

Add a controller test that stores `controller.sections` twice after initialization and expects `identical(first, second)` to be true. Add a narrow reader widget test with 30 paragraphs, an old playback cursor at paragraph 0, and a host callback that rebuilds with `playbackStarting: true` when paragraph 20 starts. Select paragraph 20, press `从这里朗读`, rebuild with a new section wrapper, and assert paragraph 20 remains visible instead of paragraph 0 being followed.

- [ ] **Step 2: Run the red tests**

Run in GitHub Actions after pushing the test-only commit:

```powershell
$redRunId = gh run list --branch fix/reader-playback-ux --limit 1 --json databaseId --jq '.[0].databaseId'
gh run watch $redRunId --exit-status
```

Expected: controller identity and read-from-here no-jump tests fail on the old implementation.

- [ ] **Step 3: Implement the minimum fix**

Return the already immutable `_sections` field directly:

```dart
List<ReaderChapterSection> get sections => _sections;
```

In `ReaderPage`, store the cursor requested by `_play`:

```dart
PlaybackCursor? _pendingPlaybackTarget;

void _play(ReaderParagraph paragraph) {
  _pendingPlaybackTarget = PlaybackCursor(
    chapterId: paragraph.chapterId,
    paragraphIndex: paragraph.index,
  );
  // Preserve the existing selection, progress report, and callback.
}
```

At the start of `_followPlayingParagraph`, ignore an old cursor while a different target is pending. Clear the pending target when it matches the runtime cursor, then continue normal follow behavior. If playback startup finishes without reaching the target, clear the pending value without scrolling away from the user's selection.

- [ ] **Step 4: Verify green and commit**

Run the focused reader tests in CI, then commit:

```powershell
git add test/features/reader lib/features/reader
git commit -m "fix: keep read-from-here target stable"
```

### Task 2: Current-Chapter Remaining Time

**Files:**
- Modify: `test/features/playback/playback_coordinator_test.dart`
- Modify: `test/features/playback/player_page_test.dart`
- Modify: `test/features/playback/playback_recovery_test.dart`
- Modify: `lib/features/playback/domain/playback_timeline.dart`
- Modify: `lib/features/playback/domain/playback_coordinator.dart`
- Modify: `lib/features/playback/presentation/player_page.dart`
- Modify: `lib/features/reader/data/reading_progress_repository.dart`

**Interfaces:**
- Produces: `PlaybackChapterTextSource.remainingCharactersInChapter(PlaybackCursor)`, `PlaybackTimeline.chapterRemaining`.
- Consumes: provider segment `position` and `duration`, current segment rune count, Drift chapter paragraphs, player speed.

- [ ] **Step 1: Write failing domain and widget tests**

Add tests requiring:

```dart
const PlaybackTimeline(
  position: Duration(seconds: 10),
  duration: Duration(seconds: 20),
  chapterRemaining: Duration(minutes: 3),
)
```

The player must render `本章剩余 03:00` at 1.0x and recompute after a speed change. A timed coordinator test must provide two same-chapter paragraphs, publish a 20-second timeline for a 10-character current segment, and expect the enriched chapter estimate to include the later paragraph. A Drift source test must ensure only text from the current cursor through the same chapter's end is counted.

- [ ] **Step 2: Run the red tests**

Push the test-only commit and wait for CI. Expected: compilation or expectation failure because `chapterRemaining` and the chapter text source capability do not exist.

- [ ] **Step 3: Add the timeline and source capability**

Extend `PlaybackTimeline`:

```dart
final Duration? chapterRemaining;
```

Add an optional capability next to `PlaybackParagraphSource`:

```dart
abstract interface class PlaybackChapterTextSource {
  Future<int> remainingCharactersInChapter(PlaybackCursor cursor);
}
```

Implement it in `DriftPlaybackParagraphSource` by loading paragraphs in the same chapter whose index is greater than or equal to the cursor index and summing `record.content.runes.length`.

- [ ] **Step 4: Enrich coordinator timelines**

When a paragraph starts, load the remaining chapter character count if the source supports `PlaybackChapterTextSource`. For each timeline:

```dart
const fallbackMicrosPerCharacter = 240000;
final completedCharacters = _segments
    .take(_segmentIndex)
    .fold<int>(0, (total, segment) => total + segment.text.runes.length);
final currentCharacters = _segments[_segmentIndex].text.runes.length;
final laterCharacters = max(
  0,
  chapterCharacters - completedCharacters - currentCharacters,
);
final microsPerCharacter = duration == null || currentCharacters == 0
    ? fallbackMicrosPerCharacter
    : duration.inMicroseconds ~/ currentCharacters;
final currentRemaining = duration == null
    ? Duration(microseconds: currentCharacters * microsPerCharacter)
    : duration - position;
final chapterRemaining = currentRemaining +
    Duration(microseconds: laterCharacters * microsPerCharacter);
```

Publish the enriched value both before playback preparation and for provider timeline events.

- [ ] **Step 5: Render and verify the chapter label**

Use `timeline.chapterRemaining` in `PlayerPage`, falling back to current-segment remaining when absent. Divide by `_speed`, render `本章剩余`, run focused tests, then commit:

```powershell
git add lib/features/playback lib/features/reader/data test/features/playback
git commit -m "feat: show current chapter remaining time"
```

### Task 3: Tap-Controlled Immersive Toolbar

**Files:**
- Modify: `test/features/reader/reader_page_test.dart`
- Modify: `test/app/navigation_test.dart`
- Modify: `lib/features/reader/presentation/reader_page.dart`

**Interfaces:**
- Produces: body key `reader-body`, overlay key `reader-toolbar`, private `_toolbarVisible` state.
- Preserves: existing AppBar actions and tooltips.

- [ ] **Step 1: Write failing reader chrome tests**

Add tests asserting the toolbar is visually hidden initially, a stationary tap on `reader-body` reveals it, a second tap hides it, and the first paragraph's global position does not change. Add a separate drag test proving a scroll gesture does not reveal the toolbar.

- [ ] **Step 2: Run the red tests**

Push the test-only commit. Expected: the existing fixed `Scaffold.appBar` is visible and no `reader-body`/`reader-toolbar` overlay state exists.

- [ ] **Step 3: Implement overlay chrome and tap detection**

Build the page as a `Stack` with the full-height reader body and an `AnimatedSlide` toolbar overlay. Keep the toolbar mounted, wrap it with `IgnorePointer` and `ExcludeSemantics` while hidden, and translate it by `Offset(0, -1)`.

Wrap the body in `Listener` keyed `reader-body`. Record pointer-down position and toggle only when pointer-up remains within 8 logical pixels. Clear the candidate when movement exceeds the threshold or the pointer is cancelled. Use the existing AppBar as the overlay content keyed `reader-toolbar`.

- [ ] **Step 4: Update navigation tests and verify**

Add a helper that taps `reader-body` before tests interact with reader toolbar actions. Run reader and navigation tests, then commit:

```powershell
git add lib/features/reader/presentation/reader_page.dart test/features/reader/reader_page_test.dart test/app/navigation_test.dart
git commit -m "feat: add immersive reader toolbar"
```

### Task 4: Full Verification and Packaging

**Files:**
- Verify only; no production changes unless a failing test identifies a root cause.

- [ ] **Step 1: Push and verify GitHub Actions**

Confirm `flutter analyze`, full `flutter test`, Android APK build, and iOS no-codesign build all succeed.

- [ ] **Step 2: Request independent code review**

Review the complete range from `5e4c1f5` to the feature head for state races, duration math, pointer handling, and regression coverage. Fix all critical and important findings with tests.

- [ ] **Step 3: Verify repository state**

```powershell
git diff --check 5e4c1f5..HEAD
git status --short
git rev-list --left-right --count HEAD...origin/fix/reader-playback-ux
```

Expected: no diff warnings, clean worktree, and `0 0` remote divergence.

- [ ] **Step 4: Package final artifacts**

Download the final CI APK and unsigned IPA. Sign the APK with the existing local fixed keystore, verify APK Signature Scheme v2 and certificate SHA-256 `267cb8de01589736b4b25f8abe46451289c3441faa2c6bc2910fc053c21ff195`, and report exact file SHA-256 values.
