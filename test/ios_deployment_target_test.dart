import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all iOS deployment targets support background_downloader', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final deploymentTargets = RegExp(
      r'IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);',
    ).allMatches(project).map((match) => double.parse(match.group(1)!));

    expect(deploymentTargets, isNotEmpty);
    expect(
      deploymentTargets.every((version) => version >= 14.0),
      isTrue,
      reason: 'background_downloader requires iOS 14.0 or newer',
    );
  });
}
