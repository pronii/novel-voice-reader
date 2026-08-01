# Reader Progress and Zhipu Rate-Limit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Zhipu speech resilient to rate limits, add a real API-key connection test, restore paragraph-level reading position, and remove the fixed reader footer.

**Architecture:** Keep speech request policy inside `ZhipuTtsClient`, while `VoiceSettingsPage` receives injected save and connection-test callbacks. Replace the reader's variable-height sliver list with `ScrollablePositionedList` so the saved paragraph can be both observed and restored by index; route code remains the owner of Drift persistence and playback lifecycle.

**Tech Stack:** Flutter, Dart 3.12, Riverpod, Drift, Dio, `scrollable_positioned_list`, flutter_test.

## Global Constraints

- The bottom navigation bar is removed completely; chapter switching remains in the app-bar directory.
- Reading progress is paragraph based and uses the first visible body paragraph.
- The connection test sends the short text `测试`, discards audio, and never saves credentials or profiles.
- Zhipu fallback retry delays are exactly 2, 4, 8, and 16 seconds for five total attempts.
- A valid `Retry-After` delta-seconds or HTTP-date value takes precedence and is capped at 60 seconds.
- API keys, input text, and response bodies must not appear in user-facing failures or logs.
- No database migration is introduced.

---

### Task 1: Zhipu Retry Policy and Connection Probe

**Files:**
- Modify: `lib/features/speech/data/zhipu_tts_client.dart`
- Modify: `test/features/speech/zhipu_tts_client_test.dart`

**Interfaces:**
- Consumes: existing `Dio`, `SecureCredentials`, `SpeechSegment`, and `VoiceProfile`.
- Produces: `Future<void> ZhipuTtsClient.testConnection({required String apiKey, required VoiceProfile profile})` and retry-delay parsing shared by normal synthesis.

- [ ] **Step 1: Write failing tests for fallback delays and Retry-After**

Extend `HttpOutcome.status` with response headers and record injected delays:

```dart
test('uses bounded exponential delays when 429 has no Retry-After', () async {
  final delays = <Duration>[];
  final adapter = RecordingHttpClientAdapter(outcomes: const [
    HttpOutcome.status(429),
    HttpOutcome.status(429),
    HttpOutcome.status(429),
    HttpOutcome.status(429),
    HttpOutcome.success([4, 5, 6]),
  ]);
  final client = ZhipuTtsClient(
    dio: Dio()..httpClientAdapter = adapter,
    credentials: SecureCredentials(FakeSecureStore('zhipu-secret')),
    delay: (duration) async => delays.add(duration),
  );

  await client.synthesize(testSegment, testProfile);

  expect(delays, const [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
  ]);
});

test('honors Retry-After seconds and caps it at sixty seconds', () async {
  final delays = <Duration>[];
  final adapter = RecordingHttpClientAdapter(outcomes: const [
    HttpOutcome.status(429, headers: {'retry-after': ['120']}),
    HttpOutcome.success([4, 5, 6]),
  ]);
  final client = ZhipuTtsClient(
    dio: Dio()..httpClientAdapter = adapter,
    credentials: SecureCredentials(FakeSecureStore('zhipu-secret')),
    delay: (duration) async => delays.add(duration),
  );

  await client.synthesize(testSegment, testProfile);

  expect(delays, const [Duration(seconds: 60)]);
});
```

Add an HTTP-date case with an injected `now` of `DateTime.utc(2026, 8, 1, 0, 0)` and expected delay of 30 seconds.

- [ ] **Step 2: Run the retry tests and verify RED**

Run:

```powershell
flutter test test/features/speech/zhipu_tts_client_test.dart --plain-name "uses bounded exponential delays when 429 has no Retry-After"
flutter test test/features/speech/zhipu_tts_client_test.dart --plain-name "honors Retry-After seconds and caps it at sixty seconds"
```

Expected: FAIL because the current client retries only three times with 250/500 ms delays and the fixture has no response-header support.

- [ ] **Step 3: Implement the bounded retry policy**

Add an injectable clock and compute the delay from the response:

