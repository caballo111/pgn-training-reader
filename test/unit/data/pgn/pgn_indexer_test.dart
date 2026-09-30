import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/time/app_clock.dart';
import 'package:pgntrainingreader/core/utilities/id_generator.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';
import 'package:pgntrainingreader/data/file_access/file_source.dart';
import 'package:pgntrainingreader/data/file_access/file_source_picker.dart';
import 'package:pgntrainingreader/data/pgn/pgn_indexer.dart';
import 'package:pgntrainingreader/domain/library/pgn_import_service.dart';

void main() {
  test(
    'start indexes bounded source ranges and completes with a safe checkpoint',
    () async {
      final bytes = Uint8List.fromList(
        '''[Event "One"]
[White "Ada"]
[Black "Lee"]
[X-ContentType "Puzzle"]
[X-ExerciseId "lesson-1"]

1. e4 e5 *

[Event "Two"]
[White "Kim"]
[Black "Jo"]

1. d4 d5 *
'''
            .codeUnits,
      );
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026);
      await db
          .into(db.pgnSources)
          .insert(
            PgnSourcesCompanion.insert(
              id: 'source',
              displayName: 'games.pgn',
              accessMode: 'ManagedCopy',
              managedPath: const Value('0123456789abcdef0123456789abcdef'),
              scannerVersion: 1,
              importState: 'ready',
              createdAtMicros: 1,
              updatedAtMicros: 1,
            ),
          );
      final service = DriftPgnImportService(
        database: db,
        fileSource: _BytesFileSource(bytes),
        idGenerator: _SequenceIds(),
        clock: _Clock(now),
      );
      final operation = service.start(PgnImportRequest(sourceId: 'source'));
      final result = await operation.result;
      expect(result.phase, PgnImportPhase.completed);
      expect(result.indexedBlockCount, 2);
      final blocks = await db.select(db.pgnBlocks).get();
      expect(blocks.map((row) => row.ordinal), <int>[0, 1]);
      expect(blocks.first.exerciseId, 'lesson-1');
      expect(blocks.first.inferredClassification, isFalse);
      expect(blocks.last.inferredClassification, isTrue);
      final job = await db.select(db.importJobs).getSingle();
      expect(job.safeCheckpoint, bytes.length);
      expect(job.status, 'completed');
    },
  );
}

final class _BytesFileSource implements FileSource {
  _BytesFileSource(this.bytes);
  final Uint8List bytes;
  @override
  Stream<List<int>> openReadStream(OpaqueSourceReference reference) async* {
    yield bytes;
  }

  @override
  Future<int?> length(OpaqueSourceReference reference) async => bytes.length;
  @override
  Future<Uint8List> readRange(
    OpaqueSourceReference reference, {
    required int start,
    required int endExclusive,
  }) async => Uint8List.fromList(bytes.sublist(start, endExclusive));
  @override
  Future<FileFingerprintInput> fingerprintInput(
    OpaqueSourceReference reference, {
    DateTime? modifiedAt,
    int sampleSize = 4096,
  }) async => FileFingerprintInput(
    length: bytes.length,
    modifiedAt: modifiedAt,
    samples: <FingerprintSample>[FingerprintSample(offset: 0, bytes: bytes)],
  );
  @override
  Future<ManagedCopyResult> copyToManagedStorage(
    OpaqueSourceReference reference, {
    required ManagedCopyTarget target,
    required CopyCancellation cancellation,
    int? expectedLength,
  }) => throw UnimplementedError();
}

final class _SequenceIds implements IdGenerator {
  int _value = 0;
  @override
  String generateId() => 'id-${_value++}';
}

final class _Clock implements AppClock {
  _Clock(this.utcNow);
  @override
  final DateTime utcNow;
  @override
  Duration get monotonicElapsed => Duration.zero;
}
