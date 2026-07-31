import 'package:novel_voice_reader/core/errors/app_failure.dart';
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
