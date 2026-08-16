import 'package:flutter/material.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_credentials_input.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

final class VoiceSettingsSubmission {
  const VoiceSettingsSubmission({
    required this.profile,
    required this.credentials,
  });

  final VoiceProfile profile;
  final SpeechCredentialsInput credentials;
}

final class VoiceSettingsPage extends StatefulWidget {
  const VoiceSettingsPage({
    super.key,
    this.initialProfile,
    this.hasSavedCloudApiKey = false,
    this.hasSavedMiMoApiKey = false,
    this.onTestConnection,
    this.onSave,
  });

  final VoiceProfile? initialProfile;
  final bool hasSavedCloudApiKey;
  final bool hasSavedMiMoApiKey;
  final Future<void> Function(VoiceSettingsSubmission submission)?
  onTestConnection;
  final Future<void> Function(VoiceSettingsSubmission submission)? onSave;

  @override
  State<VoiceSettingsPage> createState() => _VoiceSettingsPageState();
}

final class _VoiceSettingsPageState extends State<VoiceSettingsPage> {
  final _baseUrl = TextEditingController(text: 'https://api.openai.com');
  final _model = TextEditingController(text: 'gpt-4o-mini-tts');
  final _voice = TextEditingController(text: 'alloy');
  final _apiKey = TextEditingController();
  final _mimoApiKey = TextEditingController();
  final _mimoStyle = TextEditingController();

  SpeechProviderType _provider = SpeechProviderType.cloud;
  String _mimoVoice = VoiceProfile.defaultMiMoVoice;
  double _speed = 1;
  bool _saving = false;
  bool _testingConnection = false;

  static const _mimoVoiceLabels = <String, String>{
    '冰糖': '冰糖（中文女声）',
    '茉莉': '茉莉（中文女声）',
    '苏打': '苏打（中文男声）',
    '白桦': '白桦（中文男声）',
    'Mia': 'Mia（英文女声）',
    'Chloe': 'Chloe（英文女声）',
    'Milo': 'Milo（英文男声）',
    'Dean': 'Dean（英文男声）',
  };

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    if (profile == null) return;
    _provider = profile.providerType;
    _speed = profile.speed;
    if (profile.providerType == SpeechProviderType.mimo) {
      _mimoVoice = profile.voice ?? VoiceProfile.defaultMiMoVoice;
      _mimoStyle.text = profile.style ?? '';
    } else if (profile.providerType == SpeechProviderType.cloud) {
      // Restore the saved cloud endpoint config so reopening settings doesn't
      // silently revert to the hardcoded defaults.
      final baseUrl = profile.baseUrl;
      final model = profile.model;
      final voice = profile.voice;
      if (baseUrl != null && baseUrl.isNotEmpty) _baseUrl.text = baseUrl;
      if (model != null && model.isNotEmpty) _model.text = model;
      if (voice != null && voice.isNotEmpty) _voice.text = voice;
    }
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _voice.dispose();
    _apiKey.dispose();
    _mimoApiKey.dispose();
    _mimoStyle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cloud = _provider == SpeechProviderType.cloud;
    final mimo = _provider == SpeechProviderType.mimo;
    return Scaffold(
      appBar: AppBar(title: const Text('语音设置')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<SpeechProviderType>(
            key: const Key('tts-provider-dropdown'),
            initialValue: _provider,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '语音服务'),
            items: const [
              DropdownMenuItem(
                value: SpeechProviderType.cloud,
                child: _ProviderOption(icon: Icons.cloud_outlined, label: '兼容'),
              ),
              DropdownMenuItem(
                value: SpeechProviderType.mimo,
                child: _ProviderOption(
                  icon: Icons.auto_awesome_outlined,
                  label: 'MiMo',
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) _selectProvider(value);
            },
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
          if (mimo) ..._mimoFields(),
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
        decoration: InputDecoration(
          labelText: 'API Key',
          helperText: widget.hasSavedCloudApiKey ? '已保存，留空则保持不变' : null,
        ),
      ),
    ];
  }

  List<Widget> _mimoFields() {
    return [
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _mimoVoice,
        decoration: const InputDecoration(labelText: '音色'),
        items: [
          for (final voice in VoiceProfile.mimoVoices)
            DropdownMenuItem(
              value: voice,
              child: Text(_mimoVoiceLabels[voice] ?? voice),
            ),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _mimoVoice = value);
        },
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _mimoStyle,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: '朗读风格（可选）',
          hintText: '例如：沉稳、有磁性，语速稍慢，根据剧情自然调整情绪。',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _mimoApiKey,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: 'MiMo API Key',
          helperText: widget.hasSavedMiMoApiKey ? '已保存，留空则保持不变' : null,
        ),
      ),
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

  void _selectProvider(SpeechProviderType provider) {
    setState(() => _provider = provider);
  }

  Future<void> _save() async {
    if (_saving || _testingConnection) return;
    final submission = _validatedSubmission();
    if (submission == null) return;
    if (!_hasUsableCredential(submission)) return;
    setState(() => _saving = true);
    try {
      await widget.onSave?.call(submission);
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
    if (!_hasUsableCredential(submission)) return;
    setState(() => _testingConnection = true);
    try {
      await widget.onTestConnection?.call(submission);
      _showMessage('连接成功，API Key 可用');
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
    } on ArgumentError {
      _showMessage('请检查语音服务配置');
      return null;
    }
    return VoiceSettingsSubmission(
      profile: profile,
      credentials: switch (_provider) {
        SpeechProviderType.cloud => SpeechCredentialsInput(
          apiKey: _apiKey.text,
        ),
        SpeechProviderType.mimo => SpeechCredentialsInput(
          apiKey: _mimoApiKey.text,
        ),
      },
    );
  }

  VoiceProfile _buildProfile() {
    return switch (_provider) {
      SpeechProviderType.cloud => VoiceProfile.cloud(
        baseUrl: _baseUrl.text,
        model: _model.text,
        voice: _voice.text,
        speed: _speed,
        outputFormat: 'mp3',
      ),
      SpeechProviderType.mimo => VoiceProfile.mimo(
        voice: _mimoVoice,
        style: _mimoStyle.text,
        speed: _speed,
      ),
    };
  }

  bool _hasUsableCredential(VoiceSettingsSubmission submission) {
    if (submission.credentials.normalizedApiKey != null) return true;
    final saved = switch (_provider) {
      SpeechProviderType.cloud => widget.hasSavedCloudApiKey,
      SpeechProviderType.mimo => widget.hasSavedMiMoApiKey,
    };
    if (!saved) {
      _showMessage(
        _provider == SpeechProviderType.mimo
            ? '请输入 MiMo API Key'
            : '请输入云端语音 API Key',
      );
    }
    return saved;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _ProviderOption extends StatelessWidget {
  const _ProviderOption({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
    );
  }
}
