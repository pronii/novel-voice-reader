import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/main.dart' as app;

void main() {
  test('initializes the audio session before the background audio service', () async {
    final sessionReady = Completer<void>();
    var serviceStarted = false;

    final startup = app.initializePlaybackServices(
      initializeAudioSession: () => sessionReady.future,
      initializeAudioService: () async {
        serviceStarted = true;
        return Object();
      },
    );
    await Future<void>.delayed(Duration.zero);

    expect(serviceStarted, isFalse);
    sessionReady.complete();
    await startup;

    expect(serviceStarted, isTrue);
  });
}
