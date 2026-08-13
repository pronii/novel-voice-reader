// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, BookRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('txt'),
  );
  static const VerificationMeta _sourceFileNameMeta = const VerificationMeta(
    'sourceFileName',
  );
  @override
  late final GeneratedColumn<String> sourceFileName = GeneratedColumn<String>(
    'source_file_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastReadAtMeta = const VerificationMeta(
    'lastReadAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReadAt = GeneratedColumn<DateTime>(
    'last_read_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    sourceType,
    sourceFileName,
    importedAt,
    lastReadAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    }
    if (data.containsKey('source_file_name')) {
      context.handle(
        _sourceFileNameMeta,
        sourceFileName.isAcceptableOrUnknown(
          data['source_file_name']!,
          _sourceFileNameMeta,
        ),
      );
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    }
    if (data.containsKey('last_read_at')) {
      context.handle(
        _lastReadAtMeta,
        lastReadAt.isAcceptableOrUnknown(
          data['last_read_at']!,
          _lastReadAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      sourceFileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_file_name'],
      ),
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
      lastReadAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_read_at'],
      ),
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class BookRecord extends DataClass implements Insertable<BookRecord> {
  final int id;
  final String title;
  final String sourceType;
  final String? sourceFileName;
  final DateTime importedAt;
  final DateTime? lastReadAt;
  const BookRecord({
    required this.id,
    required this.title,
    required this.sourceType,
    this.sourceFileName,
    required this.importedAt,
    this.lastReadAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['source_type'] = Variable<String>(sourceType);
    if (!nullToAbsent || sourceFileName != null) {
      map['source_file_name'] = Variable<String>(sourceFileName);
    }
    map['imported_at'] = Variable<DateTime>(importedAt);
    if (!nullToAbsent || lastReadAt != null) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt);
    }
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      title: Value(title),
      sourceType: Value(sourceType),
      sourceFileName: sourceFileName == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceFileName),
      importedAt: Value(importedAt),
      lastReadAt: lastReadAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadAt),
    );
  }

  factory BookRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookRecord(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      sourceFileName: serializer.fromJson<String?>(json['sourceFileName']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
      lastReadAt: serializer.fromJson<DateTime?>(json['lastReadAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'sourceType': serializer.toJson<String>(sourceType),
      'sourceFileName': serializer.toJson<String?>(sourceFileName),
      'importedAt': serializer.toJson<DateTime>(importedAt),
      'lastReadAt': serializer.toJson<DateTime?>(lastReadAt),
    };
  }

  BookRecord copyWith({
    int? id,
    String? title,
    String? sourceType,
    Value<String?> sourceFileName = const Value.absent(),
    DateTime? importedAt,
    Value<DateTime?> lastReadAt = const Value.absent(),
  }) => BookRecord(
    id: id ?? this.id,
    title: title ?? this.title,
    sourceType: sourceType ?? this.sourceType,
    sourceFileName: sourceFileName.present
        ? sourceFileName.value
        : this.sourceFileName,
    importedAt: importedAt ?? this.importedAt,
    lastReadAt: lastReadAt.present ? lastReadAt.value : this.lastReadAt,
  );
  BookRecord copyWithCompanion(BooksCompanion data) {
    return BookRecord(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      sourceFileName: data.sourceFileName.present
          ? data.sourceFileName.value
          : this.sourceFileName,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      lastReadAt: data.lastReadAt.present
          ? data.lastReadAt.value
          : this.lastReadAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookRecord(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceFileName: $sourceFileName, ')
          ..write('importedAt: $importedAt, ')
          ..write('lastReadAt: $lastReadAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    sourceType,
    sourceFileName,
    importedAt,
    lastReadAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookRecord &&
          other.id == this.id &&
          other.title == this.title &&
          other.sourceType == this.sourceType &&
          other.sourceFileName == this.sourceFileName &&
          other.importedAt == this.importedAt &&
          other.lastReadAt == this.lastReadAt);
}

class BooksCompanion extends UpdateCompanion<BookRecord> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> sourceType;
  final Value<String?> sourceFileName;
  final Value<DateTime> importedAt;
  final Value<DateTime?> lastReadAt;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceFileName = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.lastReadAt = const Value.absent(),
  });
  BooksCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.sourceType = const Value.absent(),
    this.sourceFileName = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.lastReadAt = const Value.absent(),
  }) : title = Value(title);
  static Insertable<BookRecord> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? sourceType,
    Expression<String>? sourceFileName,
    Expression<DateTime>? importedAt,
    Expression<DateTime>? lastReadAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (sourceType != null) 'source_type': sourceType,
      if (sourceFileName != null) 'source_file_name': sourceFileName,
      if (importedAt != null) 'imported_at': importedAt,
      if (lastReadAt != null) 'last_read_at': lastReadAt,
    });
  }

  BooksCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? sourceType,
    Value<String?>? sourceFileName,
    Value<DateTime>? importedAt,
    Value<DateTime?>? lastReadAt,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      sourceType: sourceType ?? this.sourceType,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      importedAt: importedAt ?? this.importedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (sourceFileName.present) {
      map['source_file_name'] = Variable<String>(sourceFileName.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (lastReadAt.present) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceFileName: $sourceFileName, ')
          ..write('importedAt: $importedAt, ')
          ..write('lastReadAt: $lastReadAt')
          ..write(')'))
        .toString();
  }
}

class $ChaptersTable extends Chapters
    with TableInfo<$ChaptersTable, ChapterRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, bookId, chapterIndex, title];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChapterRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {bookId, chapterIndex},
  ];
  @override
  ChapterRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChapterRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_id'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
    );
  }

  @override
  $ChaptersTable createAlias(String alias) {
    return $ChaptersTable(attachedDatabase, alias);
  }
}

class ChapterRecord extends DataClass implements Insertable<ChapterRecord> {
  final int id;
  final int bookId;
  final int chapterIndex;
  final String title;
  const ChapterRecord({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.title,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<int>(bookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['title'] = Variable<String>(title);
    return map;
  }

  ChaptersCompanion toCompanion(bool nullToAbsent) {
    return ChaptersCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      title: Value(title),
    );
  }

  factory ChapterRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChapterRecord(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<int>(json['bookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      title: serializer.fromJson<String>(json['title']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<int>(bookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'title': serializer.toJson<String>(title),
    };
  }

  ChapterRecord copyWith({
    int? id,
    int? bookId,
    int? chapterIndex,
    String? title,
  }) => ChapterRecord(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    title: title ?? this.title,
  );
  ChapterRecord copyWithCompanion(ChaptersCompanion data) {
    return ChapterRecord(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      title: data.title.present ? data.title.value : this.title,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChapterRecord(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('title: $title')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bookId, chapterIndex, title);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChapterRecord &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterIndex == this.chapterIndex &&
          other.title == this.title);
}

class ChaptersCompanion extends UpdateCompanion<ChapterRecord> {
  final Value<int> id;
  final Value<int> bookId;
  final Value<int> chapterIndex;
  final Value<String> title;
  const ChaptersCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.title = const Value.absent(),
  });
  ChaptersCompanion.insert({
    this.id = const Value.absent(),
    required int bookId,
    required int chapterIndex,
    required String title,
  }) : bookId = Value(bookId),
       chapterIndex = Value(chapterIndex),
       title = Value(title);
  static Insertable<ChapterRecord> custom({
    Expression<int>? id,
    Expression<int>? bookId,
    Expression<int>? chapterIndex,
    Expression<String>? title,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (title != null) 'title': title,
    });
  }

  ChaptersCompanion copyWith({
    Value<int>? id,
    Value<int>? bookId,
    Value<int>? chapterIndex,
    Value<String>? title,
  }) {
    return ChaptersCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      title: title ?? this.title,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChaptersCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('title: $title')
          ..write(')'))
        .toString();
  }
}

class $ParagraphsTable extends Paragraphs
    with TableInfo<$ParagraphsTable, ParagraphRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParagraphsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<int> chapterId = GeneratedColumn<int>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chapters (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _paragraphIndexMeta = const VerificationMeta(
    'paragraphIndex',
  );
  @override
  late final GeneratedColumn<int> paragraphIndex = GeneratedColumn<int>(
    'paragraph_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    chapterId,
    paragraphIndex,
    content,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'paragraphs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ParagraphRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('paragraph_index')) {
      context.handle(
        _paragraphIndexMeta,
        paragraphIndex.isAcceptableOrUnknown(
          data['paragraph_index']!,
          _paragraphIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paragraphIndexMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {chapterId, paragraphIndex},
  ];
  @override
  ParagraphRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ParagraphRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_id'],
      )!,
      paragraphIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paragraph_index'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
    );
  }

  @override
  $ParagraphsTable createAlias(String alias) {
    return $ParagraphsTable(attachedDatabase, alias);
  }
}

