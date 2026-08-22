import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/diagnostics/domain/playback_telemetry.dart';
import 'package:novel_voice_reader/features/playback/data/background_keep_alive.dart';

void main() {
  Future<Directory> tempDir() async {
    final directory = await Directory.systemTemp.createTemp('nvr_tel_instr');
    addTearDown(() => directory.delete(recursive: true));
    return directory;
  }

  test('keep-alive records start and stop events', () async {
    final directory = await tempDir();
    final telemetry = _RecordingTelemetry();
    final player = SilentKeepAlivePlayer(
      supportDirectory: () async => directory,
      output: _NoopKeepAliveOutput(),
      telemetry: telemetry,
    );

    await player.start();
    await player.stop();

    expect(telemetry.names, contains('keepalive.start'));
    expect(telemetry.names, contains('keepalive.stop'));
    await player.dispose();
  });

  test('keep-alive records a recovery when the loop errors', () async {
    final directory = await tempDir();
    final telemetry = _RecordingTelemetry();
    final output = _NoopKeepAliveOutput();
    final player = SilentKeepAlivePlayer(
      supportDirectory: () async => directory,
      output: output,
      telemetry: telemetry,
    );

    await player.start();
    output.emitError(StateError('source evicted'));
    await pumpEventQueue();

    expect(telemetry.names, contains('keepalive.error'));
    expect(telemetry.names, contains('keepalive.recover.begin'));
    await player.dispose();
  });
}

final class _RecordingTelemetry implements PlaybackTelemetry {
  final List<String> names = [];

  @override
  void record(String name, [Map<String, Object?> fields = const {}]) {
    names.add(name);
  }

  @override
  Future<void> flush() async {}
}

final class _NoopKeepAliveOutput implements KeepAliveAudioOutput {
  final _errors = StreamController<Object>.broadcast();

  void emitError(Object error) => _errors.add(error);

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> configure({required double volume}) async {}

  @override
  Future<void> loadLoop(String filePath) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() async {
    await _errors.close();
  }
}
