import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';
import 'package:novel_voice_reader/features/speech/presentation/voice_settings_page.dart';

void main() {
  testWidgets('saves an Azure region, voice, and subscription key', (
    tester,
  ) async {
    VoiceProfile? savedProfile;
    String? savedKey;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onSave: (profile, apiKey) async {
            savedProfile = profile;
            savedKey = apiKey;
          },
        ),
      ),
    );

    await tester.tap(find.text('Azure'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Subscription Key'),
      'azure-secret',
    );
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(savedProfile?.providerType, SpeechProviderType.azure);
    expect(
      savedProfile?.normalizedBaseUrl,
      'https://eastasia.tts.speech.microsoft.com',
    );
    expect(savedProfile?.voice, 'zh-CN-XiaoxiaoNeural');
    expect(savedKey, 'azure-secret');
  });

  testWidgets('shows a validation message for an invalid Azure region', (
    tester,
  ) async {
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onSave: (profile, apiKey) async {
            saves++;
          },
        ),
      ),
    );

    await tester.tap(find.text('Azure'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Azure Region'),
      'invalid region',
    );
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.text('请输入有效的 Azure Region 和音色'), findsOneWidget);
    expect(saves, 0);
  });

  testWidgets('saves an official Zhipu voice and API key on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    VoiceProfile? savedProfile;
    String? savedKey;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onSave: (profile, apiKey) async {
            savedProfile = profile;
            savedKey = apiKey;
          },
        ),
      ),
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-260, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('智谱'));
    await tester.pump();
    await tester.tap(find.text('彤彤 (tongtong)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('小陈 (xiaochen)').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'API Key'),
      'zhipu-secret',
    );
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(savedProfile?.providerType, SpeechProviderType.zhipu);
    expect(savedProfile?.voice, 'xiaochen');
    expect(savedProfile?.model, 'glm-tts');
    expect(savedProfile?.outputFormat, 'wav');
    expect(savedKey, 'zhipu-secret');
  });
}
