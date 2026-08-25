import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:novel_voice_reader/features/downloads/domain/cache_key.dart';
import 'package:novel_voice_reader/features/speech/domain/speech_segmenter.dart';
import 'package:novel_voice_reader/features/speech/domain/voice_profile.dart';

abstract interface class CloudSpeechSynthesizer {
  Future<Uint8List> synthesize(SpeechSegment segment, VoiceProfile profile);
}

abstract interface class SpeechAudioCache {
  Future<File> obtain(SpeechSegment segment, VoiceProfile profile);
}

enum AudioCacheObtainSource { cacheHit, joinedInFlight, created }

final class AudioCacheObtainResult {
  const AudioCacheObtainResult({required this.file, required this.source});

  final File file;
  final AudioCacheObtainSource source;
}

/// A cache that can answer whether a segment's audio is already on disk without
/// synthesizing it. Implemented by caches whose storage layout the reader
/// controls, so lock-screen playback can prepare cache-only audio and never
/// fall back to a network synth.
abstract interface class LookupSpeechAudioCache {
  /// Returns the cached, validated audio file for [segment] if it already
  /// exists locally, or null on a cache miss. Never synthesizes.
  Future<File?> lookup(SpeechSegment segment, VoiceProfile profile);
}

final class AudioCacheRepository
    implements SpeechAudioCache, LookupSpeechAudioCache {
  const AudioCacheRepository({
    required this.directory,
    required this.synthesizer,
  });

  final Directory directory;
  final CloudSpeechSynthesizer synthesizer;

  @override
  Future<File> obtain(SpeechSegment segment, VoiceProfile profile) async {
    await directory.create(recursive: true);
    final extension = _normalizedExtension(profile.outputFormat);
    final finalFile = _fileFor(segment, profile, extension);
    if (await finalFile.exists()) {
      try {
        await _validateExistingAudio(finalFile, extension);
        return finalFile;
      } on FormatException {
        await finalFile.delete();
      }
    }

    final partial = File('${finalFile.path}.partial');
    if (await partial.exists()) {
      await partial.delete();
    }

    try {
      final bytes = await synthesizer.synthesize(segment, profile);
      _validateAudio(bytes, extension, totalLength: bytes.length);
      await partial.writeAsBytes(bytes, flush: true);
      return await partial.rename(finalFile.path);
    } catch (_) {
      if (await partial.exists()) {
        await partial.delete();
      }
      rethrow;
    }
  }

  @override
  Future<File?> lookup(SpeechSegment segment, VoiceProfile profile) async {
    final extension = _normalizedExtension(profile.outputFormat);
    final finalFile = _fileFor(segment, profile, extension);
    if (!await finalFile.exists()) {
      return null;
    }
    try {
      await _validateExistingAudio(finalFile, extension);
      return finalFile;
    } on FormatException {
      // A corrupt cache entry is treated as a miss; never synthesize here.
      await finalFile.delete();
      return null;
    }
  }

  File _fileFor(
    SpeechSegment segment,
    VoiceProfile profile,
    String extension,
  ) {
    final key = CacheKey.forSegment(segment, profile);
    return File('${directory.path}${Platform.pathSeparator}$key.$extension');
  }

  static String _normalizedExtension(String? outputFormat) {
    final extension = (outputFormat ?? 'mp3').trim().toLowerCase();
    if (extension.endsWith('-mp3')) {
      return 'mp3';
    }
    const supported = {'mp3', 'opus', 'aac', 'flac', 'wav', 'pcm', 'ogg'};
    if (!supported.contains(extension)) {
      throw ArgumentError.value(
        outputFormat,
        'outputFormat',
        'Unsupported audio format.',
      );
    }
    return extension;
  }

  static Future<void> _validateExistingAudio(
    File file,
    String extension,
  ) async {
    final reader = await file.open();
    try {
      final length = await reader.length();
      final header = await reader.read(min(length, 12));
      _validateAudio(header, extension, totalLength: length);
    } finally {
      await reader.close();
    }
  }

  static void _validateAudio(
    Uint8List bytes,
    String extension, {
    required int totalLength,
  }) {
    final valid = switch (extension) {
      'mp3' =>
        _startsWith(bytes, const [0x49, 0x44, 0x33]) ||
            (bytes.length >= 2 &&
                bytes[0] == 0xff &&
                (bytes[1] & 0xe0) == 0xe0),
      'wav' =>
        bytes.length >= 12 &&
            _startsWith(bytes, const [0x52, 0x49, 0x46, 0x46]) &&
            _startsWith(bytes, const [0x57, 0x41, 0x56, 0x45], offset: 8),
      'opus' || 'ogg' => _startsWith(bytes, const [0x4f, 0x67, 0x67, 0x53]),
      'flac' => _startsWith(bytes, const [0x66, 0x4c, 0x61, 0x43]),
      'aac' =>
        bytes.length >= 2 && bytes[0] == 0xff && (bytes[1] & 0xf6) == 0xf0,
      'pcm' => totalLength > 0 && totalLength.isEven,
      _ => false,
    };
    if (!valid) {
      throw FormatException('Cloud TTS returned invalid $extension audio.');
    }
  }

  static bool _startsWith(
    Uint8List bytes,
    List<int> signature, {
    int offset = 0,
  }) {
    if (bytes.length < offset + signature.length) {
      return false;
    }
    for (var index = 0; index < signature.length; index++) {
      if (bytes[offset + index] != signature[index]) {
        return false;
      }
    }
    return true;
  }
}
