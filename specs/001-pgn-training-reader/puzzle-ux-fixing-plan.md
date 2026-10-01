# Puzzle UX assessment and fixing plan

Date: 2026-10-01. Status: implemented; automated verification passed; Android build and physical-device acceptance pending.

Scope: reading versus solving, casual practice versus cycle training, automatic
opponent replies, completion policies, assistance, continued solving after
failure, review, navigation, and training-set composition. Implementation and automated verification are recorded below. Physical-device
acceptance remains separate from implementation completion.

## Follow-up: builder and board consistency

Status: implemented; all 334 automated tests pass; static analysis,
changed-file formatting, and whitespace checks pass. Review golden inspected.
Physical-device acceptance remains pending.

1. Make book/section/difficulty dropdowns fit narrow widths and long labels.
   Keep Save in a persistent action region, with saving/disabled state. Put
   builder controls before long result/selection lists; expose Select all
   matching results with the current result count and apply current search and
   filters. Preserve source order, deduplication, and unavailable-content guards.
2. Publish the learner's committed position before a short automatic-reply
   pause (target 300 ms). Keep input locked across the transition; Back/pause
   must wait for durable writes. Restore pending replies without unnecessary
   animation delay. Marked opponent replies still require prediction.
3. Keep the first incorrect move and its immutable scored failure. Later
   incorrect practice submissions provide feedback without appending another
   rejected move to notation/history; accepted continued practice remains saved.
4. Show the requested hint by highlighting its origin piece square. Remove
   prose describing that square; keep an accessible label for the granted cue.
   Clear the highlight when play advances, without exposing destination moves.
5. Reuse shared board/moves layout and navigation controls across reading,
   solving, and review. Use icon buttons for first/previous/next/last and flip;
   allow notation clicks to navigate review with selected-move highlighting.
   Keep variations/comments accessible in review and future notation concealed
   during solving. Next move and Next exercise remain distinct actions.

Delegation: Luna workers own the set editor, solver transitions, and shared
presentation respectively. The overseeing agent updates policy, reviews the
combined changes, and checks integration. Acceptance includes narrow-width and
large-text layout tests, bulk search selection, visible save without scrolling,
intermediate reply rendering, durable failure/recovery, visual hint concealment,
clickable review notation, and the full automated suite.

Implemented shared `StudyBoardFrame`, `StudyNavigationControls`, and
`StudyMoveButton` presentation. Reading and review retain their own branch
state while using the same geometry, icon controls, and move selection styling.
Review notation includes move numbers and annotations; duplicate static
notation was removed. Visual hint tests cover white/black orientation and
clearing the cue; a widget test verifies the intermediate learner position
and disabled board during the reply delay. Solver tests cover cancelled replies,
external pause, disposal, immediate recovery, and repeated incorrect predictions.
Integration verifies that cycle pause and casual Back wait for pending reply
writes and restore the saved position without rewriting finalized scores.

## 1. Assessment

### Follow-up: lag when opening the set editor

The builder previously read the full index in sequential 100-entry pages and
put every candidate inside one Column. The nested shrink-wrapped preview also
laid out its entire selection. Result filtering and numbering calculations ran
again on controller updates such as typing the set name. Bulk addition called
single-item addition repeatedly, scanning and copying a growing selection and
notifying listeners once per item.

The editor now uses one CustomScrollView with lazy candidate and reorderable
preview slivers. It requests bounded 1,000-entry metadata pages, stops paging
when the route is disposed, and keeps filtering/numbering outside controller
updates. Visible candidate rows use a selected-ID set for membership checks.
Bulk addition builds the selection in one linear batch and notifies once.
All metadata is still loaded before bulk actions become available, preserving
exact whole-result selection and filter choices rather than selecting just the
viewport. The form and Save render while metadata loads; errors expose Retry.

Verified with a 3,000-entry fixture: three page requests (rather than thirty
100-entry requests), fewer than thirty mounted candidate rows, all 3,000 entries
selected in source order, and no reload on name changes. Tests also verify the
form during a pending load, cancellation after leaving, and drag reordering and
removal in the lazy preview. All 337 tests pass; analysis, changed-file format,
and whitespace checks pass. These are structural and regression results;
on-device opening times have not been measured.

The app currently couples three different decisions: whether content is a
puzzle, whether the reader wants to solve it now, and whether solving belongs
to a repeatable training cycle. These need independent controls.

Code inspection confirms:

- `LibraryPuzzlePractice._start` creates/reuses a single-puzzle training set
  and opens a timed cycle session, even for an ordinary library encounter.
