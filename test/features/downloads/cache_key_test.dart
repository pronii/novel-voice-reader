import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/downloads/domain/cache_key.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test('is stable for the same text and voice configuration', () {
    const segment = SpeechSegment(
      id: '1:0',
      paragraphId: 1,
      text: '正文',
      partIndex: 0,
    );
    final profile = VoiceProfile.cloud(
      baseUrl: 'https://example.com/',
      model: 'tts-model',
      voice: 'voice-a',
      speed: 1,
      outputFormat: 'mp3',
    );

    final first = CacheKey.forSegment(segment, profile);
    final second = CacheKey.forSegment(segment, profile);

    expect(first, second);
    expect(first, hasLength(64));
    expect(first, isNot(contains('正文')));
  });

  test('changes when the voice changes', () {
    const segment = SpeechSegment(
      id: '1:0',
      paragraphId: 1,
      text: '正文',
      partIndex: 0,
    );
    final first = CacheKey.forSegment(
      segment,
      VoiceProfile.cloud(
        baseUrl: 'https://example.com',
        model: 'tts-model',
        voice: 'voice-a',
        speed: 1,
        outputFormat: 'mp3',
      ),
    );
    final second = CacheKey.forSegment(
      segment,
      VoiceProfile.cloud(
        baseUrl: 'https://example.com',
        model: 'tts-model',
        voice: 'voice-b',
        speed: 1,
        outputFormat: 'mp3',
      ),
    );

    expect(first, isNot(second));
  });

  test('separates identical text from different paragraph ids', () {
    const firstSegment = SpeechSegment(
      id: '1:0',
      paragraphId: 1,
      text: '相同正文',
      partIndex: 0,
    );
    const secondSegment = SpeechSegment(
      id: '99:3',
      paragraphId: 99,
      text: '相同正文',
      partIndex: 3,
    );
    final profile = VoiceProfile.cloud(
      baseUrl: 'https://example.com',
      model: 'tts-model',
      voice: 'voice-a',
      speed: 1,
      outputFormat: 'mp3',
    );

    expect(
      CacheKey.forSegment(firstSegment, profile),
      isNot(CacheKey.forSegment(secondSegment, profile)),
    );
  });
}
