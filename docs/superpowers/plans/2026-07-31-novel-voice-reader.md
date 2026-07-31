# Novel Voice Reader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter app for Android and iOS that imports TXT/EPUB novels, reads them with system or OpenAI-compatible cloud TTS, and manages configurable chapter-ahead audio caching.

**Architecture:** A feature-oriented Flutter application keeps parsing, playback, TTS, caching, and persistence behind domain interfaces. Drift stores normalized books and progress, secure storage holds API credentials, platform adapters provide system speech and background media, and a deterministic cache key keeps cloud audio reusable without exposing secrets.

**Tech Stack:** Flutter 3.44.8 stable, Dart 3.x, Riverpod, Drift/SQLite, Dio, `file_picker`, `epubx`, `flutter_tts`, `just_audio`, `audio_service`, `flutter_secure_storage`, `path_provider`, and `background_downloader`.

## Global Constraints

- Support Android and iOS from one Flutter project.
- Import TXT and non-DRM EPUB only.
- Store all book content, progress, settings, and audio locally.
- Keep API keys exclusively in Android Keystore/iOS Keychain-backed secure storage.
- Treat `POST {baseUrl}/v1/audio/speech` with `model`, `voice`, and `input` as the cloud compatibility contract.
- Allow any integer from 0 through the remaining chapter count, plus an explicit whole-book cache option.
- Android may replenish background downloads persistently; iOS replenishment remains opportunistic after termination.
- Never log authorization headers, API keys, or novel text sent to cloud TTS.
- Use test-driven development for domain and infrastructure behavior.
- Windows performs Android checks; GitHub Actions macOS performs unsigned iOS compilation.

---

## Planned File Structure

```text
lib/
  app/
    app.dart
    router.dart
    theme.dart
  core/
    errors/app_failure.dart
    storage/app_database.dart
    storage/app_database.g.dart
    storage/secure_credentials.dart
  features/
    library/
      data/book_import_repository.dart
      domain/book.dart
      domain/book_parser.dart
      presentation/library_page.dart
    reader/
      data/reading_progress_repository.dart
      domain/playback_cursor.dart
      domain/reader_controller.dart
      presentation/reader_page.dart
    speech/
      data/cloud_tts_client.dart
      data/system_tts_adapter.dart
      domain/speech_provider.dart
      domain/speech_segmenter.dart
      presentation/voice_settings_page.dart
    playback/
      data/background_audio_handler.dart
      domain/playback_coordinator.dart
      presentation/player_page.dart
    downloads/
      data/audio_cache_repository.dart
      data/download_scheduler.dart
      domain/cache_key.dart
      domain/download_policy.dart
      presentation/cache_page.dart
  main.dart
test/
  fixtures/
  features/
integration_test/
tool/
  bootstrap_flutter.ps1
.github/workflows/ci.yml
```

Each file owns one public responsibility. Generated Drift code is the only generated source committed to the repository.

### Task 1: Reproducible Flutter Bootstrap and CI

**Files:**
- Create: `tool/bootstrap_flutter.ps1`
- Create: `pubspec.yaml` and Flutter platform scaffolding through `flutter create`
- Create: `lib/app/app.dart`
- Create: `analysis_options.yaml`
- Create: `.github/workflows/ci.yml`
- Modify: `.gitignore`
- Test: `test/smoke_test.dart`

**Interfaces:**
- Produces: a Flutter package named `novel_voice_reader` with `lib/main.dart`.
- Produces: local SDK command `work/tools/flutter/bin/flutter.bat`.
- Produces: CI checks `flutter analyze`, `flutter test`, Android debug build, and unsigned iOS build.

- [ ] **Step 1: Write the SDK bootstrap script**

