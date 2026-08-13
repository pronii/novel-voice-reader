import 'dart:async';

import 'package:flutter/foundation.dart';

/// The lifecycle of the reader's automatic page scroll.
enum AutoScrollStatus {
  /// Not scrolling; no timer armed.
  idle,

  /// Actively advancing the page on every tick.
  running,

  /// Temporarily halted but remembered, so it can resume where it stopped.
  paused,
}

/// The coarse speed labels shown next to the fine-grained speed slider, so the
/// user gets a sense of "slow / medium / fast" while still tuning continuously.
enum AutoScrollSpeedBand {
  slow('慢'),
  medium('中'),
  fast('快');

  const AutoScrollSpeedBand(this.label);

  final String label;
}

/// Drives the reader's "auto scroll" feature: on a fixed tick it asks the page
/// to advance by a small pixel offset, producing a steady downward crawl the
/// user does not have to swipe.
///
/// The controller owns only timing and speed state; it never touches the scroll
/// view directly. Instead it calls [onAdvance] with the pixel offset to cover
/// and the tick duration, so the widget can forward that to whatever scroll
/// mechanism it uses. This keeps the controller unit-testable without a widget
/// tree (mirroring [SleepTimerController]).
class AutoScrollController extends ChangeNotifier {
  AutoScrollController({
    required void Function(double offset, Duration duration) onAdvance,
    double? initialSpeed,
    // Named param backs a private field, so an initializing formal won't apply.
    // ignore: prefer_initializing_formals
  }) : _onAdvance = onAdvance,
       _speed = _clampSpeed(initialSpeed ?? defaultSpeed);

  /// How often the page is nudged forward. A short tick keeps the motion
  /// visually smooth while staying cheap enough for a reading crawl.
  static const Duration tick = Duration(milliseconds: 50);

  /// Speed bounds in logical pixels per second.
  static const double minSpeed = 10;
  static const double maxSpeed = 150;
  static const double defaultSpeed = 45;

  final void Function(double offset, Duration duration) _onAdvance;

  Timer? _timer;
  AutoScrollStatus _status = AutoScrollStatus.idle;
  double _speed;

  /// The current lifecycle state.
  AutoScrollStatus get status => _status;

  /// Whether the page is being advanced right now.
  bool get isRunning => _status == AutoScrollStatus.running;

  /// True when scrolling is armed but temporarily halted.
  bool get isPaused => _status == AutoScrollStatus.paused;

  /// Scroll speed in logical pixels per second, always within
  /// [minSpeed]..[maxSpeed].
  double get speed => _speed;

  /// A coarse band derived from [speed], used for the "慢/中/快" label.
  AutoScrollSpeedBand get speedBand {
    const third = (maxSpeed - minSpeed) / 3;
    if (_speed <= minSpeed + third) {
      return AutoScrollSpeedBand.slow;
    }
    if (_speed <= minSpeed + third * 2) {
      return AutoScrollSpeedBand.medium;
    }
    return AutoScrollSpeedBand.fast;
  }

  /// Updates the crawl speed. Takes effect immediately: the running timer reads
  /// [_speed] on its next tick, so there is no need to restart it.
  set speed(double value) {
    final next = _clampSpeed(value);
    if (next == _speed) {
      return;
    }
    _speed = next;
    notifyListeners();
  }

  /// Starts (or resumes) the downward crawl. No-op if already running.
  void start() {
    if (_status == AutoScrollStatus.running) {
      return;
    }
    _status = AutoScrollStatus.running;
    _armTimer();
    notifyListeners();
  }

  /// Halts the crawl but keeps it armed so [start] resumes from here.
  void pause() {
    if (_status != AutoScrollStatus.running) {
      return;
    }
    _status = AutoScrollStatus.paused;
    _disarmTimer();
    notifyListeners();
  }

  /// Toggles between running and paused. Starting from [AutoScrollStatus.idle]
  /// begins scrolling.
  void toggle() {
    if (_status == AutoScrollStatus.running) {
      pause();
    } else {
      start();
    }
  }

  /// Stops the crawl entirely and forgets it, returning to
  /// [AutoScrollStatus.idle].
  void stop() {
    if (_status == AutoScrollStatus.idle) {
      return;
    }
    _status = AutoScrollStatus.idle;
    _disarmTimer();
    notifyListeners();
  }

  void _armTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(tick, (_) {
      final offset =
          _speed * tick.inMilliseconds / Duration.millisecondsPerSecond;
      _onAdvance(offset, tick);
    });
  }

  void _disarmTimer() {
    _timer?.cancel();
    _timer = null;
  }

  static double _clampSpeed(double value) => value.clamp(minSpeed, maxSpeed);

  @override
  void dispose() {
    _disarmTimer();
    super.dispose();
  }
}
