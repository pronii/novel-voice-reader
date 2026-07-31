import 'package:flutter/material.dart';

final class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.bookTitle,
    required this.chapterTitle,
    this.onPrevious,
    this.onNext,
    this.onPlay,
    this.onPause,
  });

  final String bookTitle;
  final String chapterTitle;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

final class _PlayerPageState extends State<PlayerPage> {
  bool _playing = false;
  double _speed = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('播放器')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                Icons.auto_stories,
                size: 88,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 28),
              Text(
                widget.bookTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(widget.chapterTitle, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              const LinearProgressIndicator(value: 0),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: '上一段',
                    onPressed: widget.onPrevious,
                    icon: const Icon(Icons.skip_previous),
                  ),
                  IconButton.filled(
                    tooltip: _playing ? '暂停' : '播放',
                    iconSize: 36,
                    onPressed: _togglePlayback,
                    icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                  ),
                  IconButton(
                    tooltip: '下一段',
                    onPressed: widget.onNext,
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
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
                  setState(() => _speed = values.single);
                },
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  void _togglePlayback() {
    setState(() => _playing = !_playing);
    if (_playing) {
      widget.onPlay?.call();
    } else {
      widget.onPause?.call();
    }
  }
}
