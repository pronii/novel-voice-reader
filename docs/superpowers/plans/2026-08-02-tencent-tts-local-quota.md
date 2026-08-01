# Tencent Cloud TTS and Local Quota Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add direct Tencent Cloud TTS playback with secure user credentials, connection testing, configurable voices, and an explicitly local estimate of monthly free characters.

**Architecture:** A pure TC3 signer feeds a Tencent-specific `CloudSpeechSynthesizer`; successful uncached requests atomically update a Drift monthly-usage row. Provider-aware settings values carry Tencent's two credentials without placing secrets in profiles or the database, while the existing cache and playback abstractions remain unchanged.

**Tech Stack:** Flutter/Dart, Dio, crypto, Drift SQLite, flutter_secure_storage, flutter_test, mocktail

## Global Constraints

- Call `https://tts.tencentcloudapi.com` action `TextToVoice`, API version `2019-08-23`, service `tts`.
- Use `ModelType=1`, `PrimaryLanguage=1`, `SampleRate=16000`, and `Codec=mp3`.
- Tencent segments contain at most 150 Unicode code points.
- Default `VoiceType` is `1001`; custom voices must be positive integers.
- Store `SecretId` and `SecretKey` separately in secure storage and never expose them in errors, logs, profiles, cache keys, or Drift.
- Usage is a `本机估算` only and counts successful Tencent synthesis after cache misses plus successful connection tests.
- Do not change System, compatible cloud, Azure, or Zhipu behavior.
- Flutter analysis and the complete test suite must pass before packaging.

---

### Task 1: Tencent Profile, Credentials, and Segment Limit

**Files:**
- Create: `lib/features/speech/domain/speech_credentials_input.dart`
- Modify: `lib/features/speech/domain/voice_profile.dart`
- Modify: `lib/core/storage/secure_credentials.dart`
- Modify: `lib/features/playback/domain/playback_coordinator.dart`
- Modify: `lib/features/downloads/data/download_plan_store.dart`
- Test: `test/features/speech/voice_profile_test.dart`
- Test: `test/features/speech/speech_credentials_input_test.dart`
- Test: `test/core/storage/secure_credentials_test.dart`
- Test: `test/features/playback/playback_coordinator_test.dart`
- Test: `test/features/downloads/drift_download_plan_store_test.dart`

**Interfaces:**
- Produces: `SpeechProviderType.tencent`, `VoiceProfile.tencent({int voiceType = 1001, double speed = 1})`, `VoiceProfile.maxSegmentCharacters`.
- Produces: `SpeechCredentialsInput({String? apiKey, String? secretId, String? secretKey})` with trimmed values.
- Produces: `SecureCredentials.read/write/deleteTencentSecretId()` and matching `SecretKey` methods.

- [ ] **Step 1: Write failing domain and secure-storage tests**

```dart
test('builds the fixed Tencent profile and segment limit', () {
  final profile = VoiceProfile.tencent(voiceType: 1001, speed: 1.2);
  expect(profile.providerType, SpeechProviderType.tencent);
  expect(profile.normalizedBaseUrl, 'https://tts.tencentcloudapi.com');
  expect(profile.voice, '1001');
  expect(profile.outputFormat, 'mp3');
  expect(profile.maxSegmentCharacters, 150);
});

test('Tencent credentials use separate secure values', () async {
  await credentials.writeTencentSecretId(' id ');
  await credentials.writeTencentSecretKey(' key ');
  expect(await credentials.readTencentSecretId(), 'id');
  expect(await credentials.readTencentSecretKey(), 'key');
});
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `flutter test test/features/speech/voice_profile_test.dart test/core/storage/secure_credentials_test.dart`

Expected: compilation fails because Tencent APIs do not exist.

- [ ] **Step 3: Implement the minimal domain and credential APIs**

```dart
enum SpeechProviderType { system, cloud, azure, zhipu, tencent }

factory VoiceProfile.tencent({int voiceType = 1001, double speed = 1}) {
  if (voiceType <= 0) throw ArgumentError.value(voiceType, 'voiceType');
  _validateSpeed(speed);
  return VoiceProfile._(
    providerType: SpeechProviderType.tencent,
    baseUrl: 'https://tts.tencentcloudapi.com',
    model: '1',
    voice: '$voiceType',
    speed: speed,
    outputFormat: 'mp3',
  );
}

int get maxSegmentCharacters =>
    providerType == SpeechProviderType.tencent ? 150 : 1000;
