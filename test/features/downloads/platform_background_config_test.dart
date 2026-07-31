import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('Android declares download and foreground playback permissions', () {
    final document = XmlDocument.parse(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
    );
    final permissions = document
        .findAllElements('uses-permission')
        .map(
          (element) =>
              element.getAttribute('android:name') ??
              element.getAttribute('name'),
        )
        .whereType<String>()
        .toSet();

    expect(
      permissions,
      containsAll({
        'android.permission.INTERNET',
        'android.permission.WAKE_LOCK',
        'android.permission.RECEIVE_BOOT_COMPLETED',
        'android.permission.FOREGROUND_SERVICE',
        'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
      }),
    );
    expect(
      document
          .findAllElements('service')
          .map((element) => element.getAttribute('android:name'))
          .whereType<String>(),
      contains('com.ryanheise.audioservice.AudioService'),
    );
    expect(
      document
          .findAllElements('receiver')
          .map((element) => element.getAttribute('android:name'))
          .whereType<String>(),
      contains('com.ryanheise.audioservice.MediaButtonReceiver'),
    );
    expect(
      File(
        'android/app/src/main/kotlin/com/pronii/novel_voice_reader/MainActivity.kt',
      ).readAsStringSync(),
      contains('AudioServiceActivity'),
    );
  });

  test('iOS declares opportunistic processing and audio background modes', () {
    final document = XmlDocument.parse(
      File('ios/Runner/Info.plist').readAsStringSync(),
    );

    expect(
      valuesForArrayKey(document, 'UIBackgroundModes'),
      containsAll({'audio', 'fetch', 'processing'}),
    );
    expect(
      valuesForArrayKey(document, 'BGTaskSchedulerPermittedIdentifiers'),
      contains('com.pronii.novelVoiceReader.downloadProcessing'),
    );
  });
}

Set<String> valuesForArrayKey(XmlDocument document, String name) {
  final key = document
      .findAllElements('key')
      .singleWhere((element) => element.innerText == name);
  final siblings = key.parent!.children.whereType<XmlElement>().toList();
  final array = siblings[siblings.indexOf(key) + 1];
  return array
      .findElements('string')
      .map((element) => element.innerText)
      .toSet();
}
