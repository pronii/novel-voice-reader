final class SpeechSegment {
  const SpeechSegment({
    required this.id,
    required this.paragraphId,
    required this.text,
    required this.partIndex,
  });

  final String id;
  final int paragraphId;
  final String text;
  final int partIndex;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SpeechSegment &&
            id == other.id &&
            paragraphId == other.paragraphId &&
            text == other.text &&
            partIndex == other.partIndex;
  }

  @override
  int get hashCode => Object.hash(id, paragraphId, text, partIndex);
}

final class SpeechSegmenter {
  const SpeechSegmenter();

  static const _sentenceEndings = '。！？!?；;';

  /// Single-character onomatopoeia / interjections that carry no narratable
  /// meaning on their own (e.g. a lone "嗤！"). A paragraph whose only
  /// meaningful character is one of these is not spoken: [split] returns no
  /// segments, so playback advances past it. Meaningful one-character lines
  /// (好, 是, 对 …) are deliberately absent so they are still read.
  static const _skippableInterjections = <String>{
    '嗤', '哼', '呵', '嘿', '哈', '嘻', '嗷', '啧', '切', '呸', '嘁',
    '啊', '呀', '哦', '噢', '喔', '咦', '唉', '哎', '呃', '唔', '哟', '唷', '嚯',
    '咚', '哐', '砰', '嘭', '咔', '嚓', '唰', '咻', '嗖', '嗒', '啪', '嘶', '叮',
  };

  static bool _isContentRune(int rune) =>
      (rune >= 0x4E00 && rune <= 0x9FFF) || // CJK unified ideographs
      (rune >= 0x41 && rune <= 0x5A) || // A-Z
      (rune >= 0x61 && rune <= 0x7A) || // a-z
      (rune >= 0x30 && rune <= 0x39); // 0-9

  /// True when the paragraph's only meaningful character is a skippable
  /// interjection. Punctuation, quotes and whitespace are ignored when
  /// judging "single character", so "嗤！" and "“嗤！”" both qualify.
  bool _isSkippableInterjection(String text) {
    final core = String.fromCharCodes(text.runes.where(_isContentRune));
    return core.runes.length == 1 && _skippableInterjections.contains(core);
  }

  List<SpeechSegment> split({
    required int paragraphId,
    required String text,
    required int maxCharacters,
  }) {
    if (maxCharacters <= 0) {
      throw ArgumentError.value(
        maxCharacters,
        'maxCharacters',
        'Must be positive.',
      );
    }
    if (_isSkippableInterjection(text)) {
      return const [];
    }
    final chunks = <String>[];
    var buffer = '';

    void flushBuffer() {
      if (buffer.isNotEmpty) {
        chunks.add(buffer);
        buffer = '';
      }
    }

    for (final sentence in _sentences(text)) {
      final sentenceLength = sentence.runes.length;
      if (sentenceLength > maxCharacters) {
        flushBuffer();
        final codePoints = sentence.runes.toList(growable: false);
        for (var start = 0; start < codePoints.length; start += maxCharacters) {
          final end = (start + maxCharacters).clamp(0, codePoints.length);
          chunks.add(String.fromCharCodes(codePoints.sublist(start, end)));
        }
      } else if (buffer.runes.length + sentenceLength <= maxCharacters) {
        buffer += sentence;
      } else {
        flushBuffer();
        buffer = sentence;
      }
    }
    flushBuffer();

    return [
      for (final entry in chunks.indexed)
        SpeechSegment(
          id: '$paragraphId:${entry.$1}',
          paragraphId: paragraphId,
          text: entry.$2,
          partIndex: entry.$1,
        ),
    ];
  }

  Iterable<String> _sentences(String text) sync* {
    var start = 0;
    for (var index = 0; index < text.length; index++) {
      if (_sentenceEndings.contains(text[index])) {
        yield text.substring(start, index + 1);
        start = index + 1;
      }
    }
    if (start < text.length) {
      yield text.substring(start);
    }
  }
}
