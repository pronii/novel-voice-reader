enum SpeechProviderType { system, cloud, mimo }

final class VoiceProfile {
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

  int get maxSegmentCharacters => switch (providerType) {
    SpeechProviderType.mimo => 360,
    _ => 1000,
  };

  static void _validateSpeed(double speed) {
    if (speed <= 0) {
      throw ArgumentError.value(speed, 'speed', 'Must be positive.');
    }
  }
}
