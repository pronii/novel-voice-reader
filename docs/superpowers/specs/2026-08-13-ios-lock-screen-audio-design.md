# iOS Lock-Screen Audio Design

## Goal

Keep MiMo cloud TTS playback alive across iOS lock-screen transitions and
between cached audio segments.

## Root Cause

The app declares `UIBackgroundModes=audio` and uses `audio_service`, but it
never explicitly configures or activates the shared iOS audio session. MiMo
uses `just_audio` to play a sequence of generated files. A gap between files
can leave the process without an active playback-category session, allowing
iOS to suspend it after the screen locks.

## Design

Add a startup audio-session initializer backed by the existing transitive
`audio_session` package. Configure `AudioSessionConfiguration.music()` and
activate the session before calling `AudioService.init`. Keep the initializer
behind a narrow interface so ordering and failure behavior can be tested
without platform channels.

Initialization failure is fatal at startup: continuing would reproduce an
unreliable lock-screen playback state. Existing MiMo synthesis, caching,
segmenting, playback controls, and platform background declarations remain
unchanged.

## Verification

- Unit test verifies music configuration precedes activation.
- Startup orchestration test verifies audio-session initialization completes
  before AudioService initialization begins.
- Run Flutter analysis and the complete test suite.
- Manually trigger the packaging workflow and require iOS no-codesign build.