class ParagraphRecord extends DataClass implements Insertable<ParagraphRecord> {
  final int id;
  final int chapterId;
  final int paragraphIndex;
  final String content;
  const ParagraphRecord({
    required this.id,
    required this.chapterId,
    required this.paragraphIndex,
    required this.content,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['chapter_id'] = Variable<int>(chapterId);
    map['paragraph_index'] = Variable<int>(paragraphIndex);
    map['content'] = Variable<String>(content);
    return map;
  }

  ParagraphsCompanion toCompanion(bool nullToAbsent) {
    return ParagraphsCompanion(
      id: Value(id),
      chapterId: Value(chapterId),
      paragraphIndex: Value(paragraphIndex),
      content: Value(content),
    );
  }

  factory ParagraphRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ParagraphRecord(
      id: serializer.fromJson<int>(json['id']),
      chapterId: serializer.fromJson<int>(json['chapterId']),
      paragraphIndex: serializer.fromJson<int>(json['paragraphIndex']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'chapterId': serializer.toJson<int>(chapterId),
      'paragraphIndex': serializer.toJson<int>(paragraphIndex),
      'content': serializer.toJson<String>(content),
    };
  }

  ParagraphRecord copyWith({
    int? id,
    int? chapterId,
    int? paragraphIndex,
    String? content,
  }) => ParagraphRecord(
    id: id ?? this.id,
    chapterId: chapterId ?? this.chapterId,
    paragraphIndex: paragraphIndex ?? this.paragraphIndex,
    content: content ?? this.content,
  );
  ParagraphRecord copyWithCompanion(ParagraphsCompanion data) {
    return ParagraphRecord(
      id: data.id.present ? data.id.value : this.id,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      paragraphIndex: data.paragraphIndex.present
          ? data.paragraphIndex.value
          : this.paragraphIndex,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ParagraphRecord(')
          ..write('id: $id, ')
          ..write('chapterId: $chapterId, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, chapterId, paragraphIndex, content);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParagraphRecord &&
          other.id == this.id &&
          other.chapterId == this.chapterId &&
          other.paragraphIndex == this.paragraphIndex &&
          other.content == this.content);
}

class ParagraphsCompanion extends UpdateCompanion<ParagraphRecord> {
  final Value<int> id;
  final Value<int> chapterId;
  final Value<int> paragraphIndex;
  final Value<String> content;
  const ParagraphsCompanion({
    this.id = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.paragraphIndex = const Value.absent(),
    this.content = const Value.absent(),
  });
  ParagraphsCompanion.insert({
    this.id = const Value.absent(),
    required int chapterId,
    required int paragraphIndex,
    required String content,
  }) : chapterId = Value(chapterId),
       paragraphIndex = Value(paragraphIndex),
       content = Value(content);
  static Insertable<ParagraphRecord> custom({
    Expression<int>? id,
    Expression<int>? chapterId,
    Expression<int>? paragraphIndex,
    Expression<String>? content,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chapterId != null) 'chapter_id': chapterId,
      if (paragraphIndex != null) 'paragraph_index': paragraphIndex,
      if (content != null) 'content': content,
    });
  }

  ParagraphsCompanion copyWith({
    Value<int>? id,
    Value<int>? chapterId,
    Value<int>? paragraphIndex,
    Value<String>? content,
  }) {
    return ParagraphsCompanion(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      paragraphIndex: paragraphIndex ?? this.paragraphIndex,
      content: content ?? this.content,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<int>(chapterId.value);
    }
    if (paragraphIndex.present) {
      map['paragraph_index'] = Variable<int>(paragraphIndex.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParagraphsCompanion(')
          ..write('id: $id, ')
          ..write('chapterId: $chapterId, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressesTable extends ReadingProgresses
    with TableInfo<$ReadingProgressesTable, ReadingProgressRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<int> chapterId = GeneratedColumn<int>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chapters (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _paragraphIndexMeta = const VerificationMeta(
    'paragraphIndex',
  );
  @override
  late final GeneratedColumn<int> paragraphIndex = GeneratedColumn<int>(
    'paragraph_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    chapterId,
    paragraphIndex,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingProgressRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('paragraph_index')) {
      context.handle(
        _paragraphIndexMeta,
        paragraphIndex.isAcceptableOrUnknown(
          data['paragraph_index']!,
          _paragraphIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paragraphIndexMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  ReadingProgressRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressRecord(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_id'],
      )!,
      paragraphIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paragraph_index'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReadingProgressesTable createAlias(String alias) {
    return $ReadingProgressesTable(attachedDatabase, alias);
  }
}

class ReadingProgressRecord extends DataClass
    implements Insertable<ReadingProgressRecord> {
  final int bookId;
  final int chapterId;
  final int paragraphIndex;
  final DateTime updatedAt;
  const ReadingProgressRecord({
    required this.bookId,
    required this.chapterId,
    required this.paragraphIndex,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<int>(bookId);
    map['chapter_id'] = Variable<int>(chapterId);
    map['paragraph_index'] = Variable<int>(paragraphIndex);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReadingProgressesCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressesCompanion(
      bookId: Value(bookId),
      chapterId: Value(chapterId),
      paragraphIndex: Value(paragraphIndex),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReadingProgressRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressRecord(
      bookId: serializer.fromJson<int>(json['bookId']),
      chapterId: serializer.fromJson<int>(json['chapterId']),
      paragraphIndex: serializer.fromJson<int>(json['paragraphIndex']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<int>(bookId),
      'chapterId': serializer.toJson<int>(chapterId),
      'paragraphIndex': serializer.toJson<int>(paragraphIndex),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReadingProgressRecord copyWith({
    int? bookId,
    int? chapterId,
    int? paragraphIndex,
    DateTime? updatedAt,
  }) => ReadingProgressRecord(
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    paragraphIndex: paragraphIndex ?? this.paragraphIndex,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReadingProgressRecord copyWithCompanion(ReadingProgressesCompanion data) {
    return ReadingProgressRecord(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      paragraphIndex: data.paragraphIndex.present
          ? data.paragraphIndex.value
          : this.paragraphIndex,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressRecord(')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, chapterId, paragraphIndex, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressRecord &&
          other.bookId == this.bookId &&
          other.chapterId == this.chapterId &&
          other.paragraphIndex == this.paragraphIndex &&
          other.updatedAt == this.updatedAt);
}

class ReadingProgressesCompanion
    extends UpdateCompanion<ReadingProgressRecord> {
  final Value<int> bookId;
  final Value<int> chapterId;
  final Value<int> paragraphIndex;
  final Value<DateTime> updatedAt;
  const ReadingProgressesCompanion({
    this.bookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.paragraphIndex = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ReadingProgressesCompanion.insert({
    this.bookId = const Value.absent(),
    required int chapterId,
    required int paragraphIndex,
    required DateTime updatedAt,
  }) : chapterId = Value(chapterId),
       paragraphIndex = Value(paragraphIndex),
       updatedAt = Value(updatedAt);
  static Insertable<ReadingProgressRecord> custom({
    Expression<int>? bookId,
    Expression<int>? chapterId,
    Expression<int>? paragraphIndex,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (paragraphIndex != null) 'paragraph_index': paragraphIndex,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ReadingProgressesCompanion copyWith({
    Value<int>? bookId,
    Value<int>? chapterId,
    Value<int>? paragraphIndex,
    Value<DateTime>? updatedAt,
  }) {
    return ReadingProgressesCompanion(
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      paragraphIndex: paragraphIndex ?? this.paragraphIndex,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<int>(chapterId.value);
    }
    if (paragraphIndex.present) {
      map['paragraph_index'] = Variable<int>(paragraphIndex.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressesCompanion(')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('paragraphIndex: $paragraphIndex, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $VoiceProfilesTable extends VoiceProfiles
    with TableInfo<$VoiceProfilesTable, VoiceProfileRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VoiceProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _providerTypeMeta = const VerificationMeta(
    'providerType',
  );
  @override
  late final GeneratedColumn<String> providerType = GeneratedColumn<String>(
    'provider_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voiceMeta = const VerificationMeta('voice');
  @override
  late final GeneratedColumn<String> voice = GeneratedColumn<String>(
    'voice',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
    'speed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _pitchMeta = const VerificationMeta('pitch');
  @override
  late final GeneratedColumn<double> pitch = GeneratedColumn<double>(
    'pitch',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outputFormatMeta = const VerificationMeta(
    'outputFormat',
  );
  @override
  late final GeneratedColumn<String> outputFormat = GeneratedColumn<String>(
    'output_format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _styleMeta = const VerificationMeta('style');
  @override
  late final GeneratedColumn<String> style = GeneratedColumn<String>(
    'style',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    providerType,
    baseUrl,
    model,
    voice,
    speed,
    pitch,
    outputFormat,
    style,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'voice_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<VoiceProfileRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('provider_type')) {
      context.handle(
        _providerTypeMeta,
        providerType.isAcceptableOrUnknown(
          data['provider_type']!,
          _providerTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerTypeMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('voice')) {
      context.handle(
        _voiceMeta,
        voice.isAcceptableOrUnknown(data['voice']!, _voiceMeta),
      );
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    }
    if (data.containsKey('pitch')) {
      context.handle(
        _pitchMeta,
        pitch.isAcceptableOrUnknown(data['pitch']!, _pitchMeta),
      );
    }
    if (data.containsKey('output_format')) {
      context.handle(
        _outputFormatMeta,
        outputFormat.isAcceptableOrUnknown(
          data['output_format']!,
          _outputFormatMeta,
        ),
      );
    }
    if (data.containsKey('style')) {
      context.handle(
        _styleMeta,
        style.isAcceptableOrUnknown(data['style']!, _styleMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VoiceProfileRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VoiceProfileRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      providerType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_type'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      voice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice'],
      ),
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed'],
      )!,
      pitch: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pitch'],
      ),
      outputFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_format'],
      ),
      style: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}style'],
      ),
    );
  }

  @override
  $VoiceProfilesTable createAlias(String alias) {
    return $VoiceProfilesTable(attachedDatabase, alias);
  }
}

class VoiceProfileRecord extends DataClass
    implements Insertable<VoiceProfileRecord> {
  final int id;
  final String providerType;
  final String? baseUrl;
  final String? model;
  final String? voice;
  final double speed;
  final double? pitch;
  final String? outputFormat;
  final String? style;
  const VoiceProfileRecord({
    required this.id,
    required this.providerType,
    this.baseUrl,
    this.model,
    this.voice,
    required this.speed,
    this.pitch,
    this.outputFormat,
    this.style,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['provider_type'] = Variable<String>(providerType);
    if (!nullToAbsent || baseUrl != null) {
      map['base_url'] = Variable<String>(baseUrl);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || voice != null) {
      map['voice'] = Variable<String>(voice);
    }
    map['speed'] = Variable<double>(speed);
    if (!nullToAbsent || pitch != null) {
      map['pitch'] = Variable<double>(pitch);
    }
    if (!nullToAbsent || outputFormat != null) {
      map['output_format'] = Variable<String>(outputFormat);
    }
    if (!nullToAbsent || style != null) {
      map['style'] = Variable<String>(style);
    }
    return map;
  }

  VoiceProfilesCompanion toCompanion(bool nullToAbsent) {
    return VoiceProfilesCompanion(
      id: Value(id),
      providerType: Value(providerType),
      baseUrl: baseUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(baseUrl),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      voice: voice == null && nullToAbsent
          ? const Value.absent()
          : Value(voice),
      speed: Value(speed),
      pitch: pitch == null && nullToAbsent
          ? const Value.absent()
          : Value(pitch),
      outputFormat: outputFormat == null && nullToAbsent
          ? const Value.absent()
          : Value(outputFormat),
      style: style == null && nullToAbsent
          ? const Value.absent()
          : Value(style),
    );
  }

  factory VoiceProfileRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VoiceProfileRecord(
      id: serializer.fromJson<int>(json['id']),
      providerType: serializer.fromJson<String>(json['providerType']),
      baseUrl: serializer.fromJson<String?>(json['baseUrl']),
      model: serializer.fromJson<String?>(json['model']),
      voice: serializer.fromJson<String?>(json['voice']),
      speed: serializer.fromJson<double>(json['speed']),
      pitch: serializer.fromJson<double?>(json['pitch']),
      outputFormat: serializer.fromJson<String?>(json['outputFormat']),
      style: serializer.fromJson<String?>(json['style']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'providerType': serializer.toJson<String>(providerType),
      'baseUrl': serializer.toJson<String?>(baseUrl),
      'model': serializer.toJson<String?>(model),
      'voice': serializer.toJson<String?>(voice),
      'speed': serializer.toJson<double>(speed),
      'pitch': serializer.toJson<double?>(pitch),
      'outputFormat': serializer.toJson<String?>(outputFormat),
      'style': serializer.toJson<String?>(style),
    };
  }

  VoiceProfileRecord copyWith({
    int? id,
    String? providerType,
    Value<String?> baseUrl = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<String?> voice = const Value.absent(),
    double? speed,
    Value<double?> pitch = const Value.absent(),
    Value<String?> outputFormat = const Value.absent(),
    Value<String?> style = const Value.absent(),
  }) => VoiceProfileRecord(
    id: id ?? this.id,
    providerType: providerType ?? this.providerType,
    baseUrl: baseUrl.present ? baseUrl.value : this.baseUrl,
    model: model.present ? model.value : this.model,
    voice: voice.present ? voice.value : this.voice,
    speed: speed ?? this.speed,
    pitch: pitch.present ? pitch.value : this.pitch,
    outputFormat: outputFormat.present ? outputFormat.value : this.outputFormat,
    style: style.present ? style.value : this.style,
  );
  VoiceProfileRecord copyWithCompanion(VoiceProfilesCompanion data) {
    return VoiceProfileRecord(
      id: data.id.present ? data.id.value : this.id,
      providerType: data.providerType.present
          ? data.providerType.value
          : this.providerType,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      model: data.model.present ? data.model.value : this.model,
      voice: data.voice.present ? data.voice.value : this.voice,
      speed: data.speed.present ? data.speed.value : this.speed,
      pitch: data.pitch.present ? data.pitch.value : this.pitch,
      outputFormat: data.outputFormat.present
          ? data.outputFormat.value
          : this.outputFormat,
      style: data.style.present ? data.style.value : this.style,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VoiceProfileRecord(')
          ..write('id: $id, ')
          ..write('providerType: $providerType, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('model: $model, ')
          ..write('voice: $voice, ')
          ..write('speed: $speed, ')
          ..write('pitch: $pitch, ')
          ..write('outputFormat: $outputFormat, ')
          ..write('style: $style')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    providerType,
    baseUrl,
    model,
    voice,
    speed,
    pitch,
    outputFormat,
    style,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VoiceProfileRecord &&
          other.id == this.id &&
          other.providerType == this.providerType &&
          other.baseUrl == this.baseUrl &&
          other.model == this.model &&
          other.voice == this.voice &&
          other.speed == this.speed &&
          other.pitch == this.pitch &&
          other.outputFormat == this.outputFormat &&
          other.style == this.style);
}

class VoiceProfilesCompanion extends UpdateCompanion<VoiceProfileRecord> {
  final Value<int> id;
  final Value<String> providerType;
  final Value<String?> baseUrl;
  final Value<String?> model;
  final Value<String?> voice;
  final Value<double> speed;
  final Value<double?> pitch;
  final Value<String?> outputFormat;
  final Value<String?> style;
  const VoiceProfilesCompanion({
    this.id = const Value.absent(),
    this.providerType = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.model = const Value.absent(),
    this.voice = const Value.absent(),
    this.speed = const Value.absent(),
    this.pitch = const Value.absent(),
    this.outputFormat = const Value.absent(),
    this.style = const Value.absent(),
  });
  VoiceProfilesCompanion.insert({
    this.id = const Value.absent(),
    required String providerType,
    this.baseUrl = const Value.absent(),
    this.model = const Value.absent(),
    this.voice = const Value.absent(),
    this.speed = const Value.absent(),
    this.pitch = const Value.absent(),
    this.outputFormat = const Value.absent(),
    this.style = const Value.absent(),
  }) : providerType = Value(providerType);
  static Insertable<VoiceProfileRecord> custom({
    Expression<int>? id,
    Expression<String>? providerType,
    Expression<String>? baseUrl,
    Expression<String>? model,
    Expression<String>? voice,
    Expression<double>? speed,
    Expression<double>? pitch,
    Expression<String>? outputFormat,
    Expression<String>? style,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (providerType != null) 'provider_type': providerType,
      if (baseUrl != null) 'base_url': baseUrl,
      if (model != null) 'model': model,
      if (voice != null) 'voice': voice,
      if (speed != null) 'speed': speed,
      if (pitch != null) 'pitch': pitch,
      if (outputFormat != null) 'output_format': outputFormat,
      if (style != null) 'style': style,
    });
  }

  VoiceProfilesCompanion copyWith({
    Value<int>? id,
    Value<String>? providerType,
    Value<String?>? baseUrl,
    Value<String?>? model,
    Value<String?>? voice,
    Value<double>? speed,
    Value<double?>? pitch,
    Value<String?>? outputFormat,
    Value<String?>? style,
  }) {
    return VoiceProfilesCompanion(
      id: id ?? this.id,
      providerType: providerType ?? this.providerType,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      voice: voice ?? this.voice,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      outputFormat: outputFormat ?? this.outputFormat,
      style: style ?? this.style,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (providerType.present) {
      map['provider_type'] = Variable<String>(providerType.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (voice.present) {
      map['voice'] = Variable<String>(voice.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    if (pitch.present) {
      map['pitch'] = Variable<double>(pitch.value);
    }
    if (outputFormat.present) {
      map['output_format'] = Variable<String>(outputFormat.value);
    }
    if (style.present) {
      map['style'] = Variable<String>(style.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VoiceProfilesCompanion(')
          ..write('id: $id, ')
          ..write('providerType: $providerType, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('model: $model, ')
          ..write('voice: $voice, ')
          ..write('speed: $speed, ')
          ..write('pitch: $pitch, ')
          ..write('outputFormat: $outputFormat, ')
          ..write('style: $style')
          ..write(')'))
        .toString();
  }
}

class $DownloadPoliciesTable extends DownloadPolicies
    with TableInfo<$DownloadPoliciesTable, DownloadPolicyRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadPoliciesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _chaptersAheadMeta = const VerificationMeta(
    'chaptersAhead',
  );
  @override
  late final GeneratedColumn<int> chaptersAhead = GeneratedColumn<int>(
    'chapters_ahead',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _wholeBookMeta = const VerificationMeta(
    'wholeBook',
  );
  @override
  late final GeneratedColumn<bool> wholeBook = GeneratedColumn<bool>(
    'whole_book',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("whole_book" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _wifiOnlyMeta = const VerificationMeta(
    'wifiOnly',
  );
  @override
  late final GeneratedColumn<bool> wifiOnly = GeneratedColumn<bool>(
    'wifi_only',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("wifi_only" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _maxCacheBytesMeta = const VerificationMeta(
    'maxCacheBytes',
  );
  @override
  late final GeneratedColumn<int> maxCacheBytes = GeneratedColumn<int>(
    'max_cache_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    chaptersAhead,
    wholeBook,
    wifiOnly,
    maxCacheBytes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_policies';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadPolicyRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('chapters_ahead')) {
      context.handle(
        _chaptersAheadMeta,
        chaptersAhead.isAcceptableOrUnknown(
          data['chapters_ahead']!,
          _chaptersAheadMeta,
        ),
      );
    }
    if (data.containsKey('whole_book')) {
      context.handle(
        _wholeBookMeta,
        wholeBook.isAcceptableOrUnknown(data['whole_book']!, _wholeBookMeta),
      );
    }
    if (data.containsKey('wifi_only')) {
      context.handle(
        _wifiOnlyMeta,
        wifiOnly.isAcceptableOrUnknown(data['wifi_only']!, _wifiOnlyMeta),
      );
    }
    if (data.containsKey('max_cache_bytes')) {
      context.handle(
        _maxCacheBytesMeta,
        maxCacheBytes.isAcceptableOrUnknown(
          data['max_cache_bytes']!,
          _maxCacheBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maxCacheBytesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  DownloadPolicyRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadPolicyRecord(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_id'],
      )!,
      chaptersAhead: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapters_ahead'],
      )!,
      wholeBook: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}whole_book'],
      )!,
      wifiOnly: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}wifi_only'],
      )!,
      maxCacheBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_cache_bytes'],
      )!,
    );
  }

  @override
  $DownloadPoliciesTable createAlias(String alias) {
    return $DownloadPoliciesTable(attachedDatabase, alias);
  }
}

class DownloadPolicyRecord extends DataClass
    implements Insertable<DownloadPolicyRecord> {
  final int bookId;
  final int chaptersAhead;
  final bool wholeBook;
  final bool wifiOnly;
  final int maxCacheBytes;
  const DownloadPolicyRecord({
    required this.bookId,
    required this.chaptersAhead,
    required this.wholeBook,
    required this.wifiOnly,
    required this.maxCacheBytes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<int>(bookId);
    map['chapters_ahead'] = Variable<int>(chaptersAhead);
    map['whole_book'] = Variable<bool>(wholeBook);
    map['wifi_only'] = Variable<bool>(wifiOnly);
    map['max_cache_bytes'] = Variable<int>(maxCacheBytes);
    return map;
  }

  DownloadPoliciesCompanion toCompanion(bool nullToAbsent) {
    return DownloadPoliciesCompanion(
      bookId: Value(bookId),
      chaptersAhead: Value(chaptersAhead),
      wholeBook: Value(wholeBook),
      wifiOnly: Value(wifiOnly),
      maxCacheBytes: Value(maxCacheBytes),
    );
  }

  factory DownloadPolicyRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadPolicyRecord(
      bookId: serializer.fromJson<int>(json['bookId']),
      chaptersAhead: serializer.fromJson<int>(json['chaptersAhead']),
      wholeBook: serializer.fromJson<bool>(json['wholeBook']),
      wifiOnly: serializer.fromJson<bool>(json['wifiOnly']),
      maxCacheBytes: serializer.fromJson<int>(json['maxCacheBytes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<int>(bookId),
      'chaptersAhead': serializer.toJson<int>(chaptersAhead),
      'wholeBook': serializer.toJson<bool>(wholeBook),
      'wifiOnly': serializer.toJson<bool>(wifiOnly),
      'maxCacheBytes': serializer.toJson<int>(maxCacheBytes),
    };
  }

  DownloadPolicyRecord copyWith({
    int? bookId,
    int? chaptersAhead,
    bool? wholeBook,
    bool? wifiOnly,
    int? maxCacheBytes,
  }) => DownloadPolicyRecord(
    bookId: bookId ?? this.bookId,
    chaptersAhead: chaptersAhead ?? this.chaptersAhead,
    wholeBook: wholeBook ?? this.wholeBook,
    wifiOnly: wifiOnly ?? this.wifiOnly,
    maxCacheBytes: maxCacheBytes ?? this.maxCacheBytes,
  );
  DownloadPolicyRecord copyWithCompanion(DownloadPoliciesCompanion data) {
    return DownloadPolicyRecord(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chaptersAhead: data.chaptersAhead.present
          ? data.chaptersAhead.value
          : this.chaptersAhead,
      wholeBook: data.wholeBook.present ? data.wholeBook.value : this.wholeBook,
      wifiOnly: data.wifiOnly.present ? data.wifiOnly.value : this.wifiOnly,
      maxCacheBytes: data.maxCacheBytes.present
          ? data.maxCacheBytes.value
          : this.maxCacheBytes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadPolicyRecord(')
          ..write('bookId: $bookId, ')
          ..write('chaptersAhead: $chaptersAhead, ')
          ..write('wholeBook: $wholeBook, ')
          ..write('wifiOnly: $wifiOnly, ')
          ..write('maxCacheBytes: $maxCacheBytes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(bookId, chaptersAhead, wholeBook, wifiOnly, maxCacheBytes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadPolicyRecord &&
          other.bookId == this.bookId &&
          other.chaptersAhead == this.chaptersAhead &&
          other.wholeBook == this.wholeBook &&
          other.wifiOnly == this.wifiOnly &&
          other.maxCacheBytes == this.maxCacheBytes);
}

class DownloadPoliciesCompanion extends UpdateCompanion<DownloadPolicyRecord> {
  final Value<int> bookId;
  final Value<int> chaptersAhead;
  final Value<bool> wholeBook;
  final Value<bool> wifiOnly;
  final Value<int> maxCacheBytes;
  const DownloadPoliciesCompanion({
    this.bookId = const Value.absent(),
    this.chaptersAhead = const Value.absent(),
    this.wholeBook = const Value.absent(),
    this.wifiOnly = const Value.absent(),
    this.maxCacheBytes = const Value.absent(),
  });
  DownloadPoliciesCompanion.insert({
    this.bookId = const Value.absent(),
    this.chaptersAhead = const Value.absent(),
    this.wholeBook = const Value.absent(),
    this.wifiOnly = const Value.absent(),
    required int maxCacheBytes,
  }) : maxCacheBytes = Value(maxCacheBytes);
  static Insertable<DownloadPolicyRecord> custom({
    Expression<int>? bookId,
    Expression<int>? chaptersAhead,
    Expression<bool>? wholeBook,
    Expression<bool>? wifiOnly,
    Expression<int>? maxCacheBytes,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (chaptersAhead != null) 'chapters_ahead': chaptersAhead,
      if (wholeBook != null) 'whole_book': wholeBook,
      if (wifiOnly != null) 'wifi_only': wifiOnly,
      if (maxCacheBytes != null) 'max_cache_bytes': maxCacheBytes,
    });
  }

  DownloadPoliciesCompanion copyWith({
    Value<int>? bookId,
    Value<int>? chaptersAhead,
    Value<bool>? wholeBook,
    Value<bool>? wifiOnly,
    Value<int>? maxCacheBytes,
  }) {
    return DownloadPoliciesCompanion(
      bookId: bookId ?? this.bookId,
      chaptersAhead: chaptersAhead ?? this.chaptersAhead,
      wholeBook: wholeBook ?? this.wholeBook,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      maxCacheBytes: maxCacheBytes ?? this.maxCacheBytes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (chaptersAhead.present) {
      map['chapters_ahead'] = Variable<int>(chaptersAhead.value);
    }
    if (wholeBook.present) {
      map['whole_book'] = Variable<bool>(wholeBook.value);
    }
    if (wifiOnly.present) {
      map['wifi_only'] = Variable<bool>(wifiOnly.value);
    }
    if (maxCacheBytes.present) {
      map['max_cache_bytes'] = Variable<int>(maxCacheBytes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadPoliciesCompanion(')
          ..write('bookId: $bookId, ')
          ..write('chaptersAhead: $chaptersAhead, ')
          ..write('wholeBook: $wholeBook, ')
          ..write('wifiOnly: $wifiOnly, ')
          ..write('maxCacheBytes: $maxCacheBytes')
          ..write(')'))
        .toString();
  }
}

class $AudioCacheEntriesTable extends AudioCacheEntries
    with TableInfo<$AudioCacheEntriesTable, AudioCacheRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<int> chapterId = GeneratedColumn<int>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chapters (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _paragraphIdMeta = const VerificationMeta(
    'paragraphId',
  );
  @override
  late final GeneratedColumn<int> paragraphId = GeneratedColumn<int>(
    'paragraph_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES paragraphs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAccessedAtMeta = const VerificationMeta(
    'lastAccessedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAccessedAt =
      GeneratedColumn<DateTime>(
        'last_accessed_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    bookId,
    chapterId,
    paragraphId,
    filePath,
    byteSize,
    status,
    lastAccessedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_cache_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<AudioCacheRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('paragraph_id')) {
      context.handle(
        _paragraphIdMeta,
        paragraphId.isAcceptableOrUnknown(
          data['paragraph_id']!,
          _paragraphIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paragraphIdMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_byteSizeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('last_accessed_at')) {
      context.handle(
        _lastAccessedAtMeta,
        lastAccessedAt.isAcceptableOrUnknown(
          data['last_accessed_at']!,
          _lastAccessedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastAccessedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  AudioCacheRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioCacheRecord(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_id'],
      )!,
      paragraphId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paragraph_id'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      lastAccessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_accessed_at'],
      )!,
    );
  }

  @override
  $AudioCacheEntriesTable createAlias(String alias) {
    return $AudioCacheEntriesTable(attachedDatabase, alias);
  }
}

class AudioCacheRecord extends DataClass
    implements Insertable<AudioCacheRecord> {
  final String cacheKey;
  final int bookId;
  final int chapterId;
  final int paragraphId;
  final String filePath;
  final int byteSize;
  final String status;
  final DateTime lastAccessedAt;
  const AudioCacheRecord({
    required this.cacheKey,
    required this.bookId,
    required this.chapterId,
    required this.paragraphId,
    required this.filePath,
    required this.byteSize,
    required this.status,
    required this.lastAccessedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['book_id'] = Variable<int>(bookId);
    map['chapter_id'] = Variable<int>(chapterId);
    map['paragraph_id'] = Variable<int>(paragraphId);
    map['file_path'] = Variable<String>(filePath);
    map['byte_size'] = Variable<int>(byteSize);
    map['status'] = Variable<String>(status);
    map['last_accessed_at'] = Variable<DateTime>(lastAccessedAt);
    return map;
  }

  AudioCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return AudioCacheEntriesCompanion(
      cacheKey: Value(cacheKey),
      bookId: Value(bookId),
      chapterId: Value(chapterId),
      paragraphId: Value(paragraphId),
      filePath: Value(filePath),
      byteSize: Value(byteSize),
      status: Value(status),
      lastAccessedAt: Value(lastAccessedAt),
    );
  }

  factory AudioCacheRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioCacheRecord(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      bookId: serializer.fromJson<int>(json['bookId']),
      chapterId: serializer.fromJson<int>(json['chapterId']),
      paragraphId: serializer.fromJson<int>(json['paragraphId']),
      filePath: serializer.fromJson<String>(json['filePath']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      status: serializer.fromJson<String>(json['status']),
      lastAccessedAt: serializer.fromJson<DateTime>(json['lastAccessedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'bookId': serializer.toJson<int>(bookId),
      'chapterId': serializer.toJson<int>(chapterId),
      'paragraphId': serializer.toJson<int>(paragraphId),
      'filePath': serializer.toJson<String>(filePath),
      'byteSize': serializer.toJson<int>(byteSize),
      'status': serializer.toJson<String>(status),
      'lastAccessedAt': serializer.toJson<DateTime>(lastAccessedAt),
    };
  }

  AudioCacheRecord copyWith({
    String? cacheKey,
    int? bookId,
    int? chapterId,
    int? paragraphId,
    String? filePath,
    int? byteSize,
    String? status,
    DateTime? lastAccessedAt,
  }) => AudioCacheRecord(
    cacheKey: cacheKey ?? this.cacheKey,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    paragraphId: paragraphId ?? this.paragraphId,
    filePath: filePath ?? this.filePath,
    byteSize: byteSize ?? this.byteSize,
    status: status ?? this.status,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
  );
  AudioCacheRecord copyWithCompanion(AudioCacheEntriesCompanion data) {
    return AudioCacheRecord(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      paragraphId: data.paragraphId.present
          ? data.paragraphId.value
          : this.paragraphId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      status: data.status.present ? data.status.value : this.status,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioCacheRecord(')
          ..write('cacheKey: $cacheKey, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('paragraphId: $paragraphId, ')
          ..write('filePath: $filePath, ')
          ..write('byteSize: $byteSize, ')
          ..write('status: $status, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    cacheKey,
    bookId,
    chapterId,
    paragraphId,
    filePath,
    byteSize,
    status,
    lastAccessedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioCacheRecord &&
          other.cacheKey == this.cacheKey &&
          other.bookId == this.bookId &&
          other.chapterId == this.chapterId &&
          other.paragraphId == this.paragraphId &&
          other.filePath == this.filePath &&
          other.byteSize == this.byteSize &&
          other.status == this.status &&
          other.lastAccessedAt == this.lastAccessedAt);
}

class AudioCacheEntriesCompanion extends UpdateCompanion<AudioCacheRecord> {
  final Value<String> cacheKey;
  final Value<int> bookId;
  final Value<int> chapterId;
  final Value<int> paragraphId;
  final Value<String> filePath;
  final Value<int> byteSize;
  final Value<String> status;
  final Value<DateTime> lastAccessedAt;
  final Value<int> rowid;
  const AudioCacheEntriesCompanion({
    this.cacheKey = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.paragraphId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.status = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioCacheEntriesCompanion.insert({
    required String cacheKey,
    required int bookId,
    required int chapterId,
    required int paragraphId,
    required String filePath,
    required int byteSize,
    required String status,
    required DateTime lastAccessedAt,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       bookId = Value(bookId),
       chapterId = Value(chapterId),
       paragraphId = Value(paragraphId),
       filePath = Value(filePath),
       byteSize = Value(byteSize),
       status = Value(status),
       lastAccessedAt = Value(lastAccessedAt);
  static Insertable<AudioCacheRecord> custom({
    Expression<String>? cacheKey,
    Expression<int>? bookId,
    Expression<int>? chapterId,
    Expression<int>? paragraphId,
    Expression<String>? filePath,
    Expression<int>? byteSize,
    Expression<String>? status,
    Expression<DateTime>? lastAccessedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (bookId != null) 'book_id': bookId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (paragraphId != null) 'paragraph_id': paragraphId,
      if (filePath != null) 'file_path': filePath,
      if (byteSize != null) 'byte_size': byteSize,
      if (status != null) 'status': status,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioCacheEntriesCompanion copyWith({
    Value<String>? cacheKey,
    Value<int>? bookId,
    Value<int>? chapterId,
    Value<int>? paragraphId,
    Value<String>? filePath,
    Value<int>? byteSize,
    Value<String>? status,
    Value<DateTime>? lastAccessedAt,
    Value<int>? rowid,
  }) {
    return AudioCacheEntriesCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      paragraphId: paragraphId ?? this.paragraphId,
      filePath: filePath ?? this.filePath,
      byteSize: byteSize ?? this.byteSize,
      status: status ?? this.status,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<int>(chapterId.value);
    }
    if (paragraphId.present) {
      map['paragraph_id'] = Variable<int>(paragraphId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastAccessedAt.present) {
      map['last_accessed_at'] = Variable<DateTime>(lastAccessedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioCacheEntriesCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('paragraphId: $paragraphId, ')
          ..write('filePath: $filePath, ')
          ..write('byteSize: $byteSize, ')
          ..write('status: $status, ')
          ..write('lastAccessedAt: $lastAccessedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadJobsTable extends DownloadJobs
    with TableInfo<$DownloadJobsTable, DownloadJobRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _paragraphIdMeta = const VerificationMeta(
    'paragraphId',
  );
  @override
  late final GeneratedColumn<int> paragraphId = GeneratedColumn<int>(
    'paragraph_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES paragraphs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    paragraphId,
    cacheKey,
    priority,
    retryCount,
    status,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadJobRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('paragraph_id')) {
      context.handle(
        _paragraphIdMeta,
        paragraphId.isAcceptableOrUnknown(
          data['paragraph_id']!,
          _paragraphIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paragraphIdMeta);
    }
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {cacheKey},
  ];
  @override
  DownloadJobRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadJobRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      paragraphId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paragraph_id'],
      )!,
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DownloadJobsTable createAlias(String alias) {
    return $DownloadJobsTable(attachedDatabase, alias);
  }
}

class DownloadJobRecord extends DataClass
    implements Insertable<DownloadJobRecord> {
  final int id;
  final int paragraphId;
  final String cacheKey;
  final int priority;
  final int retryCount;
  final String status;
  final DateTime createdAt;
  const DownloadJobRecord({
    required this.id,
    required this.paragraphId,
    required this.cacheKey,
    required this.priority,
    required this.retryCount,
    required this.status,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['paragraph_id'] = Variable<int>(paragraphId);
    map['cache_key'] = Variable<String>(cacheKey);
    map['priority'] = Variable<int>(priority);
    map['retry_count'] = Variable<int>(retryCount);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DownloadJobsCompanion toCompanion(bool nullToAbsent) {
    return DownloadJobsCompanion(
      id: Value(id),
      paragraphId: Value(paragraphId),
      cacheKey: Value(cacheKey),
      priority: Value(priority),
      retryCount: Value(retryCount),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory DownloadJobRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadJobRecord(
      id: serializer.fromJson<int>(json['id']),
      paragraphId: serializer.fromJson<int>(json['paragraphId']),
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      priority: serializer.fromJson<int>(json['priority']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'paragraphId': serializer.toJson<int>(paragraphId),
      'cacheKey': serializer.toJson<String>(cacheKey),
      'priority': serializer.toJson<int>(priority),
      'retryCount': serializer.toJson<int>(retryCount),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DownloadJobRecord copyWith({
    int? id,
    int? paragraphId,
    String? cacheKey,
    int? priority,
    int? retryCount,
    String? status,
    DateTime? createdAt,
  }) => DownloadJobRecord(
    id: id ?? this.id,
    paragraphId: paragraphId ?? this.paragraphId,
    cacheKey: cacheKey ?? this.cacheKey,
    priority: priority ?? this.priority,
    retryCount: retryCount ?? this.retryCount,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
  DownloadJobRecord copyWithCompanion(DownloadJobsCompanion data) {
    return DownloadJobRecord(
      id: data.id.present ? data.id.value : this.id,
      paragraphId: data.paragraphId.present
          ? data.paragraphId.value
          : this.paragraphId,
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      priority: data.priority.present ? data.priority.value : this.priority,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadJobRecord(')
          ..write('id: $id, ')
          ..write('paragraphId: $paragraphId, ')
          ..write('cacheKey: $cacheKey, ')
          ..write('priority: $priority, ')
          ..write('retryCount: $retryCount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    paragraphId,
    cacheKey,
    priority,
    retryCount,
    status,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadJobRecord &&
          other.id == this.id &&
          other.paragraphId == this.paragraphId &&
          other.cacheKey == this.cacheKey &&
          other.priority == this.priority &&
          other.retryCount == this.retryCount &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class DownloadJobsCompanion extends UpdateCompanion<DownloadJobRecord> {
  final Value<int> id;
  final Value<int> paragraphId;
  final Value<String> cacheKey;
  final Value<int> priority;
  final Value<int> retryCount;
  final Value<String> status;
  final Value<DateTime> createdAt;
  const DownloadJobsCompanion({
    this.id = const Value.absent(),
    this.paragraphId = const Value.absent(),
    this.cacheKey = const Value.absent(),
    this.priority = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DownloadJobsCompanion.insert({
    this.id = const Value.absent(),
    required int paragraphId,
    required String cacheKey,
    required int priority,
    this.retryCount = const Value.absent(),
    required String status,
    this.createdAt = const Value.absent(),
  }) : paragraphId = Value(paragraphId),
       cacheKey = Value(cacheKey),
       priority = Value(priority),
       status = Value(status);
  static Insertable<DownloadJobRecord> custom({
    Expression<int>? id,
    Expression<int>? paragraphId,
    Expression<String>? cacheKey,
    Expression<int>? priority,
    Expression<int>? retryCount,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (paragraphId != null) 'paragraph_id': paragraphId,
      if (cacheKey != null) 'cache_key': cacheKey,
      if (priority != null) 'priority': priority,
      if (retryCount != null) 'retry_count': retryCount,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DownloadJobsCompanion copyWith({
    Value<int>? id,
    Value<int>? paragraphId,
    Value<String>? cacheKey,
    Value<int>? priority,
    Value<int>? retryCount,
    Value<String>? status,
    Value<DateTime>? createdAt,
  }) {
    return DownloadJobsCompanion(
      id: id ?? this.id,
      paragraphId: paragraphId ?? this.paragraphId,
      cacheKey: cacheKey ?? this.cacheKey,
      priority: priority ?? this.priority,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (paragraphId.present) {
      map['paragraph_id'] = Variable<int>(paragraphId.value);
    }
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadJobsCompanion(')
          ..write('id: $id, ')
          ..write('paragraphId: $paragraphId, ')
          ..write('cacheKey: $cacheKey, ')
          ..write('priority: $priority, ')
          ..write('retryCount: $retryCount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TencentTtsMonthlyUsagesTable extends TencentTtsMonthlyUsages
    with
        TableInfo<$TencentTtsMonthlyUsagesTable, TencentTtsMonthlyUsageRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TencentTtsMonthlyUsagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _periodMeta = const VerificationMeta('period');
  @override
  late final GeneratedColumn<String> period = GeneratedColumn<String>(
    'period',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usedCharactersMeta = const VerificationMeta(
    'usedCharacters',
  );
  @override
  late final GeneratedColumn<int> usedCharacters = GeneratedColumn<int>(
    'used_characters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _quotaCharactersMeta = const VerificationMeta(
    'quotaCharacters',
  );
  @override
  late final GeneratedColumn<int> quotaCharacters = GeneratedColumn<int>(
    'quota_characters',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    period,
    usedCharacters,
    quotaCharacters,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tencent_tts_monthly_usages';
  @override
  VerificationContext validateIntegrity(
    Insertable<TencentTtsMonthlyUsageRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('period')) {
      context.handle(
        _periodMeta,
        period.isAcceptableOrUnknown(data['period']!, _periodMeta),
      );
    } else if (isInserting) {
      context.missing(_periodMeta);
    }
    if (data.containsKey('used_characters')) {
      context.handle(
        _usedCharactersMeta,
        usedCharacters.isAcceptableOrUnknown(
          data['used_characters']!,
          _usedCharactersMeta,
        ),
      );
    }
    if (data.containsKey('quota_characters')) {
      context.handle(
        _quotaCharactersMeta,
        quotaCharacters.isAcceptableOrUnknown(
          data['quota_characters']!,
          _quotaCharactersMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {period};
  @override
  TencentTtsMonthlyUsageRecord map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TencentTtsMonthlyUsageRecord(
      period: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period'],
      )!,
      usedCharacters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}used_characters'],
      )!,
      quotaCharacters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quota_characters'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TencentTtsMonthlyUsagesTable createAlias(String alias) {
    return $TencentTtsMonthlyUsagesTable(attachedDatabase, alias);
  }
}

class TencentTtsMonthlyUsageRecord extends DataClass
    implements Insertable<TencentTtsMonthlyUsageRecord> {
  final String period;
  final int usedCharacters;
  final int? quotaCharacters;
  final DateTime updatedAt;
  const TencentTtsMonthlyUsageRecord({
    required this.period,
    required this.usedCharacters,
    this.quotaCharacters,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['period'] = Variable<String>(period);
    map['used_characters'] = Variable<int>(usedCharacters);
    if (!nullToAbsent || quotaCharacters != null) {
      map['quota_characters'] = Variable<int>(quotaCharacters);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TencentTtsMonthlyUsagesCompanion toCompanion(bool nullToAbsent) {
    return TencentTtsMonthlyUsagesCompanion(
      period: Value(period),
      usedCharacters: Value(usedCharacters),
      quotaCharacters: quotaCharacters == null && nullToAbsent
          ? const Value.absent()
          : Value(quotaCharacters),
      updatedAt: Value(updatedAt),
    );
  }

  factory TencentTtsMonthlyUsageRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TencentTtsMonthlyUsageRecord(
      period: serializer.fromJson<String>(json['period']),
      usedCharacters: serializer.fromJson<int>(json['usedCharacters']),
      quotaCharacters: serializer.fromJson<int?>(json['quotaCharacters']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'period': serializer.toJson<String>(period),
      'usedCharacters': serializer.toJson<int>(usedCharacters),
      'quotaCharacters': serializer.toJson<int?>(quotaCharacters),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TencentTtsMonthlyUsageRecord copyWith({
    String? period,
    int? usedCharacters,
    Value<int?> quotaCharacters = const Value.absent(),
    DateTime? updatedAt,
  }) => TencentTtsMonthlyUsageRecord(
    period: period ?? this.period,
    usedCharacters: usedCharacters ?? this.usedCharacters,
    quotaCharacters: quotaCharacters.present
        ? quotaCharacters.value
        : this.quotaCharacters,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TencentTtsMonthlyUsageRecord copyWithCompanion(
    TencentTtsMonthlyUsagesCompanion data,
  ) {
    return TencentTtsMonthlyUsageRecord(
      period: data.period.present ? data.period.value : this.period,
      usedCharacters: data.usedCharacters.present
          ? data.usedCharacters.value
          : this.usedCharacters,
      quotaCharacters: data.quotaCharacters.present
          ? data.quotaCharacters.value
          : this.quotaCharacters,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TencentTtsMonthlyUsageRecord(')
          ..write('period: $period, ')
          ..write('usedCharacters: $usedCharacters, ')
          ..write('quotaCharacters: $quotaCharacters, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(period, usedCharacters, quotaCharacters, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TencentTtsMonthlyUsageRecord &&
          other.period == this.period &&
          other.usedCharacters == this.usedCharacters &&
          other.quotaCharacters == this.quotaCharacters &&
          other.updatedAt == this.updatedAt);
}

class TencentTtsMonthlyUsagesCompanion
    extends UpdateCompanion<TencentTtsMonthlyUsageRecord> {
  final Value<String> period;
  final Value<int> usedCharacters;
  final Value<int?> quotaCharacters;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TencentTtsMonthlyUsagesCompanion({
    this.period = const Value.absent(),
    this.usedCharacters = const Value.absent(),
    this.quotaCharacters = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TencentTtsMonthlyUsagesCompanion.insert({
    required String period,
    this.usedCharacters = const Value.absent(),
    this.quotaCharacters = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : period = Value(period),
       updatedAt = Value(updatedAt);
  static Insertable<TencentTtsMonthlyUsageRecord> custom({
    Expression<String>? period,
    Expression<int>? usedCharacters,
    Expression<int>? quotaCharacters,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (period != null) 'period': period,
      if (usedCharacters != null) 'used_characters': usedCharacters,
      if (quotaCharacters != null) 'quota_characters': quotaCharacters,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TencentTtsMonthlyUsagesCompanion copyWith({
    Value<String>? period,
    Value<int>? usedCharacters,
    Value<int?>? quotaCharacters,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TencentTtsMonthlyUsagesCompanion(
      period: period ?? this.period,
      usedCharacters: usedCharacters ?? this.usedCharacters,
      quotaCharacters: quotaCharacters ?? this.quotaCharacters,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (period.present) {
      map['period'] = Variable<String>(period.value);
    }
    if (usedCharacters.present) {
      map['used_characters'] = Variable<int>(usedCharacters.value);
    }
    if (quotaCharacters.present) {
      map['quota_characters'] = Variable<int>(quotaCharacters.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TencentTtsMonthlyUsagesCompanion(')
          ..write('period: $period, ')
          ..write('usedCharacters: $usedCharacters, ')
          ..write('quotaCharacters: $quotaCharacters, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $ChaptersTable chapters = $ChaptersTable(this);
  late final $ParagraphsTable paragraphs = $ParagraphsTable(this);
  late final $ReadingProgressesTable readingProgresses =
      $ReadingProgressesTable(this);
  late final $VoiceProfilesTable voiceProfiles = $VoiceProfilesTable(this);
  late final $DownloadPoliciesTable downloadPolicies = $DownloadPoliciesTable(
    this,
  );
  late final $AudioCacheEntriesTable audioCacheEntries =
      $AudioCacheEntriesTable(this);
  late final $DownloadJobsTable downloadJobs = $DownloadJobsTable(this);
  late final $TencentTtsMonthlyUsagesTable tencentTtsMonthlyUsages =
      $TencentTtsMonthlyUsagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    chapters,
    paragraphs,
    readingProgresses,
    voiceProfiles,
    downloadPolicies,
    audioCacheEntries,
    downloadJobs,
    tencentTtsMonthlyUsages,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'books',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('chapters', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chapters',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('paragraphs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'books',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reading_progresses', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chapters',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reading_progresses', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'books',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('download_policies', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'books',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('audio_cache_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chapters',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('audio_cache_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'paragraphs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('audio_cache_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'paragraphs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('download_jobs', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$BooksTableCreateCompanionBuilder =
    BooksCompanion Function({
      Value<int> id,
      required String title,
      Value<String> sourceType,
      Value<String?> sourceFileName,
      Value<DateTime> importedAt,
      Value<DateTime?> lastReadAt,
    });
typedef $$BooksTableUpdateCompanionBuilder =
    BooksCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> sourceType,
      Value<String?> sourceFileName,
      Value<DateTime> importedAt,
      Value<DateTime?> lastReadAt,
    });

final class $$BooksTableReferences
    extends BaseReferences<_$AppDatabase, $BooksTable, BookRecord> {
  $$BooksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ChaptersTable, List<ChapterRecord>>
  _chaptersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.chapters,
    aliasName: 'books__id__chapters__book_id',
  );

  $$ChaptersTableProcessedTableManager get chaptersRefs {
    final manager = $$ChaptersTableTableManager(
      $_db,
      $_db.chapters,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_chaptersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ReadingProgressesTable,
    List<ReadingProgressRecord>
  >
  _readingProgressesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.readingProgresses,
        aliasName: 'books__id__reading_progresses__book_id',
      );

  $$ReadingProgressesTableProcessedTableManager get readingProgressesRefs {
    final manager = $$ReadingProgressesTableTableManager(
      $_db,
      $_db.readingProgresses,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _readingProgressesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DownloadPoliciesTable, List<DownloadPolicyRecord>>
  _downloadPoliciesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.downloadPolicies,
    aliasName: 'books__id__download_policies__book_id',
  );

  $$DownloadPoliciesTableProcessedTableManager get downloadPoliciesRefs {
    final manager = $$DownloadPoliciesTableTableManager(
      $_db,
      $_db.downloadPolicies,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _downloadPoliciesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AudioCacheEntriesTable, List<AudioCacheRecord>>
  _audioCacheEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.audioCacheEntries,
        aliasName: 'books__id__audio_cache_entries__book_id',
      );

  $$AudioCacheEntriesTableProcessedTableManager get audioCacheEntriesRefs {
    final manager = $$AudioCacheEntriesTableTableManager(
      $_db,
      $_db.audioCacheEntries,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _audioCacheEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceFileName => $composableBuilder(
    column: $table.sourceFileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> chaptersRefs(
    Expression<bool> Function($$ChaptersTableFilterComposer f) f,
  ) {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableFilterComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> readingProgressesRefs(
    Expression<bool> Function($$ReadingProgressesTableFilterComposer f) f,
  ) {
    final $$ReadingProgressesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingProgresses,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingProgressesTableFilterComposer(
            $db: $db,
            $table: $db.readingProgresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> downloadPoliciesRefs(
    Expression<bool> Function($$DownloadPoliciesTableFilterComposer f) f,
  ) {
    final $$DownloadPoliciesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloadPolicies,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadPoliciesTableFilterComposer(
            $db: $db,
            $table: $db.downloadPolicies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> audioCacheEntriesRefs(
    Expression<bool> Function($$AudioCacheEntriesTableFilterComposer f) f,
  ) {
    final $$AudioCacheEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.audioCacheEntries,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioCacheEntriesTableFilterComposer(
            $db: $db,
            $table: $db.audioCacheEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceFileName => $composableBuilder(
    column: $table.sourceFileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceFileName => $composableBuilder(
    column: $table.sourceFileName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => column,
  );

  Expression<T> chaptersRefs<T extends Object>(
    Expression<T> Function($$ChaptersTableAnnotationComposer a) f,
  ) {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableAnnotationComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> readingProgressesRefs<T extends Object>(
    Expression<T> Function($$ReadingProgressesTableAnnotationComposer a) f,
  ) {
    final $$ReadingProgressesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.readingProgresses,
          getReferencedColumn: (t) => t.bookId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ReadingProgressesTableAnnotationComposer(
                $db: $db,
                $table: $db.readingProgresses,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> downloadPoliciesRefs<T extends Object>(
    Expression<T> Function($$DownloadPoliciesTableAnnotationComposer a) f,
  ) {
    final $$DownloadPoliciesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloadPolicies,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadPoliciesTableAnnotationComposer(
            $db: $db,
            $table: $db.downloadPolicies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> audioCacheEntriesRefs<T extends Object>(
    Expression<T> Function($$AudioCacheEntriesTableAnnotationComposer a) f,
  ) {
    final $$AudioCacheEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.audioCacheEntries,
          getReferencedColumn: (t) => t.bookId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AudioCacheEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.audioCacheEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTable,
          BookRecord,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (BookRecord, $$BooksTableReferences),
          BookRecord,
          PrefetchHooks Function({
            bool chaptersRefs,
            bool readingProgressesRefs,
            bool downloadPoliciesRefs,
            bool audioCacheEntriesRefs,
          })
        > {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String?> sourceFileName = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<DateTime?> lastReadAt = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                title: title,
                sourceType: sourceType,
                sourceFileName: sourceFileName,
                importedAt: importedAt,
                lastReadAt: lastReadAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<String> sourceType = const Value.absent(),
                Value<String?> sourceFileName = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<DateTime?> lastReadAt = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                title: title,
                sourceType: sourceType,
                sourceFileName: sourceFileName,
                importedAt: importedAt,
                lastReadAt: lastReadAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$BooksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                chaptersRefs = false,
                readingProgressesRefs = false,
                downloadPoliciesRefs = false,
                audioCacheEntriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (chaptersRefs) db.chapters,
                    if (readingProgressesRefs) db.readingProgresses,
                    if (downloadPoliciesRefs) db.downloadPolicies,
                    if (audioCacheEntriesRefs) db.audioCacheEntries,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (chaptersRefs)
                        await $_getPrefetchedData<
                          BookRecord,
                          $BooksTable,
                          ChapterRecord
                        >(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._chaptersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).chaptersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (readingProgressesRefs)
                        await $_getPrefetchedData<
                          BookRecord,
                          $BooksTable,
                          ReadingProgressRecord
                        >(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._readingProgressesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).readingProgressesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (downloadPoliciesRefs)
                        await $_getPrefetchedData<
                          BookRecord,
                          $BooksTable,
                          DownloadPolicyRecord
                        >(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._downloadPoliciesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).downloadPoliciesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (audioCacheEntriesRefs)
                        await $_getPrefetchedData<
                          BookRecord,
                          $BooksTable,
                          AudioCacheRecord
                        >(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._audioCacheEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).audioCacheEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTable,
      BookRecord,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (BookRecord, $$BooksTableReferences),
      BookRecord,
      PrefetchHooks Function({
        bool chaptersRefs,
        bool readingProgressesRefs,
        bool downloadPoliciesRefs,
        bool audioCacheEntriesRefs,
      })
    >;
typedef $$ChaptersTableCreateCompanionBuilder =
    ChaptersCompanion Function({
      Value<int> id,
      required int bookId,
      required int chapterIndex,
      required String title,
    });
typedef $$ChaptersTableUpdateCompanionBuilder =
    ChaptersCompanion Function({
      Value<int> id,
      Value<int> bookId,
      Value<int> chapterIndex,
      Value<String> title,
    });

final class $$ChaptersTableReferences
    extends BaseReferences<_$AppDatabase, $ChaptersTable, ChapterRecord> {
  $$ChaptersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('chapters__book_id__books__id');

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<int>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ParagraphsTable, List<ParagraphRecord>>
  _paragraphsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.paragraphs,
    aliasName: 'chapters__id__paragraphs__chapter_id',
  );

  $$ParagraphsTableProcessedTableManager get paragraphsRefs {
    final manager = $$ParagraphsTableTableManager(
      $_db,
      $_db.paragraphs,
    ).filter((f) => f.chapterId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_paragraphsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ReadingProgressesTable,
    List<ReadingProgressRecord>
  >
  _readingProgressesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.readingProgresses,
        aliasName: 'chapters__id__reading_progresses__chapter_id',
      );

  $$ReadingProgressesTableProcessedTableManager get readingProgressesRefs {
    final manager = $$ReadingProgressesTableTableManager(
      $_db,
      $_db.readingProgresses,
    ).filter((f) => f.chapterId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _readingProgressesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AudioCacheEntriesTable, List<AudioCacheRecord>>
  _audioCacheEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.audioCacheEntries,
        aliasName: 'chapters__id__audio_cache_entries__chapter_id',
      );

  $$AudioCacheEntriesTableProcessedTableManager get audioCacheEntriesRefs {
    final manager = $$AudioCacheEntriesTableTableManager(
      $_db,
      $_db.audioCacheEntries,
    ).filter((f) => f.chapterId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _audioCacheEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> paragraphsRefs(
    Expression<bool> Function($$ParagraphsTableFilterComposer f) f,
  ) {
    final $$ParagraphsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.paragraphs,
      getReferencedColumn: (t) => t.chapterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParagraphsTableFilterComposer(
            $db: $db,
            $table: $db.paragraphs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> readingProgressesRefs(
    Expression<bool> Function($$ReadingProgressesTableFilterComposer f) f,
  ) {
    final $$ReadingProgressesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingProgresses,
      getReferencedColumn: (t) => t.chapterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingProgressesTableFilterComposer(
            $db: $db,
            $table: $db.readingProgresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> audioCacheEntriesRefs(
    Expression<bool> Function($$AudioCacheEntriesTableFilterComposer f) f,
  ) {
    final $$AudioCacheEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.audioCacheEntries,
      getReferencedColumn: (t) => t.chapterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioCacheEntriesTableFilterComposer(
            $db: $db,
            $table: $db.audioCacheEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> paragraphsRefs<T extends Object>(
    Expression<T> Function($$ParagraphsTableAnnotationComposer a) f,
  ) {
    final $$ParagraphsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.paragraphs,
      getReferencedColumn: (t) => t.chapterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParagraphsTableAnnotationComposer(
            $db: $db,
            $table: $db.paragraphs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> readingProgressesRefs<T extends Object>(
    Expression<T> Function($$ReadingProgressesTableAnnotationComposer a) f,
  ) {
    final $$ReadingProgressesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.readingProgresses,
          getReferencedColumn: (t) => t.chapterId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ReadingProgressesTableAnnotationComposer(
                $db: $db,
                $table: $db.readingProgresses,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> audioCacheEntriesRefs<T extends Object>(
    Expression<T> Function($$AudioCacheEntriesTableAnnotationComposer a) f,
  ) {
    final $$AudioCacheEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.audioCacheEntries,
          getReferencedColumn: (t) => t.chapterId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AudioCacheEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.audioCacheEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ChaptersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChaptersTable,
          ChapterRecord,
          $$ChaptersTableFilterComposer,
          $$ChaptersTableOrderingComposer,
          $$ChaptersTableAnnotationComposer,
          $$ChaptersTableCreateCompanionBuilder,
          $$ChaptersTableUpdateCompanionBuilder,
          (ChapterRecord, $$ChaptersTableReferences),
          ChapterRecord,
          PrefetchHooks Function({
            bool bookId,
            bool paragraphsRefs,
            bool readingProgressesRefs,
            bool audioCacheEntriesRefs,
          })
        > {
  $$ChaptersTableTableManager(_$AppDatabase db, $ChaptersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> bookId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<String> title = const Value.absent(),
              }) => ChaptersCompanion(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                title: title,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int bookId,
                required int chapterIndex,
                required String title,
              }) => ChaptersCompanion.insert(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                title: title,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ChaptersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                bookId = false,
                paragraphsRefs = false,
                readingProgressesRefs = false,
                audioCacheEntriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (paragraphsRefs) db.paragraphs,
                    if (readingProgressesRefs) db.readingProgresses,
                    if (audioCacheEntriesRefs) db.audioCacheEntries,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (bookId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.bookId,
                                    referencedTable: $$ChaptersTableReferences
                                        ._bookIdTable(db),
                                    referencedColumn: $$ChaptersTableReferences
                                        ._bookIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (paragraphsRefs)
                        await $_getPrefetchedData<
                          ChapterRecord,
                          $ChaptersTable,
                          ParagraphRecord
                        >(
                          currentTable: table,
                          referencedTable: $$ChaptersTableReferences
                              ._paragraphsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChaptersTableReferences(
                                db,
                                table,
                                p0,
                              ).paragraphsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.chapterId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (readingProgressesRefs)
                        await $_getPrefetchedData<
                          ChapterRecord,
                          $ChaptersTable,
                          ReadingProgressRecord
                        >(
                          currentTable: table,
                          referencedTable: $$ChaptersTableReferences
                              ._readingProgressesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChaptersTableReferences(
                                db,
                                table,
                                p0,
                              ).readingProgressesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.chapterId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (audioCacheEntriesRefs)
                        await $_getPrefetchedData<
                          ChapterRecord,
                          $ChaptersTable,
                          AudioCacheRecord
                        >(
                          currentTable: table,
                          referencedTable: $$ChaptersTableReferences
                              ._audioCacheEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChaptersTableReferences(
                                db,
                                table,
                                p0,
                              ).audioCacheEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.chapterId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ChaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChaptersTable,
      ChapterRecord,
      $$ChaptersTableFilterComposer,
      $$ChaptersTableOrderingComposer,
      $$ChaptersTableAnnotationComposer,
      $$ChaptersTableCreateCompanionBuilder,
      $$ChaptersTableUpdateCompanionBuilder,
      (ChapterRecord, $$ChaptersTableReferences),
      ChapterRecord,
      PrefetchHooks Function({
        bool bookId,
        bool paragraphsRefs,
        bool readingProgressesRefs,
        bool audioCacheEntriesRefs,
      })
    >;
typedef $$ParagraphsTableCreateCompanionBuilder =
    ParagraphsCompanion Function({
      Value<int> id,
      required int chapterId,
      required int paragraphIndex,
      required String content,
    });
typedef $$ParagraphsTableUpdateCompanionBuilder =
    ParagraphsCompanion Function({
      Value<int> id,
      Value<int> chapterId,
      Value<int> paragraphIndex,
      Value<String> content,
    });

final class $$ParagraphsTableReferences
    extends BaseReferences<_$AppDatabase, $ParagraphsTable, ParagraphRecord> {
  $$ParagraphsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ChaptersTable _chapterIdTable(_$AppDatabase db) =>
      db.chapters.createAlias('paragraphs__chapter_id__chapters__id');

  $$ChaptersTableProcessedTableManager get chapterId {
    final $_column = $_itemColumn<int>('chapter_id')!;

    final manager = $$ChaptersTableTableManager(
      $_db,
      $_db.chapters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_chapterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AudioCacheEntriesTable, List<AudioCacheRecord>>
  _audioCacheEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.audioCacheEntries,
        aliasName: 'paragraphs__id__audio_cache_entries__paragraph_id',
      );

  $$AudioCacheEntriesTableProcessedTableManager get audioCacheEntriesRefs {
    final manager = $$AudioCacheEntriesTableTableManager(
      $_db,
      $_db.audioCacheEntries,
    ).filter((f) => f.paragraphId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _audioCacheEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DownloadJobsTable, List<DownloadJobRecord>>
  _downloadJobsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.downloadJobs,
    aliasName: 'paragraphs__id__download_jobs__paragraph_id',
  );

  $$DownloadJobsTableProcessedTableManager get downloadJobsRefs {
    final manager = $$DownloadJobsTableTableManager(
      $_db,
      $_db.downloadJobs,
    ).filter((f) => f.paragraphId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_downloadJobsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ParagraphsTableFilterComposer
    extends Composer<_$AppDatabase, $ParagraphsTable> {
  $$ParagraphsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  $$ChaptersTableFilterComposer get chapterId {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableFilterComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> audioCacheEntriesRefs(
    Expression<bool> Function($$AudioCacheEntriesTableFilterComposer f) f,
  ) {
    final $$AudioCacheEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.audioCacheEntries,
      getReferencedColumn: (t) => t.paragraphId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioCacheEntriesTableFilterComposer(
            $db: $db,
            $table: $db.audioCacheEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> downloadJobsRefs(
    Expression<bool> Function($$DownloadJobsTableFilterComposer f) f,
  ) {
    final $$DownloadJobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloadJobs,
      getReferencedColumn: (t) => t.paragraphId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadJobsTableFilterComposer(
            $db: $db,
            $table: $db.downloadJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ParagraphsTableOrderingComposer
    extends Composer<_$AppDatabase, $ParagraphsTable> {
  $$ParagraphsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChaptersTableOrderingComposer get chapterId {
    final $$ChaptersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableOrderingComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ParagraphsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParagraphsTable> {
  $$ParagraphsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  $$ChaptersTableAnnotationComposer get chapterId {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableAnnotationComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> audioCacheEntriesRefs<T extends Object>(
    Expression<T> Function($$AudioCacheEntriesTableAnnotationComposer a) f,
  ) {
    final $$AudioCacheEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.audioCacheEntries,
          getReferencedColumn: (t) => t.paragraphId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AudioCacheEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.audioCacheEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> downloadJobsRefs<T extends Object>(
    Expression<T> Function($$DownloadJobsTableAnnotationComposer a) f,
  ) {
    final $$DownloadJobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloadJobs,
      getReferencedColumn: (t) => t.paragraphId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadJobsTableAnnotationComposer(
            $db: $db,
            $table: $db.downloadJobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ParagraphsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ParagraphsTable,
          ParagraphRecord,
          $$ParagraphsTableFilterComposer,
          $$ParagraphsTableOrderingComposer,
          $$ParagraphsTableAnnotationComposer,
          $$ParagraphsTableCreateCompanionBuilder,
          $$ParagraphsTableUpdateCompanionBuilder,
          (ParagraphRecord, $$ParagraphsTableReferences),
          ParagraphRecord,
          PrefetchHooks Function({
            bool chapterId,
            bool audioCacheEntriesRefs,
            bool downloadJobsRefs,
          })
        > {
  $$ParagraphsTableTableManager(_$AppDatabase db, $ParagraphsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParagraphsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParagraphsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParagraphsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> chapterId = const Value.absent(),
                Value<int> paragraphIndex = const Value.absent(),
                Value<String> content = const Value.absent(),
              }) => ParagraphsCompanion(
                id: id,
                chapterId: chapterId,
                paragraphIndex: paragraphIndex,
                content: content,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int chapterId,
                required int paragraphIndex,
                required String content,
              }) => ParagraphsCompanion.insert(
                id: id,
                chapterId: chapterId,
                paragraphIndex: paragraphIndex,
                content: content,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ParagraphsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                chapterId = false,
                audioCacheEntriesRefs = false,
                downloadJobsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (audioCacheEntriesRefs) db.audioCacheEntries,
                    if (downloadJobsRefs) db.downloadJobs,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (chapterId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.chapterId,
                                    referencedTable: $$ParagraphsTableReferences
                                        ._chapterIdTable(db),
                                    referencedColumn:
                                        $$ParagraphsTableReferences
                                            ._chapterIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (audioCacheEntriesRefs)
                        await $_getPrefetchedData<
                          ParagraphRecord,
                          $ParagraphsTable,
                          AudioCacheRecord
                        >(
                          currentTable: table,
                          referencedTable: $$ParagraphsTableReferences
                              ._audioCacheEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ParagraphsTableReferences(
                                db,
                                table,
                                p0,
                              ).audioCacheEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.paragraphId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (downloadJobsRefs)
                        await $_getPrefetchedData<
                          ParagraphRecord,
                          $ParagraphsTable,
                          DownloadJobRecord
                        >(
                          currentTable: table,
                          referencedTable: $$ParagraphsTableReferences
                              ._downloadJobsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ParagraphsTableReferences(
                                db,
                                table,
                                p0,
                              ).downloadJobsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.paragraphId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ParagraphsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ParagraphsTable,
      ParagraphRecord,
      $$ParagraphsTableFilterComposer,
      $$ParagraphsTableOrderingComposer,
      $$ParagraphsTableAnnotationComposer,
      $$ParagraphsTableCreateCompanionBuilder,
      $$ParagraphsTableUpdateCompanionBuilder,
      (ParagraphRecord, $$ParagraphsTableReferences),
      ParagraphRecord,
      PrefetchHooks Function({
        bool chapterId,
        bool audioCacheEntriesRefs,
        bool downloadJobsRefs,
      })
    >;
typedef $$ReadingProgressesTableCreateCompanionBuilder =
    ReadingProgressesCompanion Function({
      Value<int> bookId,
      required int chapterId,
      required int paragraphIndex,
      required DateTime updatedAt,
    });
typedef $$ReadingProgressesTableUpdateCompanionBuilder =
    ReadingProgressesCompanion Function({
      Value<int> bookId,
      Value<int> chapterId,
      Value<int> paragraphIndex,
      Value<DateTime> updatedAt,
    });

final class $$ReadingProgressesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ReadingProgressesTable,
          ReadingProgressRecord
        > {
  $$ReadingProgressesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('reading_progresses__book_id__books__id');

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<int>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ChaptersTable _chapterIdTable(_$AppDatabase db) =>
      db.chapters.createAlias('reading_progresses__chapter_id__chapters__id');

  $$ChaptersTableProcessedTableManager get chapterId {
    final $_column = $_itemColumn<int>('chapter_id')!;

    final manager = $$ChaptersTableTableManager(
      $_db,
      $_db.chapters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_chapterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReadingProgressesTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingProgressesTable> {
  $$ReadingProgressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChaptersTableFilterComposer get chapterId {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableFilterComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingProgressesTable> {
  $$ReadingProgressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChaptersTableOrderingComposer get chapterId {
    final $$ChaptersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableOrderingComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingProgressesTable> {
  $$ReadingProgressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get paragraphIndex => $composableBuilder(
    column: $table.paragraphIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChaptersTableAnnotationComposer get chapterId {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableAnnotationComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingProgressesTable,
          ReadingProgressRecord,
          $$ReadingProgressesTableFilterComposer,
          $$ReadingProgressesTableOrderingComposer,
          $$ReadingProgressesTableAnnotationComposer,
          $$ReadingProgressesTableCreateCompanionBuilder,
          $$ReadingProgressesTableUpdateCompanionBuilder,
          (ReadingProgressRecord, $$ReadingProgressesTableReferences),
          ReadingProgressRecord,
          PrefetchHooks Function({bool bookId, bool chapterId})
        > {
  $$ReadingProgressesTableTableManager(
    _$AppDatabase db,
    $ReadingProgressesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingProgressesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> bookId = const Value.absent(),
                Value<int> chapterId = const Value.absent(),
                Value<int> paragraphIndex = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ReadingProgressesCompanion(
                bookId: bookId,
                chapterId: chapterId,
                paragraphIndex: paragraphIndex,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> bookId = const Value.absent(),
                required int chapterId,
                required int paragraphIndex,
                required DateTime updatedAt,
              }) => ReadingProgressesCompanion.insert(
                bookId: bookId,
                chapterId: chapterId,
                paragraphIndex: paragraphIndex,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReadingProgressesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false, chapterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bookId,
                                referencedTable:
                                    $$ReadingProgressesTableReferences
                                        ._bookIdTable(db),
                                referencedColumn:
                                    $$ReadingProgressesTableReferences
                                        ._bookIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (chapterId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.chapterId,
                                referencedTable:
                                    $$ReadingProgressesTableReferences
                                        ._chapterIdTable(db),
                                referencedColumn:
                                    $$ReadingProgressesTableReferences
                                        ._chapterIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReadingProgressesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingProgressesTable,
      ReadingProgressRecord,
      $$ReadingProgressesTableFilterComposer,
      $$ReadingProgressesTableOrderingComposer,
      $$ReadingProgressesTableAnnotationComposer,
      $$ReadingProgressesTableCreateCompanionBuilder,
      $$ReadingProgressesTableUpdateCompanionBuilder,
      (ReadingProgressRecord, $$ReadingProgressesTableReferences),
      ReadingProgressRecord,
      PrefetchHooks Function({bool bookId, bool chapterId})
    >;
typedef $$VoiceProfilesTableCreateCompanionBuilder =
    VoiceProfilesCompanion Function({
      Value<int> id,
      required String providerType,
      Value<String?> baseUrl,
      Value<String?> model,
      Value<String?> voice,
      Value<double> speed,
      Value<double?> pitch,
      Value<String?> outputFormat,
      Value<String?> style,
    });
typedef $$VoiceProfilesTableUpdateCompanionBuilder =
    VoiceProfilesCompanion Function({
      Value<int> id,
      Value<String> providerType,
      Value<String?> baseUrl,
      Value<String?> model,
      Value<String?> voice,
      Value<double> speed,
      Value<double?> pitch,
      Value<String?> outputFormat,
      Value<String?> style,
    });

class $$VoiceProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $VoiceProfilesTable> {
  $$VoiceProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voice => $composableBuilder(
    column: $table.voice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pitch => $composableBuilder(
    column: $table.pitch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputFormat => $composableBuilder(
    column: $table.outputFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VoiceProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $VoiceProfilesTable> {
  $$VoiceProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voice => $composableBuilder(
    column: $table.voice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pitch => $composableBuilder(
    column: $table.pitch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputFormat => $composableBuilder(
    column: $table.outputFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get style => $composableBuilder(
    column: $table.style,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VoiceProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VoiceProfilesTable> {
  $$VoiceProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get voice =>
      $composableBuilder(column: $table.voice, builder: (column) => column);

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<double> get pitch =>
      $composableBuilder(column: $table.pitch, builder: (column) => column);

  GeneratedColumn<String> get outputFormat => $composableBuilder(
    column: $table.outputFormat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get style =>
      $composableBuilder(column: $table.style, builder: (column) => column);
}

class $$VoiceProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VoiceProfilesTable,
          VoiceProfileRecord,
          $$VoiceProfilesTableFilterComposer,
          $$VoiceProfilesTableOrderingComposer,
          $$VoiceProfilesTableAnnotationComposer,
          $$VoiceProfilesTableCreateCompanionBuilder,
          $$VoiceProfilesTableUpdateCompanionBuilder,
          (
            VoiceProfileRecord,
            BaseReferences<
              _$AppDatabase,
              $VoiceProfilesTable,
              VoiceProfileRecord
            >,
          ),
          VoiceProfileRecord,
          PrefetchHooks Function()
        > {
  $$VoiceProfilesTableTableManager(_$AppDatabase db, $VoiceProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VoiceProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VoiceProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VoiceProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> providerType = const Value.absent(),
                Value<String?> baseUrl = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> voice = const Value.absent(),
                Value<double> speed = const Value.absent(),
                Value<double?> pitch = const Value.absent(),
                Value<String?> outputFormat = const Value.absent(),
                Value<String?> style = const Value.absent(),
              }) => VoiceProfilesCompanion(
                id: id,
                providerType: providerType,
                baseUrl: baseUrl,
                model: model,
                voice: voice,
                speed: speed,
                pitch: pitch,
                outputFormat: outputFormat,
                style: style,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String providerType,
                Value<String?> baseUrl = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> voice = const Value.absent(),
                Value<double> speed = const Value.absent(),
                Value<double?> pitch = const Value.absent(),
                Value<String?> outputFormat = const Value.absent(),
                Value<String?> style = const Value.absent(),
              }) => VoiceProfilesCompanion.insert(
                id: id,
                providerType: providerType,
                baseUrl: baseUrl,
                model: model,
                voice: voice,
                speed: speed,
                pitch: pitch,
                outputFormat: outputFormat,
                style: style,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VoiceProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VoiceProfilesTable,
      VoiceProfileRecord,
      $$VoiceProfilesTableFilterComposer,
      $$VoiceProfilesTableOrderingComposer,
      $$VoiceProfilesTableAnnotationComposer,
      $$VoiceProfilesTableCreateCompanionBuilder,
      $$VoiceProfilesTableUpdateCompanionBuilder,
      (
        VoiceProfileRecord,
        BaseReferences<_$AppDatabase, $VoiceProfilesTable, VoiceProfileRecord>,
      ),
      VoiceProfileRecord,
      PrefetchHooks Function()
    >;
typedef $$DownloadPoliciesTableCreateCompanionBuilder =
    DownloadPoliciesCompanion Function({
      Value<int> bookId,
      Value<int> chaptersAhead,
      Value<bool> wholeBook,
      Value<bool> wifiOnly,
      required int maxCacheBytes,
    });
typedef $$DownloadPoliciesTableUpdateCompanionBuilder =
    DownloadPoliciesCompanion Function({
      Value<int> bookId,
      Value<int> chaptersAhead,
      Value<bool> wholeBook,
      Value<bool> wifiOnly,
      Value<int> maxCacheBytes,
    });

final class $$DownloadPoliciesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DownloadPoliciesTable,
          DownloadPolicyRecord
        > {
  $$DownloadPoliciesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('download_policies__book_id__books__id');

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<int>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DownloadPoliciesTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadPoliciesTable> {
  $$DownloadPoliciesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get chaptersAhead => $composableBuilder(
    column: $table.chaptersAhead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get wholeBook => $composableBuilder(
    column: $table.wholeBook,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get wifiOnly => $composableBuilder(
    column: $table.wifiOnly,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxCacheBytes => $composableBuilder(
    column: $table.maxCacheBytes,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadPoliciesTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadPoliciesTable> {
  $$DownloadPoliciesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get chaptersAhead => $composableBuilder(
    column: $table.chaptersAhead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get wholeBook => $composableBuilder(
    column: $table.wholeBook,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get wifiOnly => $composableBuilder(
    column: $table.wifiOnly,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxCacheBytes => $composableBuilder(
    column: $table.maxCacheBytes,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadPoliciesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadPoliciesTable> {
  $$DownloadPoliciesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get chaptersAhead => $composableBuilder(
    column: $table.chaptersAhead,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get wholeBook =>
      $composableBuilder(column: $table.wholeBook, builder: (column) => column);

  GeneratedColumn<bool> get wifiOnly =>
      $composableBuilder(column: $table.wifiOnly, builder: (column) => column);

  GeneratedColumn<int> get maxCacheBytes => $composableBuilder(
    column: $table.maxCacheBytes,
    builder: (column) => column,
  );

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadPoliciesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadPoliciesTable,
          DownloadPolicyRecord,
          $$DownloadPoliciesTableFilterComposer,
          $$DownloadPoliciesTableOrderingComposer,
          $$DownloadPoliciesTableAnnotationComposer,
          $$DownloadPoliciesTableCreateCompanionBuilder,
          $$DownloadPoliciesTableUpdateCompanionBuilder,
          (DownloadPolicyRecord, $$DownloadPoliciesTableReferences),
          DownloadPolicyRecord,
          PrefetchHooks Function({bool bookId})
        > {
  $$DownloadPoliciesTableTableManager(
    _$AppDatabase db,
    $DownloadPoliciesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadPoliciesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadPoliciesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadPoliciesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> bookId = const Value.absent(),
                Value<int> chaptersAhead = const Value.absent(),
                Value<bool> wholeBook = const Value.absent(),
                Value<bool> wifiOnly = const Value.absent(),
                Value<int> maxCacheBytes = const Value.absent(),
              }) => DownloadPoliciesCompanion(
                bookId: bookId,
                chaptersAhead: chaptersAhead,
                wholeBook: wholeBook,
                wifiOnly: wifiOnly,
                maxCacheBytes: maxCacheBytes,
              ),
          createCompanionCallback:
              ({
                Value<int> bookId = const Value.absent(),
                Value<int> chaptersAhead = const Value.absent(),
                Value<bool> wholeBook = const Value.absent(),
                Value<bool> wifiOnly = const Value.absent(),
                required int maxCacheBytes,
              }) => DownloadPoliciesCompanion.insert(
                bookId: bookId,
                chaptersAhead: chaptersAhead,
                wholeBook: wholeBook,
                wifiOnly: wifiOnly,
                maxCacheBytes: maxCacheBytes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DownloadPoliciesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bookId,
                                referencedTable:
                                    $$DownloadPoliciesTableReferences
                                        ._bookIdTable(db),
                                referencedColumn:
                                    $$DownloadPoliciesTableReferences
                                        ._bookIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DownloadPoliciesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadPoliciesTable,
      DownloadPolicyRecord,
      $$DownloadPoliciesTableFilterComposer,
      $$DownloadPoliciesTableOrderingComposer,
      $$DownloadPoliciesTableAnnotationComposer,
      $$DownloadPoliciesTableCreateCompanionBuilder,
      $$DownloadPoliciesTableUpdateCompanionBuilder,
      (DownloadPolicyRecord, $$DownloadPoliciesTableReferences),
      DownloadPolicyRecord,
      PrefetchHooks Function({bool bookId})
    >;
typedef $$AudioCacheEntriesTableCreateCompanionBuilder =
    AudioCacheEntriesCompanion Function({
      required String cacheKey,
      required int bookId,
      required int chapterId,
      required int paragraphId,
      required String filePath,
      required int byteSize,
      required String status,
      required DateTime lastAccessedAt,
      Value<int> rowid,
    });
typedef $$AudioCacheEntriesTableUpdateCompanionBuilder =
    AudioCacheEntriesCompanion Function({
      Value<String> cacheKey,
      Value<int> bookId,
      Value<int> chapterId,
      Value<int> paragraphId,
      Value<String> filePath,
      Value<int> byteSize,
      Value<String> status,
      Value<DateTime> lastAccessedAt,
      Value<int> rowid,
    });

final class $$AudioCacheEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AudioCacheEntriesTable,
          AudioCacheRecord
        > {
  $$AudioCacheEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('audio_cache_entries__book_id__books__id');

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<int>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ChaptersTable _chapterIdTable(_$AppDatabase db) =>
      db.chapters.createAlias('audio_cache_entries__chapter_id__chapters__id');

  $$ChaptersTableProcessedTableManager get chapterId {
    final $_column = $_itemColumn<int>('chapter_id')!;

    final manager = $$ChaptersTableTableManager(
      $_db,
      $_db.chapters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_chapterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ParagraphsTable _paragraphIdTable(_$AppDatabase db) => db.paragraphs
      .createAlias('audio_cache_entries__paragraph_id__paragraphs__id');

  $$ParagraphsTableProcessedTableManager get paragraphId {
    final $_column = $_itemColumn<int>('paragraph_id')!;

    final manager = $$ParagraphsTableTableManager(
      $_db,
      $_db.paragraphs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_paragraphIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AudioCacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $AudioCacheEntriesTable> {
  $$AudioCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChaptersTableFilterComposer get chapterId {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableFilterComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ParagraphsTableFilterComposer get paragraphId {
    final $$ParagraphsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paragraphId,
      referencedTable: $db.paragraphs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParagraphsTableFilterComposer(
            $db: $db,
            $table: $db.paragraphs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioCacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $AudioCacheEntriesTable> {
  $$AudioCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChaptersTableOrderingComposer get chapterId {
    final $$ChaptersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableOrderingComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ParagraphsTableOrderingComposer get paragraphId {
    final $$ParagraphsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paragraphId,
      referencedTable: $db.paragraphs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParagraphsTableOrderingComposer(
            $db: $db,
            $table: $db.paragraphs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioCacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AudioCacheEntriesTable> {
  $$AudioCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => column,
  );

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChaptersTableAnnotationComposer get chapterId {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableAnnotationComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ParagraphsTableAnnotationComposer get paragraphId {
    final $$ParagraphsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paragraphId,
      referencedTable: $db.paragraphs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParagraphsTableAnnotationComposer(
            $db: $db,
            $table: $db.paragraphs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioCacheEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AudioCacheEntriesTable,
          AudioCacheRecord,
          $$AudioCacheEntriesTableFilterComposer,
          $$AudioCacheEntriesTableOrderingComposer,
          $$AudioCacheEntriesTableAnnotationComposer,
          $$AudioCacheEntriesTableCreateCompanionBuilder,
          $$AudioCacheEntriesTableUpdateCompanionBuilder,
          (AudioCacheRecord, $$AudioCacheEntriesTableReferences),
          AudioCacheRecord,
          PrefetchHooks Function({
            bool bookId,
            bool chapterId,
            bool paragraphId,
          })
        > {
  $$AudioCacheEntriesTableTableManager(
    _$AppDatabase db,
    $AudioCacheEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioCacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioCacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudioCacheEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<int> bookId = const Value.absent(),
                Value<int> chapterId = const Value.absent(),
                Value<int> paragraphId = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> lastAccessedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioCacheEntriesCompanion(
                cacheKey: cacheKey,
                bookId: bookId,
                chapterId: chapterId,
                paragraphId: paragraphId,
                filePath: filePath,
                byteSize: byteSize,
                status: status,
                lastAccessedAt: lastAccessedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required int bookId,
                required int chapterId,
                required int paragraphId,
                required String filePath,
                required int byteSize,
                required String status,
                required DateTime lastAccessedAt,
                Value<int> rowid = const Value.absent(),
              }) => AudioCacheEntriesCompanion.insert(
                cacheKey: cacheKey,
                bookId: bookId,
                chapterId: chapterId,
                paragraphId: paragraphId,
                filePath: filePath,
                byteSize: byteSize,
                status: status,
                lastAccessedAt: lastAccessedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AudioCacheEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({bookId = false, chapterId = false, paragraphId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (bookId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.bookId,
                                    referencedTable:
                                        $$AudioCacheEntriesTableReferences
                                            ._bookIdTable(db),
                                    referencedColumn:
                                        $$AudioCacheEntriesTableReferences
                                            ._bookIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (chapterId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.chapterId,
                                    referencedTable:
                                        $$AudioCacheEntriesTableReferences
                                            ._chapterIdTable(db),
                                    referencedColumn:
                                        $$AudioCacheEntriesTableReferences
                                            ._chapterIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (paragraphId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.paragraphId,
                                    referencedTable:
                                        $$AudioCacheEntriesTableReferences
                                            ._paragraphIdTable(db),
                                    referencedColumn:
                                        $$AudioCacheEntriesTableReferences
                                            ._paragraphIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$AudioCacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AudioCacheEntriesTable,
      AudioCacheRecord,
      $$AudioCacheEntriesTableFilterComposer,
      $$AudioCacheEntriesTableOrderingComposer,
      $$AudioCacheEntriesTableAnnotationComposer,
      $$AudioCacheEntriesTableCreateCompanionBuilder,
      $$AudioCacheEntriesTableUpdateCompanionBuilder,
      (AudioCacheRecord, $$AudioCacheEntriesTableReferences),
      AudioCacheRecord,
      PrefetchHooks Function({bool bookId, bool chapterId, bool paragraphId})
    >;
typedef $$DownloadJobsTableCreateCompanionBuilder =
    DownloadJobsCompanion Function({
      Value<int> id,
      required int paragraphId,
      required String cacheKey,
      required int priority,
      Value<int> retryCount,
      required String status,
      Value<DateTime> createdAt,
    });
typedef $$DownloadJobsTableUpdateCompanionBuilder =
    DownloadJobsCompanion Function({
      Value<int> id,
      Value<int> paragraphId,
      Value<String> cacheKey,
      Value<int> priority,
      Value<int> retryCount,
      Value<String> status,
      Value<DateTime> createdAt,
    });

final class $$DownloadJobsTableReferences
    extends
        BaseReferences<_$AppDatabase, $DownloadJobsTable, DownloadJobRecord> {
  $$DownloadJobsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ParagraphsTable _paragraphIdTable(_$AppDatabase db) =>
      db.paragraphs.createAlias('download_jobs__paragraph_id__paragraphs__id');

  $$ParagraphsTableProcessedTableManager get paragraphId {
    final $_column = $_itemColumn<int>('paragraph_id')!;

    final manager = $$ParagraphsTableTableManager(
      $_db,
      $_db.paragraphs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_paragraphIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DownloadJobsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadJobsTable> {
  $$DownloadJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ParagraphsTableFilterComposer get paragraphId {
    final $$ParagraphsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paragraphId,
      referencedTable: $db.paragraphs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParagraphsTableFilterComposer(
            $db: $db,
            $table: $db.paragraphs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadJobsTable> {
  $$DownloadJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ParagraphsTableOrderingComposer get paragraphId {
    final $$ParagraphsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paragraphId,
      referencedTable: $db.paragraphs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParagraphsTableOrderingComposer(
            $db: $db,
            $table: $db.paragraphs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadJobsTable> {
  $$DownloadJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ParagraphsTableAnnotationComposer get paragraphId {
    final $$ParagraphsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.paragraphId,
      referencedTable: $db.paragraphs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParagraphsTableAnnotationComposer(
            $db: $db,
            $table: $db.paragraphs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadJobsTable,
          DownloadJobRecord,
          $$DownloadJobsTableFilterComposer,
          $$DownloadJobsTableOrderingComposer,
          $$DownloadJobsTableAnnotationComposer,
          $$DownloadJobsTableCreateCompanionBuilder,
          $$DownloadJobsTableUpdateCompanionBuilder,
          (DownloadJobRecord, $$DownloadJobsTableReferences),
          DownloadJobRecord,
          PrefetchHooks Function({bool paragraphId})
        > {
  $$DownloadJobsTableTableManager(_$AppDatabase db, $DownloadJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> paragraphId = const Value.absent(),
                Value<String> cacheKey = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DownloadJobsCompanion(
                id: id,
                paragraphId: paragraphId,
                cacheKey: cacheKey,
                priority: priority,
                retryCount: retryCount,
                status: status,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int paragraphId,
                required String cacheKey,
                required int priority,
                Value<int> retryCount = const Value.absent(),
                required String status,
                Value<DateTime> createdAt = const Value.absent(),
              }) => DownloadJobsCompanion.insert(
                id: id,
                paragraphId: paragraphId,
                cacheKey: cacheKey,
                priority: priority,
                retryCount: retryCount,
                status: status,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DownloadJobsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({paragraphId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (paragraphId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.paragraphId,
                                referencedTable: $$DownloadJobsTableReferences
                                    ._paragraphIdTable(db),
                                referencedColumn: $$DownloadJobsTableReferences
                                    ._paragraphIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DownloadJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadJobsTable,
      DownloadJobRecord,
      $$DownloadJobsTableFilterComposer,
      $$DownloadJobsTableOrderingComposer,
      $$DownloadJobsTableAnnotationComposer,
      $$DownloadJobsTableCreateCompanionBuilder,
      $$DownloadJobsTableUpdateCompanionBuilder,
      (DownloadJobRecord, $$DownloadJobsTableReferences),
      DownloadJobRecord,
      PrefetchHooks Function({bool paragraphId})
    >;
typedef $$TencentTtsMonthlyUsagesTableCreateCompanionBuilder =
    TencentTtsMonthlyUsagesCompanion Function({
      required String period,
      Value<int> usedCharacters,
      Value<int?> quotaCharacters,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TencentTtsMonthlyUsagesTableUpdateCompanionBuilder =
    TencentTtsMonthlyUsagesCompanion Function({
      Value<String> period,
      Value<int> usedCharacters,
      Value<int?> quotaCharacters,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$TencentTtsMonthlyUsagesTableFilterComposer
    extends Composer<_$AppDatabase, $TencentTtsMonthlyUsagesTable> {
  $$TencentTtsMonthlyUsagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get usedCharacters => $composableBuilder(
    column: $table.usedCharacters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quotaCharacters => $composableBuilder(
    column: $table.quotaCharacters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TencentTtsMonthlyUsagesTableOrderingComposer
    extends Composer<_$AppDatabase, $TencentTtsMonthlyUsagesTable> {
  $$TencentTtsMonthlyUsagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get usedCharacters => $composableBuilder(
    column: $table.usedCharacters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quotaCharacters => $composableBuilder(
    column: $table.quotaCharacters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TencentTtsMonthlyUsagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TencentTtsMonthlyUsagesTable> {
  $$TencentTtsMonthlyUsagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  GeneratedColumn<int> get usedCharacters => $composableBuilder(
    column: $table.usedCharacters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quotaCharacters => $composableBuilder(
    column: $table.quotaCharacters,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TencentTtsMonthlyUsagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TencentTtsMonthlyUsagesTable,
          TencentTtsMonthlyUsageRecord,
          $$TencentTtsMonthlyUsagesTableFilterComposer,
          $$TencentTtsMonthlyUsagesTableOrderingComposer,
          $$TencentTtsMonthlyUsagesTableAnnotationComposer,
          $$TencentTtsMonthlyUsagesTableCreateCompanionBuilder,
          $$TencentTtsMonthlyUsagesTableUpdateCompanionBuilder,
          (
            TencentTtsMonthlyUsageRecord,
            BaseReferences<
              _$AppDatabase,
              $TencentTtsMonthlyUsagesTable,
              TencentTtsMonthlyUsageRecord
            >,
          ),
          TencentTtsMonthlyUsageRecord,
          PrefetchHooks Function()
        > {
  $$TencentTtsMonthlyUsagesTableTableManager(
    _$AppDatabase db,
    $TencentTtsMonthlyUsagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TencentTtsMonthlyUsagesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$TencentTtsMonthlyUsagesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TencentTtsMonthlyUsagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> period = const Value.absent(),
                Value<int> usedCharacters = const Value.absent(),
                Value<int?> quotaCharacters = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TencentTtsMonthlyUsagesCompanion(
                period: period,
                usedCharacters: usedCharacters,
                quotaCharacters: quotaCharacters,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String period,
                Value<int> usedCharacters = const Value.absent(),
                Value<int?> quotaCharacters = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TencentTtsMonthlyUsagesCompanion.insert(
                period: period,
                usedCharacters: usedCharacters,
                quotaCharacters: quotaCharacters,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TencentTtsMonthlyUsagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TencentTtsMonthlyUsagesTable,
      TencentTtsMonthlyUsageRecord,
      $$TencentTtsMonthlyUsagesTableFilterComposer,
      $$TencentTtsMonthlyUsagesTableOrderingComposer,
      $$TencentTtsMonthlyUsagesTableAnnotationComposer,
      $$TencentTtsMonthlyUsagesTableCreateCompanionBuilder,
      $$TencentTtsMonthlyUsagesTableUpdateCompanionBuilder,
      (
        TencentTtsMonthlyUsageRecord,
        BaseReferences<
          _$AppDatabase,
          $TencentTtsMonthlyUsagesTable,
          TencentTtsMonthlyUsageRecord
        >,
      ),
      TencentTtsMonthlyUsageRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db, _db.chapters);
  $$ParagraphsTableTableManager get paragraphs =>
      $$ParagraphsTableTableManager(_db, _db.paragraphs);
  $$ReadingProgressesTableTableManager get readingProgresses =>
      $$ReadingProgressesTableTableManager(_db, _db.readingProgresses);
  $$VoiceProfilesTableTableManager get voiceProfiles =>
      $$VoiceProfilesTableTableManager(_db, _db.voiceProfiles);
  $$DownloadPoliciesTableTableManager get downloadPolicies =>
      $$DownloadPoliciesTableTableManager(_db, _db.downloadPolicies);
  $$AudioCacheEntriesTableTableManager get audioCacheEntries =>
      $$AudioCacheEntriesTableTableManager(_db, _db.audioCacheEntries);
  $$DownloadJobsTableTableManager get downloadJobs =>
      $$DownloadJobsTableTableManager(_db, _db.downloadJobs);
  $$TencentTtsMonthlyUsagesTableTableManager get tencentTtsMonthlyUsages =>
      $$TencentTtsMonthlyUsagesTableTableManager(
        _db,
        _db.tencentTtsMonthlyUsages,
      );
}
