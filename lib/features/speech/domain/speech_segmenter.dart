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