- `GameReaderPage` selects puzzle presentation from content classification.
  A reading preference must not require reclassifying a puzzle as text.
- `AuthoredLinePuzzleEvaluator` evaluates submitted moves against authored
  children and completes at a leaf; it has no author-marker completion policy
  or explicit automatic-opponent operation.
- `PuzzleSolverController` refuses interaction after finalization. The solving
  view replaces the board with an attempt-ended interstitial, preventing the
  requested continued solving after a mistake.
- The move list displays user moves in UCI. The desired list needs readable
  SAN, move numbers, automatic replies, and assistance/error indicators.
- Review uses a separate scrolling layout and forces white orientation.
  `StudyLayout` already exists for the other study surfaces.
- `ActiveSessionPage` wraps nested scaffolds in a `PopScope` with `canPop:
  false`, then attempts to pop after closing. This is a navigation defect
  candidate, not a verified device diagnosis. Reproduce both toolbar and system
  Back before choosing the fix.
- The set editor adds one block at a time and uses `Event` as its title,
  including placeholder `?` values. Indexed metadata already includes source,
  exercise ID, section, sequence, and difficulty.

The checkmark semantics and Woodpecker examples below are supplied assessment
requirements; this pass did not independently inspect the source PGN.

## 2. Recommended UX decisions

### Reading and training are independent

Use a remembered **per-book preference**: “Solve puzzles” or “Read normally”.
Default to concealed puzzle previews until the user chooses otherwise.

Provide “Read this puzzle” on the current puzzle as a temporary override, and
“Read puzzles in this book” to persist the preference. Provide the reverse
action so the learner can return to solving. A global preference can be added
later as a default for new books; it should not replace book-specific choices.
Per-puzzle persistence would create unnecessary micromanagement.

Reading exposes normal notation, comments, and variations without scoring or
starting a timer. It changes presentation intent, not content classification.
Entering reading after starting an attempt is an explicit answer exposure:
finalize an unfinished attempt as revealed before exposing answers; preserve an
already failed outcome. A later fresh attempt does not erase that history.

Offer casual solving directly from library content, without creating a set or
cycle. Casual history, if retained, remains separate from cycle metrics. Enter
cycle training through an explicitly selected training set. Any supported
puzzle content can join a set; neither title nor Woodpecker identity determines
eligibility. A reading preference does not silently bypass cycle exercises;
reading an active cycle puzzle uses the explicit reveal/review action.

### Ordinary solving sequence

1. Show the starting position, learner side, and exercise progress.
2. Learner submits a move; accept only encoded authored continuations.
3. Play the authored opponent reply automatically, then return control to the
   learner. With multiple opponent continuations, use authored principal order
   deterministically; retain other branches for review. Learner alternatives
   remain equally acceptable when explicitly encoded.
4. Record both sides below the board using SAN and move numbers.
5. On a wrong move, immediately record failure and show “Incorrect — you can
   keep trying”. Return the board to the last accepted position after brief
   feedback, retain the rejected move in the interaction record, and allow
   another move. Do not disclose the full solution automatically.
6. Offer Hint, then Show move, plus a separate Show solution action. Keep these
   actions available during continued practice after failure.
7. On reaching the applicable completion point, enter review automatically
   in the same board layout. Keep the reached position and orientation.
8. Let the learner dwell and inspect the solution. Advance only through “Next
   exercise”; the final exercise offers “Finish cycle”. Casual batches follow
   source order and return to the book when finished.

Separate immutable **scored attempt state** from **interactive practice state**.
Failure ends scoring and its timer, but continued practice can still advance
the board. Practice/review time is excluded from scored completion time.
Post-result interactions must not be appended by mutating finalized attempt
records; use a separate interaction record if durable continuation is needed.
Persist enough position/phase information to restore review or continued
practice after restart without advancing to the next item automatically.

### Assistance and scoring

Recommended initial hint: identify/highlight the piece to consider, without
playing the move. Show move then supplies and plays one accepted move. Show
solution exposes the full line and enters review.

Count hints and record move reveals explicitly. A hint makes the attempt
assisted and ineligible for an unassisted pass; showing a move/solution makes
an unfinished attempt revealed. Continued success cannot turn failure or
reveal into a pass. Preserve an earlier failure as the historical outcome and
record subsequent assistance separately.

