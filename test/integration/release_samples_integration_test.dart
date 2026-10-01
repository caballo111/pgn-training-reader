import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/time/app_clock.dart';
import 'package:pgntrainingreader/core/utilities/id_generator.dart';
import 'package:pgntrainingreader/data/database/app_database.dart';
import 'package:pgntrainingreader/data/file_access/file_source.dart';
import 'package:pgntrainingreader/data/file_access/file_source_picker.dart';
import 'package:pgntrainingreader/data/file_access/managed_file_source.dart';
import 'package:pgntrainingreader/data/pgn/pgn_indexer.dart';
import 'package:pgntrainingreader/data/repositories/drift_chess_content_repository.dart';
import 'package:pgntrainingreader/data/repositories/drift_pgn_index_repository.dart';
import 'package:pgntrainingreader/data/repositories/drift_pgn_source_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/library/pgn_import_service.dart';

void main() {
  test(
    'documented samples survive managed import and database reopening',
    () async {
      const names = [
        'puzzle',
        'instruction',
        'demonstration',
        'fen-start',
        'alternative-variations',
      ];
      final originals = <String>[];
      for (final name in names) {
        originals.add(await File('samples/$name.pgn').readAsString());
      }
      final bytes = Uint8List.fromList(utf8.encode(originals.join('\n')));
      final temp = await Directory.systemTemp.createTemp('release-samples-');
      addTearDown(() => temp.delete(recursive: true));
      final fileSource = ManagedFileSource(
        pickedSources: _PickedBytes(bytes),
        directoryProvider: () async => temp,
      );
      final copied = await fileSource.copyToManagedStorage(
        const _PickedReference(),
        target: await fileSource.createTarget(),
        cancellation: CopyCancellation(),
        expectedLength: bytes.length,
      );
      final dbFile = File('${temp.path}/history.sqlite');
      var db = AppDatabase(NativeDatabase(dbFile));
      try {
        await db
            .into(db.pgnSources)
            .insert(
              PgnSourcesCompanion.insert(
                id: 'samples',
                displayName: 'Sanitized samples',
                accessMode: 'ManagedCopy',
                managedPath: Value(copied.reference),
                scannerVersion: DriftPgnImportService.scannerVersion,
                importState: 'ready',
                createdAtMicros: 1,
                updatedAtMicros: 1,
              ),
            );
        final service = DriftPgnImportService(
          database: db,
          fileSource: fileSource,
          idGenerator: RandomIdGenerator(),
          clock: SystemAppClock(),
        );
        final result = await service
            .start(PgnImportRequest(sourceId: 'samples'))
            .result;
        expect(result.phase, PgnImportPhase.completed);
        expect(result.indexedBlockCount, names.length);
        expect(result.diagnosticCount, 0);
        await db.close();
        db = AppDatabase(NativeDatabase(dbFile));
        final index = DriftPgnIndexRepository(db);
        final contents = DriftChessContentRepository(
          indexRepository: index,
          sourceRepository: DriftPgnSourceRepository(db),
          fileSource: fileSource,
        );
        final page = await index.search(limit: 10);
        expect(page.items, hasLength(names.length));
        expect(page.items.map((b) => b.contentType), [
          ContentType.puzzle,
          ContentType.text,
          ContentType.text,
          ContentType.puzzle,
          ContentType.puzzle,
        ]);
        for (var i = 0; i < names.length; i++) {
          final block = page.items[i];
          final raw = await fileSource.readRange(
            ManagedSourceReference(copied.reference),
            start: block.startOffset,
            endExclusive: block.endOffset,
          );
          expect(utf8.decode(raw), originals[i].trimRight());
          final content = (await contents.getById(block.id))!;
          expect(content.headers['Event'], isNotEmpty);
          if (names[i] == 'fen-start') {
            expect(content.startingFen.split(' ')[1], 'b');
            expect(content.rootMoves.single.uci, 'e7e5');
          }
          if (names[i] == 'alternative-variations') {
            expect(content.rootMoves.map((move) => move.uci), ['e2e4', 'd2d4']);
            expect(
              content.headers['X-Title'],
              'Two authored central pawn moves',
            );
          }
        }
        expect(await db.select(db.puzzleAttempts).get(), isEmpty);
        expect(await db.select(db.cycles).get(), isEmpty);
      } finally {
        await db.close();
      }
    },
  );
}

final class _PickedReference implements OpaqueSourceReference {
  const _PickedReference();
}

final class _PickedBytes implements PickedSourceAccess {
  const _PickedBytes(this.bytes);
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
