import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}

Set<double> _selectedSpeed(WidgetTester tester) => tester
    .widget<SegmentedButton<double>>(find.byType(SegmentedButton<double>))
    .selected;
