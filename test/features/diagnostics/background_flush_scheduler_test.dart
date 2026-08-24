import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/diagnostics/application/background_flush_scheduler.dart';

void main() {
  test('uploads on background then periodically, and stops on foreground', () async {
    var flushes = 0;
    final scheduler = BackgroundFlushScheduler(
      flush: () async => flushes++,
      interval: const Duration(milliseconds: 20),
    );
    addTearDown(scheduler.dispose);

    // Backgrounding uploads immediately, before any suspension.
    scheduler.onBackground();
    expect(flushes, 1);

    // ...and keeps uploading while backgrounded.
    await Future<void>.delayed(const Duration(milliseconds: 75));
    expect(flushes, greaterThan(1));

    // Foregrounding uploads once more and stops the periodic pump.
    final afterForeground = flushes + 1;
    scheduler.onForeground();
    expect(flushes, afterForeground);
    await Future<void>.delayed(const Duration(milliseconds: 75));
    expect(
      flushes,
      afterForeground,
      reason: 'periodic uploads must stop once foregrounded',
    );
  });

  test('dispose stops the periodic pump', () async {
    var flushes = 0;
    final scheduler = BackgroundFlushScheduler(
      flush: () async => flushes++,
      interval: const Duration(milliseconds: 20),
    );

    scheduler.onBackground();
    final afterDispose = flushes;
    scheduler.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 75));
    expect(flushes, afterDispose);
  });
}
