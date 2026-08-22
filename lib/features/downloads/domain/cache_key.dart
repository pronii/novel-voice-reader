import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

abstract final class CacheKey {
  // A single "get the audio for this segment" flows the same segment and
  // profile instances through the provider, the runtime, the repository and
  // the store, each of which independently needs the key — recomputing a
  // SHA-256 over up to 360 characters of text four or five times per segment
  // on the playback hot path. Memoise the result per segment instance, guarded
  // by profile identity so a different profile (or a fresh segment instance)
  // recomputes exactly once and a stale key can never be returned. Keyed by
  // identity through an Expando, so the entry is collected with the segment and
  // no unbounded map grows.
  static final Expando<_MemoizedKey> _memo = Expando<_MemoizedKey>('cacheKey');

  static String forSegment(SpeechSegment segment, VoiceProfile profile) {
    final cached = _memo[segment];
    if (cached != null && identical(cached.profile, profile)) {
      return cached.key;
    }
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
      profile.style,
    ]);
    final key = sha256.convert(utf8.encode(canonical)).toString();
    _memo[segment] = _MemoizedKey(profile, key);
    return key;
  }
}

class _MemoizedKey {
  const _MemoizedKey(this.profile, this.key);
  final VoiceProfile profile;
  final String key;
}
