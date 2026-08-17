import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:novel_voice_reader/features/diagnostics/domain/playback_telemetry.dart';

// Fields are private but the constructor params are public named parameters, so
// they cannot be expressed as `this._field` initializing formals (named params
// may not start with an underscore); the pass-through assignments are intended.
// ignore_for_file: prefer_initializing_formals

/// Ships a batch of events to a collector. Abstracted so the buffering and
/// rotation logic can be tested without real HTTP.
abstract interface class TelemetryUploader {
  /// POSTs [events] to [endpoint]. Returns true only if the collector accepted
  /// them (HTTP 2xx); returning false (or throwing) leaves the batch buffered
  /// for the next flush.
  Future<bool> upload(String endpoint, List<Map<String, Object?>> events);
}

/// A [TelemetryUploader] backed by Dio.
final class DioTelemetryUploader implements TelemetryUploader {
  const DioTelemetryUploader(this._dio, {this.session = const {}, this.token});

  final Dio _dio;

  /// Static per-launch context (platform, OS version, launch id) attached to
  /// every batch so the collector can group events by run.
  final Map<String, Object?> session;

  /// Optional shared secret guarding a public collector. When set it is sent as
  /// the `X-Telemetry-Token` header; the collector rejects batches without it.
  /// Not an API key to any paid service — it only gates the diagnostics sink.
  final String? token;

  @override
  Future<bool> upload(
    String endpoint,
    List<Map<String, Object?>> events,
  ) async {
    try {
      final response = await _dio.post<dynamic>(
        endpoint,
        data: <String, Object?>{
          if (session.isNotEmpty) 'session': session,
          'events': events,
        },
        options: Options(
          contentType: 'application/json',
          headers: <String, Object?>{
            if (token != null && token!.isNotEmpty) 'X-Telemetry-Token': token,
          },
          // The collector decides how to respond; we only care about the code.
          validateStatus: (_) => true,
        ),
      );
      final code = response.statusCode ?? 0;
      return code >= 200 && code < 300;
    } catch (_) {
      return false;
    }
  }
}

/// File-backed [PlaybackTelemetry] implementing the local-first, deferred-upload
/// strategy the lock-screen bug demands.
///
/// The failure being diagnosed is iOS *suspending* the backgrounded isolate, so
/// events cannot be shipped live at the moment they matter most. Instead every
/// event is appended (and fsync'd) to a JSONL file that survives suspension, and
/// upload is attempted opportunistically when the app is alive again (launch /
/// foreground). The monotonic-timestamp gap between the last event before a
/// suspension and the first after it is itself the key diagnostic signal.
///
/// All work is serialized on an internal queue and every path swallows its
/// errors: telemetry must never disrupt or slow playback.
final class BufferedPlaybackTelemetry implements PlaybackTelemetry {
  BufferedPlaybackTelemetry({
    required Future<Directory> Function() supportDirectory,
    required Future<String?> Function() endpointLoader,
    required TelemetryUploader uploader,
    Future<bool> Function()? isOnline,
    int Function()? monotonicMicros,
    DateTime Function()? now,
    int maxBufferedEvents = 5000,
    int trimSlack = 500,
  }) : _supportDirectory = supportDirectory,
       _endpointLoader = endpointLoader,
       _uploader = uploader,
       _isOnline = isOnline,
       _now = now ?? (() => DateTime.now().toUtc()),
       _maxBufferedEvents = maxBufferedEvents,
       _trimSlack = trimSlack,
       _monotonic = monotonicMicros ?? _defaultMonotonic();

  final Future<Directory> Function() _supportDirectory;
  final Future<String?> Function() _endpointLoader;
  final TelemetryUploader _uploader;
  final Future<bool> Function()? _isOnline;
  final DateTime Function() _now;
  final int Function() _monotonic;
  final int _maxBufferedEvents;
  final int _trimSlack;

  Future<void> _writes = Future<void>.value();
  Future<void>? _flushing;
  File? _file;
  int _seq = 0;
  int? _lineCount;

