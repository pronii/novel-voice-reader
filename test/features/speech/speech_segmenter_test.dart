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

  test('counts Unicode code points without splitting surrogate pairs', () {
    final text = List.filled(151, '𠮷').join();

    final parts = const SpeechSegmenter().split(
      paragraphId: 10,
      text: text,
      maxCharacters: 150,
    );

    expect(parts.map((part) => part.text.runes.length), [150, 1]);
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

  test('skips a lone onomatopoeia paragraph so it is not narrated', () {
    for (final text in ['嗤！', '“嗤！”', '啊？', '哼。', '呃……']) {
      expect(
        const SpeechSegmenter().split(
          paragraphId: 3,
          text: text,
          maxCharacters: 100,
        ),
        isEmpty,
        reason: text,
      );
    }
  });

  test('still narrates a meaningful single-character line', () {
    for (final text in ['好。', '是！', '对。']) {
      final parts = const SpeechSegmenter().split(
        paragraphId: 4,
        text: text,
        maxCharacters: 100,
      );
      expect(parts, hasLength(1), reason: text);
      expect(parts.single.text, text);
    }
  });

  test('does not skip a multi-character onomatopoeia paragraph', () {
    final parts = const SpeechSegmenter().split(
      paragraphId: 5,
      text: '嗤嗤！',
      maxCharacters: 100,
    );
    expect(parts, hasLength(1));
    expect(parts.single.text, '嗤嗤！');
  });
}
