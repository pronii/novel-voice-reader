# Buffered Cloud Speech Design

## Goal

Cloud TTS playback should feel chapter-continuous and remain reliable while an
iPhone is locked. The app will keep roughly three minutes of future speech in
the native audio queue, crossing chapter boundaries when necessary, while
retaining paragraph highlighting and cache reuse.

## Decisions

- Keep audio split into semantic chunks. Prefer sentence boundaries and target
  chunks that represent about 45 to 90 seconds of speech.
- Use a deterministic character estimate of 240 ms per Chinese character until
  measured audio duration is available. The initial buffer target is 3 minutes.
- Plan future segments in playback order, including later paragraphs and the
  next chapter through `PlaybackParagraphSource.nextAfter`.
- Synthesize serially. MiMo already retries transient failures and rate limits;
  a serial queue prevents a burst of requests.
- Store each generated chunk through the existing content-addressed audio cache.
- Queue multiple local files in just_audio/AVQueuePlayer before the current file
  ends. Native playback must not depend on Dart waking at every boundary.
- Invalidate all pending planning and queue mutations when the playback target,
  voice profile, or continuation epoch changes.
- Preserve logical `SpeechStarted` and `SpeechCompleted` events per segment so
  cursor persistence, highlighting, remaining-time calculation, and chapter
  transitions remain correct.

## Components

### Semantic segment sizing

`VoiceProfile` supplies a target and hard maximum chunk size. MiMo uses a
larger semantic chunk than providers with strict limits; Tencent retains its
150-character hard limit. `SpeechSegmenter` continues to prefer punctuation
and only hard-splits sentences that exceed the provider maximum.

### Future segment planner

`PlaybackCoordinator` walks the remaining pieces of the current paragraph and
then calls `nextAfter` repeatedly. It returns ordered segments until their
estimated duration reaches three minutes. Because `nextAfter` crosses chapters
in the Drift implementation, no chapter-specific branch is needed.

### Batch prefetch contract

`PrefetchingSpeechProvider` accepts an ordered list of segments. The cached
provider obtains them serially, reuses existing files, and appends each valid
item to the native queue. Every asynchronous boundary checks a generation
token. A newer prepare invalidates stale work.

### Native queue events

The audio engine associates queued file paths with segment IDs. Native index
changes identify exactly which segment began and which previous segment
completed. Terminal completion is attributed to the current queue item.
Promotion removes consumed items without rebuilding the remaining playlist.

## Failure handling

- A failed look-ahead request does not stop the current audio. Normal prepare
  remains the authoritative error path when playback reaches the missing item.
- MiMo retry/backoff remains unchanged.
- Jumping, stopping, or disposing invalidates stale prefetches and native queue
  additions.
- Cache validation and partial-file cleanup remain in `AudioCacheRepository`.

## Testing

- Semantic splitting respects punctuation and provider hard limits.
- Planner fills approximately three minutes and crosses a chapter boundary.
- Batch prefetch is serial, ordered, and reuses cache files.
- Stale batches cannot mutate a newer native queue.
- Native index transitions emit one lifecycle event per segment, including
  delayed Dart delivery while locked.
- Existing speed, highlighting, progress, remaining-time, and navigation tests
  remain green.

## Non-goals

- No single audio file per chapter.
- No parallel MiMo synthesis.
- No new user setting in this change; the buffer target is initially fixed at
  three minutes.
- Existing manual chapter download settings are unchanged.
