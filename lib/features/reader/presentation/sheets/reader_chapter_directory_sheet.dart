import 'package:flutter/material.dart';
import 'package:novel_voice_reader/features/reader/domain/reader_content.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Shows the searchable chapter directory and resolves to the picked chapter
/// id, or null when the sheet is dismissed.
///
/// The list opens scrolled to [currentChapterId] so the reader lands on their
/// place instead of the top of a long book.
Future<int?> showChapterDirectorySheet({
  required BuildContext context,
  required List<ReaderChapter> chapters,
  required int? currentChapterId,
}) async {
  var query = '';
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        final normalizedQuery = query.trim().toLowerCase();
        final filteredChapters = chapters.where((chapter) {
          return chapter.title.toLowerCase().contains(normalizedQuery) ||
              '${chapter.index + 1}'.contains(normalizedQuery);
        }).toList();
        final currentChapterIndex = filteredChapters.indexWhere(
          (chapter) => chapter.id == currentChapterId,
        );

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    '章节目录',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜索章节',
                    ),
                    onChanged: (value) {
                      setSheetState(() => query = value);
                    },
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: filteredChapters.isEmpty
                      ? const Center(child: Text('没有匹配的章节'))
                      : PageStorage(
                          bucket: PageStorageBucket(),
                          child: ScrollablePositionedList.builder(
                            key: PageStorageKey<String>(
                              'chapter-directory-$query',
                            ),
                            initialScrollIndex:
                                (currentChapterIndex < 0 ||
                                    currentChapterIndex >=
                                        filteredChapters.length)
                                ? 0
                                : currentChapterIndex,
                            itemCount: filteredChapters.length,
                            itemBuilder: (context, index) {
                              final chapter = filteredChapters[index];
                              final selected = chapter.id == currentChapterId;
                              return ListTile(
                                title: Text(chapter.title),
                                leading: SizedBox(
                                  width: 32,
                                  child: Text('${chapter.index + 1}'),
                                ),
                                trailing: selected
                                    ? const Icon(Icons.check)
                                    : null,
                                selected: selected,
                                onTap: () =>
                                    Navigator.of(context).pop(chapter.id),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
