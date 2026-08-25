import '../../diagnostics/domain/playback_telemetry.dart';
import '../../downloads/data/audio_cache_repository.dart';
import '../../reader/domain/reader_content.dart';
import '../../speech/domain/speech_segmenter.dart';
import '../../speech/domain/voice_profile.dart';

typedef ManualSeekProfileLoader = Future<VoiceProfile> Function();
typedef ManualSeekSegmentWarmer =
    Future<AudioCacheObtainSource> Function(
      SpeechSegment segment,
      VoiceProfile profile,
    );

final class ManualSeekPrewarmer {
  const ManualSeekPrewarmer({
    required ManualSeekProfileLoader loadProfile,
    required ManualSeekSegmentWarmer warmSegment,
    PlaybackTelemetry telemetry = const NoopPlaybackTelemetry(),
    SpeechSegmenter segmenter = const SpeechSegmenter(),
    // Named parameters back private fields, so initializing formals don't apply.
    // ignore: prefer_initializing_formals
  }) : _loadProfile = loadProfile,
       // ignore: prefer_initializing_formals
       _warmSegment = warmSegment,
       // ignore: prefer_initializing_formals
       _telemetry = telemetry,
       // ignore: prefer_initializing_formals
       _segmenter = segmenter;

  final ManualSeekProfileLoader _loadProfile;
  final ManualSeekSegmentWarmer _warmSegment;
  final PlaybackTelemetry _telemetry;
  final SpeechSegmenter _segmenter;

  Future<void> warm(ReaderParagraph paragraph) async {
    final startedAt = Stopwatch()..start();
    _record('playback.manual_seek.warm.begin', paragraph);
    try {
      final profile = await _loadProfile();
      if (profile.providerType != SpeechProviderType.server) {
        _record('playback.manual_seek.warm.skipped', paragraph, {
          'reason': 'provider_not_server',
        });
        return;
      }
      final segments = _segmenter.split(
        paragraphId: paragraph.id,
        text: paragraph.text,
        maxCharacters: profile.maxSegmentCharacters,
      );
      if (segments.isEmpty) {
        _record('playback.manual_seek.warm.skipped', paragraph, {
          'reason': 'empty_text',
        });
        return;
      }
      final source = await _warmSegment(segments.first, profile);
      _record('playback.manual_seek.warm.success', paragraph, {
        'elapsed_ms': startedAt.elapsedMilliseconds,
        'source': source.name,
      });
    } catch (error) {
      _record('playback.manual_seek.warm.failure', paragraph, {
        'elapsed_ms': startedAt.elapsedMilliseconds,
        'error_type': error.runtimeType.toString(),
      });
    }
  }

  void _record(
    String name,
    ReaderParagraph paragraph, [
    Map<String, Object?> fields = const {},
  ]) {
    recordPlaybackTelemetrySafely(
      _telemetry,
      name,
      {
        'paragraph_id': paragraph.id,
        'chapter_id': paragraph.chapterId,
        'paragraph_index': paragraph.index,
        ...fields,
      },
    );
  }
}
