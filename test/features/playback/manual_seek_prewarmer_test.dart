import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/diagnostics/domain/playback_telemetry.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
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

  test('warms only the first server segment beyond the 1000-char limit', () async {
    final warmed = <(SpeechSegment, VoiceProfile)>[];
    final telemetry = _RecordingTelemetry();
    final prewarmer = ManualSeekPrewarmer(
      loadProfile: () async => _serverProfile(),
      warmSegment: (segment, profile) async {
        warmed.add((segment, profile));
        return AudioCacheObtainSource.created;
      },
      telemetry: telemetry,
    );

    await prewarmer.warm(
      ReaderParagraph(
        id: 42,
        chapterId: 7,
        index: 3,
        text: List.filled(1200, '文').join(),
      ),
    );

    expect(warmed, hasLength(1));
    expect(warmed.single.$1.id, '42:0');
    expect(warmed.single.$1.paragraphId, 42);
    expect(warmed.single.$1.partIndex, 0);
    expect(warmed.single.$1.text.runes, hasLength(1000));
    expect(warmed.single.$2.providerType, SpeechProviderType.server);
    expect(
      telemetry.events.map((event) => event.$1),
      [
        'playback.manual_seek.warm.begin',
        'playback.manual_seek.warm.success',
      ],
    );
    expect(
      telemetry.events.last.$2['source'],
      AudioCacheObtainSource.created.name,
    );
  });

  test('does not warm a segment for a non-server profile', () async {
    var warmCalls = 0;
    final telemetry = _RecordingTelemetry();
    final prewarmer = ManualSeekPrewarmer(
      loadProfile: () async => _cloudProfile(),
      warmSegment: (segment, profile) async {
        warmCalls++;
        return AudioCacheObtainSource.created;
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
    final telemetry = _RecordingTelemetry();
    final prewarmer = ManualSeekPrewarmer(
      loadProfile: () async => _serverProfile(),
      warmSegment: (segment, profile) async {
        warmCalls++;
        return AudioCacheObtainSource.created;
      },
      telemetry: telemetry,
    );

    await prewarmer.warm(
      const ReaderParagraph(id: 42, chapterId: 7, index: 3, text: ''),
    );

    expect(warmCalls, 0);
    expect(telemetry.events.last.$1, 'playback.manual_seek.warm.skipped');
    expect(telemetry.events.last.$2['reason'], 'empty_text');
  });

  for (final source in AudioCacheObtainSource.values) {
    test('records ${source.name} as the warm-up source', () async {
      final telemetry = _RecordingTelemetry();
      final prewarmer = ManualSeekPrewarmer(
        loadProfile: () async => _serverProfile(),
        warmSegment: (segment, profile) async => source,
        telemetry: telemetry,
      );

      await prewarmer.warm(paragraph);

      final success = telemetry.events.singleWhere(
        (event) => event.$1 == 'playback.manual_seek.warm.success',
      );
      expect(success.$2['source'], source.name);
    });
  }

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

  test('telemetry failures never escape or prevent warming', () async {
    var warmCalls = 0;
    final prewarmer = ManualSeekPrewarmer(
      loadProfile: () async => _serverProfile(),
      warmSegment: (segment, profile) async {
        warmCalls++;
        return AudioCacheObtainSource.created;
      },
      telemetry: _ThrowingTelemetry(),
    );

    await expectLater(prewarmer.warm(paragraph), completes);

    expect(warmCalls, 1);
  });

  test('telemetry failures do not replace a warm-up failure', () async {
    final prewarmer = ManualSeekPrewarmer(
      loadProfile: () async => _serverProfile(),
      warmSegment: (segment, profile) async {
        throw StateError('warm-up failed');
      },
      telemetry: _ThrowingTelemetry(),
    );

    await expectLater(prewarmer.warm(paragraph), completes);
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

final class _ThrowingTelemetry implements PlaybackTelemetry {
  @override
  void record(String name, [Map<String, Object?> fields = const {}]) {
    throw StateError('telemetry failed');
  }

  @override
  Future<void> flush() async {}
}
