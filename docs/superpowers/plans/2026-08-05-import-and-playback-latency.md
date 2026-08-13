# Import And Playback Latency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Speed up database persistence for large books and hide cloud synthesis time between spoken paragraphs.

**Architecture:** Drift batches paragraph writes per chapter. Cloud speech providers expose optional one-item lookahead prefetching, coordinated by playback without changing the active audio source.

**Tech Stack:** Flutter, Dart, Drift, just_audio, flutter_test

## Global Constraints

- Preserve import atomicity and paragraph ordering.
- Prefetch at most one next segment and keep normal preparation as fallback.
- Do not change system TTS behavior.

---

### Task 1: Batch Paragraph Persistence

**Files:**
- Modify: `test/features/library/book_import_repository_test.dart`
- Modify: `lib/features/library/data/book_import_repository.dart`

- [ ] Add a query-interceptor test expecting paragraph work to use `runBatched`.
- [ ] Run the test and observe failure because imports currently use individual inserts.
- [ ] Replace the inner paragraph insert loop with a Drift batch operation.
- [ ] Run library tests and confirm ordering and statement behavior.

### Task 2: One-Segment Cloud Audio Prefetch

**Files:**
- Modify: `test/features/playback/playback_coordinator_test.dart`
- Modify: `test/features/speech/cached_audio_speech_provider_test.dart`
- Modify: `lib/features/speech/domain/speech_provider.dart`
- Modify: `lib/features/speech/data/cached_audio_speech_provider.dart`
- Modify: `lib/features/playback/domain/playback_coordinator.dart`

- [ ] Add tests proving the next segment is prefetched without replacing active audio.
- [ ] Run tests and observe failure because no prefetch capability exists.
- [ ] Add the optional provider interface and cache-only implementation.
- [ ] Schedule guarded one-item lookahead from the playback coordinator.
- [ ] Run focused tests, the full test suite, and static analysis.
