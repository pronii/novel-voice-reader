import 'package:flutter/material.dart';
import 'package:novel_voice_reader/app/design/paper_tokens.dart';
import 'package:novel_voice_reader/app/widgets/book_cover.dart';

final class LibraryBookItem {
  const LibraryBookItem({
    required this.id,
    required this.title,
    required this.progressLabel,
    this.coverImagePath,
  });

  final int id;
  final String title;
  final String progressLabel;

  /// Local path of a fetched cover image, or null to show a generated cover.
  final String? coverImagePath;
}

final class LibraryPage extends StatelessWidget {
  const LibraryPage({
    super.key,
    required this.books,
    required this.onImport,
    this.continueBook,
    this.continueProgress,
    this.onOpenBook,
    this.onListenBook,
    this.onOpenCacheSettings,
    this.onOpenSettings,
    this.loading = false,
    this.errorMessage,
  });

  final List<LibraryBookItem> books;

  /// The most recently read book, shown as the "continue reading" hero card.
  /// Null on a fresh shelf, while loading, or when nothing has been opened yet.
  final LibraryBookItem? continueBook;

  /// 0..1 chapter progress of [continueBook], or null when unknown; drives the
  /// thin progress bar on the hero card.
  final double? continueProgress;

  final Future<void> Function() onImport;
  final ValueChanged<int>? onOpenBook;

  /// Opens the player for a book straight from the hero card ("继续听").
  final ValueChanged<int>? onListenBook;
  final ValueChanged<int>? onOpenCacheSettings;

  /// Opens the unified settings screen; the app bar shows a single entry
  /// instead of a row of icon-only actions.
  final VoidCallback? onOpenSettings;

  final bool loading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: Insets.page,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '声阅',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              '书架',
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        actions: [
          if (onOpenSettings != null)
            IconButton(
              tooltip: '设置',
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          const SizedBox(width: Insets.xs),
        ],
      ),
      body: _body(context),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: '导入小说',
        onPressed: loading ? null : onImport,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('导入'),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage case final message?) {
      return _CenteredNotice(icon: Icons.error_outline, title: message);
    }
    // The featured continue-reading book is excluded from the grid, so an
    // empty grid alone does not mean an empty shelf.
    if (books.isEmpty && continueBook == null) {
      return _EmptyShelf(onImport: onImport);
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            Insets.page,
            Insets.md,
            Insets.page,
            104,
          ),
          sliver: SliverMainAxisGroup(
            slivers: [
              if (continueBook case final book?)
                SliverToBoxAdapter(
                  child: _ContinueReadingCard(
                    book: book,
                    progress: continueProgress,
                    onOpenBook: onOpenBook,
                    onListenBook: onListenBook,
                  ),
                ),
              if (books.isNotEmpty)
                ...[
                  SliverToBoxAdapter(
                    child: _ShelfHeader(count: books.length),
                  ),
                  SliverGrid(
                    gridDelegate: _shelfDelegate(context),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final book = books[index];
                      return _BookCell(
                        book: book,
                        onOpenBook: onOpenBook,
                        onOpenCacheSettings: onOpenCacheSettings,
                      );
                    }, childCount: books.length),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }

  /// Shelf cells keep the cover in an Expanded area and give the text block a
  /// fixed allowance, so growing text scale pushes covers shorter instead of
  /// overflowing. [textExtent] must stay in sync with [_BookCell]'s block.
  SliverGridDelegateWithMaxCrossAxisExtent _shelfDelegate(
    BuildContext context,
  ) {
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 190,
      mainAxisSpacing: Insets.md,
      crossAxisSpacing: Insets.md,
      mainAxisExtent: 148 + _textExtent(context),
    );
  }
}

/// Reserved height of a shelf cell's text block: up to two title lines, a
/// fixed gap, and a progress row whose height is the larger of the label line
/// and the compact cache button.
double _textExtent(BuildContext context) {
  final scaler = MediaQuery.textScalerOf(context);
  final titleLines = scaler.scale(17) * 1.35 * 2;
  final progressRow = _progressRowExtent(scaler);
  return titleLines + 6 + progressRow + Insets.lg;
}

double _progressRowExtent(TextScaler scaler) =>
    scaler.scale(12.5) * 1.45 < 34 ? 34 : scaler.scale(12.5) * 1.45;

