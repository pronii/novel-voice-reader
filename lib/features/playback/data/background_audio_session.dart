import 'dart:io';

import 'package:audio_session/audio_session.dart';

abstract interface class AudioSessionDelegate {
  Future<void> configure(AudioSessionConfiguration configuration);

  Future<bool> setActive(bool active);
}

final class BackgroundAudioSession {
  const BackgroundAudioSession(
    this._delegate, {
    required bool activateOnInitialize,
  }) : _activateOnInitialize = activateOnInitialize;

  final AudioSessionDelegate _delegate;
  final bool _activateOnInitialize;

  static Future<BackgroundAudioSession> system() async {
    final session = await AudioSession.instance;
    return BackgroundAudioSession(
      _PluginAudioSessionDelegate(session),
      activateOnInitialize: Platform.isIOS,
    );
  }

  Future<void> initialize() async {
    await _delegate.configure(AudioSessionConfiguration.music());
    if (!_activateOnInitialize) {
      return;
    }
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
