import 'dart:io';

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
    expect(await store.totalCacheBytes(), 4);
  });
}

final profile = VoiceProfile.cloud(
  baseUrl: 'https://example.com',
  model: 'tts-model',
  voice: 'voice-a',
  speed: 1,
  outputFormat: 'mp3',
);
