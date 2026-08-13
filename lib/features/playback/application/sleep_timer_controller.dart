import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:novel_voice_reader/features/reader/domain/playback_cursor.dart';

/// The selectable sleep-timer options shown to the user.
enum SleepTimerPreset {
  min15(Duration(minutes: 15), '15 分钟'),
  min30(Duration(minutes: 30), '30 分钟'),
  min45(Duration(minutes: 45), '45 分钟'),
  min60(Duration(minutes: 60), '60 分钟'),
  endOfChapter(null, '本章播完后');

  const SleepTimerPreset(this.duration, this.label);

  /// The countdown length, or `null` for the "after this chapter" option.
  final Duration? duration;
  final String label;

  bool get isEndOfChapter => duration == null;
}

/// Drives a sleep timer that stops playback after a chosen duration or once the
/// current chapter finishes. It lives above any single page (via a Riverpod
/// provider) so the countdown keeps running while the user navigates away.
///
/// The controller depends only on lightweight callbacks so it can be unit
/// tested without constructing the whole playback runtime.
class SleepTimerController extends ChangeNotifier {
  SleepTimerController({
    required Future<void> Function() onExpire,
    required int? Function() currentChapterId,
    required Stream<PlaybackCursor?> Function() cursorChanges,
  }) : _onExpire = onExpire,
       _currentChapterId = currentChapterId,
       _cursorChanges = cursorChanges;

  final Future<void> Function() _onExpire;
  final int? Function() _currentChapterId;
  final Stream<PlaybackCursor?> Function() _cursorChanges;

  Timer? _fireTimer;
  Timer? _ticker;
  StreamSubscription<PlaybackCursor?>? _cursorSubscription;

  bool _active = false;
  bool _endOfChapter = false;
  Duration? _remaining;

  /// Whether a timer is currently armed.
  bool get isActive => _active;

  /// True when the armed timer stops at the end of the current chapter rather
  /// than after a fixed duration.
  bool get isEndOfChapter => _endOfChapter;

  /// The remaining time for a duration timer, or `null` for the
  /// end-of-chapter mode / when inactive.
  Duration? get remaining => _remaining;

  /// Arms a fixed-duration timer, replacing any existing one.
  void startDuration(Duration duration) {
    cancel(notify: false);
    if (duration <= Duration.zero) {
      notifyListeners();
      return;
    }
    _active = true;
    _endOfChapter = false;
    _remaining = duration;
    _fireTimer = Timer(duration, _expire);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = _remaining;
      if (current == null) return;
      final next = current - const Duration(seconds: 1);
      _remaining = next <= Duration.zero ? Duration.zero : next;
      notifyListeners();
    });
    notifyListeners();
  }

  /// Arms a timer that stops playback once the current chapter finishes.
  ///
  /// Returns `false` (and arms nothing) when nothing is playing, so the caller
  /// can prompt the user to start playback first.
  bool startEndOfChapter() {
    final chapterId = _currentChapterId();
    if (chapterId == null) {
      return false;
    }
    cancel(notify: false);
    _active = true;
    _endOfChapter = true;
    _remaining = null;
    _cursorSubscription = _cursorChanges().listen((cursor) {
      if (cursor == null) {
        // Playback stopped on its own (chapter/book ended or user stopped);
        // nothing left to stop.
        cancel();
        return;
      }
      if (cursor.chapterId != chapterId) {
        _expire();
      }
    });
    notifyListeners();
    return true;
  }

  Future<void> _expire() async {
    if (!_active) return;
    cancel();
    await _onExpire();
  }

  /// Cancels any armed timer and resets state.
  void cancel({bool notify = true}) {
    _fireTimer?.cancel();
    _fireTimer = null;
    _ticker?.cancel();
    _ticker = null;
    unawaited(_cursorSubscription?.cancel());
    _cursorSubscription = null;
    _active = false;
    _endOfChapter = false;
    _remaining = null;
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    cancel(notify: false);
    super.dispose();
  }
}