```powershell
$ErrorActionPreference = 'Stop'
$version = '3.44.8'
$sha256 = '095c108a08e0377d8a6501fed65aeb288908a070ed3f135e525dc6431c7686e4'
$archive = "flutter_windows_${version}-stable.zip"
$url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/$archive"
$tools = Join-Path $PSScriptRoot '..\work\tools'
$zip = Join-Path $tools $archive
$flutter = Join-Path $tools 'flutter\bin\flutter.bat'

New-Item -ItemType Directory -Force -Path $tools | Out-Null
if (-not (Test-Path $flutter)) {
  Invoke-WebRequest -Uri $url -OutFile $zip
  if ((Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sha256) {
    throw 'Flutter SDK checksum mismatch.'
  }
  Expand-Archive -Path $zip -DestinationPath $tools -Force
}
& $flutter --version
```

- [ ] **Step 2: Run the bootstrap and create the app**

Run:

```powershell
pwsh -File tool/bootstrap_flutter.ps1
work/tools/flutter/bin/flutter.bat create --project-name novel_voice_reader --org com.pronii --platforms android,ios .
```

Expected: Flutter reports version `3.44.8`; Android and iOS platform folders are created without deleting `docs/`.

- [ ] **Step 3: Add runtime and development dependencies**

Run:

```powershell
work/tools/flutter/bin/flutter.bat pub add flutter_riverpod go_router drift drift_flutter dio file_picker epubx flutter_tts just_audio audio_service flutter_secure_storage path_provider background_downloader crypto uuid charset_converter
work/tools/flutter/bin/flutter.bat pub add --dev build_runner drift_dev mocktail
work/tools/flutter/bin/flutter.bat pub add --dev integration_test --sdk=flutter
```

Expected: dependency resolution succeeds and `pubspec.lock` is created.

- [ ] **Step 4: Add the minimal application and replace the generated counter test**

```dart
import 'package:flutter/material.dart';

final class NovelVoiceReaderApp extends StatelessWidget {
  const NovelVoiceReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '声阅',
      home: const Scaffold(
        appBar: AppBar(title: Text('书架')),
        body: Center(child: Text('还没有导入小说')),
      ),
    );
  }
}
```

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/app/app.dart';

void main() {
  testWidgets('opens the library as the first screen', (tester) async {
    await tester.pumpWidget(const NovelVoiceReaderApp());
    expect(find.text('书架'), findsOneWidget);
  });
}
```

- [ ] **Step 5: Add CI with separate Android and iOS jobs**

```yaml
name: ci
on:
  push:
  pull_request:

jobs:
  test-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.8'
          channel: stable
          cache: true
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter analyze
      - run: flutter test
      - run: flutter build apk --debug

  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.8'
          channel: stable
          cache: true
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter build ios --debug --no-codesign
```

- [ ] **Step 6: Verify and commit**

Run:

```powershell
work/tools/flutter/bin/flutter.bat analyze
work/tools/flutter/bin/flutter.bat test
git add .
git commit -m "build: bootstrap Flutter application"
```

Expected: analysis and smoke test pass; the SDK under `work/` remains ignored.

### Task 2: Database, Domain Models, and Secure Credentials

**Files:**
- Create: `lib/core/storage/app_database.dart`
- Create: `lib/core/storage/secure_credentials.dart`
- Create: `lib/features/library/domain/book.dart`
- Create: `lib/features/reader/domain/playback_cursor.dart`
- Create: `lib/features/downloads/domain/download_policy.dart`
- Create: `lib/features/speech/domain/voice_profile.dart`
- Test: `test/core/storage/app_database_test.dart`
- Test: `test/core/storage/secure_credentials_test.dart`

**Interfaces:**
- Produces: `AppDatabase`, `BookRecord`, `ChapterRecord`, `ParagraphRecord`, `ReadingProgressRecord`, `AudioCacheRecord`, and `DownloadJobRecord`.
- Produces: `SecureKeyValueStore`, `FlutterSecureKeyValueStore`, and `SecureCredentials.readApiKey()`, `writeApiKey(String)`, and `deleteApiKey()`.
- Produces: `DownloadPolicy(chaptersAhead, wholeBook, wifiOnly, maxCacheBytes)`.

- [ ] **Step 1: Write failing database and credential tests**

```dart
test('deleting a book cascades to chapters and paragraphs', () async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final bookId = await db.createBookWithChapter(
    title: '测试书',
    chapterTitle: '第一章',
    paragraphs: const ['第一段', '第二段'],
  );
  await db.deleteBook(bookId);
  expect(await db.paragraphCountForBook(bookId), 0);
  await db.close();
});

