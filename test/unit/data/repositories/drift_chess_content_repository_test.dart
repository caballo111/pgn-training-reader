import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/core/errors/app_failure.dart';
import 'package:pgntrainingreader/data/file_access/file_source.dart';
import 'package:pgntrainingreader/data/file_access/file_source_picker.dart';
import 'package:pgntrainingreader/data/file_access/source_fingerprint.dart';
import 'package:pgntrainingreader/data/repositories/drift_chess_content_repository.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/pgn_block_index.dart';
import 'package:pgntrainingreader/domain/chess_content/pgn_source.dart';
import 'package:pgntrainingreader/domain/library/pgn_index_repository.dart';
import 'package:pgntrainingreader/domain/library/pgn_source_repository.dart';

void main() {
  for (final token in ['Z0', '--']) {
    test('loads an inferred $token introduction without altering source bytes', () async {
      final bytes = Uint8List.fromList(
        '[White "1) Introduction"]\n[PlyCount "1"]\n\n{Read first} 1. $token *\n'
            .codeUnits,
      );
      final original = Uint8List.fromList(bytes);
      final fingerprint = FileFingerprintInput(
        length: bytes.length,
        modifiedAt: null,
        samples: [FingerprintSample(offset: 0, bytes: bytes)],
      );
      final file = _RecordingRangeSource(
        bytes,
        currentFingerprintInput: fingerprint,
      );
      final repository = DriftChessContentRepository(
        indexRepository: _Blocks([
          PgnBlockIndex(
            id: 'intro',
            sourceId: 'source',
            startOffset: 0,
            endOffset: bytes.length,
            ordinal: 0,
            contentType: ContentType.demonstration,
            inferredClassification: true,
            parseStatus: PgnBlockParseStatus.notParsed,
          ),
        ]),
        sourceRepository: _OneSource(
          fingerprint: SourceFingerprint.compute(fingerprint),
        ),
        fileSource: file,
      );
      final content = (await repository.getById('intro'))!;
      expect(content.contentType, ContentType.instruction);
      expect(content.comments, ['Read first']);
      expect(content.rootMoves, isEmpty);
      expect(content.instructionalPlaceholder, token);
      expect(bytes, original);
      expect(file.lastRead, original);
    });
  }

  test(
    'loads exactly the indexed first, middle, and last byte ranges',
    () async {
      const games = [
        '[Event "First"]\n[Result "1-0"]\n\n1. e4 e5 1-0\n',
        '[Event "Middle"]\n[Result "0-1"]\n\n1. d4 d5 0-1\n',
        '[Event "Last"]\n[Result "*"]\n\n1. c4 e5 *\n',
      ];
      final sourceBytes = Uint8List.fromList(games.join('\n').codeUnits);
      final blocks = <PgnBlockIndex>[];
      var offset = 0;
      for (var index = 0; index < games.length; index++) {
        final bytes = Uint8List.fromList(games[index].codeUnits);
        final start = _find(sourceBytes, bytes, offset);
        final end = start + bytes.length;
        blocks.add(
          PgnBlockIndex(
            id: 'game-$index',
            sourceId: 'source',
            startOffset: start,
            endOffset: end,
            ordinal: index,
            contentType: ContentType.demonstration,
            parseStatus: PgnBlockParseStatus.notParsed,
          ),
        );
        offset = end;
      }
      final sourceFingerprintInput = FileFingerprintInput(
        length: sourceBytes.length,
        modifiedAt: null,
        samples: [FingerprintSample(offset: 0, bytes: sourceBytes)],
      );
      final rangeSource = _RecordingRangeSource(
        sourceBytes,
        currentFingerprintInput: sourceFingerprintInput,
      );
      final repository = DriftChessContentRepository(
        indexRepository: _Blocks(blocks),
        sourceRepository: _OneSource(
          fingerprint: SourceFingerprint.compute(sourceFingerprintInput),
        ),
        fileSource: rangeSource,
      );

      for (var index = 0; index < blocks.length; index++) {
        final content = await repository.getById('game-$index');
        expect(content?.headers['Event'], ['First', 'Middle', 'Last'][index]);
        expect(
          rangeSource.lastRead,
          Uint8List.fromList(games[index].codeUnits),
        );
        expect(rangeSource.lastStart, blocks[index].startOffset);
        expect(rangeSource.lastEnd, blocks[index].endOffset);
      }
    },
  );

  test(
    'checks the source fingerprint before reading a stored locator',
    () async {
      final bytes = Uint8List.fromList(
        '[Event "Game"]\n[Result "*"]\n\n1. e4 *\n'.codeUnits,
      );
      final block = PgnBlockIndex(
        id: 'game',
        sourceId: 'source',
        startOffset: 0,
        endOffset: bytes.length,
        ordinal: 0,
        contentType: ContentType.demonstration,
        parseStatus: PgnBlockParseStatus.notParsed,
      );
      final rangeSource = _RecordingRangeSource(
        bytes,
        currentFingerprintInput: FileFingerprintInput(
          length: bytes.length,
          modifiedAt: DateTime.utc(2026),
          samples: [FingerprintSample(offset: 0, bytes: bytes)],
        ),
      );
      final repository = DriftChessContentRepository(
        indexRepository: _Blocks([block]),
        sourceRepository: _OneSource(
          accessMode: PgnSourceAccessMode.externalReference,
          externalReference: 'content://com.example.documents/document/42',
          fingerprint: 'stale-fingerprint',
        ),
        fileSource: rangeSource,
      );

      await expectLater(
        repository.getById('game'),
        throwsA(
          isA<FileFailure>().having(
            (failure) => failure.code,
            'code',
            'source_changed',
          ),
        ),
      );
      expect(rangeSource.lastRead, isNull);
      expect(
        rangeSource.lastFingerprintReference,
        isA<ExternalSourceReference>(),
      );
    },
  );
}

