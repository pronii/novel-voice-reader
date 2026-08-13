import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/playback/application/sleep_timer_controller.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';

void main() {
  late int expired;
  late int? chapterId;
  late StreamController<PlaybackCursor?> cursors;
  late SleepTimerController controller;

  setUp(() {
    expired = 0;
    chapterId = 10;
    cursors = StreamController<PlaybackCursor?>.broadcast();
    controller = SleepTimerController(
      onExpire: () async => expired++,
      currentChapterId: () => chapterId,
      cursorChanges: () => cursors.stream,
    );
  });

  tearDown(() {
    controller.dispose();
    cursors.close();
  });

  testWidgets('stops playback after the chosen duration', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());

    controller.startDuration(const Duration(minutes: 15));
    expect(controller.isActive, isTrue);
    expect(controller.remaining, const Duration(minutes: 15));

    await tester.pump(const Duration(minutes: 15));
    await tester.pump(Duration.zero);

    expect(expired, 1);
    expect(controller.isActive, isFalse);
    expect(controller.remaining, isNull);
  });

  testWidgets('counts the remaining time down every second', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());

    controller.startDuration(const Duration(minutes: 15));
    await tester.pump(const Duration(seconds: 60));

    expect(controller.remaining, const Duration(minutes: 14));
    expect(controller.isActive, isTrue);
    expect(expired, 0);
  });

  testWidgets('cancelling prevents the timer from firing', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());

    controller.startDuration(const Duration(minutes: 15));
    controller.cancel();
    expect(controller.isActive, isFalse);

    await tester.pump(const Duration(minutes: 20));
    expect(expired, 0);
  });

  testWidgets('stops once the current chapter finishes', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());

    expect(controller.startEndOfChapter(), isTrue);
    expect(controller.isActive, isTrue);
    expect(controller.isEndOfChapter, isTrue);

    // A cursor still inside the armed chapter must not stop playback.
    cursors.add(const PlaybackCursor(chapterId: 10, paragraphIndex: 4));
    await tester.pump();
    expect(expired, 0);
    expect(controller.isActive, isTrue);

    // Crossing into the next chapter stops playback exactly once.
    cursors.add(const PlaybackCursor(chapterId: 11, paragraphIndex: 0));
    await tester.pump();
    expect(expired, 1);
    expect(controller.isActive, isFalse);
  });

  testWidgets('end-of-chapter timer clears when playback stops itself', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());

    expect(controller.startEndOfChapter(), isTrue);
    cursors.add(null);
    await tester.pump();

    expect(expired, 0);
    expect(controller.isActive, isFalse);
  });

  testWidgets('does not arm end-of-chapter when nothing is playing', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    chapterId = null;

    expect(controller.startEndOfChapter(), isFalse);
    expect(controller.isActive, isFalse);
  });
}
