import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:novel_voice_reader/app/providers.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/core/network/speech_http_client.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/downloads/domain/download_policy.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_path.dart';
import 'package:novel_voice_reader/features/downloads/presentation/cache_page.dart';
import 'package:novel_voice_reader/features/library/data/book_import_repository.dart';
import 'package:novel_voice_reader/features/library/data/epub_book_parser.dart';
import 'package:novel_voice_reader/features/library/data/txt_book_parser.dart';
import 'package:novel_voice_reader/features/library/presentation/library_page.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_handler.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_coordinator.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_timeline.dart';
import 'package:novel_voice_reader/features/playback/presentation/player_page.dart';
import 'package:novel_voice_reader/features/playback/presentation/sleep_timer_button.dart';
import 'package:novel_voice_reader/features/reader/application/reader_chapter_window_controller.dart';
import 'package:novel_voice_reader/features/reader/data/reading_progress_repository.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/reader/presentation/reader_page.dart';
import 'package:novel_voice_reader/features/speech/data/speech_provider_factory.dart';
import 'package:novel_voice_reader/features/speech/data/mimo_tts_client.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';
import 'package:novel_voice_reader/features/speech/presentation/voice_settings_page.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/library',
    routes: [
      GoRoute(
        path: '/library',
        builder: (context, state) => const _LibraryRoutePage(),
      ),
      GoRoute(
        path: '/reader/:bookId',
        builder: (context, state) => _ReaderRoutePage(
          bookId: int.parse(state.pathParameters['bookId']!),
        ),
      ),
      GoRoute(
        path: '/player/:bookId',
        builder: (context, state) => _PlayerRoutePage(
          bookId: int.parse(state.pathParameters['bookId']!),
        ),
      ),
      GoRoute(
        path: '/settings/voice',
        builder: (context, state) => const _VoiceSettingsRoutePage(),
      ),
      GoRoute(
        path: '/settings/cache/:bookId',
        builder: (context, state) => _CacheSettingsRoutePage(
          bookId: int.parse(state.pathParameters['bookId']!),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('声阅')),
      body: const Center(child: Text('页面无法打开')),
    ),
  );
}

final class _LibraryRoutePage extends ConsumerStatefulWidget {
  const _LibraryRoutePage();

  @override
  ConsumerState<_LibraryRoutePage> createState() => _LibraryRoutePageState();
}

final class _LibraryRoutePageState extends ConsumerState<_LibraryRoutePage> {
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    if (ref.watch(databaseProvider) == null) {
      return LibraryPage(
        books: const [],
        onImport: _importBook,
        onOpenVoiceSettings: () => context.push('/settings/voice'),
      );
    }
    final books = ref.watch(libraryBooksProvider);
    return books.when(
      loading: () =>
          LibraryPage(books: const [], loading: true, onImport: _importBook),
      error: (_, _) => LibraryPage(
        books: const [],
        errorMessage: '书架加载失败',
        onImport: _importBook,
      ),
      data: (records) => LibraryPage(
        books: [
          for (final book in records)
            LibraryBookItem(
              id: book.id,
              title: book.title,
              progressLabel: book.lastReadAt == null ? '尚未开始' : '继续阅读',
            ),
        ],
        loading: _importing,
        onImport: _importBook,
        onOpenBook: (bookId) => context.push('/reader/$bookId'),
        onOpenVoiceSettings: () => context.push('/settings/voice'),
        onOpenCacheSettings: (bookId) =>
            context.push('/settings/cache/$bookId'),
      ),
    );
  }

  Future<void> _importBook() async {
    final database = ref.read(databaseProvider);
    if (database == null || _importing) {
      return;
    }
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt', 'epub'],
        withData: false,
      );
      final file = result?.files.singleOrNull;
      if (file == null) {
        return;
      }
      if (file.size > BookImportRepository.maxFileBytes) {
        throw const AppFailure('图书文件超过 100 MB，请先压缩或拆分');
      }
      await BookImportRepository(
        database: database,
        txtParser: const TxtBookParser(),
        epubParser: const EpubBookParser(),
      ).importFile(file);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_importErrorMessage(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }
}

