import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:novel_voice_reader/core/network/speech_http_client.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/diagnostics/domain/playback_telemetry.dart';
import 'package:novel_voice_reader/features/downloads/application/audio_cache_runtime.dart';
import 'package:novel_voice_reader/features/library/data/cover_repository.dart';
import 'package:novel_voice_reader/features/playback/application/sleep_timer_controller.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_handler.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_session.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_content.dart';
import 'package:novel_voice_reader/features/settings/application/theme_mode_controller.dart';
import 'package:novel_voice_reader/features/settings/data/theme_mode_preference_store.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

final databaseProvider = Provider<AppDatabase?>((ref) => null);
final playbackRuntimeProvider = Provider<PlaybackRuntime?>((ref) => null);
final audioCacheRuntimeProvider = Provider<AudioCacheRuntime?>((ref) => null);

/// Fetches and caches book covers from the self-hosted server. Assembled from
/// the database plus a fresh HTTP client and the platform support directory
/// (mirroring how other client-only services are built here). Null until a
/// database is available — e.g. widget tests without a Riverpod scope — in
/// which case the library page simply skips cover fetching.
final coverRepositoryProvider = Provider<CoverRepository?>((ref) {
  final database = ref.watch(databaseProvider);
  if (database == null) {
    return null;
  }
  return CoverRepository(
    database: database,
    dio: createSpeechDio(),
    supportDirectory: getApplicationSupportDirectory,
  );
});

/// File-backed store for the light/dark preference. `null` by default so widget
/// tests never touch `path_provider`; [NovelVoiceReaderApp] injects a real one.
final themeModePreferenceStoreProvider = Provider<ThemeModePreferenceStore?>(
  (ref) => null,
);

/// The current app-wide light/dark mode, persisted when a store is present.
final themeModeControllerProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
      final controller = ThemeModeController(
        ref.watch(themeModePreferenceStoreProvider),
      );
      unawaited(controller.load());
      return controller;
    });

/// The shared background audio session. Overridden in [NovelVoiceReaderApp]
/// with the session created at startup; a no-op default keeps widgets and
/// tests independent of platform audio.
final backgroundAudioSessionProvider = Provider<BackgroundAudioSession?>(
  (ref) => null,
);

/// Background-playback diagnostics sink. Overridden in [NovelVoiceReaderApp]
/// with the real buffered/uploading implementation; a no-op by default so
/// widgets and tests never depend on it being wired.
final playbackTelemetryProvider = Provider<PlaybackTelemetry>(
  (ref) => const NoopPlaybackTelemetry(),
);