/// The "继续阅读" hero: a wide paper card with the book's cover, serif title,
/// real chapter progress and a one-tap listen button, so the shelf opens with
/// an answer to "刚才读到哪了" instead of a flat list.
class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({
    required this.book,
    required this.progress,
    this.onOpenBook,
    this.onListenBook,
  });

  final LibraryBookItem book;
  final double? progress;
  final ValueChanged<int>? onOpenBook;
  final ValueChanged<int>? onListenBook;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final paper = context.paper;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.bookmark, size: 14, color: paper.accent),
            const SizedBox(width: Insets.xs),
            Text(
              '继续阅读',
              style: textTheme.labelMedium?.copyWith(
                color: paper.accent,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpenBook == null ? null : () => onOpenBook!(book.id),
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Row(
                children: [
                  Hero(
                    tag: 'book-cover-${book.id}',
                    child: BookCover(
                      title: book.title,
                      imagePath: book.coverImagePath,
                      width: 84,
                      height: 118,
                    ),
                  ),
                  const SizedBox(width: Insets.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleLarge,
                        ),
                        const SizedBox(height: Insets.sm),
                        Text(
                          book.progressLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (progress case final value?) ...[
                          const SizedBox(height: Insets.md),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: value.clamp(0.0, 1.0),
                              minHeight: 4,
                              color: paper.accent,
                              backgroundColor:
                                  scheme.surfaceContainerHighest,
                            ),
                          ),
                        ],
                        const SizedBox(height: Insets.md),
                        FilledButton.tonalIcon(
                          onPressed: onListenBook == null
                              ? null
                              : () => onListenBook!(book.id),
                          icon: const Icon(Icons.graphic_eq, size: 18),
                          label: const Text('继续听'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "全部藏书" section header between the hero card and the grid.
class _ShelfHeader extends StatelessWidget {
  const _ShelfHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.xl, bottom: Insets.md),
      child: Row(
        children: [
          Expanded(
            child: Text('全部藏书', style: textTheme.titleSmall),
          ),
          Text(
            '$count 本',
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One shelf cell: the cover fills the space above the text block, so larger
/// text scales shrink the cover instead of clipping words. The text block's
/// height budget lives in [_textExtent].
class _BookCell extends StatelessWidget {
  const _BookCell({
    required this.book,
    this.onOpenBook,
    this.onOpenCacheSettings,
  });

  final LibraryBookItem book;
  final ValueChanged<int>? onOpenBook;
  final ValueChanged<int>? onOpenCacheSettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenBook == null ? null : () => onOpenBook!(book.id),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Keep the cover's ~0.72 book aspect while fitting the free
                  // box; a little breathing room keeps rows from touching.
                  final height = (constraints.maxHeight - Insets.md).clamp(
                    72.0,
                    168.0,
                  );
                  final width = (height * 0.72).clamp(
                    0.0,
                    constraints.maxWidth - Insets.lg,
                  );
                  return Center(
                    child: BookCover(
                      title: book.title,
                      imagePath: book.coverImagePath,
                      width: width,
                      height: height,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: _progressRowExtent(
                      MediaQuery.textScalerOf(context),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            book.progressLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (onOpenCacheSettings != null)
                          IconButton(
                            tooltip: '缓存设置',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 34,
                              minHeight: 34,
                            ),
                            onPressed: () =>
                                onOpenCacheSettings!(book.id),
                            icon: Icon(
                              Icons.offline_pin_outlined,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty shelf: a small trio of generated "spines" plus an inline import
/// button, so the first launch reads as an invitation rather than a blank list.
class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.onImport});

  final Future<void> Function() onImport;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 132,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.rotate(
                    angle: -0.12,
                    child: const BookCover(title: '山', width: 76, height: 108),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: Transform.rotate(
                      angle: 0.02,
                      child: const BookCover(title: '海', width: 84, height: 120),
                    ),
                  ),
                  Transform.rotate(
                    angle: 0.12,
                    child: const BookCover(title: '月', width: 76, height: 108),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),
            Text('还没有导入小说', textAlign: TextAlign.center, style: textTheme.titleMedium),
            const SizedBox(height: Insets.sm),
            Text(
              '导入 TXT 或 EPUB，开始你的第一本书',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.xl),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('选择文件导入'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered icon + message used for the error state.
class _CenteredNotice extends StatelessWidget {
  const _CenteredNotice({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: Insets.lg),
            Text(title, textAlign: TextAlign.center, style: textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
