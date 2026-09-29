# Training Session Contract

This contract defines cycle, session, item-selection, and puzzle-attempt
lifecycle coordination in domain terms. It complements
`lib/domain/training/training_session_service.dart` and the cycle, session,
item, attempt, and timing-segment models. Training records are local and
progress-affecting writes obey FR-039 atomicity. Its persistence boundary is
`lib/domain/training/training_repository.dart`.

## Preconditions

- A new cycle can start only for an existing, active training set containing
  supported items. An archived, missing, empty, or otherwise untrainable set
  cannot start a cycle.
- A set has at most one active cycle. A second `startOrResumeCycle` call
  returns/resumes that existing active cycle; it does not create a duplicate.
- Opening a session requires an active cycle and no other active session for
  that cycle. `studyDay` is a history-grouping value, not a duration input.
- Pausing requires an active session. If it owns an active attempt, the caller
  supplies that open segment's nonnegative monotonic duration; otherwise the
  active-attempt duration is null. Resuming requires a paused session.
  Recovery requires an interrupted active session and closes work at the last
  durable lifecycle boundary.
- Item selection requires a known active cycle. Item order is the explicit
  set order. Instructions and demonstrations are traversed but do not create
  scored puzzle attempts.
- Pause requires an unfinished attempt with an open active segment and a
  non-negative monotonic segment duration. Resume requires an unfinished
  paused attempt. Finalization requires an unfinished attempt and
  non-negative duration for any open segment.
- Attempt lifecycle status is one of `active`, `paused`, or `finalized`.
  Creation/resume is `active`; pause changes it to `paused`; resume changes it
  back to `active`; exactly one terminal outcome changes it to `finalized`.
  The outcome (`passed`, `wrong_move`, and so on) is separate from this
  lifecycle status. A finalized attempt cannot return to either unfinished
  status.
- Wall-clock timestamps are for audit/history. Active durations come from a
  monotonic clock and exclude paused, inactive, suspended, closed, and
  between-session time.

## Operations and results

### Start or resume a cycle

Returns the active cycle if one exists for the set. Otherwise creates and
returns a new cycle with the supplied wall-clock start time. Completed or
stopped cycles remain historical records; beginning another pass creates a
new cycle identity.

### Open and close a session

Opening creates an active session with start time and study day. Closing an
active or paused session records its end time and returns the closed session.
Before closing, any active attempt must be paused or finalized so its current
timing segment is closed. Session wall-clock duration is never counted as
puzzle-solving time.

### Pause, resume, and recover a session

Pausing changes an active session to `paused`. If the session has an active
attempt, the same durable transition closes its open timing segment, adds the
given monotonic duration to the attempt, and changes the attempt status to
`paused`. The duration is null only when no attempt is active. Resuming changes
the session to `active`; if it contains an unfinished paused attempt, that
attempt returns to `active` with a new timing segment. The resume result
contains the session and that segment, or null for the segment when there is
no paused attempt.

Recovery ends an interrupted active session with `recovered` status. It pauses
unfinished work and closes the active segment at the last persisted lifecycle
boundary. Unmeasurable time after that boundary is excluded. A later session
can resume the same unfinished attempt with a fresh segment.

### Select the next item

Returns an unfinished exercise first, otherwise the next pending item in
explicit set order, or null when every item is complete. Puzzle completion is
determined by this cycle's attempt history; instruction and demonstration
completion is tracked by durable cycle-scoped completion records. Selection
alone creates no attempt and does not count non-puzzle content as a scored
result.

### Start a puzzle attempt

Starting requires a Puzzle item belonging to the active cycle's set, an
active session belonging to that cycle, and no unfinished attempt for that
item in the cycle. It creates an `active` attempt and its first open timing
segment atomically. A retry after an earlier finalized attempt receives a new
attempt identity; it does not overwrite history.

### Complete a non-puzzle item

Completing an Instruction or Demonstration records durable completion keyed
by cycle ID and training-set-item ID. Completion is idempotent for the same
cycle/item pair, does not mutate the shared set item, and does not create a
scored attempt. The supplied completion time is retained for history. The
operation rejects Puzzle items or items outside the cycle's set.

### Pause and resume an attempt

Pause closes the current timing segment, adds its monotonic duration to the
attempt total, and retains the same unfinished attempt identity. Resume starts
a new timing segment and returns that segment. The gap between segments is
excluded. Process recovery must use the last persisted lifecycle boundary;
unknown time after that boundary is not counted.

### Finalize an attempt

