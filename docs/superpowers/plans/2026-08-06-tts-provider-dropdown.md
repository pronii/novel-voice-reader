# TTS Provider Dropdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the horizontally scrolling TTS provider segments with a full-width dropdown that works on narrow phones.

**Architecture:** `VoiceSettingsPage` owns the selected provider as before. A keyed `DropdownButtonFormField<SpeechProviderType>` maps the six enum values to their current icon and label, then delegates changes to the existing `_selectProvider` method.

**Tech Stack:** Flutter Material 3, Flutter widget tests

## Global Constraints

- Preserve all six provider enum values and labels.
- Keep provider-specific forms and save behavior unchanged.
- The selector must fit at 320 logical pixels without horizontal scrolling.

---

### Task 1: Define The Narrow-Screen Contract

**Files:** Modify `test/features/speech/voice_settings_page_test.dart`.

- [ ] Add a 320-pixel widget test that expects key `tts-provider-dropdown`, opens it, selects MiMo, and sees the MiMo API key field.
- [ ] Run the focused test and verify it fails because the dropdown key does not exist.

### Task 2: Replace The Provider Selector

**Files:** Modify `lib/features/speech/presentation/voice_settings_page.dart`.

- [ ] Replace `SingleChildScrollView` and `SegmentedButton` with `DropdownButtonFormField<SpeechProviderType>`.
- [ ] Reuse the six existing icons and labels, use `isExpanded: true`, and call `_selectProvider` from `onChanged`.
- [ ] Run the focused test and verify it passes.

### Task 3: Update Existing Provider Selection Tests

**Files:** Modify `test/features/speech/voice_settings_page_test.dart` and `test/app/navigation_test.dart`.

- [ ] Add a test helper that opens key `tts-provider-dropdown` and taps the requested provider label.
- [ ] Replace horizontal drags and direct offstage label taps with the helper.
- [ ] Run the voice settings and navigation tests, then the full suite.

