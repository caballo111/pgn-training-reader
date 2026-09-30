import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chessground/chessground.dart' as chessground;
import 'package:pgntrainingreader/core/utilities/id_generator.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/domain/training/attempt_move.dart';
import 'package:pgntrainingreader/domain/training/authored_line_puzzle_evaluator.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
import 'package:pgntrainingreader/domain/training/puzzle_evaluator.dart';
import 'package:pgntrainingreader/domain/training/timing_segment.dart';
import 'package:pgntrainingreader/domain/training/training_repository.dart';
import 'package:pgntrainingreader/features/puzzle_solver/application/puzzle_presentation_state.dart';
import 'package:pgntrainingreader/features/puzzle_solver/application/puzzle_solver_controller.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_solution_review_view.dart';
import 'package:pgntrainingreader/features/puzzle_solver/presentation/puzzle_solving_view.dart';

const _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';
final _puzzle = ChessContent(
  headers: const {},
  startingFen: _fen,
  contentType: ContentType.puzzle,
  rootMoves: [
    MoveNode(
      san: 'e4',
      uci: 'e2e4',
      fenBefore: _fen,
      fenAfter: _afterE4,
      children: [
        MoveNode(
          san: 'e5',
          uci: 'e7e5',
          fenBefore: _afterE4,
          fenAfter:
              'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
        ),
      ],
    ),
  ],
);
final _started = DateTime.utc(2026);

final class _Ids implements IdGenerator {
  int value = 0;
  @override
  String generateId() => 'golden-${value++}';
}

final class _Repository implements TrainingRepository {
  _Repository(this.attempt);
  PuzzleAttempt attempt;
  final List<AttemptMove> moves = [];

  @override
  Future<PuzzleAttempt?> getAttempt(String id) async => attempt;
  @override
  Future<List<AttemptMove>> listAttemptMoves(String id) async => List.of(moves);
  @override
  Future<void> recordSubmittedMove({
    required AttemptMove move,
    required PuzzleAttempt updatedAttempt,
    TimingSegment? closingTimingSegment,
  }) async {
    moves.add(move);
    attempt = updatedAttempt;
  }

  @override
  Future<void> finalizeAttempt({
    required PuzzleAttempt attempt,
    TimingSegment? finalTimingSegment,
  }) async => this.attempt = attempt;
  @override
  Future<void> updateUnfinishedAttempt(PuzzleAttempt attempt) async =>
      this.attempt = attempt;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PuzzleAttempt _attempt() => PuzzleAttempt(
  id: 'golden-attempt',
  blockId: 'golden-block',
  cycleId: 'golden-cycle',
  sessionId: 'golden-session',
  startedAt: _started,
);

Future<PuzzleSolverController> _controller({bool blackToMove = false}) async {
  final controller = PuzzleSolverController(
    repository: _Repository(_attempt()),
    evaluatorFactory: () => AuthoredLinePuzzleEvaluator(idGenerator: _Ids()),
  );
  await controller.initialize(puzzle: _puzzle, attemptId: 'golden-attempt');
  if (blackToMove) await controller.submitMove(uci: 'e2e4');
  return controller;
}

Future<void> _setPhoneSize(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await _loadTestFont('Roboto', 'Roboto-Regular.ttf');
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await materialIcons.load();
  });

  testWidgets('phone active puzzle, white to move', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      _app(
        home: PuzzleSolvingView(
          controller: await _controller(),
          currentExercise: 2,
          totalExercises: 5,
          orientation: PuzzleSide.white,
          onPause: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('White to move'), findsOneWidget);
    await _waitForBoardImages(tester);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../golden/puzzle_solver/active-white.png'),
    );
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('phone active puzzle, black to move', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      _app(
        home: PuzzleSolvingView(
          controller: await _controller(blackToMove: true),
          currentExercise: 2,
          totalExercises: 5,
          orientation: PuzzleSide.white,
          onPause: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Black to move'), findsOneWidget);
    await _waitForBoardImages(tester);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../golden/puzzle_solver/active-black.png'),
    );
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('phone active puzzle at large text scale', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      _app(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: PuzzleSolvingView(
            controller: await _controller(),
            currentExercise: 2,
            totalExercises: 5,
            orientation: PuzzleSide.white,
            onPause: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('White to move'), findsOneWidget);
    await _waitForBoardImages(tester);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../golden/puzzle_solver/active-large-text.png'),
    );
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('phone failed attempt review', (tester) async {
    await _setPhoneSize(tester);
    final attempt = _attempt();
    final evaluator = AuthoredLinePuzzleEvaluator();
    evaluator.initialize(puzzle: _puzzle, attempt: attempt);
    final finalState = evaluator.submitMove(uci: 'e2e3');
    expect(finalState.attempt.outcome?.name, 'wrongMove');
    final presentation = PuzzlePresentationState.fromDomain(
      puzzle: _puzzle,
      evaluation: finalState,
    );
    await tester.pumpWidget(
      _app(home: PuzzleSolutionReviewView(presentation: presentation)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Result: Incorrect move'), findsOneWidget);
    await _waitForBoardImages(tester);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../golden/puzzle_solver/failed-review.png'),
    );
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

MaterialApp _app({required Widget home}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(fontFamily: 'Roboto'),
  home: home,
);

Future<void> _loadTestFont(String family, String filename) async {
  final bytes = await File('test/golden/fonts/$filename').readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
}

Future<void> _waitForBoardImages(WidgetTester tester) async {
  await tester.runAsync(chessground.ChessgroundImages.instance.ready);
  await tester.pumpAndSettle();
}
