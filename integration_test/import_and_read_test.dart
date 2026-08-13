import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:novel_voice_reader/app/app.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/library/data/book_import_repository.dart';
import 'package:novel_voice_reader/features/library/data/epub_book_parser.dart';
import 'package:novel_voice_reader/features/library/data/txt_book_parser.dart';
import 'package:novel_voice_reader/features/reader/data/reading_progress_repository.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('imports TXT, opens it, and restores confirmed progress', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final bookId =
        await BookImportRepository(
          database: database,
          txtParser: const TxtBookParser(),
          epubParser: const EpubBookParser(),
        ).importBytes(
          Uint8List.fromList(utf8.encode('第一章\n第一段。\n第二段。')),
          fileName: '测试.txt',
        );
    final chapter = await database.firstChapterForBook(bookId);
    await DriftPlaybackProgressRepository(
      database: database,
      bookId: bookId,
    ).confirm(PlaybackCursor(chapterId: chapter.id, paragraphIndex: 1));

    await tester.pumpWidget(NovelVoiceReaderApp(database: database));
    await _pumpUntilFound(tester, find.text('测试'));
    await tester.tap(find.text('测试'));
    await _pumpUntilFound(tester, find.text('第二段。'));

    final restored = await DriftPlaybackProgressRepository(
      database: database,
      bookId: bookId,
    ).restore();
    expect(restored?.paragraphIndex, 1);
    expect(await database.select(database.voiceProfiles).get(), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for the expected widget.');
}
