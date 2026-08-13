final class SpeechCredentialsInput {
  const SpeechCredentialsInput({this.apiKey, this.secretId, this.secretKey});

  final String? apiKey;
  final String? secretId;
  final String? secretKey;

  String? get normalizedApiKey => _normalize(apiKey);

  String? get normalizedSecretId => _normalize(secretId);

  String? get normalizedSecretKey => _normalize(secretKey);

  static String? _normalize(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