test('API key round-trips only through secure storage', () async {
  final store = FakeSecureStore();
  final credentials = SecureCredentials(store);
  await credentials.writeApiKey('secret');
  expect(await credentials.readApiKey(), 'secret');
  expect(store.values.keys, ['cloud_tts_api_key']);
});
```

- [ ] **Step 2: Run tests and confirm missing-type failures**

Run:

```powershell
work/tools/flutter/bin/flutter.bat test test/core/storage
```

Expected: FAIL because `AppDatabase` and `SecureCredentials` do not exist.

- [ ] **Step 3: Implement Drift tables, transaction methods, and secure storage wrapper**

```dart
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final class SecureCredentials {
  SecureCredentials(this._storage);
  static const _apiKeyKey = 'cloud_tts_api_key';
  final SecureKeyValueStore _storage;

  Future<String?> readApiKey() => _storage.read(_apiKeyKey);
  Future<void> writeApiKey(String value) =>
      _storage.write(_apiKeyKey, value);
  Future<void> deleteApiKey() => _storage.delete(_apiKeyKey);
}
```

The Drift schema must annotate data classes as `BookRecord`, `ChapterRecord`, `ParagraphRecord`, `ReadingProgressRecord`, `AudioCacheRecord`, and `DownloadJobRecord`. It uses foreign keys with cascade deletion, unique `(chapterId, paragraphIndex)`, and a transaction around full-book import. `VoiceProfile` stores only Base URL, model, voice, speed, and output format; it has no API key field or database column.

- [ ] **Step 4: Generate code and run focused tests**

Run:

```powershell
work/tools/flutter/bin/dart.bat run build_runner build
work/tools/flutter/bin/flutter.bat test test/core/storage
```

Expected: all storage tests pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/core lib/features/library/domain lib/features/reader/domain lib/features/downloads/domain test/core
git commit -m "feat: add local book database and secure credentials"
```

### Task 3: TXT and EPUB Import Pipeline

**Files:**
- Create: `lib/features/library/domain/book_parser.dart`
- Create: `lib/features/library/data/txt_book_parser.dart`
- Create: `lib/features/library/data/epub_book_parser.dart`
- Create: `lib/features/library/data/book_import_repository.dart`
- Create: `test/fixtures/utf8_novel.txt`
- Create: `test/fixtures/sample.epub`
- Test: `test/features/library/txt_book_parser_test.dart`
- Test: `test/features/library/epub_book_parser_test.dart`
- Test: `test/features/library/book_import_repository_test.dart`

**Interfaces:**
- Produces: `BookParser.parse(Uint8List bytes, String fileName) -> ParsedBook`.
- Produces: `ParsedBook(title, chapters)` and `ParsedChapter(title, paragraphs)`.
- Produces: `BookImportRepository.importFile(PlatformFile) -> int bookId`.
- Consumes: `AppDatabase.importParsedBook(ParsedBook)`.

- [ ] **Step 1: Write parsing tests**

```dart
test('detects Chinese chapter headings and keeps paragraphs', () async {
  final parsed = await const TxtBookParser().parse(
    Uint8List.fromList(
      utf8.encode('第一章 开始\n第一段。\n\n第二段。\n第二章 继续\n第三段。'),
    ),
    '测试.txt',
  );
  expect(parsed.title, '测试');
  expect(parsed.chapters.map((c) => c.title), ['第一章 开始', '第二章 继续']);
  expect(parsed.chapters.first.paragraphs, ['第一段。', '第二段。']);
});

test('falls back to one chapter when headings are absent', () async {
  final parsed = await const TxtBookParser().parse(
    Uint8List.fromList(utf8.encode('第一段。\n\n第二段。')),
    '无章节.txt',
  );
  expect(parsed.chapters.single.paragraphs.length, 2);
});
```

