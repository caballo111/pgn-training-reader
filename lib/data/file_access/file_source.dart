import 'dart:typed_data';

import '../../core/errors/app_failure.dart';
import 'file_source_picker.dart';

/// Operations for reading selected PGN sources and creating durable managed
/// copies. Implementations keep platform objects behind this boundary.
abstract interface class FileSource {
  /// Opens a sequential byte stream. Consumers must cancel the subscription
  /// when they stop before EOF.
  Stream<List<int>> openReadStream(OpaqueSourceReference reference);

  /// Returns the current byte length, or `null` when the provider cannot
  /// determine it reliably. Copying must still work when this is unknown.
  Future<int?> length(OpaqueSourceReference reference);

  /// Reads bytes in `[start, endExclusive)`. Offsets are zero-based byte
  /// offsets, not character offsets. An empty range is valid; invalid or
  /// out-of-bounds ranges fail with [FileFailure]. Implementations
  /// must not return bytes from a different revision of the source silently.
  Future<Uint8List> readRange(
    OpaqueSourceReference reference, {
    required int start,
    required int endExclusive,
  });

  /// Collects stable inputs for a lightweight revision fingerprint. Sample
  /// bytes are taken from the beginning, middle, and end where possible.
  /// Fingerprints are change detectors, not cryptographic identity proofs.
  Future<FileFingerprintInput> fingerprintInput(
    OpaqueSourceReference reference, {
    DateTime? modifiedAt,
    int sampleSize = 4096,
  });

  /// Copies the selected stream into a temporary managed target and promotes
  /// it only after EOF and successful close/verification. On cancellation or
  /// any read/write error the incomplete target is discarded. Implementations
  /// must stream bounded chunks rather than buffer the whole source.
  Future<ManagedCopyResult> copyToManagedStorage(
    OpaqueSourceReference reference, {
    required ManagedCopyTarget target,
    required CopyCancellation cancellation,
    int? expectedLength,
  });
}

/// Destination lifecycle used by [FileSource.copyToManagedStorage]. A target
/// writes to temporary storage until [promote] atomically makes it available.
abstract interface class ManagedCopyTarget {
  /// Appends bytes to the temporary copy.
  Future<void> write(List<int> bytes);

  /// Flushes and closes the temporary copy, then verifies and promotes it.
  /// Returns its opaque persistent reference.
  Future<String> promote({required int bytesWritten});

  /// Closes and removes any unpromoted temporary copy. Safe to call more than
  /// once, including after a failed write.
  Future<void> discard();
}

/// Cooperative cancellation checked between bounded reads and writes.
final class CopyCancellation {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() => _isCancelled = true;
}

/// Properties used as inputs to a cheap source-revision fingerprint.
final class FileFingerprintInput {
  FileFingerprintInput({
    required this.length,
    required this.modifiedAt,
    required List<FingerprintSample> samples,
  }) : samples = List.unmodifiable(
         samples.map(
           (sample) =>
               FingerprintSample(offset: sample.offset, bytes: sample.bytes),
         ),
       );

  final int? length;
  final DateTime? modifiedAt;

  /// Sampled raw bytes, ordered by their zero-based source offset. Overlapping
  /// samples may be deduplicated by an implementation.
  final List<FingerprintSample> samples;
}

/// A byte sample and its location in the source.
final class FingerprintSample {
  FingerprintSample({required this.offset, required Uint8List bytes})
    : bytes = Uint8List.fromList(bytes);

  final int offset;
  final Uint8List bytes;
}

/// Result of a completed managed copy.
final class ManagedCopyResult {
  const ManagedCopyResult({required this.reference, required this.length});

  /// Opaque persistent reference understood by the managed-source adapter.
  final String reference;
  final int length;
}
