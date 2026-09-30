import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/features/game_reader/presentation/instruction_view.dart';

void main() {
  final content = ChessContent(
    headers: const {
      'Event': 'A long instructional title for a narrow screen',
      'X-ContentType': 'Instruction',
      'X-Section': 'Opening principles',
    },
    startingFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    contentType: ContentType.instruction,
    comments: const [
      'Develop the pieces toward the center before launching an attack.',
      'Keep the king safe and connect the rooks.',
    ],
    rootMoves: [
      MoveNode(
        san: 'e4',
        uci: 'e2e4',
        fenBefore: 'start',
        fenAfter: 'after e4',
        comments: const ['Control the center.'],
        children: [
          MoveNode(
            san: 'e5',
            uci: 'e7e5',
            fenBefore: 'after e4',
            fenAfter: 'after e5',
            children: [
              MoveNode(
                san: 'Nf3',
                uci: 'g1f3',
                fenBefore: 'after e5',
                fenAfter: 'after Nf3',
              ),
            ],
          ),
        ],
      ),
    ],
  );

  testWidgets('scrolls instruction content on a small phone at 2x text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(body: InstructionView(content: content)),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Instruction'), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('e4'), findsOneWidget);
  });
}
