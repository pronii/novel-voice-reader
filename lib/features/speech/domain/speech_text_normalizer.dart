/// Normalizes book text before it reaches a TTS engine so numbers are read
/// the way a Chinese narrator would say them (e.g. `123` → `一百二十三`,
/// `1990年` → `一九九零年`, `3.14` → `三点一四`) instead of falling back to
/// English digit/word pronunciation.
///
/// Idempotent: the output never contains ASCII digits, so applying it twice
/// is safe (both the app and the self-hosted server may normalize).
final class SpeechTextNormalizer {
  const SpeechTextNormalizer();

  static const _digits = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
  static const _smallUnits = ['', '十', '百', '千'];
  static const _bigUnits = ['', '万', '亿'];

  static final _ellipsisPattern = RegExp(r'\.{3,}|…{2,}');
  static final _repeatedCharPattern = RegExp(r'([\u4e00-\u9fa5])\1{2,}');
  static final _percentPattern = RegExp(r'(\d+(?:\.\d+)?)%');
  static final _decimalPattern = RegExp(r'\d+\.\d+');
  static final _yearPattern = RegExp(r'(\d{4})年');
  static final _intPattern = RegExp(r'-?\d+');

  String normalizeForTts(String text) {
    if (text.isEmpty) return text;
    var result = text;
    // 省略号(……或 3+ 个点)统一为破折号——TTS 看到纯停顿符不会再发出拟声音
    result = result.replaceAllMapped(
      _ellipsisPattern,
      (_) => '——',
    );
    // 叠字压缩:3+ 个连续同字(如嗖嗖嗖、啊啊啊、哈哈哈)→ 2 个,
    // 避免 TTS 拉长或拟声化(读成"咻咻咻"之类)
    result = result.replaceAllMapped(
      _repeatedCharPattern,
      (match) => '${match.group(1)}${match.group(1)}',
    );
    // 50% → 百分之五十；12.5% → 百分之十二点五
    result = result.replaceAllMapped(
      _percentPattern,
      (match) => '百分之${_numberToChinese(match.group(1)!)}',
    );
    // 3.14 → 三点一四
    result = result.replaceAllMapped(
      _decimalPattern,
      (match) => _numberToChinese(match.group(0)!),
    );
    // 1990年 → 一九九零年（年份按位读，避免“一千九百九十年”）
    result = result.replaceAllMapped(
      _yearPattern,
      (match) => '${_digitByDigit(match.group(1)!)}年',
    );
    // 123 → 一百二十三；-5 → 负五
    result = result.replaceAllMapped(
      _intPattern,
      (match) => _intToChinese(int.parse(match.group(0)!)),
    );
    return result;
  }

  /// Converts an optionally-fractional numeric string, e.g. `12.5` → `十二点五`.
  String _numberToChinese(String value) {
    if (!value.contains('.')) {
      return _intToChinese(int.parse(value));
    }
    final parts = value.split('.');
    return '${_intToChinese(int.parse(parts[0]))}点${_digitByDigit(parts[1])}';
  }

  /// Reads each digit in turn: `1990` → `一九九零`. Used for years and for
  /// numbers too large to comfortably say as a whole value.
  String _digitByDigit(String digits) {
    return digits.split('').map((char) => _digits[int.parse(char)]).join();
  }

  /// Whole-number to Chinese: 0 → 零, 15 → 十五, 123 → 一百二十三,
  /// 1001 → 一千零一, 10000 → 一万, 123456789 → 一亿二千三百四十五万六千七百八十九.
  String _intToChinese(int value) {
    if (value == 0) return '零';
    if (value < 0) return '负${_intToChinese(-value)}';
    final raw = value.toString();
    if (raw.length > 12) return _digitByDigit(raw);

    final sections = <int>[];
    var remaining = value;
    while (remaining > 0) {
      sections.add(remaining % 10000);
      remaining ~/= 10000;
    }

    final parts = <String>[];
    for (var index = sections.length - 1; index >= 0; index--) {
      final section = sections[index];
      if (section == 0) {
        // All-zero section in the middle: emit one 零 when lower sections
        // have non-zero content, e.g. 100000001 → 一亿零一.
        final hasLowerNonZero = sections.take(index).any((s) => s != 0);
        if (hasLowerNonZero && parts.isNotEmpty && !parts.last.endsWith('零')) {
          parts.add('零');
        }
        continue;
      }
      // A non-leading section under 1000 implies internal zeros, e.g.
      // 10001 → 一万零一.
      final needZero =
          parts.isNotEmpty && section < 1000 && !parts.last.endsWith('零');
      parts.add('${needZero ? '零' : ''}${_sectionToChinese(section)}'
          '${_bigUnits[index]}');
    }
    return parts.join();
  }

  /// Converts a 1–9999 block: 1 → 一, 10 → 十, 15 → 十五, 101 → 一百零一,
  /// 1001 → 一千零一.
  String _sectionToChinese(int section) {
    if (section < 10) return _digits[section];
    if (section < 20) {
      return section == 10 ? '十' : '十${_digits[section % 10]}';
    }
    final buffer = StringBuffer();
    final raw = section.toString();
    for (var index = 0; index < raw.length; index++) {
      final digit = int.parse(raw[index]);
      final place = raw.length - 1 - index;
      if (digit == 0) {
        final restHasNonZero = raw.substring(index + 1).contains(RegExp(r'[1-9]'));
        if (restHasNonZero && !buffer.toString().endsWith('零')) {
          buffer.write('零');
        }
      } else {
        buffer
          ..write(_digits[digit])
          ..write(_smallUnits[place]);
      }
    }
    return buffer.toString();
  }
}
