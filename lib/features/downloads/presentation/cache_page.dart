import 'dart:math';

import 'package:flutter/material.dart';
import 'package:novel_voice_reader/features/downloads/domain/download_policy.dart';

final class CachePage extends StatefulWidget {
  const CachePage({
    super.key,
    required this.chapterCount,
    required this.currentChapterIndex,
    required this.onApply,
    this.initialPolicy,
  });

  final int chapterCount;
  final int currentChapterIndex;
  final ValueChanged<DownloadPolicy> onApply;
  final DownloadPolicy? initialPolicy;

  @override
  State<CachePage> createState() => _CachePageState();
}

final class _CachePageState extends State<CachePage> {
  late final TextEditingController _chaptersController;
  late bool _wholeBook;
  late bool _wifiOnly;
  late int _maxCacheBytes;
  String? _errorText;

  int get _remainingChapters =>
      max(0, widget.chapterCount - widget.currentChapterIndex - 1);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPolicy;
    _wholeBook = initial?.wholeBook ?? false;
    _wifiOnly = initial?.wifiOnly ?? true;
    _maxCacheBytes = initial?.maxCacheBytes ?? 512 * 1024 * 1024;
    _chaptersController = TextEditingController(
      text: min(initial?.chaptersAhead ?? 3, _remainingChapters).toString(),
    )..addListener(_refreshSummary);
  }

  @override
  void dispose() {
    _chaptersController
      ..removeListener(_refreshSummary)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('缓存设置')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('下载范围', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            key: const Key('chaptersAhead'),
            controller: _chaptersController,
            enabled: !_wholeBook,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '后续章节数',
              helperText: '可选 0 - $_remainingChapters',
              errorText: _errorText,
            ),
          ),
          SwitchListTile(
            key: const Key('wholeBook'),
            contentPadding: EdgeInsets.zero,
            title: const Text('缓存所有未读章节'),
            value: _wholeBook,
            onChanged: (value) => setState(() => _wholeBook = value),
          ),
          const Divider(height: 32),
          Text('网络与容量', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('仅在 Wi-Fi 下下载'),
            value: _wifiOnly,
            onChanged: (value) => setState(() => _wifiOnly = value),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _maxCacheBytes,
            decoration: const InputDecoration(labelText: '缓存容量上限'),
            items: const [
              DropdownMenuItem(value: 256 * 1024 * 1024, child: Text('256 MB')),
              DropdownMenuItem(value: 512 * 1024 * 1024, child: Text('512 MB')),
              DropdownMenuItem(value: 1024 * 1024 * 1024, child: Text('1 GB')),
              DropdownMenuItem(
                value: 2 * 1024 * 1024 * 1024,
                child: Text('2 GB'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _maxCacheBytes = value);
              }
            },
          ),
          const SizedBox(height: 24),
          Text(
            _wholeBook
                ? '将缓存所有未读章节'
                : '将缓存当前章节及后续 ${_chaptersController.text} 章',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _apply,
            icon: const Icon(Icons.check),
            label: const Text('应用'),
          ),
        ],
      ),
    );
  }

  void _refreshSummary() {
    if (mounted) {
      setState(() => _errorText = null);
    }
  }

  void _apply() {
    final chaptersAhead = int.tryParse(_chaptersController.text);
    if (chaptersAhead == null ||
        chaptersAhead < 0 ||
        chaptersAhead > _remainingChapters) {
      setState(() => _errorText = '请输入 0 - $_remainingChapters');
      return;
    }
    widget.onApply(
      DownloadPolicy(
        chaptersAhead: chaptersAhead,
        wholeBook: _wholeBook,
        wifiOnly: _wifiOnly,
        maxCacheBytes: _maxCacheBytes,
      ),
    );
    FocusScope.of(context).unfocus();
  }
}