/// Sleep timer shared across the reader and player pages. Stopping playback on
/// expiry dismisses the media notification via [NovelAudioHandler.stop].
///
/// Widgets should observe the returned controller with a [ListenableBuilder]
/// to react to countdown ticks.
final sleepTimerControllerProvider = Provider<SleepTimerController>((ref) {
  final runtime = ref.watch(playbackRuntimeProvider);
  final controller = SleepTimerController(
    onExpire: () async {
      await runtime?.handler.stop();
      // The sleep timer expiring means the user is done listening. The
      // sustainer pauses the inaudible keep-alive loop on stop, but it keeps
      // the audio session active by design (for a quick resume). On iOS an
      // active session with no output keeps the app in the running
      // background-audio state and drains the battery; deactivate it so the OS
      // can suspend the app. The next play request re-activates via
      // BackgroundPlaybackSustainer.ensureActive.
      await ref.read(backgroundAudioSessionProvider)?.deactivate();
    },
    currentChapterId: () => runtime?.currentCursor?.chapterId,
    cursorChanges: () =>
        runtime?.cursorChanges ?? const Stream<PlaybackCursor?>.empty(),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// Default self-hosted TTS server used when the user has not configured any
/// voice profile. Pointing at the built-in server means listening works out of
/// the box and book covers (served from the same host) fetch automatically.
const String kDefaultServerBaseUrl = 'https://tts.ll.993209.xyz:888';

/// The active voice profile, or the built-in self-hosted server when none has
/// been configured. The app's default voice service is the self-hosted server,
/// so the user never has to pick a provider before first use.
Future<VoiceProfile> loadActiveVoiceProfile(AppDatabase database) async {
  final query = database.select(database.voiceProfiles)
    ..orderBy([(profile) => OrderingTerm.desc(profile.id)])
    ..limit(1);
  return voiceProfileFromRecord(await query.getSingleOrNull()) ??
      VoiceProfile.server(
        baseUrl: kDefaultServerBaseUrl,
        model: VoiceProfile.mimoModel,
        voice: VoiceProfile.defaultMiMoVoice,
      );
}

VoiceProfile? voiceProfileFromRecord(VoiceProfileRecord? record) {
  if (record == null) {
    return null;
  }
  try {
    return switch (record.providerType) {
      'cloud'
          when record.baseUrl != null &&
              record.model != null &&
              record.voice != null =>
        VoiceProfile.cloud(
          baseUrl: record.baseUrl!,
          model: record.model!,
          voice: record.voice!,
          speed: record.speed,
          outputFormat: record.outputFormat ?? 'mp3',
        ),
      'server'
          when record.baseUrl != null &&
              record.model != null &&
              record.voice != null =>
        VoiceProfile.server(
          baseUrl: record.baseUrl!,
          model: record.model!,
          voice: record.voice!,
          speed: record.speed,
          outputFormat: record.outputFormat ?? 'wav',
        ),
      'mimo' => VoiceProfile.mimo(
        voice: record.voice ?? VoiceProfile.defaultMiMoVoice,
        style: record.style,
        speed: record.speed,
      ),
      _ => null,
    };
  } on ArgumentError {
    return null;
  }
}

final libraryBooksProvider = StreamProvider<List<BookRecord>>((ref) {
  final database = ref.watch(databaseProvider);
  if (database == null) {
    return Stream.value(const []);
  }
  final query = database.select(database.books)
    ..orderBy([
      (book) => OrderingTerm(
        expression: book.lastReadAt,
        mode: OrderingMode.desc,
        nulls: NullsOrder.last,
      ),
      (book) => OrderingTerm.desc(book.importedAt),
    ]);
  return query.watch();
});

final readerPageDataProvider = FutureProvider.autoDispose
    .family<ReaderPageData, ReaderPageRequest>((ref, request) async {
      final bookId = request.bookId;
      final database = ref.watch(databaseProvider);
      if (database == null) {
        throw StateError('Database is unavailable.');
      }
      final book = await (database.select(
        database.books,
      )..where((row) => row.id.equals(bookId))).getSingle();
      final chapters = await database.chaptersForBook(bookId);
      final readerChapters = [
        for (final record in chapters)
          ReaderChapter(
            id: record.id,
            index: record.chapterIndex,
            title: record.title,
          ),
      ];
      if (chapters.isEmpty) {
        return ReaderPageData(
          book: book,
          chapters: const [],
          savedCursor: null,
        );
      }
      final progress = await database.progressForBook(bookId);
      final requestedChapterId = request.chapterId;
      final requestedChapter = requestedChapterId == null
          ? null
          : readerChapters
                .where((chapter) => chapter.id == requestedChapterId)
                .firstOrNull;
      final progressChapter = progress == null
          ? null
          : readerChapters
                .where((chapter) => chapter.id == progress.chapterId)
                .firstOrNull;
      final selectedChapter =
          requestedChapter ?? progressChapter ?? readerChapters.first;
      final savedParagraphIndex = progress?.chapterId == selectedChapter.id
          ? progress?.paragraphIndex ?? 0
          : 0;
      return ReaderPageData(
        book: book,
        chapters: readerChapters,
        savedCursor: PlaybackCursor(
          chapterId: selectedChapter.id,
          paragraphIndex: savedParagraphIndex,
        ),
      );
    });

Future<ReaderChapterSection> loadReaderChapterSection(
  AppDatabase database,
  ReaderChapter chapter,
) async {
  final records = await database.paragraphsForChapter(chapter.id);
  return ReaderChapterSection(
    chapter: chapter,
    paragraphs: [
      for (final record in records)
        ReaderParagraph(
          id: record.id,
          chapterId: chapter.id,
          index: record.paragraphIndex,
          text: record.content,
        ),
    ],
  );
}

final class ReaderPageRequest {
  const ReaderPageRequest(this.bookId, [this.chapterId]);

  final int bookId;
  final int? chapterId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderPageRequest &&
          bookId == other.bookId &&
          chapterId == other.chapterId;

  @override
  int get hashCode => Object.hash(bookId, chapterId);
}

final class ReaderPageData {
  const ReaderPageData({
    required this.book,
    required this.chapters,
    required this.savedCursor,
  });

  final BookRecord book;
  final List<ReaderChapter> chapters;
  final PlaybackCursor? savedCursor;
}
