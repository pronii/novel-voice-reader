import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/speech/data/system_tts_adapter.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test('maps engine start and completion callbacks to speech events', () async {
    final engine = FakeSystemTtsEngine();
    final adapter = SystemTtsAdapter(engine);
    const segment = SpeechSegment(
      id: '3:0',
      paragraphId: 3,
      text: '正文',
      partIndex: 0,
    );
    final events = <SpeechEvent>[];
    final subscription = adapter.events.listen(events.add);

    await adapter.prepare(segment, VoiceProfile.system());
    await adapter.play();
    engine.start();
    engine.complete();

    expect(engine.spoken, ['正文']);
    expect(events.whereType<SpeechStarted>().single.segmentId, '3:0');
    expect(events.whereType<SpeechCompleted>().single.segmentId, '3:0');
    await subscription.cancel();
    await adapter.dispose();
  });

  test('pause and resume delegate to the engine', () async {
    final engine = FakeSystemTtsEngine();
    final adapter = SystemTtsAdapter(engine);
    const segment = SpeechSegment(
      id: '3:0',
      paragraphId: 3,
      text: '正文',
      partIndex: 0,
    );
    await adapter.prepare(segment, VoiceProfile.system());
    await adapter.play();

    await adapter.pause();
    await adapter.resume();

    expect(engine.pauseCalls, 1);
    expect(engine.spoken, ['正文', '正文']);
    await adapter.dispose();
  });
}

final class FakeSystemTtsEngine implements SystemTtsEngine {
  final List<String> spoken = [];
  int pauseCalls = 0;
  void Function()? onStart;
  void Function()? onComplete;
  void Function(Object error)? onError;

  @override
  void setCompletionHandler(void Function() handler) {
    onComplete = handler;
  }

  @override
  void setErrorHandler(void Function(Object error) handler) {
    onError = handler;
  }

  @override
  void setStartHandler(void Function() handler) {
    onStart = handler;
  }

  @override
  Future<void> configure(VoiceProfile profile) async {}

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> stop() async {}

  void start() => onStart?.call();

  void complete() => onComplete?.call();
}
