# Reader Chapter Navigation During Playback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent active playback-follow from undoing a manual directory chapter jump while leaving audio playback unchanged.

**Architecture:** Keep the behavior inside `ReaderPage`, where both directory selection and playback-follow are coordinated. Record that directory navigation suspended follow, gate scroll-end rearming and paged playback cursor forwarding with that state, and clear it only on an explicit reader playback action.

**Tech Stack:** Flutter, Dart, `flutter_test`, `scrollable_positioned_list`

## Global Constraints

- Do not pause, stop, restart, or redirect existing audio when a directory chapter is selected.
- Do not restore scroll-mode paragraph highlighting.
- Do not run local validation; push the focused test to CI as requested.

---

### Task 1: Preserve Manual Chapter Navigation During Playback

**Files:**
- Modify: `lib/features/reader/presentation/reader_page.dart`
- Test: `test/app/navigation_test.dart`

**Interfaces:**
- Consumes: `ReaderPage.playbackCursor`, `ReaderPage.onChapterSelected`, and the existing `_playbackFollow` state.
- Produces: Directory navigation that remains independent from the active playback cursor until `_startListening()` or `_play()` explicitly restores follow.

- [ ] **Step 1: Write the failing navigation test**

Start a `PlaybackRuntime` in chapter 1 in both scroll and slide modes, open the directory, select chapter 7, pump beyond the one-second follow heartbeat, then assert chapter 7 remains visible and the runtime cursor is still chapter 1.

- [ ] **Step 2: Verify the test would fail on current behavior**

Do not execute locally per user instruction. The pre-fix call chain is `onChapterSelected -> centerOn(target) -> sections update -> _followPlayingParagraph() -> onPlaybackChapterNeeded(old cursor chapter) -> centerOn(old chapter)`.

- [ ] **Step 3: Implement the minimal state fix**

Add `_playbackFollowSuspendedByNavigation`. Set it and disable `_playbackFollow` before invoking `onChapterSelected`. Do not rearm follow from `ScrollEndNotification` while the flag is set. Pass a null playback cursor to `PaginatedReaderView` while follow is disabled, and include `navigationGeneration` in its key so explicit jumps discard stale page anchors. Clear the flag in `_startListening()` and `_play()`.

- [ ] **Step 4: Submit CI verification**

Push the focused implementation and test. Confirm the GitHub Actions test workflow passes.

- [ ] **Step 5: Commit**

```powershell
git add docs/superpowers/specs/2026-08-24-reader-chapter-navigation-during-playback-design.md docs/superpowers/plans/2026-08-24-reader-chapter-navigation-during-playback.md lib/features/reader/presentation/reader_page.dart test/app/navigation_test.dart
git commit -m "fix(reader): preserve chapter browsing during playback"
git push origin HEAD
```