int _find(Uint8List whole, Uint8List part, int from) {
  for (var index = from; index <= whole.length - part.length; index++) {
    var matches = true;
    for (var partIndex = 0; partIndex < part.length; partIndex++) {
      if (whole[index + partIndex] != part[partIndex]) {
        matches = false;
        break;
      }
    }
    if (matches) return index;
  }
  throw StateError('Test PGN block was not found in combined source bytes.');
}

final class _RecordingRangeSource implements FileSource {
  _RecordingRangeSource(this.bytes, {this.currentFingerprintInput});

  final Uint8List bytes;
  final FileFingerprintInput? currentFingerprintInput;
  Uint8List? lastRead;
  OpaqueSourceReference? lastFingerprintReference;
  int? lastStart;
  int? lastEnd;

  @override
  Future<Uint8List> readRange(
    OpaqueSourceReference reference, {
    required int start,
    required int endExclusive,
  }) async {
    lastStart = start;
    lastEnd = endExclusive;
    lastRead = Uint8List.fromList(bytes.sublist(start, endExclusive));
    return lastRead!;
  }

  @override
  Future<FileFingerprintInput> fingerprintInput(
    OpaqueSourceReference reference, {
    DateTime? modifiedAt,
    int sampleSize = 4096,
  }) async {
    lastFingerprintReference = reference;
    return currentFingerprintInput!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Blocks implements PgnIndexRepository {
  _Blocks(this.items);

  final List<PgnBlockIndex> items;

  @override
  Future<PgnBlockIndex?> getById(String id) async =>
      items.where((item) => item.id == id).firstOrNull;

  @override
  Future<PgnIndexPage> search({
    PgnIndexFilter filter = const PgnIndexFilter(),
    PgnIndexSort sort = PgnIndexSort.sourceOrder,
    int offset = 0,
    required int limit,
  }) => throw UnimplementedError();

  @override
  Future<int> countForSource(String sourceId) => throw UnimplementedError();
}

final class _OneSource implements PgnSourceRepository {
  _OneSource({
    this.fingerprint,
    this.accessMode = PgnSourceAccessMode.managedCopy,
    this.externalReference,
  });

  final String? fingerprint;
  final PgnSourceAccessMode accessMode;
  final String? externalReference;

  @override
  Future<PgnSource?> getById(String id) async => PgnSource(
    id: id,
    displayName: 'Library',
    accessMode: accessMode,
    managedPath: accessMode == PgnSourceAccessMode.managedCopy
        ? '0123456789abcdef0123456789abcdef'
        : null,
    externalReference: externalReference,
    scannerVersion: 1,
    importState: 'indexed',
    fingerprint: fingerprint,
    modifiedAt: null,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  @override
  Future<void> update(PgnSource source) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
