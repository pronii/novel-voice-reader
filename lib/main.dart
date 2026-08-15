import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:novel_voice_reader/app/app.dart';
import 'package:novel_voice_reader/app/providers.dart';
import 'package:novel_voice_reader/core/network/speech_http_client.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/core/storage/secure_credentials.dart';
import 'package:novel_voice_reader/features/downloads/application/audio_cache_runtime.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_path.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_session.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_handler.dart';
import 'package:novel_voice_reader/features/playback/data/background_keep_alive.dart';
import 'package:novel_voice_reader/features/playback/data/background_playback_sustainer.dart';

/// Retains the background playback sustainer for the whole process lifetime.
///
/// The sustainer only stays reachable through the stream subscriptions it wires
/// up; keeping an explicit top-level reference guarantees it is never garbage
/// collected out from under a locked-screen playback session.
// ignore: unused_element
BackgroundPlaybackSustainer? _backgroundPlaybackSustainer;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase(driftDatabase(name: 'novel_voice_reader'));
  final supportDirectory = await getApplicationSupportDirectory();
  final credentials = SecureCredentials(
    FlutterSecureKeyValueStore(const FlutterSecureStorage()),
  );
  final audioCacheRuntime = AudioCacheRuntime(
    database: database,
    cacheDirectoryForBook: (bookId) =>
        audioCacheDirectoryForBook(supportDirectory, bookId),
    dio: createSpeechDio(),
    credentials: credentials,
    activeProfileLoader: () => loadActiveVoiceProfile(database),
    connectivityChanges: Connectivity().onConnectivityChanged,
  );
  await audioCacheRuntime.start();
  final controller = AttachablePlaybackController();
  final audioSession = await BackgroundAudioSession.system();
  final handler = await initializePlaybackServices(
    initializeAudioSession: audioSession.initialize,
    initializeAudioService: () => AudioService.init(
      builder: () => NovelAudioHandler(controller),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.pronii.novel_voice_reader.playback',
        androidNotificationChannelName: '小说朗读',
        androidNotificationOngoing: true,
      ),
    ),
  );
  // Keep the audio session rendering across inter-segment gaps and recover it
  // after interruptions / route changes, so locked-screen background playback
  // does not get suspended a minute or two in.
  _backgroundPlaybackSustainer = BackgroundPlaybackSustainer(
    session: audioSession,
    keepAlive: SilentKeepAlivePlayer(
      supportDirectory: getApplicationSupportDirectory,
    ),
    handler: handler,
  );
  runApp(
    NovelVoiceReaderApp(
      database: database,
      playbackRuntime: PlaybackRuntime(
        controller: controller,
        handler: handler,
      ),
      audioCacheRuntime: audioCacheRuntime,
    ),
  );
}

Future<T> initializePlaybackServices<T>({
  required Future<void> Function() initializeAudioSession,
  required Future<T> Function() initializeAudioService,
}) async {
  await initializeAudioSession();
  return initializeAudioService();
}
