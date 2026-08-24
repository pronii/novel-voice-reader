# Manual Seek Latency Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce custom-cloud manual seek latency by front-loading job polling and warming the first target segment on the first tap of a scroll-mode double tap.

**Architecture:** `ReaderPage` reports a best-effort warm-up intent without changing selection or playback state. A focused `ManualSeekPrewarmer` resolves the active custom-cloud profile, builds the exact first `SpeechSegment`, and warms the process-wide `AudioCacheRuntime`; confirmed playback then joins that runtime's existing in-flight request. `ServerTtsClient` keeps an immediate first status check and uses a 150/250/500 ms backoff for pending jobs.

**Tech Stack:** Flutter 3.44.8, Dart, Riverpod, Drift, Dio, flutter_test, GitHub Actions.

## Global Constraints

- Only custom cloud (`SpeechProviderType.server`) receives speculative warm-up.
- Preserve the existing `chapterId + paragraphIndex` playback cursor.
- Warm-up must not play audio, update the cursor, select a paragraph, or show a paragraph highlight.
- Late or failed warm-up work may only affect the audio cache.
- Do not include novel text, service URLs, or credentials in telemetry.
- Do not change automatic next-segment prefetch, global segment sizes, or the server API.
- Do not run local validation; push the implementation branch and use GitHub Actions CI.

---

## File Structure

- Create `lib/features/playback/application/manual_seek_prewarmer.dart`: turn a reader paragraph into its first speech segment and perform best-effort custom-cloud cache warm-up with diagnostic timing.
- Create `test/features/playback/manual_seek_prewarmer_test.dart`: unit coverage for server-only warm-up, stable segment identity, failure isolation, and safe telemetry.
- Modify `lib/features/speech/data/server_tts_client.dart`: replace the fixed pending-job delay with a bounded front-loaded schedule.
- Modify `test/features/speech/server_tts_client_test.dart`: capture and assert pending-job delay order and completion behavior.
- Modify `lib/features/reader/presentation/reader_page.dart`: expose `onWarmFrom` and notify it only on the first eligible scroll-mode paragraph tap.
- Modify `test/features/reader/reader_page_test.dart`: verify first-tap notification, double-tap playback, cross-paragraph behavior, and no highlight regression.
- Modify `lib/app/router.dart`: wire the warm-up intent to the process-wide cache runtime and existing active-profile/telemetry dependencies.
- Modify `test/features/downloads/audio_cache_runtime_test.dart`: prove concurrent warm-up and confirmed obtain calls share one synthesis operation.

### Task 1: Front-Loaded Custom Cloud Polling

**Files:**
- Modify: `test/features/speech/server_tts_client_test.dart`
- Modify: `lib/features/speech/data/server_tts_client.dart`

**Interfaces:**
- Consumes: existing `ServerTtsDelay = Future<void> Function(Duration duration)`.
- Produces: `ServerTtsClient.pollIntervals`, a non-empty `List<Duration>` defaulting to 150 ms, 250 ms, and 500 ms; delays after later pending responses reuse the last entry.

- [ ] **Step 1: Write the failing polling schedule test**

Extend `_ServerAdapter` with `int runningResponsesRemaining`, decrement it for each job-status response, and return `running` until it reaches zero. Add:

```dart
test('front-loads pending job polls before settling at 500 ms', () async {
  final delays = <Duration>[];
  final adapter = _ServerAdapter()..runningResponsesRemaining = 3;
  final client = ServerTtsClient(
    dio: Dio()..httpClientAdapter = adapter,
    credentials: SecureCredentials(_Store('secret')),
    delay: (duration) async => delays.add(duration),
  );
  const segment = SpeechSegment(
    id: '1:0',
    paragraphId: 1,
    text: '正文',
    partIndex: 0,
  );
  final profile = VoiceProfile.server(
    baseUrl: 'https://tts.example.com',
    model: 'tts-model',
    voice: 'voice-a',
    speed: 1,
  );

  await client.synthesize(segment, profile);

  expect(delays, const [
    Duration(milliseconds: 150),
    Duration(milliseconds: 250),
    Duration(milliseconds: 500),
  ]);
});
```

Keep the existing immediate-completion test and assert that it records no delay.

- [ ] **Step 2: Push the failing test and verify RED in CI**

