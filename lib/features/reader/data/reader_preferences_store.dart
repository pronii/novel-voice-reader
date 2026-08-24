import 'dart:convert';
import 'dart:io';

import 'package:novel_voice_reader/features/reader/domain/reader_page_mode.dart';

// The private field is initialized from a public named parameter, which cannot
// be a `this._field` initializing formal (named params may not be private).
// ignore_for_file: prefer_initializing_formals

/// Persists the reader's page-turn mode (scroll / slide / curl) as a small JSON
/// file, mirroring `DiagnosticsSettingsStore`'s file-based pattern so no Drift
/// schema migration / code generation is required for a single global setting.
///
/// The mode is a global UI preference (not per book) and never a secret, so a
/// plain JSON file under the application-support directory is sufficient.
final class ReaderPreferencesStore {
  ReaderPreferencesStore({
    required Future<Directory> Function() supportDirectory,
  }) : _supportDirectory = supportDirectory;

  final Future<Directory> Function() _supportDirectory;

  static const String _modeKey = 'reading_mode';

  Future<File> _file() async {
    final directory = await _supportDirectory();
    return File('${directory.path}/reader/preferences.json');
  }

  /// Returns the saved page-turn mode, or [ReaderPageMode.scroll] when nothing
  /// is stored or the file is missing / corrupt. Never throws.
  Future<ReaderPageMode> loadMode() async {
    try {
      final file = await _file();
      if (!file.existsSync()) {
        return ReaderPageMode.scroll;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return ReaderPageMode.scroll;
      }
      final value = decoded[_modeKey];
      return ReaderPageMode.fromStorage(value is String ? value : null);
    } catch (_) {
      return ReaderPageMode.scroll;
    }
  }

  /// Persists [mode]'s [ReaderPageMode.storageKey]. Never throws.
  Future<void> saveMode(ReaderPageMode mode) async {
    try {
      final file = await _file();
      file.parent.createSync(recursive: true);
      await file.writeAsString(
        jsonEncode(<String, Object?>{_modeKey: mode.storageKey}),
      );
    } catch (_) {
      // Best-effort: failing to persist the mode must not crash the reader.
    }
  }
}
