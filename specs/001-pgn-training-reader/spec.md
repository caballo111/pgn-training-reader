# Specification: PGN Training Reader

**Feature**: `001-pgn-training-reader`  
**Status**: Accepted feature baseline  
**Date**: 2026-09-15

## 1. Product summary

PGN Training Reader is an offline-first application for importing a user's chess
study material, finding individual games or training blocks, reading annotated
content, and practicing authored chess exercises over repeatable training
cycles. The original PGN remains the canonical source of chess content. The
application may index and organize that content, but it must not silently
rewrite its moves, variations, comments, annotations, tags, starting position,
or result.

The first release targets Android and one local user. It supports multiple
imported PGN sources and the content types Puzzle, Instruction, and
Demonstration. Training state and history remain available without network
access.

## 2. Goals and non-goals

### Goals

- Import large PGN collections with visible progress, cancellation, diagnostics,
  and safe continuation after interruption.
- Make indexed content searchable and browsable without requiring the user to
  inspect one enormous document manually.
- Display standard PGN content faithfully, including FEN starts, comments,
  NAGs, and nested variations.
- Provide deterministic puzzle practice based on the authored PGN solution
  tree, while concealing solution-bearing content during an active attempt.
- Organize exercises and explanatory material into ordered sets and repeatable
  cycles that can span sessions and calendar days.
- Show transparent progress, timing, failure reasons, and comparisons between
  cycles.
- Preserve imported material and attempt history through app restarts, source
  changes, and recoverable failures.

### Non-goals for the MVP

- Accounts, cloud synchronization, social features, leaderboards, or a backend.
- Remote chess engines, engine-based puzzle equivalence, or automatic engine
  analysis.
- Editing the imported PGN as part of reading or training.
- Multiple local user profiles.
- Support for unsupported chess variants as standard chess.

## 3. User stories and priority

### US1 — Import a PGN library (P1)

As a chess learner, I want to import a large PGN file and see its contents
indexed progressively so that I can use the library without waiting for the
whole file to be loaded or losing all progress if the operation is interrupted.

### US2 — Browse and read content (P1)

As a chess learner, I want to search and browse indexed games, instructions,
and demonstrations, then open one block with its headers, board positions,
notation, comments, annotations, and variations so that I can study the
material in context.

### US3 — Solve authored puzzles (P1)

As a chess learner, I want to solve a puzzle from its starting position and
receive deterministic validation against the authored PGN variations so that my
result reflects the material's intended solution rather than an opaque engine
judgment.

### US4 — Train in cycles (P1)

As a chess learner, I want to create an ordered set containing exercises and
supporting instruction or demonstration blocks, then complete repeatable cycles
over multiple sessions and days so that I can apply a structured training
method.

### US5 — Review progress (P2)

As a chess learner, I want to review accuracy, active time, outcomes, mistakes,
and cycle-to-cycle changes so that I can understand improvement and identify
material that needs more work.

### US6 — Preserve and recover data (P1)

As a chess learner, I want imports, training progress, and attempt history to
survive interruption, app restart, source changes, and recoverable failures so
that my study material and work are not silently lost or misreported.

## 4. Acceptance scenarios

### US1: Import a PGN library

#### Scenario 1 — Import a valid multi-block PGN

Given the user selects a readable PGN source  
When the user starts an import  
Then the application reports import progress and indexes each discoverable PGN
block in source order  
And the user can browse indexed metadata before opening every full move tree.

#### Scenario 2 — Cancel and resume an import

Given an import has committed some blocks  
When the user cancels or the application is interrupted  
Then committed blocks remain available  
And a later resume continues from a safe boundary without duplicating blocks
or silently skipping a block.

#### Scenario 3 — Import a malformed source

Given a source contains a malformed block between two recognizable blocks  
When the source is indexed  
Then the malformed block is reported with an actionable diagnostic  
And the valid neighboring blocks remain available when their boundaries can be
established.