```powershell
git add test/features/speech/server_tts_client_test.dart
git commit -m "test(speech): cover front-loaded server polling"
git push -u origin codex/manual-seek-latency
gh run list --branch codex/manual-seek-latency --workflow ci.yml --limit 1
$runId = gh run list --branch codex/manual-seek-latency --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId'
gh run watch $runId --exit-status
```

Expected: `test-android` fails because `ServerTtsClient` still records 750 ms delays.

- [ ] **Step 3: Implement the minimal polling schedule**

Change the constructor and fields to:

```dart
ServerTtsClient({
  required this.dio,
  required this.credentials,
  ServerTtsDelay? delay,
  this.pollIntervals = const [
    Duration(milliseconds: 150),
    Duration(milliseconds: 250),
    Duration(milliseconds: 500),
  ],
  this.maxPolls = 360,
}) : assert(maxPolls > 0),
     assert(pollIntervals.isNotEmpty),
     assert(pollIntervals.every((interval) => interval > Duration.zero)),
     _delay = delay ?? Future<void>.delayed;

final List<Duration> pollIntervals;

Duration _pollDelay(int poll) {
  final index = poll < pollIntervals.length ? poll : pollIntervals.length - 1;
  return pollIntervals[index];
}
```

After each non-terminal status response, call `await _delay(_pollDelay(poll));`. The default 360 polls keep the prior approximately three-minute timeout budget after the steady interval becomes 500 ms.

- [ ] **Step 4: Push the implementation and verify GREEN in CI**

```powershell
git add lib/features/speech/data/server_tts_client.dart
git commit -m "perf(speech): poll new server jobs sooner"
git push
gh run list --branch codex/manual-seek-latency --workflow ci.yml --limit 1
$runId = gh run list --branch codex/manual-seek-latency --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId'
gh run watch $runId --exit-status
```

Expected: `test-android` completes successfully, including `flutter analyze` and `flutter test`.

### Task 2: Best-Effort Manual Seek Prewarmer

**Files:**
- Create: `test/features/playback/manual_seek_prewarmer_test.dart`
- Create: `lib/features/playback/application/manual_seek_prewarmer.dart`

**Interfaces:**
- Consumes: `ReaderParagraph`, `VoiceProfile`, `SpeechSegmenter`, `PlaybackTelemetry`.
- Produces: `ManualSeekPrewarmer.warm(ReaderParagraph paragraph) -> Future<void>`.
- Constructor dependencies:

```dart
typedef ManualSeekProfileLoader = Future<VoiceProfile> Function();
typedef ManualSeekSegmentWarmer =
    Future<void> Function(SpeechSegment segment, VoiceProfile profile);

ManualSeekPrewarmer({
  required ManualSeekProfileLoader loadProfile,
  required ManualSeekSegmentWarmer warmSegment,
  PlaybackTelemetry telemetry = const NoopPlaybackTelemetry(),
  SpeechSegmenter segmenter = const SpeechSegmenter(),
});
```

- [ ] **Step 1: Write failing prewarmer tests**

Use recording closures and a recording telemetry fake. Cover these exact assertions:

```dart
await prewarmer.warm(const ReaderParagraph(
  id: 42,
  chapterId: 7,
  index: 3,
  text: '第一句。第二句。',
));

expect(warmed.single.$1, const SpeechSegment(
  id: '42:0',
  paragraphId: 42,
  text: '第一句。第二句。',
  partIndex: 0,
));
expect(warmed.single.$2.providerType, SpeechProviderType.server);
```

Add separate tests proving a non-server profile never calls `warmSegment`, an empty paragraph is ignored, and a thrown warm-up error completes normally while recording only `paragraph_id`, `chapter_id`, `paragraph_index`, `elapsed_ms`, and `error_type` metadata.

- [ ] **Step 2: Push the failing tests and verify RED in CI**

```powershell
git add test/features/playback/manual_seek_prewarmer_test.dart
git commit -m "test(playback): specify manual seek warm-up"
git push
gh run list --branch codex/manual-seek-latency --workflow ci.yml --limit 1
$runId = gh run list --branch codex/manual-seek-latency --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId'
gh run watch $runId --exit-status
```

Expected: compilation fails because `manual_seek_prewarmer.dart` and `ManualSeekPrewarmer` do not exist.

- [ ] **Step 3: Implement the prewarmer**

`warm` loads the active profile, exits unless its provider is `server`, splits with `profile.maxSegmentCharacters`, exits when there is no segment, then awaits only the first segment. Wrap the whole operation in `try/catch`; record `playback.manual_seek.warm.begin`, `.success`, `.failure`, or `.skipped`, and never rethrow:

