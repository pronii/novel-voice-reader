import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/reader/application/auto_scroll_controller.dart';

void main() {
  late List<double> advances;
  late AutoScrollController controller;

  setUp(() {
    advances = <double>[];
    controller = AutoScrollController(
      onAdvance: (offset, _) => advances.add(offset),
    );
  });

  tearDown(() {
    controller.dispose();
  });

  test('starts idle with a clamped default speed', () {
    expect(controller.status, AutoScrollStatus.idle);
    expect(controller.isRunning, isFalse);
    expect(controller.speed, AutoScrollController.defaultSpeed);
  });

  testWidgets('advances by speed * tick on every tick while running', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());

    controller.speed = 100; // 100 px/s -> 5 px per 50ms tick.
    controller.start();
    expect(controller.status, AutoScrollStatus.running);

    await tester.pump(AutoScrollController.tick * 3);

    expect(advances.length, 3);
    expect(advances.every((offset) => (offset - 5).abs() < 1e-9), isTrue);

    controller.stop();
  });

  testWidgets('pausing stops further advances but keeps it armed', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());

    controller.start();
    await tester.pump(AutoScrollController.tick * 2);
    final advancesWhenPaused = advances.length;

    controller.pause();
    expect(controller.status, AutoScrollStatus.paused);

    await tester.pump(AutoScrollController.tick * 5);
    expect(advances.length, advancesWhenPaused);

    // Resuming continues the crawl.
    controller.start();
    await tester.pump(AutoScrollController.tick * 2);
    expect(advances.length, greaterThan(advancesWhenPaused));

    controller.stop();
  });

  testWidgets('stop returns to idle and disarms the timer', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());

    controller.start();
    await tester.pump(AutoScrollController.tick);
    controller.stop();
    expect(controller.status, AutoScrollStatus.idle);

    final before = advances.length;
    await tester.pump(AutoScrollController.tick * 5);
    expect(advances.length, before);
  });

  test('toggle flips between running and paused', () {
    controller.toggle();
    expect(controller.isRunning, isTrue);
    controller.toggle();
    expect(controller.isPaused, isTrue);
    controller.stop();
  });

  test('speed is clamped and maps to coarse bands', () {
    controller.speed = 5; // below min
    expect(controller.speed, AutoScrollController.minSpeed);
    expect(controller.speedBand, AutoScrollSpeedBand.slow);

    controller.speed = 999; // above max
    expect(controller.speed, AutoScrollController.maxSpeed);
    expect(controller.speedBand, AutoScrollSpeedBand.fast);

    controller.speed = 80; // middle of the range
    expect(controller.speedBand, AutoScrollSpeedBand.medium);
  });

  test('notifies listeners on state and speed changes', () {
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.start();
    controller.speed = controller.speed + 20;
    controller.pause();
    controller.stop();

    expect(notifications, 4);
  });

  testWidgets(
    'a manual gesture suspends the crawl but keeps it running and resumes',
    (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());

      controller.speed = 100;
      controller.start();
      await tester.pump(AutoScrollController.tick * 2);
      final beforeGesture = advances.length;

      // A manual swipe interrupts the crawl without leaving the running state.
      controller.notifyUserInteractionStart();
      expect(controller.status, AutoScrollStatus.running);
      expect(controller.isRunning, isTrue);

      // No advances happen while the finger is down.
      await tester.pump(AutoScrollController.tick * 5);
      expect(advances.length, beforeGesture);

      controller.notifyUserInteractionEnd();
      // Still suspended until the resume delay elapses.
      await tester.pump(AutoScrollController.tick);
      expect(advances.length, beforeGesture);

      // Once the delay passes the crawl picks back up on its own.
      await tester.pump(AutoScrollController.gestureResumeDelay);
      await tester.pump(AutoScrollController.tick * 2);
      expect(advances.length, greaterThan(beforeGesture));

      controller.stop();
    },
  );

  testWidgets('a manual gesture while paused does not resume the crawl', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());

    controller.start();
    controller.pause();
    final paused = advances.length;

    controller.notifyUserInteractionStart();
    controller.notifyUserInteractionEnd();

    await tester.pump(
      AutoScrollController.gestureResumeDelay + AutoScrollController.tick * 3,
    );
    expect(controller.status, AutoScrollStatus.paused);
    expect(advances.length, paused);
  });

  testWidgets('pausing during a gesture cancels the pending resume', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());

    controller.start();
    controller.notifyUserInteractionStart();
    controller.notifyUserInteractionEnd();
    controller.pause();

    await tester.pump(
      AutoScrollController.gestureResumeDelay + AutoScrollController.tick * 3,
    );
    expect(controller.status, AutoScrollStatus.paused);
  });
}
