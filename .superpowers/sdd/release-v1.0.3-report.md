# Release Report: Manual Seek Latency → v1.0.3

## Status

DONE

## Scope

- Feature branch: `codex/manual-seek-latency`
- Reviewed HEAD: `8ac40f5` (13 commits over `main`, strict linear / clean fast-forward)
- Merged to `origin/main`: `d6bbf27..8ac40f5` (fast-forward, no `--force`)
- Release tag: `v1.0.3` (annotated) → `8ac40f5`
- CI run: `32804443057` (event=push, ref `refs/tags/v1.0.3`) — `test-android` / `build-android` / `build-ios` all success

## Independent final review

Verdict: **MERGEABLE**. All 7 target behaviors implemented and covered by tests:

1. Server polling front-loaded 150 → 250 → 500 ms (`ServerTtsClient._pollDelay`, index clamped to last). `maxPolls` 240 → 360 keeps the total timeout ≈ 180 s.
2. Scroll mode: first tap warms, double tap plays (`ReaderPage._handleParagraphTap`); no re-warm on the play tap.
3. Warm and confirmed playback reuse the same in-flight synthesis (`AudioCacheRuntime.obtainTracked`; router `_warmFrom` + `_playFrom` share one runtime).
4. Warm does not play, advance the cursor, or highlight (widget tests assert no active-paragraph and empty `played` on first tap).
5. Telemetry is exception-isolated (`recordPlaybackTelemetrySafely`; `PlaybackTelemetry.record` is sync `void`; `PlaybackCoordinator._record` switched to it).
6. Obtain source distinguished: `cacheHit` / `created` / `joinedInFlight`; confirmed seek records `source` + `reused`.
7. First-obtain-failure retry no longer loses telemetry (`_manualSeekRecorded` reset in `catch`; test "records a confirmed seek when an obtain retry succeeds").

Concurrency: in-flight dedup + `whenComplete` `identical` guard cleans up on both success and failure (failed key not poisoned; retry re-creates a fresh entry).

Notes (non-blocking): warm is speculative synthesis on each first tap (server provider only); `pubspec` stayed `1.0.0+1`, so the built APK reports `versionName` 1.0.0 / `versionCode` 1 regardless of the `v1.0.3` tag.

## Release artifact

- Artifact: `app-release` (from run `32804443057`)
- File: `app-release.apk`, 77,916,737 bytes
- SHA-256: `40c76a868bcb3290e9d3544ff7b33ad86e63d0f2d7a6e8d5641f09bef5401cd0`
- Signing: APK Signature Scheme v2/v3 present (no v1 JAR signature — expected for a release build)

## Remaining housekeeping (host-side)

- Fast-forward local `main` to `8ac40f5` on the host (left at `ffded2c` in the VM to avoid rewriting CRLF working-tree state).
- `git worktree prune` on the host (the VM cannot see the recorded Windows worktree paths, so pruning from the VM is unsafe).
