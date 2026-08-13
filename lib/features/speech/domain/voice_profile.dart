enum SpeechProviderType { system, cloud, azure, zhipu, tencent, mimo }

final class VoiceProfile {
  static const defaultAzureVoice = 'zh-CN-XiaoxiaoNeural';
  static const defaultAzureOutputFormat = 'audio-24khz-48kbitrate-mono-mp3';
  static const zhipuBaseUrl = 'https://open.bigmodel.cn/api/paas/v4';
  static const zhipuModel = 'glm-tts';
  static const zhipuOutputFormat = 'wav';
  static const tencentBaseUrl = 'https://tts.tencentcloudapi.com';
  static const defaultTencentVoiceType = 1001;
  static const defaultZhipuVoice = 'tongtong';
  static const mimoBaseUrl = 'https://api.xiaomimimo.com';
  static const mimoModel = 'mimo-v2.5-tts';
  static const defaultMiMoVoice = '冰糖';
  static const mimoVoices = <String>[
    '冰糖',
    '茉莉',
    '苏打',
    '白桦',
    'Mia',
    'Chloe',
    'Milo',
    'Dean',
  ];
  static const zhipuVoices = <String>[
    'tongtong',
    'chuichui',
    'xiaochen',
    'jam',
    'kazi',
    'douji',
    'luodo',
  ];

  factory VoiceProfile.system({
    String? voice,
    double speed = 1,
    double pitch = 1,
  }) {
    _validateSpeed(speed);
    return VoiceProfile._(
      providerType: SpeechProviderType.system,
      voice: voice,
      speed: speed,
      pitch: pitch,
    );
  }

  factory VoiceProfile.cloud({
    required String baseUrl,
    required String model,
    required String voice,
    required double speed,
    required String outputFormat,
  }) {
    _validateSpeed(speed);
    return VoiceProfile._(
      providerType: SpeechProviderType.cloud,
      baseUrl: baseUrl,
      model: model,
      voice: voice,
      speed: speed,
      outputFormat: outputFormat,
    );
  }

  factory VoiceProfile.azure({
    required String region,
    String voice = defaultAzureVoice,
    double speed = 1,
    String outputFormat = defaultAzureOutputFormat,
  }) {
    _validateSpeed(speed);
    final normalizedRegion = region.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(normalizedRegion)) {
      throw ArgumentError.value(region, 'region', 'Must be an Azure region.');
    }
    final normalizedVoice = voice.trim();
    if (normalizedVoice.isEmpty) {
      throw ArgumentError.value(voice, 'voice', 'Must not be empty.');
    }
    return VoiceProfile._(
      providerType: SpeechProviderType.azure,
      baseUrl: 'https://$normalizedRegion.tts.speech.microsoft.com',
      voice: normalizedVoice,
      speed: speed,
      outputFormat: outputFormat.trim(),
    );
  }

  factory VoiceProfile.zhipu({
    String voice = defaultZhipuVoice,
    double speed = 1,
  }) {
    _validateSpeed(speed);
    final normalizedVoice = voice.trim().toLowerCase();
    if (!zhipuVoices.contains(normalizedVoice)) {
      throw ArgumentError.value(voice, 'voice', 'Unsupported Zhipu voice.');
    }
    return VoiceProfile._(
      providerType: SpeechProviderType.zhipu,
      baseUrl: zhipuBaseUrl,
      model: zhipuModel,
      voice: normalizedVoice,
      speed: speed,
      outputFormat: zhipuOutputFormat,
    );
  }

  factory VoiceProfile.tencent({
    int voiceType = defaultTencentVoiceType,
    double speed = 1,
  }) {
    _validateSpeed(speed);
    if (voiceType <= 0) {
      throw ArgumentError.value(voiceType, 'voiceType', 'Must be positive.');
    }
    return VoiceProfile._(
      providerType: SpeechProviderType.tencent,
      baseUrl: tencentBaseUrl,
      model: '1',
      voice: voiceType.toString(),
      speed: speed,
      outputFormat: 'mp3',
    );
  }

  factory VoiceProfile.mimo({
    String voice = defaultMiMoVoice,
    String? style,
    double speed = 1,
  }) {
    _validateSpeed(speed);
    final normalizedVoice = voice.trim();
    if (!mimoVoices.contains(normalizedVoice)) {
      throw ArgumentError.value(voice, 'voice', 'Unsupported MiMo voice.');
    }
    final normalizedStyle = style?.trim();
    return VoiceProfile._(
      providerType: SpeechProviderType.mimo,
      baseUrl: mimoBaseUrl,
      model: mimoModel,
      voice: normalizedVoice,
      speed: speed,
      outputFormat: 'wav',
      style: normalizedStyle == null || normalizedStyle.isEmpty
          ? null
          : normalizedStyle,
    );
  }

  const VoiceProfile._({
    required this.providerType,
    this.baseUrl,
    this.model,
    this.voice,
    required this.speed,
    this.pitch,
    this.outputFormat,
    this.style,
  });

  final SpeechProviderType providerType;
  final String? baseUrl;
  final String? model;
  final String? voice;
  final double speed;
  final double? pitch;
  final String? outputFormat;
  final String? style;

  String get normalizedBaseUrl {
    final value = baseUrl;
    if (value == null) {
      return '';
    }
    return value.replaceFirst(RegExp(r'/+$'), '');
  }

  int get maxSegmentCharacters =>
      switch (providerType) {
        SpeechProviderType.tencent => 150,
        SpeechProviderType.mimo => 360,
        _ => 1000,
      };

  static void _validateSpeed(double speed) {
    if (speed <= 0) {
      throw ArgumentError.value(speed, 'speed', 'Must be positive.');
    }
  }
}
