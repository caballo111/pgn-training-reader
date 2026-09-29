/// How a PGN source remains available to the application after import.
///
/// These values are persisted in the database. Keep their serialized values
/// explicit so a Dart enum rename cannot silently change stored data.
enum PgnSourceAccessMode {
  /// The source was copied into application-managed storage.
  managedCopy,

  /// The source remains at an external location that the app can reopen.
  externalReference;

  /// Returns the canonical value stored in the database.
  String toDatabaseValue() => switch (this) {
    PgnSourceAccessMode.managedCopy => 'ManagedCopy',
    PgnSourceAccessMode.externalReference => 'ExternalReference',
  };

  /// Parses a canonical database value.
  ///
  /// Parsing is case-sensitive and does not trim whitespace. Unknown values
  /// fail rather than being interpreted as a different access mode.
  static PgnSourceAccessMode fromDatabaseValue(String value) => switch (value) {
    'ManagedCopy' => PgnSourceAccessMode.managedCopy,
    'ExternalReference' => PgnSourceAccessMode.externalReference,
    _ => throw FormatException('Unknown PGN source access mode.', value),
  };
}

/// A PGN file registered in the user's local library.
///
/// [managedPath] and [externalReference] are opaque storage references. The
/// domain model deliberately does not depend on `dart:io`, `Uri`, or any
/// platform file-picker type. Exactly one reference is present, as selected
/// by [accessMode].
final class PgnSource {
  factory PgnSource({
    required String id,
    required String displayName,
    required PgnSourceAccessMode accessMode,
    String? managedPath,
    String? externalReference,
    int? sizeBytes,
    DateTime? modifiedAt,
    String? fingerprint,
    required int scannerVersion,
    required String importState,
    int safeCheckpoint = 0,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (displayName.isEmpty) {
      throw ArgumentError.value(
        displayName,
        'displayName',
        'Must not be empty.',
      );
    }
    if (scannerVersion <= 0) {
      throw ArgumentError.value(
        scannerVersion,
        'scannerVersion',
        'Must be positive.',
      );
    }
    if (sizeBytes != null && sizeBytes < 0) {
      throw ArgumentError.value(
        sizeBytes,
        'sizeBytes',
        'Must not be negative.',
      );
    }
    if (safeCheckpoint < 0) {
      throw ArgumentError.value(
        safeCheckpoint,
        'safeCheckpoint',
        'Must not be negative.',
      );
    }

    final hasManagedPath = managedPath != null && managedPath.isNotEmpty;
    final hasExternalReference =
        externalReference != null && externalReference.isNotEmpty;
    final hasValidReference = switch (accessMode) {
      PgnSourceAccessMode.managedCopy =>
        hasManagedPath && externalReference == null,
      PgnSourceAccessMode.externalReference =>
        hasExternalReference && managedPath == null,
    };
    if (!hasValidReference) {
      throw ArgumentError(
        'Exactly one non-empty storage reference must match the access mode.',
      );
    }
    if (importState.isEmpty) {
      throw ArgumentError.value(
        importState,
        'importState',
        'Must not be empty.',
      );
    }

    return PgnSource._(
      id: id,
      displayName: displayName,
      accessMode: accessMode,
      managedPath: managedPath,
      externalReference: externalReference,
      sizeBytes: sizeBytes,
      modifiedAt: modifiedAt,
      fingerprint: fingerprint,
      scannerVersion: scannerVersion,
      importState: importState,
      safeCheckpoint: safeCheckpoint,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  const PgnSource._({
    required this.id,
    required this.displayName,
    required this.accessMode,
    required this.managedPath,
    required this.externalReference,
    required this.sizeBytes,
    required this.modifiedAt,
    required this.fingerprint,
    required this.scannerVersion,
    required this.importState,
    required this.safeCheckpoint,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String displayName;
  final PgnSourceAccessMode accessMode;
  final String? managedPath;
  final String? externalReference;
  final int? sizeBytes;
  final DateTime? modifiedAt;
  final String? fingerprint;
  final int scannerVersion;
  final String importState;
  final int safeCheckpoint;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PgnSource &&
          other.id == id &&
          other.displayName == displayName &&
          other.accessMode == accessMode &&
          other.managedPath == managedPath &&
          other.externalReference == externalReference &&
          other.sizeBytes == sizeBytes &&
          other.modifiedAt == modifiedAt &&
          other.fingerprint == fingerprint &&
          other.scannerVersion == scannerVersion &&
          other.importState == importState &&
          other.safeCheckpoint == safeCheckpoint &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    accessMode,
    managedPath,
    externalReference,
    sizeBytes,
    modifiedAt,
    fingerprint,
    scannerVersion,
    importState,
    safeCheckpoint,
    createdAt,
    updatedAt,
  );
}