```dart
Future<void> warm(ReaderParagraph paragraph) async {
  final startedAt = Stopwatch()..start();
  _record('playback.manual_seek.warm.begin', paragraph);
  try {
    final profile = await _loadProfile();
    if (profile.providerType != SpeechProviderType.server) {
      _record('playback.manual_seek.warm.skipped', paragraph, {
        'reason': 'provider_not_server',
      });
      return;
    }
    final segments = _segmenter.split(
      paragraphId: paragraph.id,
      text: paragraph.text,
      maxCharacters: profile.maxSegmentCharacters,
    );
    if (segments.isEmpty) return;
    await _warmSegment(segments.first, profile);
    _record('playback.manual_seek.warm.success', paragraph, {
      'elapsed_ms': startedAt.elapsedMilliseconds,
    });
  } catch (error) {
    _record('playback.manual_seek.warm.failure', paragraph, {
      'elapsed_ms': startedAt.elapsedMilliseconds,
      'error_type': error.runtimeType.toString(),
    });
  }
}
```

The `_record` helper adds only numeric cursor/paragraph identifiers; it must never add `paragraph.text`, a base URL, or credentials.

- [ ] **Step 4: Push and verify GREEN in CI**

```powershell
git add lib/features/playback/application/manual_seek_prewarmer.dart
git commit -m "feat(playback): add safe manual seek prewarmer"
git push
gh run list --branch codex/manual-seek-latency --workflow ci.yml --limit 1
$runId = gh run list --branch codex/manual-seek-latency --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId'
gh run watch $runId --exit-status
```

Expected: `test-android` completes successfully.

### Task 3: First-Tap Wiring and In-Flight Reuse

**Files:**
- Modify: `test/features/reader/reader_page_test.dart`
- Modify: `lib/features/reader/presentation/reader_page.dart`
- Modify: `test/features/downloads/audio_cache_runtime_test.dart`
- Modify: `lib/app/router.dart`

**Interfaces:**
- Consumes: `ManualSeekPrewarmer.warm`, `AudioCacheRuntime.obtain`, the existing `onPlayFrom` callback.
- Produces: optional `ReaderPage.onWarmFrom: ValueChanged<ReaderParagraph>?`.

- [ ] **Step 1: Write failing first-tap widget tests**

Extend the `_reader` test helper with `ValueChanged<ReaderParagraph>? onWarmFrom`. Add a test that taps paragraph 101 once and asserts:

```dart
expect(warmed, [same(paragraphs[1])]);
expect(played, isEmpty);
expect(find.byKey(const ValueKey('active-paragraph-101')), findsNothing);
```

Tap the same paragraph a second time within `kDoubleTapTimeout` and assert there is still exactly one warm callback and exactly one play callback. Add a cross-paragraph case proving each first tap warms its own paragraph but does not play.

- [ ] **Step 2: Push the widget tests and verify RED in CI**

```powershell
git add test/features/reader/reader_page_test.dart
git commit -m "test(reader): cover first-tap seek warm-up"
git push
gh run list --branch codex/manual-seek-latency --workflow ci.yml --limit 1
$runId = gh run list --branch codex/manual-seek-latency --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId'
gh run watch $runId --exit-status
```

Expected: compilation fails because `ReaderPage.onWarmFrom` does not exist.

- [ ] **Step 3: Add the reader callback without visual state changes**

Add `onWarmFrom` to the constructor and fields. In `_handleParagraphTap`, only after determining the tap is not a double tap, invoke:

```dart
if (_pageMode == ReaderPageMode.scroll && now != null) {
  widget.onWarmFrom?.call(paragraph);
}
```

Then retain `_selectParagraph(paragraph)`. Do not set `_activeParagraphId`, `playbackCursor`, or `_pendingPlaybackTarget` in this path.

- [ ] **Step 4: Write the failing process-wide reuse test**

In `audio_cache_runtime_test.dart`, configure a controllable adapter whose audio response waits on a `Completer<void>`. Call `runtime.obtain` twice concurrently with the same `bookId`, segment, and profile; release the response and assert both futures resolve to the same path and the adapter saw exactly one `/v1/jobs` POST.

