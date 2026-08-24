import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/app/widgets/book_cover.dart';

void main() {
  testWidgets('draws a first-character monogram when no cover image is set', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BookCover(title: '三体'))),
      ),
    );

    // With no imagePath the placeholder is drawn: a single-glyph monogram of
    // the title's first character, and no Image widget.
    expect(find.text('三'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('renders an Image widget when a cover image path is set', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: BookCover(title: '三体', imagePath: '/tmp/does-not-exist'),
          ),
        ),
      ),
    );

    // A real cover swaps in an Image.file; the monogram is not drawn up front.
    // (A missing/corrupt file later falls back to the placeholder via the
    // Image's errorBuilder, which is exercised at runtime, not synchronously.)
    expect(find.byType(Image), findsOneWidget);
  });
}