```

Use `profile.maxSegmentCharacters` in both playback and download-plan splitting. Implement the immutable provider-aware credentials value and the two secure-storage keys.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `flutter test test/features/speech/voice_profile_test.dart test/features/speech/speech_credentials_input_test.dart test/core/storage/secure_credentials_test.dart test/features/playback/playback_coordinator_test.dart test/features/downloads/drift_download_plan_store_test.dart`

Expected: all pass and existing provider segmentation remains 1000.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/speech/domain lib/core/storage/secure_credentials.dart lib/features/playback/domain/playback_coordinator.dart lib/features/downloads/data/download_plan_store.dart test
git commit -m "feat: add Tencent speech profile and credentials"
```

### Task 2: Monthly Local Usage Persistence

**Files:**
- Create: `lib/features/speech/data/tencent_tts_usage_repository.dart`
- Modify: `lib/core/storage/app_database.dart`
- Regenerate: `lib/core/storage/app_database.g.dart`
- Test: `test/features/speech/tencent_tts_usage_repository_test.dart`
- Test: `test/core/storage/app_database_test.dart`

**Interfaces:**
- Produces: `TencentTtsUsageSnapshot(period, usedCharacters, quotaCharacters, updatedAt)` with `remainingCharacters`, `overageCharacters`, and `isQuotaConfigured`.
- Produces: `TencentTtsUsageCounter.addSuccessfulCharacters(int count)`.
- Produces: `TencentTtsUsageRepository.current()`, `setMonthlyQuota(int?)`, and atomic counter implementation.

- [ ] **Step 1: Write failing repository tests**

```dart
test('increments current month atomically and computes remaining', () async {
  final repository = TencentTtsUsageRepository(database, clock: () => DateTime(2026, 8, 2));
  await Future.wait([repository.addSuccessfulCharacters(10), repository.addSuccessfulCharacters(15)]);
  await repository.setMonthlyQuota(100);
  final usage = await repository.current();
  expect(usage.usedCharacters, 25);
  expect(usage.remainingCharacters, 75);
  expect(usage.overageCharacters, 0);
});
```

Add cases for no configured quota, failed/zero input rejection, month rollover, quota carry-forward, and overage clamping.

- [ ] **Step 2: Run the repository test and verify RED**

Run: `flutter test test/features/speech/tencent_tts_usage_repository_test.dart`

Expected: compilation fails because the table and repository do not exist.

- [ ] **Step 3: Add the Drift table, migration, and repository**

```dart
@DataClassName('TencentTtsMonthlyUsageRecord')
class TencentTtsMonthlyUsages extends Table {
  TextColumn get period => text()();
  IntColumn get usedCharacters => integer().withDefault(const Constant(0))();
  IntColumn get quotaCharacters => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {period};
}
```

Increment with one SQL upsert inside a transaction. Set schema version to 2 and create the new table in `onUpgrade` when upgrading from version 1. Carry forward only the latest non-null quota into a newly created month.

- [ ] **Step 4: Regenerate Drift and run focused tests**

Run: `dart run build_runner build --delete-conflicting-outputs`

Run: `flutter test test/features/speech/tencent_tts_usage_repository_test.dart test/core/storage/app_database_test.dart`

Expected: all pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/core/storage/app_database.dart lib/core/storage/app_database.g.dart lib/features/speech/data/tencent_tts_usage_repository.dart test/features/speech/tencent_tts_usage_repository_test.dart test/core/storage/app_database_test.dart
git commit -m "feat: track local Tencent TTS usage"
```

### Task 3: Deterministic TC3 Signing

**Files:**
- Create: `lib/features/speech/data/tencent_tc3_signer.dart`
- Test: `test/features/speech/tencent_tc3_signer_test.dart`

**Interfaces:**
- Produces: `TencentTc3Signature(authorization, timestamp, host, payload)`.
- Produces: `TencentTc3Signer.sign({required String secretId, required String secretKey, required String payload, required DateTime now})`.

- [ ] **Step 1: Add a fixed-time signing test**

Use Tencent Cloud's TC3 example credentials, fixed UTC timestamp, canonical host `tts.tencentcloudapi.com`, canonical headers `content-type;host`, and a fixed JSON payload. Assert payload SHA-256, credential scope, signed headers, and the exact authorization string calculated independently from the documented four-step algorithm.

- [ ] **Step 2: Run the signer test and verify RED**

Run: `flutter test test/features/speech/tencent_tc3_signer_test.dart`

Expected: compilation fails because `TencentTc3Signer` is missing.

- [ ] **Step 3: Implement canonical request and HMAC chain**

```dart
final canonicalRequest = [
  'POST', '/', '',
  'content-type:application/json; charset=utf-8\nhost:tts.tencentcloudapi.com\n',
  'content-type;host', sha256Hex(payload),
].join('\n');
final date = utcDate(now);
final scope = '$date/tts/tc3_request';
final secretDate = hmac('TC3$secretKey', date);
final secretService = hmacBytes(secretDate, 'tts');
final secretSigning = hmacBytes(secretService, 'tc3_request');
```

Generate lowercase hexadecimal hashes and avoid storing credentials on the result object.

- [ ] **Step 4: Run signer tests and verify GREEN**

Run: `flutter test test/features/speech/tencent_tc3_signer_test.dart`

Expected: all pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/speech/data/tencent_tc3_signer.dart test/features/speech/tencent_tc3_signer_test.dart
git commit -m "feat: sign Tencent Cloud TC3 requests"
```

