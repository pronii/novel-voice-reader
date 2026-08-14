import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release build uses an external long-lived signing key', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('rootProject.file("key.properties")'));
    expect(gradle, contains('signingConfigs.create("release")'));
    expect(gradle, contains('signingConfigs.getByName("release")'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
  });
}
