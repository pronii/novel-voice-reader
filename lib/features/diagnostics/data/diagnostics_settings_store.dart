import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Persists the diagnostics upload endpoint independently of the Drift database
/// so no schema migration / code generation is required to add it.
///
/// The endpoint is not a secret (it is a plain collector URL the user pastes in
/// settings), so a small JSON file under the application-support directory is
/// sufficient and avoids pulling in secure storage.
final class DiagnosticsSettingsStore {
  DiagnosticsSettingsStore({
    required Future<Directory> Function() supportDirectory,
  }) : _supportDirectory = supportDirectory;

  final Future<Directory> Function() _supportDirectory;

  Future<File> _file() async {
    final directory = await _supportDirectory();
    return File('${directory.path}/diagnostics/endpoint.json');
  }

  /// Returns the configured upload URL, or `null` if none is set or the stored
  /// value is empty/invalid. Never throws.
  Future<String?> loadEndpoint() async {
    try {
      final file = await _file();
      if (!file.existsSync()) {
        return null;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return null;
      }
      final url = decoded['url'];
      if (url is String && url.trim().isNotEmpty) {
        return url.trim();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Persists [url] (trimmed). An empty/blank value clears the endpoint.
  /// Never throws.
  Future<void> saveEndpoint(String? url) async {
    try {
      final file = await _file();
      final trimmed = url?.trim() ?? '';
      file.parent.createSync(recursive: true);
      await file.writeAsString(jsonEncode(<String, Object?>{'url': trimmed}));
    } catch (_) {
      // Best-effort: a failure to persist the endpoint must not crash settings.
    }
  }
}
