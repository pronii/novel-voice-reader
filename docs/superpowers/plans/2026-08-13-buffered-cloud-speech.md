# Buffered Cloud Speech Implementation Plan

**Goal:** Maintain about three minutes of ordered cloud TTS audio in the native
player queue, including the next chapter, without breaking highlighting or
navigation.

**Architecture:** PlaybackCoordinator plans ordered future speech segments;
CachedAudioSpeechProvider serially materializes and queues them; the just_audio
engine owns native playlist continuity and emits item-aware transitions.

### Task 1: Semantic chunk policy

**Files:** `lib/features/speech/domain/voice_profile.dart`,
`lib/features/speech/domain/speech_segmenter.dart`, corresponding tests.

1. Add failing tests for MiMo semantic target sizing and hard sentence splits.
2. Add provider-aware target/max character policy.
3. Run focused tests and commit.

### Task 2: Three-minute future planner

**Files:** `lib/features/playback/domain/playback_coordinator.dart`,
`test/features/playback/playback_coordinator_test.dart`.

1. Add failing tests proving multiple segments are planned and planning crosses
   into the next chapter until the estimated 180-second target is reached.
2. Change the prefetch contract from one segment to an ordered batch.
3. Preserve continuation ownership checks at every paragraph lookup.
4. Run focused tests and commit.

### Task 3: Serial cache and multi-item native queue

**Files:** `lib/features/speech/data/cached_audio_speech_provider.dart`,
`test/features/speech/cached_audio_speech_provider_test.dart`.

1. Add failing tests for ordered multi-item queueing, cache reuse, stale batch
   invalidation, and item-aware completion.
2. Extend the engine contract to replace future queue items atomically.
3. Obtain files serially and append them in order.
4. Keep promotion and terminal completion race handling.
5. Run focused tests and commit.

### Task 4: Regression verification and packaging

1. Run `flutter analyze` and the complete Flutter test suite in CI.
2. Request independent review focused on queue races and cross-platform impact.
3. Fix all blocking and important findings and rerun CI.
4. Trigger the manual workflow, verify iOS release and Android build artifacts,
   and download the unsigned IPA.
