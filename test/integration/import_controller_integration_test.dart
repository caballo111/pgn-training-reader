import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/app/dependencies.dart';
import 'package:pgntrainingreader/core/time/app_clock.dart';
import 'package:pgntrainingreader/core/utilities/id_generator.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';
import 'package:pgntrainingreader/data/file_access/file_source_picker.dart';
import 'package:pgntrainingreader/data/file_access/managed_file_source.dart';
import 'package:pgntrainingreader/data/pgn/pgn_indexer.dart';
import 'package:pgntrainingreader/data/repositories/drift_pgn_index_repository.dart';
import 'package:pgntrainingreader/data/repositories/drift_pgn_source_repository.dart';
import 'package:pgntrainingreader/domain/library/pgn_index_repository.dart';
import 'package:pgntrainingreader/features/import_library/application/import_controller.dart';
import 'package:pgntrainingreader/features/import_library/application/import_recovery.dart';

void main() {
  test(
    'app dependencies discover a durable resumable import from the DB',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      const now = 1790640000000000;
      const managedToken = '0123456789abcdef0123456789abcdef';
      await database
          .into(database.pgnSources)
          .insert(
            PgnSourcesCompanion.insert(
              id: 'restored-source',
              displayName: 'restored.pgn',
              accessMode: 'ManagedCopy',
              managedPath: const Value(managedToken),
              sizeBytes: const Value(4096),
              scannerVersion: 1,
              importState: 'indexing',
              createdAtMicros: now,
              updatedAtMicros: now,
            ),
          );
      await database
          .into(database.importJobs)
          .insert(
            ImportJobsCompanion.insert(
              id: 'restored-job',
              sourceId: 'restored-source',
              status: 'cancelled',
              blocksIndexed: const Value(50),
              bytesProcessed: const Value(2048),
              safeCheckpoint: const Value(2048),
              startedAtMicros: now,
            ),
          );

      final dependencies = AppDependencies(databaseFactory: () => database);
      final controller = dependencies.importController;
      addTearDown(controller.dispose);
      final restored = Completer<void>();
      void listener() {
        if (controller.state.status == ImportStatus.cancelled &&
            !restored.isCompleted) {
          restored.complete();
        }
      }

      controller.addListener(listener);
      if (controller.state.status == ImportStatus.cancelled) {
        restored.complete();
      }
      await restored.future.timeout(const Duration(seconds: 2));
      controller.removeListener(listener);

      expect(controller.state.progress?.indexedBlockCount, 50);
      expect(
        importRecoveryFor(controller.state).action,
        ImportRecoveryAction.resume,
      );
    },
  );

  test(
    'selects, copies, cancels at a committed batch, resumes, and indexes once',
    () async {
      final temp = await Directory.systemTemp.createTemp('pgn-controller-');
      addTearDown(() => temp.delete(recursive: true));
      final blocks = List<String>.generate(120, _pgnBlock);
      final sourceBytes = Uint8List.fromList(
        utf8.encode('${blocks.join('\n')}\n'),
      );
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final fileSource = ManagedFileSource(
        pickedSources: _PickedBytes(sourceBytes),
        directoryProvider: () async => temp,
      );
      final clock = _FixedClock(DateTime.utc(2026, 9, 29));
      final ids = _SequenceIds();
      final controller = _makeController(
        fileSource: fileSource,
        database: database,
        ids: ids,
        clock: clock,
        sourceBytes: sourceBytes,
      );
      var controllerDisposed = false;
      addTearDown(() {
        if (!controllerDisposed) controller.dispose();
      });

      var cancelRequested = false;
      Future<void>? cancelFuture;
      controller.addListener(() {
        final state = controller.state;
        if (!cancelRequested &&
            state.status == ImportStatus.indexing &&
            (state.progress?.indexedBlockCount ?? 0) >= 50) {
          cancelRequested = true;
          cancelFuture = controller.cancel();
        }
      });

      await controller.selectAndImport();
      await cancelFuture;

      expect(cancelRequested, isTrue);
      expect(controller.state.status, ImportStatus.cancelled);
      expect(
        controller.state.result?.indexedBlockCount,
        greaterThanOrEqualTo(50),
      );
      expect(controller.state.result?.resumeDisposition.name, 'resume');

      final savedSource =
          (await database.select(database.pgnSources).get()).single;
      final managedReference = ManagedSourceReference(savedSource.managedPath!);
      final bytesBeforeResume = await fileSource.readRange(
        managedReference,
        start: 0,
        endExclusive: savedSource.sizeBytes!,
      );
      expect(bytesBeforeResume, orderedEquals(sourceBytes));
      final committedBeforeResume = await (database.select(
        database.pgnBlocks,
      )..orderBy([(block) => OrderingTerm.asc(block.ordinal)])).get();
      expect(committedBeforeResume.length, greaterThanOrEqualTo(50));
      final committedIds = committedBeforeResume.map((row) => row.id).toList();

      final stoppedJob =
          (await (database.select(database.importJobs)
                ..where((job) => job.id.equals(controller.state.result!.jobId)))
              .getSingle());
      final stoppedSource = await DriftPgnSourceRepository(database)
          .getById(stoppedJob.sourceId);
      expect(stoppedSource, isNotNull);
      controller.dispose();
      controllerDisposed = true;

      final restoredController = _makeController(
        fileSource: fileSource,
        database: database,
        ids: ids,
        clock: clock,
        sourceBytes: sourceBytes,
      );
      addTearDown(restoredController.dispose);
      restoredController.restoreResumableImport(
        source: stoppedSource!,
        jobId: stoppedJob.id,
        indexedBlockCount: stoppedJob.blocksIndexed,
        diagnosticCount: stoppedJob.diagnosticCount,
        bytesRead: stoppedJob.bytesProcessed,
        safeCheckpoint: stoppedJob.safeCheckpoint,
      );

      expect(restoredController.state.status, ImportStatus.cancelled);
      expect(restoredController.state.result?.resumeDisposition.name, 'resume');
      expect(
        importRecoveryFor(restoredController.state).action,
        ImportRecoveryAction.resume,
      );
      expect(
        importRecoveryFor(restoredController.state).explanation,
        contains('managed copy'),
      );

      await restoredController.resume();

      expect(restoredController.state.status, ImportStatus.completed);
      expect(restoredController.state.result?.indexedBlockCount, 120);
      expect(restoredController.state.result?.diagnosticCount, 0);
      final rows = await (database.select(
        database.pgnBlocks,
      )..orderBy([(block) => OrderingTerm.asc(block.ordinal)])).get();
      expect(rows, hasLength(120));
      expect(rows.map((row) => row.id).toSet(), hasLength(120));
      expect(rows.map((row) => row.ordinal), List<int>.generate(120, (i) => i));
      expect(rows.take(committedIds.length).map((row) => row.id), committedIds);

      final indexedPage = await DriftPgnIndexRepository(database)
          .search(filter: PgnIndexFilter(sourceId: savedSource.id), limit: 200);
      expect(indexedPage.items, hasLength(120));
      for (var i = 0; i < blocks.length; i++) {
        final indexed = indexedPage.items[i];
        final raw = await fileSource.readRange(
          managedReference,
          start: indexed.startOffset,
          endExclusive: indexed.endOffset,
        );
        expect(
          utf8.decode(raw),
          blocks[i].trimRight(),
          reason: 'PGN block ordinal $i',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

ImportController _makeController({
  required ManagedFileSource fileSource,
  required AppDatabase database,
  required _SequenceIds ids,
  required _FixedClock clock,
  required Uint8List sourceBytes,
}) => ImportController(
  fileSourcePicker: _FixturePicker(
    SelectedFileSource(
      reference: const _FixtureReference(),
      displayName: 'controller-fixture.pgn',
      lengthBytes: sourceBytes.length,
      mimeType: 'application/x-chess-pgn',
    ),
  ),
  fileSource: fileSource,
  targetFactory: fileSource.createTarget,
  sourceRepository: DriftPgnSourceRepository(database),
  importService: DriftPgnImportService(
    database: database,
    fileSource: fileSource,
    idGenerator: ids,
    clock: clock,
  ),
  clock: clock,
  idGenerator: ids,
);

String _pgnBlock(int index) =>
    '[Event "Game $index"]\n'
    '[White "White $index"]\n'
    '[Black "Black $index"]\n'
    '\n'
    '1. e4 e5 2. Nf3 Nc6 *\n';

final class _FixtureReference implements OpaqueSourceReference {
  const _FixtureReference();
}

final class _FixturePicker implements FileSourcePicker {
  _FixturePicker(this.source);
  final SelectedFileSource source;

  @override
  Future<SelectedFileSource?> pickPgnSource() async => source;
}

final class _PickedBytes implements PickedSourceAccess {
  _PickedBytes(this.bytes);
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
}

final class _SequenceIds implements IdGenerator {
  var _next = 0;

  @override
  String generateId() => 'integration-${_next++}';
}

final class _FixedClock implements AppClock {
  const _FixedClock(this.utcNow);

  @override
  final DateTime utcNow;

  @override
  Duration get monotonicElapsed => Duration.zero;
}
