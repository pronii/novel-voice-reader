final class SpeechCredentialsInput {
  const SpeechCredentialsInput({this.apiKey});

  final String? apiKey;

  String? get normalizedApiKey => _normalize(apiKey);

  static String? _normalize(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
