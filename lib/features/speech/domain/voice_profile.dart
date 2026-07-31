enum SpeechProviderType { system, cloud, azure }

final class VoiceProfile {
  static const defaultAzureVoice = 'zh-CN-XiaoxiaoNeural';
  static const defaultAzureOutputFormat = 'audio-24khz-48kbitrate-mono-mp3';

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