#### Scenario 4 — Import a source that cannot be used reliably

Given the selected source becomes unavailable, cannot be read, or does not
provide reliable continued access  
When the application detects the problem  
Then it explains what was preserved  
And offers a supported recovery action such as selecting the source again or
creating a reliable local copy.

### US2: Browse and read content

#### Scenario 5 — Search and filter indexed content

Given the library contains indexed blocks  
When the user searches or filters by available metadata such as player, event,
result, content type, section, theme, or difficulty  
Then the application shows matching results in stable explicit order  
And list navigation remains paginated or otherwise bounded for large libraries.

#### Scenario 6 — Read a standard game

Given an indexed block contains a valid standard PGN  
When the user opens it in reader mode  
Then the application shows its headers, starting position, moves, comments,
NAGs, result, and authored variations without silently changing them.

#### Scenario 7 — Read a FEN-start or annotated block

Given an indexed block uses `SetUp` and `FEN`, or contains recursive
variations, comments, or Unicode metadata  
When the user opens it  
Then the application derives and displays the correct starting position and
side to move  
And preserves the available annotations and variation structure.

#### Scenario 8 — Handle unsupported content

Given a block represents an unsupported variant, malformed position, or
otherwise unsupported content  
When the user opens it  
Then the application labels it unsupported and explains the limitation  
And does not silently interpret it as ordinary chess.

### US3: Solve authored puzzles

#### Scenario 9 — Start a puzzle without leaking its solution

Given the user starts an uncompleted Puzzle  
When the puzzle is displayed  
Then the application shows the starting position, side to move, and permitted
training instructions  
But does not expose solution moves, future solution positions, solution
comments, or navigation controls that reveal the answer.

#### Scenario 10 — Accept an authored move and variation

Given the current position has one or more authored acceptable child moves  
When the user submits one of those legal moves  
Then the move is accepted and the puzzle advances according to the authored
solution tree  
And an explicitly authored alternative variation is accepted wherever it is
available.

#### Scenario 11 — Fail on an incorrect move

Given the user is attempting a puzzle  
When the user submits a legal move that is not an allowed child of the current
solution node, or submits an illegal move  
Then the attempt immediately ends with outcome `wrong_move`  
And the wrong move and failure reason are recorded  
And the solution may then be revealed because the attempt has failed.

#### Scenario 12 — Complete, reveal, or skip a puzzle

Given the user is attempting a puzzle  
When the user completes the authored solution, explicitly reveals it, or skips
the puzzle  
Then the attempt is finalized with the corresponding outcome  
And the solution becomes available after completion, reveal, or skip.

### US4: Train in cycles

#### Scenario 13 — Create an ordered mixed set

Given the library contains supported content  
When the user creates a training set  
Then the user can add Puzzle, Instruction, and Demonstration items in an
explicit order  
And the set remains linked to stable content identities rather than transient
list positions.

#### Scenario 14 — Continue a cycle across sessions and days

Given a cycle has pending items  
When the user ends a session and returns later, including on another calendar
day  
Then the application preserves completed items and resumes at the unfinished
item or next pending item according to recorded state  
And time between sessions is not counted as active training time.

#### Scenario 15 — Treat non-puzzle items correctly

Given an ordered set contains an Instruction or Demonstration  
When the user completes or leaves that item  
Then it contributes to set and cycle progress  
But it does not create a scored puzzle result or distort puzzle accuracy.

### US5: Review progress

#### Scenario 16 — Review transparent metrics

Given the user has finalized puzzle attempts  
When the user opens progress for a set or cycle  
Then the application shows attempted, passed, and non-passing outcomes,
accuracy, total active time, average and median active time per attempt, wrong
moves, hints, reveals, skips, timeouts, and abandoned attempts  
And each metric has an understandable definition.

#### Scenario 17 — Compare cycles

Given the user has completed or partially completed more than one cycle for a
set  
When the user compares cycles  
Then the application shows the same raw metrics for each cycle and their
changes  
And does not replace them with an unexplained composite score.

