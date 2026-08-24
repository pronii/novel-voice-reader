import 'package:flutter/material.dart';

final class LibraryBookItem {
  const LibraryBookItem({
    required this.id,
    required this.title,
    required this.progressLabel,
  });

  final int id;
  final String title;
  final String progressLabel;
}

/// 木质书架样式的书库主页。
///
/// 视觉还原自设计稿：胡桃木渐变柜体 + 多层横向隔板 + 错落书脊排列，
/// 每本书是独立书脊卡片，书脊下方展示阅读进度；书架末尾保留一个
/// 「加号书」占位用于导入新书（替代原悬浮按钮）。
final class LibraryPage extends StatelessWidget {
  const LibraryPage({
    super.key,
    required this.books,
    required this.onImport,
    this.onOpenBook,
    this.onOpenVoiceSettings,
    this.onOpenCacheSettings,
    this.loading = false,
    this.errorMessage,
  });

  final List<LibraryBookItem> books;
  final Future<void> Function() onImport;
  final ValueChanged<int>? onOpenBook;
  final VoidCallback? onOpenVoiceSettings;
  final ValueChanged<int>? onOpenCacheSettings;
  final bool loading;
  final String? errorMessage;

  /// 每层书架最多摆放的书籍数量（与设计稿一致，窄屏 5 本）。
  static const _booksPerShelf = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E6),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              bookCount: books.length,
              onOpenVoiceSettings: onOpenVoiceSettings,
            ),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (loading) {
      return const _WoodShelf(
        child: Center(child: CircularProgressIndicator(color: Color(0xFFE8D9B8))),
      );
    }
    if (errorMessage case final message?) {
      return _WoodShelf(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFE8D9B8)),
            ),
          ),
        ),
      );
    }
    if (books.isEmpty) {
      return _WoodShelf(
        child: Center(
          child: _EmptyShelf(onImport: onImport),
        ),
      );
    }
    final shelves = <List<LibraryBookItem>>[];
    for (var i = 0; i < books.length; i += _booksPerShelf) {
      final end = (i + _booksPerShelf) > books.length
          ? books.length
          : i + _booksPerShelf;
      shelves.add(books.sublist(i, end));
    }
    return _WoodShelf(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 26),
        children: [
          for (var i = 0; i < shelves.length; i++) ...[
            _ShelfRow(
              books: shelves[i],
              isLastRow: i == shelves.length - 1,
              onOpenBook: onOpenBook,
              onOpenCacheSettings: onOpenCacheSettings,
              onImport: onImport,
            ),
            const _ShelfBoard(),
          ],
        ],
      ),
    );
  }
}

/// 顶部工具栏：标题 + 统计 + 语音设置入口。
final class _Header extends StatelessWidget {
  const _Header({required this.bookCount, this.onOpenVoiceSettings});

  final int bookCount;
  final VoidCallback? onOpenVoiceSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '我的书架',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3B3226),
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '共 $bookCount 本书 · 持续更新中',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A7D6A),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '语音设置',
            onPressed: onOpenVoiceSettings,
            icon: const Icon(
              Icons.record_voice_over_outlined,
              color: Color(0xFF3B3226),
            ),
          ),
        ],
      ),
    );
  }
}

/// 胡桃木渐变柜体容器：圆角 + 内阴影营造真实柜体深度。
final class _WoodShelf extends StatelessWidget {
  const _WoodShelf({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 6, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF78603F), Color(0xFF5C4430)],
        ),
        border: Border.all(color: const Color(0xFF47341F), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x593B2C1A),
            offset: Offset(0, 6),
            blurRadius: 24,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// 一层书架：书籍横排，书脊底部对齐隔板；最后一层末尾追加「加号书」。
final class _ShelfRow extends StatelessWidget {
  const _ShelfRow({
    required this.books,
    required this.isLastRow,
    this.onOpenBook,
    this.onOpenCacheSettings,
    this.onImport,
  });

  final List<LibraryBookItem> books;
  final bool isLastRow;
  final ValueChanged<int>? onOpenBook;
  final ValueChanged<int>? onOpenCacheSettings;
  final Future<void> Function()? onImport;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final book in books) ...[
            _BookSpine(
              book: book,
              onTap: onOpenBook == null ? null : () => onOpenBook!(book.id),
              onLongPress: onOpenCacheSettings == null
                  ? null
                  : () => onOpenCacheSettings!(book.id),
            ),
            const SizedBox(width: 10),
          ],
          if (isLastRow)
            _AddBookPlaceholder(onImport: onImport),
        ],
      ),
    );
  }
}

/// 书脊卡片：基于书籍 ID 稳定生成高度与颜色，形成错落有致的书架效果。
final class _BookSpine extends StatelessWidget {
  const _BookSpine({
    required this.book,
    this.onTap,
    this.onLongPress,
  });

  final LibraryBookItem book;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  static const _heights = <double>[
    128, 150, 172, 138, 158, 120, 176, 132, 164, 144, 180, 124,
  ];

  static const _colors = <Color>[
    Color(0xFFD9663D),
    Color(0xFF5B7B9A),
    Color(0xFF4A6B5A),
    Color(0xFFD9A441),
    Color(0xFF7A3B3B),
    Color(0xFFC4623A),
    Color(0xFF3E5C76),
    Color(0xFF5E4B6E),
    Color(0xFF6B8E7A),
    Color(0xFF8A6B4B),
  ];

  @override
  Widget build(BuildContext context) {
    final seed = book.id.abs();
    final height = _heights[seed % _heights.length];
    final baseColor = _colors[seed % _colors.length];
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 52,
        height: height,
        padding: const EdgeInsets.fromLTRB(3, 10, 3, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color.lerp(baseColor, Colors.white, 0.18)!,
              baseColor,
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              offset: Offset(2, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFFF8EC),
                height: 1.2,
              ),
            ),
            Text(
              book.progressLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 8,
                color: Color(0xCCFFF8EC),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 书架末尾的「加号书」占位：点击导入新书。
final class _AddBookPlaceholder extends StatelessWidget {
  const _AddBookPlaceholder({this.onImport});

  final Future<void> Function()? onImport;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onImport,
      child: Container(
        width: 46,
        height: 156,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: const Color(0x14FFF8EC),
          border: Border.all(color: const Color(0x59E8D9B8), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_circle_outline,
              size: 26,
              color: Color(0xFFE8D9B8),
            ),
            const SizedBox(height: 6),
            Text(
              '添加书籍',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFE8D9B8).withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 横向隔板：分隔书层的木条，带底部投影。
final class _ShelfBoard extends StatelessWidget {
  const _ShelfBoard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      margin: const EdgeInsets.only(top: 14, bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: const LinearGradient(
          colors: [Color(0xFF947447), Color(0xFF6B4F33)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

/// 空书架状态：引导用户导入第一本书。
final class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.onImport});

  final Future<void> Function() onImport;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.menu_book_outlined,
          size: 56,
          color: Color(0x66FFF8EC),
        ),
        const SizedBox(height: 12),
        const Text(
          '还没有导入小说',
          style: TextStyle(fontSize: 15, color: Color(0xB3FFF8EC)),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('导入第一本书'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3B2B18),
            foregroundColor: const Color(0xFFF5EFE4),
          ),
        ),
      ],
    );
  }
}
