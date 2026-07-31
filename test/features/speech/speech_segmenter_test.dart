import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';

void main() {
  test('splits on sentence punctuation without losing text', () {
    const text = '第一句很短。第二句也很短！第三句结束？';

    final parts = const SpeechSegmenter().split(
      paragraphId: 7,
      text: text,
      maxCharacters: 12,
    );

    expect(parts.map((part) => part.text).join(), text);
    expect(parts.every((part) => part.text.length <= 12), isTrue);
    expect(parts.map((part) => part.id), ['7:0', '7:1', '7:2']);
  });

  test('hard-splits a sentence longer than the service limit', () {
    final text = List.filled(25, '长').join();

    final parts = const SpeechSegmenter().split(
      paragraphId: 9,
      text: text,
      maxCharacters: 10,
    );

    expect(parts.map((part) => part.text.length), [10, 10, 5]);
    expect(parts.map((part) => part.text).join(), text);
  });

  test('rejects a non-positive service limit', () {
    expect(
      () => const SpeechSegmenter().split(
        paragraphId: 1,
        text: '正文',
        maxCharacters: 0,
      ),
      throwsArgumentError,
    );
  });
}
