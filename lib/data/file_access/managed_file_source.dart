import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/errors/app_failure.dart';
import 'file_source.dart';
import 'file_source_picker.dart';

/// The private provider reference used by the file picker adapter.
///
/// Keeping provider details behind callbacks lets this adapter work with
/// Android document providers without leaking their handles to callers.
abstract interface class PickedSourceAccess {
  Stream<List<int>> openReadStream(OpaqueSourceReference reference);
  Future<int?> length(OpaqueSourceReference reference);
  Future<DateTime?> modifiedAt(OpaqueSourceReference reference);
  Future<Uint8List> readRange(
    OpaqueSourceReference reference, {
    required int start,
    required int endExclusive,
  });
}

/// Opaque stable identifier for a completed copy in application documents.
/// Its value is an internal token, not a filesystem path.
final class ManagedSourceReference implements OpaqueSourceReference {
  factory ManagedSourceReference(String token) {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(token)) {
      throw ArgumentError.value(
        token,
        'token',
        'Invalid managed source token.',
      );
    }
    return ManagedSourceReference._(token);
  }

  const ManagedSourceReference._(this.token);

  final String token;

  @override
  String toString() => 'ManagedSourceReference(<opaque>)';
}

/// Reads picked sources and stores byte-for-byte copies in app-private storage.
final class ManagedFileSource implements FileSource {
  ManagedFileSource({
    required this.pickedSources,
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider = directoryProvider ?? _defaultDirectory;

  static const String _directoryName = 'managed_pgn_sources';

  final PickedSourceAccess pickedSources;
  final Future<Directory> Function() _directoryProvider;

  static Future<Directory> _defaultDirectory() =>
      getApplicationDocumentsDirectory();

  Future<Directory> _managedDirectory() async {
    try {
      final documents = await _directoryProvider();
      final directory = Directory(p.join(documents.path, _directoryName));
      await directory.create(recursive: true);
      return directory;
    } on FileFailure {
      rethrow;
    } on FileSystemException catch (error) {
      if (_isOutOfSpace(error)) {
        throw const FileFailure(
          code: 'insufficient_storage',
          message: 'There is not enough device storage to save this source.',
        );
      }
      throw const FileFailure(
        code: 'managed_storage_unavailable',
        message: 'App storage is unavailable for saving the selected source.',
      );
    } catch (_) {
      throw const FileFailure(
        code: 'managed_storage_unavailable',
        message: 'App storage is unavailable for saving the selected source.',
      );
    }
  }

  Future<File> _fileFor(ManagedSourceReference reference) async {
    // Tokens are generated locally and validated before using them as a path.
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(reference.token)) {
      throw const FileFailure(
        code: 'managed_reference_invalid',
        message: 'The saved local copy reference is invalid.',
      );
    }
    return File(
      p.join((await _managedDirectory()).path, '${reference.token}.pgn'),
    );
  }

  @override
  Stream<List<int>> openReadStream(OpaqueSourceReference reference) async* {
    if (reference is ManagedSourceReference) {
      try {
        final file = await _fileFor(reference);
        if (!await file.exists()) _missingManagedCopy();
        yield* file.openRead();
      } on FileFailure {
        rethrow;
      } on FileSystemException {
        _missingManagedCopy();
      }
      return;
    }
    yield* pickedSources.openReadStream(reference);
  }

  @override
  Future<int?> length(OpaqueSourceReference reference) async {
    if (reference is ManagedSourceReference) {
      final file = await _fileFor(reference);
      try {
        return await file.length();
      } on FileSystemException {
        _missingManagedCopy();
      }
    }
    return pickedSources.length(reference);
  }

  @override
  Future<Uint8List> readRange(
    OpaqueSourceReference reference, {
    required int start,
    required int endExclusive,
  }) async {
    if (start < 0 || endExclusive < start) {
      throw const FileFailure(
        code: 'file_range_invalid',
        message: 'The requested byte range is invalid.',
      );
    }
    if (reference is! ManagedSourceReference) {
      return pickedSources.readRange(
        reference,
        start: start,
        endExclusive: endExclusive,
      );
    }
    final file = await _fileFor(reference);
    RandomAccessFile? handle;
    try {
      handle = await file.open(mode: FileMode.read);
      final size = await handle.length();
      if (endExclusive > size) {
        throw const FileFailure(
          code: 'file_range_out_of_bounds',
          message: 'The requested byte range is outside the saved source.',
        );
      }
      await handle.setPosition(start);
      final bytes = await handle.read(endExclusive - start);
      if (bytes.length != endExclusive - start) _missingManagedCopy();
      return Uint8List.fromList(bytes);
    } on FileFailure {
      rethrow;
    } on FileSystemException {
      _missingManagedCopy();
    } finally {
      await handle?.close();
    }
  }

  @override
  Future<FileFingerprintInput> fingerprintInput(
    OpaqueSourceReference reference, {
    DateTime? modifiedAt,
    int sampleSize = 4096,
  }) async {
    if (sampleSize < 1) {
      throw ArgumentError.value(sampleSize, 'sampleSize', 'Must be positive.');
    }
    final size = await length(reference);
    final actualModified =
        modifiedAt ??
        (reference is ManagedSourceReference
            ? await (await _fileFor(reference)).lastModified()
            : await pickedSources.modifiedAt(reference));
    if (size == null || size == 0) {
      return FileFingerprintInput(
        length: size,
        modifiedAt: actualModified,
        samples: const [],
      );
    }
    final sampleLength = min(sampleSize, size);
    final offsets = <int>{
      0,
      max(0, (size - sampleLength) ~/ 2),
      size - sampleLength,
    };
    final samples = <FingerprintSample>[];
    for (final offset in offsets.toList()..sort()) {
      samples.add(
        FingerprintSample(
          offset: offset,
          bytes: await readRange(
            reference,
            start: offset,
            endExclusive: offset + sampleLength,
          ),
        ),
      );
    }
    return FileFingerprintInput(
      length: size,
      modifiedAt: actualModified,
      samples: samples,
    );
  }

  @override
  Future<ManagedCopyResult> copyToManagedStorage(
    OpaqueSourceReference reference, {
    required ManagedCopyTarget target,
    required CopyCancellation cancellation,
    int? expectedLength,
  }) => copyStreamToManagedTarget(
    openReadStream(reference),
    target,
    cancellation,
    expectedLength: expectedLength,
  );

  /// Makes an isolated target; the final name is unique and never replaces an
  /// existing managed source. Pass this target to [copyToManagedStorage].
  Future<ManagedCopyTarget> createTarget() async {
    try {
      final directory = await _managedDirectory();
      for (var attempt = 0; attempt < 4; attempt++) {
        final token = _newToken();
        final temp = File(p.join(directory.path, '.$token.tmp'));
        final finalFile = File(p.join(directory.path, '$token.pgn'));
        RandomAccessFile? handle;
        var tempCreated = false;
        try {
          await temp.create(exclusive: true);
          tempCreated = true;
          handle = await temp.open(mode: FileMode.write);
          await finalFile.create(exclusive: true);
          return _FileManagedCopyTarget(
            temp: temp,
            finalFile: finalFile,
            handle: handle,
            reference: token,
          );
        } on FileSystemException catch (error) {
          await handle?.close();
          if (tempCreated && await temp.exists()) await temp.delete();
          if (await finalFile.exists()) continue;
          if (_isOutOfSpace(error)) {
            throw const FileFailure(
              code: 'insufficient_storage',
              message:
                  'There is not enough device storage to save this source.',
            );
          }
          rethrow;
        }
      }
      throw const FileFailure(
        code: 'managed_target_unavailable',
        message: 'A safe local copy could not be created. Try again.',
      );
    } on FileFailure {
      rethrow;
    } on FileSystemException catch (error) {
      if (_isOutOfSpace(error)) {
        throw const FileFailure(
          code: 'insufficient_storage',
          message: 'There is not enough device storage to save this source.',
        );
      }
      throw const FileFailure(
        code: 'managed_storage_unavailable',
        message: 'App storage is unavailable for saving the selected source.',
      );
    }
  }

  /// Deletes one app-owned managed copy identified by its opaque token.
  /// External references and caller-supplied paths are never accepted.
  Future<void> deleteManagedCopy(String token) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(token)) {
      throw const FileFailure(
        code: 'managed_reference_invalid',
        message: 'The saved local copy reference is invalid.',
      );
    }
    try {
      final documents = await _directoryProvider();
      final managed = Directory(p.join(documents.path, _directoryName));
      if (!await managed.exists()) return;
      final resolvedRoot = await managed.resolveSymbolicLinks();
      final resolvedDocuments = await documents.resolveSymbolicLinks();
      final expectedRoot = p.normalize(
        p.join(resolvedDocuments, _directoryName),
      );
      if (p.normalize(resolvedRoot) != expectedRoot) {
        throw const FileFailure(
          code: 'managed_root_invalid',
          message: 'The saved local copy is outside app-managed storage.',
        );
      }
      final file = File(p.join(resolvedRoot, '$token.pgn'));
      // File.delete removes a symlink itself rather than following its target.
      if (await file.exists() || await Link(file.path).exists()) {
        await file.delete();
      }
    } on FileFailure {
      rethrow;
    } on FileSystemException {
      throw const FileFailure(
        code: 'managed_cleanup_failed',
        message:
            'The saved local copy could not be deleted. Retry cleanup later.',
      );
    } catch (_) {
      throw const FileFailure(
        code: 'managed_cleanup_failed',
        message:
            'The saved local copy could not be deleted. Retry cleanup later.',
      );
    }
  }

  static String _newToken() {
    final random = Random.secure();
    return List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static bool _isOutOfSpace(FileSystemException error) {
    final code = error.osError?.errorCode;
    return code == 28 || code == 112;
  }

  Never _missingManagedCopy() => throw const FileFailure(
    code: 'managed_source_missing',
    message: 'The saved local copy is unavailable. Re-import the source.',
  );
}

