import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/downloads/domain/download_window.dart';

void main() {
  test('keeps current plus the requested number of later chapters', () {
    expect(
      DownloadWindow.calculate(
        currentChapterIndex: 4,
        chaptersAhead: 3,
        wholeBook: false,
        chapterCount: 10,
      ),
      [4, 5, 6, 7],
    );
  });

  test('clamps to the final chapter', () {
    expect(
      DownloadWindow.calculate(
        currentChapterIndex: 8,
        chaptersAhead: 9,
        wholeBook: false,
        chapterCount: 10,
      ),
      [8, 9],
    );
  });

  test('whole book includes every unfinished chapter', () {
    expect(
      DownloadWindow.calculate(
        currentChapterIndex: 2,
        chaptersAhead: 0,
        wholeBook: true,
        chapterCount: 5,
      ),
      [2, 3, 4],
    );
  });

  test('returns an empty window for an empty book', () {
    expect(
      DownloadWindow.calculate(
        currentChapterIndex: 0,
        chaptersAhead: 0,
        wholeBook: false,
        chapterCount: 0,
      ),
      isEmpty,
    );
  });

  test('rejects a current chapter outside the book', () {
    expect(
      () => DownloadWindow.calculate(
        currentChapterIndex: 4,
        chaptersAhead: 0,
        wholeBook: false,
        chapterCount: 4,
      ),
      throwsArgumentError,
    );
  });
}
