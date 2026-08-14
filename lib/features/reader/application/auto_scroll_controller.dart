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

  /// User-facing speed scale. The reader tunes an integer level in
  /// [minLevel]..[maxLevel]; it maps linearly onto [minSpeed]..[maxSpeed], so
  /// the exposed control is a free 1–100 dial rather than a few fixed presets.
  static const int minLevel = 1;
  static const int maxLevel = 100;

  final void Function(double offset, Duration duration) _onAdvance;

  Timer? _timer;
  AutoScrollStatus _status = AutoScrollStatus.idle;
  // While the reader is dragging, the crawl is suspended without leaving the
  // running state, so the toolbar still shows it as active and it resumes the
  // instant the gesture ends.
  bool _suspendedForGesture = false;
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

  /// The current speed as a user-facing level in [minLevel]..[maxLevel].
  int get speedLevel => _levelForSpeed(_speed);

  /// Sets the crawl speed from a user-facing level in [minLevel]..[maxLevel].
  set speedLevel(int level) {
    speed = _speedForLevel(level);
  }

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

  static double _speedForLevel(int level) {
    final clamped = level.clamp(minLevel, maxLevel);
    final t = (clamped - minLevel) / (maxLevel - minLevel);
    return minSpeed + t * (maxSpeed - minSpeed);
  }

  static int _levelForSpeed(double speed) {
    final t = (speed - minSpeed) / (maxSpeed - minSpeed);
    return (t * (maxLevel - minLevel)).round() + minLevel;
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
    if (_status == AutoScrollStatus.running && !_suspendedForGesture) {
      return;
    }
    _suspendedForGesture = false;
    _status = AutoScrollStatus.running;
    _armTimer();
    notifyListeners();
  }

  /// Halts the crawl but keeps it armed so [start] resumes from here.
  void pause() {
    if (_status != AutoScrollStatus.running) {
      return;
    }
    _suspendedForGesture = false;
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
    _suspendedForGesture = false;
    _status = AutoScrollStatus.idle;
    _disarmTimer();
    notifyListeners();
  }

  /// Called when the reader begins a manual swipe. While running, the crawl is
  /// suspended for the duration of the gesture so it does not fight the drag,
  /// but the running state is preserved — a manual scroll interrupts, it never
  /// exits auto scroll. Ignored while paused or idle.
  void notifyUserInteractionStart() {
    if (_status != AutoScrollStatus.running) {
      return;
    }
    _suspendedForGesture = true;
    _disarmTimer();
  }

  /// Called when a manual scroll (including any fling) settles. The crawl picks
  /// back up immediately, so letting go hands control straight back to the
  /// auto scroll.
  void notifyUserInteractionEnd() {
    if (!_suspendedForGesture) {
      return;
    }
    _suspendedForGesture = false;
    if (_status == AutoScrollStatus.running) {
      _armTimer();
    }
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
