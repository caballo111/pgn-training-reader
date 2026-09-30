import 'package:dartchess/dartchess.dart';

import '../../core/errors/app_failure.dart';
import '../../domain/chess_content/chess_content.dart';
import '../../domain/chess_content/content_type.dart';
import '../../domain/chess_content/move_node.dart';

/// Converts one indexed PGN block into its immutable chess-content tree.
final class DartchessContentParser {
  const DartchessContentParser();

  ChessContent parse(
    String pgn, {
    required ContentType contentType,
    bool? inferredClassification,
  }) {
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
          : game.moves.children
                .map((child) => _node(child, initialPosition))
                .toList(growable: false);
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

  MoveNode _node(PgnChildNode<PgnNodeData> child, Position before) {
    final move = before.parseSan(child.data.san);
    if (move == null) {
      throw const PgnFailure(
        code: 'pgn_illegal_authored_move',
        message: 'The selected PGN block contains a move that cannot be read safely.',
      );
    }
    final after = before.play(move);
    final comments = <String>[
      ...?child.data.startingComments,
      ...?child.data.comments,
    ];
    return MoveNode(
      san: child.data.san,
      uci: move.uci,
      fenBefore: before.fen,
      fenAfter: after.fen,
      comments: comments,
      nags: child.data.nags ?? const [],
      children: child.children
          .map((next) => _node(next, after))
          .toList(growable: false),
    );
  }
}
