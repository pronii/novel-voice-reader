import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/downloads/data/download_scheduler.dart';
import 'package:novel_voice_reader/features/downloads/domain/download_policy.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test(
    'orders current segment, current chapter, then later chapters',
    () async {
      final store = FakeDownloadPlanStore(
        candidates: [
          candidate(chapter: 4, paragraph: 40),
          candidate(chapter: 4, paragraph: 41),
          candidate(chapter: 5, paragraph: 50),
        ],
      );
      final dispatcher = FakeDownloadTaskDispatcher();
      final scheduler = DownloadScheduler(store: store, dispatcher: dispatcher);

      final result = await scheduler.reconcile(
        bookId: 7,
        chapterCount: 8,
        currentChapterIndex: 4,
        currentSegmentId: '41:0',
        policy: policy(chaptersAhead: 1, wifiOnly: true),
        profile: profile,
      );

      expect(dispatcher.requests.map((request) => request.taskId), [
        'cache-41-0',
        'cache-40-0',
        'cache-50-0',
      ]);
      expect(dispatcher.requests.map((request) => request.priority), [0, 1, 2]);
      expect(
        dispatcher.requests.every((request) => request.requiresWifi),
        isTrue,
      );
      expect(result.targetChapterIndexes, [4, 5]);
      expect(result.enqueuedTaskIds, [
        'cache-41-0',
        'cache-40-0',
        'cache-50-0',
      ]);
    },
  );

  test('zero chapters ahead queues the full current chapter', () async {
    final store = FakeDownloadPlanStore(
      candidates: [
        candidate(chapter: 4, paragraph: 40),
        candidate(chapter: 4, paragraph: 41, part: 0),
        candidate(chapter: 4, paragraph: 41, part: 1),
      ],
    );
    final dispatcher = FakeDownloadTaskDispatcher();
    final scheduler = DownloadScheduler(store: store, dispatcher: dispatcher);

    await scheduler.reconcile(
      bookId: 7,
      chapterCount: 8,
      currentChapterIndex: 4,
      currentSegmentId: '41:1',
      policy: policy(chaptersAhead: 0),
      profile: profile,
    );

    expect(dispatcher.requests.map((request) => request.taskId), [
      'cache-41-1',
      'cache-40-0',
      'cache-41-0',
    ]);
  });

  test('cancels only not-started jobs outside the new window', () async {
    final store = FakeDownloadPlanStore(
      candidates: [
        candidate(chapter: 1, paragraph: 10),
        candidate(chapter: 1, paragraph: 11),
        candidate(chapter: 1, paragraph: 12),
        candidate(chapter: 4, paragraph: 40, cached: true),
      ],
      jobs: [
        job('cache-10-0', chapter: 1, status: DownloadJobStatus.enqueued),
        job('cache-11-0', chapter: 1, status: DownloadJobStatus.running),
        job('cache-12-0', chapter: 1, status: DownloadJobStatus.complete),
      ],
    );
    final dispatcher = FakeDownloadTaskDispatcher();
    final scheduler = DownloadScheduler(store: store, dispatcher: dispatcher);

    final result = await scheduler.reconcile(
      bookId: 7,
      chapterCount: 8,
      currentChapterIndex: 4,
      currentSegmentId: '40:0',
      policy: policy(chaptersAhead: 0),
      profile: profile,
    );

    expect(dispatcher.canceledTaskIds, ['cache-10-0']);
    expect(store.statuses['cache-10-0'], DownloadJobStatus.canceled);
    expect(store.statuses.containsKey('cache-11-0'), isFalse);
    expect(store.statuses.containsKey('cache-12-0'), isFalse);
    expect(result.canceledTaskIds, ['cache-10-0']);
  });

  test('stops queuing before the estimated cache limit', () async {
    final store = FakeDownloadPlanStore(
      cacheBytes: 900,
      candidates: [
        candidate(chapter: 4, paragraph: 40, estimatedBytes: 80),
        candidate(chapter: 4, paragraph: 41, estimatedBytes: 80),
      ],
    );
    final dispatcher = FakeDownloadTaskDispatcher();
    final scheduler = DownloadScheduler(store: store, dispatcher: dispatcher);

    final result = await scheduler.reconcile(
      bookId: 7,
      chapterCount: 8,
      currentChapterIndex: 4,
      currentSegmentId: '40:0',
      policy: policy(chaptersAhead: 1, maxCacheBytes: 1000),
      profile: profile,
    );

    expect(dispatcher.requests.map((request) => request.taskId), [
      'cache-40-0',
    ]);
    expect(result.cacheLimitReached, isTrue);
  });

  test(
    'reserves capacity for old-profile work outside the new window',
    () async {
      final store = FakeDownloadPlanStore(
        candidates: [
          candidate(chapter: 1, paragraph: 10, estimatedBytes: 80),
          candidate(chapter: 4, paragraph: 40, estimatedBytes: 40),
        ],
        jobs: [
          job('legacy-10-0', chapter: 1, status: DownloadJobStatus.running),
        ],
      );
      final dispatcher = FakeDownloadTaskDispatcher();
      final scheduler = DownloadScheduler(store: store, dispatcher: dispatcher);

      final result = await scheduler.reconcile(
        bookId: 7,
        chapterCount: 8,
        currentChapterIndex: 4,
        currentSegmentId: '40:0',
        policy: policy(chaptersAhead: 0, maxCacheBytes: 100),
        profile: profile,
      );

      expect(dispatcher.requests, isEmpty);
      expect(result.cacheLimitReached, isTrue);
    },
  );

  test('retries a pending job during the next reconciliation', () async {
    final store = FakeDownloadPlanStore(
      candidates: [candidate(chapter: 4, paragraph: 40)],
    );
    final dispatcher = FakeDownloadTaskDispatcher(results: [false, true]);
    final scheduler = DownloadScheduler(store: store, dispatcher: dispatcher);

    final first = await scheduler.reconcile(
      bookId: 7,
      chapterCount: 8,
      currentChapterIndex: 4,
      currentSegmentId: '40:0',
      policy: policy(chaptersAhead: 0),
      profile: profile,
    );
    final second = await scheduler.reconcile(
      bookId: 7,
      chapterCount: 8,
      currentChapterIndex: 4,
      currentSegmentId: '40:0',
      policy: policy(chaptersAhead: 0),
      profile: profile,
    );

    expect(first.enqueuedTaskIds, isEmpty);
    expect(second.enqueuedTaskIds, ['cache-40-0']);
    expect(dispatcher.requests, hasLength(2));
    expect(store.statuses['cache-40-0'], DownloadJobStatus.enqueued);
  });

  test('does not overwrite active jobs during reconciliation', () async {
    final store = FakeDownloadPlanStore(
      candidates: [
        candidate(chapter: 4, paragraph: 40),
        candidate(chapter: 4, paragraph: 41),
      ],
      jobs: [
        job('cache-40-0', chapter: 4, status: DownloadJobStatus.enqueued),
        job('cache-41-0', chapter: 4, status: DownloadJobStatus.running),
      ],
    );
    final dispatcher = FakeDownloadTaskDispatcher();
    final scheduler = DownloadScheduler(store: store, dispatcher: dispatcher);

    final result = await scheduler.reconcile(
      bookId: 7,
      chapterCount: 8,
      currentChapterIndex: 4,
      currentSegmentId: '40:0',
      policy: policy(chaptersAhead: 0),
      profile: profile,
    );

    expect(dispatcher.requests.map((request) => request.taskId), [
      'cache-40-0',
      'cache-41-0',
    ]);
    expect(store.statuses, isEmpty);
    expect(result.enqueuedTaskIds, isEmpty);
  });

  test(
    'returns a persisted active job to pending when restore is rejected',
    () async {
      final store = FakeDownloadPlanStore(
        candidates: [candidate(chapter: 4, paragraph: 40)],
        jobs: [
          job('cache-40-0', chapter: 4, status: DownloadJobStatus.enqueued),
        ],
      );
      final dispatcher = FakeDownloadTaskDispatcher(results: [false]);
      final scheduler = DownloadScheduler(store: store, dispatcher: dispatcher);

      await scheduler.reconcile(
        bookId: 7,
        chapterCount: 8,
        currentChapterIndex: 4,
        currentSegmentId: '40:0',
        policy: policy(chaptersAhead: 0),
        profile: profile,
      );

      expect(store.statuses['cache-40-0'], DownloadJobStatus.pending);
    },
  );

  test('keeps a rejected dispatch pending', () async {
    final store = FakeDownloadPlanStore(
      candidates: [candidate(chapter: 4, paragraph: 40)],
    );
    final dispatcher = FakeDownloadTaskDispatcher(results: [false]);
    final scheduler = DownloadScheduler(store: store, dispatcher: dispatcher);

    await scheduler.reconcile(
      bookId: 7,
      chapterCount: 8,
      currentChapterIndex: 4,
      currentSegmentId: '40:0',
      policy: policy(chaptersAhead: 0),
      profile: profile,
    );

    expect(store.statuses['cache-40-0'], DownloadJobStatus.pending);
  });
}

