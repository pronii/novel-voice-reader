import 'dart:async';

import 'package:flutter/material.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/features/speech/data/tencent_tts_usage_repository.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_credentials_input.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

enum TencentCredentialField { secretId, secretKey }

final class VoiceSettingsSubmission {
  const VoiceSettingsSubmission({
    required this.profile,
    required this.credentials,
    this.monthlyQuotaCharacters,
  });

  final VoiceProfile profile;
  final SpeechCredentialsInput credentials;
  final int? monthlyQuotaCharacters;
}

final class VoiceSettingsPage extends StatefulWidget {
  const VoiceSettingsPage({
    super.key,
    this.onTestConnection,
    this.onSave,
    this.onLoadTencentUsage,
    this.onClearTencentCredential,
  });

  final Future<void> Function(VoiceSettingsSubmission submission)?
  onTestConnection;
  final Future<void> Function(VoiceSettingsSubmission submission)? onSave;
  final Future<TencentTtsUsageSnapshot> Function()? onLoadTencentUsage;
  final Future<void> Function(TencentCredentialField field)?
  onClearTencentCredential;

  @override
  State<VoiceSettingsPage> createState() => _VoiceSettingsPageState();
}

final class _VoiceSettingsPageState extends State<VoiceSettingsPage> {
  final _baseUrl = TextEditingController(text: 'https://api.openai.com');
  final _model = TextEditingController(text: 'gpt-4o-mini-tts');
  final _voice = TextEditingController(text: 'alloy');
  final _apiKey = TextEditingController();
  final _azureRegion = TextEditingController(text: 'eastasia');
  final _azureVoice = TextEditingController(
    text: VoiceProfile.defaultAzureVoice,
  );
  final _azureSubscriptionKey = TextEditingController();
  final _zhipuApiKey = TextEditingController();
  final _tencentSecretId = TextEditingController();
  final _tencentSecretKey = TextEditingController();
  final _tencentCustomVoice = TextEditingController();
  final _tencentQuota = TextEditingController();

  SpeechProviderType _provider = SpeechProviderType.system;
  String _zhipuVoice = VoiceProfile.defaultZhipuVoice;
  String _tencentVoice = '1001';
  double _speed = 1;
  bool _saving = false;
  bool _testingConnection = false;
  bool _loadingTencentUsage = false;
  bool _quotaTouched = false;
  TencentTtsUsageSnapshot? _tencentUsage;

  static const _zhipuVoiceLabels = <String, String>{
    'tongtong': '彤彤 (tongtong)',
    'chuichui': '锤锤 (chuichui)',
    'xiaochen': '小陈 (xiaochen)',
    'jam': 'jam',
    'kazi': 'kazi',
    'douji': 'douji',
    'luodo': 'luodo',
  };

