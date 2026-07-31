# Broken EPUB Import and Zhipu TTS Design

## Scope

Allow EPUB books with missing non-reading resources to import when their spine
and chapter documents are intact. Add Zhipu GLM-TTS as a dedicated speech
provider while preserving System, OpenAI-compatible, and Azure providers.

## EPUB Import

The supplied EPUB is structurally readable and contains 2,005 spine documents,
but its manifest references `OEBPS/Images/cover0001.jpg`, which is absent from
the archive. `EpubReader.readBook` eagerly reads every image and aborts before
the application can extract any chapter.

The parser will open EPUB metadata and content references with
`EpubReader.openBook`, then read only linear spine documents. Manifest path
normalization and the existing semantic/div/body text extraction remain in
place. A missing cover, image, font, stylesheet, or other resource that is not
needed for chapter text will not prevent import. A missing spine XHTML file,
invalid package metadata, encrypted content, or a book with no readable
chapters will still produce an import error.

The parser continues to return the complete `ParsedBook`; database writes stay
inside the existing transaction so a failed import cannot leave a partial
book. The supplied EPUB is the manual acceptance fixture, while a small
generated EPUB with an absent manifest image provides the automated regression
test.

## Zhipu TTS

Voice settings will add a dedicated `Zhipu` provider next to System,
OpenAI-compatible, and Azure. The endpoint and model are fixed to the official
API contract:

- Endpoint: `https://open.bigmodel.cn/api/paas/v4/audio/speech`
- Model: `glm-tts`
- Response format: `wav`
- Default voice: `tongtong`
- Speed range: `0.5` through `2.0`

The user enters a Zhipu API Key and chooses one of the official system voices:
`tongtong`, `chuichui`, `xiaochen`, `jam`, `kazi`, `douji`, or `luodo`. The
request uses Bearer authentication and sends `model`, `input`, `voice`,
`response_format`, and `speed`. Paragraph segmentation keeps every request
under the official 1,024-character input limit.

The Zhipu API Key uses a provider-specific secure-storage entry. It is never
written to Drift, logs, Git, or cache metadata. The active profile persists as
provider type `zhipu` plus its public voice, speed, model, endpoint, and output
format. Reader playback uses the existing cached-audio provider and
`just_audio`; cache identity already includes profile settings, so Zhipu audio
does not collide with Azure or compatible-provider audio.

The UI will label the provider `智谱` but will not claim that GLM-TTS is
permanently free. The official model page links to current pricing rather than
guaranteeing a permanent free tier.

## Error Handling

Missing or empty Zhipu credentials are rejected before the request. HTTP
401/403, 429, timeout, connection, empty-audio, and other HTTP failures map to
sanitized Chinese messages. Transient 429 and 5xx failures use the same bounded
retry policy as the compatible cloud client. API response bodies and keys are
not exposed to the user.

## Verification

Automated tests cover an EPUB whose manifest contains a missing image, lazy
spine ordering and text extraction, Zhipu profile defaults and persistence,
separate secure credentials, the exact official request URL/body/headers,
failure mapping and retries, provider factory wiring, and settings-page save
behavior. The supplied 13 MB EPUB must parse as title `完美世界` with 2,005
spine documents and 2,004 readable chapters; its text-free cover document is
not a chapter. Flutter analysis and the complete test suite must pass before
Android APK and unsigned iOS IPA artifacts are rebuilt.