### US6: Preserve and recover data

#### Scenario 18 — Recover after app inactivity or restart

Given a session or attempt is active  
When the app becomes inactive, is backgrounded, or is terminated  
Then the active timing segment is closed or safely recoverable  
And inactive, suspended, closed, and between-day time is excluded from active
solving time  
And the user can resume the unfinished work after reopening the app.

#### Scenario 19 — Detect a changed source

Given an indexed source is missing or its content has changed  
When the user tries to browse or resume content that depends on it  
Then the application detects that the index may no longer identify the same
content  
And asks the user to relink, re-import, or otherwise repair the source before
using affected locators.

#### Scenario 20 — Preserve history during a recoverable data failure

Given a write, migration, or import continuation fails  
When the application reports the failure  
Then previously committed training history and import data remain intact  
And the user receives an actionable recovery path rather than silent data loss.

## 5. Functional requirements

### Import and library requirements

- **FR-001**: The application MUST let the user select a PGN source and import
  one or more sources into the local library.
- **FR-002**: Import MUST process large sources incrementally and MUST NOT
  require the complete source or every parsed block to reside in memory at
  once.
- **FR-003**: Import MUST expose its current phase, progress when measurable,
  indexed-block count, diagnostic count, cancellation state, and final result.
- **FR-004**: The user MUST be able to cancel an import safely. Cancellation
  MUST retain committed work and MUST leave a resumable or clearly restartable
  state.
- **FR-005**: The application MUST establish a reliable way to retrieve an
  indexed block later and MUST detect when the source needed for retrieval is
  missing or changed.
- **FR-006**: The index MUST retain source order, stable content identity,
  source location, standard searchable headers, classification, and parse
  status for each block.
- **FR-007**: The library MUST support search and filtering by player, event,
  result, content type, section, theme, and difficulty when those values are
  present.
- **FR-008**: Search results MUST use stable explicit ordering and support
  bounded list loading for libraries of at least 100,000 indexed blocks.
- **FR-009**: Import diagnostics MUST identify severity, affected block or
  source location when known, a stable diagnostic category, and a sanitized
  actionable message.
- **FR-010**: Duplicate source imports MUST not silently create ambiguous
  training identities. Duplicate exercise identifiers MUST be detected and
  reported rather than silently merged.

### PGN fidelity and content requirements

- **FR-011**: Imported PGN content MUST remain canonical and MUST NOT be
  silently rewritten by indexing, reading, classification, or training.
- **FR-012**: The application MUST preserve standard tags, `SetUp`, `FEN`,
  comments, NAGs, recursive annotation variations, Unicode metadata, moves,
  and results whenever the source is readable.
- **FR-013**: Application-specific classification and metadata MAY be read from
  documented `X-` tags, including `X-ContentType`, `X-ExerciseId`,
  `X-Section`, `X-Sequence`, `X-Theme`, and `X-Difficulty`.
- **FR-014**: A valid `X-ContentType` MUST be authoritative. Unknown values
  MUST be retained as `Unsupported` rather than guessed as a supported type.
- **FR-015**: When classification is inferred, the application MUST mark it as
  inferred and MUST allow a user override without altering unrelated PGN
  content.
- **FR-016**: Every indexed block MUST have an explicit classification:
  `Puzzle`, `Instruction`, `Demonstration`, or `Unsupported`.
- **FR-017**: The application MUST derive the active side and starting
  position from the PGN/FEN content, not from names, titles, comments, or
  duplicated metadata.
- **FR-018**: Unsupported variants, malformed positions, and unparseable
  content MUST be reported as unsupported or malformed and MUST NOT be
  silently interpreted as standard chess.

### Reading and puzzle requirements

- **FR-019**: Reader mode MUST provide headers, position navigation, notation,
  comments, NAGs, results, and authored variations for supported content.