String _importErrorMessage(Object error) {
  return switch (error) {
    AppFailure(:final message) => message,
    UnsupportedError() => '仅支持 TXT 和非 DRM EPUB 图书',
    FormatException() => '图书文件损坏、加密或不包含可阅读正文',
    _ => '导入失败，请确认文件仍可访问',
  };
}

final class _ReaderRoutePage extends ConsumerStatefulWidget {
  const _ReaderRoutePage({required this.bookId});

  final int bookId;

  @override
  ConsumerState<_ReaderRoutePage> createState() => _ReaderRoutePageState();
}

final class _ReaderRoutePageState extends ConsumerState<_ReaderRoutePage> {
  ReaderChapterWindowController? _chapterWindow;
  Future<void>? _chapterWindowInitialization;
  PlaybackCursor? _navigationCursor;
  int? _visibleChapterId;
  PlaybackRuntime? _observedPlaybackRuntime;
  StreamSubscription<PlaybackCursor?>? _playbackCursorSubscription;
  int _playbackSubscriptionGeneration = 0;
  PlaybackCursor? _playbackCursor;
  PlaybackRuntime? _pendingPlaybackRuntime;
  PlaybackReplacementToken? _pendingPlaybackReplacement;
  bool _playbackStarting = false;

  @override
  void dispose() {
    final pendingReplacement = _pendingPlaybackReplacement;
    final runtime = _pendingPlaybackRuntime;
    if (pendingReplacement != null && runtime != null) {
      runtime.cancelReplacement(pendingReplacement);
    }
    _chapterWindow?.removeListener(_onChapterWindowChanged);
    _chapterWindow?.dispose();
    unawaited(_playbackCursorSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookId = widget.bookId;
    _observePlaybackRuntime(ref.watch(playbackRuntimeProvider));
    final data = ref.watch(readerPageDataProvider(ReaderPageRequest(bookId)));
    return data.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const Scaffold(body: Center(child: Text('小说内容加载失败'))),
      data: (value) => _buildInitializedReader(value),
    );
  }

