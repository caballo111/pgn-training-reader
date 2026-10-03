import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/content_type.dart';
import '../../../domain/chess_content/move_node.dart';
import '../../../domain/training/puzzle_attempt.dart';
import '../../../domain/training/puzzle_evaluator.dart';

enum PuzzleInteractionPhase { solving, failedPractice, review }

/// Safe, immutable data for presenting one puzzle attempt.
///
/// While the attempt is unfinished, this projection contains only the current
/// position and moves accepted from the user. The authored tree and its
/// annotations are copied into [solution] only once evaluation has finalized
/// the attempt (including an explicit reveal).
final class PuzzlePresentationState {
  PuzzlePresentationState._({
    required this.currentFen,
    required this.startingFen,
    required this.sideToMove,
    required this.attemptStatus,
    required this.outcome,
    required List<String> playedMoves,
    required List<PuzzlePresentationMove>? solution,
    required List<String> comments,
    this.entries = const [],
    this.rejections = const [],
    this.rejectedMove,
    this.phase = PuzzleInteractionPhase.solving,
    this.learnerSide = PuzzleSide.white,
    this.isPredictingReply = false,
    this.hintSquare,
    this.feedback,
    this.usedFullLineFallback = false,
    this.policyLabel = 'All Moves',
    this.boardOrientation,
    this.hintCount = 0,
  }) : playedMoves = List.unmodifiable(playedMoves),
       solution = solution == null ? null : List.unmodifiable(solution),
       comments = List.unmodifiable(comments);

  /// Creates a presentation-safe projection of the puzzle and evaluator.
  factory PuzzlePresentationState.fromDomain({
    required ChessContent puzzle,
    required PuzzleEvaluationState evaluation,
    bool? solutionVisibleOverride,
    List<PuzzlePlayedMove> entries = const [],
    List<PuzzleRejection> rejections = const [],
    PuzzleRejection? rejectedMove,
    PuzzleInteractionPhase? phase,
    PuzzleSide? learnerSide,
    bool isPredictingReply = false,
    String? hintSquare,
    String? feedback,
    bool usedFullLineFallback = false,
    String policyLabel = 'All Moves',
    PuzzleSide? boardOrientation,
    int hintCount = 0,
  }) {
    if (puzzle.contentType != ContentType.puzzle) {
      throw ArgumentError.value(
        puzzle.contentType,
        'puzzle.contentType',
        'Puzzle presentation requires Puzzle content.',
      );
    }

    // Scoring may already be finalized after the first wrong move while the
    // learner continues practicing. An explicit active phase must keep all
    // authored text/tree content concealed, even for that recorded failure.
    final isStillPracticing =
        phase == PuzzleInteractionPhase.solving ||
        phase == PuzzleInteractionPhase.failedPractice;
    final solutionVisible =
        !isStillPracticing &&
        (solutionVisibleOverride ??
            (evaluation.isFinalized || evaluation.solutionRevealed));
    return PuzzlePresentationState._(
      currentFen: evaluation.currentFen,
      entries: List.unmodifiable(entries),
      rejections: List.unmodifiable(rejections),
      rejectedMove: rejectedMove,
      phase:
          phase ??
          (solutionVisible
              ? PuzzleInteractionPhase.review
              : evaluation.attempt.outcome == PuzzleAttemptOutcome.wrongMove
              ? PuzzleInteractionPhase.failedPractice
              : PuzzleInteractionPhase.solving),
      learnerSide:
          learnerSide ??
          (puzzle.startingFen.split(' ')[1] == 'b'
              ? PuzzleSide.black
              : PuzzleSide.white),
      isPredictingReply: isPredictingReply,
      hintSquare: hintSquare,
      feedback: feedback,
      usedFullLineFallback: usedFullLineFallback,
      policyLabel: policyLabel,
      boardOrientation: boardOrientation,
      hintCount: hintCount,
      startingFen: puzzle.startingFen,
      sideToMove: evaluation.sideToMove,
      attemptStatus: evaluation.attempt.status,
      outcome: evaluation.attempt.outcome,
      playedMoves: entries.isNotEmpty
          ? [
              for (final entry in entries)
                if (entry.accepted) entry.uci,
            ]
          : [
              for (final move in evaluation.moves)
                if (move.legal && move.accepted) move.move,
            ],
      solution: solutionVisible
          ? [
              for (final move in puzzle.rootMoves)
                PuzzlePresentationMove._(move),
            ]
          : null,
      // Block comments can also contain authored answers, so keep them behind
      // the same terminal-state gate as move annotations.
      comments: solutionVisible ? puzzle.comments : const [],
    );
  }

  /// FEN for the current board position only.
  final String currentFen;

  /// Authored starting position used to replay the revealed line for review.
  final String startingFen;

  /// Side to move in [currentFen].
  final PuzzleSide sideToMove;

