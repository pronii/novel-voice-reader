import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_task_dispatcher.dart';
import 'package:novel_voice_reader/features/downloads/data/download_plan_store.dart';
import 'package:novel_voice_reader/features/downloads/data/download_scheduler.dart';
import 'package:novel_voice_reader/features/downloads/domain/cache_key.dart';
import 'package:novel_voice_reader/features/downloads/domain/download_policy.dart';
import 'package:novel_voice_reader/features/speech/data/cloud_tts_client.dart';
import 'package:novel_voice_reader/features/speech/data/mimo_tts_client.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

final class AudioCacheRuntime {
  AudioCacheRuntime({
    required AppDatabase database,
    required this.cacheDirectoryForBook,
    required Dio dio,
    required SecureCredentials credentials,
    DownloadNetworkGate? networkGate,
    Future<VoiceProfile> Function()? activeProfileLoader,
    Stream<List<ConnectivityResult>>? connectivityChanges,
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
       _connectivityChanges = connectivityChanges;

  final AppDatabase _database;
  final DriftDownloadPlanStore _store;
  final Directory Function(int bookId) cacheDirectoryForBook;
  final Dio _dio;
  final SecureCredentials _credentials;
  final DownloadNetworkGate _networkGate;
  final Future<VoiceProfile> Function()? _activeProfileLoader;
  final Stream<List<ConnectivityResult>>? _connectivityChanges;
  final Map<String, Future<File>> _inFlight = {};
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
  }) {
    final cacheKey = CacheKey.forSegment(segment, profile);
    final key = '$bookId:$cacheKey';
    final existing = _inFlight[key];
    if (existing != null) {
      return existing;
    }

    late final Future<File> operation;
    operation =
        AudioCacheRepository(
              directory: cacheDirectoryForBook(bookId),
              synthesizer: _synthesizer(profile),
            )
            .obtain(segment, profile)
            .then((file) async {
              await _store.recordCachedFile(
                bookId: bookId,
                segment: segment,
                profile: profile,
                file: file,
              );
              _protectRecent(bookId, cacheKey);
              final policy = await _store.policyForBook(bookId);
              await _store.pruneToLimit(
                bookId: bookId,
                maxBytes:
                    policy?.maxCacheBytes ??
                    DownloadPolicy.defaultMaxCacheBytes,
                protectedKeys: _recentKeysForBook(bookId),
              );
              return file;
            })
            .whenComplete(() {
              if (identical(_inFlight[key], operation)) {
                _inFlight.remove(key);
              }
            });
    _inFlight[key] = operation;
    return operation;
  }

  SpeechAudioCache forBook(int bookId) => _RuntimeBookAudioCache(this, bookId);

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
    if (profile.providerType == SpeechProviderType.system) return;
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
      final operations = List<Future<File>>.of(_inFlight.values);
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
      SpeechProviderType.mimo => MiMoTtsClient(
        dio: _dio,
        credentials: _credentials,
      ),
      SpeechProviderType.system => throw StateError(
        'System TTS cannot be stored as downloadable audio.',
      ),
    };
  }
}

final class _RuntimeBookAudioCache implements SpeechAudioCache {
  const _RuntimeBookAudioCache(this._runtime, this._bookId);

  final AudioCacheRuntime _runtime;
  final int _bookId;

  @override
  Future<File> obtain(SpeechSegment segment, VoiceProfile profile) {
    return _runtime.obtain(bookId: _bookId, segment: segment, profile: profile);
  }
}
