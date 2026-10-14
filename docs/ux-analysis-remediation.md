# Reading, puzzle review, and analysis: UX remediation list

Assessment date: 2026-10-14.

Status: all twelve remediation items have been implemented. Final verification
is recorded in the implementation evidence below. The findings retain the
original problem descriptions for review.
Assessment evidence: the supplied app screenshots and inspection of the current
Flutter implementation. Lichess and TakeTakeTake comparisons refer only to the
supplied screenshots. No live device walkthrough was performed for the
assessment.

## Current flows

### Reading

The authored board is static. Explore position and a compact engine control are
pinned beside the board controls, while comments and notation remain in the
scrolling details. The board can be compacted or expanded. Explore position
opens or resumes a personal draft at the selected authored occurrence. Explore
suggestion saves the full principal variation in that draft and opens at its
origin so the learner can step through the line.

### Finished training puzzle

Once the solution is visible, the solver transitions to solution review. Review
normally starts at the accepted/reached path, unless a saved review path exists.
The textual outcome, Review solution, and Review my tries are surfaced in the
details; Explore position and a compact engine control stay beside the board.
Exploring a legal rejected try opens after its attempted SAN move; an illegal
try opens the pre-move board and identifies the illegal move.
The review footer provides the next exercise/finish action, with retry also
available in casual book practice. Exploration replaces that footer with Return
to review.

### Personal analysis

The workspace accepts legal moves for both sides, preserves sibling branches,
and saves drafts when a repository is configured. The displayed notation is
only the path ending at the current cursor. Continuation buttons show only
children of the current position. Previous removes the last cursor index;
Next always selects child zero. First and Last also operate only on personal
moves. Book context is collapsed; selecting a book move from reading-origin
context saves the draft and exits to authored reading. Review-origin book
context now includes selectable authored notation and sibling alternatives;
selecting one saves the draft and returns to review at that move.

## Remediation backlog

P1: address in the first remediation pass. P2: address next. These priorities
describe learning and navigation impact, not production incident severity.

### R01 — Next/Last silently switch branches (P1; code-confirmed)

After exploring a second sibling, Previous then Next follows the first stored
sibling. Last repeatedly follows that first-child rule. Users cannot reliably
retrace the variation they just investigated.

Remediation: maintain the selected continuation independently of cursor depth.
Previous/Next must traverse that selected line. Choose another branch explicitly.

Acceptance: create branches A and B, explore B, step backward and forward, and
remain on B. Last reaches B's leaf. All siblings remain available.

Evidence: `lib/domain/analysis/exploration_session.dart`, `previous`, `next`,
and `last`.

### R02 — Rewinding hides the continuation and earlier branch points (P1; code-confirmed)

The move tree renders only moves through the cursor. On rewind, later moves
disappear from notation although they still exist in storage. From a leaf,
alternative branches at earlier moves have no visible indicator. Users must
backtrack to discover them. The label Other continuations also includes all
children, without identifying the selected continuation.

Remediation: show the complete selected line, including moves after the cursor;
mark branch points and expose sibling variations at their divergence. Highlight
the current move and selected branch. Keep the active move visible during navigation.

Acceptance: rewinding leaves later notation visible and selectable; a branch
created earlier can be found from the current leaf without guessing its location.

Evidence: `lib/features/analysis/presentation/exploration_move_tree.dart` and
the `activeLine`/`branches` getters in `exploration_session.dart`.

### R03 — Explore suggestion jumps to the end and changes meaning by context (P1; code-confirmed)

From reading/review it enters a workspace. Inside a workspace it inserts the
entire engine line into the current tree. Both operations select the line's
end, so the learner loses the starting position and must rewind to understand
the first suggested move. Engine-seeded moves look like manually entered moves.

Remediation: offer a consistent View engine line action that opens the line at
the current position or first suggested move. Keep Add line to exploration as
a separate explicit operation. Label engine-origin continuations; allow manual
branches from any selected move. Never automatically advance to the final move.

Acceptance: viewing a suggestion preserves the origin and permits step-by-step
inspection; adding it retains existing sibling branches and identifies its source.

Evidence: `ExplorationWorkspaceState._loadDraft`, `_playSuggestedMoves`, and
`AnalysisPanel`'s Explore suggestion callback.

### R04 — Analysis entry is hidden and inconsistent across reading/review (P1; implemented)

