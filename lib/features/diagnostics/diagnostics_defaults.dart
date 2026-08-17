/// The collector the app ships with, so playback diagnostics upload out of the
/// box with no manual setup. A value saved in Settings overrides it; it can also
/// be changed at build time via `--dart-define=NVR_TELEMETRY_ENDPOINT=...`.
///
/// Diagnostic metadata only (playback state, error types, timestamps, platform);
/// never book text, TTS input, or secrets.
const String kBuiltInTelemetryEndpoint = String.fromEnvironment(
  'NVR_TELEMETRY_ENDPOINT',
  defaultValue: 'http://45.136.28.241/nvr/collect',
);

/// Shared secret gating the public collector. Not a credential to any paid or
/// sensitive service, so shipping it in the client is acceptable. Overridable
/// via `--dart-define=NVR_TELEMETRY_TOKEN=...`.
const String kBuiltInTelemetryToken = String.fromEnvironment(
  'NVR_TELEMETRY_TOKEN',
  defaultValue: 'zBoaef6P9R9MQV39ZVE7Kolh6NaLuURo',
);
