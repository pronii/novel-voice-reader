# Reader Navigation, EPUB Import, and Azure TTS Design

## Scope

Fix navigation from the reader back to the library, expose all imported
chapters with previous/next navigation, make mobile EPUB imports work when the
picker returns a file path instead of in-memory bytes, and add standard Azure
AI Speech synthesis.

## Reader

Opening a book pushes the reader route. The reader also exposes an explicit
back-to-library command so direct links still have a safe exit. Reader data is
keyed by book and optional selected chapter. The page shows a chapter list plus
previous and next chapter controls, and selecting a chapter persists paragraph
zero as reading progress.

## EPUB Import

The import repository reads picker bytes when available and otherwise reads
the picker-provided `XFile`. The EPUB parser normalizes manifest paths and
accepts common div-based chapter markup. User-facing errors distinguish an
unreadable file from an unsupported, encrypted, or empty EPUB.

## Azure TTS

Voice settings provide System, OpenAI-compatible, and Azure AI Speech modes.
Azure requires a region, subscription key, and neural voice name. The key is
stored separately in secure storage. Azure synthesis uses the official Speech
REST endpoint, SSML input, and MP3 output. Cloud audio is cached and played
through `just_audio`, so the selected cloud provider is used by actual reader
playback rather than only being saved as configuration.

## Verification

Regression tests cover path-based imports, EPUB path/markup normalization,
reader back and chapter controls, Azure request headers and SSML escaping,
secure Azure credentials, cached audio playback, and active profile mapping.
GitHub CI must pass Flutter analysis/tests, Android APK build, iOS unsigned IPA
build, and artifact upload.

