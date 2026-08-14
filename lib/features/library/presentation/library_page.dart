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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('声阅'),
            Text('书架', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '语音设置',
            onPressed: onOpenVoiceSettings,
            icon: const Icon(Icons.record_voice_over_outlined),
          ),
        ],
      ),
      body: _body(context),
      floatingActionButton: FloatingActionButton(
        tooltip: '导入小说',
        onPressed: loading ? null : onImport,
        child: const Icon(Icons.upload_file),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage case final message?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
    }
    if (books.isEmpty) {
      return const Center(child: Text('还没有导入小说'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: books.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final book = books[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          leading: Icon(
            Icons.menu_book_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(book.progressLabel),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onOpenCacheSettings != null)
                IconButton(
                  tooltip: '缓存设置',
                  onPressed: () => onOpenCacheSettings!(book.id),
                  icon: const Icon(Icons.offline_pin_outlined),
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: onOpenBook == null ? null : () => onOpenBook!(book.id),
        );
      },
    );
  }
}
