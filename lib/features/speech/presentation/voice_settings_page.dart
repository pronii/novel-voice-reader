import 'package:flutter/material.dart';
import 'package:novel_voice_reader/core/errors/app_failure.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

final class VoiceSettingsPage extends StatefulWidget {
  const VoiceSettingsPage({super.key, this.onTestConnection, this.onSave});

  final Future<void> Function(VoiceProfile profile, String apiKey)?
  onTestConnection;
  final Future<void> Function(VoiceProfile profile, String? apiKey)? onSave;

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
  SpeechProviderType _provider = SpeechProviderType.system;
  String _zhipuVoice = VoiceProfile.defaultZhipuVoice;
  double _speed = 1;
  bool _saving = false;
  bool _testingConnection = false;

  static const _zhipuVoiceLabels = <String, String>{
    'tongtong': '彤彤 (tongtong)',
    'chuichui': '锤锤 (chuichui)',
    'xiaochen': '小陈 (xiaochen)',
    'jam': 'jam',
    'kazi': 'kazi',
    'douji': 'douji',
    'luodo': 'luodo',
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cloud = _provider == SpeechProviderType.cloud;
    final azure = _provider == SpeechProviderType.azure;
    final zhipu = _provider == SpeechProviderType.zhipu;
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
              ],
              selected: {_provider},
              onSelectionChanged: (values) {
                setState(() => _provider = values.single);
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
          if (cloud) ...[
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
          ],
          if (azure) ...[
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
          ],
          if (zhipu) ...[
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
                if (value != null) {
                  setState(() => _zhipuVoice = value);
                }
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
            OutlinedButton.icon(
              onPressed:
                  widget.onTestConnection == null ||
                      _saving ||
                      _testingConnection
                  ? null
                  : _testConnection,
              icon: const Icon(Icons.wifi_tethering),
              label: Text(_testingConnection ? '测试中' : '测试连接'),
            ),
          ],
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

  Future<void> _save() async {
    if (_saving || _testingConnection) {
      return;
    }
    late final VoiceProfile profile;
    try {
      profile = _buildProfile();
    } on ArgumentError {
      _showMessage(
        _provider == SpeechProviderType.azure
            ? '请输入有效的 Azure Region 和音色'
            : '请检查语音服务配置',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave?.call(profile, switch (_provider) {
        SpeechProviderType.system => null,
        SpeechProviderType.cloud => _apiKey.text.trim(),
        SpeechProviderType.azure => _azureSubscriptionKey.text.trim(),
        SpeechProviderType.zhipu => _zhipuApiKey.text.trim(),
        SpeechProviderType.tencent => null,
      });
      _showMessage('语音设置已保存');
    } catch (_) {
      _showMessage('语音设置保存失败');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _testConnection() async {
    if (_saving || _testingConnection) {
      return;
    }
    final apiKey = _zhipuApiKey.text.trim();
    if (apiKey.isEmpty) {
      _showMessage('请输入智谱 API Key');
      return;
    }
    final profile = VoiceProfile.zhipu(voice: _zhipuVoice, speed: _speed);
    setState(() => _testingConnection = true);
    try {
      await widget.onTestConnection?.call(profile, apiKey);
      _showMessage('连接成功，API Key 可用');
    } on AppFailure catch (failure) {
      _showMessage(failure.message);
    } catch (_) {
      _showMessage('连接测试失败');
    } finally {
      if (mounted) {
        setState(() => _testingConnection = false);
      }
    }
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
      SpeechProviderType.tencent => VoiceProfile.tencent(speed: _speed),
    };
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
