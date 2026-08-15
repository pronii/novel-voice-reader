import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:novel_voice_reader/features/speech/data/system_tts_adapter.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_provider.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps the normal speed multiplier to the system TTS rate', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return 1;
        });
    final engine = FlutterSystemTtsEngine();

    await engine.configure(VoiceProfile.system());

    expect(
      calls.where((call) => call.method == 'setSpeechRate').single.arguments,
      0.5,
    );
  });

  test('maps a playback multiplier to the system TTS rate', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return 1;
        });
    final engine = FlutterSystemTtsEngine();

    await engine.setPlaybackSpeed(1.5);

    expect(
      calls.where((call) => call.method == 'setSpeechRate').single.arguments,
      0.75,
    );
  });

  test('forwards playback speed to an adjustable system engine', () async {
    final engine = AdjustableFakeSystemTtsEngine();
    final adapter = SystemTtsAdapter(engine);

    await adapter.setPlaybackSpeed(1.5);

    expect(engine.speedChanges, [1.5]);
    await adapter.dispose();
  });

  test(
    'rejects playback speed when the system engine is not adjustable',
    () async {
      final adapter = SystemTtsAdapter(FakeSystemTtsEngine());

      await expectLater(adapter.setPlaybackSpeed(1.5), throwsStateError);

      await adapter.dispose();
    },
  );

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

  test(
    'configures the platform audio session once before the first speak',
    () async {
      final engine = SessionConfigurableFakeSystemTtsEngine();
      final adapter = SystemTtsAdapter(engine);
      const first = SpeechSegment(
        id: '1:0',
        paragraphId: 1,
        text: '第一句',
        partIndex: 0,
      );
      const second = SpeechSegment(
        id: '1:1',
        paragraphId: 1,
        text: '第二句',
        partIndex: 1,
      );

      await adapter.prepare(first, VoiceProfile.system());
      await adapter.play();
      await adapter.prepare(second, VoiceProfile.system());
      await adapter.play();

      // The iOS session (playback category / shared instance) must be armed
      // before any audio is produced, and only once for the provider's life.
      expect(engine.configureSessionCalls, 1);
      expect(engine.configuredBeforeFirstSpeak, isTrue);
      await adapter.dispose();
    },
  );

  test(
    'FlutterSystemTtsEngine shares the audio session when configuring on iOS',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return 1;
          });
      final engine = FlutterSystemTtsEngine(FlutterTts(), true);

      await engine.configureSession();

      // setIosAudioCategory itself is guarded by the real platform inside
      // flutter_tts, so on a non-iOS host we can only assert the shared-session
      // call fires; the category application is covered by on-device testing.
      final shared = calls
          .where((call) => call.method == 'setSharedInstance')
          .single;
      expect(shared.arguments, isTrue);
    },
  );
}

class FakeSystemTtsEngine implements SystemTtsEngine {
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

final class AdjustableFakeSystemTtsEngine extends FakeSystemTtsEngine
    implements AdjustableSystemTtsEngine {
  final List<double> speedChanges = [];

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    speedChanges.add(speed);
  }
}

final class SessionConfigurableFakeSystemTtsEngine extends FakeSystemTtsEngine
    implements SessionConfigurableSystemTtsEngine {
  int configureSessionCalls = 0;
  bool configuredBeforeFirstSpeak = false;

  @override
  Future<void> configureSession() async {
    configureSessionCalls++;
    configuredBeforeFirstSpeak = spoken.isEmpty;
  }
}
