import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_timeline.dart';
import 'package:novel_voice_reader/features/playback/presentation/player_page.dart';

void main() {
  testWidgets('reports a selected playback speed', (tester) async {
    double? selectedSpeed;

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerPage(
          bookTitle: '测试书',
          chapterTitle: '第一章',
          initialSpeed: 1.25,
          onSpeedChanged: (speed) async => selectedSpeed = speed,
        ),
      ),
    );

    expect(
      tester
          .widget<SegmentedButton<double>>(find.byType(SegmentedButton<double>))
          .selected,
      {1.25},
    );
    await tester.tap(find.text('1.5x'));
    await tester.pump();

    expect(selectedSpeed, 1.5);
  });

  testWidgets('keeps the effective speed when applying a change fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerPage(
          bookTitle: '测试书',
          chapterTitle: '第一章',
          onSpeedChanged: (_) async => throw StateError('speed failed'),
        ),
      ),
    );

    await tester.tap(find.text('1.5x'));
    await tester.pump();

    expect(
      tester
          .widget<SegmentedButton<double>>(find.byType(SegmentedButton<double>))
          .selected,
      {1},
    );
  });

  testWidgets('serializes rapid playback speed selections', (tester) async {
    final completions = <Completer<void>>[];
    final requestedSpeeds = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerPage(
          bookTitle: '测试书',
          chapterTitle: '第一章',
          onSpeedChanged: (speed) async {
            requestedSpeeds.add(speed);
            final completion = Completer<void>();
            completions.add(completion);
            await completion.future;
          },
        ),
      ),
    );

    await tester.tap(find.text('1.25x'));
    await tester.tap(find.text('1.5x'));
    await tester.pump();

    expect(requestedSpeeds, [1.25]);
    expect(_selectedSpeed(tester), {1});

    completions.first.complete();
    await tester.pump();
    expect(requestedSpeeds, [1.25, 1.5]);
    expect(_selectedSpeed(tester), {1.25});

    completions.last.complete();
    await tester.pump();
    expect(_selectedSpeed(tester), {1.5});
  });

  testWidgets('shows pause when playback is already active', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlayerPage(
          bookTitle: '测试书',
          chapterTitle: '第一章',
          initialPlaying: true,
        ),
      ),
    );

    expect(find.byTooltip('暂停'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });

  testWidgets('follows external playback state changes', (tester) async {
    final changes = StreamController<bool>();
    addTearDown(changes.close);
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerPage(
          bookTitle: '测试书',
          chapterTitle: '第一章',
          playingChanges: changes.stream,
        ),
      ),
    );

    expect(find.byTooltip('播放'), findsOneWidget);
    changes.add(true);
    await tester.pump();
    expect(find.byTooltip('暂停'), findsOneWidget);

    changes.add(false);
    await tester.pump();
    expect(find.byTooltip('播放'), findsOneWidget);
  });

  testWidgets('shows real playback progress and remaining time', (
    tester,
  ) async {
    final timelineChanges = StreamController<PlaybackTimeline>();
    addTearDown(timelineChanges.close);
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerPage(
          bookTitle: '测试书',
          chapterTitle: '第一章',
          initialTimeline: const PlaybackTimeline(
            position: Duration(minutes: 1),
            duration: Duration(minutes: 5),
          ),
          timelineChanges: timelineChanges.stream,
        ),
      ),
    );

    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.2,
    );
    expect(find.text('01:00 / 05:00'), findsOneWidget);
    expect(find.text('剩余 04:00'), findsOneWidget);

    timelineChanges.add(
      const PlaybackTimeline(
        position: Duration(minutes: 2, seconds: 30),
        duration: Duration(minutes: 5),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.5,
    );
    expect(find.text('02:30 / 05:00'), findsOneWidget);
    expect(find.text('剩余 02:30'), findsOneWidget);
  });
}

Set<double> _selectedSpeed(WidgetTester tester) => tester
    .widget<SegmentedButton<double>>(find.byType(SegmentedButton<double>))
    .selected;
