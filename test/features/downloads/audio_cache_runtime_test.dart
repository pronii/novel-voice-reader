import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/diagnostics/domain/playback_telemetry.dart';
import 'package:novel_voice_reader/features/downloads/application/audio_cache_runtime.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_task_dispatcher.dart';
import 'package:novel_voice_reader/features/downloads/domain/cache_key.dart';
import 'package:novel_voice_reader/features/downloads/domain/download_policy.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test('reconciles chapter audio into files and cache records', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final root = await Directory.systemTemp.createTemp('audio-cache-runtime');
    addTearDown(() async {
      await database.close();
      if (await root.exists()) await root.delete(recursive: true);
    });
    final bookId = await database.createBookWithChapter(
      title: '缓存测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。', '第二段。'],
    );
    final chapter = await database.firstChapterForBook(bookId);
    final paragraphs = await database.paragraphsForChapter(chapter.id);
    final dio = Dio()..httpClientAdapter = _AudioHttpAdapter();
    final runtime = AudioCacheRuntime(
      database: database,
      cacheDirectoryForBook: (id) =>
          Directory('${root.path}${Platform.pathSeparator}book-$id'),
      dio: dio,
      credentials: SecureCredentials(_MemorySecureStore()),
      networkGate: const AllowAllDownloadNetworkGate(),
    );
    addTearDown(runtime.dispose);
    final profile = VoiceProfile.cloud(
      baseUrl: 'https://example.com',
      model: 'tts-model',
      voice: 'voice-a',
      speed: 1,
      outputFormat: 'mp3',
    );

    final reconciliation = runtime.reconcile(
      bookId: bookId,
      chapterCount: 1,
      currentChapterIndex: 0,
      currentParagraphId: paragraphs.first.id,
      policy: DownloadPolicy(
        chaptersAhead: 0,
        wholeBook: false,
        wifiOnly: false,
        maxCacheBytes: DownloadPolicy.defaultMaxCacheBytes,
      ),
      profile: profile,
    );
    await runtime.waitForIdle();
    await reconciliation;

    final records = await database.select(database.audioCacheEntries).get();
    expect(records, hasLength(2));
    expect(
      await Future.wait(
        records.map((record) => File(record.filePath).exists()),
      ),
      everyElement(isTrue),
    );
  });

  test('restores persisted cache policies when the runtime starts', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final root = await Directory.systemTemp.createTemp('audio-cache-restore');
    addTearDown(() async {
      await database.close();
      if (await root.exists()) await root.delete(recursive: true);
    });
    final bookId = await database.createBookWithChapter(
      title: '恢复测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。', '第二段。'],
    );
    await _savePolicy(database, bookId, wifiOnly: false);
    final profile = _cloudProfile();
    final runtime = _runtime(
      database: database,
      root: root,
      activeProfileLoader: () async => profile,
    );
    addTearDown(runtime.dispose);

    await runtime.start();
    await runtime.waitForIdle();

    final records = await database.select(database.audioCacheEntries).get();
    expect(records, hasLength(2));
  });

  test('retries persisted work after connectivity changes', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final root = await Directory.systemTemp.createTemp('audio-cache-network');
    final connectivity = StreamController<List<ConnectivityResult>>.broadcast(
      sync: true,
    );
    addTearDown(() async {
      await connectivity.close();
      await database.close();
      if (await root.exists()) await root.delete(recursive: true);
    });
    final bookId = await database.createBookWithChapter(
      title: '网络恢复测试书',
      chapterTitle: '第一章',
      paragraphs: const ['等待网络。'],
    );
    await _savePolicy(database, bookId, wifiOnly: true);
    final gate = _MutableNetworkGate(false);
    final runtime = _runtime(
      database: database,
      root: root,
      activeProfileLoader: () async => _cloudProfile(),
      networkGate: gate,
      connectivityChanges: connectivity.stream,
    );
    addTearDown(runtime.dispose);

    await runtime.start();
    await runtime.waitForIdle();
    expect(await database.select(database.audioCacheEntries).get(), isEmpty);

    gate.canRunNow = true;
    connectivity.add(const [ConnectivityResult.wifi]);
    await runtime.waitForIdle();

    expect(
      await database.select(database.audioCacheEntries).get(),
      hasLength(1),
    );
  });

  test('lookup returns a warmed segment file without synthesizing', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final root = await Directory.systemTemp.createTemp('audio-cache-lookup');
    addTearDown(() async {
      await database.close();
      if (await root.exists()) await root.delete(recursive: true);
    });
    final bookId = await database.createBookWithChapter(
      title: '查找测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。'],
    );
    final adapter = _CountingAudioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final runtime = AudioCacheRuntime(
      database: database,
      cacheDirectoryForBook: (id) => _bookDir(root, id),
      dio: dio,
      credentials: SecureCredentials(_MemorySecureStore()),
      networkGate: const AllowAllDownloadNetworkGate(),
    );
    addTearDown(runtime.dispose);
    final profile = _cloudProfile();
    const segment = SpeechSegment(
      id: '1:0',
      paragraphId: 1,
      text: '第一段。',
      partIndex: 0,
    );

    final warmed = await runtime.obtain(
      bookId: bookId,
      segment: segment,
      profile: profile,
    );
    expect(adapter.fetchCount, 1);

    final cache = runtime.forBook(bookId);
    expect(cache, isA<LookupSpeechAudioCache>());
    final found = await (cache as LookupSpeechAudioCache).lookup(
      segment,
      profile,
    );

    expect(found != null, isTrue);
    expect(found!.path, warmed.path);
    expect(adapter.fetchCount, 1, reason: 'lookup must not synthesize');
  });

  test('lookup returns null on a miss without synthesizing', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final root = await Directory.systemTemp.createTemp('audio-cache-miss');
    addTearDown(() async {
      await database.close();
      if (await root.exists()) await root.delete(recursive: true);
    });
    final bookId = await database.createBookWithChapter(
      title: '缺失测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。'],
    );
    final adapter = _CountingAudioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final runtime = AudioCacheRuntime(
      database: database,
      cacheDirectoryForBook: (id) => _bookDir(root, id),
      dio: dio,
      credentials: SecureCredentials(_MemorySecureStore()),
      networkGate: const AllowAllDownloadNetworkGate(),
    );
    addTearDown(runtime.dispose);
    final profile = _cloudProfile();
    const segment = SpeechSegment(
      id: '1:0',
      paragraphId: 1,
      text: '还没有缓存。',
      partIndex: 0,
    );

    final found = await runtime.lookup(
      bookId: bookId,
      segment: segment,
      profile: profile,
    );

    expect(found, null);
    expect(adapter.fetchCount, 0, reason: 'a miss must never synthesize');
  });

  test('lookup treats a corrupt cache file as a miss', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final root = await Directory.systemTemp.createTemp('audio-cache-corrupt');
    addTearDown(() async {
      await database.close();
      if (await root.exists()) await root.delete(recursive: true);
    });
    final bookId = await database.createBookWithChapter(
      title: '损坏测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。'],
    );
    final adapter = _CountingAudioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final runtime = AudioCacheRuntime(
      database: database,
      cacheDirectoryForBook: (id) => _bookDir(root, id),
      dio: dio,
      credentials: SecureCredentials(_MemorySecureStore()),
      networkGate: const AllowAllDownloadNetworkGate(),
    );
    addTearDown(runtime.dispose);
    final profile = _cloudProfile();
    const segment = SpeechSegment(
      id: '1:0',
      paragraphId: 1,
      text: '损坏的缓存。',
      partIndex: 0,
    );

    final bookDir = _bookDir(root, bookId);
    await bookDir.create(recursive: true);
    final key = CacheKey.forSegment(segment, profile);
    final corrupt = File(
      '${bookDir.path}${Platform.pathSeparator}$key.mp3',
    );
    await corrupt.writeAsBytes(const [0x00, 0x00, 0x00, 0x00], flush: true);

    final found = await runtime.lookup(
      bookId: bookId,
      segment: segment,
      profile: profile,
    );

    expect(found, null);
    expect(await corrupt.exists(), isFalse);
    expect(adapter.fetchCount, 0, reason: 'a corrupt entry must never synthesize');
  });

  test('reports created, joined in-flight, and cache-hit obtains', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final root = await Directory.systemTemp.createTemp('audio-cache-in-flight');
    addTearDown(() async {
      await database.close();
      if (await root.exists()) await root.delete(recursive: true);
    });
    final bookId = await database.createBookWithChapter(
      title: '并发缓存测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。'],
    );
    final adapter = _ControllableServerAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final runtime = AudioCacheRuntime(
      database: database,
      cacheDirectoryForBook: (id) => _bookDir(root, id),
      dio: dio,
      credentials: SecureCredentials(_MemorySecureStore()),
      networkGate: const AllowAllDownloadNetworkGate(),
    );
    addTearDown(runtime.dispose);
    final profile = VoiceProfile.server(
      baseUrl: 'https://example.com',
      model: 'tts-model',
      voice: 'voice-a',
      speed: 1,
      outputFormat: 'mp3',
    );
    const segment = SpeechSegment(
      id: '1:0',
      paragraphId: 1,
      text: '第一段。',
      partIndex: 0,
    );

    final telemetry = _RecordingTelemetry();
    final warm = runtime.obtainTracked(
      bookId: bookId,
      segment: segment,
      profile: profile,
    );
    await adapter.waitForJobCreation();
    final confirmed = runtime.forBook(
      bookId,
      telemetry: telemetry,
      recordManualSeek: true,
    ).obtain(segment, profile);
    adapter.releaseAudio();
    final warmResult = await warm;
    final confirmedFile = await confirmed;

    expect(warmResult.source, AudioCacheObtainSource.created);
    expect(warmResult.file.path, confirmedFile.path);
    expect(adapter.jobCreations, 1);
    expect(
      telemetry.events.single.$2,
      containsPair('source', AudioCacheObtainSource.joinedInFlight.name),
    );

    final cached = await runtime.obtainTracked(
      bookId: bookId,
      segment: segment,
      profile: profile,
    );
    expect(cached.source, AudioCacheObtainSource.cacheHit);

    final cachedTelemetry = _RecordingTelemetry();
    final cachedConfirmed = await runtime.forBook(
      bookId,
      telemetry: cachedTelemetry,
      recordManualSeek: true,
    ).obtain(segment, profile);
    expect(cachedConfirmed.path, warmResult.file.path);
    expect(
      cachedTelemetry.events.single.$2,
      containsPair('source', AudioCacheObtainSource.cacheHit.name),
    );
    expect(adapter.jobCreations, 1);
  });

  test('manual-seek telemetry failures do not block cache obtains', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final root = await Directory.systemTemp.createTemp('audio-cache-telemetry');
    addTearDown(() async {
      await database.close();
      if (await root.exists()) await root.delete(recursive: true);
    });
    final bookId = await database.createBookWithChapter(
      title: '遥测隔离测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。'],
    );
    final runtime = AudioCacheRuntime(
      database: database,
      cacheDirectoryForBook: (id) => _bookDir(root, id),
      dio: Dio()..httpClientAdapter = _CountingAudioAdapter(),
      credentials: SecureCredentials(_MemorySecureStore()),
      networkGate: const AllowAllDownloadNetworkGate(),
    );
    addTearDown(runtime.dispose);
    const segment = SpeechSegment(
      id: '1:0',
      paragraphId: 1,
      text: '第一段。',
      partIndex: 0,
    );

    await expectLater(
      runtime.forBook(
        bookId,
        telemetry: _ThrowingTelemetry(),
        recordManualSeek: true,
      ).obtain(segment, _cloudProfile()),
      completes,
    );
  });

  test('records a confirmed seek when an obtain retry succeeds', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final root = await Directory.systemTemp.createTemp('audio-cache-retry');
    addTearDown(() async {
      await database.close();
      if (await root.exists()) await root.delete(recursive: true);
    });
    final bookId = await database.createBookWithChapter(
      title: '重试遥测测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。'],
    );
    final adapter = _FailOnceAudioAdapter();
    final runtime = AudioCacheRuntime(
      database: database,
      cacheDirectoryForBook: (id) => _bookDir(root, id),
      dio: Dio()..httpClientAdapter = adapter,
      credentials: SecureCredentials(_MemorySecureStore()),
      networkGate: const AllowAllDownloadNetworkGate(),
    );
    addTearDown(runtime.dispose);
    final telemetry = _RecordingTelemetry();
    final cache = runtime.forBook(
      bookId,
      telemetry: telemetry,
      recordManualSeek: true,
    );
    const segment = SpeechSegment(
      id: '1:0',
      paragraphId: 1,
      text: '第一段。',
      partIndex: 0,
    );

    await expectLater(
      cache.obtain(segment, _cloudProfile()),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(cache.obtain(segment, _cloudProfile()), completes);

    expect(adapter.fetchCount, 2);
    expect(telemetry.events, hasLength(1));
    expect(
      telemetry.events.single.$2,
      containsPair('source', AudioCacheObtainSource.created.name),
    );
  });
}

