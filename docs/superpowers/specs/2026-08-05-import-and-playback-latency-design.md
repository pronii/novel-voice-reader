# Import And Playback Latency Design

## Goal

Reduce large EPUB import time and remove network synthesis latency from the audible gap between cloud-TTS paragraphs.

## Design

- Keep the existing parser and transaction boundaries. Insert each chapter's paragraph companions through Drift's batch API instead of awaiting one SQLite call per paragraph.
- Add an optional `PrefetchingSpeechProvider` capability. The playback coordinator prefetches only the next segment while the current segment is playing.
- `CachedAudioSpeechProvider` implements prefetch by populating the existing file cache without changing the active player source. System TTS remains unchanged.
- Prefetch failures are ignored because normal `prepare` remains the authoritative path and already reports user-facing failures.
- A generation counter prevents stale asynchronous prefetch work from a prior manual seek from affecting the active playback sequence.

## Verification

- A Drift interceptor test must observe batched statements during import and verify every paragraph remains ordered and present.
- A coordinator test must prove that the next paragraph is prefetched before completion, then prepared and played after completion.
- Existing playback, import, full Flutter tests, and static analysis must pass.
