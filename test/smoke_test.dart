import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/app/app.dart';

void main() {
  testWidgets('opens the library as the first screen', (tester) async {
    await tester.pumpWidget(const NovelVoiceReaderApp());

    expect(find.text('书架'), findsOneWidget);
    expect(find.text('还没有导入小说'), findsOneWidget);
  });
}
