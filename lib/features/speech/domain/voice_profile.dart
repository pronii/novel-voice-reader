enum SpeechProviderType { system, cloud, mimo }

final class VoiceProfile {
  static const _cloudOutputFormats = <String>{
    'mp3',
    'opus',
    'aac',
    'flac',
    'wav',
    'pcm',
    'ogg',
  };
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
    _validatePitch(pitch);
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
    final normalizedBaseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalizedBaseUrl);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Invalid HTTP(S) URL.');
    }
    final normalizedModel = model.trim();
    final normalizedVoice = voice.trim();
    final normalizedFormat = outputFormat.trim().toLowerCase();
    if (normalizedModel.isEmpty) {
      throw ArgumentError.value(model, 'model', 'Must not be empty.');
    }
    if (normalizedVoice.isEmpty) {
      throw ArgumentError.value(voice, 'voice', 'Must not be empty.');
    }
    if (!_cloudOutputFormats.contains(normalizedFormat) &&
        !normalizedFormat.endsWith('-mp3')) {
      throw ArgumentError.value(
        outputFormat,
        'outputFormat',
        'Unsupported audio format.',
      );
    }
    return VoiceProfile._(
      providerType: SpeechProviderType.cloud,
      baseUrl: normalizedBaseUrl,
      model: normalizedModel,
      voice: normalizedVoice,
      speed: speed,
      outputFormat: normalizedFormat,
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
    return value;
  }

  int get maxSegmentCharacters => switch (providerType) {
    SpeechProviderType.mimo => 360,
    _ => 1000,
  };

  static void _validateSpeed(double speed) {
    if (!speed.isFinite || speed <= 0) {
      throw ArgumentError.value(speed, 'speed', 'Must be positive.');
    }
  }

  static void _validatePitch(double pitch) {
    if (!pitch.isFinite || pitch <= 0) {
      throw ArgumentError.value(pitch, 'pitch', 'Must be positive.');
    }
  }
}