  Widget _buildInitializedReader(ReaderPageData data) {
    final database = ref.read(databaseProvider);
    if (database == null) {
      return const Scaffold(body: Center(child: Text('小说内容加载失败')));
    }
    if (data.chapters.isEmpty) {
      return ReaderPage(
        bookId: widget.bookId,
        bookTitle: data.book.title,
        chapters: const [],
        sections: const [],
        onBackToLibrary: _backToLibrary,
      );
    }
    final initialization = _ensureChapterWindow(data, database);
    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(body: Center(child: Text('小说内容加载失败')));
        }
        final window = _chapterWindow;
        if (snapshot.connectionState != ConnectionState.done ||
            window == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return ReaderPage(
          bookId: widget.bookId,
          bookTitle: data.book.title,
          chapters: data.chapters,
          sections: window.sections,
          currentChapterId: _visibleChapterId ?? _navigationCursor?.chapterId,
          initialCursor: _navigationCursor,
          navigationGeneration: window.navigationGeneration,
          playbackStarting: _playbackStarting,
          playbackCursor: _playbackCursor,
          playbackActive: _playbackCursor != null,
          onBackToLibrary: _backToLibrary,
          onChapterSelected: (chapterId) =>
              unawaited(_selectChapter(chapterId)),
          onVisibleChapterChanged: (chapterId) {
            _visibleChapterId = chapterId;
          },
          onReadingPositionChanged: (paragraph) {
            unawaited(_persistReadingPosition(database, paragraph));
          },
          onOpenPlayer: () => context.push('/player/${widget.bookId}'),
          onPlayFrom: (paragraph) => unawaited(_playFrom(data, paragraph)),
          onLoadPrevious: window.loadPrevious,
          onLoadNext: window.loadNext,
          onPlaybackChapterNeeded: _ensurePlaybackChapter,
        );
      },
    );
  }

  Future<void> _ensureChapterWindow(ReaderPageData data, AppDatabase database) {
    final existing = _chapterWindowInitialization;
    if (existing != null) {
      return existing;
    }
    _navigationCursor = data.savedCursor;
    _visibleChapterId = data.savedCursor?.chapterId;
    final window = ReaderChapterWindowController(
      chapters: data.chapters,
      loadSection: (chapter) => loadReaderChapterSection(database, chapter),
    );
    window.addListener(_onChapterWindowChanged);
    _chapterWindow = window;
    return _chapterWindowInitialization = window.initialize(
      chapterId: data.savedCursor?.chapterId ?? data.chapters.first.id,
    );
  }

  void _onChapterWindowChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _observePlaybackRuntime(PlaybackRuntime? runtime) {
    if (identical(_observedPlaybackRuntime, runtime)) {
      return;
    }
    final generation = ++_playbackSubscriptionGeneration;
    unawaited(_playbackCursorSubscription?.cancel());
    _observedPlaybackRuntime = runtime;
    _playbackCursor = runtime?.currentCursor;
    _playbackCursorSubscription = runtime?.cursorChanges.listen((cursor) {
      if (mounted && generation == _playbackSubscriptionGeneration) {
        setState(() => _playbackCursor = cursor);
      }
    });
  }

  Future<void> _ensurePlaybackChapter(int chapterId) async {
    final window = _chapterWindow;
    if (window == null ||
        window.sections.any((section) => section.chapter.id == chapterId)) {
      return;
    }
    await window.centerOn(chapterId: chapterId, resetNavigation: false);
  }

  Future<void> _playFrom(ReaderPageData data, ReaderParagraph paragraph) async {
    if (_playbackStarting) {
      return;
    }
    setState(() => _playbackStarting = true);
    try {
      final database = ref.read(databaseProvider);
      final runtime = ref.read(playbackRuntimeProvider);
      final chapter = data.chapters
          .where((chapter) => chapter.id == paragraph.chapterId)
          .firstOrNull;
      if (database == null || runtime == null || chapter == null) {
        return;
      }
      final replacementToken = runtime.beginReplacement();
      _pendingPlaybackRuntime = runtime;
      _pendingPlaybackReplacement = replacementToken;
      final profile = await loadActiveVoiceProfile(database);
      final audioCacheRuntime = ref.read(audioCacheRuntimeProvider);
      final Directory cacheDirectory;
      if (audioCacheRuntime == null) {
        final supportDirectory = await getApplicationSupportDirectory();
        cacheDirectory = audioCacheDirectoryForBook(
          supportDirectory,
          widget.bookId,
        );
      } else {
        cacheDirectory = audioCacheRuntime.cacheDirectoryForBook(widget.bookId);
      }
      final providerFactory = audioCacheRuntime == null
          ? SpeechProviderFactory(
              dio: createSpeechDio(),
              credentials: SecureCredentials(
                FlutterSecureKeyValueStore(const FlutterSecureStorage()),
              ),
              cacheDirectory: cacheDirectory,
            )
          : SpeechProviderFactory(
              cacheDirectory: cacheDirectory,
              audioCache: audioCacheRuntime.forBook(widget.bookId),
            );
      final provider = providerFactory.create(profile);
      final coordinator = PlaybackCoordinator(
        provider: provider,
        progress: DriftPlaybackProgressRepository(
          database: database,
          bookId: widget.bookId,
        ),
        paragraphs: DriftPlaybackParagraphSource(database),
        voiceProfile: profile,
        onFailure: _showSpeechFailure,
      );
      final started = await runtime.replaceAndPlayFrom(
        coordinator,
        PlaybackCursor(
          chapterId: paragraph.chapterId,
          paragraphIndex: paragraph.index,
        ),
        token: replacementToken,
      );
      if (!started) {
        return;
      }
      _pendingPlaybackRuntime = null;
      _pendingPlaybackReplacement = null;
      runtime.handler.publishNowPlaying(
        bookId: widget.bookId,
        bookTitle: data.book.title,
        chapterTitle: chapter.title,
      );
      runtime.handler.markPlaying();
      await (database.update(database.books)
            ..where((book) => book.id.equals(widget.bookId)))
          .write(BooksCompanion(lastReadAt: Value(DateTime.now())));
      if (audioCacheRuntime != null &&
          profile.providerType != SpeechProviderType.system) {
        final policyRecord =
            await (database.select(database.downloadPolicies)
                  ..where((policy) => policy.bookId.equals(widget.bookId)))
                .getSingleOrNull();
        if (policyRecord != null) {
          unawaited(
            audioCacheRuntime
                .reconcile(
                  bookId: widget.bookId,
                  chapterCount: data.chapters.length,
                  currentChapterIndex: chapter.index,
                  currentParagraphId: paragraph.id,
                  policy: DownloadPolicy(
                    chaptersAhead: policyRecord.chaptersAhead,
                    wholeBook: policyRecord.wholeBook,
                    wifiOnly: policyRecord.wifiOnly,
                    maxCacheBytes: policyRecord.maxCacheBytes,
                  ),
                  profile: profile,
                )
                .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
          );
        }
      }
    } catch (error) {
      if (error is! AppFailure) {
        _showSpeechFailure(const AppFailure('朗读启动失败'));
      }
    } finally {
      _pendingPlaybackRuntime = null;
      _pendingPlaybackReplacement = null;
      if (mounted) {
        setState(() => _playbackStarting = false);
      }
    }
  }

  void _showSpeechFailure(AppFailure failure) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failure.message)));
  }

  void _backToLibrary() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/library');
    }
  }

  Future<void> _selectChapter(int chapterId) async {
    final window = _chapterWindow;
    // Guard against re-selecting the chapter the reader is *currently showing*,
    // not the last one navigated to — otherwise a chapter the user scrolled or
    // played away from can no longer be re-selected from the TOC.
    if (window == null || chapterId == _visibleChapterId) {
      return;
    }
    _navigationCursor = PlaybackCursor(chapterId: chapterId, paragraphIndex: 0);
    _visibleChapterId = chapterId;
    await window.centerOn(chapterId: chapterId);
    final database = ref.read(databaseProvider);
    if (database != null) {
      await _persistSelectedChapter(database, chapterId);
    }
  }

  Future<void> _persistSelectedChapter(
    AppDatabase database,
    int chapterId,
  ) async {
    await database.upsertProgress(
      bookId: widget.bookId,
      chapterId: chapterId,
      paragraphIndex: 0,
    );
    await (database.update(database.books)
          ..where((book) => book.id.equals(widget.bookId)))
        .write(BooksCompanion(lastReadAt: Value(DateTime.now())));
  }

  Future<void> _persistReadingPosition(
    AppDatabase database,
    ReaderParagraph paragraph,
  ) async {
    await database.upsertProgress(
      bookId: widget.bookId,
      chapterId: paragraph.chapterId,
      paragraphIndex: paragraph.index,
    );
    await (database.update(database.books)
          ..where((book) => book.id.equals(widget.bookId)))
        .write(BooksCompanion(lastReadAt: Value(DateTime.now())));
  }
}

