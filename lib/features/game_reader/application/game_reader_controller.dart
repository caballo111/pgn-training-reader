import 'package:dartchess/dartchess.dart' as chess;

import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/move_node.dart';
import '../../../domain/training/puzzle_evaluator.dart';
import '../../../shared/chessboard/chessboard_adapter.dart';
import 'reader_navigation_state.dart';

/// Position and move hints derived from the active path in a reader move tree.
final class GameReaderPosition {
  GameReaderPosition({
    required this.position,
    required Map<String, Set<String>> legalDestinations,
    required this.lastMoveUci,
  }) : legalDestinations = Map.unmodifiable({
         for (final entry in legalDestinations.entries)
           entry.key: Set<String>.unmodifiable(entry.value),
       });

  /// The current legal chess position reconstructed by replaying the move path.
  final chess.Chess position;

  /// Legal destinations for each origin square, in algebraic notation.
  final Map<String, Set<String>> legalDestinations;

  /// UCI for the last move on the active path, or `null` at the start.
  final String? lastMoveUci;

  /// FEN and active color from the reconstructed position.
  String get fen => position.fen;

  PuzzleSide get sideToMove => switch (position.turn) {
    chess.Side.white => PuzzleSide.white,
    chess.Side.black => PuzzleSide.black,
  };

  /// Converts this domain snapshot for display by chessground.
  ChessboardViewData forBoard({required PuzzleSide orientation}) =>
      ChessboardAdapter.fromPosition(
        fen: fen,
        sideToMove: sideToMove,
        legalDestinations: legalDestinations,
        orientation: orientation,
        lastMoveUci: lastMoveUci,
      );
}

/// Controls reader navigation and derives board state from authored moves.
///
/// The `san`, `fenBefore`, and `fenAfter` strings on [MoveNode] are retained
/// for faithful display and diagnostics. This controller reconstructs the
/// active position by replaying the selected UCI move path from the starting
/// FEN, so the chess library determines the current side to move.
final class GameReaderController {
  GameReaderController(ChessContent content)
    : _content = content,
      _navigation = ReaderNavigationState.initial(content) {
    // Validate the starting position at construction, even when the content
    // has no moves and no later position read would otherwise parse it.
    _positionFor(_navigation);
  }

  final ChessContent _content;
  ReaderNavigationState _navigation;

  ReaderNavigationState get navigation => _navigation;

  ChessContent get content => _content;

  /// Current board position, legality hints, and active path's last move.
  GameReaderPosition get current => _positionFor(_navigation);

  void first() => _moveTo(_navigation.first());

  void previous() => _moveTo(_navigation.previous());

  void next() => _moveTo(_navigation.next());

  void last() => _moveTo(_navigation.last());

  void selectVariation(int childIndex) =>
      _moveTo(_navigation.selectVariation(childIndex));

  void returnToParentLine() => _moveTo(_navigation.returnToParentLine());

  void _moveTo(ReaderNavigationState next) {
    // Reconstruct before publishing navigation so malformed authored move
    // data cannot leave the controller at a state it cannot render.
    _positionFor(next);
    _navigation = next;
  }

  GameReaderPosition _positionFor(ReaderNavigationState navigation) {
    final chess.Setup setup;
    try {
      setup = chess.Setup.parseFen(_content.startingFen);
    } on FormatException catch (error) {
      throw FormatException(
        'Invalid starting FEN: $error',
        _content.startingFen,
      );
    }

    chess.Chess position;
    try {
      position = chess.Chess.fromSetup(setup);
    } on chess.PositionSetupException catch (error) {
      throw FormatException(
        'Invalid starting chess position: $error',
        _content.startingFen,
      );
    }

    String? lastMoveUci;
    for (final node in navigation.path) {
      final move = chess.Move.parse(node.uci);
      if (move == null) {
        throw FormatException('Invalid UCI move in move tree.', node.uci);
      }
      try {
        position = position.play(move) as chess.Chess;
      } on chess.PlayException catch (error) {
        throw FormatException('Illegal move in move tree: $error', node.uci);
      }
      lastMoveUci = node.uci;
    }

    return GameReaderPosition(
      position: position,
      legalDestinations: {
        for (final entry in chess.makeLegalMoves(position).entries)
          entry.key.name: {
            for (final destination in entry.value) destination.name,
          },
      },
      lastMoveUci: lastMoveUci,
    );
  }
}
