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
      if (await File(row.filePath).exists()) {
        cachedKeys.add(row.cacheKey);
      }
    }

    final result = <DownloadCandidate>[];
    final chapters = await _database.chaptersForBook(bookId);
    for (final chapter in chapters) {
      final paragraphs = await _database.paragraphsForChapter(chapter.id);
      for (final paragraph in paragraphs) {
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

  @override
  Future<int> totalCacheBytes() async {
    final total = _database.audioCacheEntries.byteSize.sum();
    final query = _database.selectOnly(_database.audioCacheEntries)
      ..addColumns([total])
      ..where(_database.audioCacheEntries.status.equals('complete'));
    final row = await query.getSingle();
    return row.read(total) ?? 0;
  }
}