Use an explicit assisted result for hint-only completion and display it
separately in reports; update metric definitions rather than silently treating
assisted success as passed. Avoid inferring tactical hints from prose comments.
The revised concealment policy permits only the explicitly requested hint or
move, not unrelated future moves or comments. Do not add repetitive confirmation
dialogs; label the scoring consequence at the action.

### Completion policy

| Policy | Completion point |
|---|---|
| Key Moves | First reliable accepted checkmarked move on the selected branch; full continuation if that branch has no marker. |
| All Moves | Leaf of an accepted authored continuation. |

Allow policy selection before casual practice or cycle start. Recommend Key
Moves when supported markers exist; otherwise All Moves. Persist the effective
policy and fallback reason with attempt history. For cycles, fix the policy for
the cycle and reuse it for comparable subsequent cycles.

Recognize an explicit, documented checkmark token attached to a move; do not
treat any mention of checkmarks in explanatory text as an endpoint. Preserve
raw comments and every subsequent move. Detection is generic and independent
of the book title; the initial token is `✔`. Other spellings require verified
fixtures rather than broad guessing.

A marker on an alternative branch cannot finish the main branch. Evaluate
markers only on the actual accepted path; show a non-spoiling “Full line used:
no completion marker on this continuation” notice when fallback is established.

For strict Key Moves scoring, pause automatic play **before a marked opponent
reply** and ask the learner to predict that reply on the board. Correct
prediction reaches the endpoint; wrong prediction fails. Ordinary opponent
replies remain automatic. If a simplified mode later auto-plays marked replies,
record and label its less strict scoring separately.

Exercise 15 (`1... Qxf1+ {✔} 2. Kxf1 Re1#`) must pass on `Qxf1+` in Key Moves;
All Moves continues through mate. Exercise 14's alternative-branch marker must
not complete the unmarked main line. Comments describing unencoded winning
ideas do not become accepted moves; no engine equivalence is introduced.

### Review and Back

Use `StudyLayout` for solving and review, with stable board size, position,
orientation, flip control, and supporting pane. Review exposes full authored
notation, annotations, and variation navigation. Start at the reached position,
while preserving access to the initial position and subsequent authored moves.

Define one route owner and distinguish Back from Next exercise. Back from the
study surface returns to its launching book/set context; variation/position
navigation uses its own controls. Back pauses unfinished scored work and closes
timing durably, without skipping or advancing. A storage failure keeps the
learner on the surface with a retryable error. Repeated taps cannot close twice.
After durable closure, allow a deliberate route pop through the `PopScope`
guard. Remove ambiguous “Return to cycle” advancement wording.

### Training sets

A set is a saved, ordered selection, not automatically a whole book or a
difficulty category. Repeat the same selection over cycles and sessions/days.

Builder flow: choose book → optional section/difficulty → select all, exercise
range, first half/second half, or individual entries → preview → save. Allow
additional selections from other books, removal, and reordering before save.
Range selection uses displayed exercise numbers where metadata supports them;
missing numbers and gaps must be visible. Source order is the default order.
Half shortcuts operate on filtered puzzles, with the first half taking the
extra item for odd counts. Include supporting text only by explicit selection.

Preview lists readable titles and distinguishes puzzle count from text count.
Prefer exercise identity with section/book context, meaningful authored title,
then player names or source ordinal. Treat `?` and blank metadata as missing.
Bulk addition deduplicates by stable block ID and reports unavailable or
unsupported entries rather than silently accepting them. The candidate browser
must query all matching entries, not just the currently loaded library page.

Snapshot ordered membership and scoring policy for each cycle. Editing a set
affects future cycles; it cannot change a running/historical cycle. Comparisons
identify changed membership/policy and do not present them as like-for-like.

## 3. Implementation order and deliverables

| Phase | Deliverable | Main touchpoints |
|---|---|---|
| 1 — Policy and state foundations | Update SDD contracts; define reading intent, casual context, completion policy, move actor, assisted scoring, and separate interaction phase. Design persistence/migrations and cycle snapshots before changing UI. | `spec.md`, `data-model.md`, both training contracts, domain models, Drift schema/repositories. |
| 2 — Navigation and shared review | Reproduce/fix Back; adopt `StudyLayout`; retain orientation/position; automatic review with explicit Next/Finish and no interstitial. | `ActiveSessionPage`, `PuzzleSolvingView`, `PuzzleSolutionReviewView`, navigation and style guide. |
| 3 — Solver behavior | Automatic replies, strict opponent prediction, branch-specific markers/fallback, continued practice, hints/show move, SAN history. Persist transitions atomically and restore them after interruption. | Evaluator, solver controller/projection, session service/controller, attempt and interaction persistence. |
| 4 — Library reading/casual practice | Per-book preference and temporary override; ordinary reader access; standalone/batch solving without synthetic cycles. | Library practice, reader controller/page, app routes, preference and casual-practice persistence. |
| 5 — Set builder and comparisons | Bulk section/range/half selection, cross-book composition, previews and meaningful titles; use cycle snapshots and report policy differences. | Set editor/controller, index queries, set/cycle repositories, progress reports. |
| 6 — Acceptance | Focused regression checks plus a physical-device walkthrough of book reading, casual batches, and repeatable cycles. | Existing unit/widget/integration suites and device acceptance checklist. |

