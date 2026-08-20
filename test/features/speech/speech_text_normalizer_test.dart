import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_text_normalizer.dart';

void main() {
  const normalizer = SpeechTextNormalizer();

  group('SpeechTextNormalizer', () {
    test('reads plain integers in Chinese', () {
      expect(normalizer.normalizeForTts('有123个人'), '有一百二十三个人');
      expect(normalizer.normalizeForTts('0'), '零');
      expect(normalizer.normalizeForTts('10'), '十');
      expect(normalizer.normalizeForTts('15'), '十五');
      expect(normalizer.normalizeForTts('100'), '一百');
      expect(normalizer.normalizeForTts('1000'), '一千');
      expect(normalizer.normalizeForTts('1001'), '一千零一');
      expect(normalizer.normalizeForTts('10000'), '一万');
      expect(normalizer.normalizeForTts('12345'), '一万二千三百四十五');
    });

    test('reads decimals digit by digit after the point', () {
      expect(normalizer.normalizeForTts('3.14'), '三点一四');
      expect(normalizer.normalizeForTts('0.5'), '零点五');
      expect(normalizer.normalizeForTts('10.25'), '十点二五');
    });

    test('reads percentages in Chinese', () {
      expect(normalizer.normalizeForTts('成功率50%'), '成功率百分之五十');
      expect(normalizer.normalizeForTts('12.5%'), '百分之十二点五');
    });

    test('reads four-digit years digit by digit', () {
      expect(normalizer.normalizeForTts('1990年'), '一九九零年');
      expect(normalizer.normalizeForTts('2024年8月'), '二零二四年八月');
    });

    test('reads ordinals as values', () {
      expect(normalizer.normalizeForTts('第3章'), '第三章');
      expect(normalizer.normalizeForTts('第12名'), '第十二名');
    });

    test('handles negative numbers', () {
      expect(normalizer.normalizeForTts('-5度'), '负五度');
    });

    test('keeps Chinese text, punctuation and tone words untouched', () {
      const input = '啊，轰的一声，门被撞开了！';
      expect(normalizer.normalizeForTts(input), input);
      expect(normalizer.normalizeForTts('他笑了笑，说道：“好。”'), '他笑了笑，说道：“好。”');
    });

    test('collapses ellipsis into an em dash', () {
      // ASCII 3+ dots → 破折号
      expect(normalizer.normalizeForTts('...'), '——');
      expect(normalizer.normalizeForTts('......'), '——');
      expect(normalizer.normalizeForTts('我......没事'), '我——没事');
      // 2+ 个 U+2026 → 破折号
      expect(normalizer.normalizeForTts('他砰的一声……'), '他砰的一声——');
      // 单 U+2026 保留(短停顿)
      expect(normalizer.normalizeForTts('嗯…好吧'), '嗯…好吧');
    });

    test('compresses 3+ repeated Chinese characters to two', () {
      expect(normalizer.normalizeForTts('嗖嗖嗖'), '嗖嗖');
      expect(normalizer.normalizeForTts('啊啊啊'), '啊啊');
      expect(normalizer.normalizeForTts('哈哈哈！'), '哈哈！');
      expect(normalizer.normalizeForTts('砰砰砰三声'), '砰砰三声');
      // 2 个不压缩
      expect(normalizer.normalizeForTts('呵呵'), '呵呵');
      // 不应破坏正常 2 字叠用
      expect(normalizer.normalizeForTts('他独自自出发'), '他独自自出发');
    });

    test('applies tone-word rules in mixed context', () {
      expect(
        normalizer.normalizeForTts('嗖嗖嗖的风声……他嗖嗖嗖的跑过去'),
        '嗖嗖的风声——他嗖嗖的跑过去',
      );
    });

    test('is idempotent', () {
      const input = '他生于1990年，身高180.5cm，体重72kg，达标率95%。';
      final once = normalizer.normalizeForTts(input);
      final twice = normalizer.normalizeForTts(once);
      expect(twice, once);
      expect(once.contains(RegExp(r'\d')), isFalse);
    });

    test('handles empty text', () {
      expect(normalizer.normalizeForTts(''), '');
    });
  });
}
