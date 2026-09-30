import 'package:flutter/material.dart';

import 'dependencies.dart';
import '../domain/chess_content/chess_content.dart';
import '../domain/chess_content/content_type.dart';
import '../domain/training/authored_line_puzzle_evaluator.dart';
import '../domain/training/puzzle_evaluator.dart';
import '../domain/training/training_set.dart';
import '../domain/training/training_set_item.dart';
import '../features/game_reader/presentation/reader_board.dart';
import '../features/training_session/application/active_session_controller.dart';
import '../features/training_session/presentation/active_session_page.dart';
import '../shared/chessboard/chessboard_adapter.dart';

/// Library preview contains only the initial position. Explicit practice uses
/// a persisted single-puzzle set and the normal timed session lifecycle.
final class LibraryPuzzlePractice extends StatefulWidget {
  const LibraryPuzzlePractice({
    super.key,
    required this.dependencies,
    required this.blockId,
    required this.puzzle,
  });

  final AppDependencies dependencies;
  final String blockId;
  final ChessContent puzzle;

  @override
  State<LibraryPuzzlePractice> createState() => _LibraryPuzzlePracticeState();
}

final class _LibraryPuzzlePracticeState extends State<LibraryPuzzlePractice> {
  bool _starting = false;
  String? _error;

  Future<void> _start() async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    final dependencies = widget.dependencies;
    ActiveSessionController? controller;
    try {
      // Reuse only an intact library practice set; edited or archived sets
      // retain their history and are never changed by this entry point.
      final prefix = 'library-practice:${widget.blockId}:';
      final sets = await dependencies.trainingSetRepository.listSets();
      var set = sets
          .where(
            (set) =>
                set.id.startsWith(prefix) &&
                set.status == TrainingSetStatus.active &&
                set.items.length == 1 &&
                set.items.single.blockId == widget.blockId &&
                set.items.single.contentType == ContentType.puzzle,
          )
          .firstOrNull;
      if (set == null) {
        final now = dependencies.clock.utcNow;
        final id = '$prefix${dependencies.idGenerator.generateId()}';
        set = TrainingSet(
          id: id,
          name: 'Library puzzle practice',
          items: [
            TrainingSetItem(
              id: dependencies.idGenerator.generateId(),
              trainingSetId: id,
              blockId: widget.blockId,
              position: 0,
              contentType: ContentType.puzzle,
              addedAt: now,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        );
        await dependencies.trainingSetRepository.createSet(set);
      }
      if (!mounted) return;
      controller = ActiveSessionController(
        trainingSet: set,
        sessionService: dependencies.trainingSessionService,
        repository: dependencies.trainingRepository,
        contentRepository: dependencies.chessContentRepository,
        clock: dependencies.clock,
        evaluatorFactory: () => AuthoredLinePuzzleEvaluator(
          clock: dependencies.clock,
          idGenerator: dependencies.idGenerator,
        ),
      );
      final sessionController = controller;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ActiveSessionPage(controller: sessionController),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Practice could not be opened. Try again.');
      }
    } finally {
      controller?.dispose();
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final side = widget.puzzle.startingFen.split(' ')[1] == 'b'
        ? PuzzleSide.black
        : PuzzleSide.white;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ReaderBoard(
              board: ChessboardAdapter.fromPosition(
                fen: widget.puzzle.startingFen,
                sideToMove: side,
                legalDestinations: const {},
                orientation: side,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Start a timed practice attempt or resume your unfinished attempt. Leaving practice pauses it. Results are saved in training progress.',
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _starting ? null : _start,
            child: const Text('Start or resume practice'),
          ),
          if (_error != null) Text(_error!),
        ],
      ),
    );
  }
}
