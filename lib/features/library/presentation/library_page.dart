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
    this.onOpenBook,
    this.onOpenVoiceSettings,
    this.onCheckUpdate,
    this.onOpenCacheSettings,
    this.themeMode,
    this.onCycleThemeMode,
    this.loading = false,
    this.errorMessage,
  });

  final List<LibraryBookItem> books;
  final Future<void> Function() onImport;
  final ValueChanged<int>? onOpenBook;
  final VoidCallback? onOpenVoiceSettings;
  final VoidCallback? onCheckUpdate;
  final ValueChanged<int>? onOpenCacheSettings;

  /// The current app theme mode. When supplied together with [onCycleThemeMode]
  /// a follow-system / light / dark toggle appears in the app bar. Both are null
  /// in widget tests that build [LibraryPage] without a Riverpod scope, in which
  /// case the toggle is simply hidden.
  final ThemeMode? themeMode;
  final VoidCallback? onCycleThemeMode;

  final bool loading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final mode = themeMode;
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
          if (mode != null && onCycleThemeMode != null)
            IconButton(
              tooltip: _themeTooltip(mode),
              onPressed: onCycleThemeMode,
              icon: Icon(_themeIcon(mode)),
            ),
          if (onCheckUpdate != null)
            IconButton(
              tooltip: '检查更新',
              onPressed: onCheckUpdate,
              icon: const Icon(Icons.system_update_alt_outlined),
            ),
          IconButton(
            tooltip: '语音设置',
            onPressed: onOpenVoiceSettings,
            icon: const Icon(Icons.record_voice_over_outlined),
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

  static IconData _themeIcon(ThemeMode mode) => switch (mode) {
    ThemeMode.system => Icons.brightness_auto_outlined,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
  };

  static String _themeTooltip(ThemeMode mode) => switch (mode) {
    ThemeMode.system => '主题：跟随系统',
    ThemeMode.light => '主题：浅色',
    ThemeMode.dark => '主题：深色',
  };

  Widget _body(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage case final message?) {
      return _CenteredNotice(icon: Icons.error_outline, title: message);
    }
    if (books.isEmpty) {
      return const _CenteredNotice(
        icon: Icons.auto_stories_outlined,
        title: '还没有导入小说',
        subtitle: '点击右下角的按钮，导入 TXT 或 EPUB 开始阅读',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Insets.page, Insets.md, Insets.page, 104),
      itemCount: books.length,
      separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
      itemBuilder: (context, index) => _BookCard(
        book: books[index],
        onOpenBook: onOpenBook,
        onOpenCacheSettings: onOpenCacheSettings,
      ),
    );
  }
}

/// Centered icon + message used for the empty and error states.
class _CenteredNotice extends StatelessWidget {
  const _CenteredNotice({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

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
            if (subtitle != null) ...[
              const SizedBox(height: Insets.sm),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single book row: generated cover, serif title, progress, and actions.
class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.onOpenBook,
    required this.onOpenCacheSettings,
  });

  final LibraryBookItem book;
  final ValueChanged<int>? onOpenBook;
  final ValueChanged<int>? onOpenCacheSettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final paper = context.paper;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenBook == null ? null : () => onOpenBook!(book.id),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: [
              BookCover(
                title: book.title,
                imagePath: book.coverImagePath,
                width: 56,
                height: 78,
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
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: Insets.sm),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_border, size: 15, color: paper.accent),
                        const SizedBox(width: Insets.xs),
                        Flexible(
                          child: Text(
                            book.progressLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              if (onOpenCacheSettings != null)
                IconButton(
                  tooltip: '缓存设置',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onOpenCacheSettings!(book.id),
                  icon: Icon(
                    Icons.offline_pin_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
