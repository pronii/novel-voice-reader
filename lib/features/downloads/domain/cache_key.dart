import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

abstract final class CacheKey {
  static String forSegment(SpeechSegment segment, VoiceProfile profile) {
    final canonical = jsonEncode([
      'v1',
      segment.id,
      segment.paragraphId,
      segment.text,
      profile.normalizedBaseUrl,
      profile.model,
      profile.voice,
      profile.speed,
      profile.outputFormat,
    ]);
    return sha256.convert(utf8.encode(canonical)).toString();
  }
}
