# Training Session Contract

This contract defines book reading intent, standalone solving, cycle
snapshots, item selection, session timing, and scored attempt lifecycle. It
complements the domain training service and repository boundaries.

## Reading intent and score boundary

Each book has a reading intent: `read` or `solve`. `Read` opens the puzzle as
reader content. `Solve` opens a standalone interaction unless the user
separately starts or resumes a cycle. Standalone puzzle moves, hints, and
reveals are stored in a separate interaction history. They never
create database Cycle or TrainingSession rows, show an active-time timer, or
appear in cycle aggregates. The standalone controller may construct an in-memory
attempt with synthetic cycle/session IDs to reuse puzzle interaction APIs;
those IDs are not persisted as lifecycle records. Standalone progress stays
separate in its solving flow. Reading intent does not choose completion policy
or make a standalone solve cycle-scored. Cycle scoring requires an active cycle
and a puzzle selected by that cycle.

## Start or resume a cycle

Removing a set archives it and records a durable removal marker atomically.
Visible set lists exclude removed definitions, while stable-ID lookups retain
them for historical relationships. Removed sets cannot be edited or used to
start/resume training through the set list. No cycle, session, attempt, snapshot,
or imported content is deleted. Already archived sets keep their archive time.

A new cycle requires an active, nonempty, trainable set. At creation,
transactionally snapshot the explicit ordered selection as `(set item
identity, block identity, content type)`. Persist the selected completion
policy (`keyMoves` or `allMoves`) separately before puzzle training begins;
after that initial write the policy cannot change. The reading intent is
independent. Later set edits do not rewrite an existing cycle selection or
policy. A legacy cycle without a snapshot uses `allMoves` and the retained
set definition as a compatibility fallback. Its original membership cannot be
reconstructed reliably, so comparisons with unknown snapshots are disabled. A standalone solve interaction selects and persists its
own policy in that interaction record.

At most one active cycle exists per set. Starting/resuming returns that cycle
when present; otherwise it creates a new identity and item-selection snapshot.
Completed or stopped cycles remain historical. The cursor identifies the
current attempt/item, including finalized attempts with an open practice or
review interaction. Cursor writes are separate from corresponding score or
item-completion writes. On resume, restore the durable cursor before selecting
any later item. The cursor may refer to an active/paused attempt or a finalized
attempt whose practice/review interaction remains open. Reopen that attempt and
its interaction first; after explicit Next clears the cursor, select the next
pending snapshotted item in order. Do not filter finalized cursor attempts out
as if they were completed navigation.

The selected cycle completion policy is written before puzzle training and is
immutable thereafter. A different selection applies to standalone solve
interactions or a newly started cycle only.

## Sessions and active time

Opening a session requires an active cycle and no other active session for
that cycle. Session `studyDay` groups history only. Active durations use a
monotonic clock and exclude pauses, inactive/background time, process gaps,
and time between sessions.

Pausing closes the current timing segment and retains attempt identity.
Resuming opens a new segment. Process recovery closes work at the last durable
lifecycle boundary and excludes unknown elapsed time. Closing a session first
pauses or finalizes any active attempt. Session transitions and their timing
changes commit atomically.

## Select and complete cycle items

Selection follows the cycle's snapshotted explicit order. Restore the durable
cursor before selecting the next pending item. Puzzle completion is derived
from cycle attempt history. Instruction and Demonstration items
have durable completion keyed by cycle and item; they do not create scored
attempts or affect puzzle accuracy. Non-puzzle completion is idempotent. Its
cursor update is a separate write; do not assume both writes share one
transaction.

Cycle completion requires traversal of every snapshotted item, durable
completion for each non-puzzle item, and at least one finalized scored attempt
for every required puzzle. Completion does not create or rewrite attempt
history.

## Scored attempts

Starting a puzzle attempt requires its item in the active cycle snapshot, an
active session, and no unfinished attempt for that item. It creates a new
attempt and timing segment atomically. A retry after finalization receives a
new attempt identity.

Each submitted move is evaluated against legal chess moves and authored
children. The first incorrect or illegal submission finalizes the scored
attempt as `WrongMove` with its reason and wrong-move count. Practice remains
interactive and concealed afterward; its later board interactions are stored
outside the immutable score. Reaching the solution later cannot turn that
score into a pass.

Completing the snapshotted policy endpoint finalizes `Passed` when no hint was
used, or `Assisted` after one or more hints. Showing a move finalizes
`Revealed` before advancing the shared practice board. Reveal, skip, timeout,
and abandon are distinct terminal outcomes. A terminal score and its timing
closure commit together and remain append-only.

Review uses the shared practice board. The learner chooses review navigation
and advances to another item only with an explicit **Next** action.

## Atomicity, retention, and failures

- Cycle creation and ordered selection snapshot commit together. The cycle
  policy is persisted in a later, separate write before puzzle training.
- Attempt creation and its first timing segment commit together.
- Submitted move and resulting scored state commit together; a terminal move
  also closes its timing segment in the same transaction.
- Non-puzzle completion is durably recorded and idempotent; its later cursor
  update is a separate write.
- Session pause/resume/recovery commits session, attempt, and segment changes
  together.
- Before closing a session or leaving its page, wait for in-flight session and
  puzzle-controller writes to become idle, then close. Do not discard pending
  writes during navigation or disposal.
- Standalone interaction persistence is separate and cannot update cycle
  aggregates.
- Cursor writes are separate from attempt scoring and non-puzzle completion.
  The application waits for pending controller writes to become idle before
  closing a session or leaving its page, then performs the close transition.
- Failed writes leave the prior committed state visible. Never publish an
  uncommitted cursor, interaction, outcome, or duration.
- Missing, archived, or untrainable set; mismatched item/session/cycle;
  unfinished duplicate attempt; negative duration; and invalid lifecycle
  transition are rejected without partial progress.
- Removing a set item or losing its source does not remove cycle snapshots or
  historical attempts. Show unavailable content with its history retained.
