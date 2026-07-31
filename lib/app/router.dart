import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:novel_voice_reader/app/providers.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/downloads/domain/download_policy.dart';
import 'package:novel_voice_reader/features/downloads/presentation/cache_page.dart';
import 'package:novel_voice_reader/features/library/data/book_import_repository.dart';
import 'package:novel_voice_reader/features/library/data/epub_book_parser.dart';
import 'package:novel_voice_reader/features/library/data/txt_book_parser.dart';
import 'package:novel_voice_reader/features/library/presentation/library_page.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_coordinator.dart';
import 'package:novel_voice_reader/features/playback/presentation/player_page.dart';
import 'package:novel_voice_reader/features/reader/data/reading_progress_repository.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/reader/presentation/reader_page.dart';
import 'package:novel_voice_reader/features/speech/data/speech_provider_factory.dart';
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
        path: '/settings/cache',
        builder: (context, state) => const _CacheSettingsRoutePage(),
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
        onOpenCacheSettings: () => context.push('/settings/cache'),
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
        onOpenCacheSettings: () => context.push('/settings/cache'),
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
        withData: true,
      );
      final file = result?.files.singleOrNull;
      if (file == null) {
        return;
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
  int? _selectedChapterId;
  PlaybackCoordinator? _coordinator;

  @override
  Widget build(BuildContext context) {
    final bookId = widget.bookId;
    final data = ref.watch(
      readerPageDataProvider(ReaderPageRequest(bookId, _selectedChapterId)),
    );
    return data.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const Scaffold(body: Center(child: Text('小说内容加载失败'))),
      data: (value) => ReaderPage(
        bookId: bookId,
        bookTitle: value.book.title,
        chapterTitle: value.chapter?.title ?? '未命名章节',
        chapters: value.chapters,
        currentChapterId: value.chapter?.id,
        paragraphs: value.paragraphs,
        initialActiveParagraphId: value.activeParagraphId,
        onBackToLibrary: _backToLibrary,
        onChapterSelected: (chapterId) => _selectChapter(value, chapterId),
        onPreviousChapter: value.currentChapterIndex > 0
            ? () => _selectChapter(
                value,
                value.chapters[value.currentChapterIndex - 1].id,
              )
            : null,
        onNextChapter:
            value.currentChapterIndex >= 0 &&
                value.currentChapterIndex < value.chapters.length - 1
            ? () => _selectChapter(
                value,
                value.chapters[value.currentChapterIndex + 1].id,
              )
            : null,
        onOpenPlayer: () => context.push('/player/$bookId'),
        onPlayFrom: (paragraph) => unawaited(_playFrom(value, paragraph)),
      ),
    );
  }

  Future<void> _playFrom(ReaderPageData data, ReaderParagraph paragraph) async {
    final database = ref.read(databaseProvider);
    final runtime = ref.read(playbackRuntimeProvider);
    final chapter = data.chapter;
    if (database == null || chapter == null) {
      return;
    }
    try {
      final profile = await loadActiveVoiceProfile(database);
      final supportDirectory = await getApplicationSupportDirectory();
      final credentials = SecureCredentials(
        FlutterSecureKeyValueStore(const FlutterSecureStorage()),
      );
      final provider = SpeechProviderFactory(
        dio: Dio(),
        credentials: credentials,
        cacheDirectory: Directory(
          '${supportDirectory.path}${Platform.pathSeparator}speech_audio',
        ),
      ).create(profile);
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
      final previous = _coordinator;
      _coordinator = coordinator;
      if (previous != null) {
        await previous.dispose();
      }
      runtime?.controller.attach(coordinator);
      runtime?.handler.publishNowPlaying(
        bookId: widget.bookId,
        bookTitle: data.book.title,
        chapterTitle: chapter.title,
      );
      await coordinator.playFrom(
        PlaybackCursor(chapterId: chapter.id, paragraphIndex: paragraph.index),
      );
      runtime?.handler.markPlaying();
      await (database.update(database.books)
            ..where((book) => book.id.equals(widget.bookId)))
          .write(BooksCompanion(lastReadAt: Value(DateTime.now())));
    } catch (error) {
      if (error is! AppFailure) {
        _showSpeechFailure(const AppFailure('朗读启动失败'));
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

  void _selectChapter(ReaderPageData data, int chapterId) {
    if (chapterId == data.chapter?.id) {
      return;
    }
    setState(() => _selectedChapterId = chapterId);
    final database = ref.read(databaseProvider);
    if (database != null) {
      unawaited(_persistSelectedChapter(database, chapterId));
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
}

final class _PlayerRoutePage extends ConsumerWidget {
  const _PlayerRoutePage({required this.bookId});

  final int bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(readerPageDataProvider(ReaderPageRequest(bookId)));
    return data.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const Scaffold(body: Center(child: Text('播放器加载失败'))),
      data: (value) => PlayerPage(
        bookTitle: value.book.title,
        chapterTitle: value.chapter?.title ?? '未命名章节',
        onPlay: ref.read(playbackRuntimeProvider)?.handler.play,
        onPause: ref.read(playbackRuntimeProvider)?.handler.pause,
        onPrevious: ref.read(playbackRuntimeProvider)?.handler.skipToPrevious,
        onNext: ref.read(playbackRuntimeProvider)?.handler.skipToNext,
      ),
    );
  }
}

final class _VoiceSettingsRoutePage extends ConsumerWidget {
  const _VoiceSettingsRoutePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VoiceSettingsPage(
      onSave: (profile, apiKey) async {
        final database = ref.read(databaseProvider);
        if (database != null) {
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
                ),
              );
        }
        if (apiKey != null && apiKey.isNotEmpty) {
          final credentials = SecureCredentials(
            FlutterSecureKeyValueStore(const FlutterSecureStorage()),
          );
          if (profile.providerType == SpeechProviderType.azure) {
            await credentials.writeAzureSubscriptionKey(apiKey);
          } else if (profile.providerType == SpeechProviderType.cloud) {
            await credentials.writeApiKey(apiKey);
          }
        }
      },
    );
  }
}

