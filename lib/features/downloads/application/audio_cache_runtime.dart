import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/diagnostics/domain/playback_telemetry.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_task_dispatcher.dart';
import 'package:novel_voice_reader/features/downloads/data/download_plan_store.dart';
import 'package:novel_voice_reader/features/downloads/data/download_scheduler.dart';
import 'package:novel_voice_reader/features/downloads/domain/cache_key.dart';
import 'package:novel_voice_reader/features/downloads/domain/download_policy.dart';
import 'package:novel_voice_reader/features/speech/data/cloud_tts_client.dart';
import 'package:novel_voice_reader/features/speech/data/mimo_tts_client.dart';
import 'package:novel_voice_reader/features/speech/data/server_tts_client.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

final class AudioCacheRuntime {
  AudioCacheRuntime({
    required AppDatabase database,
    required this.cacheDirectoryForBook,
    required Dio dio,
    required SecureCredentials credentials,
    DownloadNetworkGate? networkGate,
    Future<VoiceProfile?> Function()? activeProfileLoader,
    Stream<List<ConnectivityResult>>? connectivityChanges,
    PlaybackTelemetry telemetry = const NoopPlaybackTelemetry(),
  }) : _store = DriftDownloadPlanStore(database),
       _database = database,
       // Keep public constructor labels without exposing private field names.
       // ignore: prefer_initializing_formals
       _dio = dio,
       // ignore: prefer_initializing_formals
       _credentials = credentials,
       _networkGate =
           networkGate ??
           ConnectivityDownloadNetworkGate(FlutterConnectivityReader()),
       // Keep public constructor labels without exposing private field names.
       // ignore: prefer_initializing_formals
       _activeProfileLoader = activeProfileLoader,
       // ignore: prefer_initializing_formals
       _connectivityChanges = connectivityChanges,
       // ignore: prefer_initializing_formals
       _telemetry = telemetry;

  final AppDatabase _database;
  final DriftDownloadPlanStore _store;
  final Directory Function(int bookId) cacheDirectoryForBook;
  final Dio _dio;
  final SecureCredentials _credentials;

  /// The process-wide credentials store. Exposed so the settings UI shares the
  /// exact instance the background synthesis path reads from — a saved API key
  /// updates the same in-memory cache the locked-screen synthesizer sees.
  SecureCredentials get credentials => _credentials;
  final DownloadNetworkGate _networkGate;
  final Future<VoiceProfile?> Function()? _activeProfileLoader;
  final Stream<List<ConnectivityResult>>? _connectivityChanges;
  final PlaybackTelemetry _telemetry;
  final Map<String, Future<AudioCacheObtainResult>> _inFlight = {};
  final Map<int, LinkedHashSet<String>> _recentKeysByBook = {};
  final Map<int, Future<void>> _reconcileTails = {};
  Future<void>? _resumeTail;
  Future<void>? _disposeFuture;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _started = false;
  late final AudioCacheTaskDispatcher _dispatcher = AudioCacheTaskDispatcher(
    obtain: (request) => obtain(
      bookId: request.bookId,
      segment: request.candidate.segment,
      profile: request.profile,
    ),
    store: _store,
    networkGate: _networkGate,
  );
  late final DownloadScheduler _scheduler = DownloadScheduler(
    store: _store,
    dispatcher: _dispatcher,
  );

  Future<File> obtain({
    required int bookId,
    required SpeechSegment segment,
    required VoiceProfile profile,
  }) async {
    final result = await obtainTracked(
      bookId: bookId,
      segment: segment,
      profile: profile,
    );
    return result.file;
  }

  Future<AudioCacheObtainResult> obtainTracked({
    required int bookId,
    required SpeechSegment segment,
    required VoiceProfile profile,
  }) {
    final cacheKey = CacheKey.forSegment(segment, profile);
    final key = '$bookId:$cacheKey';
    final existing = _inFlight[key];
    if (existing != null) {
      return existing.then(
        (result) => AudioCacheObtainResult(
          file: result.file,
          source: AudioCacheObtainSource.joinedInFlight,
        ),
      );
    }

    late final Future<AudioCacheObtainResult> operation;
    operation = _obtainAndRecord(
      bookId,
      segment,
      profile,
      cacheKey,
    ).whenComplete(() {
      if (identical(_inFlight[key], operation)) {
        _inFlight.remove(key);
      }
    });
    _inFlight[key] = operation;
    return operation;
  }

