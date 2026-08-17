import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/diagnostics/data/diagnostics_settings_store.dart';

void main() {
  Future<Directory> tempDir() async {
    final directory = await Directory.systemTemp.createTemp('nvr_diag_settings');
    addTearDown(() => directory.delete(recursive: true));
    return directory;
  }

  test('returns null before an endpoint is saved', () async {
    final directory = await tempDir();
    final store = DiagnosticsSettingsStore(
      supportDirectory: () async => directory,
    );
    expect(await store.loadEndpoint(), isNull);
  });

  test('persists and reloads a trimmed endpoint', () async {
    final directory = await tempDir();
    final store = DiagnosticsSettingsStore(
      supportDirectory: () async => directory,
    );

    await store.saveEndpoint('  https://collector.example/ingest  ');

    expect(await store.loadEndpoint(), 'https://collector.example/ingest');
  });

  test('clears the endpoint when saving a blank value', () async {
    final directory = await tempDir();
    final store = DiagnosticsSettingsStore(
      supportDirectory: () async => directory,
    );

    await store.saveEndpoint('https://collector.example/ingest');
    await store.saveEndpoint('   ');

    expect(await store.loadEndpoint(), isNull);
  });
}