```dart
typedef ZhipuTtsNow = DateTime Function();

ZhipuTtsClient({
  required this.dio,
  required this.credentials,
  int maxAttempts = 5,
  ZhipuTtsDelay? delay,
  ZhipuTtsNow? now,
}) : assert(maxAttempts > 0),
     _maxAttempts = maxAttempts,
     _delay = delay ?? Future<void>.delayed,
     _now = now ?? DateTime.now;

Duration _retryDelay(DioException error, int attempt) {
  if (error.response?.statusCode == 429) {
    final header = error.response?.headers.value('retry-after');
    final seconds = int.tryParse(header ?? '');
    if (seconds != null && seconds >= 0) {
      return Duration(seconds: seconds.clamp(0, 60));
    }
    final date = HttpDate.parse(header ?? '');
    final duration = date.difference(_now().toUtc());
    if (!duration.isNegative) {
      return duration > const Duration(seconds: 60)
          ? const Duration(seconds: 60)
          : duration;
    }
  }
  return Duration(seconds: 1 << attempt);
}
```

Guard HTTP-date parsing with `try/catch FormatException`, use attempt values 1 through 4 to produce 2/4/8/16 seconds, and retain `_isRetriable` plus sanitized `_failureFor` mapping.

- [ ] **Step 4: Write failing tests for the real connection probe**

```dart
test('tests an entered key with a short real synthesis request', () async {
  final adapter = RecordingHttpClientAdapter(
    outcomes: [HttpOutcome.success(validWavBytes)],
  );
  final client = ZhipuTtsClient(
    dio: Dio()..httpClientAdapter = adapter,
    credentials: SecureCredentials(FakeSecureStore('stored-key')),
  );

  await client.testConnection(apiKey: 'entered-key', profile: testProfile);

  expect(adapter.request?.headers['Authorization'], 'Bearer entered-key');
  expect(adapter.request?.data['input'], '测试');
});

test('connection test rejects invalid audio and does not retry 429', () async {
  final invalidAdapter = RecordingHttpClientAdapter(
    outcomes: const [HttpOutcome.success([1, 2, 3])],
  );
  final invalidClient = ZhipuTtsClient(
    dio: Dio()..httpClientAdapter = invalidAdapter,
    credentials: SecureCredentials(FakeSecureStore('stored-key')),
  );
  await expectLater(
    invalidClient.testConnection(apiKey: 'entered-key', profile: testProfile),
    throwsA(isA<AppFailure>().having(
      (failure) => failure.message,
      'message',
      '智谱语音服务返回了无效音频',
    )),
  );

  final limitedAdapter = RecordingHttpClientAdapter(
    outcomes: const [HttpOutcome.status(429)],
  );
  final limitedClient = ZhipuTtsClient(
    dio: Dio()..httpClientAdapter = limitedAdapter,
    credentials: SecureCredentials(FakeSecureStore('stored-key')),
  );
  await expectLater(
    limitedClient.testConnection(apiKey: 'entered-key', profile: testProfile),
    throwsA(isA<AppFailure>().having(
      (failure) => failure.message,
      'message',
      '智谱语音服务请求过于频繁',
    )),
  );
  expect(limitedAdapter.calls, 1);
});
```

- [ ] **Step 5: Run the connection tests and verify RED**

Run: `flutter test test/features/speech/zhipu_tts_client_test.dart`

Expected: FAIL because `testConnection` and WAV validation do not exist.

- [ ] **Step 6: Implement the connection probe**

Factor the POST into a private method accepting an explicit key. `synthesize`
uses the stored key and retry loop; `testConnection` validates the entered key,
makes exactly one request, and validates RIFF/WAVE bytes:

```dart
Future<void> testConnection({
  required String apiKey,
  required VoiceProfile profile,
}) async {
  if (apiKey.trim().isEmpty) {
    throw const AppFailure('请输入智谱 API Key');
  }
  try {
    final bytes = await _request(
      const SpeechSegment(
        id: 'zhipu-connection-test',
        paragraphId: -1,
        text: '测试',
        partIndex: 0,
      ),
      profile,
      apiKey.trim(),
    );
    if (!_isWave(bytes)) {
      throw const AppFailure('智谱语音服务返回了无效音频');
    }
  } on DioException catch (error) {
    throw _failureFor(error);
  }
}
```

- [ ] **Step 7: Run tests and commit**

Run: `flutter test test/features/speech/zhipu_tts_client_test.dart`

Expected: all Zhipu client tests PASS.

```powershell
git add lib/features/speech/data/zhipu_tts_client.dart test/features/speech/zhipu_tts_client_test.dart
git commit -m "fix: make Zhipu requests resilient to rate limits"
```

---

### Task 2: Zhipu Test-Connection Button

**Files:**
- Modify: `lib/features/speech/presentation/voice_settings_page.dart`
- Modify: `lib/app/router.dart`
- Modify: `test/features/speech/voice_settings_page_test.dart`

