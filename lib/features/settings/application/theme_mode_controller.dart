import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_voice_reader/features/settings/data/theme_mode_preference_store.dart';

/// Holds the current app-wide [ThemeMode] and persists changes.
///
/// Starts on [ThemeMode.system] so the very first frame never blocks on disk
/// (important because `getApplicationSupportDirectory()` does not resolve under
/// `flutter_test`); [load] then asynchronously replaces it with the saved value
/// if a [ThemeModePreferenceStore] was provided. When no store is injected
/// (widget tests), the controller stays purely in-memory.
final class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._store) : super(ThemeMode.system);

  final ThemeModePreferenceStore? _store;

  /// Loads the persisted mode, if any. Safe to call when no store is present.
  Future<void> load() async {
    final store = _store;
    if (store == null) return;
    final mode = await store.loadMode();
    if (mounted) state = mode;
  }

  /// Sets and persists [mode].
  Future<void> setMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await _store?.saveMode(mode);
  }

  /// Cycles system → light → dark → system, for a single-tap toggle.
  void cycle() {
    setMode(switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    });
  }
}
