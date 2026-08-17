import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:novel_voice_reader/app/providers.dart';
import 'package:novel_voice_reader/app/router.dart';
import 'package:novel_voice_reader/app/theme.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/diagnostics/domain/playback_telemetry.dart';
import 'package:novel_voice_reader/features/downloads/application/audio_cache_runtime.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_handler.dart';

final class NovelVoiceReaderApp extends StatefulWidget {
  const NovelVoiceReaderApp({
    super.key,
    this.database,
    this.playbackRuntime,
    this.audioCacheRuntime,
    this.telemetry = const NoopPlaybackTelemetry(),
  });

  final AppDatabase? database;
  final PlaybackRuntime? playbackRuntime;
  final AudioCacheRuntime? audioCacheRuntime;
  final PlaybackTelemetry telemetry;

  @override
  State<NovelVoiceReaderApp> createState() => _NovelVoiceReaderAppState();
}

final class _NovelVoiceReaderAppState extends State<NovelVoiceReaderApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter();
    WidgetsBinding.instance.addObserver(this);
    // Seed the current lifecycle state so a runtime created while the app is
    // already backgrounded starts in cache-first mode.
    final initial = WidgetsBinding.instance.lifecycleState;
    if (initial != null) {
      widget.playbackRuntime?.setForeground(initial == AppLifecycleState.resumed);
    }
    // Ship anything buffered by a previous (possibly suspended) run.
    unawaited(widget.telemetry.flush());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // The lifecycle transitions are the anchor for reading the diagnostics log:
    // the monotonic-time gap after a `paused`/`inactive` marks an OS suspension.
    widget.telemetry.record('lifecycle', {'state': state.name});
    // Tell playback when the UI is backgrounded so it can prefer local audio
    // without forbidding TTS synthesis needed to sustain background playback.
    widget.playbackRuntime?.setForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      // Back in the foreground: upload whatever was buffered while backgrounded.
      unawaited(widget.telemetry.flush());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        playbackTelemetryProvider.overrideWithValue(widget.telemetry),
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
