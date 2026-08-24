# Reader Chapter Navigation During Playback Design

## Goal

When audio is playing, selecting another chapter from the reader directory must keep the reader on the selected chapter instead of following the still-playing cursor back to the audio chapter.

## Behavior

- Directory selection changes the reading chapter and persists that reading position.
- Existing audio continues from its current cursor without pause, restart, or chapter replacement.
- Directory selection disables playback-follow for the current browsing state.
- Programmatic scroll completion caused by the chapter jump must not re-enable playback-follow.
- Starting playback explicitly from the reader re-enables playback-follow.
- Scroll-mode paragraph taps remain visually neutral and do not change playback.
- Double-tapping a paragraph starts playback from that paragraph's existing `chapterId + paragraphIndex` cursor; no character-level offset is introduced.
- Paged modes receive no playback cursor while playback-follow is disabled and remount on an explicit navigation generation, so they initialize from the selected chapter instead of a stale page anchor.

## Implementation

`ReaderPage` owns a boolean that records whether directory navigation has suspended playback-follow. Selecting a directory chapter sets the flag and disables follow before notifying the route. Scroll completion only re-enables follow when directory navigation has not suspended it. The paginated view key includes the explicit navigation generation so a directory jump discards its stale anchor. Explicit playback actions clear the suspension and enable follow.

## Regression Coverage

App navigation widget tests cover scroll and slide modes. Each starts playback in chapter 1, selects chapter 7 from the directory, advances time beyond the follow heartbeat, and verifies chapter 7 remains visible while the playback cursor remains in chapter 1.

A reader widget test verifies that a single paragraph tap does not invoke playback while a double tap invokes playback exactly once with the tapped paragraph and does not restore scroll-mode highlighting.
