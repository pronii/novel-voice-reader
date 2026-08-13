# iOS Lock-Screen Audio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Activate an iOS playback audio session before background audio starts.

**Architecture:** A small platform-audio initializer owns audio-session
configuration. A testable startup function sequences that initializer before
`AudioService.init` and `runApp`.

**Tech Stack:** Flutter, `audio_session` 0.2.4, `audio_service` 0.18.19,
`flutter_test`, GitHub Actions.

## Global Constraints

- Configure `AudioSessionConfiguration.music()`.
- Activate the session before initializing `AudioService`.
- Preserve MiMo synthesis, cache, and playback APIs.
- Preserve existing Android behavior and platform background declarations.

---

### Task 1: Audio Session Startup

**Files:**
- Create: `lib/features/playback/data/background_audio_session.dart`
- Modify: `lib/main.dart`
- Modify: `pubspec.yaml`
- Create: `test/features/playback/background_audio_session_test.dart`
- Create: `test/main_test.dart`

**Interfaces:**
- Produces: `BackgroundAudioSession.initialize()` and testable app startup
  sequencing.
- Consumes: `AudioSessionConfiguration.music()`, `AudioService.init`.

- [ ] Write tests requiring configure-then-activate and session-before-service.
- [ ] Push the test-only commit and verify expected RED in GitHub Actions.
- [ ] Add the direct `audio_session` dependency and minimum initializer.
- [ ] Extract startup sequencing without changing runtime construction.
- [ ] Push implementation and require analyze plus complete tests to pass.
- [ ] Manually trigger packaging and require iOS no-codesign build to pass.
- [ ] Request independent code review and resolve blocking findings.