### Task 4: Tencent TextToVoice Client

**Files:**
- Create: `lib/features/speech/data/tencent_tts_client.dart`
- Test: `test/features/speech/tencent_tts_client_test.dart`

**Interfaces:**
- Consumes: `SecureCredentials`, `TencentTc3Signer`, `TencentTtsUsageCounter`, `VoiceProfile.tencent`.
- Produces: `TencentTtsClient implements CloudSpeechSynthesizer`.
- Produces: `testConnection({required SpeechCredentialsInput credentials, required VoiceProfile profile})`.

- [ ] **Step 1: Write failing request, response, and error tests**

Assert exact endpoint and headers `Authorization`, `Content-Type`, `Host`, `X-TC-Action`, `X-TC-Timestamp`, `X-TC-Version`; assert required JSON fields and unique `SessionId`; decode a Base64 MP3 fixture; count Unicode code points after success. Add cases for missing secure credentials, Tencent error codes, timeout, invalid Base64, empty audio, and a usage-store failure that does not discard valid audio.

- [ ] **Step 2: Run the client test and verify RED**

Run: `flutter test test/features/speech/tencent_tts_client_test.dart`

Expected: compilation fails because `TencentTtsClient` is missing.

- [ ] **Step 3: Implement TextToVoice and sanitized failures**

```dart
final body = jsonEncode({
  'Text': segment.text,
  'SessionId': sessionId(),
  'VoiceType': int.parse(profile.voice!),
  'ModelType': 1,
  'PrimaryLanguage': 1,
  'SampleRate': 16000,
  'Codec': 'mp3',
  'Speed': TencentSpeedMapper.fromMultiplier(profile.speed),
  'Volume': 0,
});
```

Post with `dio`, inspect `Response.Error` before audio, Base64-decode `Response.Audio`, then best-effort increment `segment.text.runes.length`. Map authentication, authorization, voice/parameter, rate-limit, timeout/network, service, and malformed-audio cases to fixed Chinese `AppFailure` messages. Never include raw errors, request bodies, or secrets.

- [ ] **Step 4: Run client tests and verify GREEN**

Run: `flutter test test/features/speech/tencent_tts_client_test.dart`

Expected: all pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/speech/data/tencent_tts_client.dart test/features/speech/tencent_tts_client_test.dart
git commit -m "feat: synthesize speech with Tencent Cloud"
```

### Task 5: Provider Factory, Persistence Mapping, and Cache Accounting

**Files:**
- Modify: `lib/features/speech/data/speech_provider_factory.dart`
- Modify: `lib/app/providers.dart`
- Modify: `lib/app/router.dart`
- Test: `test/features/speech/speech_provider_factory_test.dart`
- Test: `test/app/voice_profile_mapping_test.dart`
- Test: `test/features/downloads/audio_cache_repository_test.dart`

**Interfaces:**
- Consumes: `TencentTtsUsageCounter` supplied to `SpeechProviderFactory`.
- Produces: cached Tencent provider routing and safe stored-profile reconstruction.

- [ ] **Step 1: Add failing factory and mapping tests**

```dart
test('creates cached Tencent playback', () async {
  final provider = factory.create(VoiceProfile.tencent());
  expect((provider as CachedAudioSpeechProvider).cache.synthesizer, isA<TencentTtsClient>());
});
```

Add a stored `providerType: 'tencent'` mapping test and an invalid voice fallback test. Extend cache tests to prove a second `obtain` does not invoke the synthesizer/counter path.

- [ ] **Step 2: Run focused tests and verify RED**

Run: `flutter test test/features/speech/speech_provider_factory_test.dart test/app/voice_profile_mapping_test.dart test/features/downloads/audio_cache_repository_test.dart`

Expected: Tencent cases fail.

- [ ] **Step 3: Wire the factory and profile mapping**

Add the Tencent switch arm, construct `TencentTtsClient`, and pass `TencentTtsUsageRepository(database)` from reader routing. Parse the stored voice as an integer inside a guarded helper so corrupt values fall back to System.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `flutter test test/features/speech/speech_provider_factory_test.dart test/app/voice_profile_mapping_test.dart test/features/downloads/audio_cache_repository_test.dart`

Expected: all pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/speech/data/speech_provider_factory.dart lib/app/providers.dart lib/app/router.dart test/features/speech/speech_provider_factory_test.dart test/app/voice_profile_mapping_test.dart test/features/downloads/audio_cache_repository_test.dart
git commit -m "feat: route Tencent speech through audio cache"
```

