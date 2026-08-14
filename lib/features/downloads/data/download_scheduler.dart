import 'package:novel_voice_reader/features/downloads/domain/download_policy.dart';
import 'package:novel_voice_reader/features/downloads/domain/download_window.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

enum DownloadJobStatus {
  pending,
  enqueued,
  running,
  complete,
  failed,
  canceled,
}

final class DownloadCandidate {
  const DownloadCandidate({
    required this.cacheKey,
    this.chapterId = -1,
    required this.chapterIndex,
    required this.paragraphIndex,
    required this.segment,
    required this.estimatedBytes,
    required this.cached,
  });

  final String cacheKey;
  final int chapterId;
  final int chapterIndex;
  final int paragraphIndex;
  final SpeechSegment segment;
  final int estimatedBytes;
  final bool cached;
}

final class DownloadJobSnapshot {
  const DownloadJobSnapshot({
    required this.taskId,
    required this.bookId,
    required this.chapterIndex,
    required this.paragraphId,
    required this.status,
    required this.retryCount,
    this.priority = 10,
  });

  final String taskId;
  final int bookId;
  final int chapterIndex;
  final int paragraphId;
  final DownloadJobStatus status;
  final int retryCount;
  final int priority;

  DownloadJobSnapshot copyWith({DownloadJobStatus? status, int? retryCount}) {
    return DownloadJobSnapshot(
      taskId: taskId,
      bookId: bookId,
      chapterIndex: chapterIndex,
      paragraphId: paragraphId,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      priority: priority,
    );
  }
}

abstract interface class DownloadPlanStore {
  Future<List<DownloadCandidate>> candidatesForBook(
    int bookId,
    VoiceProfile profile,
  );

  Future<List<DownloadJobSnapshot>> jobsForBook(int bookId);

  Future<int> totalCacheBytes();

  Future<void> putJob(DownloadJobSnapshot job);

  Future<void> setJobStatus(
    String taskId,
    DownloadJobStatus status, {
    int? retryCount,
  });
}

final class DownloadDispatchRequest {
  const DownloadDispatchRequest({
    required this.taskId,
    required this.bookId,
    required this.candidate,
    required this.profile,
    required this.priority,
    required this.requiresWifi,
  });

  final String taskId;
  final int bookId;
  final DownloadCandidate candidate;
  final VoiceProfile profile;
  final int priority;
  final bool requiresWifi;
}

abstract interface class DownloadTaskDispatcher {
  Future<bool> enqueue(DownloadDispatchRequest request);

  Future<bool> cancel(String taskId);
}

final class DownloadReconcileResult {
  const DownloadReconcileResult({
    required this.targetChapterIndexes,
    required this.enqueuedTaskIds,
    required this.canceledTaskIds,
    required this.cacheLimitReached,
  });

  final List<int> targetChapterIndexes;
  final List<String> enqueuedTaskIds;
  final List<String> canceledTaskIds;
  final bool cacheLimitReached;
}

final class DownloadScheduler {
  factory DownloadScheduler({
    required DownloadPlanStore store,
    required DownloadTaskDispatcher dispatcher,
  }) {
    return DownloadScheduler._(store, dispatcher);
  }

  const DownloadScheduler._(this._store, this._dispatcher);

  final DownloadPlanStore _store;
  final DownloadTaskDispatcher _dispatcher;