AudioCacheRuntime _runtime({
  required AppDatabase database,
  required Directory root,
  required Future<VoiceProfile> Function() activeProfileLoader,
  DownloadNetworkGate networkGate = const AllowAllDownloadNetworkGate(),
  Stream<List<ConnectivityResult>>? connectivityChanges,
}) {
  final dio = Dio()..httpClientAdapter = _AudioHttpAdapter();
  return AudioCacheRuntime(
    database: database,
    cacheDirectoryForBook: (id) =>
        Directory('${root.path}${Platform.pathSeparator}book-$id'),
    dio: dio,
    credentials: SecureCredentials(_MemorySecureStore()),
    networkGate: networkGate,
    activeProfileLoader: activeProfileLoader,
    connectivityChanges: connectivityChanges,
  );
}

Future<void> _savePolicy(
  AppDatabase database,
  int bookId, {
  required bool wifiOnly,
}) {
  return database
      .into(database.downloadPolicies)
      .insert(
        DownloadPoliciesCompanion.insert(
          bookId: Value(bookId),
          chaptersAhead: const Value(0),
          wholeBook: const Value(false),
          wifiOnly: Value(wifiOnly),
          maxCacheBytes: DownloadPolicy.defaultMaxCacheBytes,
        ),
      );
}

Directory _bookDir(Directory root, int bookId) =>
    Directory('${root.path}${Platform.pathSeparator}book-$bookId');