final profile = VoiceProfile.cloud(
  baseUrl: 'https://example.com',
  model: 'tts-model',
  voice: 'voice-a',
  speed: 1,
  outputFormat: 'mp3',
);

DownloadPolicy policy({
  required int chaptersAhead,
  bool wifiOnly = false,
  int maxCacheBytes = 1024 * 1024,
}) {
  return DownloadPolicy(
    chaptersAhead: chaptersAhead,
    wholeBook: false,
    wifiOnly: wifiOnly,
    maxCacheBytes: maxCacheBytes,
  );
}

DownloadCandidate candidate({
  required int chapter,
  required int paragraph,
  int part = 0,
  int estimatedBytes = 10,
  bool cached = false,
}) {
  return DownloadCandidate(
    cacheKey: 'cache-$paragraph-$part',
    chapterIndex: chapter,
    paragraphIndex: paragraph,
    segment: SpeechSegment(
      id: '$paragraph:$part',
      paragraphId: paragraph,
      text: '正文 $paragraph:$part',
      partIndex: part,
    ),
    estimatedBytes: estimatedBytes,
    cached: cached,
  );
}

DownloadJobSnapshot job(
  String taskId, {
  required int chapter,
  required DownloadJobStatus status,
}) {
  return DownloadJobSnapshot(
    taskId: taskId,
    bookId: 7,
    chapterIndex: chapter,
    paragraphId: int.parse(taskId.split('-')[1]),
    status: status,
    retryCount: 0,
  );
}

