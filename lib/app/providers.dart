import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/downloads/application/audio_cache_runtime.dart';
import 'package:novel_voice_reader/features/playback/application/sleep_timer_controller.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_handler.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_content.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

final databaseProvider = Provider<AppDatabase?>((ref) => null);
final playbackRuntimeProvider = Provider<PlaybackRuntime?>((ref) => null);
final audioCacheRuntimeProvider = Provider<AudioCacheRuntime?>((ref) => null);

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
    },
    currentChapterId: () => runtime?.currentCursor?.chapterId,
    cursorChanges: () =>
        runtime?.cursorChanges ?? const Stream<PlaybackCursor?>.empty(),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

Future<VoiceProfile> loadActiveVoiceProfile(AppDatabase database) async {
  final query = database.select(database.voiceProfiles)
    ..orderBy([(profile) => OrderingTerm.desc(profile.id)])
    ..limit(1);
  return voiceProfileFromRecord(await query.getSingleOrNull());
}

VoiceProfile voiceProfileFromRecord(VoiceProfileRecord? record) {
  if (record == null) {
    return VoiceProfile.system();
  }
  try {
    return switch (record.providerType) {
      'system' => VoiceProfile.system(
        voice: record.voice,
        speed: record.speed,
        pitch: record.pitch ?? 1,
      ),
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
      'mimo' => VoiceProfile.mimo(
        voice: record.voice ?? VoiceProfile.defaultMiMoVoice,
        style: record.style,
        speed: record.speed,
      ),
      _ => VoiceProfile.system(),
    };
  } on ArgumentError {
    return VoiceProfile.system();
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