  Future<DownloadReconcileResult> reconcile({
    required int bookId,
    required int chapterCount,
    required int currentChapterIndex,
    required String currentSegmentId,
    required DownloadPolicy policy,
    required VoiceProfile profile,
  }) async {
    final targetChapters = DownloadWindow.calculate(
      currentChapterIndex: currentChapterIndex,
      chaptersAhead: policy.chaptersAhead,
      wholeBook: policy.wholeBook,
      chapterCount: chapterCount,
    );
    final targetChapterSet = targetChapters.toSet();
    final allCandidates = await _store.candidatesForBook(bookId, profile);
    var targetCandidates = allCandidates
        .where((candidate) => targetChapterSet.contains(candidate.chapterIndex))
        .toList();
    if (!policy.wholeBook && policy.chaptersAhead == 0) {
      targetCandidates = targetCandidates
          .where((candidate) => candidate.segment.id == currentSegmentId)
          .toList();
    }
    targetCandidates.sort(
      (first, second) => _compareCandidates(
        first,
        second,
        currentChapterIndex,
        currentSegmentId,
      ),
    );

    final targetIds = {
      for (final candidate in targetCandidates) candidate.cacheKey,
    };
    final jobs = await _store.jobsForBook(bookId);
    final jobsById = {for (final job in jobs) job.taskId: job};
    final canceledTaskIds = <String>[];
    for (final job in jobs) {
      if (targetIds.contains(job.taskId)) {
        continue;
      }
      final canceled = switch (job.status) {
        DownloadJobStatus.pending || DownloadJobStatus.failed => true,
        DownloadJobStatus.enqueued => await _dispatcher.cancel(job.taskId),
        _ => false,
      };
      if (canceled) {
        await _store.setJobStatus(job.taskId, DownloadJobStatus.canceled);
        canceledTaskIds.add(job.taskId);
      }
    }

    final candidatesById = {
      for (final candidate in targetCandidates) candidate.cacheKey: candidate,
    };
    var remainingBytes = policy.maxCacheBytes - await _store.totalCacheBytes();
    for (final job in jobs) {
      if (job.status == DownloadJobStatus.enqueued ||
          job.status == DownloadJobStatus.running) {
        remainingBytes -= candidatesById[job.taskId]?.estimatedBytes ?? 0;
      }
    }

    var cacheLimitReached = remainingBytes < 0;
    final enqueuedTaskIds = <String>[];
    for (final candidate in targetCandidates) {
      if (candidate.cached) {
        continue;
      }
      final existing = jobsById[candidate.cacheKey];
      if (existing != null &&
          (existing.status == DownloadJobStatus.enqueued ||
              existing.status == DownloadJobStatus.running ||
              existing.status == DownloadJobStatus.complete)) {
        continue;
      }
      if (existing != null &&
          existing.status == DownloadJobStatus.failed &&
          existing.retryCount >= 3) {
        continue;
      }
      if (candidate.estimatedBytes > remainingBytes) {
        // Skip this candidate but keep scanning: a later, smaller candidate may
        // still fit within the remaining cache budget.
        cacheLimitReached = true;
        continue;
      }
      remainingBytes -= candidate.estimatedBytes;

      final priority = _priorityFor(
        candidate,
        currentChapterIndex,
        currentSegmentId,
      );
      final pendingJob = DownloadJobSnapshot(
        taskId: candidate.cacheKey,
        bookId: bookId,
        chapterIndex: candidate.chapterIndex,
        paragraphId: candidate.segment.paragraphId,
        status: DownloadJobStatus.pending,
        retryCount: existing?.retryCount ?? 0,
        priority: priority,
      );
      await _store.putJob(pendingJob);
      final accepted = await _dispatcher.enqueue(
        DownloadDispatchRequest(
          taskId: candidate.cacheKey,
          bookId: bookId,
          candidate: candidate,
          profile: profile,
          priority: priority,
          requiresWifi: policy.wifiOnly,
        ),
      );
      if (accepted) {
        await _store.setJobStatus(
          candidate.cacheKey,
          DownloadJobStatus.enqueued,
        );
        enqueuedTaskIds.add(candidate.cacheKey);
      }
    }

    return DownloadReconcileResult(
      targetChapterIndexes: targetChapters,
      enqueuedTaskIds: enqueuedTaskIds,
      canceledTaskIds: canceledTaskIds,
      cacheLimitReached: cacheLimitReached,
    );
  }

  static int _compareCandidates(
    DownloadCandidate first,
    DownloadCandidate second,
    int currentChapterIndex,
    String currentSegmentId,
  ) {
    final priorityComparison = _priorityFor(
      first,
      currentChapterIndex,
      currentSegmentId,
    ).compareTo(_priorityFor(second, currentChapterIndex, currentSegmentId));
    if (priorityComparison != 0) {
      return priorityComparison;
    }
    final chapterComparison = first.chapterIndex.compareTo(second.chapterIndex);
    if (chapterComparison != 0) {
      return chapterComparison;
    }
    final paragraphComparison = first.paragraphIndex.compareTo(
      second.paragraphIndex,
    );
    if (paragraphComparison != 0) {
      return paragraphComparison;
    }
    return first.segment.partIndex.compareTo(second.segment.partIndex);
  }

  static int _priorityFor(
    DownloadCandidate candidate,
    int currentChapterIndex,
    String currentSegmentId,
  ) {
    if (candidate.segment.id == currentSegmentId) {
      return 0;
    }
    if (candidate.chapterIndex == currentChapterIndex) {
      return 1;
    }
    return (candidate.chapterIndex - currentChapterIndex + 1).clamp(2, 10);
  }
}