  static const _tencentVoices = <String, String>{
    '1001': '1001（推荐）',
    '1002': '1002',
    '1004': '1004',
    'custom': '自定义 VoiceType',
  };

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _voice.dispose();
    _apiKey.dispose();
    _azureRegion.dispose();
    _azureVoice.dispose();
    _azureSubscriptionKey.dispose();
    _zhipuApiKey.dispose();
    _tencentSecretId.dispose();
    _tencentSecretKey.dispose();
    _tencentCustomVoice.dispose();
    _tencentQuota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cloud = _provider == SpeechProviderType.cloud;
    final azure = _provider == SpeechProviderType.azure;
    final zhipu = _provider == SpeechProviderType.zhipu;
    final tencent = _provider == SpeechProviderType.tencent;
    return Scaffold(
      appBar: AppBar(title: const Text('语音设置')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<SpeechProviderType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: SpeechProviderType.system,
                  icon: Icon(Icons.phone_android),
                  label: Text('系统'),
                ),
                ButtonSegment(
                  value: SpeechProviderType.cloud,
                  icon: Icon(Icons.cloud_outlined),
                  label: Text('兼容'),
                ),
                ButtonSegment(
                  value: SpeechProviderType.azure,
                  icon: Icon(Icons.cloud_queue),
                  label: Text('Azure'),
                ),
                ButtonSegment(
                  value: SpeechProviderType.zhipu,
                  icon: Icon(Icons.record_voice_over_outlined),
                  label: Text('智谱'),
                ),
                ButtonSegment(
                  value: SpeechProviderType.tencent,
                  icon: Icon(Icons.graphic_eq),
                  label: Text('腾讯云'),
                ),
              ],
              selected: {_provider},
              onSelectionChanged: (values) {
                _selectProvider(values.single);
              },
            ),
          ),
          const SizedBox(height: 24),
          Text('语速 ${_speed.toStringAsFixed(1)}x'),
          Slider(
            value: _speed,
            min: 0.5,
            max: 2,
            divisions: 15,
            label: _speed.toStringAsFixed(1),
            onChanged: (value) => setState(() => _speed = value),
          ),
          if (cloud) ..._cloudFields(),
          if (azure) ..._azureFields(),
          if (zhipu) ..._zhipuFields(),
          if (tencent) ..._tencentFields(),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving || _testingConnection ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? '保存中' : '保存'),
          ),
        ],
      ),
    );
  }

  List<Widget> _cloudFields() {
    return [
      const SizedBox(height: 12),
      TextField(
        controller: _baseUrl,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(labelText: 'Base URL'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _model,
        decoration: const InputDecoration(labelText: '模型'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _voice,
        decoration: const InputDecoration(labelText: '音色'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _apiKey,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        decoration: const InputDecoration(labelText: 'API Key'),
      ),
    ];
  }

  List<Widget> _azureFields() {
    return [
      const SizedBox(height: 12),
      TextField(
        controller: _azureRegion,
        decoration: const InputDecoration(labelText: 'Azure Region'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _azureVoice,
        decoration: const InputDecoration(labelText: '音色'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _azureSubscriptionKey,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        decoration: const InputDecoration(labelText: 'Subscription Key'),
      ),
    ];
  }

  List<Widget> _zhipuFields() {
    return [
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _zhipuVoice,
        decoration: const InputDecoration(labelText: '音色'),
        items: [
          for (final voice in VoiceProfile.zhipuVoices)
            DropdownMenuItem(
              value: voice,
              child: Text(_zhipuVoiceLabels[voice] ?? voice),
            ),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _zhipuVoice = value);
        },
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _zhipuApiKey,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        decoration: const InputDecoration(labelText: 'API Key'),
      ),
      const SizedBox(height: 12),
      _connectionButton(),
    ];
  }

  List<Widget> _tencentFields() {
    return [
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _tencentVoice,
        decoration: const InputDecoration(labelText: '音色'),
        items: [
          for (final entry in _tencentVoices.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _tencentVoice = value);
        },
      ),
      if (_tencentVoice == 'custom') ...[
        const SizedBox(height: 12),
        TextField(
          controller: _tencentCustomVoice,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '自定义 VoiceType'),
        ),
      ],
      const SizedBox(height: 12),
      TextField(
        controller: _tencentSecretId,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: 'SecretId',
          suffixIcon: IconButton(
            tooltip: '清除 SecretId',
            onPressed: () =>
                _clearTencentCredential(TencentCredentialField.secretId),
            icon: const Icon(Icons.clear),
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _tencentSecretKey,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: 'SecretKey',
          suffixIcon: IconButton(
            tooltip: '清除 SecretKey',
            onPressed: () =>
                _clearTencentCredential(TencentCredentialField.secretKey),
            icon: const Icon(Icons.clear),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '请使用专用腾讯云子账号，并仅授予最小 TTS 权限。',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _tencentQuota,
        keyboardType: TextInputType.number,
        onChanged: (_) => _quotaTouched = true,
        decoration: const InputDecoration(labelText: '每月免费额度（字符）'),
      ),
      const SizedBox(height: 16),
      _tencentUsageStatus(),
      const SizedBox(height: 12),
      _connectionButton(),
    ];
  }

  Widget _connectionButton() {
    return OutlinedButton.icon(
      onPressed:
          widget.onTestConnection == null || _saving || _testingConnection
          ? null
          : _testConnection,
      icon: const Icon(Icons.wifi_tethering),
      label: Text(_testingConnection ? '测试中' : '测试连接'),
    );
  }

  Widget _tencentUsageStatus() {
    final usage = _tencentUsage;
    final used = usage?.usedCharacters ?? 0;
    final quota = usage?.quotaCharacters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Row(
          children: [
            const Expanded(
              child: Text(
                '本机估算',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: '刷新本机估算',
              onPressed:
                  widget.onLoadTencentUsage == null || _loadingTencentUsage
                  ? null
                  : _refreshTencentUsage,
              icon: _loadingTencentUsage
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        Text('本月已用：$used 字符'),
        if (quota == null)
          const Text('尚未设置月度额度')
        else ...[
          Text('估算剩余：${usage!.remainingCharacters} 字符'),
          Text('月度额度：$quota 字符'),
          if (usage.overageCharacters > 0)
            Text('已超出：${usage.overageCharacters} 字符'),
        ],
        if (usage != null) Text('更新：${_formatTime(usage.updatedAt)}'),
      ],
    );
  }

  void _selectProvider(SpeechProviderType provider) {
    setState(() => _provider = provider);
    if (provider == SpeechProviderType.tencent) {
      unawaited(_refreshTencentUsage());
    }
  }

  Future<void> _save() async {
    if (_saving || _testingConnection) return;
    final submission = _validatedSubmission();
    if (submission == null) return;
    setState(() => _saving = true);
    try {
      await widget.onSave?.call(submission);
      if (_provider == SpeechProviderType.tencent) {
        await _refreshTencentUsage();
      }
      _showMessage('语音设置已保存');
    } catch (_) {
      _showMessage('语音设置保存失败');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    if (_saving || _testingConnection) return;
    final submission = _validatedSubmission();
    if (submission == null) return;
    if (_provider == SpeechProviderType.zhipu &&
        submission.credentials.normalizedApiKey == null) {
      _showMessage('请输入智谱 API Key');
      return;
    }
    if (_provider == SpeechProviderType.tencent &&
        (submission.credentials.normalizedSecretId == null ||
            submission.credentials.normalizedSecretKey == null)) {
      _showMessage('请输入腾讯云 SecretId 和 SecretKey');
      return;
    }
    setState(() => _testingConnection = true);
    try {
      await widget.onTestConnection?.call(submission);
      _showMessage(
        _provider == SpeechProviderType.tencent
            ? '连接成功，腾讯云凭据可用'
            : '连接成功，API Key 可用',
      );
      if (_provider == SpeechProviderType.tencent) {
        await _refreshTencentUsage();
      }
    } on AppFailure catch (failure) {
      _showMessage(failure.message);
    } catch (_) {
      _showMessage('连接测试失败');
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  VoiceSettingsSubmission? _validatedSubmission() {
    late final VoiceProfile profile;
    try {
      profile = _buildProfile();
    } on FormatException {
      _showMessage('请输入有效的数字 VoiceType');
      return null;
    } on ArgumentError {
      _showMessage(switch (_provider) {
        SpeechProviderType.azure => '请输入有效的 Azure Region 和音色',
        SpeechProviderType.tencent => '请输入有效的数字 VoiceType',
        _ => '请检查语音服务配置',
      });
      return null;
    }
    int? quota;
    if (_provider == SpeechProviderType.tencent) {
      final text = _tencentQuota.text.trim();
      quota = text.isEmpty ? null : int.tryParse(text);
      if (text.isNotEmpty && (quota == null || quota < 0)) {
        _showMessage('请输入有效的月度额度');
        return null;
      }
    }
    return VoiceSettingsSubmission(
      profile: profile,
      credentials: switch (_provider) {
        SpeechProviderType.system => const SpeechCredentialsInput(),
        SpeechProviderType.cloud => SpeechCredentialsInput(
          apiKey: _apiKey.text,
        ),
        SpeechProviderType.azure => SpeechCredentialsInput(
          apiKey: _azureSubscriptionKey.text,
        ),
        SpeechProviderType.zhipu => SpeechCredentialsInput(
          apiKey: _zhipuApiKey.text,
        ),
        SpeechProviderType.tencent => SpeechCredentialsInput(
          secretId: _tencentSecretId.text,
          secretKey: _tencentSecretKey.text,
        ),
      },
      monthlyQuotaCharacters: quota,
    );
  }

  VoiceProfile _buildProfile() {
    return switch (_provider) {
      SpeechProviderType.system => VoiceProfile.system(speed: _speed),
      SpeechProviderType.cloud => VoiceProfile.cloud(
        baseUrl: _baseUrl.text,
        model: _model.text,
        voice: _voice.text,
        speed: _speed,
        outputFormat: 'mp3',
      ),
      SpeechProviderType.azure => VoiceProfile.azure(
        region: _azureRegion.text,
        voice: _azureVoice.text,
        speed: _speed,
      ),
      SpeechProviderType.zhipu => VoiceProfile.zhipu(
        voice: _zhipuVoice,
        speed: _speed,
      ),
      SpeechProviderType.tencent => VoiceProfile.tencent(
        voiceType: _tencentVoice == 'custom'
            ? int.parse(_tencentCustomVoice.text.trim())
            : int.parse(_tencentVoice),
        speed: _speed,
      ),
    };
  }

  Future<void> _refreshTencentUsage() async {
    final loader = widget.onLoadTencentUsage;
    if (loader == null || _loadingTencentUsage) return;
    setState(() => _loadingTencentUsage = true);
    try {
      final usage = await loader();
      if (!mounted) return;
      setState(() {
        _tencentUsage = usage;
        if (!_quotaTouched) {
          _tencentQuota.text = usage.quotaCharacters?.toString() ?? '';
        }
      });
    } catch (_) {
      _showMessage('本机额度记录读取失败');
    } finally {
      if (mounted) setState(() => _loadingTencentUsage = false);
    }
  }

  Future<void> _clearTencentCredential(TencentCredentialField field) async {
    switch (field) {
      case TencentCredentialField.secretId:
        _tencentSecretId.clear();
      case TencentCredentialField.secretKey:
        _tencentSecretKey.clear();
    }
    try {
      await widget.onClearTencentCredential?.call(field);
    } catch (_) {
      _showMessage('腾讯云凭据清除失败');
    }
  }

  static String _formatTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
