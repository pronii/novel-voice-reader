import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:novel_voice_reader/app/providers.dart';
import 'package:novel_voice_reader/app/router.dart';
import 'package:novel_voice_reader/app/theme.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/downloads/application/audio_cache_runtime.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_handler.dart';

final class NovelVoiceReaderApp extends StatefulWidget {
  const NovelVoiceReaderApp({
    super.key,
    this.database,
    this.playbackRuntime,
    this.audioCacheRuntime,
  });

  final AppDatabase? database;
  final PlaybackRuntime? playbackRuntime;
  final AudioCacheRuntime? audioCacheRuntime;

  @override
  State<NovelVoiceReaderApp> createState() => _NovelVoiceReaderAppState();
}

final class _NovelVoiceReaderAppState extends State<NovelVoiceReaderApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter();
  }

  @override
  void dispose() {
    _router.dispose();
    final playbackRuntime = widget.playbackRuntime;
    final audioCacheRuntime = widget.audioCacheRuntime;
    final database = widget.database;
    unawaited(() async {
      await playbackRuntime?.dispose();
      await audioCacheRuntime?.dispose();
      await database?.close();
    }());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(widget.database),
        playbackRuntimeProvider.overrideWithValue(widget.playbackRuntime),
        audioCacheRuntimeProvider.overrideWithValue(widget.audioCacheRuntime),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: '声阅',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }
}
