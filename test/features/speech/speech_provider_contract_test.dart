import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';

void main() {
  test('speech failure identifies the failed segment', () {
    const failure = AppFailure('网络不可用');
    const event = SpeechFailed(segmentId: '4:2', failure: failure);

    expect(event.segmentId, '4:2');
    expect(event.failure, failure);
  });

  test('speech segments compare by stable identity and text', () {
    const first = SpeechSegment(
      id: '4:2',
      paragraphId: 4,
      text: '正文',
      partIndex: 2,
    );
    const second = SpeechSegment(
      id: '4:2',
      paragraphId: 4,
      text: '正文',
      partIndex: 2,
    );

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });
}
