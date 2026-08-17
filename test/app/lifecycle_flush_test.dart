import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/app/app.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/diagnostics/domain/playback_telemetry.dart';

/// Records how often telemetry is flushed so we can assert the background
/// upload behaviour that gets lock-screen events to the collector before iOS
/// suspends the isolate.
final class _RecordingTelemetry implements PlaybackTelemetry {
  int flushes = 0;
  final List<String> events = <String>[];

  @override
  void record(String name, [Map<String, Object?> fields = const {}]) {
    events.add(name);
  }

  @override
  Future<void> flush() async {
    flushes++;
  }
}

void main() {
  testWidgets('flushes on backgrounding and keeps flushing periodically', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final telemetry = _RecordingTelemetry();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.createBookWithChapter(
      title: '生命周期测试书',
      chapterTitle: '第一章',
      paragraphs: const ['第一段。'],
    );

    await tester.pumpWidget(
      NovelVoiceReaderApp(database: database, telemetry: telemetry),
    );
    await tester.pump();

    // initState ships anything left over from a previous (suspended) run.
    final afterLaunch = telemetry.flushes;
    expect(afterLaunch, greaterThanOrEqualTo(1));

    // Going to the lock screen uploads immediately, before a suspension.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(telemetry.flushes, greaterThan(afterLaunch));
    final afterPause = telemetry.flushes;

    // ...and keeps uploading on a timer while backgrounded.
    await tester.pump(const Duration(seconds: 21));
    expect(telemetry.flushes, greaterThan(afterPause));

    // Returning to the foreground uploads once more and stops the pump.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    final afterResume = telemetry.flushes;
    await tester.pump(const Duration(seconds: 42));
    expect(
      telemetry.flushes,
      afterResume,
      reason: 'periodic flush must stop once foregrounded',
    );
  });
}
