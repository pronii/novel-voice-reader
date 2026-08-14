import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_task_dispatcher.dart';
import 'package:novel_voice_reader/features/downloads/data/download_scheduler.dart';
import 'package:novel_voice_reader/features/downloads/domain/cache_key.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

final class DriftDownloadPlanStore
    implements DownloadPlanStore, DownloadExecutionStore {
  factory DriftDownloadPlanStore(
    AppDatabase database, {
    SpeechSegmenter segmenter = const SpeechSegmenter(),
  }) {
    return DriftDownloadPlanStore._(database, segmenter);
  }

  const DriftDownloadPlanStore._(this._database, this._segmenter);

  final AppDatabase _database;
  final SpeechSegmenter _segmenter;

  @override
  Future<List<DownloadCandidate>> candidatesForBook(
    int bookId,
    VoiceProfile profile,
  ) async {
    final cachedRows =
        await (_database.select(_database.audioCacheEntries)..where(
              (entry) =>
                  entry.bookId.equals(bookId) & entry.status.equals('complete'),
            ))
            .get();
    final cachedKeys = <String>{};
    for (final row in cachedRows) {
      final file = File(row.filePath);
      if (await file.exists()) {
        cachedKeys.add(row.cacheKey);
      } else {
        await _deleteCacheRecord(row.cacheKey);
      }
    }

    final result = <DownloadCandidate>[];
    final query =
        _database.select(_database.paragraphs).join([
            innerJoin(
              _database.chapters,
              _database.chapters.id.equalsExp(_database.paragraphs.chapterId),
            ),
          ])
          ..where(_database.chapters.bookId.equals(bookId))
          ..orderBy([
            OrderingTerm.asc(_database.chapters.chapterIndex),
            OrderingTerm.asc(_database.paragraphs.paragraphIndex),
          ]);
    for (final row in await query.get()) {
      final chapter = row.readTable(_database.chapters);
      final paragraph = row.readTable(_database.paragraphs);
      final segments = _segmenter.split(
        paragraphId: paragraph.id,
        text: paragraph.content,
        maxCharacters: profile.maxSegmentCharacters,
      );
      for (final segment in segments) {
        final cacheKey = CacheKey.forSegment(segment, profile);
        result.add(
          DownloadCandidate(
            cacheKey: cacheKey,
            chapterId: chapter.id,
            chapterIndex: chapter.chapterIndex,
            paragraphIndex: paragraph.paragraphIndex,
            segment: segment,
            estimatedBytes: max(4096, segment.text.runes.length * 4000),
            cached: cachedKeys.contains(cacheKey),
          ),
        );
      }
    }
    return result;
  }

  @override
  Future<List<DownloadJobSnapshot>> jobsForBook(int bookId) async {
    final query = _database.select(_database.downloadJobs).join([
      innerJoin(
        _database.paragraphs,
        _database.paragraphs.id.equalsExp(_database.downloadJobs.paragraphId),
      ),
      innerJoin(
        _database.chapters,
        _database.chapters.id.equalsExp(_database.paragraphs.chapterId),
      ),
    ])..where(_database.chapters.bookId.equals(bookId));
    final rows = await query.get();
    return [
      for (final row in rows)
        DownloadJobSnapshot(
          taskId: row.readTable(_database.downloadJobs).cacheKey,
          bookId: bookId,
          chapterIndex: row.readTable(_database.chapters).chapterIndex,
          paragraphId: row.readTable(_database.downloadJobs).paragraphId,
          status: DownloadJobStatus.values.byName(
            row.readTable(_database.downloadJobs).status,
          ),
          retryCount: row.readTable(_database.downloadJobs).retryCount,
          priority: row.readTable(_database.downloadJobs).priority,
        ),
    ];
  }

  @override
  Future<void> putJob(DownloadJobSnapshot job) async {
    await _database
        .into(_database.downloadJobs)
        .insertOnConflictUpdate(
          DownloadJobsCompanion.insert(
            paragraphId: job.paragraphId,
            cacheKey: job.taskId,
            priority: job.priority,
            retryCount: Value(job.retryCount),
            status: job.status.name,
          ),
        );
  }

  @override
  Future<void> setJobStatus(
    String taskId,
    DownloadJobStatus status, {
    int? retryCount,
  }) async {
    await (_database.update(
      _database.downloadJobs,
    )..where((job) => job.cacheKey.equals(taskId))).write(
      DownloadJobsCompanion(
        status: Value(status.name),
        retryCount: retryCount == null
            ? const Value.absent()
            : Value(retryCount),
      ),
    );
  }

  @override
  Future<void> incrementFailure(String taskId) {
    return _database.transaction(() async {
      final record = await (_database.select(
        _database.downloadJobs,
      )..where((job) => job.cacheKey.equals(taskId))).getSingle();
      await setJobStatus(
        taskId,
        DownloadJobStatus.failed,
        retryCount: record.retryCount + 1,
      );
    });
  }

  @override
  Future<void> recordCompleted(
    DownloadDispatchRequest request,
    File file,
  ) async {
    final byteSize = await file.length();
    await _database
        .into(_database.audioCacheEntries)
        .insertOnConflictUpdate(
          AudioCacheEntriesCompanion.insert(
            cacheKey: request.taskId,
            bookId: request.bookId,
            chapterId: request.candidate.chapterId,
            paragraphId: request.candidate.segment.paragraphId,
            filePath: file.path,
            byteSize: byteSize,
            status: 'complete',
            lastAccessedAt: DateTime.now(),
          ),
        );
  }

  Future<void> recordCachedFile({
    required int bookId,
    required SpeechSegment segment,
    required VoiceProfile profile,
    required File file,
  }) async {
    final paragraph = await (_database.select(
      _database.paragraphs,
    )..where((row) => row.id.equals(segment.paragraphId))).getSingleOrNull();
    if (paragraph == null) {
      return;
    }
    final cacheKey = CacheKey.forSegment(segment, profile);
    await _database
        .into(_database.audioCacheEntries)
        .insertOnConflictUpdate(
          AudioCacheEntriesCompanion.insert(
            cacheKey: cacheKey,
            bookId: bookId,
            chapterId: paragraph.chapterId,
            paragraphId: paragraph.id,
            filePath: file.path,
            byteSize: await file.length(),
            status: 'complete',
            lastAccessedAt: DateTime.now(),
          ),
        );
  }

  Future<int> pruneToLimit({
    required int bookId,
    required int maxBytes,
    Set<String> protectedKeys = const {},
  }) async {
    final query = _database.select(_database.audioCacheEntries)
      ..where(
        (entry) =>
            entry.bookId.equals(bookId) & entry.status.equals('complete'),
      )
      ..orderBy([(entry) => OrderingTerm.asc(entry.lastAccessedAt)]);
    final rows = await query.get();
    var totalBytes = 0;
    final existing = <({AudioCacheRecord record, File file, int bytes})>[];
    for (final record in rows) {
      final file = File(record.filePath);
      if (!await file.exists()) {
        await _deleteCacheRecord(record.cacheKey);
        continue;
      }
      final bytes = await file.length();
      totalBytes += bytes;
      existing.add((record: record, file: file, bytes: bytes));
    }
    for (final entry in existing) {
      if (totalBytes <= maxBytes) {
        break;
      }
      if (protectedKeys.contains(entry.record.cacheKey)) {
        continue;
      }
      try {
        await entry.file.delete();
      } on FileSystemException {
        continue;
      }
      await _deleteCacheRecord(entry.record.cacheKey);
      totalBytes -= entry.bytes;
    }
    return totalBytes;
  }

  Future<void> _deleteCacheRecord(String cacheKey) async {
    await (_database.delete(
      _database.audioCacheEntries,
    )..where((entry) => entry.cacheKey.equals(cacheKey))).go();
  }

  @override
  Future<int> totalCacheBytes(int bookId) async {
    final total = _database.audioCacheEntries.byteSize.sum();
    final query = _database.selectOnly(_database.audioCacheEntries)
      ..addColumns([total])
      ..where(
        _database.audioCacheEntries.bookId.equals(bookId) &
            _database.audioCacheEntries.status.equals('complete'),
      );
    final row = await query.getSingle();
    return row.read(total) ?? 0;
  }

  Future<DownloadPolicyRecord?> policyForBook(int bookId) {
    return (_database.select(
      _database.downloadPolicies,
    )..where((policy) => policy.bookId.equals(bookId))).getSingleOrNull();
  }
}