VoiceProfile _cloudProfile() => VoiceProfile.cloud(
  baseUrl: 'https://example.com',
  model: 'tts-model',
  voice: 'voice-a',
  speed: 1,
  outputFormat: 'mp3',
);

final class _MutableNetworkGate implements DownloadNetworkGate {
  _MutableNetworkGate(this.canRunNow);

  bool canRunNow;

  @override
  Future<bool> canRun({required bool requiresWifi}) async => canRunNow;
}

final class _MemorySecureStore implements SecureKeyValueStore {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => 'secret';

  @override
  Future<void> write(String key, String value) async {}
}

final class _AudioHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(const [
      0x49,
      0x44,
      0x33,
      0x04,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ], 200);
  }

  @override
  void close({bool force = false}) {}
}

final class _CountingAudioAdapter implements HttpClientAdapter {
  int fetchCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCount++;
    return ResponseBody.fromBytes(const [
      0x49,
      0x44,
      0x33,
      0x04,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ], 200);
  }

  @override
  void close({bool force = false}) {}
}

final class _FailOnceAudioAdapter implements HttpClientAdapter {
  int fetchCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCount++;
    if (fetchCount == 1) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<void>(requestOptions: options, statusCode: 400),
      );
    }
    return ResponseBody.fromBytes(const [
      0x49,
      0x44,
      0x33,
      0x04,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ], 200);
  }

  @override
  void close({bool force = false}) {}
}

