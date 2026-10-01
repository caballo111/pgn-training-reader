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
  group('malformed import diagnostics', () {
    test(
      'skips a malformed middle block and preserves valid neighbors',
      () async {
        final bytes = _bytes('''[Event "before"]
[Result "*"]
1. e4 *

[Event "broken"]
[White "unterminated
1. d4 *

[Event "after"]
[Result "*"]
1. c4 *
''');
        final run = await _import(bytes);
        expect(run.result.indexedBlockCount, 2);
        final blocks = await run.db.select(run.db.pgnBlocks).get();
        expect(blocks.map((b) => b.ordinal), [0, 2]);
        expect(blocks.map((b) => b.event), ['before', 'after']);
        expect(run.result.diagnosticCount, 1);
        expect(
          run.streamDiagnostics.single.category,
          PgnImportDiagnosticCategory.malformedBlock,
        );
        expect(run.streamDiagnostics.single.blockOrdinal, 1);
        expect(run.persistedDiagnostics.single.blockOrdinal, 1);
        expect(
          run.streamDiagnostics.single.message,
          isNot(contains('unterminated')),
        );
      },
    );

    test(
      'invalid UTF-8 block is skipped while following block is indexed',
      () async {
        final prefix = _bytes(
          '[Event "before"]\n1. e4 *\n\n[Event "bad"]\n1. e5 ',
        );
        final suffix = _bytes(' *\n\n[Event "after"]\n1. d4 *');
        final run = await _import(
          Uint8List.fromList([...prefix, 0xff, ...suffix]),
        );
        expect(run.result.indexedBlockCount, 2);
        expect(
          (await run.db.select(run.db.pgnBlocks).get()).map((b) => b.ordinal),
          [0, 2],
        );
        expect(run.streamDiagnostics.map((d) => d.category), [
          PgnImportDiagnosticCategory.invalidEncoding,
        ]);
        expect(run.persistedDiagnostics, hasLength(1));
      },
    );

    test('unknown content type stays unsupported and is diagnosed', () async {
      final run = await _import(
        _bytes('[Event "unknown"]\n[X-ContentType "Secret"]\n1. e4 *'),
      );
      final block = await run.db.select(run.db.pgnBlocks).getSingle();
      expect(block.contentType, 'Unsupported');
      expect(block.authoredContentType, 'Secret');
      expect(
        run.streamDiagnostics.map((d) => d.category),
        contains(PgnImportDiagnosticCategory.unsupportedContent),
      );
      expect(run.persistedDiagnostics, hasLength(1));
    });

    test('duplicate authored IDs remain distinct and all collisions are flagged', () async {
      final games = List.generate(
        52,
        (i) =>
            '[Event "game-$i"]\n[X-ContentType "Puzzle"]\n[X-ExerciseId "same"]\n1. e4 *',
      ).join('\n\n');
      final run = await _import(_bytes(games));
      final blocks = await run.db.select(run.db.pgnBlocks).get();
      expect(blocks, hasLength(52));
      expect(blocks.map((b) => b.id).toSet(), hasLength(52));
      expect(
        blocks.where((b) => b.diagnosticSummary == 'duplicateExerciseId'),
        hasLength(52),
      );
      expect(
        run.persistedDiagnostics.where(
          (d) => d.diagnosticCode == 'duplicateExerciseId',
        ),
        hasLength(52),
      );
    });

    test(
      'empty and comment-only input completes with clear zero-content info',
      () async {
        for (final input in [
          '',
          '  \n{only a comment}\n; and another comment\n',
        ]) {
          final run = await _import(_bytes(input));
          expect(run.result.phase, PgnImportPhase.completed);
          expect(run.result.indexedBlockCount, 0);
          expect(run.result.diagnosticCount, 1);
          expect(
            run.streamDiagnostics.single.severity,
            PgnImportDiagnosticSeverity.info,
          );
          expect(run.persistedDiagnostics.single.severity, 'info');
        }
      },
    );

    test('missing result at EOF or before next header is diagnosed', () async {
      for (final input in [
        '[Event "no-result"]\n1. e4 e5',
        '[Event "no-result"]\n1. e4 e5\n[Event "next"]\n1. d4 *',
      ]) {
        final run = await _import(_bytes(input));
        expect(
          run.persistedDiagnostics.where(
            (d) => d.diagnosticCode == 'malformedBlock',
          ),
          isNotEmpty,
        );
        expect(
          run.streamDiagnostics.any(
            (d) => d.category == PgnImportDiagnosticCategory.malformedBlock,
          ),
          isTrue,
        );
      }
    });

    test(
      'limits persisted and streamed diagnostics across malformed neighbors',
      () async {
        final malformed = List.generate(
          1005,
          (i) => '[Event "broken-$i"]\n[White "unfinished\n1. e4 *',
        ).join('\n');
        final run = await _import(_bytes(malformed));
        expect(run.result.diagnosticCount, 1000);
        expect(run.streamDiagnostics, hasLength(1000));
        expect(run.persistedDiagnostics, hasLength(1000));
        expect(
          (await run.db.select(run.db.importJobs).getSingle()).diagnosticCount,
          1000,
        );
      },
    );

    test('oversized block is skipped and following block is still indexed', () async {
      final before = '[Event "before"]\n1. e4 *\n';
      final oversized =
          '[Event "large"]\n${List.filled(8 * 1024 * 1024 + 32, 'x').join()} *\n';
      final after = '[Event "after"]\n1. d4 *';
      final run = await _import(_bytes('$before$oversized$after'));
      final blocks = await run.db.select(run.db.pgnBlocks).get();
      expect(blocks.map((block) => block.event), ['before', 'after']);
      expect(run.result.indexedBlockCount, 2);
      expect(
        run.streamDiagnostics.map((diagnostic) => diagnostic.category),
        contains(PgnImportDiagnosticCategory.malformedBlock),
      );
    });
  });
}

Future<_ImportRun> _import(Uint8List bytes) async {
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
  final operation = DriftPgnImportService(
    database: db,
    fileSource: _BytesFileSource(bytes),
    idGenerator: _SequenceIds(),
    clock: _Clock(DateTime.utc(2026)),
  ).start(PgnImportRequest(sourceId: 'source'));
  final diagnosticsFuture = operation.diagnostics.toList();
  final result = await operation.result;
  final streamDiagnostics = await diagnosticsFuture;
  return _ImportRun(
    db,
    result,
    streamDiagnostics,
    await db.select(db.importDiagnostics).get(),
  );
}

Uint8List _bytes(String source) => Uint8List.fromList(source.codeUnits);

final class _ImportRun {
  const _ImportRun(
    this.db,
    this.result,
    this.streamDiagnostics,
    this.persistedDiagnostics,
  );
  final AppDatabase db;
  final PgnImportResult result;
  final List<PgnImportDiagnostic> streamDiagnostics;
  final List<ImportDiagnostic> persistedDiagnostics;
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

final class _SequenceIds implements IdGenerator {
  int value = 0;
  @override
  String generateId() => 'id-${value++}';
}

final class _Clock implements AppClock {
  const _Clock(this.utcNow);
  @override
  final DateTime utcNow;
  @override
  Duration get monotonicElapsed => Duration.zero;
}