  static int Function() _defaultMonotonic() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsedMicroseconds;
  }

  @override
  void record(String name, [Map<String, Object?> fields = const {}]) {
    final event = PlaybackTelemetryEvent(
      seq: _seq++,
      monotonicMicros: _monotonic(),
      wallClock: _now(),
      name: name,
      fields: fields,
    );
    // Fire-and-forget: append happens on the write queue, off this turn.
    unawaited(_enqueueWrite(() => _append(event)));
  }

  @override
  Future<void> flush() {
    return _flushing ??= _flushOnce().whenComplete(() => _flushing = null);
  }

  /// Returns the backing log file (creating it if needed), or null on failure.
  /// Used by the "export diagnostics" action.
  Future<File?> currentLogFile() async {
    try {
      return await _enqueueWrite(_ensureFile);
    } catch (_) {
      return null;
    }
  }

  Future<void> _flushOnce() async {
    try {
      final endpoint = await _endpointLoader();
      if (endpoint == null) {
        return;
      }
      final online = _isOnline;
      if (online != null && !await online()) {
        return;
      }
      // Snapshot buffered lines through the write queue for a consistent view.
      final snapshot = await _enqueueWrite<List<String>>(() async {
        final file = await _ensureFile();
        return _readLines(file);
      });
      if (snapshot == null || snapshot.isEmpty) {
        return;
      }
      final events = <Map<String, Object?>>[];
      for (final line in snapshot) {
        try {
          final decoded = jsonDecode(line);
          if (decoded is Map) {
            events.add(Map<String, Object?>.from(decoded));
          }
        } catch (_) {
          // Skip a corrupt line rather than blocking the whole batch.
        }
      }
      if (events.isEmpty) {
        // Nothing parseable; drop the malformed lines so they don't wedge us.
        await _enqueueWrite(() => _dropLeading(snapshot.length));
        return;
      }
      final accepted = await _uploader.upload(endpoint, events);
      if (!accepted) {
        return;
      }
      // Drop exactly what we uploaded; events appended during the upload stay.
      await _enqueueWrite(() => _dropLeading(snapshot.length));
    } catch (_) {
      // Best-effort: a flush failure just leaves events buffered for next time.
    }
  }

  Future<T?> _enqueueWrite<T>(Future<T> Function() operation) {
    final result = _writes.then((_) => operation());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result.then<T?>((value) => value, onError: (Object _, StackTrace _) {
      return null;
    });
  }

  Future<void> _append(PlaybackTelemetryEvent event) async {
    final file = await _ensureFile();
    await file.writeAsString(
      '${event.toJsonLine()}\n',
      mode: FileMode.append,
      flush: true,
    );
    final count = (_lineCount ?? 0) + 1;
    _lineCount = count;
    if (count > _maxBufferedEvents + _trimSlack) {
      await _trim(file);
    }
  }

  Future<void> _trim(File file) async {
    final lines = _readLines(file);
    if (lines.length <= _maxBufferedEvents) {
      _lineCount = lines.length;
      return;
    }
    final kept = lines.sublist(lines.length - _maxBufferedEvents);
    await file.writeAsString('${kept.join('\n')}\n', flush: true);
    _lineCount = kept.length;
  }

  Future<void> _dropLeading(int count) async {
    final file = await _ensureFile();
    final lines = _readLines(file);
    final remaining = count >= lines.length
        ? const <String>[]
        : lines.sublist(count);
    await file.writeAsString(
      remaining.isEmpty ? '' : '${remaining.join('\n')}\n',
      flush: true,
    );
    _lineCount = remaining.length;
  }

  Future<File> _ensureFile() async {
    final existing = _file;
    if (existing != null) {
      return existing;
    }
    final directory = await _supportDirectory();
    final file = File('${directory.path}/diagnostics/playback_events.jsonl');
    file.parent.createSync(recursive: true);
    if (file.existsSync()) {
      _lineCount = _readLines(file).length;
    } else {
      file.createSync();
      _lineCount = 0;
    }
    _file = file;
    return file;
  }

  List<String> _readLines(File file) {
    if (!file.existsSync()) {
      return const <String>[];
    }
    return file
        .readAsStringSync()
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
  }
}
