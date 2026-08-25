import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/diagnostics/domain/playback_telemetry.dart';
import 'package:novel_voice_reader/features/playback/application/manual_seek_prewarmer.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_content.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  const paragraph = ReaderParagraph(
    id: 42,
    chapterId: 7,
    index: 3,
    text: '第一句。第二句。',
  );

  test('warms only the first segment for a server profile', () async {
    final warmed = <(SpeechSegment, VoiceProfile)>[];
    final telemetry = _RecordingTelemetry();
    final prewarmer = ManualSeekPrewarmer(
      loadProfile: () async => _serverProfile(),
      warmSegment: (segment, profile) async {
        warmed.add((segment, profile));
      },
      telemetry: telemetry,
    );

    await prewarmer.warm(paragraph);

    expect(
      warmed.single.$1,
      const SpeechSegment(
        id: '42:0',
        paragraphId: 42,
        text: '第一句。第二句。',
        partIndex: 0,
      ),
    );
    expect(warmed.single.$2.providerType, SpeechProviderType.server);
    expect(
      telemetry.events.map((event) => event.$1),
      [
        'playback.manual_seek.warm.begin',
        'playback.manual_seek.warm.success',
      ],
    );
  });

  test('does not warm a segment for a non-server profile', () async {
    var warmCalls = 0;
    final telemetry = _RecordingTelemetry();
    final prewarmer = ManualSeekPrewarmer(
      loadProfile: () async => _cloudProfile(),
      warmSegment: (segment, profile) async {
        warmCalls++;
      },
      telemetry: telemetry,
    );

    await prewarmer.warm(paragraph);

    expect(warmCalls, 0);
    expect(telemetry.events.last.$1, 'playback.manual_seek.warm.skipped');
    expect(telemetry.events.last.$2['reason'], 'provider_not_server');
  });

  test('ignores an empty paragraph', () async {
    var warmCalls = 0;
    final prewarmer = ManualSeekPrewarmer(
      loadProfile: () async => _serverProfile(),
      warmSegment: (segment, profile) async {
        warmCalls++;
      },
    );

    await prewarmer.warm(
      const ReaderParagraph(id: 42, chapterId: 7, index: 3, text: ''),
    );

    expect(warmCalls, 0);
  });

  test('swallows warm-up errors and records only safe metadata', () async {
    final telemetry = _RecordingTelemetry();
    final prewarmer = ManualSeekPrewarmer(
      loadProfile: () async => _serverProfile(),
      warmSegment: (segment, profile) async {
        throw StateError('warm-up failed');
      },
      telemetry: telemetry,
    );

    await expectLater(prewarmer.warm(paragraph), completes);

    final failure = telemetry.events.singleWhere(
      (event) => event.$1 == 'playback.manual_seek.warm.failure',
    );
    expect(
      failure.$2.keys,
      unorderedEquals([
        'paragraph_id',
        'chapter_id',
        'paragraph_index',
        'elapsed_ms',
        'error_type',
      ]),
    );
    expect(failure.$2, containsPair('paragraph_id', 42));
    expect(failure.$2, containsPair('chapter_id', 7));
    expect(failure.$2, containsPair('paragraph_index', 3));
    expect(failure.$2, containsPair('error_type', 'StateError'));
    expect(failure.$2['elapsed_ms'], isA<int>());
  });
}

VoiceProfile _serverProfile() => VoiceProfile.server(
  baseUrl: 'https://speech.example.com',
  model: 'test-model',
  voice: 'test-voice',
  speed: 1,
);

VoiceProfile _cloudProfile() => VoiceProfile.cloud(
  baseUrl: 'https://speech.example.com',
  model: 'test-model',
  voice: 'test-voice',
  speed: 1,
  outputFormat: 'mp3',
);

final class _RecordingTelemetry implements PlaybackTelemetry {
  final List<(String, Map<String, Object?>)> events = [];

  @override
  void record(String name, [Map<String, Object?> fields = const {}]) {
    events.add((name, fields));
  }

  @override
  Future<void> flush() async {}
}