Finalization accepts one terminal outcome: `passed`, `wrong_move`, `revealed`,
`skipped`, `timed_out`, or `abandoned`. It records completion time, outcome,
active duration, failure reason, and reveal status, and closes any open timing
segment in the same transaction. `wrong_move`, `timed_out`, and `abandoned`
require a failure reason; other outcomes omit it. `revealed` requires
`revealed = true`. For an incorrect or illegal submitted move, the evaluator
must first determine `wrong_move` with `incorrectMove` or `illegalMove`
respectively under FR-023; session finalization must not override it with a
later pass, skip, or reveal outcome.

The attempt lifecycle status becomes `finalized` at the same commit as its
outcome and completion time. Before that commit, an attempt is `active` or
`paused` and has no outcome or completion time.

### Complete a cycle

Completing requires an active cycle, every required ordered item traversed,
durable completion for each Instruction and Demonstration, and at least one
finalized attempt for each required Puzzle. It records the cycle completion
time and `completed` status without creating an attempt. Cycle completion
does not rewrite or remove its session or attempt history.

## Atomicity, retention, and lifecycle

- Starting a cycle, changing progress, closing a segment, and finalizing an
  attempt are atomic. In particular, final attempt state and its closing
  timing segment commit together; a failed commit leaves no partial result
  represented as complete.
- Pausing a session with an active attempt commits the session transition,
  attempt pause, and segment closure together. Resuming commits the session
  transition and any new attempt segment together. Recovery commits the
  recovered session and safe attempt/segment boundary together. Completing a
  non-puzzle item and completing a cycle persist their progress transitions;
  repeated completion of the same cycle/item is idempotent.
- Starting a puzzle attempt commits its active attempt and initial open timing
  segment together. It is rejected when another unfinished attempt already
  exists for that item in the cycle.
- A cycle may span any number of sessions and calendar days. Completing an
  item does not require completing the entire cycle in one session.
- Paused/resumed work transitions between `active` and `paused` while retaining
  attempt identity. Explicit retry creates a new attempt linked to the same
  exercise/cycle and never overwrites history.
- Finalized attempts are append-only from the user's perspective. Removing a
  set item or losing its source does not delete prior attempts.
- A cycle completes only after all required ordered items have been traversed
  and every required scored item has a finalized outcome. Instruction and
  demonstration traversal contributes cycle completion, not puzzle accuracy.
- Closing, backgrounding, suspension, or process termination closes or safely
  recovers active timing. Unknown elapsed wall-clock time is excluded.

The repository returns `null` for missing record lookups, keeps list results
in deterministic order, creates cycle/session/attempt records only with their
stable identities, and updates only mutable lifecycle fields. It rejects
duplicate IDs and a second active cycle for a set. Attempt moves are immutable
once recorded and use unique increasing ordinals. Closing a timing segment
updates that segment and the unfinished attempt's accumulated active duration
atomically. Finalizing persists the immutable attempt and, when present, its
last timing segment in one transaction. Raw aggregates preserve per-attempt
durations; metrics are calculated by a domain calculator, not by persistence.
Submitted moves are recorded with the resulting attempt state through one
atomic repository operation; cycle-scoped non-puzzle completion is durable
and queryable by stable item ID.

## Errors and recovery

| Condition | Contract behavior |
|---|---|
| Set missing, archived, or untrainable | Reject cycle start with a validation/domain failure; create no cycle. |
| Cycle missing or not active | Reject session opening/item selection as invalid or not found; do not create progress. |
| Another active session exists for the cycle | Reject the second open; preserve the existing session. |
| Session missing/terminal or end time precedes start | Reject close; retain prior session state. |
| Pause of a missing or non-active session; resume of a non-paused session | Reject the lifecycle transition and retain the current session/attempt state. |
| Session recovery requested for a missing or non-active session | Reject recovery; do not fabricate a lifecycle boundary. |
| Non-puzzle completion references a puzzle or item outside the cycle's set | Reject; create no completion and no attempt. |
| Cycle completion requested while any required item is pending or any puzzle lacks a finalized attempt | Reject; leave the active cycle unchanged. |
| Puzzle attempt start references a non-puzzle item, mismatched session/cycle, or an item with an unfinished attempt | Reject; create neither attempt nor timing segment. |
| Attempt missing, finalized, or in wrong lifecycle state | Reject start/pause/resume/finalize; never mutate a finalized historical attempt. |
| Negative active duration or inconsistent outcome metadata | Reject input validation; commit no attempt or timing changes. |
| Storage failure during a progress transition | Roll back all parts of that transition; preserve prior committed cycles, sessions, attempts, and segments. |
| Process interruption during an open segment | Recover at the last durable boundary, exclude unmeasurable time, and leave the attempt resumable or explicitly abandonable. |

Typed failures crossing application layers use the safe `AppFailure` hierarchy
(for example, validation and database failures). Error messages must not
include raw PGN, solution moves, private paths, or content URIs.