Reading puts the engine switch after the whole authored tree, while Explore
position is pinned. Review puts Explore in the scrolling details. On phones,
the board and multiple action rows leave only a small details viewport. The
screenshots show different fragments of the analysis card as the user scrolls.

Remediation: use one stable board-adjacent Explore position entry in reading and
review, plus a compact engine control/summary. Give lesson text, moves, and
analysis enough visible space; reduce stacked action rows and support a compact
board layout. Engine detail can expand without burying navigation.

Acceptance: exploration entry and engine state are discoverable without scrolling
through an entire chapter; analysis summary and its primary action fit together
at portrait phone size and enlarged text.

Implementation: reading and review use a pinned Explore/Resume entry beside a
compact engine summary. The board has a visible compact/expand control. Long
notes no longer push these actions out of reach. Covered by
`fits a narrow phone with enlarged text and long comments` and
`review actions stay visible with long notes at large text`.

Evidence: `TextView.build`, `PuzzleSolutionReviewViewState.build`,
`StudyLayout`, and the three supplied app screenshots.

### R05 — Completed-puzzle review does not foreground the learner's question (P1; implemented)

The outcome is an icon with a tooltip; Your tries is collapsed below the engine
panel. A learner asking why a rejected move failed must discover that section,
choose a try, and then enter a workspace whose title describes the pre-move
origin without naming the attempted move.

Remediation: present a compact textual outcome and clear Review solution,
Review my tries, and Explore position choices. Show the attempted move and
whether the board is before or after it when investigating a try. Keep Next
exercise/Finish cycle as the explicit progression action.

Acceptance: after a completed puzzle with a rejection, the learner can identify
and explore that rejection without searching through engine controls. Legal
tries open after the attempted move; illegal tries explain the pre-move position.

Evidence: `PuzzleSolutionReviewViewState._outcomeIndicator`, `_exploreTry`,
and the details ordering in `build`.

Implementation: review now shows a textual outcome with Review solution and
Review my tries actions. Try rows show the SAN and explicitly say whether
exploration opens after a legal rejected move or before an illegal move. Covered
by `review reveals authored content for every terminal outcome`,
`legal rejected try opens the board after its move`, and
`illegal rejected try identifies the pre-move position`. Existing preservation
coverage includes `review detour preserves reached position and source, and
starts engine off` and `reviewing a legal rejected try seeds it without
changing accepted solution`.

### R06 — Engine notation is unreadable and not directly navigable (P1; screenshots and code)

Principal variations are presented as a single raw UCI string, while personal
moves use numbered standard chess notation. The user must enter another flow
to inspect an individual engine move.

Remediation: render engine lines in numbered chess notation with selectable
moves. Use compact rectangular move highlights and consistent current-move
styling for book, personal, and engine notation. Keep evaluation perspective,
side to move, and line ownership explicit.

Acceptance: no ordinary engine line displays raw coordinates; selecting its
third move previews that precise position in an explicitly labeled line view.

Evidence: `AnalysisPanel.build`, `ExplorationMoveTree`, and app screenshots.

### R07 — Exploration controls cannot reach preceding book moves (P2; implemented)

First/Previous stop at the exploration origin. In reading, reaching an earlier
book move requires expanding Book context, selecting it, exiting exploration,
then opening another draft. In review, Book context has no selectable notation.

Remediation: label the personal origin and navigation scope visibly. Provide
Jump to book move/Explore from another book move with a clear save-and-switch
transition and access to the authored line in both reading and review.

Acceptance: investigating an earlier book decision takes a clear, short path,
preserves the original draft, and creates/resumes the correct draft at the new origin.

Implementation: review Book context includes selectable SAN notation and
authored sibling choices under the “Explore another book move” context. Selecting
one flushes exploration before returning to the chosen review move and keeps the
original draft. Covered by
`book notation returns to the selected sibling review move after save`.

### R08 — Showing suggestions requires repeated taps during investigation (P2; code-confirmed)

Suggestion visibility resets on position changes, loss of a result, and deeper
analysis. A user who explicitly chose to view suggestions must repeatedly press
Show suggestion while stepping through an analysis line.

Remediation: retain the user's suggestion visibility choice within the current
analysis workspace. Clear stale results immediately, then display the new line
when ready. Reset the preference when entering concealed solving or a new block.

