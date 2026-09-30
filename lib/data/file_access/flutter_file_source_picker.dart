import 'dart:async';
import 'dart:typed_data';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../../core/errors/app_failure.dart';
import 'managed_file_source.dart';
import 'file_source_picker.dart';

/// `file_picker` adapter for choosing a PGN document and reading it on demand.
///
/// The plugin owns the native document handle. It is retained only inside the
/// file-access layer and is never exposed as a path or URI to callers.
final class FlutterFileSourcePicker implements FileSourcePicker {
  const FlutterFileSourcePicker({this.pickFile});

  /// Optional seam for tests and hosts that provide their own picker UI.
  final Future<PlatformFile?> Function()? pickFile;

  @override
  Future<SelectedFileSource?> pickPgnSource() async {
    try {
      final picked = await (pickFile?.call() ?? _pickPgn());
      if (picked == null) return null;

      final reference = _PickedFileReference(picked);
      return SelectedFileSource(
        reference: reference,
        displayName: picked.name,
        lengthBytes: await _reportedLength(picked),
        mimeType: 'application/x-chess-pgn',
      );
    } on FileFailure {
      rethrow;
    } catch (_) {
      throw const FileFailure(
        code: 'file_selection_failed',
        message: 'The PGN file could not be selected. Try again.',
      );
    }
  }

  static Future<PlatformFile?> _pickPgn() => FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['pgn'],
    androidOptions: const FilePickerAndroidOptions(
      safOptions: AndroidSAFOptions(
        grant: AndroidSAFGrant.lifetime,
        accessMode: AndroidSAFAccessMode.readOnly,
        persistGrant: true,
      ),
    ),
  );
}

Future<int?> _reportedLength(PlatformFile file) async {
  try {
    return await file.length();
  } catch (_) {
    // Length is advisory; managed copying supports unknown lengths.
    return null;
  }
}

/// Read access for a selected plugin handle. Operations use sequential streams,
/// so they work with document providers that do not expose seekable paths.
final class FlutterFileSource implements PickedSourceAccess {
  const FlutterFileSource();

  static const MethodChannel _externalChannel = MethodChannel(
    'lberrios.pgntrainingreader/external_source',
  );

  PlatformFile _file(OpaqueSourceReference reference) {
    if (reference case _PickedFileReference(:final file)) return file;
    throw const FileFailure(
      code: 'invalid_source_reference',
      message: 'The selected file reference is unavailable. Select it again.',
    );
  }

  @override
  Stream<List<int>> openReadStream(OpaqueSourceReference reference) {
    if (reference is ExternalSourceReference) {
      return _openExternalReadStream(reference);
    }
    return _openReadStream(reference);
  }

  Stream<List<int>> _openExternalReadStream(
    ExternalSourceReference reference,
  ) async* {
    final size = await length(reference);
    if (size == null) {
      throw const FileFailure(
        code: 'external_source_length_unknown',
        message: 'The selected document does not support reliable range reads.',
      );
    }
    const chunkSize = 64 * 1024;
    for (var offset = 0; offset < size; offset += chunkSize) {
      final candidateEnd = offset + chunkSize;
      final end = candidateEnd < size ? candidateEnd : size;
      yield await readRange(reference, start: offset, endExclusive: end);
    }
  }

  Stream<List<int>> _openReadStream(OpaqueSourceReference reference) async* {
    try {
      yield* _file(reference).readAsByteStream();
    } on FileFailure {
      rethrow;
    } catch (_) {
      throw const FileFailure(
        code: 'source_read_failed',
        message: 'The selected file could not be read. Select it again.',
      );
    }
  }

  @override
  Future<int?> length(OpaqueSourceReference reference) async {
    if (reference case ExternalSourceReference(:final uri)) {
      return _invokeExternal<int>('length', uri);
    }
    final file = _file(reference);
    try {
      return await file.length();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DateTime?> modifiedAt(OpaqueSourceReference reference) async {
    if (reference case ExternalSourceReference(:final uri)) {
      final micros = await _invokeExternal<int>('modifiedAtMicros', uri);
      return micros == null
          ? null
          : DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
    }
    return null;
  }

  @override
  Future<Uint8List> readRange(
    OpaqueSourceReference reference, {
    required int start,
    required int endExclusive,
  }) async {
    if (reference case ExternalSourceReference(:final uri)) {
      final bytes = await _invokeExternal<Uint8List>('readRange', uri, {
        'start': start,
        'endExclusive': endExclusive,
      });
      if (bytes == null || bytes.length != endExclusive - start) {
        throw const FileFailure(
          code: 'external_source_range_invalid',
          message: 'The selected document did not return the requested bytes.',
        );
      }
      return bytes;
    }
    if (start < 0 || endExclusive < start) {
      throw const FileFailure(
        code: 'invalid_byte_range',
        message: 'The requested file range is invalid.',
      );
    }
    final size = await length(reference);
    if (size != null && endExclusive > size) {
      throw const FileFailure(
        code: 'byte_range_out_of_bounds',
        message: 'The requested file range is outside the selected file.',
      );
    }
    final result = BytesBuilder(copy: false);
    var offset = 0;
    try {
      await for (final chunk in openReadStream(reference)) {
        final chunkEnd = offset + chunk.length;
        final from = start > offset ? start - offset : 0;
        final to = endExclusive < chunkEnd
            ? endExclusive - offset
            : chunk.length;
        if (to > from) result.add(chunk.sublist(from, to));
        offset = chunkEnd;
        if (offset >= endExclusive) break;
      }
      if (result.length != endExclusive - start || offset < start) {
        throw const FileFailure(
          code: 'byte_range_out_of_bounds',
          message:
              'The selected file changed or ended before the requested range.',
        );
      }
      return result.takeBytes();
    } on FileFailure {
      rethrow;
    } catch (_) {
      throw const FileFailure(
        code: 'source_read_failed',
        message: 'The selected file could not be read.',
      );
    }
  }

  Future<T?> _invokeExternal<T>(
    String method,
    Uri uri, [
    Map<String, Object?> extra = const {},
  ]) async {
    try {
      return await _externalChannel.invokeMethod<T>(method, {
        'uri': uri.toString(),
        ...extra,
      });
    } on PlatformException catch (error) {
      throw FileFailure(
        code: error.code.isEmpty ? 'external_source_unavailable' : error.code,
        message:
            'The selected document is unavailable or cannot be read safely.',
      );
    } on MissingPluginException {
      throw const FileFailure(
        code: 'external_source_unavailable',
        message: 'External document access is unavailable on this platform.',
      );
    }
  }
}

final class _PickedFileReference implements OpaqueSourceReference {
  const _PickedFileReference(this.file);

  final PlatformFile file;
}