Update FR-020/021 for reading intent and explicitly requested assistance;
FR-023/024 for immutable scoring versus continued interaction and completion
policy; FR-026 for useful hints and assisted eligibility; FR-027–033 for casual
context, fixed cycle selections, persistence, and timing; FR-035/037 for assisted
results and comparison semantics. Revise acceptance scenarios, task tracking,
and the puzzle visibility lifecycle together. Existing leaf-based history stays
historical All Moves history; do not reinterpret old attempts using new markers.
Existing synthetic library sets/cycles retain their history and are clearly
identified as legacy practice rather than deleted or rewritten.

## 4. Acceptance gates

- Read a puzzle normally without changing its classification, creating a set,
  or affecting cycle accuracy. Reopen the book and retain its reading preference.
- Import another tactics source and train selected puzzles without a title check.
- Correct learner moves trigger the selected authored opponent replies exactly
  once; interruption/retry produces no duplicated reply or move history.
- Exercise 15 stops at its marker in Key Moves and at mate in All Moves;
  Exercise 14 isolates alternative-branch completion; unmarked branches fall back.
- Marked opponent replies require prediction before credit. Test both learner
  colors, FEN starts, promotions, and encoded alternative learner moves.
- After one wrong move, continue solving on the same board and finish with the
  original failed score. Assisted/revealed attempts never become unassisted passes.
- Show only requested assistance before review; no future solution leakage in
  visible UI, accessibility labels, or presentation state.
- Completion enters review with stable board/orientation and no auto-advance;
  dwell time does not change scored duration. Resume the same interaction phase
  after restart, including the final puzzle awaiting Finish cycle.
- Toolbar/system Back work from solving, prediction, failure continuation,
  paused state, and review. Verify pending writes, repeated Back taps, save
  failure/retry, backgrounding, and restart preserve committed history/timing.
- Build Easy, exercises 1–100, first half of Easy, and a mixed-book/text set;
  preview exact order/counts, readable titles, deduplication, and excluded items.
- Repeat an unchanged set across days/cycles; editing membership or scoring
  policy cannot alter previous cycles or produce misleading comparisons.

Use focused domain tests for scoring, restoration, branch selection, atomicity,
and snapshots; widget tests for reading intent, assistance, move list, layout,
and navigation; integration tests for persisted casual/cycle flows and timing.
Device verification is required for the reported Back and board-layout issues.

## 5. Boundaries

No PGN cleanup is needed for the supplied preserved checkmarks. Imported PGN
bytes remain canonical. Existing in-progress parser, move-tree, and presentation
changes must be preserved when implementing this plan. Engine validation,
comment-only answer acceptance, and automatic book-specific eligibility are
outside scope.


## 6. Implementation verification (2026-10-01)

Implemented with six Luna subagents and parent integration: per-book reading
intent; temporary reading override; persisted standalone casual solving without
cycle rows; direct Next exercise; branch-specific completion policies; automatic
replies with marked-opponent prediction; continued practice after failure;
counted hints/Assisted completion; shown moves/Revealed results; shared board and
review layout; durable Back; bulk sets and export-header titles; cycle snapshots
and cursors; comparison compatibility; and SDD policy updates.

- All 316 tests passed with flutter test --no-pub test.
- Analysis of lib, test, and integration_test reports no issues.
- Formatting and whitespace checks passed.
- Updated and visually inspected phone golden snapshots.
- Android debug build could not run because this environment has no Android
  SDK. Installation and physical Back/layout acceptance remain pending;
  widget tests cover toolbar/system Back and persistence-failure retry.

The Exercise 15 regression uses a constructed legal position for the supplied
move sequence rather than claiming to reproduce the source book FEN. Existing
scored history and pre-existing parser/move-tree edits were preserved. Legacy
cycles with unknown original membership have unavailable comparison metadata.