**Interfaces:**
- Consumes: `ZhipuTtsClient.testConnection` from Task 1.
- Produces: optional `VoiceSettingsPage.onTestConnection` callback with signature `Future<void> Function(VoiceProfile profile, String apiKey)`.

- [ ] **Step 1: Write failing widget tests**

Add tests that select 智谱 and verify empty-key validation, in-progress disabling,
success messaging, and failure messaging:

```dart
testWidgets('tests the entered Zhipu key without saving it', (tester) async {
  var tests = 0;
  var saves = 0;
  await tester.pumpWidget(MaterialApp(
    home: VoiceSettingsPage(
      onTestConnection: (profile, apiKey) async {
        tests++;
        expect(profile.providerType, SpeechProviderType.zhipu);
        expect(apiKey, 'entered-key');
      },
      onSave: (profile, apiKey) async => saves++,
    ),
  ));
  await tester.tap(find.text('智谱'));
  await tester.pump();
  await tester.enterText(find.widgetWithText(TextField, 'API Key'), 'entered-key');
  await tester.tap(find.text('测试连接'));
  await tester.pumpAndSettle();

  expect(tests, 1);
  expect(saves, 0);
  expect(find.text('连接成功，API Key 可用'), findsOneWidget);
});
```

Use a `Completer<void>` in another test to assert the label is `测试中` and both
test/save actions cannot start a second test while pending. Throw
`AppFailure('智谱语音服务认证失败')` to verify the sanitized text is shown.

- [ ] **Step 2: Run widget tests and verify RED**

Run: `flutter test test/features/speech/voice_settings_page_test.dart`

Expected: FAIL because `onTestConnection` and the button do not exist.

- [ ] **Step 3: Implement the settings interaction**

Add the callback and `_testingConnection` state. Under the Zhipu key field render:

```dart
OutlinedButton.icon(
  onPressed: _saving || _testingConnection ? null : _testConnection,
  icon: const Icon(Icons.wifi_tethering),
  label: Text(_testingConnection ? '测试中' : '测试连接'),
)
```

`_testConnection` builds the current Zhipu profile, validates the trimmed key,
awaits the callback, shows `连接成功，API Key 可用`, catches `AppFailure` to show
its message, catches other errors as `连接测试失败`, and always clears the state
in `finally`. Disable 保存 while `_testingConnection` is true.

- [ ] **Step 4: Wire the route without persisting the entered key**

Pass a separate callback from `_VoiceSettingsRoutePage`:

```dart
onTestConnection: (profile, apiKey) async {
  final credentials = SecureCredentials(
    FlutterSecureKeyValueStore(const FlutterSecureStorage()),
  );
  await ZhipuTtsClient(dio: Dio(), credentials: credentials)
      .testConnection(apiKey: apiKey, profile: profile);
},
```

Import `zhipu_tts_client.dart`. Do not call the existing save callback or secure
storage writes from this path.

- [ ] **Step 5: Run tests and commit**

Run:

```powershell
flutter test test/features/speech/voice_settings_page_test.dart
flutter test test/features/speech/zhipu_tts_client_test.dart
```

Expected: both suites PASS.

```powershell
git add lib/features/speech/presentation/voice_settings_page.dart lib/app/router.dart test/features/speech/voice_settings_page_test.dart
git commit -m "feat: verify Zhipu API keys from settings"
```

---

### Task 3: Restore and Persist Visible Reading Position

**Files:**
- Modify: `pubspec.yaml`
- Modify (generated): `pubspec.lock`
- Modify: `lib/features/reader/presentation/reader_page.dart`
- Modify: `lib/app/router.dart`
- Modify: `test/features/reader/reader_page_test.dart`
- Create: `test/app/reader_page_data_provider_test.dart`

**Interfaces:**
- Consumes: existing `ReaderParagraph.index`, `ReaderPageData.activeParagraphId`, and `AppDatabase.upsertProgress`.
- Produces: `ReaderPage.onReadingPositionChanged`, type `ValueChanged<ReaderParagraph>?`.

- [ ] **Step 1: Add the index-addressable list dependency**

Add `scrollable_positioned_list: ^0.3.8` under dependencies and run:

```powershell
flutter pub get
```

Expected: dependency resolution succeeds and `pubspec.lock` records
`scrollable_positioned_list`.

- [ ] **Step 2: Write failing reader widget tests**

Replace the previous/next-footer test with tests for initial positioning and
visible-position reporting. Use a 320x480 viewport and enough multi-line
paragraphs to prevent all items from fitting:

