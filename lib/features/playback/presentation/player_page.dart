import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:novel_voice_reader/app/design/paper_tokens.dart';
import 'package:novel_voice_reader/app/widgets/book_cover.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_timeline.dart';

final class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.bookTitle,
    required this.chapterTitle,
    this.onPrevious,
    this.onNext,
    this.onPlay,
    this.onPause,
    this.initialPlaying = false,
    this.playingChanges,
    this.initialTimeline = PlaybackTimeline.zero,
    this.timelineChanges,
    this.initialSpeed = 1,
    this.onSpeedChanged,
    this.actions = const <Widget>[],
  });

  final String bookTitle;
  final String chapterTitle;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final bool initialPlaying;
  final Stream<bool>? playingChanges;
  final PlaybackTimeline initialTimeline;
  final Stream<PlaybackTimeline>? timelineChanges;
  final double initialSpeed;
  final Future<void> Function(double speed)? onSpeedChanged;

  /// Extra AppBar actions (e.g. the sleep-timer button).
  final List<Widget> actions;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

final class _PlayerPageState extends State<PlayerPage> {
  late bool _playing;
  late PlaybackTimeline _timeline;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<PlaybackTimeline>? _timelineSubscription;
  late double _speed;
  Future<void> _speedChanges = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _playing = widget.initialPlaying;
    _timeline = widget.initialTimeline;
    _speed = widget.initialSpeed;
    _subscribeToPlayback();
  }

  @override
  void dispose() {
    unawaited(_playingSubscription?.cancel());
    unawaited(_timelineSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('播放器'), actions: widget.actions),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Size the cover to the screen so it reads as an immersive
            // now-playing hero, but cap it so the transport controls and speed
            // selector below always stay on-screen (and above the fold on the
            // 800x600 test surface). Scrolls only under extreme text scaling.
            final coverHeight = (constraints.maxHeight * 0.32).clamp(150.0, 240.0);
            final coverWidth = coverHeight * 0.72;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 44),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BookCover(
                      title: widget.bookTitle,
                      width: coverWidth,
                      height: coverHeight,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.bookTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.chapterTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildProgress(context),
                    const SizedBox(height: 28),
                    _buildTransport(context),
                    const SizedBox(height: 28),
                    SegmentedButton<double>(
                      segments: const [
                        ButtonSegment(value: 0.8, label: Text('0.8x')),
                        ButtonSegment(value: 1, label: Text('1.0x')),
                        ButtonSegment(value: 1.25, label: Text('1.25x')),
                        ButtonSegment(value: 1.5, label: Text('1.5x')),
                      ],
                      selected: {_speed},
                      onSelectionChanged: (values) {
                        _queueSpeedChange(values.single);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgress(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 6,
            color: context.paper.accent,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Text(_elapsedLabel, style: labelStyle)),
            Text(_remainingLabel, style: labelStyle),
          ],
        ),
      ],
    );
  }

  Widget _buildTransport(BuildContext context) {
    final paper = context.paper;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          tooltip: '上一段',
          iconSize: 32,
          onPressed: widget.onPrevious,
          icon: const Icon(Icons.skip_previous),
        ),
        IconButton.filled(
          tooltip: _playing ? '暂停' : '播放',
          iconSize: 40,
          onPressed: _togglePlayback,
          style: IconButton.styleFrom(
            backgroundColor: paper.accent,
            foregroundColor: paper.onAccent,
            minimumSize: const Size(72, 72),
          ),
          icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
        ),
        IconButton(
          tooltip: '下一段',
          iconSize: 32,
          onPressed: widget.onNext,
          icon: const Icon(Icons.skip_next),
        ),
      ],
    );
  }

  void _queueSpeedChange(double speed) {
    _speedChanges = _speedChanges.then((_) => _applySpeed(speed));
  }

  Future<void> _applySpeed(double speed) async {
    try {
      await widget.onSpeedChanged?.call(speed);
    } catch (_) {
      return;
    }
    if (mounted) {
      setState(() => _speed = speed);
    }
  }

  void _togglePlayback() {
    if (_playing) {
      widget.onPause?.call();
    } else {
      widget.onPlay?.call();
    }
  }

  void _subscribeToPlayback() {
    _playingSubscription = widget.playingChanges?.listen((playing) {
      if (mounted && playing != _playing) {
        setState(() => _playing = playing);
      }
    });
    _timelineSubscription = widget.timelineChanges?.listen((timeline) {
      if (mounted && timeline != _timeline) {
        setState(() => _timeline = timeline);
      }
    });
  }

  double? get _progress {
    // Prefer chapter-level progress so the bar reflects the whole chapter,
    // not the short current TTS segment.
    final elapsed = _timeline.chapterElapsed;
    final chapterRemaining = _timeline.chapterRemaining;
    if (elapsed != null && chapterRemaining != null) {
      final total = elapsed + chapterRemaining;
      if (total > Duration.zero) {
        return (elapsed.inMicroseconds / total.inMicroseconds).clamp(0, 1);
      }
    }
    final duration = _timeline.duration;
    if (duration == null || duration <= Duration.zero) return null;
    return (_timeline.position.inMicroseconds / duration.inMicroseconds).clamp(
      0,
      1,
    );
  }

  String get _elapsedLabel {
    final elapsed = _timeline.chapterElapsed;
    if (elapsed != null) {
      final adjusted = Duration(
        microseconds: (max(0, elapsed.inMicroseconds) / _speed).round(),
      );
      return '已听 ${_formatDuration(adjusted)}';
    }
    final duration = _timeline.duration;
    if (duration == null || duration <= Duration.zero) return '已听 --:--';
    return '已听 ${_formatDuration(_timeline.position)}';
  }

  String get _remainingLabel {
    final duration = _timeline.duration;
    final chapterRemaining = _timeline.chapterRemaining;
    if (chapterRemaining == null &&
        (duration == null || duration <= Duration.zero)) {
      return '本章剩余 --:--';
    }
    final remaining = chapterRemaining ?? duration! - _timeline.position;
    final adjusted = Duration(
      microseconds: (max(0, remaining.inMicroseconds) / _speed).round(),
    );
    return '本章剩余 ${_formatDuration(adjusted)}';
  }

  static String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 359999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