- **FR-020**: The current mode MUST be unmistakable as Reading, Instruction,
  Demonstration, or Puzzle solving.
- **FR-021**: Before a puzzle is completed, failed, skipped, or revealed, the
  interface MUST conceal solution moves, future solution positions, solution
  comments, and answer-revealing navigation or accessibility labels.
- **FR-022**: Puzzle validation MUST use legal chess moves and the authored
  PGN solution tree. It MUST support multiple explicitly authored acceptable
  variations.
- **FR-023**: An incorrect or illegal submitted move MUST immediately finalize
  the attempt as `wrong_move` in the MVP. The failure reason and wrong-move
  count MUST be retained independently of aggregate metrics.
- **FR-024**: A puzzle pass MUST require completion of the authored solution
  without reveal. Completing a puzzle, revealing, skipping, timing out, or
  abandoning it MUST produce a distinct recorded outcome.
- **FR-025**: The interface MUST clearly show whose turn it is and MUST provide
  accessible labels for the board, coordinates, controls, side to move, and
  outcome without relying only on color.
- **FR-026**: Hints, when offered, MUST be explicitly user initiated, counted
  per attempt, and MUST NOT expose solution content before the attempt reaches
  an outcome that permits reveal.

### Sets, cycles, sessions, and timing requirements

- **FR-027**: A training set MUST contain an explicitly ordered mixture of
  Puzzle, Instruction, and Demonstration items.
- **FR-028**: A cycle MUST represent one pass through the exercises in a set.
  The MVP MUST allow at most one active cycle per training set.
- **FR-029**: A cycle MUST span any number of sessions and calendar days, and
  MUST preserve pending, completed, and unfinished item state.
- **FR-030**: A session MUST record wall-clock start and end information for
  history, while active solving time MUST be calculated separately.
- **FR-031**: An attempt MUST record its exercise, cycle and session context,
  start and completion times, active duration, outcome, wrong-move count, hint
  count, reveal status, and failure reason.
- **FR-032**: Active timing MUST stop on pause, navigation away, app
  inactivity, suspension, closure, or termination, and MUST resume as a new
  active segment. Time between segments MUST be excluded.
- **FR-033**: Finalized attempts MUST be append-only from the user's
  perspective. Retrying an exercise MUST create a new attempt and MUST NOT
  overwrite an earlier result.
- **FR-034**: An unfinished attempt MUST be resumable after a recoverable app
  interruption. The user MUST be able to explicitly abandon it, producing the
  `abandoned` outcome.

### Progress and recovery requirements

- **FR-035**: Progress MUST distinguish puzzle outcomes from completion of
  instructional or demonstration items.
- **FR-036**: The application MUST show attempted exercises, passed and
  non-passing outcomes, accuracy, total active time, average and median active
  time per attempt, wrong moves, hints, reveals, skips, timeouts, and
  abandoned attempts.
- **FR-037**: For the MVP, accuracy MUST equal passed finalized puzzle attempts
  divided by all finalized puzzle attempts, expressed as a percentage. An
  empty denominator MUST display as not yet available rather than zero.
- **FR-038**: Cycle comparisons MUST use the same raw definitions and MUST
  show changes without introducing a hidden composite score.
- **FR-039**: All progress-affecting writes MUST be atomic. A failed finalization
  MUST NOT leave a partial attempt, move history, or timing segment presented
  as complete.
- **FR-040**: The application MUST preserve previously committed imports and
  attempts after cancellation, restart, storage failure, or a recoverable data
  migration failure.
- **FR-041**: Before a destructive data operation, the application MUST state
  its scope and require deliberate user confirmation. It MUST provide a way to
  preserve or export training history before synchronization or account
  functionality is introduced.
- **FR-042**: Logs and diagnostics MUST avoid raw PGN text, solution moves,
  comments, secrets, and unnecessary personal data.

## 6. Edge cases and failure behavior

- Empty files, files containing only comments, and files with no complete PGN
  blocks MUST finish with a clear zero-content result rather than appearing to
  succeed silently.
