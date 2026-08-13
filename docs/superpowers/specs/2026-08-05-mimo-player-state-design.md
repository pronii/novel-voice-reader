# MiMo Settings And Player State Design

## Goal

Restore saved MiMo narration settings safely and make the player reflect the real audio state, elapsed progress, and remaining time.

## Design

- Load the latest persisted voice profile when opening voice settings. Restore MiMo provider, voice, speed, and narration style.
- Never read a saved API key back into a text field. Pass only a `hasSavedMiMoApiKey` flag, display a saved-state hint, and treat blank input as "keep the existing key". Connection testing may use the stored key when the field is blank.
- Remove the player page's local playback boolean. Its play/pause icon follows a playback-state stream from `NovelAudioHandler`.
- Expose the current cloud-audio segment position and duration from `just_audio`. Forward that timeline through the speech provider and coordinator to the audio handler, then render a determinate progress bar plus elapsed and remaining time. Providers without duration data show an unavailable timeline rather than an estimate.
- Reset timeline state when a new segment starts or playback becomes idle so stale progress is never shown.

## Error Handling

- Missing MiMo credentials still block first-time connection tests.
- A stored credential remains unchanged when saving with an empty API-key field.
- Invalid, zero, or shorter-than-position durations are clamped before display.

## Test Strategy

- Widget tests cover restored MiMo fields, saved-key messaging, play/pause stream updates, and formatted timeline labels.
- Unit tests cover audio-engine timeline forwarding and handler/runtime publication.
- Existing full Flutter tests and static analysis guard regressions.
