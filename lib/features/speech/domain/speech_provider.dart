import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_timeline.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

abstract interface class SpeechProvider {
  Stream<SpeechEvent> get events;

  Future<void> prepare(SpeechSegment segment, VoiceProfile profile);

  Future<void> play();

  Future<void> pause();

  Future<void> resume();

  Future<void> stop();
}

abstract interface class DisposableSpeechProvider {
  Future<void> dispose();
}

abstract interface class AdjustableSpeechProvider {
  Future<void> setPlaybackSpeed(double speed);
}

abstract interface class PrefetchingSpeechProvider {
  Future<void> prefetch(SpeechSegment segment, VoiceProfile profile);
}

/// A provider that keeps a native playlist of prefetched segments and advances
/// through them by itself. When the segment the coordinator wants to play next
/// is already the one the native player has advanced to, prepare() (which may
/// hit the network) must be skipped — the audio is already playing from the
/// native queue. This is what keeps lock-screen playback continuous without a
/// per-segment Dart round-trip.
abstract interface class PlaylistSpeechProvider {
  /// The id of the segment the native player is currently playing, or null
  /// when nothing is loaded.
  String? get currentSegmentId;
}

/// A provider that can prepare a segment using only already-cached audio,
/// never reaching the network. Used while the screen is locked / the app is
/// backgrounded so a cache miss soft-pauses instead of failing with a banner.
abstract interface class CacheOnlySpeechProvider {
  /// Prepares [segment] only if its audio is already cached locally. Returns
  /// true when it was prepared and is ready to play, false on a cache miss.
  /// Never synthesizes over the network and never emits a [SpeechFailed] event.
  Future<bool> prepareCached(SpeechSegment segment, VoiceProfile profile);
}

abstract interface class TimedSpeechProvider {
  Stream<PlaybackTimeline> get playbackTimeline;
}

sealed class SpeechEvent {
  const SpeechEvent();
}

final class SpeechStarted extends SpeechEvent {
  const SpeechStarted({required this.segmentId});

  final String segmentId;
}

final class SpeechCompleted extends SpeechEvent {
  const SpeechCompleted({required this.segmentId});

  final String segmentId;
}

final class SpeechFailed extends SpeechEvent {
  const SpeechFailed({required this.segmentId, required this.failure});

  final String segmentId;
  final AppFailure failure;
}
