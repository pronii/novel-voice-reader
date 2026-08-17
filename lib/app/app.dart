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

  // While backgrounded (e.g. locked-screen playback) the app keeps producing
  // diagnostics events but iOS may suspend the isolate at any moment, after
  // which nothing can be uploaded. Flush on the way into the background and then
  // periodically so as many lock-screen events as possible reach the collector
  // before a suspension, rather than waiting for the next foreground.
  Timer? _backgroundFlushTimer;
  static const Duration _backgroundFlushInterval = Duration(seconds: 20);

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
      // Back in the foreground: stop the background pump and upload whatever was
      // buffered while backgrounded.
      _stopBackgroundFlush();
      unawaited(widget.telemetry.flush());
    } else {
      // Entering the background / lock screen while (likely) still executing:
      // push buffered events out now and keep pushing on a timer so events
      // produced during locked-screen playback reach the collector before iOS
      // suspends us. The events after a suspension are unrecoverable in-process;
      // the monotonic-time gap before the next event marks that suspension.
      unawaited(widget.telemetry.flush());
      _startBackgroundFlush();
    }
  }

  void _startBackgroundFlush() {
    _backgroundFlushTimer ??= Timer.periodic(
      _backgroundFlushInterval,
      (_) => unawaited(widget.telemetry.flush()),
    );
  }

  void _stopBackgroundFlush() {
    _backgroundFlushTimer?.cancel();
    _backgroundFlushTimer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopBackgroundFlush();
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
