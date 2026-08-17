import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/diagnostics/data/buffered_playback_telemetry.dart';

void main() {
  Future<Directory> tempDir() async {
    final directory = await Directory.systemTemp.createTemp('nvr_telemetry');
    addTearDown(() => directory.delete(recursive: true));
    return directory;
  }

  List<Map<String, dynamic>> readLines(File file) {
    if (!file.existsSync()) return const [];
    return file
        .readAsStringSync()
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .toList();
  }

  test('stamps each event with the launch id it belongs to', () async {
    final directory = await tempDir();
    final telemetry = BufferedPlaybackTelemetry(
      supportDirectory: () async => directory,
      endpointLoader: () async => null,
      uploader: _RecordingUploader(),
      launchId: 'launch-abc',
    );

    telemetry.record('first');
    telemetry.record('second');

    final file = await telemetry.currentLogFile();
    final lines = readLines(file!);
    // Every event carries its own launch id so buffered events uploaded by a
    // later launch stay attributed to the run that produced them.
    expect(lines.every((line) => line['lid'] == 'launch-abc'), isTrue);
  });

  test('omits the launch id field when none is configured', () async {
    final directory = await tempDir();
    final telemetry = BufferedPlaybackTelemetry(
      supportDirectory: () async => directory,
      endpointLoader: () async => null,
      uploader: _RecordingUploader(),
    );

    telemetry.record('first');

    final file = await telemetry.currentLogFile();
    expect(readLines(file!).single.containsKey('lid'), isFalse);
  });

  test('appends events as ordered JSONL lines', () async {
    final directory = await tempDir();
    final uploader = _RecordingUploader();
    final telemetry = BufferedPlaybackTelemetry(
      supportDirectory: () async => directory,
      endpointLoader: () async => null,
      uploader: uploader,
    );

    telemetry.record('first', {'x': 1});
    telemetry.record('second');

    final file = await telemetry.currentLogFile();
    final lines = readLines(file!);
    expect(lines, hasLength(2));
    expect(lines[0]['name'], 'first');
    expect(lines[0]['seq'], 0);
    expect((lines[0]['fields'] as Map)['x'], 1);
    expect(lines[1]['name'], 'second');
    expect(lines[1]['seq'], 1);
  });

  test('trims the oldest events past the cap', () async {
    final directory = await tempDir();
    final telemetry = BufferedPlaybackTelemetry(
      supportDirectory: () async => directory,
      endpointLoader: () async => null,
      uploader: _RecordingUploader(),
      maxBufferedEvents: 3,
      trimSlack: 0,
    );

    for (var i = 0; i < 5; i++) {
      telemetry.record('e$i');
    }

    final file = await telemetry.currentLogFile();
    final lines = readLines(file!);
    // Newest 3 kept; the two oldest dropped.
    expect(lines, hasLength(3));
    expect(lines.first['seq'], 2);
    expect(lines.last['seq'], 4);
  });

  test('flush uploads buffered events and clears them on success', () async {
    final directory = await tempDir();
    final uploader = _RecordingUploader(accept: true);
    final telemetry = BufferedPlaybackTelemetry(
      supportDirectory: () async => directory,
      endpointLoader: () async => 'https://collector.example/ingest',
      uploader: uploader,
    );

    telemetry.record('a');
    telemetry.record('b');
    await telemetry.flush();

    expect(uploader.batches, hasLength(1));
    expect(uploader.batches.single, hasLength(2));
    expect(uploader.endpoints.single, 'https://collector.example/ingest');
    final file = await telemetry.currentLogFile();
    expect(readLines(file!), isEmpty);
  });

  test('flush keeps events buffered when the upload is rejected', () async {
    final directory = await tempDir();
    final uploader = _RecordingUploader(accept: false);
    final telemetry = BufferedPlaybackTelemetry(
      supportDirectory: () async => directory,
      endpointLoader: () async => 'https://collector.example/ingest',
      uploader: uploader,
    );

    telemetry.record('a');
    await telemetry.flush();
    var file = await telemetry.currentLogFile();
    expect(readLines(file!), hasLength(1));

    // A later successful flush ships the retained event.
    uploader.accept = true;
    await telemetry.flush();
    file = await telemetry.currentLogFile();
    expect(readLines(file!), isEmpty);
    expect(uploader.batches, hasLength(2));
  });

  test('flush is a no-op without a configured endpoint', () async {
    final directory = await tempDir();
    final uploader = _RecordingUploader(accept: true);
    final telemetry = BufferedPlaybackTelemetry(
      supportDirectory: () async => directory,
      endpointLoader: () async => null,
      uploader: uploader,
    );

    telemetry.record('a');
    await telemetry.flush();

    expect(uploader.batches, isEmpty);
    final file = await telemetry.currentLogFile();
    expect(readLines(file!), hasLength(1));
  });

  test('flush skips upload when offline', () async {
    final directory = await tempDir();
    final uploader = _RecordingUploader(accept: true);
    final telemetry = BufferedPlaybackTelemetry(
      supportDirectory: () async => directory,
      endpointLoader: () async => 'https://collector.example/ingest',
      uploader: uploader,
      isOnline: () async => false,
    );

    telemetry.record('a');
    await telemetry.flush();

    expect(uploader.batches, isEmpty);
    final file = await telemetry.currentLogFile();
    expect(readLines(file!), hasLength(1));
  });
}

final class _RecordingUploader implements TelemetryUploader {
  _RecordingUploader({this.accept = true});

  bool accept;
  final List<String> endpoints = [];
  final List<List<Map<String, Object?>>> batches = [];

  @override
  Future<bool> upload(
    String endpoint,
    List<Map<String, Object?>> events,
  ) async {
    endpoints.add(endpoint);
    batches.add(List<Map<String, Object?>>.from(events));
    return accept;
  }
}
