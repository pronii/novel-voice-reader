import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:novel_voice_reader/features/diagnostics/domain/playback_telemetry.dart';

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

/// The low-level audio operations [SilentKeepAlivePlayer] needs, extracted so
/// the recovery logic can be exercised without a real platform audio player.
abstract interface class KeepAliveAudioOutput {
  Future<void> configure({required double volume});

  /// Loads [filePath] as a looping source.
  Future<void> loadLoop(String filePath);

  /// Starts output. Some players complete this future only when playback ends,
  /// so callers starting a looping source must not wait for it to finish.
  Future<void> play();

  Future<void> pause();

  /// Emits whenever the running loop errors (e.g. the backing file was evicted
  /// by the OS), so the keep-alive can rebuild and restart it.
  Stream<Object> get errors;

  Future<void> dispose();
}

/// A [KeepAliveAudioOutput] backed by a dedicated just_audio [AudioPlayer].
final class JustAudioKeepAliveOutput implements KeepAliveAudioOutput {
  JustAudioKeepAliveOutput([AudioPlayer? player])
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<Object> get errors => _player.playbackEventStream.transform(
    StreamTransformer<PlaybackEvent, Object>.fromHandlers(
      handleData: (_, _) {},
      handleError: (error, _, sink) => sink.add(error),
    ),
  );

  @override
  Future<void> configure({required double volume}) async {
    await _player.setVolume(volume);
    await _player.setLoopMode(LoopMode.one);
  }

  @override
  Future<void> loadLoop(String filePath) async {
    await _player.setAudioSource(AudioSource.file(filePath));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> dispose() => _player.dispose();
}

/// A [KeepAlivePlayer] backed by a [KeepAliveAudioOutput] looping a near-silent
/// clip generated at runtime, so no bundled asset is required.
final class SilentKeepAlivePlayer implements KeepAlivePlayer {
  SilentKeepAlivePlayer({
    required Future<Directory> Function() supportDirectory,
    KeepAliveAudioOutput? output,
    PlaybackTelemetry telemetry = const NoopPlaybackTelemetry(),
  }) : _output = output ?? JustAudioKeepAliveOutput(),
       _telemetry = telemetry,
       // ignore: prefer_initializing_formals
       _supportDirectory = supportDirectory {
    _errorSubscription = _output.errors.listen((error) {
      // The running loop failed (typically the backing file was purged while
      // backgrounded). Rebuild the source and resume so the session keeps
      // rendering instead of silently dying.
      _telemetry.record('keepalive.error', {
        'error': error.runtimeType.toString(),
        'message': error.toString(),
      });
      unawaited(_recover());
    });
  }

  final KeepAliveAudioOutput _output;
  final PlaybackTelemetry _telemetry;
  final Future<Directory> Function() _supportDirectory;
  late final StreamSubscription<Object> _errorSubscription;
  Future<void>? _prepared;
  Future<void>? _recovery;
  bool _running = false;
  bool _disposed = false;

  // A very low, non-zero amplitude. iOS revokes background-audio eligibility
  // from sessions that render pure silence (all-zero PCM at volume 0), so the
  // clip carries a faint tone and the player runs at a tiny — but non-zero —
  // volume. The product is inaudible yet counts as real output.
  static const double _volume = 0.02;

  Future<void> _ensurePrepared() {
    return _prepared ??= () async {
      final directory = await _supportDirectory();
      final file = File('${directory.path}/nvr_keep_alive_tone.wav');
      // The application-support directory is never purged from under a
      // backgrounded app (unlike the OS temporary directory), but rewrite the
      // clip if it is somehow missing so a stale memoized future can't leave us
      // pointing at a file that no longer exists.
      if (!file.existsSync()) {
        file.parent.createSync(recursive: true);
        await file.writeAsBytes(buildKeepAliveTone(const Duration(seconds: 1)));
      }
      await _output.configure(volume: _volume);
      await _output.loadLoop(file.path);
    }();
  }

  @override
  Future<void> start() async {
    if (_disposed) {
      return;
    }
    _running = true;
    _telemetry.record('keepalive.start');
    try {
      await _ensurePrepared();
      if (_disposed) {
        return;
      }
      // just_audio's play future completes only when playback is paused or
      // stopped. The keep-alive source loops forever, so waiting here would
      // permanently block the sustainer's recovery queue after the first start.
      _startOutput(recoverOnError: true);
    } catch (error) {
      // The prepared source may have been evicted; rebuild once and retry so a
      // transient failure doesn't permanently kill the keep-alive loop.
      _telemetry.record('keepalive.start.error', {
        'error': error.runtimeType.toString(),
        'message': error.toString(),
      });
      await _recover();
    }
  }

  @override
  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    _running = false;
    _telemetry.record('keepalive.stop');
    await _output.pause();
  }

  Future<void> _recover() {
    final existing = _recovery;
    if (existing != null) {
      return existing;
    }
    late final Future<void> operation;
    operation = _recoverOnce().whenComplete(() {
      if (identical(_recovery, operation)) {
        _recovery = null;
      }
    });
    _recovery = operation;
    return operation;
  }

  Future<void> _recoverOnce() async {
    if (_disposed || !_running) {
      return;
    }
    _telemetry.record('keepalive.recover.begin');
    _prepared = null;
    try {
      await _ensurePrepared();
      if (_disposed || !_running) {
        return;
      }
      // A recovery attempt gets one play request. A failed retry is consumed
      // here and left for the next explicit start/error signal, preventing a
      // tight infinite recovery loop.
      _startOutput(recoverOnError: false);
      _telemetry.record('keepalive.recover.ok');
    } catch (error) {
      // Give up quietly; the next start()/route change/interruption recovery
      // will try again.
      _telemetry.record('keepalive.recover.error', {
        'error': error.runtimeType.toString(),
        'message': error.toString(),
      });
    }
  }

  void _startOutput({required bool recoverOnError}) {
    final play = _output.play();
    // Playback errors are also exposed through [KeepAliveAudioOutput.errors],
    // which drives the rebuild path. Consume this completion future here so a
    // platform-level play failure is not reported as an unhandled async error.
    unawaited(
      play.then<void>(
        (_) {},
        onError: (Object error, StackTrace _) {
          _telemetry.record('keepalive.play.error', {
            'error': error.runtimeType.toString(),
            'message': error.toString(),
            'recoverOnError': recoverOnError,
          });
          if (recoverOnError) {
            unawaited(_recover());
          }
        },
      ),
    );
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _running = false;
    await _errorSubscription.cancel();
    await _recovery;
    await _output.dispose();
  }
}

/// Builds a mono 8 kHz 16-bit PCM WAV file containing [duration] of a
/// near-silent, low-amplitude tone.
///
/// The samples are deliberately non-zero: iOS drops background-audio
/// eligibility for sessions it detects are rendering pure silence, so the
/// keep-alive clip carries a faint sine wave that is inaudible at the tiny
/// playback volume but still registers as genuine output.
Uint8List buildKeepAliveTone(Duration duration) {
  const sampleRate = 8000;
  const bytesPerSample = 2;
  const channels = 1;
  // ~1/1000 of full scale; combined with the player's low volume this is
  // inaudible, but the PCM stream is unmistakably non-silent.
  const amplitude = 32;
  const frequency = 220.0;
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
  final data = ByteData(dataBytes);
  for (var i = 0; i < samples; i++) {
    final value = (amplitude * sin(2 * pi * frequency * i / sampleRate))
        .round();
    data.setInt16(i * bytesPerSample, value, Endian.little);
  }
  builder.add(data.buffer.asUint8List());
  return builder.toBytes();
}
