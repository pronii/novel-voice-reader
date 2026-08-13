# Tencent Cloud TTS and Local Quota Design

## Scope

Add Tencent Cloud Text-to-Speech as a first-class speech provider on Android
and iOS. Users supply their own Tencent Cloud `SecretId` and `SecretKey`, select
a common voice or enter a numeric `VoiceType`, verify connectivity, and use the
provider for reading and download-cache synthesis.

The Tencent Cloud TTS API does not expose an endpoint that reports the exact
remaining free resource package. The app therefore shows an explicitly
labelled local estimate based only on successful Tencent requests initiated by
this installation. It must never present the estimate as Tencent Cloud's
authoritative account balance.

## Integration Approach

The Flutter app calls Tencent Cloud's synchronous `TextToVoice` REST API
directly. A small provider-specific client implements `TC3-HMAC-SHA256`
signing with the existing `crypto` and `dio` dependencies. This keeps Android
and iOS on one implementation and avoids a separately deployed proxy service.

Requests use these fixed service values:

- endpoint: `https://tts.tencentcloudapi.com`
- service: `tts`
- action: `TextToVoice`
- API version: `2019-08-23`
- `ModelType`: `1`
- `PrimaryLanguage`: `1`
- `SampleRate`: `16000`
- `Codec`: `mp3`

The selected `VoiceType`, mapped speed, and generated unique `SessionId` are
supplied per request. The existing UI continues to display a speed multiplier.
For Tencent, multipliers are mapped piecewise through Tencent's documented
speed points (`0.6x/-2`, `0.8x/-1`, `1.0x/0`, `1.2x/1`, `1.5x/2`) and clamped
outside that effective range. The app requests one text segment at a time.
Tencent segments are limited to at most 150 Unicode code points so Chinese
input stays within the synchronous API limit. Existing providers keep their
current segmentation behavior.

## Components and Boundaries

`VoiceProfile` gains a `tencent` provider and factory. The generic `voice`
field stores the validated positive numeric `VoiceType` as a canonical decimal
string so existing profile persistence and cache keys remain compatible. The
factory uses voice `1001`, MP3 output, and the Tencent endpoint by default.

`TencentTc3Signer` is a pure component that produces the authorization value
from credentials, request body, host, service, and timestamp. It has no network
or storage dependency, allowing deterministic tests against a fixed timestamp
and request vector.

`TencentTtsClient` implements the existing `CloudSpeechSynthesizer` contract.
It reads both credentials, signs and sends the request, validates the response,
decodes `Response.Audio` from Base64, and returns MP3 bytes. The existing
`AudioCacheRepository` remains responsible for file validation and persistence.

`TencentTtsUsageRepository` records successful cloud consumption by calendar
month in the local Drift database. A row contains the `yyyy-MM` period, used
character count, user-entered monthly free quota, and update timestamp. A new
month starts at zero usage and carries forward the latest configured quota.
Old rows may remain for reliable rollover, but this feature only displays the
current month.

The current settings callbacks accept one optional API key. They will be
replaced by a provider-aware credentials value so Tencent's two independent
fields cannot be concatenated into one opaque string. Other providers retain
their current single-key behavior through the same value object.

## Credential Security

`SecretId` and `SecretKey` use separate keys in `FlutterSecureStorage`, backed
by iOS Keychain and Android Keystore-supported storage. They never enter Drift,
`VoiceProfile`, cache keys, error messages, or logs. Inputs are obscured by
default and can be cleared independently.

Direct mobile integration cannot make a cloud secret extraction-proof on a
compromised device. The settings UI will advise using a dedicated Tencent Cloud
sub-account with only the minimum TTS permission. This release does not add a
backend credential proxy.

## Settings Experience

The speech-provider segmented control adds `腾讯云`. Its settings section
contains:

- obscured `SecretId` and `SecretKey` fields;
- a common-voice dropdown, including the recommended `1001` voice;
- a custom numeric `VoiceType` entry option;
- the existing speed control;
- a `测试连接` button;
- a monthly free-quota character input;
- a compact quota status row showing current-month used characters, estimated
  remaining characters, configured total, last local update time, and refresh.