- A source may omit ideal blank-line spacing, contain multiple blocks adjacent
  to one another, or contain malformed content between valid blocks. The
  application MUST preserve valid discoverable blocks and report uncertainty.
- Chunk or read boundaries may occur inside tag names, quoted tag values,
  escaped quotes, brace comments, semicolon comments, move tokens, or nested
  variations. The resulting index MUST be independent of read-boundary
  placement.
- Invalid text encoding MUST produce a diagnostic and MUST NOT silently replace
  or corrupt user content.
- Missing, revoked, changed, or inaccessible source access MUST invalidate or
  suspend affected retrieval until the user repairs the source relationship.
- Insufficient storage or a failed local copy MUST leave the original source
  selection and already committed library data intact, and MUST explain the
  next action.
- Cancelling at the beginning, during a block, or immediately after a commit
  MUST not create duplicate indexed records or a checkpoint inside an
  unresolved block.
- Duplicate or missing exercise identifiers MUST be surfaced. A generated
  stable identity may be used when no authored identifier exists, but file
  position alone MUST NOT be the only permanent identity.
- Unknown custom tags MUST be retained when readable. Unknown content types
  MUST remain Unsupported until the user classifies them.
- Invalid FEN, impossible positions, unsupported variants, and malformed move
  trees MUST be unavailable for puzzle scoring unless repaired or re-imported.
- A puzzle with no authored solution, an incomplete solution, or no legal
  continuation MUST be reported as invalid training content rather than
  automatically passed or treated as an engine puzzle.
- A puzzle with multiple authored acceptable first moves MUST accept each
  matching variation and reject unrelated legal moves.
- An attempt that is paused before the first move still records timing and can
  be resumed or abandoned; active duration may be zero.
- Clock changes, daylight-saving changes, and crossing midnight MUST not change
  active-duration calculations. Wall-clock values are for history and grouping
  only.
- If the app is interrupted while finalizing an attempt, the user must see one
  recoverable final state after restart, not both a partial result and a second
  duplicate result.
- If a referenced block is removed from a set or becomes unsupported, prior
  attempt history remains available and the cycle shows the item as
  unavailable or requiring repair.
- If no attempts exist, progress screens show an empty state and do not claim
  0% accuracy as a measured result.

## 7. Key entities

| Entity | Meaning and important invariants |
|---|---|
| PGN source | A user-owned imported source with display metadata, source identity, revision information, access state, and import state. A source change must be detectable. |
| Indexed block | A searchable record for one discoverable PGN block, including stable identity, source location, ordinal, headers, classification, exercise metadata, parse status, and diagnostics. Source order is retained. |
| Chess content | The faithful supported or unsupported representation of one block: headers, starting position, result, comments, NAGs, and move tree. It is independent of training state. |
| Move node | One position transition in an ordered authored tree, including the move and its annotations. Child nodes represent main-line continuation or accepted variations. |
| Content classification | `Puzzle`, `Instruction`, `Demonstration`, or `Unsupported`, plus whether the classification was authored or inferred and whether a user override exists. |
| Training set | A named, user-owned ordered collection of training items. It may mix puzzles, instructions, and demonstrations. |
| Training-set item | A stable reference to one indexed content block plus explicit order and set-specific state. It is not identified only by list position. |
| Cycle | One pass through the exercises in a training set, with lifecycle state and item progress. A set has no more than one active cycle in the MVP. |
| Training session | A bounded study period within a cycle, with wall-clock start/end values and resumable lifecycle state. |
| Puzzle attempt | One interaction with one puzzle in one cycle. It is append-only after finalization and records outcome, timing, moves, hints, reveal status, and failure reason. |
| Attempt move | A timestamped user-submitted move associated with an attempt, including whether it was legal and accepted. |
| Timing segment | One contiguous period in which an attempt is actively being solved. Segments exclude pauses, inactivity, suspension, closure, and time between sessions. |
| Import job | The durable state of an import, including source revision, progress, counts, cancellation, and the last safe continuation point. |
| Import diagnostic | A sanitized, user-visible report tied to an import and, when known, a block or source location. |
| Progress aggregate | Derived raw counts and active durations for a set, cycle, or selected group of attempts. It must not replace source attempt history. |

