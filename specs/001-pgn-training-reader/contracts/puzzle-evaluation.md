# Puzzle Evaluation Contract

This contract defines authored-line evaluation and the separation between a
cycle-scored attempt and continued practice interaction. Acceptance follows
legal moves in the PGN tree; it never uses engine equivalence.

## Inputs and policy

- Initialization requires supported Puzzle content, a valid starting
  position, at least one authored move, and an unfinished attempt (or a
  finalized attempt restored for read-only/continued practice).
- A cycle attempt uses the cycle's frozen completion policy (`keyMoves` or
  `allMoves`). A standalone solve uses the policy selected for that
  interaction, persisted in its interaction JSON. Reading intent (`read` or
  `solve`) does not choose a policy.
- Submitted learner moves use UCI. The active side and position come from the
  PGN/FEN and accepted move history.
- Initialization exposes the current board and user/practice history, never
  future solution moves, positions, annotations, or branch labels while the
  presentation is concealed.

## Authored branches and completion

Every legal child in the authored tree is an acceptable continuation. A key
move is a node whose comment contains `✔` as a standalone token; token
boundaries are whitespace or comment boundaries. Substrings such as `✔!` and
`x✔` are not markers. Marker detection applies along the actually accepted
branch, not across unrelated variations.

- `keyMoves` completes the scored line when the user reaches a marked node on
  the accepted branch.
- If that accepted branch has no marker, `keyMoves` falls back to the branch's
  authored endpoint even when another variation contains a marker.
- `allMoves` ignores markers and completes only at an authored terminal node.
- Ordinary opponent moves are played automatically using the first authored
  child in source order. Show the committed learner position before a short
  reply pause, keeping input locked until the durable transition completes.
  Recovery may immediately apply a durably pending reply. Under `keyMoves`, when an opponent reply is marked as
  a key move, pause for the learner to predict it; credit requires the
  learner's correct prediction.
- A move completing a line with no hint usage finalizes `Passed`. If one or
  more hints were used, it finalizes `Assisted`. Both have no failure reason.
- A hint increments the attempt hint count and may expose only the permitted
  hint cue: highlight the origin piece square on the board, with an accessible
  label for that granted cue. Do not replace the highlight with prose. Clear
  it when play advances; it does not expose destination moves or annotations.

## Move evaluation and continued practice

For each submitted move, check chess legality and then compare a legal move
against children of the current authored node. Accepted moves advance the
shared practice board. A submitted illegal move finalizes the scored attempt
as `WrongMove` with `IllegalMove`; a legal move outside the authored children
finalizes it as `WrongMove` with `IncorrectMove`. Record the submitted move
and increment the wrong-move count once.

That first error ends scoring for the attempt immediately. The board remains
interactive and concealed so the learner can keep practicing. Later practice
moves and their board position are persisted in the separate interaction
record; they cannot mutate the finalized attempt, its outcome, failure reason,
or metrics. Keep the first rejected move for the scored audit; additional
incorrect practice submissions are recorded in separate interaction history
when distinct by attempt, authored position, and normalized UCI. Repeats across
all prior submissions at that position show feedback without duplicate entries.
Accepted practice moves remain persisted. Feature 002 defines the continuous
study surface, versioned interaction history, and rejection presentation.
For a new interaction, keep solution content concealed until the
learner completes the continued practice line or explicitly reveals the
solution. Reaching the authored endpoint later does not change `WrongMove` to
`Passed` or `Assisted`.

A legacy finalized attempt restored without a saved interaction/snapshot may
enter read-only solution review immediately. This compatibility path does not
apply to a newly scored first error with a persisted practice interaction.
The active cycle cursor may identify a finalized attempt while that practice or
review remains open. Restore the cursor and interaction before selecting a
later cycle item; clear the cursor only after the explicit Next action.

An unsubmitted illegal board gesture is not an attempt move. Malformed UCI is
input validation failure and does not finalize or record a move.

## Reveal, show move, and review

- **Show move** finalizes an unfinished scored attempt as `Revealed` before
  advancing the shared practice board through the shown authored move. It may
  continue the automatic authored reply. The score can never later become
  `Passed` or `Assisted`.
- **Reveal solution** finalizes an unfinished attempt as `Revealed` and exposes
  the authored solution for review.
- Skip, timeout, and abandon finalize with their respective outcomes. Their
  established failure-reason rules remain in force.
- Review uses the shared practice board and its current position. The user
  navigates clickable notation with selected-move highlighting and the shared
  first/previous/next/last icon controls used in reading. Variations and
  annotations remain available. The user
  navigates review explicitly and advances to the next exercise with an
  explicit **Next** action; completion does not silently advance the cycle.
- Showing a solution after another terminal outcome never rewrites that
  outcome.

## Persistence and recovery

Scored move recording and attempt update are atomic. A terminal move and its
closing timing segment commit together. Continued practice for an already
finalized attempt is written separately from scored history. If either write
fails, publish neither an uncommitted board state nor a partial score.

Restore the saved practice cursor and interaction after interruption. A
finalized attempt remains immutable; resume the interaction record for board
practice. When no interaction exists for a legacy finalized record, permit
read-only solution review without creating or rewriting a score. A retry is a
new attempt identity and does not overwrite prior history.

Persisting a cycle cursor is a separate operation from score finalization and
non-puzzle completion. Those records remain correct if a later cursor write
fails; selection/recovery must consult the currently durable cursor and
attempt history rather than assume one shared transaction.

Production logs and diagnostics must not disclose solution moves or comments.