final class _PlayerRoutePage extends ConsumerWidget {
  const _PlayerRoutePage({required this.bookId});

  final int bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(readerPageDataProvider(ReaderPageRequest(bookId)));
    final handler = ref.watch(playbackRuntimeProvider)?.handler;
    return data.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const Scaffold(body: Center(child: Text('播放器加载失败'))),
      data: (value) => PlayerPage(
        bookTitle: value.book.title,
        actions: const [SleepTimerButton()],
        chapterTitle:
            value.chapters
                .where((chapter) => chapter.id == value.savedCursor?.chapterId)
                .firstOrNull
                ?.title ??
            value.chapters.firstOrNull?.title ??
            '未命名章节',
        initialSpeed: handler?.playbackState.value.speed ?? 1,
        initialPlaying: handler?.playbackState.value.playing ?? false,
        playingChanges: handler?.playbackState
            .map((state) => state.playing)
            .distinct(),
        initialTimeline: handler?.currentTimeline ?? PlaybackTimeline.zero,
        timelineChanges: handler?.timelineChanges,
        onSpeedChanged: handler?.setSpeed,
        onPlay: handler?.play,
        onPause: handler?.pause,
        onPrevious: handler?.skipToPrevious,
        onNext: handler?.skipToNext,
      ),
    );
  }
}

final class _VoiceSettingsInitialData {
  const _VoiceSettingsInitialData({
    required this.profile,
    required this.hasSavedCloudApiKey,
    required this.hasSavedMiMoApiKey,
  });

  final VoiceProfile profile;
  final bool hasSavedCloudApiKey;
  final bool hasSavedMiMoApiKey;
}

