# Reader Navigation And Speed Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make player speed effective, continue reading into the next chapter, and make large chapter directories searchable and current-position aware.

**Architecture:** Keep the reader's one-chapter data boundary and trigger the existing chapter-selection path after a deliberate bottom overscroll. Route speed through the existing audio handler and coordinator into provider-specific engines. Replace the plain chapter list with a searchable positioned list.

**Tech Stack:** Flutter, Riverpod, audio_service, flutter_tts, just_audio, scrollable_positioned_list, flutter_test.

## Global Constraints

- Preserve current reading progress persistence and single-chapter loading.
- Player choices remain `0.8x`, `1.0x`, `1.25x`, and `1.5x`.
- Search matches chapter title or one-based chapter number.
- No new runtime dependency.
- Every production change follows a failing widget or unit test.

---

### Task 1: Effective Playback Speed

**Files:**
- Modify: `lib/features/playback/domain/playback_coordinator.dart`
- Modify: `lib/features/playback/data/background_audio_handler.dart`
- Modify: `lib/features/playback/presentation/player_page.dart`
- Modify: `lib/features/speech/domain/speech_provider.dart`
- Modify: `lib/features/speech/data/system_tts_adapter.dart`
- Modify: `lib/features/speech/data/cached_audio_speech_provider.dart`
- Modify: `lib/app/router.dart`
- Test: `test/features/playback/background_audio_handler_test.dart`
- Test: `test/features/playback/playback_coordinator_test.dart`
- Create: `test/features/playback/player_page_test.dart`

**Interfaces:**
- Produces: `PlaybackController.setSpeed(double speed)`.
- Produces: `AdjustableSpeechProvider.setPlaybackSpeed(double speed)`.
- Produces: `PlayerPage.initialSpeed` and `PlayerPage.onSpeedChanged`.

- [ ] **Step 1: Write failing tests**

```dart
await handler.setSpeed(1.5);
expect(controller.speedChanges, [1.5]);
expect(handler.playbackState.value.speed, 1.5);
```

```dart
await coordinator.setSpeed(1.25);
expect(provider.speedChanges, [1.25]);
```

```dart
await tester.tap(find.text('1.5x'));
expect(selectedSpeed, 1.5);
```

- [ ] **Step 2: Run tests and verify behavior failures**

Run: `flutter test test/features/playback/background_audio_handler_test.dart test/features/playback/playback_coordinator_test.dart test/features/playback/player_page_test.dart`

Expected: the handler state remains `1.0`, the provider receives no speed, and the page exposes no effective speed callback.

- [ ] **Step 3: Implement the speed chain**

```dart
abstract interface class AdjustableSpeechProvider {
  Future<void> setPlaybackSpeed(double speed);
}
```

Add `setSpeed` to the controller, forward it through `NovelAudioHandler`, store it in `PlaybackCoordinator`, and reapply it after every `prepare`. Implement engine rate changes with `AudioPlayer.setSpeed` and `FlutterTts.setSpeechRate`. Wire `PlayerPage` to `handler.setSpeed` and initialize it from `handler.playbackState.value.speed`.

- [ ] **Step 4: Run focused tests and commit**

Run the Task 1 test command and expect all tests to pass.

Commit: `fix: apply player playback speed`

### Task 2: Continue Into The Next Chapter

**Files:**
- Modify: `lib/features/reader/presentation/reader_page.dart`
- Test: `test/features/reader/reader_page_test.dart`

**Interfaces:**
- Consumes: existing `chapters`, `currentChapterId`, and `onChapterSelected`.
- Produces: one-shot bottom overscroll chapter selection.

- [ ] **Step 1: Write failing reader tests**

```dart
await tester.drag(find.byType(ScrollablePositionedList), const Offset(0, -600));
await tester.drag(find.byType(ScrollablePositionedList), const Offset(0, -120));
expect(selectedChapterId, 2);
```

Add a second test with the last chapter selected and expect no callback.

- [ ] **Step 2: Run tests and verify failures**

Run: `flutter test test/features/reader/reader_page_test.dart --plain-name "continues to the next chapter"`

Expected: no chapter is selected after bottom overscroll.

- [ ] **Step 3: Implement one-shot bottom overscroll**

Track accumulated positive overscroll, trigger the next chapter at 48 logical pixels, and lock further transitions until `currentChapterId` changes. Reset accumulation on non-bottom scroll and chapter change.

- [ ] **Step 4: Run reader tests and commit**

Run: `flutter test test/features/reader/reader_page_test.dart`

Expected: all reader tests pass.

Commit: `fix: continue reading at the next chapter`

### Task 3: Searchable Current-Aware Chapter Directory

**Files:**
- Modify: `lib/features/reader/presentation/reader_page.dart`
- Test: `test/features/reader/reader_page_test.dart`

**Interfaces:**
- Consumes: existing `ReaderChapter.index`, `title`, and `currentChapterId`.
- Produces: directory search and positioned initial chapter.

- [ ] **Step 1: Write failing directory tests**

```dart
await tester.tap(find.byTooltip('章节目录'));
expect(find.text('第81章'), findsOneWidget);
```

```dart
await tester.enterText(find.byType(TextField), '目标章节');
expect(find.text('目标章节'), findsOneWidget);
expect(find.text('普通章节'), findsNothing);
```

- [ ] **Step 2: Run tests and verify failures**

Run:

```powershell
flutter test test/features/reader/reader_page_test.dart --plain-name "opens the chapter directory at the current chapter"
flutter test test/features/reader/reader_page_test.dart --plain-name "filters chapters by title and number"
```

Expected: the current late chapter is not built initially and no search field exists.

- [ ] **Step 3: Implement the directory**

Use `StatefulBuilder` for the query, `TextField` with a search icon, and `ScrollablePositionedList.builder` keyed by the query. Set `initialScrollIndex` to the current chapter's index in the filtered list, or zero when absent.

- [ ] **Step 4: Run all verification and commit**

Run:

```powershell
flutter analyze
flutter test
dart run build_runner build
git diff --check
```

Expected: zero analysis issues, all tests pass, generated files are stable, and no whitespace errors exist.

Commit: `fix: improve chapter navigation`
