import 'package:drift/drift.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';

abstract interface class TencentTtsUsageCounter {
  Future<void> addSuccessfulCharacters(int count);
}

final class TencentTtsUsageSnapshot {
  const TencentTtsUsageSnapshot({
    required this.period,
    required this.usedCharacters,
    required this.quotaCharacters,
    required this.updatedAt,
  });

  final String period;
  final int usedCharacters;
  final int? quotaCharacters;
  final DateTime updatedAt;

  bool get isQuotaConfigured => quotaCharacters != null;

  int? get remainingCharacters {
    final quota = quotaCharacters;
    return quota == null ? null : (quota - usedCharacters).clamp(0, quota);
  }

  int get overageCharacters {
    final quota = quotaCharacters;
    return quota == null
        ? 0
        : (usedCharacters - quota).clamp(0, usedCharacters);
  }
}

final class TencentTtsUsageRepository implements TencentTtsUsageCounter {
  TencentTtsUsageRepository(this._database, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final DateTime Function() _clock;

  Future<TencentTtsUsageSnapshot> current() {
    return _database.transaction(() async {
      final record = await _ensureCurrentRecord(_clock());
      return _toSnapshot(record);
    });
  }

  Future<void> setMonthlyQuota(int? quotaCharacters) async {
    if (quotaCharacters != null && quotaCharacters < 0) {
      throw ArgumentError.value(
        quotaCharacters,
        'quotaCharacters',
        'Must not be negative.',
      );
    }
    await _database.transaction(() async {
      final now = _clock();
      final record = await _ensureCurrentRecord(now);
      await (_database.update(
        _database.tencentTtsMonthlyUsages,
      )..where((row) => row.period.equals(record.period))).write(
        TencentTtsMonthlyUsagesCompanion(
          quotaCharacters: Value(quotaCharacters),
          updatedAt: Value(now),
        ),
      );
    });
  }

  @override
  Future<void> addSuccessfulCharacters(int count) async {
    if (count <= 0) {
      throw ArgumentError.value(count, 'count', 'Must be positive.');
    }
    await _database.transaction(() async {
      final now = _clock();
      final record = await _ensureCurrentRecord(now);
      await (_database.update(
        _database.tencentTtsMonthlyUsages,
      )..where((row) => row.period.equals(record.period))).write(
        TencentTtsMonthlyUsagesCompanion(
          usedCharacters: Value(record.usedCharacters + count),
          updatedAt: Value(now),
        ),
      );
    });
  }

  Future<TencentTtsMonthlyUsageRecord> _ensureCurrentRecord(
    DateTime now,
  ) async {
    final period = _periodFor(now);
    final current = await (_database.select(
      _database.tencentTtsMonthlyUsages,
    )..where((row) => row.period.equals(period))).getSingleOrNull();
    if (current != null) {
      return current;
    }

    final latestQuery = _database.select(_database.tencentTtsMonthlyUsages)
      ..orderBy([(row) => OrderingTerm.desc(row.period)])
      ..limit(1);
    final latest = await latestQuery.getSingleOrNull();
    await _database
        .into(_database.tencentTtsMonthlyUsages)
        .insert(
          TencentTtsMonthlyUsagesCompanion.insert(
            period: period,
            quotaCharacters: Value(latest?.quotaCharacters),
            updatedAt: now,
          ),
        );
    return (_database.select(
      _database.tencentTtsMonthlyUsages,
    )..where((row) => row.period.equals(period))).getSingle();
  }

  static TencentTtsUsageSnapshot _toSnapshot(
    TencentTtsMonthlyUsageRecord record,
  ) {
    return TencentTtsUsageSnapshot(
      period: record.period,
      usedCharacters: record.usedCharacters,
      quotaCharacters: record.quotaCharacters,
      updatedAt: record.updatedAt,
    );
  }

  static String _periodFor(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    return '${value.year}-$month';
  }
}