```dart
final warm = runtime.obtain(bookId: bookId, segment: segment, profile: profile);
await adapter.waitForJobCreation();
final confirmed = runtime.obtain(
  bookId: bookId,
  segment: segment,
  profile: profile,
);
adapter.releaseAudio();
final files = await Future.wait([warm, confirmed]);
expect(files[0].path, files[1].path);
expect(adapter.jobCreations, 1);
```

- [ ] **Step 5: Wire router warm-up to the shared runtime**

Add `_warmFrom(ReaderParagraph paragraph)` to `_ReaderRoutePageState`:

```dart
void _warmFrom(ReaderParagraph paragraph) {
  final database = ref.read(databaseProvider);
  final cacheRuntime = ref.read(audioCacheRuntimeProvider);
  if (database == null || cacheRuntime == null) return;
  final prewarmer = ManualSeekPrewarmer(
    loadProfile: () => loadActiveVoiceProfile(database),
    warmSegment: (segment, profile) => cacheRuntime.obtain(
      bookId: widget.bookId,
      segment: segment,
      profile: profile,
    ),
    telemetry: ref.read(playbackTelemetryProvider),
  );
  unawaited(prewarmer.warm(paragraph));
}
```

Pass `onWarmFrom: _warmFrom` when constructing the populated `ReaderPage`. Because `_playFrom` creates its provider with `audioCacheRuntime.forBook(widget.bookId)`, its confirmed `prepare` reaches the same process-wide `_inFlight` entry.

- [ ] **Step 6: Push the implementation and verify GREEN in CI**

```powershell
git add lib/app/router.dart lib/features/reader/presentation/reader_page.dart test/features/reader/reader_page_test.dart test/features/downloads/audio_cache_runtime_test.dart
git commit -m "perf(reader): warm manual seek targets on first tap"
git push
gh run list --branch codex/manual-seek-latency --workflow ci.yml --limit 1
$runId = gh run list --branch codex/manual-seek-latency --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId'
gh run watch $runId --exit-status
```

Expected: `test-android` completes successfully with `flutter analyze` and all tests passing.

### Task 4: Final CI and Delivery Review

**Files:**
- Modify only if CI or review identifies a defect in the files listed above.

**Interfaces:**
- Consumes: completed Tasks 1-3.
- Produces: a CI-green branch ready to merge.

- [ ] **Step 1: Inspect the complete diff**

```powershell
git diff origin/main...HEAD --check
git diff origin/main...HEAD --stat
git status --short
```

Expected: only the planned source, test, and plan files are changed; existing untracked user files remain untouched.

- [ ] **Step 2: Request code review**

Use the `requesting-code-review` skill and verify the implementation against `docs/plans/2026-08-24-manual-seek-latency-design.md`, with particular attention to duplicate synthesis, stale-result side effects, cursor/highlight regressions, and telemetry privacy.

- [ ] **Step 3: Verify the latest CI run**

```powershell
git push
gh run list --branch codex/manual-seek-latency --workflow ci.yml --limit 1
$runId = gh run list --branch codex/manual-seek-latency --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId'
gh run watch $runId --exit-status
gh run view $runId --json conclusion,url,headSha,jobs
```

Expected: conclusion `success`; the reported `headSha` equals `git rev-parse HEAD`.

- [ ] **Step 4: Commit review fixes if required**

```powershell
git add lib/app/router.dart lib/features/playback/application/manual_seek_prewarmer.dart lib/features/reader/presentation/reader_page.dart lib/features/speech/data/server_tts_client.dart test/features/downloads/audio_cache_runtime_test.dart test/features/playback/manual_seek_prewarmer_test.dart test/features/reader/reader_page_test.dart test/features/speech/server_tts_client_test.dart
git commit -m "fix(playback): address manual seek latency review"
git push
```

Then repeat Step 3 and require a successful run for the new HEAD.

---

## Self-Review

- Spec coverage: polling cadence is Task 1; server-only first-segment warm-up, failure isolation, and telemetry are Task 2; no-highlight first-tap UI behavior, stable segment identity, process-wide request reuse, and stale-result safety are Task 3; CI-only verification and review are Task 4.
- Placeholder scan: no deferred implementation, unspecified error handling, or command placeholders remain.
- Type consistency: `ManualSeekPrewarmer.warm(ReaderParagraph)` is the callback target used by router wiring; `ReaderPage.onWarmFrom` uses the same `ReaderParagraph`; `AudioCacheRuntime.obtain` receives the exact `SpeechSegment` and `VoiceProfile` later used by `CachedAudioSpeechProvider.prepare`.