Acceptance: with suggestions shown, navigating three personal moves does not
require three additional reveal taps; hiding suggestions remains explicit.

### R09 — Entry loses engine context and reading origin labels omit move numbers (P2; implemented)

Opening a workspace stops/disposes the source engine and constructs a new panel
with Engine off. This follows the existing policy, but the handoff does not
explain it. Reading origins use After SAN without a move number, while review
origins include one. Repeated moves can therefore be hard to locate by title.

Remediation: standardize origin labels, such as Exploring from 12...Nf6, and
show a compact Engine paused/Enable engine affordance when arriving from engine
output. Keep the default-off policy; any automatic engine continuity would need
an explicit product decision.

Acceptance: the learner can identify the exact book occurrence and engine state
on entry without inspecting several controls.

Implementation: reader origins include the move number and side-to-move
punctuation. Entry captures the selected path, complete UCI history, orientation,
engine request, and scroll offset before awaiting shutdown; conflicting reader
navigation is blocked until handoff finishes. Engine-seeded lines enter at their
origin and the workspace explains that the source engine was paused. Covered by
`entry snapshots the tapped origin while engine shutdown blocks navigation`.

### R10 — Saved drafts have resume but no visible pruning/reset controls (P2; code-confirmed)

The workspace preserves every branch and exposes Resume exploration, but it
does not provide a way to remove an accidental branch or clear the draft. This
makes repeated investigations progressively harder to manage.

Remediation: add Delete variation and Clear exploration as secondary actions,
with undo where feasible. Distinguish returning to the origin from deleting moves.

Acceptance: a learner can remove one unwanted branch while preserving siblings
and can deliberately start fresh at the same authored origin.

### R11 — Training can silently fall back to an unsaved workspace (P1; implemented)

Training scope lookup errors are converted to null; a null scope disables the
draft repository. The workspace looks normal and does not indicate that its
moves will not persist after departure.

Remediation: surface scope lookup failure with retry, or visibly mark the
workspace as temporary and offer recovery/save before exit. Avoid presenting
normal saved-draft expectations when persistence is unavailable.

Acceptance: force scope lookup failure; the learner receives a clear indication
and recovery action before investing in an exploration that cannot be restored.

Evidence: `ActiveSessionPage._scopeForItem`, `_content`, and `_reviewSurface`;
before this change, lookup errors became null and the workspace did not report
that drafts might not persist.

Implementation: lookup errors no longer become a null scope or replace the
reading/review surface. A retry banner appears, exploration stays disabled until
the retry succeeds, and a successful null result is labeled temporary before
entry and again in the workspace. Covered by
`scope lookup failure keeps review visible and retry restores exploration`.

### R12 — Origin capture can drift during asynchronous entry (P1; implemented)

Reading captures its origin only after awaiting engine shutdown. Its move
navigation remains enabled during that await. Review similarly reads the selected
path after shutdown. A rapid navigation action can therefore change the anchor
after Explore was tapped, while the suggested moves still belong to the old
position. Seeding silently stops at an illegal move, obscuring the mismatch.

Remediation: capture origin, history, orientation, and return location at tap
time; validate suggestion ownership against that snapshot; serialize entry or
temporarily disable conflicting navigation. Report failed insertion explicitly.

Acceptance: with delayed engine shutdown, tap Explore suggestion and immediately
navigate. The workspace opens at the tapped position with its matching line, or
the transition is explicitly canceled; no silent partial insertion occurs.

Evidence: `TextViewState._openExploration`, `PuzzleSolutionReviewViewState._explore`,
and the seeding loops in `ExplorationWorkspaceState`.

Implementation: reader and review capture their complete entry state before
awaiting engine shutdown, serialize conflicting entry navigation, and validate
that the source presentation is still current before opening. Review captures
the selected variation path and orientation as well. Covered by
`entry snapshots the tapped origin while engine shutdown blocks navigation`
and `review entry snapshots path and orientation before engine shutdown`.

## Proposed coherent flow

- Reading -> select an authored move -> Explore position -> manual branches ->
  Return to reading at the same move and scroll location.
- Finished puzzle -> visible outcome and reached position -> Review solution or
  Review my tries -> Explore position/this try -> Return to review -> explicit
  Next exercise or Finish cycle.
- Exploration -> select any move in the complete active line -> play a different
  legal move -> a visible sibling branch -> Previous/Next stays on that branch.
