import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/domain/training/progress_aggregate.dart';
import 'package:pgntrainingreader/features/game_reader/presentation/game_reader_page.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

ChessContent _content(ContentType type) => ChessContent(
  headers: const {'X-Title': 'Reader test'},
  startingFen: _startFen,
  contentType: type,
  rootMoves: [
    MoveNode(
      san: 'e4',
      uci: 'e2e4',
      fenBefore: _startFen,
      fenAfter: 'after e4',
      children: [
        MoveNode(
          san: 'e5',
          uci: 'e7e5',
          fenBefore: 'after e4',
          fenAfter: 'after e5',
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('reading and navigating text has no scored side effect', (
    tester,
  ) async {
    for (final type in [ContentType.text]) {
      final writer = _RecordingAttemptWriter();
      final before = writer.aggregate;
      var puzzleBuilderCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: GameReaderPage(
            content: _content(type),
            puzzleViewBuilder: (context, content) {
              puzzleBuilderCalls++;
              return _RecordingPuzzleView(writer: writer);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byTooltip('Next move'));
      await tester.tap(find.byTooltip('Next move'));
      await tester.pumpAndSettle();

      expect(puzzleBuilderCalls, 0, reason: '$type must stay in reader mode');
      expect(writer.writeCalls, 0, reason: '$type must not record attempts');
      expect(
        writer.aggregate,
        before,
        reason: '$type must not alter score inputs',
      );
    }
  });

  testWidgets('recording attempt spy is wired to the injected puzzle view', (
    tester,
  ) async {
    final writer = _RecordingAttemptWriter();
    var puzzleBuilderCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GameReaderPage(
          content: _content(ContentType.puzzle),
          puzzleViewBuilder: (context, content) {
            puzzleBuilderCalls++;
            return _RecordingPuzzleView(writer: writer);
          },
        ),
      ),
    );

    expect(puzzleBuilderCalls, 1);
    expect(writer.writeCalls, 0);
    await tester.tap(find.text('Record puzzle result'));
    await tester.pump();

    expect(writer.writeCalls, 1);
    expect(writer.aggregate.passedCount, 2);
  });
}

final class _RecordingAttemptWriter {
  int writeCalls = 0;
  ProgressAggregate aggregate = _seededPuzzleAggregate();

  void recordPassedAttempt() {
    writeCalls++;
    aggregate = _seededPuzzleAggregate(passedCount: aggregate.passedCount + 1);
  }
}

ProgressAggregate _seededPuzzleAggregate({int passedCount = 1}) =>
    ProgressAggregate(
      passedCount: passedCount,
      wrongMoveOutcomeCount: 1,
      revealedCount: 0,
      skippedCount: 0,
      timedOutCount: 0,
      abandonedCount: 0,
      wrongMoveCount: 1,
      hintCount: 0,
      attemptActiveDurations: List.generate(
        passedCount + 1,
        (index) => Duration(seconds: 20 + index * 5),
      ),
    );

final class _RecordingPuzzleView extends StatelessWidget {
  const _RecordingPuzzleView({required this.writer});

  final _RecordingAttemptWriter writer;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: writer.recordPassedAttempt,
    child: const Text('Record puzzle result'),
  );
}