```dart
testWidgets('starts at the saved paragraph and reports a new visible paragraph', (tester) async {
  final reported = <int>[];
  await tester.pumpWidget(MaterialApp(
    home: ReaderPage(
      bookId: 1,
      bookTitle: '测试书',
      chapterTitle: '第一章',
      currentChapterId: 10,
      initialActiveParagraphId: 15,
      paragraphs: longParagraphs,
      onReadingPositionChanged: (paragraph) => reported.add(paragraph.id),
    ),
  ));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('active-paragraph-15')), findsOneWidget);
  expect(find.byTooltip('上一章'), findsNothing);
  expect(find.byTooltip('下一章'), findsNothing);
  await tester.drag(find.byType(ScrollablePositionedList), const Offset(0, -300));
  await tester.pump(const Duration(milliseconds: 600));
  expect(reported, isNotEmpty);
  expect(reported.last, isNot(15));
});
```

Add a tap test asserting `onReadingPositionChanged` is called immediately with
the tapped paragraph and a layout test asserting no `BottomNavigationBar` or
fixed chapter-title footer exists.

- [ ] **Step 3: Run reader tests and verify RED**

Run: `flutter test test/features/reader/reader_page_test.dart`

Expected: FAIL because the callback, positioned list, and full-screen layout do
not exist.

- [ ] **Step 4: Implement paragraph observation and restoration**

Use `ScrollablePositionedList.builder` with an `ItemPositionsListener`, treating
item 0 as the chapter heading and item `n + 1` as paragraph `n`. Compute
`initialScrollIndex` from `initialActiveParagraphId`; after position updates,
choose the lowest paragraph item whose `itemTrailingEdge > 0` and debounce the
callback for 500 ms:

```dart
void _onItemPositionsChanged() {
  final visible = _itemPositions.itemPositions.value
      .where((position) => position.index > 0 && position.itemTrailingEdge > 0)
      .toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  if (visible.isEmpty) return;
  final paragraph = widget.paragraphs[visible.first.index - 1];
  if (paragraph.id == _lastReportedParagraphId) return;
  _progressDebounce?.cancel();
  _progressDebounce = Timer(const Duration(milliseconds: 500), () {
    _reportReadingPosition(paragraph);
  });
}
```

Key the positioned list by `currentChapterId` so chapter changes recreate it at
the new initial index. Cancel the timer and listener in `dispose`. Remove the
entire `bottomNavigationBar` and the `onPreviousChapter` / `onNextChapter`
properties. Tapping or playing a paragraph calls `_reportReadingPosition`
immediately.

- [ ] **Step 5: Persist reported positions in the route**

Pass the callback and add:

```dart
Future<void> _persistReadingPosition(
  AppDatabase database,
  int chapterId,
  ReaderParagraph paragraph,
) async {
  await database.upsertProgress(
    bookId: widget.bookId,
    chapterId: chapterId,
    paragraphIndex: paragraph.index,
  );
  await (database.update(database.books)
        ..where((book) => book.id.equals(widget.bookId)))
      .write(BooksCompanion(lastReadAt: Value(DateTime.now())));
}
```

Remove footer callback wiring. Retain `_persistSelectedChapter` for chapter-list
changes. Add this focused provider test proving a saved paragraph loads as
`ReaderPageData.activeParagraphId`:

```dart
test('reader data restores the saved paragraph id', () async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final bookId = await database.createBookWithChapter(
    title: '测试书',
    chapterTitle: '第一章',
    paragraphs: const ['第一段。', '第二段。', '第三段。'],
  );
  final chapter = await database.firstChapterForBook(bookId);
  await database.upsertProgress(
    bookId: bookId,
    chapterId: chapter.id,
    paragraphIndex: 1,
  );
  final container = ProviderContainer(overrides: [
    databaseProvider.overrideWithValue(database),
  ]);
  addTearDown(container.dispose);

  final data = await container.read(
    readerPageDataProvider(ReaderPageRequest(bookId)).future,
  );

  expect(data.activeParagraphId, data.paragraphs[1].id);
});
```

- [ ] **Step 6: Run tests and commit**

Run:

```powershell
flutter test test/features/reader/reader_page_test.dart
flutter test test/features/playback/playback_recovery_test.dart
flutter analyze
```

Expected: tests PASS and analysis reports no issues.

```powershell
git add pubspec.yaml pubspec.lock lib/features/reader/presentation/reader_page.dart lib/app/router.dart test/features/reader/reader_page_test.dart test/app/reader_page_data_provider_test.dart
git commit -m "fix: restore paragraph reading progress"
```

---

