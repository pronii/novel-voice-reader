import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

/// Keeps the platform audio session continuously producing output while
/// playback is active.
///
/// iOS only keeps a background-audio app alive while its `AVAudioSession` is
/// actually rendering audio. Between spoken segments — TTS synthesis, fetching
/// the next cloud clip, swapping the just_audio source — there is a silent gap
/// during which nothing is rendered, so the OS expires the background task and
/// suspends the isolate; the pending completion callback never fires and
/// playback dies a minute or two after locking. Looping an inaudible clip
/// across those gaps keeps the session rendering so playback survives.
abstract interface class KeepAlivePlayer {
  /// Begins (or resumes) the inaudible loop.
  Future<void> start();

  /// Stops the inaudible loop (used when playback is intentionally paused).
  Future<void> stop();

  Future<void> dispose();
}

/// A [KeepAlivePlayer] backed by an isolated [AudioPlayer] looping a silent
/// clip generated at runtime, so no bundled asset is required.
final class SilentKeepAlivePlayer implements KeepAlivePlayer {
  SilentKeepAlivePlayer({
    required Future<Directory> Function() temporaryDirectory,
    AudioPlayer? player,
  }) : _player = player ?? AudioPlayer(),
       // ignore: prefer_initializing_formals
       _temporaryDirectory = temporaryDirectory;

  final AudioPlayer _player;
  final Future<Directory> Function() _temporaryDirectory;
  Future<void>? _prepared;
  bool _disposed = false;

  Future<void> _ensurePrepared() {
    return _prepared ??= () async {
      final directory = await _temporaryDirectory();
      final file = File('${directory.path}/nvr_keep_alive_silence.wav');
      if (!file.existsSync()) {
        await file.writeAsBytes(buildSilenceWav(const Duration(seconds: 1)));
      }
      await _player.setVolume(0);
      await _player.setLoopMode(LoopMode.one);
      await _player.setAudioSource(AudioSource.file(file.path));
    }();
  }

  @override
  Future<void> start() async {
    if (_disposed) {
      return;
    }
    await _ensurePrepared();
    if (_disposed) {
      return;
    }
    await _player.play();
  }

  @override
  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    await _player.pause();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _player.dispose();
  }
}

/// Builds a mono 8 kHz 16-bit PCM WAV file containing [duration] of silence.
Uint8List buildSilenceWav(Duration duration) {
  const sampleRate = 8000;
  const bytesPerSample = 2;
  const channels = 1;
  final samples = (sampleRate * duration.inMilliseconds / 1000).round();
  final dataBytes = samples * bytesPerSample * channels;
  final byteRate = sampleRate * bytesPerSample * channels;
  final builder = BytesBuilder();
  final header = ByteData(44);
  // RIFF chunk descriptor.
  header.setUint8(0, 0x52); // 'R'
  header.setUint8(1, 0x49); // 'I'
  header.setUint8(2, 0x46); // 'F'
  header.setUint8(3, 0x46); // 'F'
  header.setUint32(4, 36 + dataBytes, Endian.little);
  header.setUint8(8, 0x57); // 'W'
  header.setUint8(9, 0x41); // 'A'
  header.setUint8(10, 0x56); // 'V'
  header.setUint8(11, 0x45); // 'E'
  // fmt sub-chunk.
  header.setUint8(12, 0x66); // 'f'
  header.setUint8(13, 0x6D); // 'm'
  header.setUint8(14, 0x74); // 't'
  header.setUint8(15, 0x20); // ' '
  header.setUint32(16, 16, Endian.little); // PCM header size
  header.setUint16(20, 1, Endian.little); // audio format = PCM
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, bytesPerSample * channels, Endian.little); // block align
  header.setUint16(34, bytesPerSample * 8, Endian.little); // bits per sample
  // data sub-chunk.
  header.setUint8(36, 0x64); // 'd'
  header.setUint8(37, 0x61); // 'a'
  header.setUint8(38, 0x74); // 't'
  header.setUint8(39, 0x61); // 'a'
  header.setUint32(40, dataBytes, Endian.little);
  builder.add(header.buffer.asUint8List());
  builder.add(Uint8List(dataBytes)); // zero-filled == silence
  return builder.toBytes();
}
