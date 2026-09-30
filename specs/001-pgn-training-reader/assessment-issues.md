# SDD assessment issues

Assessment date: 2026-09-30 (America/Managua).
Device: Samsung SM-S931B, connected through ADB.
Source: `The Woodpecker Method (September 2024).pgn`, imported from Android Downloads / Quick Share.

The user reported the visible failures below. ADB inspection of the original
source and inspection of the current application code support the diagnoses.
No source PGN or application behavior was changed during this assessment.
Checked implementation tasks do not establish acceptance of these device flows.

## ASSESS-001 — Introductory block rejected because of Z0 placeholder

Status: Implemented; physical-device acceptance recheck pending.
Category: Instructional-content compatibility gap.

Reproduction:

1. Import the Woodpecker PGN.
2. Open its first indexed entry (`White` header: `1) Introduction`).

Observed: The app displays “The selected PGN block contains a move that cannot
be read safely.”

Evidence: The first block contains introductory brace commentary and ends with
`1. Z0 *`; its `PlyCount` is `1`. It is therefore not literally a block without
move text, but its only move token is a placeholder rather than a playable
standard-chess move. `DartchessContentParser._node` rejects any token for which
`Position.parseSan` returns null. The header-only `ContentClassifier` infers
Demonstration for this block because there is no explicit content type or FEN
setup. There is no explicit Z0 instructional-placeholder handling.

Expected resolution: Define and implement narrow, documented support for this
export's instructional placeholder. Preserve the original PGN and its
commentary; do not silently discard arbitrary invalid moves or interpret the
placeholder as an ordinary chess move. Expose inferred classification and the
user override required by the specification.

Acceptance criteria:

- The first introductory entry opens with its commentary readable.
- The instructional entry creates no scored puzzle attempt.
- Original source bytes remain unchanged.
- Actual malformed move sequences still produce a typed diagnostic.
- Regression coverage distinguishes placeholder-only instructional content
  from ordinary games, puzzles, and malformed move sequences.
- Recheck the flow on the physical device with the original PGN.

Implementation notes:

- Only commentary-bearing standard-start blocks whose complete movetext is
  `1. Z0 *` (allowing whitespace and comments) receive placeholder support.
  FEN/setup blocks, authored Puzzle/Demonstration tags, alternative null-move
  spellings, variations, and mixed move sequences do not qualify.
- The parsed reader retains headers and all introductory/placeholder comments,
  records `Z0` as placeholder metadata, and creates no playable move. Legacy
  classification is inferred as Instruction; authored Instruction remains
  authoritative. No PGN bytes are written.
- The reader displays inferred classification and provides a local, persisted
  override for blocks without an authored content type. Overrides update index
  metadata only; reopening respects the saved classification. Re-indexing
  currently recalculates this metadata from the source.
- Parser, source-range repository, reader/no-scoring, and override persistence
  regressions pass. The index repository test setup now uses the current
  `indexed` source state rather than the obsolete `ready` state.
- Physical-device recheck remains pending: the Samsung device and original PGN
  are outside the sandbox, which has no ADB access. Reopen the existing first
  entry on the device after deploying the fix; confirm commentary, inferred
  classification, no scored attempt, and source-byte preservation.

Related specification: FR-011–FR-016, FR-018, FR-019; US2 and US4 Scenario 15.
Related implementation tasks: T094–T097, T105, T107, T109.

## ASSESS-002 — Library puzzle opening reaches unavailable placeholder

Status: Implemented; physical-device acceptance recheck pending.
Category: Library-to-puzzle integration defect.

Reproduction:

1. Import the Woodpecker PGN.
2. Open `4) Easy Exercises` / `Exercise 1` from the library.

Observed: The app displays “Puzzle practice is not available yet.”

Evidence: Exercise 1 contains `SetUp "1"`, a FEN starting position, and an
authored three-ply solution. The reported message is the fallback in
`GameReaderPage` when puzzle content has no `puzzleViewBuilder`.
`lib/app/navigation.dart` opens library blocks using
`GameReaderPage(content: content)` without that builder. The puzzle controller
and solving view exist and are integrated into the active training-session
presentation, but the library opening path does not connect them.

Expected resolution: Connect library puzzle opening to a supported solving
flow, with explicit attempt/session semantics and lifecycle handling. Keep
solution moves and answer-bearing comments hidden before the allowed outcome.
Editing the imported PGN cannot repair this missing application wiring.

Acceptance criteria:

- Opening Exercise 1 from the library reaches a usable puzzle flow.
- The initial board and active side derive from its authored FEN.
- Solution moves, answer-bearing comments, and accessibility output remain
  hidden until permitted by the puzzle outcome.
- Authored-line evaluation and completion work through the library entry path.
- Attempt persistence and timing follow the documented training semantics;
  opening or backing out does not create misleading completed results.
- Navigation regression coverage exercises the real library opening path.
- Recheck the flow on the physical device with the original PGN.

Implementation notes:

- Library puzzle opening now displays only the authored starting position and
  side to move, with an explicit Start or resume practice action. Opening or
  leaving this preview creates no attempt, session, or training set.
- Starting practice creates or reuses an active single-puzzle library practice
  set. This set appears in Training sets and its results use normal training
  progress reporting. Edited or archived practice sets retain their history;
  only intact active sets are reused. Completed practice can start a new cycle.
- Practice uses the existing active-session controller and puzzle solver:
  authored-line evaluation, durable moves/results, monotonic active timing,
  lifecycle pause, and interrupted-session recovery follow training semantics.
  Back navigation pauses an unfinished attempt and closes the session without
  recording a completed outcome; starting again resumes that same attempt.
- The preview renders no PGN headers, comments, or solution moves. The solver
  uses its existing safe presentation projection until a permitted outcome;
  solution review is available after the attempt ends. Source bytes are never
  written by this flow.
- A navigation regression opens the real library route using an indexed PGN
  fixture, verifies the FEN's black active side, no preview attempt, hidden
  answer comments, paused/resumed identity, authored three-ply completion,
  persisted pass, and permitted solution review. This test and the existing
  active-session widget/session integration tests pass (five tests). Analysis
  of `lib` and `test` is clean. Full-repository analysis still reports existing
  issues in `research/prototypes/dartchess_probe`.
- Physical-device recheck with the original Woodpecker PGN remains pending;
  the Samsung device and source are outside this sandbox. On the device, open
  Exercise 1, start practice, leave and resume, complete the authored line,
  and confirm timing, result persistence, and solution visibility.

Related specification: US3 Scenario 9; FR-017, FR-020–FR-024.
Related implementation tasks: T107 and Phase 10 puzzle UI integration.

## ASSESS-003 — Game Changer foreword rejected because of -- placeholder

Status: Open.
Category: Instructional-content compatibility gap.
Assessment date: 2026-09-30 (America/Managua).
Source: `Sadler, Matthew & Regan, Natasha - Game Changer - AlphaZero's Groundbreaking Chess Strategies and.pgn`, in the same Android Downloads / Quick Share directory.

Reproduction:

1. Open the imported Game Changer library on the Samsung SM-S931B.
2. Select `Main Level — Foreword by Garry Kasparov`.

Observed on the physical device through ADB: The entry is listed as
`demonstration`. Opening it shows `Unable to open PGN` and “The selected PGN
block contains a move that cannot be read safely.”

Evidence: The original first block has introductory brace commentary, no FEN
setup, and ends with `1. -- *`. Dartchess recognizes this token in its PGN
syntax tree, but the application's legal-move conversion rejects it. The
current instructional-placeholder adapter explicitly requires the original
movetext to match `1. Z0 *`, so the Woodpecker-specific handling does not cover
this export. This is a distinct reproduction of ASSESS-001 with another source
and another placeholder spelling; broad null-move support must not be inferred
from support for instructional pages.

Expected resolution: Extend the documented instructional-export compatibility
policy to cover this observed placeholder-only page while preserving source
bytes and comments. Keep genuine null moves within game/variation sequences
outside that narrow policy unless separately specified and supported.

Acceptance criteria:

- The original Game Changer foreword opens as readable instructional content.
- Placeholder-only handling covers both observed export spellings without
  accepting arbitrary malformed moves or mixed null-move sequences.
- Opening it creates no scored attempt and does not rewrite the PGN.
- Add regression coverage and repeat the foreword opening on the device.

Related specification: FR-011–FR-016, FR-018, FR-019.
Related implementation tasks: T094–T097, T105, T107, T109.

## ASSESS-004 — Game Changer publisher markup has no reader presentation

Status: Open; source/code evidence confirmed, physical-device rendering
verification blocked by ASSESS-003.
Category: Rich-comment presentation compatibility gap.

Evidence: The foreword's opening comment embeds a heading between
`@@HeaderStart@@` and `@@HeaderEnd@@`. Both `InstructionView` and
`DemonstrationView` render comments with plain `Text(comment)`, with no
interpretation of these export markers. Thus the current reader would expose
the raw delimiters rather than present a heading after parsing is unblocked.
The same entry has `Event "?"`; the reader title currently prefers Event over
the descriptive `Black` header, losing the useful foreword title.

Expected resolution: Define a presentation-only policy for the observed
publisher heading markers and a useful title fallback when Event is an
unknown-value placeholder. Preserve the original comment and headers; unknown
markup must remain available rather than being silently deleted.

Acceptance criteria:

- The foreword heading is readable without raw recognized delimiters.
- The page has a descriptive title rather than `?`.
- Long commentary remains fully reachable by scrolling on the phone.
- Original comments and headers remain canonical and unchanged.
- Validate the actual rendered foreword after ASSESS-003 is resolved; assess
  further publisher markup only when encountered in the source.

Related specification: FR-011, FR-012, FR-019.
Related implementation tasks: T095, T105–T108.