- [ ] **Step 2: Run tests and confirm failure**

Run:

```powershell
work/tools/flutter/bin/flutter.bat test test/features/library
```

Expected: FAIL because parser implementations are absent.

- [ ] **Step 3: Implement normalized parser contracts and transactional import**

```dart
abstract interface class BookParser {
  Future<ParsedBook> parse(Uint8List bytes, String fileName);
}

final class ParsedBook {
  const ParsedBook({required this.title, required this.chapters});
  final String title;
  final List<ParsedChapter> chapters;
}

final class ParsedChapter {
  const ParsedChapter({required this.title, required this.paragraphs});
  final String title;
  final List<String> paragraphs;
}
```

TXT decoding must try UTF-8 strictly, UTF-16 BOM, then `charset_converter` for GB18030 after explicit detection failure. EPUB parsing must follow spine order, strip scripts/styles, normalize whitespace, and reject encrypted manifests.

- [ ] **Step 4: Run parser and repository tests**

Run:

```powershell
work/tools/flutter/bin/flutter.bat test test/features/library
```

Expected: UTF-8, no-heading TXT, EPUB spine order, encrypted EPUB rejection, and transaction rollback tests pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/library test/features/library test/fixtures
git commit -m "feat: import TXT and EPUB novels"
```

### Task 4: Speech Segmentation and Provider Contract

**Files:**
- Create: `lib/features/speech/domain/speech_provider.dart`
- Create: `lib/features/speech/domain/speech_segmenter.dart`
- Create: `lib/features/reader/domain/playback_cursor.dart`
- Test: `test/features/speech/speech_segmenter_test.dart`
- Test: `test/features/speech/speech_provider_contract_test.dart`

**Interfaces:**
- Produces: `SpeechSegment(id, paragraphId, text, partIndex)`.
- Produces: `SpeechSegmenter.split(paragraphId, text, maxCharacters)`.
- Produces: `SpeechProvider.prepare`, `play`, `pause`, `resume`, `stop`, and event stream.

- [ ] **Step 1: Write failing segmentation tests**

```dart
test('splits on sentence punctuation without losing text', () {
  const text = '第一句很短。第二句也很短！第三句结束？';
  final parts = const SpeechSegmenter().split(7, text, 12);
  expect(parts.map((part) => part.text).join(), text);
  expect(parts.every((part) => part.text.length <= 12), isTrue);
});

test('hard-splits a sentence longer than the service limit', () {
  final text = List.filled(25, '长').join();
  final parts = const SpeechSegmenter().split(9, text, 10);
  expect(parts.map((part) => part.text.length), [10, 10, 5]);
});
```

- [ ] **Step 2: Run and observe the missing implementation**

```powershell
work/tools/flutter/bin/flutter.bat test test/features/speech/speech_segmenter_test.dart
```

Expected: FAIL because `SpeechSegmenter` is undefined.

- [ ] **Step 3: Implement immutable events and interfaces**

```dart
abstract interface class SpeechProvider {
  Stream<SpeechEvent> get events;
  Future<void> prepare(SpeechSegment segment, VoiceProfile profile);
  Future<void> play();
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
}

