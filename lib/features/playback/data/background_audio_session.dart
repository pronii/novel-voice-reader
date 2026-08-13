import 'package:audio_session/audio_session.dart';

abstract interface class AudioSessionDelegate {
  Future<void> configure(AudioSessionConfiguration configuration);

  Future<bool> setActive(bool active);
}

final class BackgroundAudioSession {
  const BackgroundAudioSession(this._delegate);

  final AudioSessionDelegate _delegate;

  static Future<BackgroundAudioSession> system() async {
    final session = await AudioSession.instance;
    return BackgroundAudioSession(_PluginAudioSessionDelegate(session));
  }

  Future<void> initialize() async {
    await _delegate.configure(AudioSessionConfiguration.music());
    final activated = await _delegate.setActive(true);
    if (!activated) {
      throw StateError('Unable to activate the background audio session.');
    }
  }
}

final class _PluginAudioSessionDelegate implements AudioSessionDelegate {
  const _PluginAudioSessionDelegate(this._session);

  final AudioSession _session;

  @override
  Future<void> configure(AudioSessionConfiguration configuration) =>
      _session.configure(configuration);

  @override
  Future<bool> setActive(bool active) => _session.setActive(active);
}