- Engine on -> numbered, selectable engine line -> View line -> step through it;
  optionally Add line to exploration without replacing existing branches.

## Existing behavior to preserve during remediation

The implementation already keeps personal drafts separate from authored PGN,
retains siblings, restores reading/review cursors and scroll, waits for configured
draft saves before return, and gates answer-bearing assistance on solution
visibility. Ordinary review initially preserves the reached position. Existing
widget tests cover several of these behaviors. Remediation should preserve these
contracts, attempt outcomes, and scored solving duration.

The earlier `analysis-and-exploration-plan.md` remains useful context. This
assessment identifies gaps between its intended interaction and current UI;
it does not authorize scoring changes or automatic engine activation.

## Implementation evidence

The user authorized implementation of the complete list. Three GPT-6 Luna agents
at max effort implemented the domain/tree, engine UI, and study-entry changes;
the parent integrated the workspace, responsive layout, and regressions.

| Item | Delivered behavior | Exact regression evidence |
| --- | --- | --- |
| R01 | Previous/Next/Last retain the selected variation | `next and last follow the explicitly selected sibling variation` |
| R02 | Full selected line remains visible, sibling branches are accessible, active move scrolls into view | `rewind keeps the full line visible and earlier siblings selectable`; `navigation scrolls the current move into view` |
| R03 | View engine line is a safe board preview; Add line is explicit and retains the cursor and provenance | `numbers the engine line in SAN and previews selected moves before adding`; `adding an engine line preserves the board cursor and labels its moves`; `adding a line does not pop the parent route during handoff` |
| R04 | Reading/review tools stay beside the board; compact board and responsive notes layout | `analysis tools stay reachable while long lesson details scroll`; `compact board frees reading space and expands again`; `review actions stay visible with long notes at large text` |
| R05 | Textual outcome, direct rejected-try entry, explicit before/after semantics | `review reveals authored content for every terminal outcome`; `legal rejected try opens the board after its move`; `illegal rejected try identifies the pre-move position` |
| R06 | Numbered selectable SAN and visible White-relative evaluation | `numbers the engine line in SAN and previews selected moves before adding` |
| R07 | Book context exposes authored moves in reading and review, saves drafts before returning to the selected move | `book context authored move returns to that reader position`; `book notation returns to the selected sibling review move after save` |
| R08 | Suggestion visibility persists within the workspace; off/ineligible clears output | `keeps revealed suggestions through three moves and deeper analysis, then resets off`; `disabling eligibility clears output and stops the engine` |
| R09 | Numbered origins, tap-time orientation, visible paused-engine handoff | `entry snapshots the tapped origin while engine shutdown blocks navigation`; `temporary draft and engine handoff are visible without scrolling` |
| R10 | Exact variation deletion and draft reset with Undo; compatible v1 draft decoding | `deletes one variation while retaining its sibling`; `clear exploration can be undone and saves restored moves`; `loads version 1 drafts without selected path or node provenance` |
| R11 | Persistence lookup errors keep review visible, offer Retry, and prevent unsaved entry; temporary drafts are labeled | `scope lookup failure keeps review visible and retry restores exploration`; `disabled exploration also blocks rejected-try entry` |
| R12 | Entry snapshots precede engine shutdown; engine insertion is atomic | `review entry snapshots path and orientation before engine shutdown`; `invalid seeded line retains existing draft without partial moves`; `invalid added engine line does not leave a partially inserted branch`; `does not expose a legal prefix of an invalid engine line` |

The casual reading footer now emphasizes Next block and makes Solve puzzle
secondary. Move highlights use compact rectangles with accessible touch targets.
Engine preview dismissal targets its own route, including during a frame update.

Phone review and active-puzzle snapshots were rendered and visually inspected,
including enlarged text. The baselines were refreshed with the current local
Flutter renderer without relaxing image-difference tolerances. No device
walkthrough is claimed by this verification.

Final validation: `flutter analyze` completed with no issues; `flutter test
--reporter expanded` completed with **489 tests passed**. After a final test-only
lint correction, the engine-panel suite was rerun and all **18 tests passed**.
`git diff --check` is clean.

Rejected-try origins are labeled before the attempted move so the book context
stays attached to its correct position; legal tries are still selected after
that move on entry. The two puzzle-review suites were rerun after this label
clarification with **15 tests passed**.