final class FakeDownloadPlanStore implements DownloadPlanStore {
  FakeDownloadPlanStore({
    required this.candidates,
    this.jobs = const [],
    this.cacheBytes = 0,
  });

  final List<DownloadCandidate> candidates;
  final List<DownloadJobSnapshot> jobs;
  final int cacheBytes;
  final Map<String, DownloadJobStatus> statuses = {};

  @override
  Future<List<DownloadCandidate>> candidatesForBook(
    int bookId,
    VoiceProfile profile,
  ) async {
    return candidates;
  }

  @override
  Future<List<DownloadJobSnapshot>> jobsForBook(int bookId) async {
    return [
      for (final item in jobs)
        item.copyWith(status: statuses[item.taskId] ?? item.status),
      for (final entry in statuses.entries)
        if (jobs.every((item) => item.taskId != entry.key))
          DownloadJobSnapshot(
            taskId: entry.key,
            bookId: bookId,
            chapterIndex: candidates
                .singleWhere((item) => item.cacheKey == entry.key)
                .chapterIndex,
            paragraphId: candidates
                .singleWhere((item) => item.cacheKey == entry.key)
                .segment
                .paragraphId,
            status: entry.value,
            retryCount: 0,
          ),
    ];
  }

  @override
  Future<void> putJob(DownloadJobSnapshot job) async {
    statuses[job.taskId] = job.status;
  }

  @override
  Future<void> setJobStatus(
    String taskId,
    DownloadJobStatus status, {
    int? retryCount,
  }) async {
    statuses[taskId] = status;
  }

  @override
  Future<int> totalCacheBytes(int bookId) async => cacheBytes;
}

final class FakeDownloadTaskDispatcher implements DownloadTaskDispatcher {
  FakeDownloadTaskDispatcher({List<bool>? results})
    : _results = results ?? <bool>[];

  final List<bool> _results;
  final List<DownloadDispatchRequest> requests = [];
  final List<String> canceledTaskIds = [];

  @override
  Future<bool> cancel(String taskId) async {
    canceledTaskIds.add(taskId);
    return true;
  }

  @override
  Future<bool> enqueue(DownloadDispatchRequest request) async {
    requests.add(request);
    if (_results.isEmpty) {
      return true;
    }
    return _results.removeAt(0);
  }
}
