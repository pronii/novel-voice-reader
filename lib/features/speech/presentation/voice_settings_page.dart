import 'package:flutter/material.dart';
import 'package:novel_voice_reader/app/widgets/section_card.dart';
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
    this.initialDiagnosticsEndpoint,
    this.onSaveDiagnosticsEndpoint,
    this.onUploadDiagnostics,
    this.onExportDiagnostics,
  });

  final VoiceProfile? initialProfile;
  final bool hasSavedCloudApiKey;
  final bool hasSavedMiMoApiKey;
  final Future<void> Function(VoiceSettingsSubmission submission)?
  onTestConnection;
  final Future<void> Function(VoiceSettingsSubmission submission)? onSave;

  /// Currently configured diagnostics upload URL, shown in the field.
  final String? initialDiagnosticsEndpoint;

  /// Persists a new diagnostics upload URL (empty clears it). When null, the
  /// whole diagnostics section is hidden.
  final Future<void> Function(String endpoint)? onSaveDiagnosticsEndpoint;

  /// Triggers an immediate upload of buffered diagnostics.
  final Future<void> Function()? onUploadDiagnostics;

  /// Exports the buffered diagnostics (e.g. copies them to the clipboard) for
  /// when no collector is configured. Returns a human-readable result summary.
  final Future<String> Function()? onExportDiagnostics;

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
  final _diagnosticsEndpoint = TextEditingController();

  static const _defaultServerUrl = 'https://tts.ll.993209.xyz:888';

  SpeechProviderType _provider = SpeechProviderType.cloud;
  String _mimoVoice = VoiceProfile.defaultMiMoVoice;
  double _speed = 1;
  bool _saving = false;
  bool _testingConnection = false;
  bool _diagnosticsBusy = false;

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
    _diagnosticsEndpoint.text = widget.initialDiagnosticsEndpoint ?? '';
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
    _diagnosticsEndpoint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cloud =
        _provider == SpeechProviderType.cloud ||
        _provider == SpeechProviderType.server;
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
                value: SpeechProviderType.server,
                child: _ProviderOption(
                  icon: Icons.cloud_outlined,
                  label: '官方服务器',
                ),
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
          if (widget.onSaveDiagnosticsEndpoint != null) ..._diagnosticsFields(),
        ],
      ),
      bottomNavigationBar: StickyActionBar(
        action: FilledButton.icon(
          onPressed: _saving || _testingConnection ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? '保存中' : '保存'),
        ),
      ),
    );
  }

  List<Widget> _diagnosticsFields() {
    return [
      const SizedBox(height: 24),
      const Divider(),
      const SizedBox(height: 8),
      Text('诊断上报', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      const Text(
        '锁屏播放诊断事件会先存在本机，回到前台时上传到下面的地址(任何能接收 '
        'POST JSON 的服务/临时 webhook 都行)。已内置默认上报地址,无需填写;'
        '如需改到自己的服务器可覆盖此地址。',
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('diagnostics-endpoint-field'),
        controller: _diagnosticsEndpoint,
        keyboardType: TextInputType.url,
        enableSuggestions: false,
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: '诊断上报地址',
          hintText: 'https://example.com/collect',
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _diagnosticsBusy ? null : _saveDiagnosticsEndpoint,
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存地址'),
          ),
          if (widget.onUploadDiagnostics != null)
            OutlinedButton.icon(
              onPressed: _diagnosticsBusy ? null : _uploadDiagnostics,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('立即上传'),
            ),
          if (widget.onExportDiagnostics != null)
            OutlinedButton.icon(
              onPressed: _diagnosticsBusy ? null : _exportDiagnostics,
              icon: const Icon(Icons.ios_share),
              label: const Text('导出'),
            ),
        ],
      ),
    ];
  }

  List<Widget> _cloudFields() {
    if (_provider == SpeechProviderType.server) {
      return [
        const SizedBox(height: 12),
        const Text(
          '官方服务器，无需额外配置',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        _connectionButton(),
      ];
    }
    return [
      const SizedBox(height: 12),
      TextField(
        controller: _baseUrl,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
          labelText: 'Base URL',
        ),
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
        isExpanded: true,
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
    setState(() {
      _provider = provider;
    });
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
        SpeechProviderType.server || SpeechProviderType.mimo =>
          SpeechCredentialsInput(apiKey: _mimoApiKey.text),
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
      SpeechProviderType.server => VoiceProfile.server(
        baseUrl: _defaultServerUrl,
        model: VoiceProfile.mimoModel,
        voice: VoiceProfile.defaultMiMoVoice,
        speed: _speed,
        outputFormat: 'wav',
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
      // The self-hosted server can carry the upstream key itself, so it needs
      // no local key.
      SpeechProviderType.server => true,
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

  Future<void> _saveDiagnosticsEndpoint() async {
    final save = widget.onSaveDiagnosticsEndpoint;
    if (save == null || _diagnosticsBusy) return;
    setState(() => _diagnosticsBusy = true);
    try {
      await save(_diagnosticsEndpoint.text.trim());
      _showMessage('诊断上报地址已保存');
    } catch (_) {
      _showMessage('诊断上报地址保存失败');
    } finally {
      if (mounted) setState(() => _diagnosticsBusy = false);
    }
  }

  Future<void> _uploadDiagnostics() async {
    final upload = widget.onUploadDiagnostics;
    if (upload == null || _diagnosticsBusy) return;
    setState(() => _diagnosticsBusy = true);
    try {
      await upload();
      _showMessage('已尝试上传诊断日志');
    } catch (_) {
      _showMessage('诊断日志上传失败');
    } finally {
      if (mounted) setState(() => _diagnosticsBusy = false);
    }
  }

  Future<void> _exportDiagnostics() async {
    final export = widget.onExportDiagnostics;
    if (export == null || _diagnosticsBusy) return;
    setState(() => _diagnosticsBusy = true);
    try {
      final summary = await export();
      _showMessage(summary);
    } catch (_) {
      _showMessage('诊断日志导出失败');
    } finally {
      if (mounted) setState(() => _diagnosticsBusy = false);
    }
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
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label, maxLines: 1, softWrap: false)),
      ],
    );
  }
}