final class _RecordingTelemetry implements PlaybackTelemetry {
  final List<(String, Map<String, Object?>)> events = [];

  @override
  void record(String name, [Map<String, Object?> fields = const {}]) {
    events.add((name, fields));
  }

  @override
  Future<void> flush() async {}
}

final class _ThrowingTelemetry implements PlaybackTelemetry {
  @override
  void record(String name, [Map<String, Object?> fields = const {}]) {
    throw StateError('telemetry failed');
  }

  @override
  Future<void> flush() async {}
}

final class _ControllableServerAdapter implements HttpClientAdapter {
  final Completer<void> _jobCreated = Completer<void>();
  final Completer<void> _audioReleased = Completer<void>();
  int jobCreations = 0;

  Future<void> waitForJobCreation() => _jobCreated.future;

  void releaseAudio() => _audioReleased.complete();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' && options.path.endsWith('/v1/jobs')) {
      jobCreations++;
      if (!_jobCreated.isCompleted) _jobCreated.complete();
      return _json('{"id":"job-1","status":"running"}');
    }
    if (options.path.endsWith('/v1/jobs/job-1')) {
      return _json('{"id":"job-1","status":"completed"}');
    }
    await _audioReleased.future;
    return ResponseBody.fromBytes(
      const [
        0x49,
        0x44,
        0x33,
        0x04,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
      ],
      200,
      headers: {
        Headers.contentTypeHeader: ['audio/mpeg'],
      },
    );
  }

  ResponseBody _json(String value) => ResponseBody.fromString(
    value,
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}
