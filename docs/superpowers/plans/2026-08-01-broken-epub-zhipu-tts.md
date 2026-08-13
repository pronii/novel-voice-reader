# Broken EPUB Import and Zhipu TTS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import the supplied EPUB despite its missing unused cover image and add first-class Zhipu GLM-TTS playback to Android and iOS.

**Architecture:** Open EPUBs through `EpubReader.openBook` and load only linear spine XHTML references, preserving the existing parser output and transactional import boundary. Model Zhipu as a distinct voice profile and secure credential, synthesize through a dedicated official-API client, and reuse the existing cached-audio playback path.

**Tech Stack:** Flutter 3.44.8, Dart 3.12, epubx, Dio, flutter_secure_storage, Drift, just_audio, flutter_test, mocktail

## Global Constraints

- Preserve System, OpenAI-compatible, and Azure provider behavior.
- Use `https://open.bigmodel.cn/api/paas/v4/audio/speech`, model `glm-tts`, and non-streaming `wav` output.
- Store the Zhipu API Key only in `flutter_secure_storage` under a provider-specific key.
- Keep speech chunks at the existing 1,000-character limit, below Zhipu's official 1,024-character maximum.
- Do not claim that GLM-TTS is permanently free.
- Do not commit the supplied copyrighted EPUB or any API key.

---

### Task 1: Lazy EPUB Spine Parsing

**Files:**
- Modify: `test/features/library/epub_book_parser_test.dart`
- Modify: `lib/features/library/data/epub_book_parser.dart`

**Interfaces:**
- Consumes: `EpubReader.openBook(List<int>)`, `EpubTextContentFileRef.readContentAsText()`
- Produces: unchanged `Future<ParsedBook> EpubBookParser.parse(Uint8List bytes, String fileName)`

- [ ] **Step 1: Write the failing missing-resource regression test**

Extend `_buildEpub` with `includeMissingImageManifestItem` and add a manifest item whose `href="images/missing-cover.jpg"` is absent from the archive. The test must call the real parser and assert both spine chapters remain readable:

```dart
test('ignores missing non-reading resources while parsing the spine', () async {
  final parsed = await const EpubBookParser().parse(
    _buildEpub(includeMissingImageManifestItem: true),
    'broken-cover.epub',
  );

  expect(parsed.title, '测试 EPUB');
  expect(parsed.chapters.map((chapter) => chapter.title), ['第二章', '第一章']);
});
```

