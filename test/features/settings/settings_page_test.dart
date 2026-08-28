import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/settings/presentation/settings_page.dart';

void main() {
  testWidgets('changes the theme mode from the segmented control', (
    tester,
  ) async {
    ThemeMode? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          themeMode: ThemeMode.system,
          onThemeModeChanged: (mode) => selected = mode,
        ),
      ),
    );

    await tester.tap(find.text('深色'));

    expect(selected, ThemeMode.dark);
  });

  testWidgets('routes to voice settings and the update check', (tester) async {
    var voiceOpened = false;
    var updateChecked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          themeMode: ThemeMode.light,
          onThemeModeChanged: (_) {},
          onOpenVoiceSettings: () => voiceOpened = true,
          onCheckUpdate: () => updateChecked = true,
          versionLabel: '当前版本 1.0.9 (10009)',
        ),
      ),
    );

    expect(find.text('当前版本 1.0.9 (10009)'), findsOneWidget);

    await tester.tap(find.text('语音设置'));
    expect(voiceOpened, isTrue);

    await tester.tap(find.text('检查更新'));
    expect(updateChecked, isTrue);
  });
}
