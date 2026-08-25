# Final Review Fix Report

## Status

Complete. All Important and Minor findings from `final-review-findings.md`
are implemented. An independent final review found no Critical or Important
issues and one additional Minor retry-observability gap; that gap was also
fixed through its own corrected RED/GREEN cycle.

Local `flutter test` and `flutter analyze` were intentionally not run. All
behavioral verification used GitHub Actions, as required.

## TDD / CI Evidence

### Initial RED

- Commit: `78478c6766367b523f1bf32c920b1bfb538ca111`
  (`test(playback): specify final seek telemetry fixes`)
- Run: `32800238210`
- Result: expected failure in `flutter analyze` after `build_runner` passed.
- Evidence: 20 missing-API errors for `AudioCacheObtainSource`,
  `obtainTracked`, manual-seek cache instrumentation parameters, and
  `ServerTtsClient.telemetry`. `flutter test` was skipped after analysis.

### First GREEN

- Commit: `3b9f25439f2e9893d0cec554a7bed1925a707a60`
  (`feat(playback): add safe manual seek telemetry`)
- Run: `32800576866`
- Result: success. `build_runner` passed, `flutter analyze` reported no
  issues, and `flutter test` reported 401 passed / 1 skipped.

### Independent Review Follow-up

- Review result at `3b9f254`: no Critical or Important findings. One Minor:
  a failed first confirmed-seek obtain consumed the one-shot telemetry marker,
  so a successful retry did not emit its cache source.
- Commit: `99aef2ece07a230a5f036b1c22e8ea9e5cf5afab`
  (`test(downloads): cover confirmed seek obtain retry`)
- Run: `32801118535`
- Result: failure for the wrong reason. The test adapter used a retriable
  connection error, which `CloudTtsClient` retried internally; the first
  cache obtain therefore succeeded. This run did not establish RED.
- Commit: `c22c2794ae719baa1f524600c53561061cc186e0`
  (`test(downloads): fail first seek obtain without retry`)
- Run: `32801351559`
- Result: correct RED. Analysis passed; tests reported 401 passed / 1 failed /
  1 skipped. The target test completed the second obtain successfully but
  expected one confirmed-seek event and observed zero.
- Commit: `9ab94316cbab48570abef879be0f8b6e26581607`
  (`fix(downloads): retain seek telemetry across retry`)
- Run: `32801563208`
- Result: final implementation GREEN. `build_runner` passed,
  `flutter analyze` reported no issues, and `flutter test` reported
  402 passed / 1 skipped.

## Implementation

- Added a typed `AudioCacheObtainSource` and `AudioCacheObtainResult` while
  preserving `SpeechAudioCache.obtain -> Future<File>` and the existing cache
  identity (`bookId + CacheKey.forSegment(segment, profile)`).
- `AudioCacheRuntime.obtainTracked` observes `created`, `joinedInFlight`, or
  `cacheHit` from the same single obtain operation. It does not perform a
  lookup before obtain and does not issue another synthesis request.
- The confirmed manual-seek cache wrapper records only its first successful
  obtain, so automatic look-ahead prefetch is not mislabeled. A failed first
  obtain restores eligibility for the normal playback retry.
- Manual warm-up remains restricted to `SpeechProviderType.server`, warms only
  the first segment, records a fixed `empty_text` skipped terminal event, and
  records its typed cache source.
- `ServerTtsClient` records job creation-response-to-ready duration and poll
  count at the completed status response. Fields contain no URL, request body,
  novel text, cache key, or credentials.
- `PlaybackCoordinator` records prepare-to-play duration after successful
  playback start.
- All new telemetry sites use `recordPlaybackTelemetrySafely`; a throwing sink
  cannot affect warm-up, synthesis, caching, confirmed playback, or retries.
- Updated polling design wording to match the implemented immediate first
  status GET followed by 150/250/500 ms delays after pending responses.

## Files Changed

- `docs/plans/2026-08-24-manual-seek-latency-design.md`
- `lib/app/router.dart`
- `lib/features/diagnostics/domain/playback_telemetry.dart`
- `lib/features/downloads/application/audio_cache_runtime.dart`
- `lib/features/downloads/data/audio_cache_repository.dart`
- `lib/features/playback/application/manual_seek_prewarmer.dart`
- `lib/features/playback/domain/playback_coordinator.dart`
- `lib/features/speech/data/server_tts_client.dart`
- `lib/main.dart`
- `test/features/downloads/audio_cache_runtime_test.dart`
- `test/features/playback/manual_seek_prewarmer_test.dart`
- `test/features/playback/playback_coordinator_test.dart`
- `test/features/speech/server_tts_client_test.dart`
- `.superpowers/sdd/final-fix-report.md`

No change was made to `.superpowers/sdd/progress.md`. The pre-existing local
modification to `.superpowers/sdd/task-3-report.md` was preserved and excluded
from every commit.

## Test Coverage

- `manual_seek_prewarmer_test.dart`: server-only behavior; input longer than
  1000 characters warms exactly the first segment; empty text terminal skip;
  all three cache sources; warm failure; throwing telemetry on success/failure.
- `audio_cache_runtime_test.dart`: created/joined/cache-hit sources; one server
  job across warm and confirmed seek; confirmed cache/in-flight reuse events;
  throwing telemetry; failed first obtain followed by a successful recorded
  retry.
- `server_tts_client_test.dart`: immediate first GET and 150/250/500 ms pending
  delays; safe creation-to-ready fields; throwing telemetry isolation.
- Additional focused test: `playback_coordinator_test.dart` covers safe
  prepare-to-play duration fields and throwing telemetry isolation.

## Self-Review

- Cache key, `chapterId + paragraphIndex` cursor, and public playback cache
  interface remain compatible.
- Warm-up never calls play, updates progress/cursor, selects, or highlights.
- A late warm-up can only complete the shared cache operation.
- No telemetry path performs a second obtain, lookup, or cloud request.
- Only the first obtain of a confirmed manual-seek provider is labeled; later
  automatic prefetch uses the same wrapper without another confirmed event.
- Every warm begin has success, failure, or skipped terminal handling.
- New telemetry fields were checked for URL, request text/body, cache keys, and
  credentials; none are emitted.
- Independent review after the first GREEN found only the retry Minor described
  above. It is covered by the final GREEN run.

## Concerns

- No blocking code concerns.
- CI-only verification was required; no local Flutter validation was run.
- GitHub Actions reports a workflow-maintenance warning that
  `actions/checkout@v4` targets deprecated Node.js 20 and is forced onto
  Node.js 24. It did not affect the successful jobs and is outside this scope.
