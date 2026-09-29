# Puzzle Evaluation Contract

This contract defines deterministic domain evaluation against a supported
Puzzle's authored PGN move tree. It complements
`lib/domain/training/puzzle_evaluator.dart` and the attempt models. Legal move
checking uses the chess-rules adapter; authored acceptance uses the children
of the current solution node. No engine-equivalence judgment is part of this
contract.

## Preconditions

- Initialization receives supported `Puzzle` content with a valid starting
  position and at least one authored solution move.
- The attempt belongs to that puzzle and is unfinished. An already finalized
  attempt cannot be initialized for further scoring.
- The attempt lifecycle status must be `active` or `paused` when initialized;
  only an `active` attempt accepts a move (resume it before submission if
  initialized while paused). Status is separate from its
  terminal outcome: only `finalized` attempts have an outcome and completion
  time.
- The starting position and active side are derived from PGN/FEN and the move
  tree, not from display metadata.
- Submitted moves use the evaluator's UCI input format. Legal-destination
  queries use algebraic square names.
- Calls that require an initialized evaluator are made only after successful
  initialization. Move submission is allowed only while the attempt status is
  `active`.

## Operations and results

### Initialize

Initialization returns an immutable state containing the current FEN, side to
move, attempt record, and user-submitted move history. It exposes no solution
tree or future solution moves. `state` is null before initialization;
`finalAttempt` is null until terminal evaluation.

### Query legal destinations

The result is the set of legal destination squares from the requested origin
in the current position. It answers chess legality only and does not indicate
whether a move belongs to the authored solution. After finalization the result
is empty. Querying before initialization is an invalid state.

### Submit a move

For each submitted move, the evaluator first determines legality in the
current chess position, then compares a legal move with the authored child
nodes at the current solution node. An accepted child advances the current
position and records the move as legal and accepted. Any authored alternate
child is equally acceptable; child order has no correctness priority. The
resulting attempt remains `active` unless the move ends the attempt.

An accepted nonterminal move leaves the attempt unfinished. An accepted move
that reaches an authored terminal solution finalizes `passed`, provided no
earlier terminal result exists. A legal move absent from the authored children
finalizes `wrong_move` with `incorrectMove`. A submitted move that is illegal
in the current position finalizes `wrong_move` with `illegalMove`. In either
failure case, the submitted move is retained with its legality/acceptance
flags, the wrong-move count is incremented once, and the result cannot later
be changed to passed. A terminal result has status `finalized` and its
completion time is recorded in the same transition.

FR-023 precedence: every move actually submitted to the evaluator that is
illegal or an incorrect authored move immediately finalizes `wrong_move`.
Whether an unsubmitted attempted board gesture is ignored is a presentation
boundary; it cannot be used to accept a move or change attempt history.

### Reveal

Reveal finalizes an unfinished attempt as `revealed`, sets the reveal marker,
and makes the authored solution available to presentation. If an attempt was
already finalized, reveal does not replace its historical outcome. On a
previously failed or passed attempt, presenting the solution after the
terminal outcome does not relabel the attempt as `revealed`.

## State and atomicity

- State advances only along the selected accepted authored child; unrelated
  legal moves never advance the puzzle.
- The persistence boundary records each submitted move and its resulting
  attempt state together through `TrainingRepository.recordSubmittedMove`.
  For a terminal move, the move record, updated counters/status/outcome, and
  closing timing segment (if any) commit in one transaction. For a nonterminal
  move, status remains unfinished and no timing segment is closed. If the
  transaction fails, move history, attempt state, and timing data all remain
  at their prior committed values.
- Terminal outcomes are immutable. Repeating a puzzle creates a new attempt;
  it does not reset or overwrite the finalized attempt.
- Solution-bearing moves, future positions, comments, NAGs, and variation
  labels remain unavailable to puzzle presentation before a terminal outcome
  or explicit reveal.

## Errors and recovery

| Condition | Contract behavior |
|---|---|
| Unsupported content, invalid position, or no authored solution | Reject initialization as invalid/unsupported training content; do not auto-pass or use engine equivalence. |
| Attempt already finalized | Reject initialization/submission as an invalid state; preserve its outcome. |
| Query or submission before initialization | Invalid state (`StateError` at this interface boundary). |
| Move submission after finalization | Reject as invalid state; no additional move or counter is recorded. |
| Malformed UCI input or invalid square | Reject input as validation failure; it is not a submitted legal or illegal chess move and must not be confused with FR-023's submitted illegal move. |
| Illegal chess move in valid move notation | Finalize immediately as `wrong_move` / `illegalMove` under FR-023. |
| Legal move not in authored children | Finalize immediately as `wrong_move` / `incorrectMove`. |
| Persistence failure during move/finalization | `recordSubmittedMove` rolls back the move, updated attempt, and optional closing segment together; preserve the last committed attempt state. |

The domain state exposed to a puzzle-solving view must not include the
solution tree. Diagnostics and production logs must not disclose solution
moves or comments.
