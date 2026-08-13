import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/downloads/data/download_scheduler.dart';

abstract interface class DownloadExecutionStore {
  Future<void> setJobStatus(
    String taskId,
    DownloadJobStatus status, {
    int? retryCount,
  });

  Future<void> incrementFailure(String taskId);

  Future<void> recordCompleted(DownloadDispatchRequest request, File file);
}

abstract interface class DownloadNetworkGate {
  Future<bool> canRun({required bool requiresWifi});
}

final class AllowAllDownloadNetworkGate implements DownloadNetworkGate {
  const AllowAllDownloadNetworkGate();

  @override
  Future<bool> canRun({required bool requiresWifi}) async => true;
}

abstract interface class ConnectivityReader {
  Future<List<ConnectivityResult>> checkConnectivity();
}

final class FlutterConnectivityReader implements ConnectivityReader {
  FlutterConnectivityReader([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() {
    return _connectivity.checkConnectivity();
  }
}

final class ConnectivityDownloadNetworkGate implements DownloadNetworkGate {
  const ConnectivityDownloadNetworkGate(this._reader);

  final ConnectivityReader _reader;

  @override
  Future<bool> canRun({required bool requiresWifi}) async {
    if (!requiresWifi) {
      return true;
    }
    final connections = await _reader.checkConnectivity();
    return connections.contains(ConnectivityResult.wifi) ||
        connections.contains(ConnectivityResult.ethernet);
  }
}

final class AudioCacheTaskDispatcher implements DownloadTaskDispatcher {
  factory AudioCacheTaskDispatcher({
    required AudioCacheRepository repository,
    required DownloadExecutionStore store,
    DownloadNetworkGate networkGate = const AllowAllDownloadNetworkGate(),
  }) {
    return AudioCacheTaskDispatcher._(repository, store, networkGate);
  }

  AudioCacheTaskDispatcher._(this._repository, this._store, this._networkGate);

  final AudioCacheRepository _repository;
  final DownloadExecutionStore _store;
  final DownloadNetworkGate _networkGate;
  final List<DownloadDispatchRequest> _queue = [];

  DownloadDispatchRequest? _active;
  Completer<void>? _idleCompleter;
  bool _draining = false;
  bool _drainScheduled = false;

  Future<void> get idle => _idleCompleter?.future ?? Future<void>.value();

  @override
  Future<bool> enqueue(DownloadDispatchRequest request) async {
    if (!await _networkGate.canRun(requiresWifi: request.requiresWifi)) {
      return false;
    }
    if (_active?.taskId == request.taskId ||
        _queue.any((queued) => queued.taskId == request.taskId)) {
      return true;
    }
    _queue.add(request);
    _queue.sort((first, second) => first.priority.compareTo(second.priority));
    _idleCompleter ??= Completer<void>();
    _scheduleDrain();
    return true;
  }

  @override
  Future<bool> cancel(String taskId) async {
    final index = _queue.indexWhere((request) => request.taskId == taskId);
    if (index < 0) {
      return false;
    }
    _queue.removeAt(index);
    await _store.setJobStatus(taskId, DownloadJobStatus.canceled);
    _completeIdleIfNeeded();
    return true;
  }

  void _scheduleDrain() {
    if (_draining || _drainScheduled) {
      return;
    }
    _drainScheduled = true;
    Timer.run(() {
      _drainScheduled = false;
      unawaited(_drain());
    });
  }

  Future<void> _drain() async {
    if (_draining) {
      return;
    }
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final request = _queue.removeAt(0);
        if (!await _networkGate.canRun(
          requiresWifi: request.requiresWifi,
        )) {
          continue;
        }
        _active = request;
        await _store.setJobStatus(request.taskId, DownloadJobStatus.running);
        try {
          final file = await _repository.obtain(
            request.candidate.segment,
            request.profile,
          );
          await _store.recordCompleted(request, file);
          await _store.setJobStatus(request.taskId, DownloadJobStatus.complete);
        } catch (_) {
          await _store.incrementFailure(request.taskId);
        } finally {
          _active = null;
        }
      }
    } finally {
      _draining = false;
      _completeIdleIfNeeded();
      if (_queue.isNotEmpty) {
        _scheduleDrain();
      }
    }
  }

  void _completeIdleIfNeeded() {
    if (_draining || _queue.isNotEmpty) {
      return;
    }
    final completer = _idleCompleter;
    _idleCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}