final class _CacheSettingsRoutePage extends ConsumerWidget {
  const _CacheSettingsRoutePage();

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
      future: _loadCachePageData(database),
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
          onApply: (policy) {
            final bookId = data.bookId;
            if (bookId == null) {
              return;
            }
            unawaited(
              database
                  .into(database.downloadPolicies)
                  .insertOnConflictUpdate(
                    DownloadPoliciesCompanion.insert(
                      bookId: Value(bookId),
                      chaptersAhead: Value(policy.chaptersAhead),
                      wholeBook: Value(policy.wholeBook),
                      wifiOnly: Value(policy.wifiOnly),
                      maxCacheBytes: policy.maxCacheBytes,
                    ),
                  ),
            );
          },
        );
      },
    );
  }
}

Future<_CachePageData> _loadCachePageData(AppDatabase database) async {
  final booksQuery = database.select(database.books)
    ..orderBy([(book) => OrderingTerm.desc(book.importedAt)])
    ..limit(1);
  final book = await booksQuery.getSingleOrNull();
  if (book == null) {
    return const _CachePageData(
      bookId: null,
      chapterCount: 0,
      currentChapterIndex: 0,
      policy: null,
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
  final record = await (database.select(
    database.downloadPolicies,
  )..where((policy) => policy.bookId.equals(book.id))).getSingleOrNull();
  return _CachePageData(
    bookId: book.id,
    chapterCount: chapters.length,
    currentChapterIndex: currentChapterIndex,
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
    required this.bookId,
    required this.chapterCount,
    required this.currentChapterIndex,
    required this.policy,
  });

  final int? bookId;
  final int chapterCount;
  final int currentChapterIndex;
  final DownloadPolicy? policy;
}
