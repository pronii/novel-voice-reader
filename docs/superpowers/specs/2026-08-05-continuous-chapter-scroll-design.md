# Continuous Chapter Scroll Design

## Goal

Turn vertical reading into one continuous, virtualized book flow. Reaching a
chapter boundary must reveal the next or previous chapter inline without
replacing the reader page, resetting the scroll position, or showing a loading
screen.

This replaces the current bottom-overscroll chapter transition. Directory
navigation remains available for non-adjacent jumps.

## Product Reference

- Apple Books renders content documents in EPUB spine order as a continuous
  vertical stream without gaps between documents.
- Readium describes continuous scroll as displaying multiple reading-order
  resources together and pre-rendering next and previous resources.
- Consumer novel readers expose this behavior as an up/down scrolling mode:
  chapter headings occur inside the text stream rather than as a page change.

References:

- https://help.apple.com/itc/booksassetguide/en.lproj/itc56959c420.html
- https://readium.org/architecture/navigator/

## Reader Data Model

The reader loads all chapter metadata but only a bounded window of chapter
bodies. A loaded chapter section contains:

- chapter ID, display index, and title;
- ordered paragraph records;
- enough identity to report progress and start playback without consulting a
  separate page-level current chapter.

The initial window is centered on the requested chapter:

- up to one previous chapter;
- the requested chapter;
- up to two following chapters.

When the reader approaches either loaded edge, it requests the next missing
chapter in that direction. Loaded sections are rendered by one virtualized
scroll list. At most five chapter bodies remain loaded. When a sixth section is
needed, the farthest fully offscreen section on the opposite side is removed.
Visible sections are never evicted. The implementation must not eagerly load
all paragraphs for the whole book.

## Continuous Layout

Each chapter is represented in the same list by a chapter heading followed by
its paragraphs. Adjacent sections have normal reading spacing, not an artificial
page boundary. The existing 48-pixel overscroll threshold, transition lock, and
chapter-replacement key are removed.

Approaching the end of a loaded chapter schedules the next section before the
user reaches the final paragraph. Appending content must not change the current
scroll offset. Prepending a previous chapter must preserve the first visible
item as the visual anchor so content does not jump. The same anchor restoration
is applied when an offscreen section is evicted from either side of the window.

At the end of the final chapter, the list shows a small `全书读完` terminal row.
It does not attempt another load or trigger chapter selection.

## Current Chapter And Progress

The current chapter is derived from visible content, not from the chapter that
was initially requested. The first visible paragraph determines the active
chapter. When only a chapter heading is visible, that heading determines it.

After scroll settlement and the existing debounce:

- persist the first visible paragraph's chapter ID and paragraph index;
- update the current chapter used by the directory selection marker;
- keep the visible scroll position unchanged;
- avoid duplicate persistence for the same paragraph.

Closing the reader flushes a pending progress update using the paragraph's own
chapter ID.

## Directory Navigation

The searchable directory keeps title and one-based number filtering. Opening
it scrolls to and marks the currently visible chapter.

Selecting a chapter outside the loaded window rebuilds a centered window and
positions the selected chapter heading at the start of the viewport. Selecting
the chapter containing saved progress positions the saved paragraph instead.
This explicit jump may replace the loaded window; ordinary adjacent scrolling
must never do so.

Clearing directory search restores the full chapter list and relocates the
currently visible chapter as before.

## Playback

Every paragraph exposed to the reader carries its owning chapter ID. Starting
playback from a paragraph constructs the playback cursor from that chapter ID
and paragraph index. Scrolling across a chapter boundary does not stop or
replace active audio by itself.

The player and background coordinator continue to advance through paragraphs
and chapters using the database source. Existing playback speed behavior is
unchanged.

### Playback Highlight And Follow

The reading position and playback position are separate states. Scrolling may
persist a new reading position, but it must not pretend that the newly visible
paragraph is currently playing.

The playback runtime publishes a cursor whenever playback starts a paragraph,
including automatic paragraph and chapter advancement. While the reader is
open, it maps that cursor to the owning chapter section and paragraph and uses
a dedicated playing highlight. Only one paragraph may have the playing
highlight.

Playback follow is active when playback is started from the reader. As the
cursor advances, the reader keeps the highlighted paragraph visible without
resetting the chapter window. If the cursor enters an unloaded adjacent
chapter, that chapter is loaded into the same continuous window before the
highlight is applied.

A deliberate user scroll suspends automatic following so the viewport is not
pulled away from text the user is inspecting. Playback and highlight updates
continue in the background. Starting playback from a paragraph or explicitly
selecting the highlighted playback position resumes automatic following.
Stopping playback clears the playing highlight. Pausing playback retains the
highlight at the paused paragraph.

## Loading And Failure States

The initial book load keeps the existing full-page loading and error states.
Adjacent prefetch is inline:

- only one load per direction may be active;
- duplicate edge notifications are coalesced;
- a failed adjacent load leaves existing text readable;
- retry occurs when the user approaches that edge again;
- no blank full-page state replaces already loaded content.

An empty chapter still renders its heading and continues into the adjacent
chapter. A book with no chapters keeps the existing empty reader behavior.

## Test Requirements

Tests must demonstrate:

1. The next chapter title and text are part of the same scroll list before the
   current chapter is overscrolled.
2. Scrolling from the last paragraph of one chapter to the first paragraph of
   the next does not rebuild or reset the list position.
3. The visible next chapter updates progress with that chapter's ID.
4. Starting playback from appended chapter text uses the appended chapter ID.
5. Automatic playback advancement moves the playing highlight to the new
   paragraph and keeps it visible while follow is active.
6. Playback advancing into an adjacent chapter loads that section inline and
   highlights the correct chapter-owned paragraph.
7. A deliberate manual scroll suspends viewport following without freezing the
   playback highlight; starting playback from a paragraph resumes following.
8. Reading-progress updates do not change the playing highlight, and pausing
   retains it while stopping clears it.
9. A directory jump centers a new window and positions the selected chapter.
10. Opening the directory after scrolling marks and locates the visible chapter.
11. Prepending a previous chapter preserves the visual anchor.
12. Loading a sixth chapter evicts only the farthest offscreen section, retains
   at most five chapter bodies, and preserves the visual anchor.
13. Repeated edge notifications do not start duplicate loads.
14. Adjacent load failure keeps existing text visible and can retry.
15. The final chapter terminates with `全书读完` and performs no extra load.

Existing tests for saved position restoration, searchable directories,
playback controls, and progress debounce must continue to pass.

## Non-Goals

- Loading every chapter body eagerly.
- Replacing the native paragraph renderer with WebView or a new EPUB engine.
- Adding horizontal pagination or a reading-mode selector in this change.
- Changing audio caching, cloud TTS, or playback speed behavior.
