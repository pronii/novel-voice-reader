import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/downloads/data/download_plan_store.dart';
import 'package:novel_voice_reader/features/downloads/data/download_scheduler.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  late AppDatabase database;
  late DriftDownloadPlanStore store;
  late Directory directory;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = DriftDownloadPlanStore(database);
    directory = await Directory.systemTemp.createTemp('download-store-test');
  });

  tearDown(() async {
    await database.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('builds candidates and persists only non-sensitive job data', () async {
    final bookId = await database.createBookWithChapter(
      title: '测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。', '第二段。'],
    );

    final candidates = await store.candidatesForBook(bookId, profile);
    final first = candidates.first;
    await store.putJob(
      DownloadJobSnapshot(
        taskId: first.cacheKey,
        bookId: bookId,
        chapterIndex: first.chapterIndex,
        paragraphId: first.segment.paragraphId,
        status: DownloadJobStatus.pending,
        retryCount: 0,
        priority: 0,
      ),
    );

    final jobs = await store.jobsForBook(bookId);
    final rawJobs = await database.select(database.downloadJobs).get();

    expect(candidates, hasLength(2));
    expect(
      candidates.every((candidate) => candidate.estimatedBytes > 0),
      isTrue,
    );
    expect(jobs.single.taskId, first.cacheKey);
    expect(jobs.single.priority, 0);
    expect(rawJobs.single.cacheKey, isNot(contains('第一段')));
    expect(rawJobs.single.status, 'pending');
  });

  test('records completed audio and includes it in cache usage', () async {
    final bookId = await database.createBookWithChapter(
      title: '测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。'],
    );
    final candidate = (await store.candidatesForBook(bookId, profile)).single;
    final file = File(
      '${directory.path}${Platform.pathSeparator}${candidate.cacheKey}.mp3',
    );
    await file.writeAsBytes([1, 2, 3, 4]);
    final request = DownloadDispatchRequest(
      taskId: candidate.cacheKey,
      bookId: bookId,
      candidate: candidate,
      profile: profile,
      priority: 0,
      requiresWifi: false,
    );

    await store.recordCompleted(request, file);

    final refreshed = await store.candidatesForBook(bookId, profile);
    expect(refreshed.single.cached, isTrue);
    expect(await store.totalCacheBytes(bookId), 4);
  });

  test('calculates cache usage independently for each book', () async {
    final firstBookId = await database.createBookWithChapter(
      title: '第一本书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。'],
    );
    final secondBookId = await database.createBookWithChapter(
      title: '第二本书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。'],
    );
    final first = (await store.candidatesForBook(firstBookId, profile)).single;
    final second = (await store.candidatesForBook(
      secondBookId,
      profile,
    )).single;
    final firstFile = File(
      '${directory.path}${Platform.pathSeparator}first.mp3',
    );
    final secondFile = File(
      '${directory.path}${Platform.pathSeparator}second.mp3',
    );
    await firstFile.writeAsBytes([1, 2, 3]);
    await secondFile.writeAsBytes([4, 5, 6, 7, 8]);

    await store.recordCompleted(_request(firstBookId, first), firstFile);
    await store.recordCompleted(_request(secondBookId, second), secondFile);

    expect(await store.totalCacheBytes(firstBookId), 3);
    expect(await store.totalCacheBytes(secondBookId), 5);
    expect(
      await database.select(database.audioCacheEntries).get(),
      hasLength(2),
    );
  });

  test('splits MiMo download candidates at 360 characters', () async {
    final bookId = await database.createBookWithChapter(
      title: 'MiMo缓存测试',
      chapterTitle: '第一章',
      paragraphs: [List.filled(361, '文').join()],
    );

    final candidates = await store.candidatesForBook(
      bookId,
      VoiceProfile.mimo(),
    );

    expect(candidates, hasLength(2));
    expect(candidates.first.segment.text.runes.length, 360);
    expect(candidates.last.segment.text.runes.length, 1);
  });

  test('evicts the least recently used file above the book limit', () async {
    final bookId = await database.createBookWithChapter(
      title: '容量测试',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。', '第二段。'],
    );
    final candidates = await store.candidatesForBook(bookId, profile);
    final firstFile = File(
      '${directory.path}${Platform.pathSeparator}${candidates[0].cacheKey}.mp3',
    );
    final secondFile = File(
      '${directory.path}${Platform.pathSeparator}${candidates[1].cacheKey}.mp3',
    );
    await firstFile.writeAsBytes([1, 2, 3, 4]);
    await secondFile.writeAsBytes([5, 6, 7, 8]);
    await store.recordCompleted(
      DownloadDispatchRequest(
        taskId: candidates[0].cacheKey,
        bookId: bookId,
        candidate: candidates[0],
        profile: profile,
        priority: 0,
        requiresWifi: false,
      ),
      firstFile,
    );
    await store.recordCompleted(
      DownloadDispatchRequest(
        taskId: candidates[1].cacheKey,
        bookId: bookId,
        candidate: candidates[1],
        profile: profile,
        priority: 1,
        requiresWifi: false,
      ),
      secondFile,
    );
    await (database.update(
      database.audioCacheEntries,
    )..where((entry) => entry.cacheKey.equals(candidates[0].cacheKey))).write(
      AudioCacheEntriesCompanion(
        lastAccessedAt: Value(DateTime.utc(2026, 1, 1)),
      ),
    );
    await (database.update(
      database.audioCacheEntries,
    )..where((entry) => entry.cacheKey.equals(candidates[1].cacheKey))).write(
      AudioCacheEntriesCompanion(
        lastAccessedAt: Value(DateTime.utc(2026, 1, 2)),
      ),
    );

    final remaining = await store.pruneToLimit(bookId: bookId, maxBytes: 4);

    expect(remaining, 4);
    expect(await firstFile.exists(), isFalse);
    expect(await secondFile.exists(), isTrue);
  });
}

DownloadDispatchRequest _request(int bookId, DownloadCandidate candidate) {
  return DownloadDispatchRequest(
    taskId: candidate.cacheKey,
    bookId: bookId,
    candidate: candidate,
    profile: profile,
    priority: 0,
    requiresWifi: false,
  );
}

final profile = VoiceProfile.cloud(
  baseUrl: 'https://example.com',
  model: 'tts-model',
  voice: 'voice-a',
  speed: 1,
  outputFormat: 'mp3',
);