## 8. State and lifecycle rules

### Import lifecycle

An import moves through selecting, preparing, indexing, completed, cancelled,
or failed states. A cancelled or failed import retains committed results and
must expose whether it can resume, restart, or requires source repair.

### Training lifecycle

A set may be created, edited, archived, or deleted with deliberate confirmation.
A cycle may be pending, active, completed, or stopped. A session may be opened,
paused, resumed, closed, or recovered. An attempt may be active, paused,
completed, failed, revealed, skipped, timed out, or abandoned.

Only an explicit terminal action or successful completion finalizes an attempt.
Finalization records all terminal fields together. A resumed attempt continues
its existing identity; a retry creates a new attempt.

### Puzzle visibility lifecycle

Before a terminal puzzle outcome, solution-bearing moves, positions, comments,
and answer-revealing navigation are hidden. After pass, wrong move, reveal,
skip, timeout, or abandonment, the user may inspect the solution and related
annotations.

## 9. Measurable success criteria

- **SC-001 Import scale**: On the reference Android device, a library with at
  least 100,000 indexed blocks can be imported incrementally without loading
  the complete source into memory, and progress remains visible and
  cancellable.
- **SC-002 Index correctness**: For representative fixtures, every valid
  discoverable block is indexed exactly once, in source order, with correct
  source location and classification; malformed blocks produce diagnostics.
- **SC-003 Resume correctness**: Cancelling or interrupting an import and
  resuming it produces the same final indexed identities, order, and count as
  an uninterrupted import, with no duplicates.
- **SC-004 Library navigation**: With 100,000 indexed entries, a filtered or
  paginated result page loads in under 250 ms at p95 on the reference device.
- **SC-005 Content opening**: An already indexed individual game or training
  block opens in under 500 ms at p95 on the reference device, excluding an
  explicit source-repair flow.
- **SC-006 Fidelity**: Fixture coverage verifies preservation and correct
  display of standard tags, `SetUp`/`FEN`, comments, NAGs, Unicode metadata,
  one variation, nested variations, and results.
- **SC-007 Puzzle determinism**: Replaying the same authored puzzle input
  produces the same accepted and rejected move decisions, including all
  explicitly authored acceptable variations, on every run.
- **SC-008 Puzzle concealment**: Before a terminal outcome, automated tests and
  accessibility inspection find no solution move, future solution position,
  solution comment, or answer-revealing navigation control in the active puzzle
  view.
- **SC-009 Honest timing**: Tests covering pause, backgrounding, restart, and
  multi-day continuation show that excluded intervals contribute zero active
  solving time and that persisted segment totals are repeatable.
- **SC-010 History integrity**: Retrying a puzzle creates a distinct attempt;
  finalization and its timing data are either both committed or both absent;
  prior finalized attempts remain unchanged.
- **SC-011 Recovery**: After simulated cancellation, process interruption,
  source change, storage failure, and recoverable data-write failure, previously
  committed library data and training history remain readable or have a clear,
  actionable repair path.
- **SC-012 Accessibility**: Core import, browse, reader, puzzle, training, and
  progress workflows expose labels for mode, side to move, board coordinates,
  timing, outcome, and actions, and remain usable without color alone.

## 10. Privacy, ownership, and compatibility expectations

All imported PGNs, annotations, and training history are local user-owned data.
The MVP does not require network access and must not upload source content,
attempt data, or telemetry without explicit informed consent. Destructive
operations must state their scope. Standard PGN compatibility is a product
requirement; application-specific `X-` metadata may be ignored by other PGN
readers without making the underlying chess content unreadable.
