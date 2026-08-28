import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';
import 'package:novel_voice_reader/features/speech/presentation/voice_settings_page.dart';

void main() {
  testWidgets('offers only remote TTS providers', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VoiceSettingsPage()));

    expect(find.text('Base URL'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tts-provider-dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('系统'), findsNothing);
    expect(find.text('兼容'), findsWidgets);
    expect(find.text('MiMo'), findsOneWidget);
  });

  testWidgets('selects a TTS provider from a dropdown on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: VoiceSettingsPage()));

    expect(find.byType(SingleChildScrollView), findsNothing);
    await tester.tap(find.byKey(const Key('tts-provider-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MiMo').last);
    await tester.pumpAndSettle();

    expect(find.text('MiMo API Key'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disables connection testing when no callback is available', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: VoiceSettingsPage()));

    await _selectVoiceProvider(tester, 'MiMo');

    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '测试连接'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('disables test and save actions while testing a MiMo key', (
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

    await _selectVoiceProvider(tester, 'MiMo');
    await tester.enterText(
      find.widgetWithText(TextField, 'MiMo API Key'),
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

  testWidgets('shows a sanitized MiMo connection failure', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onTestConnection: (submission) async {
            throw const AppFailure('MiMo 语音服务认证失败');
          },
        ),
      ),
    );

    await _selectVoiceProvider(tester, 'MiMo');
    await tester.enterText(
      find.widgetWithText(TextField, 'MiMo API Key'),
      'invalid-key',
    );
    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();

    expect(find.text('MiMo 语音服务认证失败'), findsOneWidget);
  });

  testWidgets('recovers the connection button after a sanitized timeout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          onTestConnection: (submission) async {
            throw const AppFailure('MiMo 语音服务连接超时');
          },
        ),
      ),
    );

    await _selectVoiceProvider(tester, 'MiMo');
    await tester.enterText(
      find.widgetWithText(TextField, 'MiMo API Key'),
      'timeout-secret',
    );
    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();

    expect(find.text('MiMo 语音服务连接超时'), findsOneWidget);
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

  testWidgets('hides unexpected MiMo connection failure details', (
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

    await _selectVoiceProvider(tester, 'MiMo');
    await tester.enterText(
      find.widgetWithText(TextField, 'MiMo API Key'),
      'invalid-key',
    );
    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();

    expect(find.text('连接测试失败'), findsOneWidget);
    expect(find.textContaining('sensitive details'), findsNothing);
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

    await _selectVoiceProvider(tester, 'MiMo');
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

    await _selectVoiceProvider(tester, 'MiMo');
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

    await _selectVoiceProvider(tester, 'MiMo');
    await tester.tap(find.text('测试连接'));
    await tester.pump();

    expect(tests, 0);
    expect(find.text('请输入 MiMo API Key'), findsOneWidget);
  });

  testWidgets('requires a cloud key before saving a compatible profile', (
    tester,
  ) async {
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(home: VoiceSettingsPage(onSave: (_) async => saves++)),
    );

    await _selectVoiceProvider(tester, '兼容');
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(saves, 0);
    expect(find.text('请输入云端语音 API Key'), findsOneWidget);
  });

  testWidgets('uses the deployed URL for the self-hosted provider', (
    tester,
  ) async {
    // The self-hosted form now shows a helper line under the key field, which
    // pushes the save button past the default 600px viewport; give the test a
    // taller surface so the (lazily built) button stays in the widget tree.
    tester.view.physicalSize = const Size(400, 1200);
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

    await _selectVoiceProvider(tester, '自建服务端');
    final keyField = find.widgetWithText(TextField, 'MiMo API Key');
    final saveButton = find.byType(FilledButton).first;
    await tester.enterText(keyField, 'secret');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(saved?.profile.providerType, SpeechProviderType.server);
    expect(saved?.profile.normalizedBaseUrl, 'https://tts.ll.993209.xyz:888');
    expect(saved?.profile.model, VoiceProfile.mimoModel);
    expect(saved?.profile.voice, VoiceProfile.defaultMiMoVoice);
    expect(saved?.profile.outputFormat, 'wav');
  });

  testWidgets('keeps an existing cloud key when the input is blank', (
    tester,
  ) async {
    VoiceSettingsSubmission? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceSettingsPage(
          initialProfile: VoiceProfile.cloud(
            baseUrl: 'https://example.com',
            model: 'tts-model',
            voice: 'voice-a',
            speed: 1,
            outputFormat: 'mp3',
          ),
          hasSavedCloudApiKey: true,
          onSave: (submission) async => saved = submission,
        ),
      ),
    );

    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(saved?.profile.providerType, SpeechProviderType.cloud);
    expect(saved?.credentials.normalizedApiKey, isNull);
    expect(find.text('已保存，留空则保持不变'), findsOneWidget);
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

    await tester.ensureVisible(find.text('测试连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();

    expect(tested?.profile.style, '自然朗读');
    expect(tested?.credentials.normalizedApiKey, isNull);
    expect(find.text('连接成功，API Key 可用'), findsOneWidget);
  });
}

Future<void> _selectVoiceProvider(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('tts-provider-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
  // The provider card sits below the fold on the default 800x600 surface;
  // scroll the connection button into view so later taps land.
  final connection = find.text('测试连接');
  if (tester.any(connection)) {
    await tester.ensureVisible(connection);
    await tester.pumpAndSettle();
  }
}
