import 'dart:convert';

import 'file_source.dart';

/// Builds a stable, inexpensive revision fingerprint from file metadata and
/// sampled source bytes. This is intended to detect ordinary edits before
/// reusing stored byte offsets; it is not an integrity or authenticity hash.
///
/// Collision limitations: changes outside the sampled regions can go
/// undetected when length and modified time also remain unchanged. The
/// 64-bit non-cryptographic result can collide even when sampled bytes differ,
/// so callers must not use it to prove byte-for-byte equality or trust.
final class SourceFingerprint {
  const SourceFingerprint._();

  /// Returns a deterministic 64-bit hexadecimal fingerprint.
  ///
  /// The input contains the source length, optional last-modified time, and
  /// samples (including each sample's byte offset and length). Two independent
  /// 32-bit accumulators are used to avoid adding a crypto dependency to
  /// this small metadata check.
  static String compute(FileFingerprintInput input) {
    final encoder = _FingerprintAccumulator();
    encoder.addString('pgn-source-fingerprint-v1');
    encoder.addNullableInt(input.length);
    final modifiedAt = input.modifiedAt?.toUtc().microsecondsSinceEpoch;
    encoder.addNullableInt(modifiedAt);

    final samples = [...input.samples]
      ..sort((left, right) => left.offset.compareTo(right.offset));
    encoder.addInt(samples.length);
    for (final sample in samples) {
      encoder.addInt(sample.offset);
      encoder.addInt(sample.bytes.length);
      encoder.addBytes(sample.bytes);
    }
    return encoder.finish();
  }
}

/// Small deterministic byte accumulator. Explicit byte encoding keeps the
/// result independent of locale, platform endianness, and Dart's randomized
/// `Object.hash` implementation.
final class _FingerprintAccumulator {
  static const int _mask32 = 0xffffffff;
  static const int _prime = 0x01000193;

  int _first = 0x811c9dc5;
  int _second = 0x9e3779b9;

  void addNullableInt(int? value) {
    if (value == null) {
      addByte(0);
    } else {
      addByte(1);
      addInt(value);
    }
  }

  void addInt(int value) {
    // Signed values (notably pre-epoch timestamps) are encoded as a sign and
    // magnitude, each in a fixed eight-byte big-endian representation.
    addByte(value < 0 ? 1 : 0);
    var magnitude = value.abs();
    final bytes = List<int>.filled(8, 0);
    for (var index = bytes.length - 1; index >= 0; index--) {
      bytes[index] = magnitude & 0xff;
      magnitude >>= 8;
    }
    addBytes(bytes);
  }

  void addString(String value) => addBytes(utf8.encode(value));

  void addBytes(List<int> bytes) {
    for (final byte in bytes) {
      addByte(byte);
    }
  }

  void addByte(int byte) {
    _first = ((_first ^ byte) * _prime) & _mask32;
    _second = ((_second ^ byte) * 0x85ebca6b) & _mask32;
  }

  String finish() =>
      '${_first.toRadixString(16).padLeft(8, '0')}'
      '${_second.toRadixString(16).padLeft(8, '0')}';
}
