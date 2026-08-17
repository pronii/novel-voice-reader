import 'dart:convert';

/// A single diagnostic event captured somewhere in the background-playback
/// chain (audio session, keep-alive loop, media handler, app lifecycle).
///
/// Events are cheap value objects: the capture site only supplies a [name] and
/// a small map of [fields]; the sequence number, monotonic timestamp, and wall
/// clock are stamped by the [PlaybackTelemetry] implementation so every event
/// is ordered and time-aligned without the call sites having to care.
final class PlaybackTelemetryEvent {
  const PlaybackTelemetryEvent({
    required this.seq,
    required this.monotonicMicros,
    required this.wallClock,
    required this.name,
    this.fields = const <String, Object?>{},
  });

  /// Process-monotonic sequence number. Gaps never happen; a jump in
  /// [monotonicMicros] between consecutive [seq] values is the fingerprint of
  /// the isolate having been suspended by the OS.
  final int seq;

  /// Microseconds elapsed on a process-level [Stopwatch]. Unlike [wallClock]
  /// this cannot move backwards when the system clock is adjusted, so it is the
  /// reliable measure of how long a gap between events really was.
  final int monotonicMicros;

  /// Wall-clock capture time (UTC). Human-readable, but only trustworthy
  /// relative to [monotonicMicros].
  final DateTime wallClock;

  /// Short, stable event identifier, e.g. `keepalive.recover.begin`.
  final String name;

  /// Event-specific structured payload. Must contain only diagnostic metadata —
  /// never book text, TTS input, or secrets.
  final Map<String, Object?> fields;

  Map<String, Object?> toJson() => <String, Object?>{
    'seq': seq,
    'mono_us': monotonicMicros,
    'ts': wallClock.toIso8601String(),
    'name': name,
    if (fields.isNotEmpty) 'fields': fields,
  };

  String toJsonLine() => jsonEncode(toJson());
}

/// Sink for background-playback diagnostics.
///
/// Implementations must be fire-and-forget safe: [record] never throws and does
/// no blocking work on the caller's turn, and [flush] swallows all errors. The
/// playback chain calls these on its hot paths, so telemetry must never be able
/// to disrupt playback.
abstract interface class PlaybackTelemetry {
  /// Captures an event. Returns immediately; persistence happens off the
  /// caller's synchronous path.
  void record(String name, [Map<String, Object?> fields]);

  /// Attempts to ship any buffered events to the configured destination.
  /// Safe to call opportunistically (app launch, returning to foreground);
  /// a no-op when nothing is buffered or no destination is configured.
  Future<void> flush();
}

/// A [PlaybackTelemetry] that discards everything. The default wherever
/// telemetry is optional, so instrumentation adds no behaviour unless a real
/// implementation is injected (and keeps existing tests unaffected).
final class NoopPlaybackTelemetry implements PlaybackTelemetry {
  const NoopPlaybackTelemetry();

  @override
  void record(String name, [Map<String, Object?> fields = const {}]) {}

  @override
  Future<void> flush() async {}
}
