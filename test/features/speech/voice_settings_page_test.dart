import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/features/speech/data/tencent_tts_usage_repository.dart';
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
          onSave: (submission) async {
            savedProfile = submission.profile;
            savedKey = submission.credentials.normalizedApiKey;
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
          onSave: (submission) async {
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
          onSave: (submission) async {
            savedProfile = submission.profile;
            savedKey = submission.credentials.normalizedApiKey;
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

  testWidgets('trims a Zhipu API key before saving', (tester) async {
    String? savedKey;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onSave: (submission) async =>
              savedKey = submission.credentials.normalizedApiKey,
        ),
      ),
    );

    await tester.tap(find.text('智谱'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'API Key'),
      '  zhipu-secret  ',
    );
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(savedKey, 'zhipu-secret');
  });

  testWidgets('disables connection testing when no callback is available', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: VoiceSettingsPage()));

    await tester.tap(find.text('智谱'));
    await tester.pump();

    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '测试连接'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('tests the entered Zhipu key without saving it', (tester) async {
    var tests = 0;
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onTestConnection: (submission) async {
            tests++;
            expect(submission.profile.providerType, SpeechProviderType.zhipu);
            expect(submission.credentials.normalizedApiKey, 'entered-key');
          },
          onSave: (submission) async => saves++,
        ),
      ),
    );

    await tester.tap(find.text('智谱'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'API Key'),
      'entered-key',
    );
    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();

    expect(tests, 1);
    expect(saves, 0);
    expect(find.text('连接成功，API Key 可用'), findsOneWidget);
  });

  testWidgets('requires a non-empty Zhipu key before testing', (tester) async {
    var tests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onTestConnection: (submission) async => tests++,
        ),
      ),
    );

    await tester.tap(find.text('智谱'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'API Key'), '   ');
    await tester.tap(find.text('测试连接'));
    await tester.pump();

    expect(tests, 0);
    expect(find.text('请输入智谱 API Key'), findsOneWidget);
  });

  testWidgets('disables test and save actions while testing a Zhipu key', (
    tester,
  ) async {
    final connectionTest = Completer<void>();
    var tests = 0;
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onTestConnection: (submission) {
            tests++;
            return connectionTest.future;
          },
          onSave: (submission) async => saves++,
        ),
      ),
    );

    await tester.tap(find.text('智谱'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'API Key'),
      'entered-key',
    );
    await tester.tap(find.text('测试连接'));

    await tester.tap(find.text('测试连接'));
    await tester.tap(find.text('保存'));
    expect(tests, 1);
    expect(saves, 0);

    await tester.pump();

    expect(tests, 1);
    expect(find.text('测试中'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '测试中'))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    connectionTest.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shows a sanitized Zhipu connection failure', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onTestConnection: (submission) async {
            throw const AppFailure('智谱语音服务认证失败');
          },
        ),
      ),
    );

    await tester.tap(find.text('智谱'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'API Key'),
      'invalid-key',
    );
    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();

    expect(find.text('智谱语音服务认证失败'), findsOneWidget);
  });

  testWidgets('recovers the connection button after a sanitized timeout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onTestConnection: (submission) async {
            throw const AppFailure('智谱语音服务连接超时');
          },
        ),
      ),
    );

    await tester.tap(find.text('智谱'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'API Key'),
      'timeout-secret',
    );
    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();

    expect(find.text('智谱语音服务连接超时'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.textContaining('timeout-secret'),
      ),
      findsNothing,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '测试连接'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('hides unexpected Zhipu connection failure details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onTestConnection: (submission) async {
            throw StateError('sensitive details');
          },
        ),
      ),
    );

    await tester.tap(find.text('智谱'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'API Key'),
      'invalid-key',
    );
    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();

    expect(find.text('连接测试失败'), findsOneWidget);
    expect(find.textContaining('sensitive details'), findsNothing);
  });

  testWidgets('saves Tencent credentials, voice, and monthly quota', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    VoiceSettingsSubmission? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onSave: (submission) async => saved = submission,
        ),
      ),
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('腾讯云'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'SecretId'),
      '  entered-id  ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'SecretKey'),
      '  entered-key  ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '每月免费额度（字符）'),
      '1000000',
    );
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(saved?.profile.providerType, SpeechProviderType.tencent);
    expect(saved?.profile.voice, '1001');
    expect(saved?.credentials.normalizedSecretId, 'entered-id');
    expect(saved?.credentials.normalizedSecretKey, 'entered-key');
    expect(saved?.monthlyQuotaCharacters, 1000000);
  });

  testWidgets('tests entered Tencent credentials without saving', (
    tester,
  ) async {
    VoiceSettingsSubmission? tested;
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onTestConnection: (submission) async => tested = submission,
          onSave: (submission) async => saves++,
        ),
      ),
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('腾讯云'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'SecretId'),
      'entered-id',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'SecretKey'),
      'entered-key',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final testButton = find.widgetWithText(OutlinedButton, '测试连接').last;
    await tester.tap(testButton);
    await tester.pumpAndSettle();

    expect(tested?.profile.providerType, SpeechProviderType.tencent);
    expect(tested?.credentials.normalizedSecretId, 'entered-id');
    expect(tested?.credentials.normalizedSecretKey, 'entered-key');
    expect(saves, 0);
    expect(find.text('连接成功，腾讯云凭据可用'), findsOneWidget);
  });

  testWidgets('shows and refreshes the Tencent local quota estimate', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onLoadTencentUsage: () async {
            loads++;
            return TencentTtsUsageSnapshot(
              period: '2026-08',
              usedCharacters: loads == 1 ? 25 : 30,
              quotaCharacters: 100,
              updatedAt: DateTime(2026, 8, 2, 12, 30),
            );
          },
        ),
      ),
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('腾讯云'));
    await tester.pumpAndSettle();

    expect(find.text('本机估算'), findsOneWidget);
    expect(find.text('本月已用：25 字符'), findsOneWidget);
    expect(find.text('估算剩余：75 字符'), findsOneWidget);
    expect(find.text('月度额度：100 字符'), findsOneWidget);

    await tester.tap(find.byTooltip('刷新本机估算'));
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text('本月已用：30 字符'), findsOneWidget);
    expect(find.text('估算剩余：70 字符'), findsOneWidget);
  });

  testWidgets('refreshes the Tencent quota estimate after saving', (
    tester,
  ) async {
    var savedQuota = 100;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onSave: (submission) async {
            savedQuota = submission.monthlyQuotaCharacters!;
          },
          onLoadTencentUsage: () async => TencentTtsUsageSnapshot(
            period: '2026-08',
            usedCharacters: 25,
            quotaCharacters: savedQuota,
            updatedAt: DateTime(2026, 8, 2, 12, 30),
          ),
        ),
      ),
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('腾讯云'));
    await tester.pumpAndSettle();
    expect(find.text('月度额度：100 字符'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '每月免费额度（字符）'), '200');
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('月度额度：200 字符'), findsOneWidget);
  });

  testWidgets('warns Tencent users to use least-privilege credentials', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: VoiceSettingsPage()));

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('腾讯云'));
    await tester.pumpAndSettle();

    expect(find.textContaining('专用腾讯云子账号'), findsOneWidget);
    expect(find.textContaining('最小 TTS 权限'), findsOneWidget);
  });

  testWidgets('clears Tencent credentials independently', (tester) async {
    final cleared = <TencentCredentialField>[];
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onClearTencentCredential: (field) async => cleared.add(field),
        ),
      ),
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('腾讯云'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'SecretId'),
      'entered-id',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'SecretKey'),
      'entered-key',
    );

    await tester.tap(find.byTooltip('清除 SecretId'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('清除 SecretKey'));
    await tester.pumpAndSettle();

    expect(cleared, [
      TencentCredentialField.secretId,
      TencentCredentialField.secretKey,
    ]);
  });

  testWidgets('rejects a non-numeric custom Tencent VoiceType', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(onSave: (submission) async => saves++),
      ),
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('腾讯云'));
    await tester.pump();
    await tester.tap(find.text('1001（推荐）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义 VoiceType').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '自定义 VoiceType'),
      'abc',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('请输入有效的数字 VoiceType'), findsOneWidget);
    expect(saves, 0);
  });

  testWidgets('saves a MiMo preset voice, narration style, and API key', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    VoiceSettingsSubmission? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onSave: (submission) async => saved = submission,
        ),
      ),
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('MiMo'));
    await tester.pump();
    await tester.tap(find.text('冰糖（中文女声）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dean（英文男声）').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '朗读风格（可选）'),
      '  沉稳、有磁性，语速稍慢。  ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'MiMo API Key'),
      '  mimo-secret  ',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(saved?.profile.providerType, SpeechProviderType.mimo);
    expect(saved?.profile.voice, 'Dean');
    expect(saved?.profile.style, '沉稳、有磁性，语速稍慢。');
    expect(saved?.credentials.normalizedApiKey, 'mimo-secret');
  });

  testWidgets('tests the entered MiMo key without saving it', (tester) async {
    VoiceSettingsSubmission? tested;
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onTestConnection: (submission) async => tested = submission,
          onSave: (submission) async => saves++,
        ),
      ),
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('MiMo'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'MiMo API Key'),
      'entered-key',
    );
    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();

    expect(tested?.profile.providerType, SpeechProviderType.mimo);
    expect(tested?.credentials.normalizedApiKey, 'entered-key');
    expect(saves, 0);
    expect(find.text('连接成功，API Key 可用'), findsOneWidget);
  });

  testWidgets('requires a non-empty MiMo key before testing', (tester) async {
    var tests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onTestConnection: (submission) async => tests++,
        ),
      ),
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('MiMo'));
    await tester.pump();
    await tester.tap(find.text('测试连接'));
    await tester.pump();

    expect(tests, 0);
    expect(find.text('请输入 MiMo API Key'), findsOneWidget);
  });

  testWidgets('restores the saved MiMo profile without exposing its API key', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          initialProfile: VoiceProfile.mimo(
            voice: 'Dean',
            style: '沉稳、有磁性，语速稍慢。',
            speed: 1.25,
          ),
          hasSavedMiMoApiKey: true,
        ),
      ),
    );

    expect(find.text('MiMo API Key'), findsOneWidget);
    expect(find.text('Dean（英文男声）'), findsOneWidget);
    expect(find.text('语速 1.3x'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '朗读风格（可选）'))
          .controller
          ?.text,
      '沉稳、有磁性，语速稍慢。',
    );
    expect(find.text('已保存，留空则保持不变'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'MiMo API Key'))
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('tests MiMo with the saved key when the input remains blank', (
    tester,
  ) async {
    VoiceSettingsSubmission? tested;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          initialProfile: VoiceProfile.mimo(style: '自然朗读'),
          hasSavedMiMoApiKey: true,
          onTestConnection: (submission) async => tested = submission,
        ),
      ),
    );

    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();

    expect(tested?.profile.style, '自然朗读');
    expect(tested?.credentials.normalizedApiKey, isNull);
    expect(find.text('连接成功，API Key 可用'), findsOneWidget);
  });
}
