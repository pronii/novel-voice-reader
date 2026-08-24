import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
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
    legacy.execute('''
      CREATE TABLE voice_profiles (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        provider_type TEXT NOT NULL,
        base_url TEXT NULL,
        model TEXT NULL,
        voice TEXT NULL,
        speed REAL NOT NULL DEFAULT 1,
        pitch REAL NULL,
        output_format TEXT NULL
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

    // The v1->v2 migration must create the monthly-usage table; inserting a
    // row would throw if the table were missing.
    await database
        .into(database.tencentTtsMonthlyUsages)
        .insert(
          TencentTtsMonthlyUsagesCompanion.insert(
            period: '2026-08',
            quotaCharacters: const Value(1000),
            updatedAt: DateTime.now(),
          ),
        );
    final usage = await database
        .select(database.tencentTtsMonthlyUsages)
        .getSingle();
    expect(usage.quotaCharacters, 1000);
  });

  test('upgrades v2 voice profiles with a nullable narration style', () async {
    final directory = await Directory.systemTemp.createTemp('novel-db-v2-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}reader.sqlite',
    );
    final legacy = sqlite3.open(file.path);
    legacy.execute('''
      CREATE TABLE voice_profiles (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        provider_type TEXT NOT NULL,
        base_url TEXT NULL,
        model TEXT NULL,
        voice TEXT NULL,
        speed REAL NOT NULL DEFAULT 1,
        pitch REAL NULL,
        output_format TEXT NULL
      );
    ''');
    legacy.execute(
      "INSERT INTO voice_profiles (provider_type, voice) VALUES ('system', NULL);",
    );
    // Opening the database migrates all the way to the current version, and the
    // 4->5 step alters `books`, so this fixture must include that table even
    // though the test targets the voice_profiles migration.
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
    legacy.execute('PRAGMA user_version = 2;');
    legacy.close();

    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);
    await database
        .into(database.voiceProfiles)
        .insert(
          VoiceProfilesCompanion.insert(
            providerType: 'mimo',
            voice: const Value('冰糖'),
            style: const Value('平静地朗读'),
          ),
        );

    final records = await database.select(database.voiceProfiles).get();
    expect(records.first.style, isNull);
    expect(records.last.style, '平静地朗读');
  });

  test('a fresh database creates the audio cache (bookId, status) index', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final indexes = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'audio_cache_entries_book_status'",
        )
        .get();

    expect(indexes, hasLength(1));
  });

  test('the v3->v4 migration adds the audio cache (bookId, status) index', () async {
    final directory = await Directory.systemTemp.createTemp('novel-db-v3-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}reader.sqlite',
    );
    final legacy = sqlite3.open(file.path);
    legacy.execute('''
      CREATE TABLE audio_cache_entries (
        cache_key TEXT NOT NULL PRIMARY KEY,
        book_id INTEGER NOT NULL,
        chapter_id INTEGER NOT NULL,
        paragraph_id INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        byte_size INTEGER NOT NULL,
        status TEXT NOT NULL,
        last_accessed_at INTEGER NOT NULL
      );
    ''');
    // Opening the database migrates all the way to the current version, and the
    // 4->5 step alters `books`, so this fixture must include that table even
    // though the test targets the audio-cache index migration.
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
    legacy.execute('PRAGMA user_version = 3;');
    legacy.close();

    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);

    final indexes = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'audio_cache_entries_book_status'",
        )
        .get();

    expect(indexes, hasLength(1));
  });

  test('the v4->v5 migration adds the book cover columns', () async {
    final directory = await Directory.systemTemp.createTemp('novel-db-v4-');
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
      "INSERT INTO books (title, imported_at) VALUES ('封面测试', 0);",
    );
    legacy.execute('PRAGMA user_version = 4;');
    legacy.close();

    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);

    // The existing row survives the migration with a null cover, and the two
    // new columns are writable through setBookCover.
    final before = await database.select(database.books).getSingle();
    expect(before.title, '封面测试');
    expect(before.coverImagePath, isNull);
    expect(before.coverFetchedAt, isNull);

    await database.setBookCover(bookId: before.id, path: '/covers/book-1');
    final after = await database.select(database.books).getSingle();
    expect(after.coverImagePath, '/covers/book-1');
    expect(after.coverFetchedAt, isNotNull);
  });
}
