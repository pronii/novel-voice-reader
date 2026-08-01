# Reader Progress and Zhipu Rate-Limit Design

## Scope

Fix three reader regressions: Zhipu GLM-TTS playback can fail with HTTP 429,
reopening a book does not visibly return to the last reading position, and the
fixed chapter bar consumes space below the正文. The change keeps the existing
book, chapter, paragraph, and playback-progress schema.

## Reader Layout

The fixed bottom navigation bar will be removed completely. The正文 list uses
all space below the app bar, including the area previously occupied by the
chapter title and previous/next buttons. Chapter switching remains available
through the chapter-directory action in the app bar. The chapter heading at
the start of the scrollable正文 remains because it is part of the reading
content rather than a fixed footer.

## Reading Progress

Progress remains paragraph based. The first visible正文 paragraph is considered
the current reading position. A position change is persisted only after
scrolling settles and only when the paragraph differs from the last persisted
value, preventing database writes on every scroll frame.

The reader will use an index-addressable scrollable list. When a book is
opened, the saved paragraph ID is mapped to its list index and used as the
initial scroll target. When the chapter changes, the list resets to the saved
paragraph for that chapter, or to the first paragraph when no saved position
exists. Tapping a paragraph and starting playback also persist that paragraph
immediately, so playback and visual-reading progress share the same cursor.

The existing `reading_progresses` row continues to store `bookId`, `chapterId`,
and `paragraphIndex`; no database migration is required. Saving progress also
updates the book's `lastReadAt` timestamp so library ordering reflects reading
activity.

## Zhipu Rate Limiting

Reader playback startup will be guarded against duplicate taps while a speech
provider is being created and its first segment is being prepared. This avoids
overlapping synthesis requests from repeated play commands.

The Zhipu client will increase its bounded retry budget for transient HTTP 429
and 5xx responses. For 429 responses it first honors a valid `Retry-After`
header in either delta-seconds or HTTP-date form. If the server does not provide
a usable value, retries use 2, 4, 8, and 16 second delays. Server-requested
delays are capped to a reasonable upper bound so a request cannot hang
indefinitely. Timeouts and connection failures keep bounded exponential
retries, while authentication and other non-transient failures are not
retried.

After the retry budget is exhausted, the user still receives the sanitized
Chinese rate-limit message. API keys, input text, and response bodies remain
excluded from errors and logs.

## Zhipu Key Verification

The Zhipu settings form will show a `测试连接` button below the API Key field.
The button uses the currently entered key, selected voice, and speed to send a
real synthesis request containing only the short text `测试`. Returned audio is
validated and discarded rather than played or cached. This verifies the
network path, credential, model, voice, and response format together.

The button is disabled while a test is running and its label changes to
`测试中`. An empty key is rejected locally. A valid audio response reports
`连接成功，API Key 可用`; 401/403 reports an invalid or unauthorized key; 429
reports that the service is reachable but currently rate limited; timeout,
connection, empty-audio, and other HTTP failures retain sanitized Chinese
messages. The test does not save the key or change the active voice profile;
the user must still press `保存` after a successful test.

## Error and Lifecycle Handling

If playback startup fails, the duplicate-start guard is released in a
`finally` block so the user can try again. Replacing a coordinator continues to
dispose the previous audio provider. Pending progress debounce work is flushed
or canceled safely when the reader is disposed, and callbacks check widget
lifecycle before touching UI state.

## Verification

Widget tests will verify that the fixed bottom chapter title and navigation
buttons are absent, the正文 occupies the available body, a saved paragraph is
used as the initial scroll position, and scrolling/tapping reports the expected
paragraph. Router or repository tests will verify that reported positions are
persisted and restored.

Zhipu client tests will verify `Retry-After` seconds, HTTP-date parsing,
fallback delays, the retry cap, and unchanged non-retry behavior for
authentication failures. Settings widget and route tests will verify empty-key
validation, the in-progress state, a successful real-request result, sanitized
failure messages, and that testing neither persists credentials nor saves a
profile. Playback route coverage will verify that duplicate startup is
suppressed. Flutter analysis and the complete test suite must pass before
Android APK and unsigned iOS IPA artifacts are rebuilt.

## Out of Scope

This change does not persist exact pixel offsets, add swipe-based chapter
navigation, change TTS account quotas, or guarantee that a permanently
exhausted Zhipu free quota can recover through retries.
