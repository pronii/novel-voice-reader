import 'package:flutter/material.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

final class VoiceSettingsPage extends StatefulWidget {
  const VoiceSettingsPage({super.key, this.onSave});

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
  SpeechProviderType _provider = SpeechProviderType.system;
  double _speed = 1;
  bool _saving = false;

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _voice.dispose();
    _apiKey.dispose();
    _azureRegion.dispose();
    _azureVoice.dispose();
    _azureSubscriptionKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cloud = _provider == SpeechProviderType.cloud;
    final azure = _provider == SpeechProviderType.azure;
    return Scaffold(
      appBar: AppBar(title: const Text('语音设置')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<SpeechProviderType>(
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
            ],
            selected: {_provider},
            onSelectionChanged: (values) {
              setState(() => _provider = values.single);
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
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? '保存中' : '保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final profile = switch (_provider) {
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
    };
    setState(() => _saving = true);
    try {
      await widget.onSave?.call(profile, switch (_provider) {
        SpeechProviderType.system => null,
        SpeechProviderType.cloud => _apiKey.text,
        SpeechProviderType.azure => _azureSubscriptionKey.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('语音设置已保存')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
