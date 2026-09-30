/// A platform-owned handle for a selected source document.
///
/// The handle intentionally exposes no URI, path, or provider details. Keep it
/// within the file-access layer and do not persist it in the domain model or
/// database. Platform adapters may implement this marker with their own
/// private reference type.
abstract interface class OpaqueSourceReference {}

/// A durable Android Storage Access Framework URI selected by the user.
///
/// Keep it opaque outside the file-access adapter. Only `content:` URIs are
/// accepted; paths and other URI schemes are never treated as file locations.
final class ExternalSourceReference implements OpaqueSourceReference {
  factory ExternalSourceReference(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'content' ||
        uri.authority.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(value, 'value', 'Invalid external source URI.');
    }
    return ExternalSourceReference._(uri);
  }

  const ExternalSourceReference._(this.uri);

  final Uri uri;

  @override
  String toString() => 'ExternalSourceReference(<opaque>)';
}

/// A source selected by the user, together with metadata suitable for display
/// and import planning.
///
/// The metadata is advisory: a provider may omit it or report a value that
/// later changes. Read operations must use [reference] rather than infer a
/// location from [displayName].
final class SelectedFileSource {
  SelectedFileSource({
    required this.reference,
    required this.displayName,
    this.lengthBytes,
    this.modifiedAt,
    this.mimeType,
  }) {
    if (displayName.trim().isEmpty) {
      throw ArgumentError.value(
        displayName,
        'displayName',
        'Must not be empty.',
      );
    }
    if (lengthBytes != null && lengthBytes! < 0) {
      throw ArgumentError.value(
        lengthBytes,
        'lengthBytes',
        'Must not be negative.',
      );
    }
  }

  /// Opaque adapter handle used to open or copy the selected document.
  final OpaqueSourceReference reference;

  /// User-visible name supplied by the picker/provider.
  final String displayName;

  /// Provider-reported byte length, when known.
  final int? lengthBytes;

  /// Provider-reported modification time, when available.
  final DateTime? modifiedAt;

  /// Provider-reported media type, when available; informational only.
  final String? mimeType;
}

/// Platform-neutral contract for asking the user to select a PGN source.
abstract interface class FileSourcePicker {
  /// Lets the user select a PGN source.
  ///
  /// Returns `null` when the user cancels. The returned reference is opaque
  /// and remains owned by the platform adapter; callers must not inspect or
  /// serialize it themselves.
  Future<SelectedFileSource?> pickPgnSource();
}
