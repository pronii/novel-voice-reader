import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:novel_voice_reader/app/providers.dart';
import 'package:novel_voice_reader/app/router.dart';
import 'package:novel_voice_reader/app/theme.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_handler.dart';

final class NovelVoiceReaderApp extends StatefulWidget {
  const NovelVoiceReaderApp({super.key, this.database, this.playbackRuntime});

  final AppDatabase? database;
  final PlaybackRuntime? playbackRuntime;

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
    if (playbackRuntime != null) {
      unawaited(playbackRuntime.dispose());
    }
    final database = widget.database;
    if (database != null) {
      unawaited(database.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(widget.database),
        playbackRuntimeProvider.overrideWithValue(widget.playbackRuntime),
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
