# Reader Playback UX Design

## Goal

Fix paragraph playback selection jumping to the old playing paragraph, show the current chapter's estimated remaining playback time, and make the reader toolbar immersive by hiding it until the page is tapped.

## Confirmed Behavior

- Tapping a paragraph still selects it and exposes `从这里朗读`.
- Starting playback from a selected paragraph must keep that paragraph in view while the new TTS request is prepared. The old playback cursor must not pull the list back.
- Normal playback following resumes when the runtime publishes the newly requested cursor.
- The player keeps its current audio-segment progress bar and elapsed/total labels. The right label changes to `本章剩余 mm:ss` and covers all text remaining in the current chapter.
- Chapter remaining time is an estimate. Use the current segment's real duration when available and a conservative per-character estimate for text whose audio has not been prepared. Apply the selected playback speed in the player UI.
- The reader toolbar is hidden when the reader opens. A short tap in the reading body toggles it. A drag used for scrolling must not toggle it.
- The toolbar overlays the reader instead of changing the list's layout, so showing or hiding it does not move the current paragraph.

## Root Cause

`ReaderChapterWindowController.sections` returns a new unmodifiable wrapper on every read. `ReaderPage.didUpdateWidget` uses collection identity to decide whether playback following should run. Pressing `从这里朗读` changes `playbackStarting` in the route, rebuilds the page with a different wrapper, and schedules a follow operation against the still-current old playback cursor. That operation scrolls away from the paragraph the user just selected.

The player receives `PlaybackTimeline` directly from the speech provider. That timeline describes one prepared speech segment, not a paragraph or chapter, so subtracting `position` from `duration` can only produce the current segment's remaining time.

## Design

### Playback Target Handoff

Keep the controller's immutable section list identity stable until a real window mutation occurs. In `ReaderPage`, record the cursor requested by `从这里朗读`. While the runtime still reports a different cursor, suppress automatic playback following. Clear the pending target and resume following as soon as the requested cursor arrives. This protects the interaction even if a real chapter-window mutation occurs while TTS is preparing.

### Chapter Remaining Estimate

Add an optional chapter-character-count capability to the paragraph source. The Drift source counts Unicode runes from the current paragraph through the end of the current chapter.

The playback coordinator enriches each provider timeline with `chapterRemaining`:

1. Count characters remaining in the chapter when a paragraph starts.
2. Subtract characters in already completed segments.
3. Use the current segment's real duration per character when it is available.
4. Otherwise use a 240 ms per-character fallback.
5. Add the current segment's remaining duration to the estimate for all later characters.

The player divides this base estimate by the effective speed and renders `本章剩余 mm:ss`. If chapter information is unavailable, it falls back to the current segment remainder rather than showing a false zero.

### Immersive Reader Toolbar

Render the toolbar as an overlay over a full-height reading body. Track pointer movement in the body: a release within an 8 logical-pixel movement threshold counts as a tap and toggles the toolbar; a scroll drag does nothing. The paragraph's existing tap behavior remains active, so the same tap can select a paragraph and reveal the toolbar.

## Alternatives Considered

- Generate every remaining audio segment to obtain exact chapter duration: rejected because it delays playback, consumes network and cloud quota, and defeats on-demand caching.
- Estimate the whole chapter only from a fixed words-per-minute value: simpler, but ignores real audio duration already available for the current segment. The hybrid estimate is more stable and more accurate.
- Remove playback following entirely: rejected because following the highlighted paragraph is useful during normal hands-free reading.
- Put the toolbar back into `Scaffold.appBar` when visible: rejected because adding and removing it changes body constraints and visibly shifts the text.
- Auto-hide the toolbar on a timer: rejected because it can disappear while the user is choosing a chapter or opening settings. Explicit tap toggling is predictable.

## Testing

- Widget regression: starting from a selected off-screen paragraph while an old cursor is active does not jump back to the old paragraph.
- Controller regression: repeated reads of unchanged sections preserve identity.
- Coordinator tests: chapter remaining includes later paragraphs and decreases as the current segment advances.
- Player test: the right label uses chapter remaining time and playback speed.
- Reader tests: toolbar is hidden initially, a tap reveals it without moving text, a second tap hides it, and a drag does not toggle it.
- Run focused tests, `flutter analyze`, the full Flutter suite, Android build, and iOS no-codesign build in GitHub Actions.