sealed class SpeechEvent {
  const SpeechEvent();
}
final class SpeechStarted extends SpeechEvent {
  const SpeechStarted(this.segmentId);
  final String segmentId;
}
final class SpeechCompleted extends SpeechEvent {
  const SpeechCompleted(this.segmentId);
  final String segmentId;
}
final class SpeechFailed extends SpeechEvent {
  const SpeechFailed(this.segmentId, this.failure);
  final String segmentId;
  final AppFailure failure;
}
```

- [ ] **Step 4: Run tests and commit**

```powershell
work/tools/flutter/bin/flutter.bat test test/features/speech
git add lib/features/speech/domain lib/features/reader/domain test/features/speech
git commit -m "feat: define speech provider and text segmentation"
```

Expected: all speech domain tests pass.

### Task 5: System TTS and Playback Coordination

**Files:**
- Create: `lib/features/speech/data/system_tts_adapter.dart`
- Create: `lib/features/playback/domain/playback_coordinator.dart`
- Create: `lib/features/reader/data/reading_progress_repository.dart`
- Test: `test/features/playback/playback_coordinator_test.dart`
- Test: `test/features/speech/system_tts_adapter_test.dart`

**Interfaces:**
- Produces: `SystemTtsAdapter implements SpeechProvider`.
- Produces: `PlaybackCoordinator.playFrom(PlaybackCursor)`, `pause`, `resume`, `nextParagraph`, and `previousParagraph`.
- Consumes: `AppDatabase`, `SpeechSegmenter`, `SpeechProvider`, and `ReadingProgressRepository`.

- [ ] **Step 1: Write coordinator tests with a fake provider**

```dart
test('advances and confirms progress after segment completion', () async {
  final provider = FakeSpeechProvider();
  final progress = FakeProgressRepository();
  final coordinator = PlaybackCoordinator(
    provider: provider,
    progress: progress,
    paragraphs: FakeParagraphSource(['第一段', '第二段']),
  );
  await coordinator.playFrom(const PlaybackCursor(chapterId: 1, paragraphIndex: 0));
  provider.completeCurrent();
  await pumpEventQueue();
  expect(progress.confirmed, const PlaybackCursor(chapterId: 1, paragraphIndex: 1));
});
```

- [ ] **Step 2: Run and confirm failure**

```powershell
work/tools/flutter/bin/flutter.bat test test/features/playback
```

Expected: FAIL because `PlaybackCoordinator` is missing.

- [ ] **Step 3: Implement coordinator and system adapter**

The adapter maps `flutter_tts` start, completion, cancel, and error handlers to `SpeechEvent`. Android `pause()` stops the utterance and retains the current paragraph cursor; `resume()` restarts that paragraph. iOS calls native pause/continue when supported.

- [ ] **Step 4: Run focused and full tests**

```powershell
work/tools/flutter/bin/flutter.bat test test/features/playback test/features/speech
work/tools/flutter/bin/flutter.bat test
```

Expected: coordinator ordering, restart-at-paragraph behavior, and progress confirmation pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/speech/data lib/features/playback/domain lib/features/reader/data test/features
git commit -m "feat: add system speech playback coordinator"
```

### Task 6: Cloud TTS Client and Atomic Audio Cache

**Files:**
- Create: `lib/features/speech/data/cloud_tts_client.dart`
- Create: `lib/features/downloads/domain/cache_key.dart`
- Create: `lib/features/downloads/data/audio_cache_repository.dart`
- Test: `test/features/speech/cloud_tts_client_test.dart`
- Test: `test/features/downloads/cache_key_test.dart`
- Test: `test/features/downloads/audio_cache_repository_test.dart`

**Interfaces:**
- Produces: `CloudTtsClient.synthesize(SpeechSegment, VoiceProfile) -> Stream<List<int>>`.
- Produces: `CacheKey.forSegment(segment, profile) -> String`.
- Produces: `AudioCacheRepository.obtain(segment, profile) -> File`.
- Consumes: `SecureCredentials.readApiKey()`.

- [ ] **Step 1: Write request, redaction, and cache-key tests**

```dart
test('posts the compatible speech request without logging text or key', () async {
  final server = MockTtsServer.audio(Uint8List.fromList([1, 2, 3]));
  final client = CloudTtsClient(dio: server.dio, credentials: FakeCredentials('key'));
  final bytes = await client.synthesize(testSegment, testProfile).expand((v) => v).toList();
  expect(server.lastRequest.path, '/v1/audio/speech');
  expect(server.lastRequest.json, containsPair('input', testSegment.text));
  expect(server.logs, isNot(contains('key')));
  expect(server.logs, isNot(contains(testSegment.text)));
  expect(bytes, [1, 2, 3]);
});

test('API key changes do not change the cache key', () {
  final first = CacheKey.forSegment(testSegment, testProfile);
  final second = CacheKey.forSegment(testSegment, testProfile);
  expect(first, second);
});
```