When no monthly quota is configured, the row shows `尚未设置月度额度` and the
used count. When used characters exceed the configured quota, remaining is
clamped to zero and the overage is shown separately. Every numeric balance is
labelled `本机估算`; refresh reloads and recalculates local data only.

Testing the connection synthesizes the two-character text `测试` using the
currently entered credentials, voice, and speed. Valid audio is discarded and
not cached. A successful test counts two characters because Tencent processed
the request. Testing neither saves credentials nor changes the active voice
profile; users still press `保存` to persist settings.

## Usage Accounting

The local counter is incremented only after `TextToVoice` returns a successful
response with non-empty, decodable audio. Counting uses the request text's
Unicode code-point length. Because the Tencent client runs only after an audio
cache miss, normal cache hits do not add usage. Download-cache synthesis and
connection tests do add usage when their Tencent requests succeed.

Deleting a book, deleting cached audio, retrying playback from an existing
cache file, or receiving a failed response does not reduce or increase the
counter. The repository performs an atomic increment to avoid lost updates
when background caching and foreground playback complete concurrently.

The estimate excludes requests made from Tencent Cloud Console, other apps,
other devices, or usage removed or adjusted by Tencent. It also cannot account
for Tencent billing delays or policy changes. The UI communicates this
limitation and provides no misleading official-balance claim.

## Errors and Resilience

The Tencent client maps common response classes to concise Chinese failures:

- missing credentials: prompt for both fields;
- authentication or signature failure: credentials invalid or unauthorized;
- permission denial: the sub-account lacks TTS access;
- unsupported `VoiceType` or invalid request: check the selected voice;
- rate limiting: request frequency is too high and should be retried later;
- Tencent server failure, timeout, or connection failure: service or network
  is temporarily unavailable;
- missing or invalid Base64 audio: the service returned invalid audio.

Server `RequestId` may be retained in a sanitized diagnostic message, but
credentials, authorization headers, request signatures, input text, and raw
response bodies are excluded. Usage persistence happens after valid synthesis.
If local accounting fails, playable audio is still returned and the estimate
may undercount; paid synthesis is not discarded solely because local tracking
failed.

## Persistence and Migration

The Drift schema version increments and adds the monthly Tencent usage table
without modifying existing book, progress, cache, or voice rows. Existing
installations migrate in place. Provider mapping recognizes `tencent`; unknown
legacy provider values retain the existing defensive fallback behavior.

Saving Tencent settings persists the non-secret voice profile and quota plus
both secrets. Clearing either credential removes only that secure-storage
entry. Switching providers does not delete Tencent settings, allowing users to
switch back without reconfiguration.

## Verification

Unit tests cover the fixed-time TC3 signature vector, canonical headers and
payload hash, request fields, response Base64 decoding, sanitized Tencent error
mapping, missing credentials, invalid audio, and the 150-code-point Tencent
segment limit.

Repository tests cover atomic successful increments, no increment on failed
synthesis, cache-hit exclusion, connection-test accounting, month rollover,
quota carry-forward, zero-clamped remaining values, and overage. Secure-storage
tests verify separate credential keys and deletion behavior.

Widget and routing tests cover the Tencent provider segment, common/custom
voice selection, numeric validation, obscured credentials, empty-field
validation, connection-test busy state and messages, local-estimate labels,
quota refresh, and saving the provider-aware credential object. Profile mapping
and factory tests verify persistence and cached-provider construction.

Flutter analysis and the complete test suite must pass. Android APK and the
unsigned iOS IPA for ESign are rebuilt only after the implementation passes
verification.

## Out of Scope

This change does not query or claim to know Tencent Cloud's authoritative free
resource-package balance, synchronize usage across devices, add a backend
proxy, manage Tencent sub-accounts or IAM policies, purchase resource packs,
or change the behavior of System, compatible cloud, Azure, or Zhipu providers.
