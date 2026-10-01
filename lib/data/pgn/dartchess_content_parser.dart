import 'package:dartchess/dartchess.dart';

import 'dart:convert';

import '../../core/errors/app_failure.dart';
import '../../domain/chess_content/chess_content.dart';
import '../../domain/chess_content/content_type.dart';
import '../../domain/chess_content/move_node.dart';
import 'pgn_header_reader.dart';
import 'scanner/pgn_boundary_scanner.dart';

/// Converts one indexed PGN block into its immutable chess-content tree.
final class DartchessContentParser {
  const DartchessContentParser();

  ChessContent parse(
    String pgn, {
    required ContentType contentType,
    bool? inferredClassification,
  }) {
    _enforceInputLimits(pgn);
    if (contentType == ContentType.unsupported) {
      throw const UnsupportedContentFailure(
        code: 'unsupported_content',
        message: 'This PGN content is not supported.',
      );
    }
    try {
      final game = PgnGame.parsePgn(pgn, initHeaders: PgnGame.emptyHeaders);
      final variant = game.headers['Variant'];
      if (variant != null && variant != 'Standard') {
        throw const UnsupportedContentFailure(
          code: 'unsupported_chess_variant',
          message: 'This PGN uses a chess variant that is not supported.',
        );
      }
      if (game.headers.isEmpty && game.moves.children.isEmpty) {
        throw const PgnFailure(
          code: 'empty_pgn_block',
          message: 'The selected PGN block is empty.',
        );
      }
      final initialPosition = PgnGame.startingPosition(game.headers);
      final inferred =
          inferredClassification ?? !game.headers.containsKey('X-ContentType');
      // Dartchess normalizes several null-move spellings to `--`. Check the
      // original movetext too: only the observed Z0 and -- instructional
      // exports qualify, never null moves inside games or variations.
      final movetext = pgn
          .replaceAll(RegExp(r'^\s*\[.*\]\s*$', multiLine: true), '')
          .replaceAll(RegExp(r'\{[^}]*\}', dotAll: true), '')
          .replaceAll(RegExp(r';[^\r\n]*'), '')
          .trim();
      final placeholderMatch = RegExp(r'^1\.\s*(Z0|--)\s*\*$')
          .firstMatch(movetext);
      final placeholder =
          placeholderMatch != null &&
          game.moves.children.length == 1 &&
          game.moves.children.single.data.san == '--' &&
          game.moves.children.single.children.isEmpty &&
          game.headers['SetUp'] != '1' &&
          !game.headers.containsKey('FEN') &&
          (game.headers['X-ContentType'] == null ||
              const {
                'Text',
                'Instruction',
                'Demonstration',
              }.contains(game.headers['X-ContentType'])) &&
          contentType != ContentType.puzzle &&
          (game.comments.isNotEmpty ||
              (game.moves.children.single.data.comments?.isNotEmpty ?? false) ||
              (game.moves.children.single.data.startingComments?.isNotEmpty ??
                  false));
      final roots = placeholder
          ? <MoveNode>[]
          : _nodes(game.moves.children, initialPosition);
      return ChessContent(
        headers: Map<String, String>.from(game.headers),
        startingFen: initialPosition.fen,
        rootMoves: roots,
        comments: [
          ...game.comments,
          if (placeholder) ...?game.moves.children.single.data.startingComments,
          if (placeholder) ...?game.moves.children.single.data.comments,
        ],
        result: game.headers['Result'],
        contentType: placeholder && inferred ? ContentType.text : contentType,
        inferredClassification: inferred,
        instructionalPlaceholder: placeholder
            ? placeholderMatch.group(1)
            : null,
      );
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const PgnFailure(
        code: 'pgn_content_parse_failed',
        message: 'The selected PGN block could not be parsed as chess content.',
      );
    }
  }

  void _enforceInputLimits(String pgn) {
    final sourceBytes = utf8.encode(pgn);
    if (sourceBytes.length > 8 * 1024 * 1024) {
      throw const PgnFailure(
        code: 'pgn_block_too_large',
        message: 'The selected PGN block exceeds the supported size.',
      );
    }
    var braceComment = false;
    var semicolonComment = false;
    var tag = false;
    var quoted = false;
    var escaped = false;
    var depth = 0;
    var lexicalLength = 0;
    for (final unit in pgn.runes) {
      if (braceComment || semicolonComment || tag) {
        lexicalLength += unit <= 0x7f
            ? 1
            : unit <= 0x7ff
            ? 2
            : unit <= 0xffff
            ? 3
            : 4;
        final limit = braceComment || semicolonComment
            ? PgnBoundaryScanner.maximumCommentBytes
            : PgnHeaderReader.maximumTagCharacters;
        if (lexicalLength > limit) {
          throw const PgnFailure(
            code: 'pgn_construct_too_large',
            message: 'The selected PGN contains an oversized tag or comment.',
          );
        }
      }
      if (semicolonComment) {
        if (unit == 10 || unit == 13) {
          semicolonComment = false;
          lexicalLength = 0;
        }
      } else if (braceComment) {
        if (unit == 125) {
          braceComment = false;
          lexicalLength = 0;
        }
      } else if (tag) {
        if (quoted && escaped) {
          escaped = false;
        } else if (quoted && unit == 92) {
          escaped = true;
        } else if (unit == 34) {
          quoted = !quoted;
        } else if (unit == 93 && !quoted) {
          tag = false;
          lexicalLength = 0;
        }
      } else if (unit == 123) {
        braceComment = true;
        lexicalLength = 1;
      } else if (unit == 59) {
        semicolonComment = true;
        lexicalLength = 1;
      } else if (unit == 91) {
        tag = true;
        lexicalLength = 1;
      } else if (unit == 40) {
        if (++depth > PgnBoundaryScanner.maximumVariationDepth) {
          throw const PgnFailure(
            code: 'pgn_variation_too_deep',
            message: 'The selected PGN contains variations nested too deeply.',
          );
        }
      } else if (unit == 41 && depth > 0) {
        depth--;
      }
    }
  }

  List<MoveNode> _nodes(List<PgnChildNode<PgnNodeData>> roots, Position start) {
    final converted = <PgnChildNode<PgnNodeData>, MoveNode>{};
    final pending = <(PgnChildNode<PgnNodeData>, Position, bool)>[];
    for (final root in roots.reversed) {
      pending.add((root, start, false));
    }
    while (pending.isNotEmpty) {
      final (child, before, expanded) = pending.removeLast();
      final move = before.parseSan(child.data.san);
      if (move == null) {
        throw const PgnFailure(
          code: 'pgn_illegal_authored_move',
          message: 'The selected PGN block contains a move that cannot be read safely.',
        );
      }
      final after = before.play(move);
      if (!expanded) {
        pending.add((child, before, true));
        for (final next in child.children.reversed) {
          pending.add((next, after, false));
        }
        continue;
      }
      converted[child] = MoveNode(
        san: child.data.san,
        uci: move.uci,
        fenBefore: before.fen,
        fenAfter: after.fen,
        startingComments: child.data.startingComments ?? const [],
        comments: child.data.comments ?? const [],
        nags: child.data.nags ?? const [],
        children: child.children
            .map((next) => converted[next]!)
            .toList(growable: false),
      );
    }
    return roots.map((root) => converted[root]!).toList(growable: false);
  }
}