Also add `missingSpineDocument` to make `chapter2.xhtml` absent while its
linear spine entry remains, and assert `parse` throws `FormatException`. This
distinguishes ignorable auxiliary damage from missing reading content.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
& .\tool\flutter.ps1 test test\features\library\epub_book_parser_test.dart --concurrency=1 -r expanded
```

Expected: the new test fails with an `EPUB parsing error` saying the missing image was not found.

- [ ] **Step 3: Implement lazy spine loading**

Replace eager `readBook` usage with `openBook`, keep the manifest and normalized-href lookup, and resolve content references rather than loaded content files:

```dart
final book = await EpubReader.openBook(bytes);
final htmlFiles = book.Content?.Html ?? const {};
final normalizedHtmlFiles = {
  for (final entry in htmlFiles.entries)
    _normalizeHref(entry.key): entry.value,
};
// Inside the spine loop:
final contentRef = normalizedHtmlFiles[normalizedHref] ?? /* suffix match */;
final html = await contentRef?.readContentAsText();
```

Do not read `Content.Images`, `Content.Fonts`, the cover, or the table-of-contents chapter tree.
Throw `FormatException('EPUB spine document is missing: $href')` when a linear
spine item cannot resolve to an XHTML content reference.

- [ ] **Step 4: Run EPUB tests and verify GREEN**

Run the command from Step 2. Expected: all EPUB parser tests pass.

- [ ] **Step 5: Verify the supplied file**

Run the external diagnostic fixture and assert
`title=完美世界 chapters=2004 paragraphs=186814`:

```powershell
& .\tool\flutter.ps1 test C:\Users\Administrator\Documents\Codex\2026-07-31\ru\work\repro_epub_test.dart --concurrency=1 -r expanded
```

The diagnostic test must call `EpubBookParser.parse` directly and report the
returned `ParsedBook`, not call `EpubReader.openBook` itself.

- [ ] **Step 6: Commit**

```powershell
git add test/features/library/epub_book_parser_test.dart lib/features/library/data/epub_book_parser.dart
git commit -m "fix: import EPUBs with missing unused resources"
```

### Task 2: Zhipu Profile and Secure Credential

**Files:**
- Modify: `test/features/speech/voice_profile_test.dart`
- Modify: `test/core/storage/secure_credentials_test.dart`
- Modify: `test/app/voice_profile_mapping_test.dart`
- Modify: `lib/features/speech/domain/voice_profile.dart`
- Modify: `lib/core/storage/secure_credentials.dart`
- Modify: `lib/app/providers.dart`

**Interfaces:**
- Produces: `SpeechProviderType.zhipu`
- Produces: `VoiceProfile.zhipu({String voice, double speed})`
- Produces: `SecureCredentials.readZhipuApiKey()`, `writeZhipuApiKey(String)`, and `deleteZhipuApiKey()`

- [ ] **Step 1: Write failing profile, credential, and persistence tests**

Add assertions for the exact fixed profile:

```dart
final profile = VoiceProfile.zhipu(voice: 'xiaochen', speed: 1.2);
expect(profile.providerType, SpeechProviderType.zhipu);
expect(profile.normalizedBaseUrl, 'https://open.bigmodel.cn/api/paas/v4');
expect(profile.model, 'glm-tts');
expect(profile.voice, 'xiaochen');
expect(profile.outputFormat, 'wav');
```

Test that an unsupported voice throws `ArgumentError`, that `zhipu_tts_api_key` is separate from compatible and Azure keys, and that a Drift record with `providerType: 'zhipu'` maps back to the same profile.

- [ ] **Step 2: Run the three focused test files and verify RED**

```powershell
& .\tool\flutter.ps1 test test\features\speech\voice_profile_test.dart test\core\storage\secure_credentials_test.dart test\app\voice_profile_mapping_test.dart --concurrency=1 -r expanded
```

Expected: compile failures because the Zhipu enum value, factory, and credential methods do not exist.

- [ ] **Step 3: Implement the Zhipu profile and credential**

Add constants and validation in `VoiceProfile`:

```dart
static const zhipuBaseUrl = 'https://open.bigmodel.cn/api/paas/v4';
static const zhipuModel = 'glm-tts';
static const zhipuOutputFormat = 'wav';
static const zhipuVoices = {
  'tongtong', 'chuichui', 'xiaochen', 'jam', 'kazi', 'douji', 'luodo',
};
```

Add `_zhipuApiKeyKey = 'zhipu_tts_api_key'` and provider-specific read/write/delete methods. Extend `voiceProfileFromRecord` with a guarded `zhipu` branch using stored voice/speed and the fixed official endpoint/model/format.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the command from Step 2. Expected: all tests pass.

- [ ] **Step 5: Commit**

```powershell
git add test/features/speech/voice_profile_test.dart test/core/storage/secure_credentials_test.dart test/app/voice_profile_mapping_test.dart lib/features/speech/domain/voice_profile.dart lib/core/storage/secure_credentials.dart lib/app/providers.dart
git commit -m "feat: model Zhipu voice profiles securely"
```

### Task 3: Zhipu Synthesis and Cached Playback

**Files:**
- Create: `test/features/speech/zhipu_tts_client_test.dart`
- Modify: `test/features/speech/speech_provider_factory_test.dart`
- Modify: `test/features/downloads/audio_cache_repository_test.dart`
- Create: `lib/features/speech/data/zhipu_tts_client.dart`
- Modify: `lib/features/speech/data/speech_provider_factory.dart`

**Interfaces:**
- Produces: `ZhipuTtsClient implements CloudSpeechSynthesizer`
- Consumes: `SecureCredentials.readZhipuApiKey()` and `VoiceProfile.zhipu(...)`

- [ ] **Step 1: Write failing official-request tests**

Use a recording `HttpClientAdapter` and assert:

```dart
expect(request.path, 'https://open.bigmodel.cn/api/paas/v4/audio/speech');
expect(request.headers['Authorization'], 'Bearer zhipu-secret');
expect(request.data, {
  'model': 'glm-tts',
  'input': '正文',
  'voice': 'tongtong',
  'response_format': 'wav',
  'speed': 1.0,
});
```

Also test missing credentials, empty successful audio, one 429 followed by success, three timeouts, 401 without retry, and sanitized Chinese failures.

- [ ] **Step 2: Write the failing provider-factory test**

Create `VoiceProfile.zhipu()` through `SpeechProviderFactory` and assert the returned `CachedAudioSpeechProvider.cache.synthesizer` is a `ZhipuTtsClient`.

Add a cache regression using RIFF/WAVE fixture bytes and
`VoiceProfile.zhipu()`; assert the published cache path ends in `.wav` and the
bytes are preserved.

- [ ] **Step 3: Run focused tests and verify RED**

```powershell
& .\tool\flutter.ps1 test test\features\speech\zhipu_tts_client_test.dart test\features\speech\speech_provider_factory_test.dart test\features\downloads\audio_cache_repository_test.dart --concurrency=1 -r expanded
```

Expected: compile failures because `ZhipuTtsClient` and the factory branch do not exist.

- [ ] **Step 4: Implement the minimal Zhipu client**

Mirror the compatible client's bounded retry behavior while using the provider-specific key and fixed URL:

```dart
final response = await dio.post<List<int>>(
  '${profile.normalizedBaseUrl}/audio/speech',
  data: {
    'model': profile.model,
    'input': segment.text,
    'voice': profile.voice,
    'response_format': profile.outputFormat,
    'speed': profile.speed,
  },
  options: Options(
    responseType: ResponseType.bytes,
    headers: {'Authorization': 'Bearer $apiKey'},
  ),
);
```

Reject non-Zhipu profiles and empty audio. Map 401/403, 429, timeout, connection, and other HTTP failures without returning API bodies.

- [ ] **Step 5: Wire the factory and verify GREEN**

Add `SpeechProviderType.zhipu => _cached(ZhipuTtsClient(...))`, run the command from Step 3, and expect all tests to pass.

- [ ] **Step 6: Commit**

```powershell
git add test/features/speech/zhipu_tts_client_test.dart test/features/speech/speech_provider_factory_test.dart test/features/downloads/audio_cache_repository_test.dart lib/features/speech/data/zhipu_tts_client.dart lib/features/speech/data/speech_provider_factory.dart
git commit -m "feat: synthesize and cache Zhipu speech"
```

### Task 4: Zhipu Settings and Persistence

**Files:**
- Modify: `test/features/speech/voice_settings_page_test.dart`
- Modify: `lib/features/speech/presentation/voice_settings_page.dart`
- Modify: `lib/app/router.dart`

**Interfaces:**
- Consumes: `VoiceProfile.zhipu`, `VoiceProfile.zhipuVoices`, `SecureCredentials.writeZhipuApiKey`
- Produces: settings callback `(VoiceProfile profile, String? apiKey)` with a Zhipu profile and key

- [ ] **Step 1: Write the failing settings widget test**

Tap `智谱`, select `小陈 (xiaochen)`, enter `zhipu-secret`, save, and assert:

```dart
expect(savedProfile?.providerType, SpeechProviderType.zhipu);
expect(savedProfile?.voice, 'xiaochen');
expect(savedProfile?.model, 'glm-tts');
expect(savedKey, 'zhipu-secret');
```

- [ ] **Step 2: Run the widget test and verify RED**

```powershell
& .\tool\flutter.ps1 test test\features\speech\voice_settings_page_test.dart --concurrency=1 -r expanded
```

Expected: `智谱` is not found.

- [ ] **Step 3: Implement the settings controls**

Add a fourth segmented option labeled `智谱`. In Zhipu mode show a `DropdownButtonFormField<String>` for the seven official voices and an obscured `API Key` text field. Build `VoiceProfile.zhipu(voice: selectedVoice, speed: _speed)` on save. Use a horizontally scrollable or wrapping control so four provider labels do not overflow on narrow phones.

- [ ] **Step 4: Persist the provider-specific key**

Extend the router save branch:

```dart
if (profile.providerType == SpeechProviderType.zhipu) {
  await credentials.writeZhipuApiKey(apiKey);
}
```

The existing Drift insert stores the public profile fields without a schema migration.

- [ ] **Step 5: Run widget and navigation/persistence tests and verify GREEN**

```powershell
& .\tool\flutter.ps1 test test\features\speech\voice_settings_page_test.dart test\app\voice_profile_mapping_test.dart test\app\navigation_test.dart --concurrency=1 -r expanded
```

Expected: all tests pass with no overflow exception.

- [ ] **Step 6: Commit**

```powershell
git add test/features/speech/voice_settings_page_test.dart lib/features/speech/presentation/voice_settings_page.dart lib/app/router.dart
git commit -m "feat: add Zhipu voice settings"
```

### Task 5: Full Verification and Artifacts

**Files:**
- Modify: `README.md`
- Modify: GitHub PR #1 description
- Produce: `outputs/novel-voice-reader-<sha>-debug.apk`
- Produce: `outputs/novel-voice-reader-<sha>-unsigned.ipa`

**Interfaces:**
- Consumes: all prior tasks
- Produces: pushed branch, updated PR, Android APK, unsigned iOS IPA

- [ ] **Step 1: Document user-visible support**

Add EPUB tolerance and Zhipu setup to `README.md`, naming the seven voices, official endpoint/model, and the requirement for the user's own API Key without promising permanent free usage.

- [ ] **Step 2: Run format, analysis, tests, and diff validation**

```powershell
& .\work\tools\flutter\bin\dart.bat format lib test
& .\tool\flutter.ps1 analyze
& .\tool\flutter.ps1 test --concurrency=1
git diff --check
```

Expected: formatter is stable, analysis reports no issues, all tests pass, and `git diff --check` emits no output.

- [ ] **Step 3: Re-run the supplied EPUB acceptance test**

Run the Task 1 Step 5 command and verify
`title=完美世界 chapters=2004 paragraphs=186814`.

- [ ] **Step 4: Commit documentation and push**

```powershell
git add README.md
git commit -m "docs: describe Zhipu TTS and resilient EPUB import"
git push origin feature/flutter-mvp
```

- [ ] **Step 5: Verify GitHub Actions**

Watch the new run until `test-android` and `build-ios` both conclude `success`. Confirm `app-debug` and `ios-unsigned-ipa` artifacts are present and unexpired.

- [ ] **Step 6: Download and verify artifacts**

Download both artifacts into a new `work/delivery-<sha>` directory, copy them into `outputs` with the short SHA in each filename, compute SHA-256, and verify the IPA contains `Payload/Runner.app` without `_CodeSignature` or `embedded.mobileprovision`.

- [ ] **Step 7: Update PR #1**

Update the PR summary and verification section with resilient EPUB import, Zhipu GLM-TTS, exact test count, successful Android/iOS jobs, and artifact names.
