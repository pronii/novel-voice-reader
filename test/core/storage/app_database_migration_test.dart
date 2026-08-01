import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/speech/data/tencent_tts_usage_repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('upgrades v1 data and creates the Tencent usage table', () async {
    final directory = await Directory.systemTemp.createTemp('novel-db-v1-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}reader.sqlite',
    );
    final legacy = sqlite3.open(file.path);
    legacy.execute('''
      CREATE TABLE books (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        source_type TEXT NOT NULL DEFAULT 'txt',
        source_file_name TEXT NULL,
        imported_at INTEGER NOT NULL,
        last_read_at INTEGER NULL
      );
    ''');
    legacy.execute(
      "INSERT INTO books (title, imported_at) VALUES ('旧版小说', 0);",
    );
    legacy.execute('PRAGMA user_version = 1;');
    legacy.close();

    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);

    final books = await database.select(database.books).get();
    expect(books.single.title, '旧版小说');

    final usage = TencentTtsUsageRepository(database);
    await usage.setMonthlyQuota(1000);
    expect((await usage.current()).quotaCharacters, 1000);
  });
}
