import 'package:flutter/material.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_content.dart';

/// A chapter title at the head of its section, plus a notice when the chapter
/// turned out to have no readable body.
class ReaderChapterHeading extends StatelessWidget {
  const ReaderChapterHeading({
    super.key,
    required this.chapter,
    required this.isEmpty,
  });

  final ReaderChapter chapter;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey<String>('chapter-heading-${chapter.id}'),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(chapter.title, style: Theme.of(context).textTheme.headlineSmall),
          if (isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24, bottom: 12),
              child: Center(child: Text('本章没有可朗读内容')),
            ),
        ],
      ),
    );
  }
}
