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
          onSpeedChanged: (speed) => selectedSpeed = speed,
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

    expect(selectedSpeed, 1.5);
  });
}
