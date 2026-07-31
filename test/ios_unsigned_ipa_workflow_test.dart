import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'unsigned IPA packaging strips signatures and provisioning profiles',
    () {
      final workflow = File('.github/workflows/ci.yml').readAsStringSync();

      expect(workflow, contains("-path '*/_CodeSignature/*' -delete"));
      expect(workflow, contains('-type d -name _CodeSignature -delete'));
      expect(
        workflow,
        contains('-type f -name embedded.mobileprovision -delete'),
      );
    },
  );
}