### Task 4: Suppress Duplicate Playback Startup

**Files:**
- Modify: `lib/app/router.dart`
- Modify: `lib/features/reader/presentation/reader_page.dart`
- Modify: `test/features/reader/reader_page_test.dart`

**Interfaces:**
- Consumes: existing `_ReaderRoutePageState._playFrom` and ReaderPage playback callbacks.
- Produces: `ReaderPage.playbackStarting`, default `false`.

- [ ] **Step 1: Write a failing widget test for disabled playback controls**

```dart
testWidgets('disables playback commands while playback is starting', (tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: ReaderPage(
      bookId: 1,
      bookTitle: '测试书',
      chapterTitle: '第一章',
      playbackStarting: true,
      paragraphs: [ReaderParagraph(id: 10, index: 0, text: '第一段。')],
    ),
  ));

  expect(tester.widget<IconButton>(find.byTooltip('播放')).onPressed, isNull);
  expect(tester.widget<TextButton>(find.widgetWithText(TextButton, '从这里朗读')).onPressed, isNull);
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `flutter test test/features/reader/reader_page_test.dart --plain-name "disables playback commands while playback is starting"`

Expected: FAIL because `playbackStarting` does not exist.

- [ ] **Step 3: Implement the route guard and UI state**

Add `_playbackStarting` to route state. At the synchronous start of `_playFrom`,
return if it is already true, otherwise set it before the first await. Clear it
in `finally` and update mounted state. Pass it to `ReaderPage` and disable both
play entry points while true:

```dart
if (_playbackStarting) return;
setState(() => _playbackStarting = true);
try {
  // Existing provider/coordinator startup.
} finally {
  if (mounted) setState(() => _playbackStarting = false);
}
```

- [ ] **Step 4: Run tests and commit**

Run:

```powershell
flutter test test/features/reader/reader_page_test.dart
flutter test test/features/playback/playback_coordinator_test.dart
```

Expected: both suites PASS.

```powershell
git add lib/app/router.dart lib/features/reader/presentation/reader_page.dart test/features/reader/reader_page_test.dart
git commit -m "fix: prevent duplicate speech startup"
```

---

### Task 5: Full Verification, Artifacts, and GitHub

**Files:**
- Produce: `build/app/outputs/flutter-apk/app-debug.apk`
- Produce: unsigned `Runner.ipa` from GitHub Actions
- Copy deliverables to: `C:/Users/Administrator/Documents/Codex/2026-07-31/ru/outputs/`

**Interfaces:**
- Consumes: all completed tasks and the existing GitHub Actions unsigned-iOS workflow.
- Produces: passing branch, Android APK, unsigned IPA, pushed commits, and successful CI evidence.

- [ ] **Step 1: Run formatting and focused suites**

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter test test/features/speech/zhipu_tts_client_test.dart
flutter test test/features/speech/voice_settings_page_test.dart
flutter test test/features/reader/reader_page_test.dart
flutter test test/features/playback/playback_coordinator_test.dart
flutter test test/features/playback/playback_recovery_test.dart
```

Expected: formatter exits 0 and all focused tests PASS.

- [ ] **Step 2: Run complete static analysis and tests**

```powershell
flutter analyze
flutter test
```

Expected: `No issues found!` and the complete suite passes with zero failures.

- [ ] **Step 3: Build Android artifact**

Run: `flutter build apk --debug`

Expected: `build/app/outputs/flutter-apk/app-debug.apk` exists and has nonzero length.

- [ ] **Step 4: Commit documentation and any final metadata**

```powershell
git add docs/superpowers/specs/2026-08-01-reader-progress-zhipu-rate-limit-design.md docs/superpowers/plans/2026-08-01-reader-progress-zhipu-rate-limit.md
git commit -m "docs: document reader reliability updates"
```

Verify `git status --short` is empty.

- [ ] **Step 5: Push and verify CI**

```powershell
git push origin feature/flutter-mvp
gh run list --branch feature/flutter-mvp --limit 5
$ciRunId = gh run list --branch feature/flutter-mvp --limit 1 --json databaseId --jq '.[0].databaseId'
gh run watch $ciRunId --exit-status
```

Expected: the new workflow run succeeds. Download the unsigned IPA artifact and
verify its archive contains neither `_CodeSignature` nor
`embedded.mobileprovision`.

- [ ] **Step 6: Publish local deliverables**

Copy the APK and verified unsigned IPA into the workspace `outputs` directory,
including the final short commit SHA in both filenames. Report exact paths,
test count, analysis result, CI run URL, and signing status.
