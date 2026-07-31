import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';

void main() {
  test('two cursors at the same paragraph are equal', () {
    const first = PlaybackCursor(chapterId: 4, paragraphIndex: 8);
    const second = PlaybackCursor(chapterId: 4, paragraphIndex: 8);

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });
}
