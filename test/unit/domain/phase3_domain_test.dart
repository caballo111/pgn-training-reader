import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/chess_content.dart';
import 'package:pgntrainingreader/domain/chess_content/content_type.dart';
import 'package:pgntrainingreader/domain/chess_content/move_node.dart';
import 'package:pgntrainingreader/domain/chess_content/pgn_block_index.dart';
import 'package:pgntrainingreader/domain/chess_content/pgn_source.dart';
import 'package:pgntrainingreader/domain/training/attempt_move.dart';
import 'package:pgntrainingreader/domain/training/cycle.dart';
import 'package:pgntrainingreader/domain/training/lifecycle_status.dart';
import 'package:pgntrainingreader/domain/training/progress_aggregate.dart';
import 'package:pgntrainingreader/domain/training/puzzle_attempt.dart';
import 'package:pgntrainingreader/domain/training/timing_segment.dart';
import 'package:pgntrainingreader/domain/training/training_session.dart';
import 'package:pgntrainingreader/domain/training/training_set.dart';
import 'package:pgntrainingreader/domain/training/training_set_item.dart';

final _start = DateTime.utc(2026, 9, 1, 12);
final _end = DateTime.utc(2026, 9, 1, 12, 1);
const _fen = 'position';

void main() {
  group('Phase 3 database enum serialization', () {
    test('ContentType serializes every canonical value strictly', () {
      _roundTrips(
        ContentType.values,
        (value) => value.toDatabaseValue(),
        ContentType.fromDatabaseValue,
      );
      _rejects(<String>[
        'puzzle',
        ' Puzzle',
        'Puzzle ',
        'Unknown',
      ], ContentType.fromDatabaseValue);
    });

    test('PgnSourceAccessMode serializes every canonical value strictly', () {
      _roundTrips(
        PgnSourceAccessMode.values,
        (value) => value.toDatabaseValue(),
        PgnSourceAccessMode.fromDatabaseValue,
      );
      _rejects(<String>[
        'managedCopy',
        'managedcopy',
        ' ManagedCopy',
      ], PgnSourceAccessMode.fromDatabaseValue);
    });

    test('PgnBlockParseStatus serializes every canonical value strictly', () {
      _roundTrips(
        PgnBlockParseStatus.values,
        (value) => value.toDatabaseValue(),
        PgnBlockParseStatus.fromDatabaseValue,
      );
      _rejects(<String>[
        'valid',
        ' Valid',
        'Unsupported ',
      ], PgnBlockParseStatus.fromDatabaseValue);
    });

    test('TrainingSetStatus serializes every canonical value strictly', () {
      _roundTrips(
        TrainingSetStatus.values,
        (value) => value.toDatabaseValue(),
        TrainingSetStatus.fromDatabaseValue,
      );
      _rejects(<String>[
        'Active',
        ' active',
        'archived ',
      ], TrainingSetStatus.fromDatabaseValue);
    });

    test('TrainingSetItemState serializes every canonical value strictly', () {
      _roundTrips(
        TrainingSetItemState.values,
        (value) => value.toDatabaseValue(),
        TrainingSetItemState.fromDatabaseValue,
      );
      _rejects(<String>[
        'Pending',
        ' pending',
        'pending ',
      ], TrainingSetItemState.fromDatabaseValue);
    });

    test('CycleStatus serializes every canonical value strictly', () {
      _roundTrips(
        CycleStatus.values,
        (value) => value.toDatabaseValue(),
        CycleStatus.fromDatabaseValue,
      );
      _rejects(<String>[
        'Active',
        'active ',
        'unknown',
      ], CycleStatus.fromDatabaseValue);
    });

    test('TrainingSessionStatus serializes every canonical value strictly', () {
      _roundTrips(
        TrainingSessionStatus.values,
        (value) => value.toDatabaseValue(),
        TrainingSessionStatus.fromDatabaseValue,
      );
      _rejects(<String>[
        'Closed',
        ' active',
        'unknown',
      ], TrainingSessionStatus.fromDatabaseValue);
    });

    test(
      'PuzzleAttemptStatus serializes active, paused, and finalized strictly',
      () {
        _roundTrips(
          PuzzleAttemptStatus.values,
          (value) => value.toDatabaseValue(),
          PuzzleAttemptStatus.fromDatabaseValue,
        );
        _rejects(<String>[
          'Active',
          'paused ',
          'complete',
        ], PuzzleAttemptStatus.fromDatabaseValue);
      },
    );

    test('PuzzleAttemptOutcome serializes every terminal outcome strictly', () {
      _roundTrips(
        PuzzleAttemptOutcome.values,
        (value) => value.toDatabaseValue(),
        PuzzleAttemptOutcome.fromDatabaseValue,
      );
      _rejects(<String>[
        'passed',
        ' Passed',
        'skipped ',
      ], PuzzleAttemptOutcome.fromDatabaseValue);
    });

    test('PuzzleAttemptFailureReason serializes every reason strictly', () {
      _roundTrips(
        PuzzleAttemptFailureReason.values,
        (value) => value.toDatabaseValue(),
        PuzzleAttemptFailureReason.fromDatabaseValue,
      );
      _rejects(<String>[
        'incorrectMove',
        'IncorrectMove ',
        'unknown',
      ], PuzzleAttemptFailureReason.fromDatabaseValue);
    });
  });

  group('Phase 3 value equality', () {
    test('PgnSource compares all persisted source fields by value', () {
      final first = _source();
      _expectValueSemantics(first, _source(), _source(displayName: 'Other'));
    });

    test('PgnBlockIndex compares metadata and byte range by value', () {
      _expectValueSemantics(_block(), _block(), _block(endOffset: 21));
    });

    test('MoveNode compares annotations and ordered branches recursively', () {
      _expectValueSemantics(_move(), _move(), _move(nags: const [1, 2]));
      expect(
        _move(children: [_move(san: 'd4')]),
        isNot(_move(children: [_move(san: 'e4')])),
      );
    });

    test('ChessContent compares header order and content by value', () {
      _expectValueSemantics(_content(), _content(), _content(result: '0-1'));
      expect(
        _content(headers: const {'Event': 'X', 'Site': 'Y'}),
        isNot(_content(headers: const {'Site': 'Y', 'Event': 'X'})),
      );
    });

    test('TrainingSetItem compares identity, position, and content type', () {
      _expectValueSemantics(_item(), _item(), _item(position: 1));
    });

    test('TrainingSet compares ordered items and lifecycle fields', () {
      _expectValueSemantics(_set(), _set(), _set(name: 'Other'));
      expect(
        _set(
          items: [
            _item(position: 0),
            _item(id: 'item-2', position: 1),
          ],
        ),
        isNot(
          _set(
            items: [
              _item(id: 'item-2', position: 0),
              _item(position: 1),
            ],
          ),
        ),
      );
    });

    test('Cycle compares identity, lifecycle timestamps, and state', () {
      _expectValueSemantics(_cycle(), _cycle(), _cycle(trainingSetId: 'other'));
    });

    test('TrainingSession compares lifecycle fields by value', () {
      _expectValueSemantics(_session(), _session(), _session(studyDay: _end));
    });

    test(
      'PuzzleAttempt compares lifecycle, outcome, and counters by value',
      () {
        final passed = _attempt(
          status: PuzzleAttemptStatus.finalized,
          completedAt: _end,
          outcome: PuzzleAttemptOutcome.passed,
        );
        _expectValueSemantics(
          passed,
          _attempt(
            status: PuzzleAttemptStatus.finalized,
            completedAt: _end,
            outcome: PuzzleAttemptOutcome.passed,
          ),
          _attempt(
            status: PuzzleAttemptStatus.finalized,
            completedAt: _end,
            outcome: PuzzleAttemptOutcome.passed,
            hintCount: 1,
          ),
        );
      },
    );

    test('AttemptMove compares submission fields by value', () {
      _expectValueSemantics(
        _attemptMove(),
        _attemptMove(),
        _attemptMove(move: 'd2d4'),
      );
    });

    test('TimingSegment compares active interval fields by value', () {
      _expectValueSemantics(
        _segment(endedAt: _end, activeDuration: const Duration(seconds: 1)),
        _segment(endedAt: _end, activeDuration: const Duration(seconds: 1)),
        _segment(endedAt: _end, activeDuration: const Duration(seconds: 2)),
      );
    });

    test(
      'ProgressAggregate compares raw counts and ordered durations by value',
      () {
        final first = _aggregate();
        _expectValueSemantics(first, _aggregate(), _aggregate(hintCount: 1));
        expect(
          _aggregate(
            passedCount: 2,
            attemptActiveDurations: [
              const Duration(seconds: 1),
              const Duration(seconds: 2),
            ],
          ),
          isNot(
            _aggregate(
              passedCount: 2,
              attemptActiveDurations: [
                const Duration(seconds: 2),
                const Duration(seconds: 1),
              ],
            ),
          ),
        );
      },
    );
  });

  group('Phase 3 construction invariants', () {
    test('PgnSource requires one matching nonempty reference and nonnegative bounds', () {
      expect(_source(sizeBytes: 0, safeCheckpoint: 0), isA<PgnSource>());
      expect(
        PgnSource(
          id: 'external',
          displayName: 'Book.pgn',
          accessMode: PgnSourceAccessMode.externalReference,
          externalReference: 'content://library/book',
          scannerVersion: 1,
          importState: 'ready',
          createdAt: _start,
          updatedAt: _start,
        ),
        isA<PgnSource>(),
      );
      expect(() => _source(managedPath: ''), throwsArgumentError);
      expect(() => _source(externalReference: 'uri'), throwsArgumentError);
      expect(() => _source(id: ''), throwsArgumentError);
      expect(() => _source(displayName: ''), throwsArgumentError);
      expect(() => _source(scannerVersion: 0), throwsArgumentError);
      expect(() => _source(importState: ''), throwsArgumentError);
      expect(() => _source(sizeBytes: -1), throwsArgumentError);
      expect(() => _source(safeCheckpoint: -1), throwsArgumentError);
    });

    test('PgnBlockIndex permits empty half-open ranges but rejects invalid offsets', () {
      expect(_block(startOffset: 4, endOffset: 4), isA<PgnBlockIndex>());
      expect(() => _block(id: ''), throwsArgumentError);
      expect(() => _block(sourceId: ''), throwsArgumentError);
      expect(() => _block(startOffset: -1), throwsArgumentError);
      expect(() => _block(startOffset: 5, endOffset: 4), throwsArgumentError);
      expect(() => _block(ordinal: -1), throwsArgumentError);
    });

    test('MoveNode enforces required notation and one-byte NAG bounds', () {
      expect(_move(nags: const [0, 255]), isA<MoveNode>());
      expect(() => _move(san: ''), throwsArgumentError);
      expect(() => _move(uci: ''), throwsArgumentError);
      expect(
        () =>
            MoveNode(san: 'e4', uci: 'e2e4', fenBefore: '', fenAfter: 'after'),
        throwsArgumentError,
      );
      expect(
        () =>
            MoveNode(san: 'e4', uci: 'e2e4', fenBefore: 'before', fenAfter: ''),
        throwsArgumentError,
      );
      expect(() => _move(nags: const [-1]), throwsArgumentError);
      expect(() => _move(nags: const [256]), throwsArgumentError);
    });

    test('MoveNode takes immutable snapshots of annotations and branches', () {
      final comments = <String>['authored'];
      final nags = <int>[1];
      final children = <MoveNode>[_move(san: 'd5')];
      final move = _move(comments: comments, nags: nags, children: children);
      comments.add('later');
      nags.add(2);
      children.clear();

      expect(move.comments, ['authored']);
      expect(move.nags, [1]);
      expect(move.children, [_move(san: 'd5')]);
      expect(() => move.comments.add('mutate'), throwsUnsupportedError);
      expect(() => move.nags.add(3), throwsUnsupportedError);
      expect(() => move.children.add(_move()), throwsUnsupportedError);
    });

    test('ChessContent preserves defensive ordered collection snapshots', () {
      final headers = <String, String>{'Event': 'A'};
      final moves = <MoveNode>[_move()];
      final comments = <String>['intro'];
      final value = _content(
        headers: headers,
        rootMoves: moves,
        comments: comments,
      );
      headers['Event'] = 'changed';
      moves.clear();
      comments.add('later');

      expect(value.headers['Event'], 'A');
      expect(value.rootMoves, [_move()]);
      expect(value.comments, ['intro']);
      expect(() => value.headers['Site'] = 'mutate', throwsUnsupportedError);
      expect(() => value.rootMoves.add(_move()), throwsUnsupportedError);
      expect(() => _content(startingFen: ''), throwsArgumentError);
      expect(() => _content(headers: const {'': 'bad'}), throwsArgumentError);
    });

    test('TrainingSetItem rejects unsupported content and invalid identity or position', () {
      expect(_item(position: 0), isA<TrainingSetItem>());
      expect(() => _item(position: -1), throwsArgumentError);
      expect(() => _item(id: ''), throwsArgumentError);
      expect(() => _item(trainingSetId: ''), throwsArgumentError);
      expect(
        () => _item(contentType: ContentType.unsupported),
        throwsArgumentError,
      );
      expect(() => _item(blockId: ''), throwsArgumentError);
    });

    test('TrainingSet sorts items and rejects duplicate IDs, positions, or foreign items', () {
      final earlier = _item(id: 'earlier', position: 0);
      final later = _item(id: 'later', position: 2);
      final set = _set(items: [later, earlier]);
      expect(set.items, [earlier, later]);
      expect(() => set.items.add(_item(position: 3)), throwsUnsupportedError);
      expect(
        () => _set(
          items: [
            _item(),
            _item(id: 'item-2'),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => _set(
          items: [
            _item(),
            _item(id: 'item-2', position: 0),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => _set(items: [_item(trainingSetId: 'foreign')]),
        throwsArgumentError,
      );
      expect(() => _set(name: '  '), throwsArgumentError);
      expect(() => _set(id: ''), throwsArgumentError);
      expect(
        () => TrainingSet(
          id: 'set',
          name: 'Archived',
          status: TrainingSetStatus.archived,
          items: const [],
          createdAt: _start,
          updatedAt: _end,
        ),
        throwsArgumentError,
      );
      expect(_set(status: TrainingSetStatus.archived), isA<TrainingSet>());
    });

    test('Cycle requires timestamps consistent with lifecycle and chronological order', () {
      expect(_cycle(status: CycleStatus.pending), isA<Cycle>());
      expect(() => _cycle(id: ''), throwsArgumentError);
      expect(() => _cycle(trainingSetId: ''), throwsArgumentError);
      expect(() => _cycle(status: CycleStatus.active), throwsArgumentError);
      expect(() => _cycle(status: CycleStatus.completed), throwsArgumentError);
      expect(
        _cycle(
          status: CycleStatus.completed,
          startedAt: _start,
          completedAt: _end,
        ),
        isA<Cycle>(),
      );
      expect(
        () => _cycle(
          status: CycleStatus.active,
          startedAt: _start,
          completedAt: _end,
        ),
        throwsArgumentError,
      );
      expect(
        _cycle(status: CycleStatus.stopped, startedAt: _start, stoppedAt: _end),
        isA<Cycle>(),
      );
      expect(
        () => _cycle(status: CycleStatus.pending, startedAt: _start),
        throwsArgumentError,
      );
      expect(
        () => _cycle(
          status: CycleStatus.completed,
          startedAt: _end,
          completedAt: _start,
        ),
        throwsArgumentError,
      );
    });

    test('TrainingSession pairs ended states with nonpreceding end time', () {
      expect(_session(), isA<TrainingSession>());
      expect(() => _session(id: ''), throwsArgumentError);
      expect(() => _session(cycleId: ''), throwsArgumentError);
      expect(
        () => _session(status: TrainingSessionStatus.closed),
        throwsArgumentError,
      );
      expect(
        () => _session(status: TrainingSessionStatus.paused, endedAt: _end),
        throwsArgumentError,
      );
      expect(
        () => _session(
          status: TrainingSessionStatus.closed,
          endedAt: _start.subtract(const Duration(seconds: 1)),
        ),
        throwsArgumentError,
      );
      expect(
        _session(status: TrainingSessionStatus.recovered, endedAt: _end),
        isA<TrainingSession>(),
      );
    });

    test('PuzzleAttempt lifecycle, outcome, reason, reveal, time, and counts agree', () {
      expect(_attempt(), isA<PuzzleAttempt>());
      expect(() => _attempt(id: ''), throwsArgumentError);
      expect(() => _attempt(blockId: ''), throwsArgumentError);
      expect(() => _attempt(cycleId: ''), throwsArgumentError);
      expect(() => _attempt(sessionId: ''), throwsArgumentError);
      expect(
        _attempt(status: PuzzleAttemptStatus.paused),
        isA<PuzzleAttempt>(),
      );
      expect(
        () => _attempt(status: PuzzleAttemptStatus.finalized),
        throwsArgumentError,
      );
      expect(
        () => _attempt(outcome: PuzzleAttemptOutcome.passed, completedAt: _end),
        throwsArgumentError,
      );
      expect(
        () => _attempt(
          status: PuzzleAttemptStatus.finalized,
          outcome: PuzzleAttemptOutcome.wrongMove,
          completedAt: _end,
        ),
        throwsArgumentError,
      );
      expect(
        () => _attempt(
          status: PuzzleAttemptStatus.finalized,
          outcome: PuzzleAttemptOutcome.passed,
          completedAt: _end,
          failureReason: PuzzleAttemptFailureReason.incorrectMove,
        ),
        throwsArgumentError,
      );
      expect(
        _attempt(
          status: PuzzleAttemptStatus.finalized,
          outcome: PuzzleAttemptOutcome.wrongMove,
          completedAt: _end,
          failureReason: PuzzleAttemptFailureReason.incorrectMove,
        ),
        isA<PuzzleAttempt>(),
      );
      expect(
        () => _attempt(
          status: PuzzleAttemptStatus.finalized,
          outcome: PuzzleAttemptOutcome.revealed,
          completedAt: _end,
        ),
        throwsArgumentError,
      );
      expect(
        _attempt(
          status: PuzzleAttemptStatus.finalized,
          outcome: PuzzleAttemptOutcome.wrongMove,
          completedAt: _end,
          failureReason: PuzzleAttemptFailureReason.incorrectMove,
          revealed: true,
        ),
        isA<PuzzleAttempt>(),
      );
      expect(
        () => _attempt(
          status: PuzzleAttemptStatus.finalized,
          outcome: PuzzleAttemptOutcome.timedOut,
          completedAt: _end,
          failureReason: PuzzleAttemptFailureReason.incorrectMove,
        ),
        throwsArgumentError,
      );
      expect(
        () => _attempt(
          status: PuzzleAttemptStatus.finalized,
          outcome: PuzzleAttemptOutcome.abandoned,
          completedAt: _end,
          failureReason: PuzzleAttemptFailureReason.timeLimitExceeded,
        ),
        throwsArgumentError,
      );
      expect(
        _attempt(
          status: PuzzleAttemptStatus.finalized,
          outcome: PuzzleAttemptOutcome.passed,
          completedAt: _end,
          revealed: true,
        ),
        isA<PuzzleAttempt>(),
      );
      expect(() => _attempt(revealed: true), throwsArgumentError);
      expect(
        () => _attempt(activeDuration: const Duration(seconds: -1)),
        throwsArgumentError,
      );
      expect(() => _attempt(wrongMoveCount: -1), throwsArgumentError);
      expect(() => _attempt(hintCount: -1), throwsArgumentError);
      expect(
        () => _attempt(
          status: PuzzleAttemptStatus.finalized,
          outcome: PuzzleAttemptOutcome.passed,
          completedAt: _start.subtract(const Duration(seconds: 1)),
        ),
        throwsArgumentError,
      );
    });

    test('AttemptMove rejects negative ordinals, empty notation, and accepted illegal moves', () {
      expect(
        _attemptMove(ordinal: 0, legal: false, accepted: false),
        isA<AttemptMove>(),
      );
      expect(() => _attemptMove(id: ''), throwsArgumentError);
      expect(() => _attemptMove(attemptId: ''), throwsArgumentError);
      expect(() => _attemptMove(ordinal: -1), throwsArgumentError);
      expect(() => _attemptMove(move: ''), throwsArgumentError);
      expect(
        () => _attemptMove(legal: false, accepted: true),
        throwsArgumentError,
      );
    });

    test('TimingSegment requires paired closing data and nonnegative active duration', () {
      expect(_segment(), isA<TimingSegment>());
      expect(() => _segment(id: ''), throwsArgumentError);
      expect(() => _segment(attemptId: ''), throwsArgumentError);
      expect(
        _segment(endedAt: _end, activeDuration: Duration.zero),
        isA<TimingSegment>(),
      );
      expect(() => _segment(endedAt: _end), throwsArgumentError);
      expect(
        () => _segment(activeDuration: Duration.zero),
        throwsArgumentError,
      );
      expect(
        () => _segment(
          endedAt: _start.subtract(const Duration(seconds: 1)),
          activeDuration: Duration.zero,
        ),
        throwsArgumentError,
      );
      expect(
        () => _segment(
          endedAt: _end,
          activeDuration: const Duration(microseconds: -1),
        ),
        throwsArgumentError,
      );
    });

    test('ProgressAggregate validates nonnegative raw counts and per-outcome durations', () {
      expect(_aggregate(), isA<ProgressAggregate>());
      expect(
        _aggregate(passedCount: 1, attemptActiveDurations: [Duration.zero]),
        isA<ProgressAggregate>(),
      );
      expect(
        _aggregate(
          passedCount: 1,
          wrongMoveOutcomeCount: 1,
          revealedCount: 1,
          skippedCount: 1,
          timedOutCount: 1,
          abandonedCount: 1,
          attemptActiveDurations: List.filled(6, Duration.zero),
        ),
        isA<ProgressAggregate>(),
      );
      final negativeCountCases = <ProgressAggregate Function()>[
        () => _aggregate(passedCount: -1),
        () => _aggregate(wrongMoveOutcomeCount: -1),
        () => _aggregate(revealedCount: -1),
        () => _aggregate(skippedCount: -1),
        () => _aggregate(timedOutCount: -1),
        () => _aggregate(abandonedCount: -1),
        () => _aggregate(wrongMoveCount: -1),
        () => _aggregate(hintCount: -1),
        () => _aggregate(completedNonPuzzleItemCount: -1),
      ];
      for (final build in negativeCountCases) {
        expect(build, throwsArgumentError);
      }
      expect(() => _aggregate(passedCount: 1), throwsArgumentError);
      expect(
        () => _aggregate(attemptActiveDurations: [const Duration(seconds: -1)]),
        throwsArgumentError,
      );
      expect(
        () => _aggregate(nonPuzzleActiveDuration: const Duration(seconds: -1)),
        throwsArgumentError,
      );

      final sourceDurations = <Duration>[Duration.zero];
      final aggregate = _aggregate(
        passedCount: 1,
        attemptActiveDurations: sourceDurations,
      );
      sourceDurations.add(const Duration(seconds: 1));
      expect(aggregate.attemptActiveDurations, [Duration.zero]);
      expect(
        () => aggregate.attemptActiveDurations.add(Duration.zero),
        throwsUnsupportedError,
      );
    });
  });
}

void _roundTrips<T>(
  Iterable<T> values,
  String Function(T) encode,
  T Function(String) decode,
) {
  for (final value in values) {
    expect(decode(encode(value)), value);
  }
}

void _rejects<T>(Iterable<String> invalidValues, T Function(String) decode) {
  for (final value in invalidValues) {
    expect(
      () => decode(value),
      throwsFormatException,
      reason: 'Rejected: $value',
    );
  }
}

void _expectValueSemantics<T>(T first, T equal, T different) {
  expect(first, equal);
  expect(first.hashCode, equal.hashCode);
  expect(first, isNot(different));
}

PgnSource _source({
  String id = 'source',
  String displayName = 'Book.pgn',
  String? managedPath = '/library/book.pgn',
  String? externalReference,
  int? sizeBytes = 10,
  int scannerVersion = 1,
  String importState = 'ready',
  int safeCheckpoint = 10,
}) => PgnSource(
  id: id,
  displayName: displayName,
  accessMode: PgnSourceAccessMode.managedCopy,
  managedPath: managedPath,
  externalReference: externalReference,
  sizeBytes: sizeBytes,
  modifiedAt: _start,
  fingerprint: 'fingerprint',
  scannerVersion: scannerVersion,
  importState: importState,
  safeCheckpoint: safeCheckpoint,
  createdAt: _start,
  updatedAt: _end,
);

PgnBlockIndex _block({
  String id = 'block',
  String sourceId = 'source',
  int startOffset = 0,
  int endOffset = 20,
  int ordinal = 0,
}) => PgnBlockIndex(
  id: id,
  sourceId: sourceId,
  startOffset: startOffset,
  endOffset: endOffset,
  ordinal: ordinal,
  event: 'Event',
  site: 'Site',
  date: '2026.09.01',
  round: '1',
  white: 'White',
  black: 'Black',
  result: '1-0',
  contentType: ContentType.puzzle,
  exerciseId: 'exercise',
  section: 'A',
  sequence: 2,
  theme: 'fork',
  difficulty: 'easy',
  parseStatus: PgnBlockParseStatus.valid,
  diagnosticSummary: null,
);

MoveNode _move({
  String san = 'e4',
  String uci = 'e2e4',
  List<String> comments = const [],
  List<int> nags = const [],
  List<MoveNode> children = const [],
}) => MoveNode(
  san: san,
  uci: uci,
  fenBefore: 'before',
  fenAfter: 'after',
  comments: comments,
  nags: nags,
  children: children,
);

ChessContent _content({
  Map<String, String> headers = const {'Event': 'X'},
  String startingFen = _fen,
  List<MoveNode> rootMoves = const [],
  List<String> comments = const [],
  String? result,
  ContentType contentType = ContentType.puzzle,
}) => ChessContent(
  headers: headers,
  startingFen: startingFen,
  rootMoves: rootMoves,
  comments: comments,
  result: result,
  contentType: contentType,
);

TrainingSetItem _item({
  String id = 'item',
  String trainingSetId = 'set',
  String blockId = 'block',
  int position = 0,
  ContentType contentType = ContentType.puzzle,
}) => TrainingSetItem(
  id: id,
  trainingSetId: trainingSetId,
  blockId: blockId,
  position: position,
  contentType: contentType,
  addedAt: _start,
);

TrainingSet _set({
  String id = 'set',
  String name = 'Training',
  TrainingSetStatus status = TrainingSetStatus.active,
  List<TrainingSetItem> items = const [],
}) => TrainingSet(
  id: id,
  name: name,
  status: status,
  items: items,
  createdAt: _start,
  updatedAt: _end,
  archivedAt: status == TrainingSetStatus.archived ? _end : null,
);

Cycle _cycle({
  String id = 'cycle',
  String trainingSetId = 'set',
  CycleStatus status = CycleStatus.pending,
  DateTime? startedAt,
  DateTime? completedAt,
  DateTime? stoppedAt,
}) => Cycle(
  id: id,
  trainingSetId: trainingSetId,
  status: status,
  startedAt: startedAt,
  completedAt: completedAt,
  stoppedAt: stoppedAt,
  createdAt: _start,
);

TrainingSession _session({
  String id = 'session',
  String cycleId = 'cycle',
  TrainingSessionStatus status = TrainingSessionStatus.active,
  DateTime? endedAt,
  DateTime? studyDay,
}) => TrainingSession(
  id: id,
  cycleId: cycleId,
  status: status,
  startedAt: _start,
  endedAt: endedAt,
  studyDay: studyDay ?? _start,
);

PuzzleAttempt _attempt({
  String id = 'attempt',
  String blockId = 'block',
  String cycleId = 'cycle',
  String sessionId = 'session',
  PuzzleAttemptStatus status = PuzzleAttemptStatus.active,
  DateTime? completedAt,
  Duration activeDuration = Duration.zero,
  PuzzleAttemptOutcome? outcome,
  PuzzleAttemptFailureReason? failureReason,
  int wrongMoveCount = 0,
  int hintCount = 0,
  bool revealed = false,
}) => PuzzleAttempt(
  id: id,
  blockId: blockId,
  cycleId: cycleId,
  sessionId: sessionId,
  status: status,
  startedAt: _start,
  completedAt: completedAt,
  activeDuration: activeDuration,
  outcome: outcome,
  failureReason: failureReason,
  wrongMoveCount: wrongMoveCount,
  hintCount: hintCount,
  revealed: revealed,
);

AttemptMove _attemptMove({
  String id = 'move',
  String attemptId = 'attempt',
  int ordinal = 0,
  String move = 'e2e4',
  bool legal = true,
  bool accepted = true,
}) => AttemptMove(
  id: id,
  attemptId: attemptId,
  ordinal: ordinal,
  move: move,
  legal: legal,
  accepted: accepted,
  submittedAt: _start,
);

TimingSegment _segment({
  String id = 'segment',
  String attemptId = 'attempt',
  DateTime? endedAt,
  Duration? activeDuration,
}) => TimingSegment(
  id: id,
  attemptId: attemptId,
  startedAt: _start,
  endedAt: endedAt,
  activeDuration: activeDuration,
);

ProgressAggregate _aggregate({
  int passedCount = 0,
  int wrongMoveOutcomeCount = 0,
  int revealedCount = 0,
  int skippedCount = 0,
  int timedOutCount = 0,
  int abandonedCount = 0,
  int wrongMoveCount = 0,
  int hintCount = 0,
  List<Duration> attemptActiveDurations = const [],
  int completedNonPuzzleItemCount = 0,
  Duration nonPuzzleActiveDuration = Duration.zero,
}) => ProgressAggregate(
  passedCount: passedCount,
  wrongMoveOutcomeCount: wrongMoveOutcomeCount,
  revealedCount: revealedCount,
  skippedCount: skippedCount,
  timedOutCount: timedOutCount,
  abandonedCount: abandonedCount,
  wrongMoveCount: wrongMoveCount,
  hintCount: hintCount,
  attemptActiveDurations: attemptActiveDurations,
  completedNonPuzzleItemCount: completedNonPuzzleItemCount,
  nonPuzzleActiveDuration: nonPuzzleActiveDuration,
);
