import 'package:audio_service/audio_service.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:novel_voice_reader/app/app.dart';
import 'package:novel_voice_reader/core/storage/app_database.dart';
import 'package:novel_voice_reader/features/playback/data/background_audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase(driftDatabase(name: 'novel_voice_reader'));
  final controller = AttachablePlaybackController();
  final handler = await AudioService.init(
    builder: () => NovelAudioHandler(controller),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.pronii.novel_voice_reader.playback',
      androidNotificationChannelName: '小说朗读',
      androidNotificationOngoing: true,
    ),
  );
  runApp(
    NovelVoiceReaderApp(
      database: database,
      playbackRuntime: PlaybackRuntime(
        controller: controller,
        handler: handler,
      ),
    ),
  );
}
