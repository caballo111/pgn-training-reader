import 'dart:math';

/// Creates stable identifiers for persisted application entities.
abstract interface class IdGenerator {
  String generateId();
}

/// Generates RFC 4122 version 4 UUIDs using a secure random source by default.
///
/// A [Random] can be supplied to make consumers deterministic in tests. The
/// default source is cryptographically secure for identifiers that may be
/// persisted or shared outside the current process.
final class RandomIdGenerator implements IdGenerator {
  RandomIdGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  @override
  String generateId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
