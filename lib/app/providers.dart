import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_handler.dart';
import 'package:novel_voice_reader/features/reader/presentation/reader_page.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

final databaseProvider = Provider<AppDatabase?>((ref) => null);
final playbackRuntimeProvider = Provider<PlaybackRuntime?>((ref) => null);

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
    'azure' => _azureProfileFromRecord(record),
    _ => VoiceProfile.system(),
  };
}

VoiceProfile _azureProfileFromRecord(VoiceProfileRecord record) {
  final region = _azureRegion(record.baseUrl);
  if (region == null) {
    return VoiceProfile.system();
  }
  return VoiceProfile.azure(
    region: region,
    voice: record.voice ?? VoiceProfile.defaultAzureVoice,
    speed: record.speed,
    outputFormat: record.outputFormat ?? VoiceProfile.defaultAzureOutputFormat,
  );
}

String? _azureRegion(String? baseUrl) {
  final host = Uri.tryParse(baseUrl ?? '')?.host.toLowerCase() ?? '';
  const suffix = '.tts.speech.microsoft.com';
  if (!host.endsWith(suffix)) {
    return null;
  }
  final region = host.substring(0, host.length - suffix.length);
  return region.isEmpty ? null : region;
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

final readerPageDataProvider =
    FutureProvider.family<ReaderPageData, ReaderPageRequest>((
      ref,
      request,
    ) async {
      final bookId = request.bookId;
      final database = ref.watch(databaseProvider);
      if (database == null) {
        throw StateError('Database is unavailable.');
      }
      final book = await (database.select(
        database.books,
      )..where((row) => row.id.equals(bookId))).getSingle();
      final chapters = await database.chaptersForBook(bookId);
      if (chapters.isEmpty) {
        return ReaderPageData(
          book: book,
          chapter: null,
          chapters: const [],
          paragraphs: const [],
          activeParagraphId: null,
        );
      }
      final progress = await database.progressForBook(bookId);
      final requestedChapterId = request.chapterId;
      final chapter = requestedChapterId != null
          ? chapters.firstWhere(
              (candidate) => candidate.id == requestedChapterId,
              orElse: () => chapters.first,
            )
          : progress == null
          ? chapters.first
          : chapters.firstWhere(
              (candidate) => candidate.id == progress.chapterId,
              orElse: () => chapters.first,
            );
      final records = await database.paragraphsForChapter(chapter.id);
      final savedParagraphIndex = progress?.chapterId == chapter.id
          ? progress?.paragraphIndex ?? 0
          : 0;
      final activeIndex = savedParagraphIndex.clamp(
        0,
        records.isEmpty ? 0 : records.length - 1,
      );
      return ReaderPageData(
        book: book,
        chapter: chapter,
        chapters: [
          for (final record in chapters)
            ReaderChapter(
              id: record.id,
              index: record.chapterIndex,
              title: record.title,
            ),
        ],
        paragraphs: [
          for (final record in records)
            ReaderParagraph(
              id: record.id,
              index: record.paragraphIndex,
              text: record.content,
            ),
        ],
        activeParagraphId: records.isEmpty ? null : records[activeIndex].id,
      );
    });

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
    required this.chapter,
    required this.chapters,
    required this.paragraphs,
    required this.activeParagraphId,
  });

  final BookRecord book;
  final ChapterRecord? chapter;
  final List<ReaderChapter> chapters;
  final List<ReaderParagraph> paragraphs;
  final int? activeParagraphId;

  int get currentChapterIndex => chapter == null
      ? -1
      : chapters.indexWhere((candidate) => candidate.id == chapter!.id);
}
