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

  test('CI publishes an unsigned release without receiving signing secrets', () {
    final workflow = File('.github/workflows/ci.yml').readAsStringSync();
    expect(workflow, isNot(contains('ANDROID_KEYSTORE_BASE64')));
    expect(workflow, contains('flutter build apk --release'));
    expect(workflow, contains(r'--build-number ${{ github.run_number }}'));
    expect(workflow, contains('name: app-release-unsigned'));
  });
}