final class _FileManagedCopyTarget implements ManagedCopyTarget {
  _FileManagedCopyTarget({
    required this.temp,
    required this.finalFile,
    required this.handle,
    required this.reference,
  });

  final File temp;
  final File finalFile;
  final String reference;
  RandomAccessFile? handle;
  bool _finished = false;

  @override
  Future<void> write(List<int> bytes) async {
    final current = handle;
    if (_finished || current == null) {
      throw StateError('Copy target is closed.');
    }
    try {
      await current.writeFrom(bytes);
    } on FileSystemException catch (error) {
      if (ManagedFileSource._isOutOfSpace(error)) {
        throw const FileFailure(
          code: 'insufficient_storage',
          message: 'There is not enough device storage to save this source.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<String> promote({required int bytesWritten}) async {
    final current = handle;
    if (_finished || current == null) {
      throw StateError('Copy target is closed.');
    }
    try {
      await current.flush();
      await current.close();
      handle = null;
      final actualLength = await temp.length();
      if (actualLength != bytesWritten) {
        throw const FileFailure(
          code: 'copy_length_mismatch',
          message: 'The saved source did not pass its length check.',
        );
      }
      // The empty final file was exclusively reserved when the target was
      // created, so a collision cannot replace an existing managed copy.
      await temp.rename(finalFile.path);
      _finished = true;
      return reference;
    } on FileSystemException catch (error) {
      if (ManagedFileSource._isOutOfSpace(error)) {
        throw const FileFailure(
          code: 'insufficient_storage',
          message: 'There is not enough device storage to save this source.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> discard() async {
    if (_finished) return;
    _finished = true;
    final current = handle;
    handle = null;
    try {
      await current?.close();
    } on FileSystemException {
      // Continue cleanup even if a failed write already closed the handle.
    }
    try {
      if (await temp.exists()) await temp.delete();
      if (await finalFile.exists()) await finalFile.delete();
    } on FileSystemException {
      // Best-effort cleanup; the unpromoted temp is never exposed as a source.
    }
  }
}

/// Streams bounded chunks into a target, verifies its byte count, and promotes
/// only after successful EOF. The picker adapter can use the same lifecycle.
Future<ManagedCopyResult> copyStreamToManagedTarget(
  Stream<List<int>> stream,
  ManagedCopyTarget target,
  CopyCancellation cancellation, {
  int? expectedLength,
}) async {
  var written = 0;
  var promoted = false;
  try {
    if (cancellation.isCancelled) {
      throw const FileFailure(
        code: 'copy_cancelled',
        message: 'Copying the selected source was cancelled.',
      );
    }
    await for (final chunk in stream) {
      if (cancellation.isCancelled) {
        throw const FileFailure(
          code: 'copy_cancelled',
          message: 'Copying the selected source was cancelled.',
        );
      }
      for (var offset = 0; offset < chunk.length; offset += 64 * 1024) {
        if (cancellation.isCancelled) {
          throw const FileFailure(
            code: 'copy_cancelled',
            message: 'Copying the selected source was cancelled.',
          );
        }
        final end = min(offset + 64 * 1024, chunk.length);
        final part = chunk.sublist(offset, end);
        await target.write(part);
        written += part.length;
      }
    }
    if (cancellation.isCancelled) {
      throw const FileFailure(
        code: 'copy_cancelled',
        message: 'Copying the selected source was cancelled.',
      );
    }
    if (expectedLength != null && expectedLength != written) {
      throw const FileFailure(
        code: 'copy_length_mismatch',
        message:
            'The selected source changed or ended before copying completed.',
      );
    }
    final reference = await target.promote(bytesWritten: written);
    promoted = true;
    return ManagedCopyResult(reference: reference, length: written);
  } on FileSystemException catch (error) {
    if (ManagedFileSource._isOutOfSpace(error)) {
      throw const FileFailure(
        code: 'insufficient_storage',
        message: 'There is not enough device storage to save this source.',
      );
    }
    throw const FileFailure(
      code: 'source_copy_failed',
      message: 'The selected source could not be copied.',
    );
  } on FileFailure {
    rethrow;
  } catch (_) {
    throw const FileFailure(
      code: 'source_copy_failed',
      message: 'The selected source could not be copied.',
    );
  } finally {
    if (!promoted) await target.discard();
  }
}
