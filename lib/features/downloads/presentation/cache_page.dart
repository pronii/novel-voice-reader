import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:novel_voice_reader/app/design/paper_tokens.dart';
import 'package:novel_voice_reader/app/widgets/section_card.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/features/downloads/domain/download_policy.dart';

final class CachePage extends StatefulWidget {
  const CachePage({
    super.key,
    required this.chapterCount,
    required this.currentChapterIndex,
    required this.onApply,
    this.initialPolicy,
    this.bookTitle,
    this.cachedBytes = 0,
    this.cachedSegmentCount = 0,
  });

  final int chapterCount;
  final int currentChapterIndex;
  final FutureOr<void> Function(DownloadPolicy) onApply;
  final DownloadPolicy? initialPolicy;
  final String? bookTitle;
  final int cachedBytes;
  final int cachedSegmentCount;

  @override
  State<CachePage> createState() => _CachePageState();
}

final class _CachePageState extends State<CachePage> {
  static const _cacheSizeOptions = <int>[
    256 * 1024 * 1024,
    512 * 1024 * 1024,
    1024 * 1024 * 1024,
    2 * 1024 * 1024 * 1024,
  ];

  late final TextEditingController _chaptersController;
  late bool _wholeBook;
  late bool _wifiOnly;
  late int _maxCacheBytes;
  String? _errorText;
  bool _applying = false;

  int get _remainingChapters =>
      max(0, widget.chapterCount - widget.currentChapterIndex - 1);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPolicy;
    _wholeBook = initial?.wholeBook ?? false;
    _wifiOnly = initial?.wifiOnly ?? true;
    final initialMaxCacheBytes =
        initial?.maxCacheBytes ?? DownloadPolicy.defaultMaxCacheBytes;
    _maxCacheBytes = _cacheSizeOptions.contains(initialMaxCacheBytes)
        ? initialMaxCacheBytes
        : DownloadPolicy.defaultMaxCacheBytes;
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('缓存设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.page,
          Insets.page,
          Insets.page,
          Insets.xxl,
        ),
        children: [
          if (widget.bookTitle case final title?) ...[
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: Insets.xl),
          ],
          SectionCard(
            title: '下载范围',
            caption: '选择随身携带多少后续内容，离线也能听。',
            children: [
              const SizedBox(height: Insets.sm),
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
            ],
          ),
          const SizedBox(height: Insets.xl),
          SectionCard(
            title: '网络与容量',
            children: [
              const SizedBox(height: Insets.sm),
              _usageStat(theme),
              const SizedBox(height: Insets.lg),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('仅在 Wi-Fi 下下载'),
                value: _wifiOnly,
                onChanged: (value) => setState(() => _wifiOnly = value),
              ),
              const SizedBox(height: Insets.md),
              DropdownButtonFormField<int>(
                initialValue: _maxCacheBytes,
                decoration: const InputDecoration(labelText: '缓存容量上限'),
                items: const [
                  DropdownMenuItem(
                    value: 256 * 1024 * 1024,
                    child: Text('256 MB'),
                  ),
                  DropdownMenuItem(
                    value: 512 * 1024 * 1024,
                    child: Text('512 MB'),
                  ),
                  DropdownMenuItem(
                    value: 1024 * 1024 * 1024,
                    child: Text('1 GB'),
                  ),
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
            ],
          ),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        summary: Text(
          _wholeBook
              ? '将缓存所有未读章节'
              : '将缓存当前章节及后续 ${_chaptersController.text} 章',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        action: FilledButton.icon(
          onPressed: _applying ? null : _apply,
          icon: const Icon(Icons.check),
          label: Text(_applying ? '应用中' : '应用'),
        ),
      ),
    );
  }

  Widget _usageStat(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前缓存',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_formatBytes(widget.cachedBytes)} · '
                '${widget.cachedSegmentCount} 段',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: min(1, widget.cachedBytes / _maxCacheBytes),
                  minHeight: 6,
                  color: context.paper.accent,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    const megabyte = 1024 * 1024;
    const gigabyte = 1024 * megabyte;
    if (bytes >= gigabyte) {
      return '${(bytes / gigabyte).toStringAsFixed(1)} GB';
    }
    return '${(bytes / megabyte).toStringAsFixed(1)} MB';
  }

  void _refreshSummary() {
    if (mounted) {
      setState(() => _errorText = null);
    }
  }

  Future<void> _apply() async {
    final chaptersAhead = int.tryParse(_chaptersController.text);
    if (chaptersAhead == null ||
        chaptersAhead < 0 ||
        chaptersAhead > _remainingChapters) {
      setState(() => _errorText = '请输入 0 - $_remainingChapters');
      return;
    }
    final policy = DownloadPolicy(
      chaptersAhead: chaptersAhead,
      wholeBook: _wholeBook,
      wifiOnly: _wifiOnly,
      maxCacheBytes: _maxCacheBytes,
    );
    FocusScope.of(context).unfocus();
    setState(() => _applying = true);
    try {
      await widget.onApply(policy);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('缓存任务已更新')));
      }
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('缓存设置应用失败')));
      }
    } finally {
      if (mounted) {
        setState(() => _applying = false);
      }
    }
  }
}