  /// Persisted lifecycle status, safe to use for active/paused/review chrome.
  final PuzzleAttemptStatus attemptStatus;

  /// Persisted terminal outcome, or null while active or paused.
  final PuzzleAttemptOutcome? outcome;

  /// User-submitted moves accepted along the authored line, in UCI notation.
  /// Rejected submissions are omitted from the active presentation projection.
  final List<String> playedMoves;

  /// Authored solution tree, including future positions and annotations.
  /// This is `null` until the attempt has finalized or been explicitly revealed.
  final List<PuzzlePresentationMove>? solution;

  /// Block-level comments, withheld while the attempt is unfinished.
  final List<String> comments;

  final List<PuzzlePlayedMove> entries;

  /// Distinct rejected submissions, deduplicated by authored path and UCI.
  final List<PuzzleRejection> rejections;

  /// Most recent rejected gesture, including repeats, for immediate feedback.
  final PuzzleRejection? rejectedMove;
  final PuzzleInteractionPhase phase;
  final PuzzleSide learnerSide;
  final bool isPredictingReply;
  final String? hintSquare;
  final String? feedback;
  final bool usedFullLineFallback;
  final String policyLabel;
  final PuzzleSide? boardOrientation;
  final int hintCount;

  bool get isSolutionVisible => solution != null;
}

/// Durable, distinct rejected move history for one attempt.
final class PuzzleRejection {
  PuzzleRejection({
    required this.ordinal,
    required this.uci,
    required List<String> authoredPath,
    required this.fenBefore,
    required this.actor,
    required this.legal,
    this.san,
    this.submittedAt,
    String? id,
  }) : authoredPath = List.unmodifiable(authoredPath),
       id = id ?? 'rejection-$ordinal';

  final String id;
  final int ordinal;
  final String uci;
  final String? san;
  final List<String> authoredPath;
  final String fenBefore;
  final String actor;
  final bool legal;
  final DateTime? submittedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'ordinal': ordinal,
    'uci': uci,
    'san': san,
    'authoredPath': authoredPath,
    'fenBefore': fenBefore,
    'actor': actor,
    'legal': legal,
    'submittedAt': submittedAt?.toIso8601String(),
  };

  factory PuzzleRejection.fromJson(Map<String, dynamic> data) =>
      PuzzleRejection(
        id: data['id'] as String?,
        ordinal: data['ordinal'] as int,
        uci: data['uci'] as String,
        san: data['san'] as String?,
        authoredPath: [
          for (final move in data['authoredPath'] as List) move as String,
        ],
        fenBefore: data['fenBefore'] as String,
        actor: data['actor'] as String,
        legal: data['legal'] as bool,
        submittedAt: data['submittedAt'] == null
            ? null
            : DateTime.parse(data['submittedAt'] as String),
      );
}

/// A solution-tree node exposed only by a finalized presentation state.
///
/// Keeping this separate from [MoveNode] ensures widgets depend on the safe
/// presentation model rather than the complete imported content model.
final class PuzzlePresentationMove {
  PuzzlePresentationMove._(MoveNode move)
    : san = move.san,
      uci = move.uci,
      fenBefore = move.fenBefore,
      fenAfter = move.fenAfter,
      comments = List.unmodifiable([
        ...move.startingComments,
        ...move.comments,
      ]),
      nags = List.unmodifiable(move.nags),
      children = List.unmodifiable([
        for (final child in move.children) PuzzlePresentationMove._(child),
      ]);

  final String san;
  final String uci;
  final String fenBefore;
  final String fenAfter;
  final List<String> comments;
  final List<int> nags;
  final List<PuzzlePresentationMove> children;
}

/// Played interaction only: no future solution nodes or authored comments.
final class PuzzlePlayedMove {
  const PuzzlePlayedMove({
    required this.uci,
    required this.san,
    required this.moveNumber,
    required this.side,
    required this.actor,
    required this.accepted,
  });
  final String uci;
  final String san;
  final int moveNumber;
  final PuzzleSide side;
  final String actor;
  final bool accepted;
  String get label =>
      '$moveNumber${side == PuzzleSide.white ? '.' : '...'} $san${accepted ? '' : ' ✗'}';
  Map<String, dynamic> toJson() => {
    'uci': uci,
    'san': san,
    'moveNumber': moveNumber,
    'side': side.name,
    'actor': actor,
    'accepted': accepted,
  };
  factory PuzzlePlayedMove.fromJson(Map<String, dynamic> data) =>
      PuzzlePlayedMove(
        uci: data['uci'] as String,
        san: data['san'] as String,
        moveNumber: data['moveNumber'] as int,
        side: PuzzleSide.values.byName(data['side'] as String),
        actor: data['actor'] as String,
        accepted: data['accepted'] as bool,
      );
}
