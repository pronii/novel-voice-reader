import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/downloads/domain/download_policy.dart';

void main() {
  test('rejects a negative chapter-ahead count', () {
    expect(
      () => DownloadPolicy(
        chaptersAhead: -1,
        wholeBook: false,
        wifiOnly: true,
        maxCacheBytes: 1024,
      ),
      throwsArgumentError,
    );
  });

  test('rejects a non-positive cache limit', () {
    expect(
      () => DownloadPolicy(
        chaptersAhead: 3,
        wholeBook: false,
        wifiOnly: true,
        maxCacheBytes: 0,
      ),
      throwsArgumentError,
    );
  });
}
