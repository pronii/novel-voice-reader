import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:novel_voice_reader/app/providers.dart';
import 'package:novel_voice_reader/app/router.dart';
import 'package:novel_voice_reader/app/theme.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/diagnostics/application/background_flush_scheduler.dart';
import 'package:novel_voice_reader/features/diagnostics/domain/playback_telemetry.dart';
import 'package:novel_voice_reader/features/downloads/application/audio_cache_runtime.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_handler.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_session.dart';
import 'package:novel_voice_reader/features/settings/data/theme_mode_preference_store.dart';

final class NovelVoiceReaderApp extends StatefulWidget {
  const NovelVoiceReaderApp({
    super.key,
    this.database,
    this.playbackRuntime,
    this.audioCacheRuntime,
    this.backgroundAudioSession,
    this.themeModeStore,
    this.telemetry = const NoopPlaybackTelemetry(),
  });

  final AppDatabase? database;
  final PlaybackRuntime? playbackRuntime;
  final AudioCacheRuntime? audioCacheRuntime;
  final BackgroundAudioSession? backgroundAudioSession;
  final ThemeModePreferenceStore? themeModeStore;
  final PlaybackTelemetry telemetry;

  @override
  State<NovelVoiceReaderApp> createState() => _NovelVoiceReaderAppState();
}

final class _NovelVoiceReaderAppState extends State<NovelVoiceReaderApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;

  // While backgrounded (e.g. locked-screen playback) the app keeps producing
  // diagnostics events but iOS may suspend the isolate at any moment, after
  // which nothing can be uploaded. This flushes on the way into the background
  // and then periodically so as many lock-screen events as possible reach the
  // collector before a suspension.
  late final BackgroundFlushScheduler _flushScheduler;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter();
    _flushScheduler = BackgroundFlushScheduler(flush: widget.telemetry.flush);
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
      _flushScheduler.onForeground();
    } else {
      // Entering the background / lock screen while (likely) still executing.
      // Events produced after a subsequent suspension are unrecoverable
      // in-process; the monotonic-time gap before the next event marks it.
      _flushScheduler.onBackground();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushScheduler.dispose();
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
        backgroundAudioSessionProvider.overrideWithValue(
          widget.backgroundAudioSession,
        ),
        playbackTelemetryProvider.overrideWithValue(widget.telemetry),
        themeModePreferenceStoreProvider.overrideWithValue(
          widget.themeModeStore,
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final themeMode = ref.watch(themeModeControllerProvider);
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: '声阅',
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