  Future<AudioCacheObtainResult> _obtainAndRecord(
    int bookId,
    SpeechSegment segment,
    VoiceProfile profile,
    String cacheKey,
  ) async {
    final repository = AudioCacheRepository(
      directory: cacheDirectoryForBook(bookId),
      synthesizer: _synthesizer(profile),
    );
    // A validated cache hit adds no bytes; only synthesis grows the cache.
    final cached = await repository.lookup(segment, profile);
    final file = cached ?? await repository.obtain(segment, profile);
    await _store.recordCachedFile(
      bookId: bookId,
      segment: segment,
      profile: profile,
      file: file,
    );
    _protectRecent(bookId, cacheKey);
    if (cached == null) {
      // Reclaim space only after real synthesis. A hit cannot have pushed the
      // cache over its limit, so running the per-obtain prune — a full-table
      // scan plus a stat per row — on every hit is pure overhead when replaying
      // an already-downloaded book. Limit/policy changes still prune via
      // _reconcileNow.
      final policy = await _store.policyForBook(bookId);
      await _store.pruneToLimit(
        bookId: bookId,
        maxBytes:
            policy?.maxCacheBytes ?? DownloadPolicy.defaultMaxCacheBytes,
        protectedKeys: _recentKeysForBook(bookId),
      );
    }
    return AudioCacheObtainResult(
      file: file,
      source: cached == null
          ? AudioCacheObtainSource.created
          : AudioCacheObtainSource.cacheHit,
    );
  }

  /// Returns the cached, validated audio file for [segment] if it is already on
  /// disk, or null on a miss/corrupt entry. Never synthesizes, records a
  /// download, or prunes — this is the lock-screen "hit disk and keep playing"
  /// path, which must not touch the network or the download plan.
  Future<File?> lookup({
    required int bookId,
    required SpeechSegment segment,
    required VoiceProfile profile,
  }) {
    return AudioCacheRepository(
      directory: cacheDirectoryForBook(bookId),
      synthesizer: _synthesizer(profile),
    ).lookup(segment, profile);
  }

  SpeechAudioCache forBook(
    int bookId, {
    PlaybackTelemetry telemetry = const NoopPlaybackTelemetry(),
    bool recordManualSeek = false,
  }) => _RuntimeBookAudioCache(
    this,
    bookId,
    telemetry: telemetry,
    recordManualSeek: recordManualSeek,
  );

