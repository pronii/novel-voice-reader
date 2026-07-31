enum SpeechProviderType { system, cloud }

final class VoiceProfile {
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

  const VoiceProfile._({
    required this.providerType,
    this.baseUrl,
    this.model,
    this.voice,
    required this.speed,
    this.pitch,
    this.outputFormat,
  });

  final SpeechProviderType providerType;
  final String? baseUrl;
  final String? model;
  final String? voice;
  final double speed;
  final double? pitch;
  final String? outputFormat;

  String get normalizedBaseUrl {
    final value = baseUrl;
    if (value == null) {
      return '';
    }
    return value.replaceFirst(RegExp(r'/+$'), '');
  }

  static void _validateSpeed(double speed) {
    if (speed <= 0) {
      throw ArgumentError.value(speed, 'speed', 'Must be positive.');
    }
  }
}
