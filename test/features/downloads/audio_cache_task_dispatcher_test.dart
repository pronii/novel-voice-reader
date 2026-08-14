import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_repository.dart';
import 'package:novel_voice_reader/features/downloads/data/audio_cache_task_dispatcher.dart';
import 'package:novel_voice_reader/features/downloads/data/download_scheduler.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

void main() {
  test('executes accepted cache work and records completion', () async {
    final directory = await Directory.systemTemp.createTemp(
      'download-dispatch-test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final executionStore = FakeDownloadExecutionStore();
    final dispatcher = AudioCacheTaskDispatcher(
      repository: AudioCacheRepository(
        directory: directory,
        synthesizer: ValidSynthesizer(),
      ),
      store: executionStore,
    );
    final request = DownloadDispatchRequest(
      taskId: 'cache-1-0',
      bookId: 7,
      candidate: const DownloadCandidate(
        cacheKey: 'cache-1-0',
        chapterId: 2,
        chapterIndex: 0,
        paragraphIndex: 0,
        segment: SpeechSegment(
          id: '1:0',
          paragraphId: 1,
          text: '正文',
          partIndex: 0,
        ),
        estimatedBytes: 100,
        cached: false,
      ),
      profile: profile,
      priority: 0,
      requiresWifi: false,
    );

    expect(await dispatcher.enqueue(request), isTrue);
    await dispatcher.idle;

    expect(executionStore.statuses, [
      DownloadJobStatus.running,
      DownloadJobStatus.complete,
    ]);
    expect(executionStore.completedFile, isNotNull);
    expect(await executionStore.completedFile!.exists(), isTrue);
  });

  test('marks failed synthesis for a later reconciliation retry', () async {
    final directory = await Directory.systemTemp.createTemp(
      'download-dispatch-test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final executionStore = FakeDownloadExecutionStore();
    final dispatcher = AudioCacheTaskDispatcher(
      repository: AudioCacheRepository(
        directory: directory,
        synthesizer: FailingSynthesizer(),
      ),
      store: executionStore,
    );
    final request = DownloadDispatchRequest(
      taskId: 'cache-1-0',
      bookId: 7,
      candidate: const DownloadCandidate(
        cacheKey: 'cache-1-0',
        chapterId: 2,
        chapterIndex: 0,
        paragraphIndex: 0,
        segment: SpeechSegment(
          id: '1:0',
          paragraphId: 1,
          text: '正文',
          partIndex: 0,
        ),
        estimatedBytes: 100,
        cached: false,
      ),
      profile: profile,
      priority: 0,
      requiresWifi: false,
    );

    await dispatcher.enqueue(request);
    await dispatcher.idle;

    expect(executionStore.statuses, [DownloadJobStatus.running]);
    expect(executionStore.failedTaskIds, ['cache-1-0']);
  });

  test(
    'leaves Wi-Fi-only work pending when the network is not allowed',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'download-dispatch-test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final executionStore = FakeDownloadExecutionStore();
      final dispatcher = AudioCacheTaskDispatcher(
        repository: AudioCacheRepository(
          directory: directory,
          synthesizer: ValidSynthesizer(),
        ),
        store: executionStore,
        networkGate: DeniedNetworkGate(),
      );
      final request = DownloadDispatchRequest(
        taskId: 'cache-1-0',
        bookId: 7,
        candidate: const DownloadCandidate(
          cacheKey: 'cache-1-0',
          chapterId: 2,
          chapterIndex: 0,
          paragraphIndex: 0,
          segment: SpeechSegment(
            id: '1:0',
            paragraphId: 1,
            text: '正文',
            partIndex: 0,
          ),
          estimatedBytes: 100,
          cached: false,
        ),
        profile: profile,
        priority: 0,
        requiresWifi: true,
      );

      expect(await dispatcher.enqueue(request), isFalse);
      expect(executionStore.statuses, isEmpty);
      expect(directory.listSync(), isEmpty);
    },
  );

  test('rechecks Wi-Fi immediately before queued work starts', () async {
    final directory = await Directory.systemTemp.createTemp(
      'download-dispatch-test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final executionStore = FakeDownloadExecutionStore();
    final dispatcher = AudioCacheTaskDispatcher(
      repository: AudioCacheRepository(
        directory: directory,
        synthesizer: ValidSynthesizer(),
      ),
      store: executionStore,
      networkGate: SequenceNetworkGate([true, false]),
    );
    final request = DownloadDispatchRequest(
      taskId: 'cache-1-0',
      bookId: 7,
      candidate: const DownloadCandidate(
        cacheKey: 'cache-1-0',
        chapterId: 2,
        chapterIndex: 0,
        paragraphIndex: 0,
        segment: SpeechSegment(
          id: '1:0',
          paragraphId: 1,
          text: '正文',
          partIndex: 0,
        ),
        estimatedBytes: 100,
        cached: false,
      ),
      profile: profile,
      priority: 0,
      requiresWifi: true,
    );

    expect(await dispatcher.enqueue(request), isTrue);
    await dispatcher.idle;

    expect(executionStore.statuses, [DownloadJobStatus.pending]);
    expect(directory.listSync(), isEmpty);
  });

  test('connectivity gate distinguishes Wi-Fi from mobile data', () async {
    final mobileGate = ConnectivityDownloadNetworkGate(
      FakeConnectivityReader([ConnectivityResult.mobile]),
    );
    final wifiGate = ConnectivityDownloadNetworkGate(
      FakeConnectivityReader([ConnectivityResult.wifi]),
    );

    expect(await mobileGate.canRun(requiresWifi: true), isFalse);
    expect(await mobileGate.canRun(requiresWifi: false), isTrue);
    expect(await wifiGate.canRun(requiresWifi: true), isTrue);
  });

  test('removes queued work when an updated Wi-Fi policy is denied', () async {
    final directory = await Directory.systemTemp.createTemp(
      'download-dispatch-test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final executionStore = FakeDownloadExecutionStore();
    final dispatcher = AudioCacheTaskDispatcher(
      obtain: (request) async {
        if (request.taskId == 'first') {
          firstStarted.complete();
          await releaseFirst.future;
        }
        final file = File(
          '${directory.path}${Platform.pathSeparator}${request.taskId}.mp3',
        );
        await file.writeAsBytes(validMp3Bytes);
        return file;
      },
      store: executionStore,
      networkGate: SequenceNetworkGate([true, true, true, false]),
    );
    final first = request(taskId: 'first');
    final second = request(taskId: 'second');

    expect(await dispatcher.enqueue(first), isTrue);
    await firstStarted.future;
    expect(await dispatcher.enqueue(second), isTrue);
    expect(
      await dispatcher.enqueue(request(taskId: 'second', requiresWifi: true)),
      isFalse,
    );
    releaseFirst.complete();
    await dispatcher.idle;

    expect(executionStore.completedTaskIds, ['first']);
  });
}

final profile = VoiceProfile.cloud(
  baseUrl: 'https://example.com',
  model: 'tts-model',
  voice: 'voice-a',
  speed: 1,
  outputFormat: 'mp3',
);

DownloadDispatchRequest request({
  required String taskId,
  bool requiresWifi = false,
}) {
  return DownloadDispatchRequest(
    taskId: taskId,
    bookId: 7,
    candidate: DownloadCandidate(
      cacheKey: taskId,
      chapterId: 2,
      chapterIndex: 0,
      paragraphIndex: 0,
      segment: SpeechSegment(
        id: '$taskId:0',
        paragraphId: taskId.hashCode,
        text: '正文',
        partIndex: 0,
      ),
      estimatedBytes: 100,
      cached: false,
    ),
    profile: profile,
    priority: 0,
    requiresWifi: requiresWifi,
  );
}

final validMp3Bytes = Uint8List.fromList([
  0x49,
  0x44,
  0x33,
  0x04,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
]);

final class ValidSynthesizer implements CloudSpeechSynthesizer {
  @override
  Future<Uint8List> synthesize(
    SpeechSegment segment,
    VoiceProfile profile,
  ) async {
    return Uint8List.fromList([
      0x49,
      0x44,
      0x33,
      0x04,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ]);
  }
}

final class FailingSynthesizer implements CloudSpeechSynthesizer {
  @override
  Future<Uint8List> synthesize(
    SpeechSegment segment,
    VoiceProfile profile,
  ) async {
    throw StateError('offline');
  }
}

final class FakeDownloadExecutionStore implements DownloadExecutionStore {
  final List<DownloadJobStatus> statuses = [];
  final List<String> failedTaskIds = [];
  final List<String> completedTaskIds = [];
  File? completedFile;

  @override
  Future<void> incrementFailure(String taskId) async {
    failedTaskIds.add(taskId);
  }

  @override
  Future<void> recordCompleted(
    DownloadDispatchRequest request,
    File file,
  ) async {
    completedFile = file;
    completedTaskIds.add(request.taskId);
  }

  @override
  Future<void> setJobStatus(
    String taskId,
    DownloadJobStatus status, {
    int? retryCount,
  }) async {
    statuses.add(status);
  }
}

final class DeniedNetworkGate implements DownloadNetworkGate {
  @override
  Future<bool> canRun({required bool requiresWifi}) async => false;
}

final class SequenceNetworkGate implements DownloadNetworkGate {
  SequenceNetworkGate(this.results);

  final List<bool> results;

  @override
  Future<bool> canRun({required bool requiresWifi}) async {
    return results.removeAt(0);
  }
}

final class FakeConnectivityReader implements ConnectivityReader {
  FakeConnectivityReader(this.results);

  final List<ConnectivityResult> results;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => results;
}
