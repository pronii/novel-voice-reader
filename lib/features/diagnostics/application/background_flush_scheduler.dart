import 'dart:async';

// The private fields are initialized from public named parameters, which cannot
// be `this._field` initializing formals (named params may not start with an
// underscore); the pass-through assignments are intended.
// ignore_for_file: prefer_initializing_formals

/// Drives telemetry uploads around app foreground/background transitions.
///
/// Lock-screen playback keeps producing diagnostics events, but iOS can suspend
/// the isolate at any time — after which nothing uploads. So this flushes
/// immediately on backgrounding and then on a fixed interval while backgrounded,
/// getting as many events as possible to the collector before a suspension, and
/// stops the pump once foregrounded (the next foreground/cold-start flush and
/// the monotonic-time gap cover the rest).
///
/// Extracted from the app widget so the timing can be exercised without pumping
/// the whole widget tree.
final class BackgroundFlushScheduler {
  BackgroundFlushScheduler({
    required Future<void> Function() flush,
    Duration interval = const Duration(seconds: 20),
  }) : _flush = flush,
       _interval = interval;

  final Future<void> Function() _flush;
  final Duration _interval;
  Timer? _timer;

  /// Foregrounded: stop the periodic pump and upload once.
  void onForeground() {
    _stop();
    unawaited(_flush());
  }

  /// Backgrounded (e.g. screen locked): upload now, then keep uploading on the
  /// interval until foregrounded. Idempotent across repeated background signals
  /// (iOS reports inactive then paused).
  void onBackground() {
    unawaited(_flush());
    _timer ??= Timer.periodic(_interval, (_) => unawaited(_flush()));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => _stop();
}