### Task 6: Tencent Settings and Local Estimate Status

**Files:**
- Modify: `lib/features/speech/presentation/voice_settings_page.dart`
- Modify: `lib/app/router.dart`
- Test: `test/features/speech/voice_settings_page_test.dart`
- Test: `test/app/navigation_test.dart`

**Interfaces:**
- Produces: `VoiceSettingsSubmission(profile, credentials, monthlyQuotaCharacters)`.
- Consumes: `onTestConnection`, `onSave`, and `onLoadTencentUsage` provider-aware callbacks.

- [ ] **Step 1: Add failing Tencent settings widget tests**

Cover the horizontally scrollable `腾讯云` segment on a 320-pixel phone, hidden Secret fields, independent clear buttons, `1001` default, common/custom numeric voice selection, empty/invalid credential validation, trimmed two-field save submission, connection-test busy state, successful test message, sanitized failure, and no implicit save during testing.

Add status cases for unconfigured quota, `本机估算` used/remaining/total text, overage, updated time, and refresh invoking `onLoadTencentUsage` exactly once more.

- [ ] **Step 2: Run widget tests and verify RED**

Run: `flutter test test/features/speech/voice_settings_page_test.dart test/app/navigation_test.dart`

Expected: Tencent UI cases fail.

- [ ] **Step 3: Implement the settings section and route callbacks**

Add provider-aware callbacks while preserving current provider behavior. Use `DropdownButtonFormField` for common voice IDs plus `自定义`, a numeric `TextField` for custom `VoiceType`, obscured credential fields with independent clear icon buttons, an outlined connection button, and an unframed compact usage section with an icon refresh button and tooltip.

The route creates one secure-credential store and usage repository per action, uses entered Tencent credentials for the real `测试` synthesis, persists secrets only on Save, persists quota, and inserts the non-secret voice profile.

- [ ] **Step 4: Run widget and routing tests and verify GREEN**

Run: `flutter test test/features/speech/voice_settings_page_test.dart test/app/navigation_test.dart`

Expected: all pass at narrow and normal viewports with no overflow.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/speech/presentation/voice_settings_page.dart lib/app/router.dart test/features/speech/voice_settings_page_test.dart test/app/navigation_test.dart
git commit -m "feat: configure Tencent TTS and show local quota"
```

### Task 7: Full Verification and Packages

**Files:**
- Modify only files required by formatter, analyzer, or regression fixes exposed by verification.
- Output: Android APK and unsigned iOS IPA through the existing workflows.

- [ ] **Step 1: Format and verify generated code is current**

Run: `dart format lib test`

Run: `dart run build_runner build --delete-conflicting-outputs`

Expected: formatter succeeds and build runner reports success.

- [ ] **Step 2: Run static analysis and the complete test suite**

Run: `flutter analyze`

Run: `flutter test`

Expected: zero analyzer issues and all tests pass.

- [ ] **Step 3: Build mobile artifacts through existing repository workflows**

Run the existing Android APK workflow locally when the Android toolchain is available. Trigger or verify the existing GitHub Actions unsigned iOS IPA workflow because Windows cannot run Xcode. Record artifact names and checksums without adding credentials to the repository.

- [ ] **Step 4: Review the final diff for secret leakage and scope**

Run: `rg -n "SecretId|SecretKey|Authorization" lib test` and inspect every match.

Run: `git diff --check origin/feature/flutter-mvp...HEAD`

Expected: secrets appear only as field names/test fixtures, no literal production credentials, and no whitespace errors.

- [ ] **Step 5: Commit any verification-only fixes and push**

```powershell
git status --short
git push origin feature/flutter-mvp
```

Expected: clean worktree and the remote branch contains all Tencent TTS commits.
