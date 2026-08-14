import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/downloads/application/audio_cache_runtime.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_task_dispatcher.dart';
import 'package:novel_voice_reader/features/downloads/domain/download_policy.dart';
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
