import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/playback/data/background_keep_alive.dart';

void main() {
  test('builds a valid low-amplitude PCM WAV of the requested duration', () {
    final bytes = buildKeepAliveTone(const Duration(seconds: 1));

    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
    expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');

    final view = ByteData.sublistView(bytes);
    expect(view.getUint16(20, Endian.little), 1); // PCM
    expect(view.getUint16(22, Endian.little), 1); // mono
    expect(view.getUint32(24, Endian.little), 8000); // sample rate
    expect(view.getUint16(34, Endian.little), 16); // bits per sample

    const expectedPayload = 8000 * 2;
    expect(view.getUint32(40, Endian.little), expectedPayload);
    expect(bytes.length, 44 + expectedPayload);

    // iOS revokes background audio from sessions rendering pure silence, so the
    // clip must carry a non-zero — but very low amplitude — signal.
    final payload = bytes.sublist(44);
    expect(payload.any((byte) => byte != 0), isTrue);
    var peak = 0;
    for (var i = 0; i + 1 < payload.length; i += 2) {
      final sample = ByteData.sublistView(
        Uint8List.fromList(payload),
      ).getInt16(i, Endian.little);
      peak = sample.abs() > peak ? sample.abs() : peak;
    }
    expect(peak, greaterThan(0));
    expect(peak, lessThan(1000)); // far below full scale (32767)
  });

  test('rebuilds the backing clip after it is purged, then restarts', () async {
    final directory = await Directory.systemTemp.createTemp('nvr_keep_alive');
    addTearDown(() => directory.delete(recursive: true));
    final output = _RecordingKeepAliveOutput();
    final player = SilentKeepAlivePlayer(
      supportDirectory: () async => directory,
      output: output,
    );

    await player.start();
    expect(output.playCalls, 1);
    expect(output.loadedPaths, hasLength(1));
    final clip = File(output.loadedPaths.single);
    expect(clip.existsSync(), isTrue);

    // Simulate iOS purging the file out from under the backgrounded app, then a
    // subsequent (failing) play that trips the rebuild path.
    clip.deleteSync();
    output.failNextPlay = true;

    await player.start();
    // The rebuild-and-restart runs asynchronously off the failed play() and
    // rewrites the clip with real file I/O, so wait for it to actually land
    // rather than assuming a single event-queue drain covers it — a contended
    // CI runner can take several real milliseconds to flush the write.
    await _pumpUntil(
      () =>
          clip.existsSync() &&
          output.loadedPaths.length >= 2 &&
          output.playCalls >= 2,
    );

    expect(clip.existsSync(), isTrue); // rewritten
    expect(output.loadedPaths, hasLength(2)); // source reloaded
    expect(output.playCalls, greaterThanOrEqualTo(2));

    await player.dispose();
  });

  test(
    'does not wait for an infinite loop to finish before returning',
    () async {
      final directory = await Directory.systemTemp.createTemp('nvr_keep_alive');
      addTearDown(() => directory.delete(recursive: true));
      final output = _RecordingKeepAliveOutput()
        ..playCompletion = Completer<void>();
      final player = SilentKeepAlivePlayer(
        supportDirectory: () async => directory,
        output: output,
      );

      await player.start().timeout(const Duration(seconds: 1));
      await player.stop().timeout(const Duration(seconds: 1));

      expect(output.playCalls, 1);
      expect(output.pauseCalls, 1);
      await player.dispose().timeout(const Duration(seconds: 1));
    },
  );

  test('recovers when the running loop reports an error', () async {
    final directory = await Directory.systemTemp.createTemp('nvr_keep_alive');
    addTearDown(() => directory.delete(recursive: true));
    final output = _RecordingKeepAliveOutput();
    final player = SilentKeepAlivePlayer(
      supportDirectory: () async => directory,
      output: output,
    );

    await player.start();
    final reloadsBeforeError = output.loadedPaths.length;

    output.emitError(StateError('source evicted'));
    await pumpEventQueue();

    expect(output.loadedPaths.length, greaterThan(reloadsBeforeError));
    expect(output.playCalls, greaterThanOrEqualTo(2));

    await player.dispose();
  });

  test('does not recover after being stopped', () async {
    final directory = await Directory.systemTemp.createTemp('nvr_keep_alive');
    addTearDown(() => directory.delete(recursive: true));
    final output = _RecordingKeepAliveOutput();
    final player = SilentKeepAlivePlayer(
      supportDirectory: () async => directory,
      output: output,
    );

    await player.start();
    await player.stop();
    final playsAfterStop = output.playCalls;

    output.emitError(StateError('late error'));
    await pumpEventQueue();

    expect(output.playCalls, playsAfterStop);

    await player.dispose();
  });
}

/// Pumps real event-loop turns until [ready] holds or [timeout] elapses.
/// Unlike a fixed [pumpEventQueue] drain, this waits in wall-clock time, so a
/// test can depend on asynchronous recovery that performs real file I/O without
/// racing a loaded machine.
Future<void> _pumpUntil(
  bool Function() ready, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!ready() && stopwatch.elapsed < timeout) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

final class _RecordingKeepAliveOutput implements KeepAliveAudioOutput {  final _errors = StreamController<Object>.broadcast();
  final List<String> loadedPaths = [];
  int playCalls = 0;
  int pauseCalls = 0;
  bool failNextPlay = false;
  Completer<void>? playCompletion;

  void emitError(Object error) => _errors.add(error);

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> configure({required double volume}) async {}

  @override
  Future<void> loadLoop(String filePath) async {
    loadedPaths.add(filePath);
  }

  @override
  Future<void> play() async {
    playCalls++;
    if (failNextPlay) {
      failNextPlay = false;
      throw StateError('play failed');
    }
    final completion = playCompletion;
    if (completion != null) {
      await completion.future;
    }
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> dispose() async {
    await _errors.close();
  }
}