final _secureCredentialsProvider = Provider.autoDispose<SecureCredentials>(
  (ref) => SecureCredentials(
    FlutterSecureKeyValueStore(const FlutterSecureStorage()),
  ),
);

final _voiceSettingsInitialDataProvider =
    FutureProvider.autoDispose<_VoiceSettingsInitialData>((ref) async {
      final database = ref.watch(databaseProvider);
      final credentials = ref.watch(_secureCredentialsProvider);
      final profile = database == null
          ? VoiceProfile.system()
          : await loadActiveVoiceProfile(database);
      String? cloudApiKey;
      String? mimoApiKey;
      try {
        cloudApiKey = await credentials.readApiKey();
      } catch (_) {
        cloudApiKey = null;
      }
      try {
        mimoApiKey = await credentials.readMiMoApiKey();
      } catch (_) {
        mimoApiKey = null;
      }
      return _VoiceSettingsInitialData(
        profile: profile,
        hasSavedCloudApiKey: cloudApiKey?.trim().isNotEmpty ?? false,
        hasSavedMiMoApiKey: mimoApiKey?.trim().isNotEmpty ?? false,
      );
    });

final class _VoiceSettingsRoutePage extends ConsumerWidget {
  const _VoiceSettingsRoutePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(databaseProvider);
    final credentials = ref.watch(_secureCredentialsProvider);
    final initialData = ref.watch(_voiceSettingsInitialDataProvider);
    return initialData.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const Scaffold(body: Center(child: Text('语音设置加载失败'))),
      data: (initial) => VoiceSettingsPage(
        initialProfile: initial.profile,
        hasSavedCloudApiKey: initial.hasSavedCloudApiKey,
        hasSavedMiMoApiKey: initial.hasSavedMiMoApiKey,
        onTestConnection: (submission) async {
          final profile = submission.profile;
          switch (profile.providerType) {
            case SpeechProviderType.mimo:
              final apiKey =
                  submission.credentials.normalizedApiKey ??
                  await credentials.readMiMoApiKey() ??
                  '';
              final dio = createSpeechDio();
              try {
                await MiMoTtsClient(
                  dio: dio,
                  credentials: credentials,
                ).testConnection(apiKey: apiKey, profile: profile);
              } finally {
                dio.close(force: true);
              }
            case SpeechProviderType.system || SpeechProviderType.cloud:
              throw const AppFailure('当前语音服务不支持连接测试');
          }
        },
        onSave: (submission) async {
          final profile = submission.profile;
          Future<void> persistProfile() async {
            if (database == null) return;
            await database.transaction(() async {
              await database.delete(database.voiceProfiles).go();
              await database
                  .into(database.voiceProfiles)
                  .insert(
                    VoiceProfilesCompanion.insert(
                      providerType: profile.providerType.name,
                      baseUrl: Value(profile.baseUrl),
                      model: Value(profile.model),
                      voice: Value(profile.voice),
                      speed: Value(profile.speed),
                      pitch: Value(profile.pitch),
                      outputFormat: Value(profile.outputFormat),
                      style: Value(profile.style),
                    ),
                  );
            });
          }

          if (profile.providerType == SpeechProviderType.mimo) {
            await credentials.runWithMiMoApiKeyUpdate(
              apiKey: submission.credentials.normalizedApiKey,
              commit: persistProfile,
            );
            return;
          }
          if (profile.providerType == SpeechProviderType.cloud) {
            await credentials.runWithApiKeyUpdate(
              apiKey: submission.credentials.normalizedApiKey,
              commit: persistProfile,
            );
            return;
          }
          await persistProfile();
        },
      ),
    );
  }
}

final class _CacheSettingsRoutePage extends ConsumerWidget {
  const _CacheSettingsRoutePage({required this.bookId});

