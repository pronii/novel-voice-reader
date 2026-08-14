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

typedef DownloadAudioObtainer =
    Future<File> Function(DownloadDispatchRequest request);

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
    AudioCacheRepository? repository,
    DownloadAudioObtainer? obtain,
    required DownloadExecutionStore store,
    DownloadNetworkGate networkGate = const AllowAllDownloadNetworkGate(),
  }) {
    if (repository == null && obtain == null) {
      throw ArgumentError('Either repository or obtain must be provided.');
    }
    return AudioCacheTaskDispatcher._(
      obtain ??
          (request) =>
              repository!.obtain(request.candidate.segment, request.profile),
      store,
      networkGate,
    );
  }

  AudioCacheTaskDispatcher._(this._obtain, this._store, this._networkGate);

  final DownloadAudioObtainer _obtain;
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
    if (_active?.taskId == request.taskId) {
      return true;
    }
    final queuedIndex = _queue.indexWhere(
      (queued) => queued.taskId == request.taskId,
    );
    if (queuedIndex >= 0) {
      if (!await _networkGate.canRun(requiresWifi: request.requiresWifi)) {
        _queue.removeAt(queuedIndex);
        _completeIdleIfNeeded();
        return false;
      }
      _queue[queuedIndex] = request;
      _queue.sort((first, second) => first.priority.compareTo(second.priority));
      return true;
    }
    if (!await _networkGate.canRun(requiresWifi: request.requiresWifi)) {
      return false;
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
        if (!await _networkGate.canRun(requiresWifi: request.requiresWifi)) {
          await _store.setJobStatus(request.taskId, DownloadJobStatus.pending);
          continue;
        }
        _active = request;
        await _store.setJobStatus(request.taskId, DownloadJobStatus.running);
        try {
          final file = await _obtain(request);
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
