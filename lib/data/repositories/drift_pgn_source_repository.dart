import 'package:drift/drift.dart';

import '../../core/errors/app_failure.dart';
import '../../domain/chess_content/pgn_source.dart';
import '../../domain/library/pgn_source_repository.dart';
import '../database/app_database.dart' hide PgnSource;
import '../database/app_database.dart' as db show PgnSource;

/// Drift-backed source metadata repository.
final class DriftPgnSourceRepository implements PgnSourceRepository {
  DriftPgnSourceRepository(this._database);

  final AppDatabase _database;

  @override
  Future<PgnSource?> getById(String id) => _guard(() async {
    final row = await (_database.select(
      _database.pgnSources,
    )..where((source) => source.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  });

  @override
  Future<List<PgnSource>> list() => _guard(() async {
    final rows =
        await (_database.select(_database.pgnSources)..orderBy([
              (source) => OrderingTerm.asc(source.displayName),
              (source) => OrderingTerm.asc(source.id),
            ]))
            .get();
    return rows.map(_fromRow).toList(growable: false);
  });

  @override
  Future<void> create(PgnSource source) => _guard(() async {
    await _database
        .into(_database.pgnSources)
        .insert(_toInsert(source), mode: InsertMode.insert);
  });

  @override
  Future<void> update(PgnSource source) => _guard(() async {
    await _database.transaction(() async {
      final old = await (_database.select(
        _database.pgnSources,
      )..where((row) => row.id.equals(source.id))).getSingleOrNull();
      if (old == null) {
        throw const DatabaseFailure(
          code: 'source_not_found',
          message: 'The source is no longer registered. Select it again.',
        );
      }

      final revisionChanged =
          (old.fingerprint != null && old.fingerprint != source.fingerprint) ||
          (old.sizeBytes != null && old.sizeBytes != source.sizeBytes) ||
          (old.modifiedAtMicros != null &&
              old.modifiedAtMicros != _toMicros(source.modifiedAt)) ||
          old.scannerVersion != source.scannerVersion;
      final updated = source.copyWithPreservingCreationTime(
        oldCreatedAt: _fromMicros(old.createdAtMicros),
        importState: revisionChanged ? 'sourceChanged' : source.importState,
        safeCheckpoint: revisionChanged ? 0 : source.safeCheckpoint,
      );

      await (_database.update(
        _database.pgnSources,
      )..where((row) => row.id.equals(source.id))).write(_toCompanion(updated));
    });
  });

  static Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const DatabaseFailure(
        code: 'source_persistence_failed',
        message: 'Source metadata could not be saved or loaded. Retry the operation.',
      );
    }
  }

  static PgnSource _fromRow(db.PgnSource row) => PgnSource(
    id: row.id,
    displayName: row.displayName,
    accessMode: PgnSourceAccessMode.fromDatabaseValue(row.accessMode),
    managedPath: row.managedPath,
    externalReference: row.externalReference,
    sizeBytes: row.sizeBytes,
    modifiedAt: row.modifiedAtMicros == null
        ? null
        : _fromMicros(row.modifiedAtMicros!),
    fingerprint: row.fingerprint,
    scannerVersion: row.scannerVersion,
    importState: row.importState,
    safeCheckpoint: row.safeCheckpoint,
    createdAt: _fromMicros(row.createdAtMicros),
    updatedAt: _fromMicros(row.updatedAtMicros),
  );

  static PgnSourcesCompanion _toInsert(PgnSource source) =>
      PgnSourcesCompanion.insert(
        id: source.id,
        displayName: source.displayName,
        accessMode: source.accessMode.toDatabaseValue(),
        managedPath: Value(source.managedPath),
        externalReference: Value(source.externalReference),
        sizeBytes: Value(source.sizeBytes),
        modifiedAtMicros: Value(_toMicros(source.modifiedAt)),
        fingerprint: Value(source.fingerprint),
        scannerVersion: source.scannerVersion,
        importState: source.importState,
        safeCheckpoint: Value(source.safeCheckpoint),
        createdAtMicros: _toMicros(source.createdAt)!,
        updatedAtMicros: _toMicros(source.updatedAt)!,
      );

  static PgnSourcesCompanion _toCompanion(PgnSource source) =>
      PgnSourcesCompanion(
        displayName: Value(source.displayName),
        accessMode: Value(source.accessMode.toDatabaseValue()),
        managedPath: Value(source.managedPath),
        externalReference: Value(source.externalReference),
        sizeBytes: Value(source.sizeBytes),
        modifiedAtMicros: Value(_toMicros(source.modifiedAt)),
        fingerprint: Value(source.fingerprint),
        scannerVersion: Value(source.scannerVersion),
        importState: Value(source.importState),
        safeCheckpoint: Value(source.safeCheckpoint),
        createdAtMicros: Value(_toMicros(source.createdAt)!),
        updatedAtMicros: Value(_toMicros(source.updatedAt)!),
      );

  static int? _toMicros(DateTime? value) =>
      value?.toUtc().microsecondsSinceEpoch;

  static DateTime _fromMicros(int value) =>
      DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true);
}

extension on PgnSource {
  PgnSource copyWithPreservingCreationTime({
    required DateTime oldCreatedAt,
    required String importState,
    required int safeCheckpoint,
  }) => PgnSource(
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
    createdAt: oldCreatedAt,
    updatedAt: updatedAt,
  );
}
