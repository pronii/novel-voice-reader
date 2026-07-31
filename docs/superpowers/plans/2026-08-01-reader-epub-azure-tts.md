# Reader, EPUB, and Azure TTS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix reader navigation and chapters, make mobile EPUB imports robust,
and provide usable Azure AI Speech playback.

**Architecture:** Keep parsing, reader state, synthesis, and audio playback in
separate units. Route widgets coordinate persistence and provider selection;
domain/data classes remain independently testable.

**Tech Stack:** Flutter 3.44.8, Riverpod, Drift, GoRouter, Dio, just_audio,
Azure AI Speech REST API

## Global Constraints

- Azure uses the standard Region + Subscription Key Speech REST API.
- Secrets must only be stored with `flutter_secure_storage`.
- EPUB remains limited to non-DRM files.
- Existing OpenAI-compatible and system TTS options remain available.
- Android and iOS outputs must continue to build.

---

### Task 1: Mobile EPUB import compatibility

**Files:**
- Modify: `lib/features/library/data/book_import_repository.dart`
- Modify: `lib/features/library/data/epub_book_parser.dart`
- Modify: `lib/app/router.dart`
- Test: `test/features/library/book_import_repository_test.dart`
- Test: `test/features/library/epub_book_parser_test.dart`

**Interfaces:**
- Consumes: `PlatformFile.bytes` or `PlatformFile.xFile`
- Produces: the existing `ParsedBook` model

- [ ] Add failing tests for path-only picker files and normalized EPUB content
  paths/div markup.
- [ ] Verify the new tests fail for the current implementation.
- [ ] Read path-only files through `XFile`, normalize EPUB hrefs, and expose
  specific import errors.
- [ ] Run the focused library tests and commit.

### Task 2: Reader navigation and chapter selection

**Files:**
- Modify: `lib/app/providers.dart`
- Modify: `lib/app/router.dart`
- Modify: `lib/features/reader/presentation/reader_page.dart`
- Test: `test/app/navigation_test.dart`
- Test: `test/features/reader/reader_page_test.dart`

**Interfaces:**
- Produces: `ReaderPageRequest(bookId, chapterId)` and chapter metadata in
  `ReaderPageData`
- Consumes: chapter selection callbacks from `ReaderPage`

- [ ] Add failing tests for returning to the library, opening the chapter
  list, and invoking previous/next chapter callbacks.
- [ ] Verify the new tests fail for the current implementation.
- [ ] Push reader routes, provide a safe library back action, key reader data
  by selected chapter, and persist chapter changes.
- [ ] Run focused reader/navigation tests and commit.

### Task 3: Azure AI Speech and cloud audio playback

**Files:**
- Modify: `lib/core/storage/secure_credentials.dart`
- Modify: `lib/features/speech/domain/voice_profile.dart`
- Create: `lib/features/speech/data/azure_tts_client.dart`
- Create: `lib/features/speech/data/cached_audio_speech_provider.dart`
- Modify: `lib/features/speech/presentation/voice_settings_page.dart`
- Modify: `lib/features/speech/data/system_tts_adapter.dart`
- Modify: `lib/features/playback/domain/playback_coordinator.dart`
- Modify: `lib/features/playback/data/background_audio_handler.dart`
- Modify: `lib/app/router.dart`
- Test: `test/core/storage/secure_credentials_test.dart`
- Test: `test/features/speech/azure_tts_client_test.dart`
- Test: `test/features/speech/cached_audio_speech_provider_test.dart`
- Test: `test/features/speech/voice_profile_test.dart`

**Interfaces:**
- `AzureTtsClient.synthesize(SpeechSegment, VoiceProfile) -> Uint8List`
- `CachedAudioSpeechProvider implements SpeechProvider`
- `VoiceProfile.azure(region, voice, speed, outputFormat)`

- [ ] Add failing tests for Azure credentials, request headers/SSML, profile
  normalization, and cached audio speech events.
- [ ] Verify the tests fail for the current implementation.
- [ ] Implement Azure synthesis, secure key storage, cloud file playback,
  settings, and active profile/provider selection.
- [ ] Run focused speech/playback tests and commit.

### Task 4: Full verification and deliverables

**Files:**
- Verify: all changed source and test files
- Deliver: Android debug APK and unsigned iOS IPA

- [ ] Run formatting, analysis, and the complete Flutter test suite.
- [ ] Push the branch and wait for the PR GitHub Actions run.
- [ ] Download and inspect Android and unsigned iOS artifacts.
- [ ] Confirm the worktree is clean and update the PR verification summary.

