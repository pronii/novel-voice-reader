import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/speech/data/tencent_tts_usage_repository.dart';

void main() {
  late AppDatabase database;
  late DateTime now;
  late TencentTtsUsageRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    now = DateTime(2026, 8, 2, 12, 30);
    repository = TencentTtsUsageRepository(database, clock: () => now);
  });

  tearDown(() => database.close());

  test('starts the current month without a configured quota', () async {
    final usage = await repository.current();

    expect(usage.period, '2026-08');
    expect(usage.usedCharacters, 0);
    expect(usage.quotaCharacters, isNull);
    expect(usage.isQuotaConfigured, isFalse);
    expect(usage.remainingCharacters, isNull);
    expect(usage.overageCharacters, 0);
  });

  test('increments atomically and computes estimated remaining', () async {
    await repository.setMonthlyQuota(100);

    await Future.wait([
      repository.addSuccessfulCharacters(10),
      repository.addSuccessfulCharacters(15),
    ]);

    final usage = await repository.current();
    expect(usage.usedCharacters, 25);
    expect(usage.remainingCharacters, 75);
    expect(usage.overageCharacters, 0);
    expect(usage.updatedAt, now);
  });

  test('clamps remaining to zero and reports overage', () async {
    await repository.setMonthlyQuota(20);
    await repository.addSuccessfulCharacters(25);

    final usage = await repository.current();
    expect(usage.remainingCharacters, 0);
    expect(usage.overageCharacters, 5);
  });

  test('starts a new month at zero and carries the latest quota', () async {
    await repository.setMonthlyQuota(1000);
    await repository.addSuccessfulCharacters(80);

    now = DateTime(2026, 9, 1, 0, 1);
    final september = await repository.current();

    expect(september.period, '2026-09');
    expect(september.usedCharacters, 0);
    expect(september.quotaCharacters, 1000);
    expect(september.remainingCharacters, 1000);
  });

  test('clears the configured quota without changing usage', () async {
    await repository.setMonthlyQuota(100);
    await repository.addSuccessfulCharacters(12);

    await repository.setMonthlyQuota(null);

    final usage = await repository.current();
    expect(usage.usedCharacters, 12);
    expect(usage.quotaCharacters, isNull);
    expect(usage.remainingCharacters, isNull);
  });

  test('rejects non-positive successful character counts', () async {
    await expectLater(
      repository.addSuccessfulCharacters(0),
      throwsArgumentError,
    );
    await expectLater(
      repository.addSuccessfulCharacters(-1),
      throwsArgumentError,
    );
  });

  test('rejects a negative monthly quota', () async {
    await expectLater(repository.setMonthlyQuota(-1), throwsArgumentError);
  });
}
