import 'dart:async';
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
  test('cancel before source bytes are read resolves as recoverable', () async {
    final bytes = Uint8List.fromList('[Event "one"]\n\n1. e4 *\n'.codeUnits);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
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
      idGenerator: _Ids(),
      clock: _Clock(),
    );
    final op = service.start(PgnImportRequest(sourceId: 'source'));
    await op.cancel();
    final result = await op.result;
    expect(result.phase, PgnImportPhase.cancelled);
    expect(result.resumeDisposition, PgnImportResumeDisposition.resume);
    expect((await db.select(db.pgnBlocks).get()), isEmpty);
    final job = await db.select(db.importJobs).getSingle();
    expect(job.status, 'cancelled');
    expect(job.cancellationRequested, isTrue);
    expect(job.safeCheckpoint, 0);
  });

  test('cancelled preparation resumes in a new service instance', () async {
    final bytes = Uint8List.fromList('[Event "one"]\n\n1. e4 *\n'.codeUnits);
    final db = await _database();
    addTearDown(db.close);
    final fs = _BytesFileSource(bytes);
    final first = _service(db, fs).start(PgnImportRequest(sourceId: 'source'));
    await first.cancel();
    final cancelled = await first.result;
    final resumed = _service(db, fs).resume(cancelled.jobId);
    final result = await resumed.result;
    expect(result.phase, PgnImportPhase.completed);
    expect(result.indexedBlockCount, 1);
    expect((await db.select(db.pgnBlocks).get()).map((b) => b.ordinal), [0]);
  });

  test('changed source revision rejects checkpoint resume', () async {
    final db = await _database();
    addTearDown(db.close);
    final fs = _BytesFileSource(
      Uint8List.fromList('[Event "one"]\n\n1. e4 *\n'.codeUnits),
    );
    final first = _service(db, fs).start(PgnImportRequest(sourceId: 'source'));
    await first.cancel();
    final cancelled = await first.result;
    fs.bytes = Uint8List.fromList('[Event "two"]\n\n1. d4 *\n'.codeUnits);
    final result = await _service(db, fs).resume(cancelled.jobId).result;
    expect(result.phase, PgnImportPhase.failed);
    expect(result.resumeDisposition, PgnImportResumeDisposition.repairSource);
  });

  test(
    'scanner version mismatch and unknown job fail without indexing',
    () async {
      final db = await _database();
      addTearDown(db.close);
      final fs = _BytesFileSource(
        Uint8List.fromList('[Event "one"]\n\n1. e4 *\n'.codeUnits),
      );
      final first = _service(
        db,
        fs,
      ).start(PgnImportRequest(sourceId: 'source'));
      await first.cancel();
      final cancelled = await first.result;
      await (db.update(db.importJobs)
            ..where((row) => row.id.equals(cancelled.jobId)))
          .write(const ImportJobsCompanion(scannerVersion: Value(999)));
      final mismatch = await _service(db, fs).resume(cancelled.jobId).result;
      expect(
        mismatch.resumeDisposition,
        PgnImportResumeDisposition.repairSource,
      );
      final unknown = await _service(db, fs).resume('missing-job').result;
      expect(unknown.phase, PgnImportPhase.failed);
      expect(unknown.resumeDisposition, PgnImportResumeDisposition.restart);
      expect(await db.select(db.pgnBlocks).get(), isEmpty);
    },
  );

  test(
    'starting an already indexed source fails without duplicating rows',
    () async {
      final db = await _database();
      addTearDown(db.close);
      final fs = _BytesFileSource(
        Uint8List.fromList('[Event "one"]\n\n1. e4 *\n'.codeUnits),
      );
      final first = await _service(
        db,
        fs,
      ).start(PgnImportRequest(sourceId: 'source')).result;
      expect(first.phase, PgnImportPhase.completed);
      final second = await _service(
        db,
        fs,
      ).start(PgnImportRequest(sourceId: 'source')).result;
      expect(second.phase, PgnImportPhase.failed);
      expect(await db.select(db.pgnBlocks).get(), hasLength(1));
    },
  );
  test(
    'failed batch rolls back its ordinal and checkpoint before resume',
    () async {
      final db = await _database();
      addTearDown(db.close);
      final fs = _BytesFileSource(
        Uint8List.fromList(
          List<String>.generate(
            120,
            (i) => '[Event "Block $i"]\n\n1. e4 *\n',
          ).join().codeUnits,
        ),
      );
      final ids = _Ids();
      DriftPgnImportService service() => DriftPgnImportService(
        database: db,
        fileSource: fs,
        idGenerator: ids,
        clock: _Clock(),
      );
      await db.customStatement(
        'CREATE TRIGGER reject_second_batch BEFORE INSERT ON pgn_blocks '
        "WHEN NEW.ordinal >= 50 BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
      );
      final stopped = await service()
          .start(PgnImportRequest(sourceId: 'source'))
          .result;
      expect(stopped.phase, PgnImportPhase.failed);
      expect(stopped.indexedBlockCount, 50);
      final job = await db.select(db.importJobs).getSingle();
      expect(job.blocksScanned, 50);
      expect(job.blocksIndexed, 50);
      final committed = await db.select(db.pgnBlocks).get();
      expect(committed, hasLength(50));
      expect(job.safeCheckpoint, committed.last.endOffset);
      await db.customStatement('DROP TRIGGER reject_second_batch');
      final completed = await service().resume(stopped.jobId).result;
      expect(completed.phase, PgnImportPhase.completed);
      expect(completed.indexedBlockCount, 120);
      final rows = await db.select(db.pgnBlocks).get();
      expect(rows.map((row) => row.ordinal), List<int>.generate(120, (i) => i));
      expect(
        rows.take(50).map((row) => row.id),
        committed.map((row) => row.id),
      );
    },
  );
  test('another service cannot resume a job that is executing', () async {
    final db = await _database();
    addTearDown(db.close);
    final gate = Completer<void>();
    final fs = _BytesFileSource(
      Uint8List.fromList('[Event "one"]\n\n1. e4 *\n'.codeUnits),
    )..streamGate = gate.future;
    final active = _service(db, fs).start(PgnImportRequest(sourceId: 'source'));
    final ready = await active.progress.firstWhere(
      (p) => p.phase == PgnImportPhase.indexing,
    );
    final competing = await _service(db, fs).resume(ready.jobId).result;
    expect(competing.phase, PgnImportPhase.failed);
    gate.complete();
    expect((await active.result).phase, PgnImportPhase.completed);
    expect(await db.select(db.pgnBlocks).get(), hasLength(1));
  });
}

Future<AppDatabase> _database() async {
  final db = AppDatabase(NativeDatabase.memory());
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
  return db;
}

DriftPgnImportService _service(AppDatabase db, _BytesFileSource fs) =>
    DriftPgnImportService(
      database: db,
      fileSource: fs,
      idGenerator: _Ids(),
      clock: _Clock(),
    );

final class _BytesFileSource implements FileSource {
  _BytesFileSource(this.bytes);
  Uint8List bytes;
  Future<void>? streamGate;
  @override
  Stream<List<int>> openReadStream(OpaqueSourceReference reference) async* {
    await streamGate;
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
    samples: [FingerprintSample(offset: 0, bytes: bytes)],
  );
  @override
  Future<ManagedCopyResult> copyToManagedStorage(
    OpaqueSourceReference reference, {
    required ManagedCopyTarget target,
    required CopyCancellation cancellation,
    int? expectedLength,
  }) => throw UnimplementedError();
}

final class _Ids implements IdGenerator {
  int i = 0;
  @override
  String generateId() => 'id-${i++}';
}

final class _Clock implements AppClock {
  @override
  DateTime get utcNow => DateTime.utc(2026);
  @override
  Duration get monotonicElapsed => Duration.zero;
}
