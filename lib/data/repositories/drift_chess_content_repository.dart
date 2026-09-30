import 'dart:convert';

import '../../core/errors/app_failure.dart';
import '../file_access/file_source.dart';
import '../file_access/managed_file_source.dart';
import '../../domain/chess_content/chess_content.dart';
import '../../domain/chess_content/chess_content_repository.dart';
import '../../domain/chess_content/pgn_block_index.dart';
import '../../domain/chess_content/pgn_source.dart';
import '../../domain/library/pgn_index_repository.dart';
import '../../domain/library/pgn_source_repository.dart';
import '../pgn/dartchess_content_parser.dart';

/// Loads one complete PGN game through its stable byte locator.
final class DriftChessContentRepository implements ChessContentRepository {
  const DriftChessContentRepository({
    required this.indexRepository,
    required this.sourceRepository,
    required this.fileSource,
    this.parser = const DartchessContentParser(),
  });

  final PgnIndexRepository indexRepository;
  final PgnSourceRepository sourceRepository;
  final FileSource fileSource;
  final DartchessContentParser parser;

  @override
  Future<ChessContent?> getById(String id) async {
    final block = await indexRepository.getById(id);
    if (block == null) return null;
    switch (block.parseStatus) {
      case PgnBlockParseStatus.valid || PgnBlockParseStatus.notParsed:
        // Supported blocks are parsed on demand. The index deliberately does
        // not parse and retain every move tree during import.
        break;
      case PgnBlockParseStatus.malformed:
        throw const PgnFailure(
          code: 'indexed_block_malformed',
          message: 'This library item contains PGN that cannot be read safely.',
        );
      case PgnBlockParseStatus.unsupported:
        throw const UnsupportedContentFailure(
          code: 'indexed_block_unsupported',
          message: 'This library item uses content that is not supported.',
        );
    }
    final source = await sourceRepository.getById(block.sourceId);
    if (source == null) {
      throw const FileFailure(
        code: 'source_missing',
        message: 'The PGN source is unavailable.',
      );
    }
    final reference = _referenceFor(source);
    final bytes = await fileSource.readRange(
      reference,
      start: block.startOffset,
      endExclusive: block.endOffset,
    );
    late final String pgn;
    try {
      pgn = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const PgnFailure(
        code: 'pgn_block_encoding_invalid',
        message: 'The selected PGN block cannot be decoded.',
      );
    }
    return parser.parse(pgn, contentType: block.contentType);
  }

  ManagedSourceReference _referenceFor(PgnSource source) {
    if (source.accessMode != PgnSourceAccessMode.managedCopy ||
        source.managedPath == null) {
      throw const FileFailure(
        code: 'source_relink_required',
        message: 'This PGN source must be relinked before its content can be opened.',
      );
    }
    try {
      return ManagedSourceReference(source.managedPath!);
    } on ArgumentError {
      throw const FileFailure(
        code: 'source_reference_invalid',
        message: 'The saved PGN copy is unavailable.',
      );
    }
  }
}
