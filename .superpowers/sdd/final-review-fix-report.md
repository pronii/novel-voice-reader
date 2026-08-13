# Final Review Fix Report: Serialize Playback Takeover

## Status

DONE

## Scope

- Base: `ce41edada78df2b33f729fca600f7ef4b97dda70`
- Branch: `fix/reader-playback-ux`
- Test-only RED commit: `f91a1deae72502fbdc8842f23278a650232234be`
- Provider serialization implementation: `3ffee517d5813cc3db75cf993971d3e821590da4`
- Analyzer correction: `fe0dd9326b180bae8184b9dfada5a7f6703259ba`
- Final behavior correction: `5a1b726e40221a6e13a84d14f7a33452105836b0`
- Re-review base/report: `09a271cd81ab579cf70e271544b04749e9617e36`
- Continuation ownership RED: `50095a6e03faa62d8f7f60fcc2c5c7139c468672`
- Continuation ownership implementation: `76a8f57caf9d4109334b6a0f8770dfa00105cc54`

The implementation changed only the two files authorized by the brief:

- `lib/features/playback/domain/playback_coordinator.dart`
- `test/features/playback/playback_coordinator_test.dart`

This report is the only additional file.

## Root Cause

`PlaybackCoordinator` used `_playbackGeneration` to order lookup completion,
but it checked the generation only after `SpeechProvider.prepare`. Two rapid
requests could therefore enter stateful provider preparation concurrently.
The provider API does not promise ordering, cancellation, or concurrency
safety. `SystemTtsAdapter` and cached speech providers retain mutable current
segment/configuration state, so a stale prepare could overwrite the segment
that a newer request intended to play.

`playFrom` also disabled timeline acceptance and cleared `_segments` before
paragraph lookup, chapter character lookup, and segmentation succeeded. A
failed replacement therefore damaged the still-active playback even though no
new provider takeover was ready.

The first fix still let `_handleSpeechEvent` read the mutable global request
generation when an active segment completed. While B was waiting for lookup or
chapter count, A could therefore borrow B's generation for its next-segment
continuation. That continuation also read the target index and segment from
shared state when its queued closure ran. If B became ready while A's prepare
was in flight, A could pass the generation check, play its stale segment, and
then let B take over.

## TDD Evidence

### RED

The test-only commit was pushed before any production edit. It added a
controllable stateful provider and focused tests for serialized takeover,
failed paragraph lookup, and failed chapter character lookup.

- Run: https://github.com/pronii/novel-voice-reader/actions/runs/31100164969
- Head: `f91a1deae72502fbdc8842f23278a650232234be`
- `flutter analyze`: passed
- `flutter test`: failed as expected, 272 passed / 3 failed
- Serialization failure: expected only A in `prepare`, but A and B were both
  active before A completed.
- Paragraph lookup failure: the active timeline remained at 1 second instead
  of accepting the later 2-second update.
- Chapter count failure: the active timeline was reset to zero instead of
  accepting the 2-second update.
- The independent iOS no-codesign build and unsigned IPA artifact succeeded.

### GREEN Iteration

The first implementation run exposed one analyzer-only lint in the error
recovery callback. After correcting it, the next run exposed two precise
behavioral issues: the tests read `timelines.last` after normal segment
continuation had correctly published its existing zero reset, and dispose had
been changed to wait for a provider `play` future that may intentionally hang.
The final correction restored the existing dispose contract and separated the
timeline-retention assertion from the subsequent continuation assertion. No
behavior expectation or provider API was weakened.

- Analyzer run: https://github.com/pronii/novel-voice-reader/actions/runs/31100648608
- Behavior diagnosis run: https://github.com/pronii/novel-voice-reader/actions/runs/31100847275

### First-Cycle Final GREEN

- Run: https://github.com/pronii/novel-voice-reader/actions/runs/31101192958
- Head: `5a1b726e40221a6e13a84d14f7a33452105836b0`
- Conclusion: success
- `flutter analyze`: passed
- Full `flutter test`: passed, 275 tests
- `flutter build apk --debug`: passed
- Android artifact upload: passed
- `flutter build ios --release --no-codesign`: passed
- Unsigned IPA packaging and artifact upload: passed

### Re-review RED

The second test-only commit added a focused stateful-provider scenario. A was
active with two segments, B waited on chapter count, and A completed its first
segment. A's second-segment prepare then hung until B became ready. The test
required A2 never to play, B to prepare/play exactly once, the final cursor and
provider segment to be B, and prepare concurrency to remain one.

- Run: https://github.com/pronii/novel-voice-reader/actions/runs/31102325435
- Head: `50095a6e03faa62d8f7f60fcc2c5c7139c468672`
- `flutter analyze`: passed
- `flutter test`: failed as expected, 275 passed / 1 failed
- Expected playback: `[A1, B]`
- Actual playback: `[A1, A2, B]`
- All existing tests passed; only the new continuation ownership test failed.

### Re-review Final GREEN

- Run: https://github.com/pronii/novel-voice-reader/actions/runs/31103116095
- Head: `76a8f57caf9d4109334b6a0f8770dfa00105cc54`
- Conclusion: success
- `flutter analyze`: passed
- Full `flutter test`: passed, 276 tests
- `flutter build apk --debug`: passed
- Android artifact upload: passed
- `flutter build ios --release --no-codesign`: passed
- Unsigned IPA packaging and artifact upload: passed

## Implementation

- Paragraph lookup, chapter character lookup, and segmentation now remain in
  request-local variables until the request is current and obtains serialized
  provider takeover execution.
- A private recoverable future queue serializes `prepare`, speed reapplication,
  and `play` transactions without changing `SpeechProvider` or public APIs.
- Generation checks run before a queued transaction touches the provider and
  after each awaited provider operation. A superseded request can finish its
  in-flight prepare but cannot call play afterward.
- A provider transaction error is still returned to its caller while the
  internal queue recovers, so later playback requests are not permanently
  blocked.
- Failed paragraph or chapter count replacements leave the active segments,
  cursor, timeline acceptance, and segment continuation intact.
- Existing disposal remains non-blocking with respect to an indefinitely
  pending provider `play` future, preserving runtime coordinator replacement.
- Active continuation now has an immutable epoch separate from the mutable
  request generation. Failed lookup/count does not advance it, while a ready
  takeover advances it before entering the provider queue and invalidates A.
- Segment continuation captures its owner, target segment index, and target
  segment before queueing. The queued transaction validates ownership before
  changing the index and after every provider await, so stale A may finish an
  in-flight prepare but cannot play or mutate B state.
- Automatic paragraph continuation reuses its immutable owner rather than
  creating a newer request generation, preserving explicit latest-request-wins
  ordering. Prefetch queueing and execution use the same owner checks.

## Verification And Review

The local Windows environment has no `dart` or `flutter` executable on PATH.
Executable Flutter evidence therefore comes from the repository's pinned
Flutter 3.44.8 GitHub Actions workflow. Local verification confirmed
`git diff --check` success, the expected RED-before-production commit order,
the scoped file allowlist, and a clean worktree before creating this report.

A read-only self-review of `ce41eda..76a8f57` against both final-review briefs
found no Critical or Important issues. It specifically checked provider error
recovery, latest-request generation gates, immutable continuation ownership,
captured segment/index targets, failed lookup/count state retention, normal
segment and paragraph continuation, prefetch behavior, speed reapplication,
and the existing dispose/replacement contract. No UI, workflow, or provider API
changed, and no brief-excluded Minor work was included.