- [ ] **Step 2: Run tests and confirm failure**

```powershell
work/tools/flutter/bin/flutter.bat test test/features/speech/cloud_tts_client_test.dart test/features/downloads
```

Expected: FAIL because cloud client and cache repository are undefined.

- [ ] **Step 3: Implement compatible request and atomic cache writes**

```dart
final response = await _dio.post<ResponseBody>(
  '${profile.normalizedBaseUrl}/v1/audio/speech',
  data: {
    'model': profile.model,
    'voice': profile.voice,
    'input': segment.text,
    'response_format': profile.outputFormat,
    'speed': profile.speed,
  },
  options: Options(
    responseType: ResponseType.stream,
    headers: {'Authorization': 'Bearer $apiKey'},
  ),
);
```

Write to `<cacheKey>.partial`, reject empty or undecodable audio, then atomically rename to the final extension. Never include the key or raw text in file names or metadata.

- [ ] **Step 4: Run failure-mode tests**

```powershell
work/tools/flutter/bin/flutter.bat test test/features/speech/cloud_tts_client_test.dart test/features/downloads
```

Expected: success, 401, 429, timeout, corrupt audio, retry, and atomic cleanup cases pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/speech/data/cloud_tts_client.dart lib/features/downloads test/features/speech/cloud_tts_client_test.dart test/features/downloads
git commit -m "feat: synthesize and cache cloud speech"
```

### Task 7: Download Window and Platform Scheduling

**Files:**
- Create: `lib/features/downloads/data/download_scheduler.dart`
- Create: `lib/features/downloads/domain/download_window.dart`
- Test: `test/features/downloads/download_window_test.dart`
- Test: `test/features/downloads/download_scheduler_test.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`
- Modify: `ios/Runner/AppDelegate.swift`

**Interfaces:**
- Produces: `DownloadWindow.calculate(currentChapterIndex, chaptersAhead, wholeBook, chapterCount)` where chapter indexes are zero-based.
- Produces: `DownloadScheduler.reconcile(bookId, currentChapter, policy)`.
- Consumes: `AudioCacheRepository`, `AppDatabase`, connectivity constraints, and `background_downloader`.

- [ ] **Step 1: Write exact window behavior tests**

```dart
test('keeps current plus the requested number of later chapters', () {
  expect(
    DownloadWindow.calculate(
      currentChapterIndex: 4,
      chaptersAhead: 3,
      wholeBook: false,
      chapterCount: 10,
    ),
    [4, 5, 6, 7],
  );
});

