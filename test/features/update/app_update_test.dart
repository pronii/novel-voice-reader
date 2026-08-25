import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/update/app_update.dart';

void main() {
  test('updateAvailable is true only for a strictly newer build', () {
    expect(updateAvailable(10008, 10007), isTrue);
    expect(updateAvailable(10007, 10007), isFalse);
    expect(updateAvailable(10006, 10007), isFalse);
  });
}
