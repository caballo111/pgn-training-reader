import 'dart:convert';

import 'package:drift/drift.dart' show Variable;

import '../data/database/app_database.dart' show AppDatabase;
import '../domain/training/attempt_move.dart';
import '../domain/training/puzzle_attempt.dart';
import '../domain/training/puzzle_interaction_repository.dart';
import '../domain/training/timing_segment.dart';
import '../domain/training/training_repository.dart';

/// Stores a casual score and its moves in app_settings, outside cycle metrics.
final class CasualTrainingRepository
    implements
        TrainingRepository,
        AtomicTrainingRepository,
        PuzzleInteractionRepository {
  CasualTrainingRepository(this._database, this.blockId, this.attemptId);

  final AppDatabase _database;
  final String blockId;
  final String attemptId;
  PuzzleAttempt? _attempt;
  final List<AttemptMove> _moves = [];
  bool _insideTransaction = false;

  static Future<String?> currentAttemptId(
    AppDatabase database,
    String blockId,
  ) async {
    final rows = await database
        .customSelect(
          'SELECT value FROM app_settings WHERE key = ?',
          variables: [Variable<String>('casual.current.$blockId')],
        )
        .get();
    return rows.firstOrNull?.data['value'] as String?;
  }

  Future<void> restore() async {
    final rows = await _database
        .customSelect(
          'SELECT value FROM app_settings WHERE key = ?',
          variables: [Variable<String>('casual.score.$attemptId')],
        )
        .get();
    if (rows.isEmpty) return;
    final data =
        jsonDecode(rows.single.data['value'] as String) as Map<String, dynamic>;
    _attempt = _attemptFromJson(
      Map<String, dynamic>.from(data['attempt'] as Map),
    );
    _moves
      ..clear()
      ..addAll(
        (data['moves'] as List).map(
          (move) => _moveFromJson(Map<String, dynamic>.from(move as Map)),
        ),
      );
  }

  Future<void> _save() async {
    final attempt = _attempt;
    if (attempt == null) return;
    await _put(
      'casual.score.$attemptId',
      jsonEncode({
        'attempt': _attemptToJson(attempt),
        'moves': [for (final move in _moves) _moveToJson(move)],
      }),
    );
    await _put('casual.current.$blockId', attemptId);
  }

  Future<void> _put(String key, String value) => _database.customStatement(
    'INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)',
    [key, value],
  );

  @override
  Future<PuzzleAttempt?> getAttempt(String id) async =>
      id == attemptId ? _attempt : null;

  @override
  Future<void> createAttempt(PuzzleAttempt attempt) async {
    if (attempt.id != attemptId ||
        attempt.blockId != blockId ||
        attempt.status != PuzzleAttemptStatus.active ||
        attempt.outcome != null) {
      throw StateError('Casual attempts must start active for this puzzle.');
    }
    if (_attempt != null) {
      throw StateError('Casual attempt identity already exists.');
    }
    final existing = await _database
        .customSelect(
          'SELECT key FROM app_settings WHERE key = ?',
          variables: [Variable<String>('casual.score.$attemptId')],
        )
        .get();
    if (existing.isNotEmpty) {
      throw StateError('Casual score identities are immutable.');
    }
    await _mutate(() {
      _attempt = attempt;
      _moves.clear();
    });
  }

  @override
  Future<List<AttemptMove>> listAttemptMoves(String id) async =>
      id == attemptId ? List.unmodifiable(_moves) : const [];

  @override
  Future<void> updateUnfinishedAttempt(PuzzleAttempt attempt) async {
    final current = _requireUnfinished(attempt.id);
    _checkIdentity(current, attempt);
    _checkMonotonic(current, attempt);
    if (attempt.status == PuzzleAttemptStatus.finalized ||
        attempt.outcome != null) {
      throw StateError('Unfinished attempts cannot be finalized by update.');
    }
    await _mutate(() => _attempt = attempt);
  }

  @override
  Future<void> recordSubmittedMove({
    required AttemptMove move,
    required PuzzleAttempt updatedAttempt,
    TimingSegment? closingTimingSegment,
  }) async {
    final current = _requireActive(updatedAttempt.id);
    _checkIdentity(current, updatedAttempt);
    _checkMonotonic(current, updatedAttempt);
    if (move.attemptId != attemptId || move.ordinal != _moves.length) {
      throw StateError(
        'Casual move history must remain append-only and ordered.',
      );
    }
    if (_moves.any((existing) => existing.id == move.id)) {
      throw StateError('Casual move identity already exists.');
    }
    await _mutate(() {
      _moves.add(move);
      _attempt = updatedAttempt;
    });
  }

  @override
  Future<void> finalizeAttempt({
    required PuzzleAttempt attempt,
    TimingSegment? finalTimingSegment,
  }) async {
    final current = _requireUnfinished(attempt.id);
    _checkIdentity(current, attempt);
    _checkMonotonic(current, attempt);
    if (attempt.status != PuzzleAttemptStatus.finalized ||
        attempt.outcome == null) {
      throw StateError('Finalized scores require a terminal outcome.');
    }
    await _mutate(() => _attempt = attempt);
  }

  PuzzleAttempt _requireUnfinished(String id) {
    final current = _attempt;
    if (id != attemptId || current == null || current.outcome != null) {
      throw StateError('Casual finalized scores are immutable.');
    }
    return current;
  }

  PuzzleAttempt _requireActive(String id) {
    final current = _requireUnfinished(id);
    if (current.status != PuzzleAttemptStatus.active) {
      throw StateError('Moves can only be submitted to active attempts.');
    }
    return current;
  }

  void _checkMonotonic(PuzzleAttempt before, PuzzleAttempt after) {
    if (after.activeDuration < before.activeDuration ||
        after.wrongMoveCount < before.wrongMoveCount ||
        after.hintCount < before.hintCount) {
      throw StateError('Casual attempt counters cannot decrease.');
    }
  }

  void _checkIdentity(PuzzleAttempt before, PuzzleAttempt after) {
    if (before.id != after.id ||
        before.blockId != after.blockId ||
        before.cycleId != after.cycleId ||
        before.sessionId != after.sessionId ||
        before.startedAt != after.startedAt) {
      throw StateError('Casual attempt identity is immutable.');
    }
  }

  Future<void> _mutate(void Function() update) async {
    final priorAttempt = _attempt;
    final priorMoves = List<AttemptMove>.of(_moves);
    update();
    try {
      if (_insideTransaction) {
        await _save();
      } else {
        await _database.transaction(_save);
      }
    } catch (_) {
      _attempt = priorAttempt;
      _moves
        ..clear()
        ..addAll(priorMoves);
      rethrow;
    }
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    final priorAttempt = _attempt;
    final priorMoves = List<AttemptMove>.of(_moves);
    try {
      return await _database.transaction(() async {
        _insideTransaction = true;
        try {
          return await action();
        } finally {
          _insideTransaction = false;
        }
      });
    } catch (_) {
      _insideTransaction = false;
      _attempt = priorAttempt;
      _moves
        ..clear()
        ..addAll(priorMoves);
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> loadPuzzleInteraction(String id) async {
    final rows = await _database
        .customSelect(
          'SELECT value FROM app_settings WHERE key = ?',
          variables: [Variable<String>('casual.interaction.$id')],
        )
        .get();
    return rows.isEmpty
        ? null
        : Map<String, dynamic>.from(
            jsonDecode(rows.single.data['value'] as String) as Map,
          );
  }

  @override
  Future<void> savePuzzleInteraction(String id, Map<String, dynamic> value) =>
      _persistInteraction(id, value);

  Future<void> _persistInteraction(
    String id,
    Map<String, dynamic> value,
  ) async {
    try {
      await _put('casual.interaction.$id', jsonEncode(value));
    } catch (_) {
      rethrow;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _attemptToJson(PuzzleAttempt value) => {
  'id': value.id,
  'blockId': value.blockId,
  'cycleId': value.cycleId,
  'sessionId': value.sessionId,
  'status': value.status.name,
  'startedAt': value.startedAt.microsecondsSinceEpoch,
  'completedAt': value.completedAt?.microsecondsSinceEpoch,
  'duration': value.activeDuration.inMilliseconds,
  'outcome': value.outcome?.name,
  'failure': value.failureReason?.name,
  'wrong': value.wrongMoveCount,
  'hints': value.hintCount,
  'revealed': value.revealed,
};

PuzzleAttempt _attemptFromJson(Map<String, dynamic> value) => PuzzleAttempt(
  id: value['id'] as String,
  blockId: value['blockId'] as String,
  cycleId: value['cycleId'] as String,
  sessionId: value['sessionId'] as String,
  status: PuzzleAttemptStatus.values.byName(value['status'] as String),
  startedAt: DateTime.fromMicrosecondsSinceEpoch(
    value['startedAt'] as int,
    isUtc: true,
  ),
  completedAt: (value['completedAt'] as int?) == null
      ? null
      : DateTime.fromMicrosecondsSinceEpoch(
          value['completedAt'] as int,
          isUtc: true,
        ),
  activeDuration: Duration(milliseconds: value['duration'] as int),
  outcome: (value['outcome'] as String?) == null
      ? null
      : PuzzleAttemptOutcome.values.byName(value['outcome'] as String),
  failureReason: (value['failure'] as String?) == null
      ? null
      : PuzzleAttemptFailureReason.values.byName(value['failure'] as String),
  wrongMoveCount: value['wrong'] as int,
  hintCount: value['hints'] as int,
  revealed: value['revealed'] as bool,
);

Map<String, dynamic> _moveToJson(AttemptMove value) => {
  'id': value.id,
  'attemptId': value.attemptId,
  'ordinal': value.ordinal,
  'move': value.move,
  'legal': value.legal,
  'accepted': value.accepted,
  'submittedAt': value.submittedAt.microsecondsSinceEpoch,
};

AttemptMove _moveFromJson(Map<String, dynamic> value) => AttemptMove(
  id: value['id'] as String,
  attemptId: value['attemptId'] as String,
  ordinal: value['ordinal'] as int,
  move: value['move'] as String,
  legal: value['legal'] as bool,
  accepted: value['accepted'] as bool,
  submittedAt: DateTime.fromMicrosecondsSinceEpoch(
    value['submittedAt'] as int,
    isUtc: true,
  ),
);