  /// Restores persisted cache plans once at launch and whenever connectivity
  /// changes. A failed book must not prevent other books from resuming.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final changes = _connectivityChanges;
    if (changes != null) {
      _connectivitySubscription = changes.listen((_) {
        unawaited(_scheduleResume());
      });
    }
    await _scheduleResume();
  }

  Future<void> _scheduleResume() {
    final previous = _resumeTail ?? Future<void>.value();
    final operation = previous.then((_) => _resumeSavedPlans());
    late final Future<void> trackedTail;
    trackedTail = operation
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() {
          if (identical(_resumeTail, trackedTail)) {
            _resumeTail = null;
          }
        });
    _resumeTail = trackedTail;
    return operation;
  }

  Future<void> _resumeSavedPlans() async {
    final loadProfile = _activeProfileLoader;
    if (loadProfile == null || _disposeFuture != null) return;
    final profile = await loadProfile();
    if (profile == null) return;
    final policies = await _database.select(_database.downloadPolicies).get();
    for (final policyRecord in policies) {
      try {
        final chapters = await _database.chaptersForBook(policyRecord.bookId);
        if (chapters.isEmpty) continue;
        final progress = await _database.progressForBook(policyRecord.bookId);
        final currentChapter = progress == null
            ? chapters.first
            : chapters.firstWhere(
                (chapter) => chapter.id == progress.chapterId,
                orElse: () => chapters.first,
              );
        final paragraph =
            await (_database.select(_database.paragraphs)
                  ..where(
                    (row) =>
                        row.chapterId.equals(currentChapter.id) &
                        row.paragraphIndex.equals(
                          progress?.paragraphIndex ?? 0,
                        ),
                  )
                  ..limit(1))
                .getSingleOrNull();
        await reconcile(
          bookId: policyRecord.bookId,
          chapterCount: chapters.length,
          currentChapterIndex: currentChapter.chapterIndex,
          currentParagraphId: paragraph?.id ?? -1,
          policy: DownloadPolicy(
            chaptersAhead: policyRecord.chaptersAhead,
            wholeBook: policyRecord.wholeBook,
            wifiOnly: policyRecord.wifiOnly,
            maxCacheBytes: policyRecord.maxCacheBytes,
          ),
          profile: profile,
        );
      } catch (_) {
        // A corrupt book or provider configuration must not block the queue.
      }
    }
  }

  Future<DownloadReconcileResult> reconcile({
    required int bookId,
    required int chapterCount,
    required int currentChapterIndex,
    required int currentParagraphId,
    required DownloadPolicy policy,
    required VoiceProfile profile,
  }) {
    final previous = _reconcileTails[bookId] ?? Future<void>.value();
    final operation = previous.then(
      (_) => _reconcileNow(
        bookId: bookId,
        chapterCount: chapterCount,
        currentChapterIndex: currentChapterIndex,
        currentParagraphId: currentParagraphId,
        policy: policy,
        profile: profile,
      ),
    );
    late final Future<void> trackedTail;
    trackedTail = operation
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() {
          if (identical(_reconcileTails[bookId], trackedTail)) {
            _reconcileTails.remove(bookId);
          }
        });
    _reconcileTails[bookId] = trackedTail;
    return operation;
  }

  Future<DownloadReconcileResult> _reconcileNow({
    required int bookId,
    required int chapterCount,
    required int currentChapterIndex,
    required int currentParagraphId,
    required DownloadPolicy policy,
    required VoiceProfile profile,
  }) async {
    await _store.pruneToLimit(
      bookId: bookId,
      maxBytes: policy.maxCacheBytes,
      protectedKeys: _recentKeysForBook(bookId),
    );
    return _scheduler.reconcile(
      bookId: bookId,
      chapterCount: chapterCount,
      currentChapterIndex: currentChapterIndex,
      currentSegmentId: '$currentParagraphId:0',
      policy: policy,
      profile: profile,
    );
  }

  Future<void> waitForIdle() async {
    while (true) {
      final resume = _resumeTail;
      if (resume == null) break;
      await resume;
    }
    while (_reconcileTails.isNotEmpty) {
      await Future.wait(List<Future<void>>.of(_reconcileTails.values));
    }
    await _dispatcher.idle;
    while (_inFlight.isNotEmpty) {
      final operations = List<Future<AudioCacheObtainResult>>.of(
        _inFlight.values,
      );
      try {
        await Future.wait(operations);
      } catch (_) {
        // Wait for every operation even when one synthesis failed.
      }
    }
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    await _connectivitySubscription?.cancel();
    await waitForIdle();
    _dio.close(force: true);
  }

  Set<String> _recentKeysForBook(int bookId) =>
      _recentKeysByBook[bookId] ?? const <String>{};

  void _protectRecent(int bookId, String key) {
    final recentKeys = _recentKeysByBook.putIfAbsent(
      bookId,
      LinkedHashSet<String>.new,
    );
    recentKeys
      ..remove(key)
      ..add(key);
    while (recentKeys.length > 3) {
      recentKeys.remove(recentKeys.first);
    }
  }

  CloudSpeechSynthesizer _synthesizer(VoiceProfile profile) {
    return switch (profile.providerType) {
      SpeechProviderType.cloud => CloudTtsClient(
        dio: _dio,
        credentials: _credentials,
      ),
      SpeechProviderType.server => ServerTtsClient(
        dio: _dio,
        credentials: _credentials,
        telemetry: _telemetry,
      ),
      SpeechProviderType.mimo => MiMoTtsClient(
        dio: _dio,
        credentials: _credentials,
      ),
    };
  }
}

final class _RuntimeBookAudioCache
    implements SpeechAudioCache, LookupSpeechAudioCache {
  _RuntimeBookAudioCache(
    this._runtime,
    this._bookId, {
    required this.telemetry,
    required this.recordManualSeek,
  });

  final AudioCacheRuntime _runtime;
  final int _bookId;
  final PlaybackTelemetry telemetry;
  final bool recordManualSeek;
  bool _manualSeekRecorded = false;

  @override
  Future<File> obtain(SpeechSegment segment, VoiceProfile profile) async {
    final shouldRecord = recordManualSeek && !_manualSeekRecorded;
    if (shouldRecord) {
      _manualSeekRecorded = true;
    }
    late final AudioCacheObtainResult result;
    try {
      result = await _runtime.obtainTracked(
        bookId: _bookId,
        segment: segment,
        profile: profile,
      );
    } catch (_) {
      if (shouldRecord) {
        _manualSeekRecorded = false;
      }
      rethrow;
    }
    if (shouldRecord) {
      recordPlaybackTelemetrySafely(
        telemetry,
        'playback.manual_seek.confirmed.cache',
        {
          'source': result.source.name,
          'reused': result.source != AudioCacheObtainSource.created,
        },
      );
    }
    return result.file;
  }

  @override
  Future<File?> lookup(SpeechSegment segment, VoiceProfile profile) {
    return _runtime.lookup(bookId: _bookId, segment: segment, profile: profile);
  }
}
