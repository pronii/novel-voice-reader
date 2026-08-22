import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;

// The private field is initialized from a public named parameter, which cannot
// be a `this._field` initializing formal (named params may not be private).
// ignore_for_file: prefer_initializing_formals

/// Persists the app-wide light/dark preference (system / light / dark) as a
/// small JSON file, mirroring `ReaderPreferencesStore`'s file-based pattern so
/// no Drift schema migration / code generation is required for a single global
/// setting.
///
/// The mode is a global UI preference (not per book) and never a secret, so a
/// plain JSON file under the application-support directory is sufficient.
final class ThemeModePreferenceStore {
  ThemeModePreferenceStore({
    required Future<Directory> Function() supportDirectory,
  }) : _supportDirectory = supportDirectory;

  final Future<Directory> Function() _supportDirectory;

  static const String _key = 'theme_mode';

  Future<File> _file() async {
    final directory = await _supportDirectory();
    return File('${directory.path}/settings/theme.json');
  }

  /// Returns the saved mode, or [ThemeMode.system] when nothing is stored or the
  /// file is missing / corrupt. Never throws.
  Future<ThemeMode> loadMode() async {
    try {
      final file = await _file();
      if (!file.existsSync()) {
        return ThemeMode.system;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return ThemeMode.system;
      }
      return _fromStorage(decoded[_key]);
    } catch (_) {
      return ThemeMode.system;
    }
  }

  /// Persists [mode]. Never throws.
  Future<void> saveMode(ThemeMode mode) async {
    try {
      final file = await _file();
      file.parent.createSync(recursive: true);
      await file.writeAsString(
        jsonEncode(<String, Object?>{_key: _toStorage(mode)}),
      );
    } catch (_) {
      // Best-effort: failing to persist must not crash the app.
    }
  }

  static ThemeMode _fromStorage(Object? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _toStorage(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}
