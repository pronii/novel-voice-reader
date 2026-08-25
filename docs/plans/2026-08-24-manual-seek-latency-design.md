# Manual Seek Latency Optimization Design

## Goal

Reduce the perceived delay between a manual playback seek and audible output when
using a custom cloud voice profile. Manual seeks include chapter navigation,
previous/next paragraph controls, and double-clicking body text.

The current delay is below one second. This change targets the avoidable client-side
portion of that delay without changing the server protocol or the persisted
`chapterId + paragraphIndex` playback cursor.

## Current Behavior

Each confirmed seek waits for the complete target audio preparation path:

1. resolve the target cursor;
2. submit a custom cloud synthesis job;
3. poll the job every 750 ms;
4. download the completed segment;
5. prepare the local audio source and start playback.

This introduces two avoidable delays. Work begins only after the gesture is fully
confirmed, and a completed cloud job may wait for the next fixed polling interval.

## Chosen Design

### Speculative target preparation

Navigation and body-text interactions may announce an intended target before the
final playback command. At that point, the playback layer starts preparing the
target segment through the existing cached speech provider.

The confirmed seek uses the same stable segment identity and therefore joins the
existing in-flight request instead of starting a second synthesis job. Preparation
is best-effort: cancellation, gesture changes, and preparation failures must not
alter playback state or surface an error until a confirmed seek actually needs the
result.

For double-click playback, the first click may warm the paragraph under the pointer,
but must not select or highlight the paragraph and must not move the persisted
cursor. Chapter and previous/next controls may warm the destination as soon as the
destination is known.

### Front-loaded cloud job polling

Replace the fixed 750 ms polling delay with a bounded schedule that checks quickly
after job creation and backs off while the job remains pending:

- immediate first status GET after job creation;
- 150 ms delay after the first pending response;
- 250 ms delay after the second pending response;
- 500 ms delay after subsequent pending responses;
- retain the existing overall timeout budget and terminal-state handling.

The schedule only affects custom cloud synthesis and does not change other speech
providers.

### Stale-request safety

Speculative preparation never calls play, updates the active cursor, or changes the
visible active paragraph. Existing playback generation/request guards remain the
authority for a confirmed seek. If the user changes targets, a late warm-up result
may populate the cache but cannot pull playback back to the older target.

## Error Handling

- Warm-up failures are swallowed after diagnostic recording; confirmed playback can
  retry through the normal path.
- A confirmed seek reports errors through the existing playback failure flow.
- Cloud job failure, cancellation, malformed responses, and timeout behavior remain
  unchanged apart from the polling cadence.
- Repeated warm-up and playback requests for the same segment must share one
  in-flight synthesis operation.

## Observability

Add duration telemetry around manual seek preparation with enough fields to
distinguish:

- warm-up started, joined, completed, or failed;
- confirmed seek cache/in-flight reuse;
- cloud job creation-to-ready duration;
- audio prepare-to-play duration.

Telemetry must not include novel text or credentials.

## CI Verification

Automated tests will verify:

1. the custom cloud client uses the 150/250/500 ms polling schedule;
2. a confirmed seek reuses preparation already in flight for the same segment;
3. warm-up alone does not play audio or update the playback cursor;
4. changing targets prevents an older warm-up from affecting active playback;
5. warm-up failure does not block a later confirmed seek retry;
6. existing chapter navigation and double-click playback behavior remains intact.

Per user preference, validation will run in CI rather than through a local test run.

## Non-Goals

- changing the custom cloud API;
- streaming audio before synthesis completes;
- changing the global segment size;
- altering automatic next-segment prefetch;
- adding paragraph selection or highlight behavior.