test('clamps to the final chapter', () {
  expect(
    DownloadWindow.calculate(
      currentChapterIndex: 8,
      chaptersAhead: 9,
      wholeBook: false,
      chapterCount: 10,
    ),
    [8, 9],
  );
});
```

- [ ] **Step 2: Run and confirm failure**

```powershell
work/tools/flutter/bin/flutter.bat test test/features/downloads/download_window_test.dart
```

Expected: FAIL because `DownloadWindow` is undefined.

- [ ] **Step 3: Implement reconciliation and constraints**

Reconciliation orders jobs as current segment, current chapter, then later chapters. It cancels only not-yet-started jobs outside the new window, preserves completed files, and pauses new work at the byte limit. Android registers persistent constrained jobs. iOS registers background transfers for already enumerated segments and recalculates the window on foreground/background refresh.

- [ ] **Step 4: Configure platform background capabilities**

Android declares internet, foreground service, foreground media playback, and boot rescheduling permissions. iOS enables `audio`, `fetch`, and `processing` background modes and registers one processing task identifier matching the scheduler.

- [ ] **Step 5: Run tests and commit**

```powershell
work/tools/flutter/bin/flutter.bat test test/features/downloads
git add lib/features/downloads test/features/downloads android/app/src/main/AndroidManifest.xml ios/Runner
git commit -m "feat: schedule configurable chapter-ahead downloads"
```

Expected: window, priority, cancellation, network, byte-limit, and resume tests pass.

### Task 8: App Navigation, Library, Reader, Player, and Settings UI

**Files:**
- Create: `lib/app/app.dart`
- Create: `lib/app/router.dart`
- Create: `lib/app/theme.dart`
- Create: `lib/features/library/presentation/library_page.dart`
- Create: `lib/features/reader/presentation/reader_page.dart`
- Create: `lib/features/playback/presentation/player_page.dart`
- Create: `lib/features/speech/presentation/voice_settings_page.dart`
- Create: `lib/features/downloads/presentation/cache_page.dart`
- Modify: `lib/main.dart`
- Test: `test/app/navigation_test.dart`
- Test: `test/features/library/library_page_test.dart`
- Test: `test/features/reader/reader_page_test.dart`
- Test: `test/features/downloads/cache_page_test.dart`

**Interfaces:**
- Produces routes `/library`, `/reader/:bookId`, `/player/:bookId`, `/settings/voice`, and `/settings/cache`.
- Consumes Riverpod providers for database, import, playback, voice settings, and downloads.

- [ ] **Step 1: Write widget tests for the complete primary flow**

```dart
testWidgets('opens a book and exposes reader playback controls', (tester) async {
  await tester.pumpWidget(testAppWithBook(title: '测试书'));
  await tester.tap(find.text('测试书'));
  await tester.pumpAndSettle();
  expect(find.text('第一章'), findsOneWidget);
  expect(find.byTooltip('播放'), findsOneWidget);
  expect(find.byTooltip('播放器'), findsOneWidget);
});