  final int bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(databaseProvider);
    if (database == null) {
      return CachePage(
        chapterCount: 0,
        currentChapterIndex: 0,
        onApply: (_) {},
      );
    }
    return FutureBuilder<_CachePageData>(
      future: _loadCachePageData(database, bookId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(body: Center(child: Text('缓存设置加载失败')));
        }
        final data = snapshot.data;
        if (data == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return CachePage(
          chapterCount: data.chapterCount,
          currentChapterIndex: data.currentChapterIndex,
          initialPolicy: data.policy,
          bookTitle: data.bookTitle,
          cachedBytes: data.cachedBytes,
          cachedSegmentCount: data.cachedSegmentCount,
          onApply: (policy) async {
            final profile = await loadActiveVoiceProfile(database);
            if (profile.providerType == SpeechProviderType.system) {
              throw const AppFailure('请先选择兼容或 MiMo 语音服务');
            }
            final runtime = ref.read(audioCacheRuntimeProvider);
            if (runtime == null) {
              throw const AppFailure('缓存服务暂时不可用');
            }
            await database
                .into(database.downloadPolicies)
                .insertOnConflictUpdate(
                  DownloadPoliciesCompanion.insert(
                    bookId: Value(bookId),
                    chaptersAhead: Value(policy.chaptersAhead),
                    wholeBook: Value(policy.wholeBook),
                    wifiOnly: Value(policy.wifiOnly),
                    maxCacheBytes: policy.maxCacheBytes,
                  ),
                );
            final result = await runtime.reconcile(
              bookId: bookId,
              chapterCount: data.chapterCount,
              currentChapterIndex: data.currentChapterIndex,
              currentParagraphId: data.currentParagraphId ?? -1,
              policy: policy,
              profile: profile,
            );
            if (result.cacheLimitReached) {
              throw const AppFailure('设置已保存，但缓存容量不足，部分内容将在释放空间后继续');
            }
          },
        );
      },
    );
  }
}

Future<_CachePageData> _loadCachePageData(
  AppDatabase database,
  int bookId,
) async {
  final book = await (database.select(
    database.books,
  )..where((book) => book.id.equals(bookId))).getSingleOrNull();
  if (book == null) {
    return const _CachePageData(
      bookTitle: null,
      chapterCount: 0,
      currentChapterIndex: 0,
      currentParagraphId: null,
      policy: null,
      cachedBytes: 0,
      cachedSegmentCount: 0,
    );
  }
  final chapters = await database.chaptersForBook(book.id);
  final progress = await database.progressForBook(book.id);
  final currentChapterIndex = progress == null
      ? 0
      : chapters
                .where((chapter) => chapter.id == progress.chapterId)
                .map((chapter) => chapter.chapterIndex)
                .firstOrNull ??
            0;
  final currentChapter = chapters
      .where((chapter) => chapter.chapterIndex == currentChapterIndex)
      .firstOrNull;
  final currentParagraph = currentChapter == null
      ? null
      : await (database.select(database.paragraphs)
              ..where(
                (paragraph) =>
                    paragraph.chapterId.equals(currentChapter.id) &
                    paragraph.paragraphIndex.equals(
                      progress?.chapterId == currentChapter.id
                          ? progress?.paragraphIndex ?? 0
                          : 0,
                    ),
              )
              ..limit(1))
            .getSingleOrNull();
  final record = await (database.select(
    database.downloadPolicies,
  )..where((policy) => policy.bookId.equals(book.id))).getSingleOrNull();
  final cachedRecords =
      await (database.select(database.audioCacheEntries)..where(
            (entry) =>
                entry.bookId.equals(book.id) & entry.status.equals('complete'),
          ))
          .get();
  return _CachePageData(
    bookTitle: book.title,
    chapterCount: chapters.length,
    currentChapterIndex: currentChapterIndex,
    currentParagraphId: currentParagraph?.id,
    cachedBytes: cachedRecords.fold(0, (sum, record) => sum + record.byteSize),
    cachedSegmentCount: cachedRecords.length,
    policy: record == null
        ? null
        : DownloadPolicy(
            chaptersAhead: record.chaptersAhead,
            wholeBook: record.wholeBook,
            wifiOnly: record.wifiOnly,
            maxCacheBytes: record.maxCacheBytes,
          ),
  );
}

final class _CachePageData {
  const _CachePageData({
    required this.bookTitle,
    required this.chapterCount,
    required this.currentChapterIndex,
    required this.currentParagraphId,
    required this.policy,
    required this.cachedBytes,
    required this.cachedSegmentCount,
  });

  final String? bookTitle;
  final int chapterCount;
  final int currentChapterIndex;
  final int? currentParagraphId;
  final DownloadPolicy? policy;
  final int cachedBytes;
  final int cachedSegmentCount;
}
