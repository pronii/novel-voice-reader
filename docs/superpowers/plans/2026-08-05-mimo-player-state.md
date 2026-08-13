# MiMo Settings And Player State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist and restore MiMo settings safely while showing real playback state and timing in the player.

**Architecture:** Voice settings receive a persisted profile plus a credential-presence flag. Cloud audio publishes a typed playback timeline that flows through the coordinator/runtime into the player, while play/pause uses the handler's authoritative playback state.

**Tech Stack:** Flutter, Riverpod, audio_service, just_audio, flutter_test

## Global Constraints

- Do not expose saved API-key plaintext in the UI.
- Display only real audio timing; do not fabricate chapter duration.
- Keep system TTS compatible when no duration stream exists.

---

### Task 1: Restore MiMo settings

**Files:**
- Modify: `lib/features/speech/presentation/voice_settings_page.dart`
- Modify: `lib/app/router.dart`
- Test: `test/features/speech/voice_settings_page_test.dart`

- [ ] Add failing widget tests for restored profile fields and saved-key behavior.
- [ ] Run the focused test and confirm failures describe missing restoration.
- [ ] Add initial profile and credential-presence inputs, then load them in the route.
- [ ] Run the focused test and confirm it passes.

### Task 2: Synchronize player state and timeline

**Files:**
- Modify: `lib/features/speech/domain/speech_provider.dart`
- Modify: `lib/features/speech/data/cached_audio_speech_provider.dart`
- Modify: `lib/features/playback/domain/playback_coordinator.dart`
- Modify: `lib/features/playback/data/background_audio_handler.dart`
- Modify: `lib/features/playback/presentation/player_page.dart`
- Modify: `lib/app/router.dart`
- Test: `test/features/speech/cached_audio_speech_provider_test.dart`
- Test: `test/features/playback/background_audio_handler_test.dart`
- Test: `test/features/playback/player_page_test.dart`

- [ ] Add failing tests for timeline forwarding, authoritative play state, and remaining-time labels.
- [ ] Run focused tests and confirm failures describe the missing stream behavior.
- [ ] Add the minimal timeline interfaces and forwarding subscriptions.
- [ ] Bind the player to handler streams and render progress labels.
- [ ] Run focused tests and confirm they pass.

### Task 3: Verify and deliver

**Files:**
- Review all modified files.

- [ ] Format changed Dart files.
- [ ] Run `flutter test` and `flutter analyze`.
- [ ] Review the final diff for security, lifecycle, and stale-state regressions.
- [ ] Commit and push the feature branch.