testWidgets('accepts an arbitrary valid chapter-ahead count', (tester) async {
  await tester.pumpWidget(testCachePage(chapterCount: 80, currentChapter: 10));
  await tester.enterText(find.byKey(const Key('chaptersAhead')), '37');
  await tester.tap(find.text('应用'));
  expect(find.text('将缓存当前章节及后续 37 章'), findsOneWidget);
});
```

- [ ] **Step 2: Run widget tests and confirm failure**

```powershell
work/tools/flutter/bin/flutter.bat test test/app test/features/library test/features/reader test/features/downloads/cache_page_test.dart
```

Expected: FAIL because application pages do not exist.

- [ ] **Step 3: Implement a quiet Material 3 application shell**

Use a top app bar and bottom navigation only where destinations are peers. Use icon buttons with tooltips for playback commands, a numeric stepper/text field for chapter count, switches for network policy, sliders for typography and speed, and unframed page sections. Do not nest cards or show instructional feature copy.

- [ ] **Step 4: Implement reading synchronization**

The reader uses stable paragraph keys, scrolls only when the active paragraph leaves the visible area, and visually highlights exactly one active paragraph. Manual scrolling does not mutate `PlaybackCursor`; tapping a paragraph exposes “从这里朗读”.

- [ ] **Step 5: Run widget tests at phone and large-text sizes**

```powershell
work/tools/flutter/bin/flutter.bat test test/app test/features
work/tools/flutter/bin/flutter.bat analyze
```

Expected: navigation, empty/loading/error states, large text, dark mode, and no-overflow assertions pass.

- [ ] **Step 6: Commit**

```powershell
git add lib test
git commit -m "feat: add library reader player and settings UI"
```

### Task 9: Background Audio, Lock-Screen Controls, and Interruption Recovery

**Files:**
- Create: `lib/features/playback/data/background_audio_handler.dart`
- Modify: `lib/features/playback/domain/playback_coordinator.dart`
- Modify: `lib/main.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`
- Test: `test/features/playback/background_audio_handler_test.dart`
- Test: `test/features/playback/playback_recovery_test.dart`

**Interfaces:**
- Produces: `NovelAudioHandler extends BaseAudioHandler`.
- Consumes: `PlaybackCoordinator`.
- Maps media commands to play, pause, previous paragraph, and next paragraph.

- [ ] **Step 1: Write media-command mapping tests**

```dart
test('lock-screen next skips exactly one paragraph', () async {
  final coordinator = FakePlaybackCoordinator(
    cursor: const PlaybackCursor(chapterId: 1, paragraphIndex: 3),
  );
  final handler = NovelAudioHandler(coordinator);
  await handler.skipToNext();
  expect(coordinator.cursor.paragraphIndex, 4);
});
```

- [ ] **Step 2: Run and confirm failure**

```powershell
work/tools/flutter/bin/flutter.bat test test/features/playback/background_audio_handler_test.dart
```

Expected: FAIL because `NovelAudioHandler` is undefined.

- [ ] **Step 3: Implement audio session and notification state**

Initialize `audio_service` before `runApp`, publish current book/chapter metadata, expose play/pause/previous/next controls, and persist progress on interruption, pause, background, and disposal. A cloud-audio focus loss pauses `just_audio`; system TTS uses the platform adapter's stop/restart semantics.

- [ ] **Step 4: Run tests and commit**

```powershell
work/tools/flutter/bin/flutter.bat test test/features/playback
git add lib/features/playback lib/main.dart android ios test/features/playback
git commit -m "feat: support background and lock-screen playback"
```

Expected: command mapping and simulated restart recovery pass locally.

### Task 10: Security, Accessibility, Builds, and Release Verification

**Files:**
- Create: `docs/testing/mobile-test-matrix.md`
- Create: `integration_test/import_and_read_test.dart`
- Modify: `README.md`
- Modify: `.github/workflows/ci.yml`
- Test: all tests and platform builds

**Interfaces:**
- Produces: documented setup for local API-compatible endpoint configuration.
- Produces: CI artifacts for Android debug APK and unsigned iOS build verification.

- [ ] **Step 1: Add an end-to-end fake-service test**

```dart
testWidgets('imports TXT, generates cloud audio, and restores progress', (tester) async {
  final harness = await AppHarness.start(fakeTtsAudio: validMp3Fixture);
  await harness.importTxt('第一章\n第一段。\n第二段。');
  await harness.configureCloudVoice();
  await harness.playFirstParagraph();
  await harness.restartApp();
  expect(harness.currentCursor, const PlaybackCursor(chapterId: 1, paragraphIndex: 0));
  expect(harness.apiKeyFoundInDatabaseOrLogs, isFalse);
});
```

- [ ] **Step 2: Run static analysis, tests, and Android build**

```powershell
work/tools/flutter/bin/flutter.bat pub get
work/tools/flutter/bin/dart.bat run build_runner build
work/tools/flutter/bin/flutter.bat analyze
work/tools/flutter/bin/flutter.bat test
work/tools/flutter/bin/flutter.bat build apk --debug
```

Expected: zero analyzer issues, all tests pass, and `build/app/outputs/flutter-apk/app-debug.apk` exists.

- [ ] **Step 3: Push and verify GitHub CI**

```powershell
git push -u origin main
gh run watch --exit-status
```

Expected: Linux tests/Android build and macOS unsigned iOS build pass.

- [ ] **Step 4: Perform real-device checks and record results**

Test one Android device and one iPhone for import, system TTS, cloud TTS, screen lock, headset commands, interruption, Wi-Fi transition, cache limit, process restart, dark mode, and large text. Record device OS versions and pass/fail results in `docs/testing/mobile-test-matrix.md`.

- [ ] **Step 5: Commit release documentation**

```powershell
git add README.md docs/testing .github/workflows/ci.yml integration_test
git commit -m "docs: add setup and mobile verification guide"
git push
```

Expected: the repository is clean and CI remains green.
