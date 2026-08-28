import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/library/presentation/library_page.dart';

void main() {
  testWidgets('shows an empty library with an import command', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LibraryPage(books: [], onImport: _noopImport),
      ),
    );

    expect(find.text('还没有导入小说'), findsOneWidget);
    expect(find.byTooltip('导入小说'), findsOneWidget);
  });

  testWidgets('does not overflow at a large text scale', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: const MaterialApp(
          home: LibraryPage(
            books: [
              LibraryBookItem(
                id: 1,
                title: '一本标题很长但仍然需要完整适配界面的测试小说',
                progressLabel: '第 38 章',
              ),
            ],
            onImport: _noopImport,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('opens cache settings for the selected book', (tester) async {
    int? selectedBookId;
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryPage(
          books: const [
            LibraryBookItem(id: 7, title: '测试书', progressLabel: '继续阅读'),
          ],
          onImport: _noopImport,
          onOpenCacheSettings: (bookId) => selectedBookId = bookId,
        ),
      ),
    );

    await tester.tap(find.byTooltip('缓存设置'));

    expect(selectedBookId, 7);
  });

  testWidgets('opens the book on tap and triggers the import FAB', (
    tester,
  ) async {
    int? openedBookId;
    var importCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryPage(
          books: const [
            LibraryBookItem(id: 3, title: '三体', progressLabel: '继续阅读'),
            LibraryBookItem(id: 5, title: '活着', progressLabel: '尚未开始'),
            LibraryBookItem(id: 9, title: '百年孤独', progressLabel: '第 12 章'),
          ],
          onImport: () async => importCalled = true,
          onOpenBook: (bookId) => openedBookId = bookId,
        ),
      ),
    );

    // FAB 导入入口应存在。
    expect(find.byTooltip('导入小说'), findsOneWidget);

    await tester.tap(find.byTooltip('导入小说'));
    expect(importCalled, isTrue);

    await tester.tap(find.text('活着'));
    expect(openedBookId, 5);
  });

  testWidgets('shows the continue-reading hero with a listen shortcut', (
    tester,
  ) async {
    int? listenedBookId;
    int? openedBookId;
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryPage(
          books: const [
            LibraryBookItem(id: 7, title: '测试书', progressLabel: '第 3 / 120 章'),
          ],
          continueBook: const LibraryBookItem(
            id: 7,
            title: '测试书',
            progressLabel: '第 3 / 120 章',
          ),
          continueProgress: 3 / 120,
          onImport: _noopImport,
          onOpenBook: (bookId) => openedBookId = bookId,
          onListenBook: (bookId) => listenedBookId = bookId,
        ),
      ),
    );

    expect(find.text('继续阅读'), findsOneWidget);
    expect(find.text('继续听'), findsOneWidget);

    await tester.tap(find.text('继续听'));
    expect(listenedBookId, 7);

    // 网格里的书本体仍走打开阅读页的路径（.last 取网格单元格中的标题）。
    await tester.tap(find.text('测试书').last);
    expect(openedBookId, 7);
  });

  testWidgets('opens settings from the app bar', (tester) async {
    var openedSettings = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryPage(
          books: const [],
          onImport: _noopImport,
          onOpenSettings: () => openedSettings = true,
        ),
      ),
    );

    await tester.tap(find.byTooltip('设置'));
    expect(openedSettings, isTrue);
  });
}

Future<void> _noopImport() async {}
