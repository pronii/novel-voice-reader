import 'dart:async';

import 'package:flutter/material.dart';
import 'package:novel_voice_reader/app/design/paper_tokens.dart';
import 'package:novel_voice_reader/app/widgets/book_cover.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_progress.dart';
import 'package:novel_voice_reader/features/playback/domain/playback_timeline.dart';

final class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.bookTitle,
    this.bookCoverPath,
    this.heroTag,
    this.paragraphText,
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

  /// Local path of a fetched cover image, or null to show a generated cover.
  final String? bookCoverPath;

  /// Shared-element tag matching the shelf's hero cover, so the artwork flies
  /// into the player on open. Null skips the Hero (e.g. pushed from the
  /// reader, which has no matching tag).
  final String? heroTag;

  /// Text of the paragraph narration is currently on, or null when playback
  /// is not active; shown as the "正在朗读" quote card between the titles and
  /// the progress bar.
  final String? paragraphText;

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
            final progress = PlaybackProgress.of(_timeline, speed: _speed);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 44),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCover(coverWidth, coverHeight),
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
                    if (widget.paragraphText
                        case final text? when text.trim().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _NowReadingCard(text: text),
                    ],
                    const SizedBox(height: 28),
                    _buildProgress(context, progress),
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

  Widget _buildCover(double coverWidth, double coverHeight) {
    final cover = BookCover(
      title: widget.bookTitle,
      imagePath: widget.bookCoverPath,
      width: coverWidth,
      height: coverHeight,
    );
    final tag = widget.heroTag;
    return tag == null ? cover : Hero(tag: tag, child: cover);
  }

  Widget _buildProgress(BuildContext context, PlaybackProgress progress) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.value,
            minHeight: 6,
            color: context.paper.accent,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Text(progress.elapsedLabel, style: labelStyle)),
            Text(progress.remainingLabel, style: labelStyle),
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

}

/// The "正在朗读" quote card: a paper block with an accent rule and the current
/// paragraph in serif, fading between paragraphs so progress is visible even
/// with the screen off-and-on glanceable.
class _NowReadingCard extends StatelessWidget {
  const _NowReadingCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final paper = context.paper;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: Insets.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                margin: const EdgeInsets.only(top: 2, bottom: 2, right: 12),
                decoration: BoxDecoration(
                  color: paper.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '正在朗读',
                      style: textTheme.labelSmall?.copyWith(
                        color: paper.accent,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Keyed on the text so a new paragraph fades in; the
                    // AnimatedSize above absorbs the height change.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                      child: Text(
                        text,
                        key: ValueKey<String>(text),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          fontFamily: PaperFonts.serif,
                          height: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
