import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/time/app_clock.dart';
import 'package:pgntrainingreader/core/utilities/id_generator.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';
import 'package:pgntrainingreader/data/file_access/file_source.dart';
import 'package:pgntrainingreader/data/file_access/file_source_picker.dart';
import 'package:pgntrainingreader/data/file_access/managed_file_source.dart';
import 'package:pgntrainingreader/data/pgn/pgn_indexer.dart';
import 'package:pgntrainingreader/data/repositories/drift_pgn_index_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/library/pgn_import_service.dart';
import 'package:pgntrainingreader/domain/library/pgn_index_repository.dart';

void main() {
  test(
    'managed PGN import resumes at committed batch without duplicate rows',
    () async {
      final temp = await Directory.systemTemp.createTemp('pgn-index-resume-');
      addTearDown(() => temp.delete(recursive: true));
      final pgnBlocks = List<String>.generate(120, _block);
      final sourceBytes = Uint8List.fromList(utf8.encode(pgnBlocks.join('\n')));
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final fileSource = ManagedFileSource(
        pickedSources: _PickedBytes(sourceBytes),
        directoryProvider: () async => temp,
      );
      final now = DateTime.utc(2026, 9, 29);

      final managed = await fileSource.createTarget();
      final copy = await fileSource.copyToManagedStorage(
        const _PickedReference(),
        target: managed,
        cancellation: CopyCancellation(),
        expectedLength: sourceBytes.length,
      );
      await _registerSource(db, 'resumed', copy.reference, now);

      final ids = _Ids();
      final service = DriftPgnImportService(
        database: db,
        fileSource: fileSource,
        idGenerator: ids,
        clock: _Clock(now),
      );
      final operation = service.start(PgnImportRequest(sourceId: 'resumed'));
      var requestedCancel = false;
      final progressSubscription = operation.progress.listen((progress) {
        if (!requestedCancel &&
            progress.phase == PgnImportPhase.indexing &&
            progress.indexedBlockCount >= 50) {
          requestedCancel = true;
          operation.cancel();
        }
      });
      final stopped = await operation.result;
      await progressSubscription.cancel();
      expect(requestedCancel, isTrue);
      expect(stopped.phase, PgnImportPhase.cancelled);
      expect(stopped.indexedBlockCount, greaterThanOrEqualTo(50));

      final beforeResume = await db.select(db.pgnBlocks).get();
      expect(beforeResume.length, greaterThanOrEqualTo(50));
      final committedIds = beforeResume.take(50).map((row) => row.id).toList();
      final recreatedService = DriftPgnImportService(
        database: db,
        fileSource: fileSource,
        idGenerator: ids,
        clock: _Clock(now),
      );
      final resumed = await recreatedService.resume(stopped.jobId).result;
      expect(resumed.phase, PgnImportPhase.completed);
      expect(resumed.indexedBlockCount, 120);

      final rows = await db.select(db.pgnBlocks).get();
      expect(rows, hasLength(120));
      expect(rows.map((row) => row.sourceId).toSet(), <String>{'resumed'});
      expect(rows.map((row) => row.ordinal), List<int>.generate(120, (i) => i));
      expect(rows.map((row) => row.id).toSet(), hasLength(120));
      expect(rows.take(committedIds.length).map((row) => row.id), committedIds);

      final repository = DriftPgnIndexRepository(db);
      final page = await repository.search(
        filter: const PgnIndexFilter(sourceId: 'resumed'),
        limit: 200,
      );
      expect(page.items, hasLength(120));
      for (var i = 0; i < 120; i++) {
        final indexed = page.items[i];
        final raw = await fileSource.readRange(
          ManagedSourceReference(copy.reference),
          start: indexed.startOffset,
          endExclusive: indexed.endOffset,
        );
        final exactBlock = utf8.decode(raw);
        expect(
          exactBlock,
          pgnBlocks[i].trimRight(),
          reason:
              'ordinal $i locator ${indexed.startOffset}..${indexed.endOffset}',
        );
        expect(exactBlock, contains('1. e4 e5 *'));
        expect(indexed.ordinal, i);
        final authoredType = switch (i % 4) {
          0 => ContentType.puzzle,
          1 => ContentType.text,
          2 => ContentType.text,
          _ => ContentType.puzzle,
        };
        expect(
          indexed.contentType,
          i % 4 == 3 ? ContentType.puzzle : authoredType,
        );
        expect(indexed.inferredClassification, i % 4 == 3);
        expect(
          indexed.authoredContentType,
          i % 4 == 0
              ? 'Puzzle'
              : i % 4 == 1
              ? 'Instruction'
              : i % 4 == 2
              ? 'Demonstration'
              : null,
        );
        if (i % 4 == 0) {
          expect(indexed.exerciseId, 'exercise-$i');
          expect(indexed.theme, 'theme-$i');
        }
        if (i % 4 == 1) expect(indexed.section, 'section-$i');
        if (i % 4 == 2) expect(indexed.sequence, i);
        if (i % 4 == 3) expect(indexed.exerciseId, isNotEmpty);
      }
    },
  );
}

String _block(int i) {
  final classification = switch (i % 4) {
    0 =>
      '[X-ContentType "Puzzle"]\n[X-ExerciseId "exercise-$i"]\n[X-Theme "theme-$i"]\n',
    1 => '[X-ContentType "Instruction"]\n[X-Section "section-$i"]\n',
    2 => '[X-ContentType "Demonstration"]\n[X-Sequence "$i"]\n',
    _ => '', // Legacy block exercises classification inference.
  };
  final fen = i % 4 == 3
      ? '[SetUp "1"]\n[FEN "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"]\n'
      : '';
  return '[Event "Block $i"]\n[White "José $i"]\n[Black "Opponent"]\n$classification$fen[X-Custom "kept-$i"]\n\n1. e4 e5 *\n';
}

Future<void> _registerSource(
  AppDatabase db,
  String id,
  String managedToken,
  DateTime now,
) async {
  await db
      .into(db.pgnSources)
      .insert(
        PgnSourcesCompanion.insert(
          id: id,
          displayName: '$id.pgn',
          accessMode: 'ManagedCopy',
          managedPath: Value(managedToken),
          scannerVersion: 1,
          importState: 'ready',
          createdAtMicros: now.microsecondsSinceEpoch,
          updatedAtMicros: now.microsecondsSinceEpoch,
        ),
      );
}

final class _PickedReference implements OpaqueSourceReference {
  const _PickedReference();
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
  Future<DateTime?> modifiedAt(OpaqueSourceReference reference) async => null;
  @override
  Future<Uint8List> readRange(
    OpaqueSourceReference reference, {
    required int start,
    required int endExclusive,
  }) async => Uint8List.fromList(bytes.sublist(start, endExclusive));
}

final class _Ids implements IdGenerator {
  var value = 0;
  @override
  String generateId() => 'generated-${value++}';
}

final class _Clock implements AppClock {
  const _Clock(this.utcNow);
  @override
  final DateTime utcNow;
  @override
  Duration get monotonicElapsed => Duration.zero;
}
