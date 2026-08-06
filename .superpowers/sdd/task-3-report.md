# Task 3 Report: Tap-Controlled Immersive Toolbar

## Status

DONE

## Scope

- Base: `13fdd289792b7e514a795f84d3756355142aac15`
- Branch: `fix/reader-playback-ux`
- Test-only RED commit: `1bf11e2d34be809ae50079da42af484cefe79a5d`
- Implementation commit: `2832418b9cdd37b9817bc28a47beab457b790c79`
- Test helper correction: `fae6cbcec0d92da97a8ce5058501c98df61d451f`

The implementation changed only the files authorized by the task brief:

- `lib/features/reader/presentation/reader_page.dart`
- `test/features/reader/reader_page_test.dart`
- `test/app/navigation_test.dart`

This report is the only additional file.

## TDD Evidence

### RED

The test-only commit added widget coverage for the hidden initial toolbar,
stationary tap toggle, unchanged paragraph geometry, drag rejection, and
paragraph selection coexistence. It was pushed before any production edit.

- Run: https://github.com/pronii/novel-voice-reader/actions/runs/31097604915
- `flutter analyze`: passed
- `flutter test`: failed as expected, 268 passed / 5 failed
- Expected cause: all five new tests failed because the baseline had no
  `reader-body` or `reader-toolbar`; existing reader tests continued to pass.

### GREEN

The first implementation run passed analysis and most new behavior tests, but
exposed test-helper side effects: a helper tap at the body center correctly
selected a paragraph as well as showing the toolbar. The geometry test also
held a dynamic active-paragraph key that changed after selection. Following
systematic debugging, the helper was changed to tap the body's 12 px outer
gutter and the geometry test now follows the stable paragraph text widget.
No production behavior or requirement assertion was weakened.

- Final run: https://github.com/pronii/novel-voice-reader/actions/runs/31098293203
- Head: `fae6cbcec0d92da97a8ce5058501c98df61d451f`
- Conclusion: success
- `flutter analyze`: passed
- Full `flutter test`: passed, 273 tests
- `flutter build apk --debug`: passed
- Android artifact upload: passed
- `flutter build ios --release --no-codesign`: passed
- Unsigned IPA packaging and artifact upload: passed

## Implementation

- Replaced the fixed `Scaffold.appBar` with a `SafeArea` containing a `Stack`.
- Kept reader content under the stable `reader-body` Listener so toolbar state
  never changes the body's layout constraints or scroll geometry.
- Kept the AppBar mounted under `reader-toolbar` and animated it for 180 ms
  with `AnimatedSlide`, `IgnorePointer`, and `ExcludeSemantics` hidden state.
- Preserved the existing title, actions, icons, tooltips, and callbacks.
- Stored one pointer id and its down position. Movement exceeding 8 logical
  pixels makes the gesture ineligible, so vertical scrolling never toggles the
  toolbar. Up and cancel both clear the stored gesture state.
- Placed the toolbar after the body in the Stack so visible controls receive
  hit testing without also triggering the body Listener.
- Added navigation helpers that reveal the toolbar and verify both zero slide
  offset and enabled pointer handling before toolbar interactions.

## Behavior Coverage

- Toolbar is visually hidden and non-interactive on initial open.
- First stationary body tap shows it; a second stationary tap hides it.
- The first visible paragraph keeps the same global position across the
  hidden/shown transition.
- A vertical scroll drag leaves the toolbar hidden.
- A paragraph tap still selects the paragraph and also toggles the toolbar.
- Existing chapter directory, reading settings, top play, player route, back
  navigation, continuous loading, position persistence, and playback-following
  assertions remain enabled and pass.
- The operating-system status area remains visible; no immersive system UI or
  auto-hide timer was added.

## Verification Notes

The local Windows environment did not have `dart` or `flutter` on PATH, so
Flutter execution evidence comes from the repository's pinned Flutter 3.44.8
GitHub Actions workflow. Local checks confirmed a clean worktree before the
report, `git diff --check` success, the expected commit order, and no code/test
files outside the brief's allowlist.

## Code Review

A read-only review of `13fdd28..fae6cbc` found no critical implementation
issues. Its only important finding was that the required Task 3 report was not
yet part of the reviewed commit range; this file resolves that finding. The
reviewer also suggested optional direct coverage of the exact 8 px boundary
and pointer-cancel recovery. Those cases are implemented explicitly, while the
task-required vertical drag behavior is covered by the passing widget test.
