# Assessment and design decisions

Date: 2026-10-02. This records the assessment before implementation.
Assessment evidence: user report and static source/document inspection.
At that stage, no app execution, device inspection, new tests, or implementation was performed.
The physical experience and exact animation timing still need acceptance on
the user's device during implementation.

## Findings

| Finding | Source evidence | Consequence |
| --- | --- | --- |
| Reading's Solve this puzzle only flips `_readThisPuzzle` to false. | `lib/app/library_puzzle_practice.dart`, reading banner in `build`. | The action's label promises solving but opens a chooser. |
| Preview contains completion policy and current/book read/solve actions. | Same file, preview `details: ListView`. The fourth action is conditional on saved Read preference. | Immediate action and persistent defaults compete in one decision. |
| Starting practice calls `Navigator.push` into `_CasualPuzzlePage`. | Same file, `_openCasualPractice`. | Another route replaces book context and navigation. |
| Solver controls follow progress, policy, feedback, moves, and assistance prose. | `puzzle_solving_view.dart`, details ListView. `StudyLayout` fixes the board and reserves limited remaining detail height. | As history grows, controls require scrolling; fixed flip control has higher visual priority than essential actions. |
| Casual page uses Casual practice as its primary title and Exercise 1 of 1. | `library_puzzle_practice.dart` and `puzzle_header.dart`. | Mode is visible, but book/section identity and meaningful book progress disappear. |
| Review is another scaffold/view state on the casual route. | `_CasualPuzzlePage.build`, `_review` branch. | It is not another pushed route at this stage, but replaces the solve surface and header, creating the perceived screen break. |
| Retry and Next exercise follow comments, solution notation, and variation dropdowns. | `puzzle_solution_review_view.dart`, details ListView. | Long reviews bury continuation actions. Back to book is fixed only when no next callback exists. |
| Variation dropdowns follow the line and label `depth + 1` as a move number. | Same file, `variation-$depth` dropdown. | Alternatives are detached from their branch point and ply depth is mislabeled as chess move number. |
| Review already restores reached accepted path and orientation. | Same file, `_initializeReachedPath`. | Preserve this behavior while making the visual shell and controls continuous. |
| Next exercise actually targets the next indexed source block. | `lib/app/navigation.dart`, `onNextPuzzle` delegates to `navigate(nextBlock!, startSolving: true)`. | Mixed content is already reachable, but label is misleading and consecutive puzzles are forced into solving rather than respecting book intent. |
| All later rejected practice entries are suppressed. | `puzzle_solver_controller.dart`, `_play`, `suppressRepeatedWrongPractice`. | It checks finalized wrongMove + rejected learner/prediction, with no equality check against earlier moves. Distinct later mistakes are lost. |
| Tests explicitly preserve suppression of a different wrong prediction. | `test/unit/features/puzzle_solver/puzzle_ux_flow_test.dart`, wrong marked opponent prediction scenario (`d7d5`, then `d7d6`). | Fixing only UI cannot repair history; policy and regression expectations must change together. |
| Current rejection has no dedicated hold/return phase. | `_play` retains accepted FEN; `puzzle_board.dart` resynchronizes board on widget updates. | A rebuild can return the piece immediately. The existing 300 ms delay applies to accepted opponent replies. |
| Section exists in indexed metadata but is not passed into casual solving. | `PgnBlockIndex.section`; indexer reads `X-Section`; casual view receives puzzle/controller/policy. | Context can use existing metadata without a whole-book parse. |

The previous [puzzle UX plan](../001-pgn-training-reader/puzzle-ux-fixing-plan.md)
is a historical implementation record, including the suppression rule now
reported as a bug. Its automated completion does not establish acceptance of
this new requested flow or the user's physical-device experience.

## Chosen UX practices

1. **Direct action:** Solve puzzle executes its stated action. Defaults and
   practice options belong in book/settings menus, not an entry gate.
2. **Continuity:** book, block, board geometry, and orientation anchor a single
   surface; mode changes modify the interaction and details.
3. **Progressive disclosure:** make the board task, Hint, Show solution, and
   continuation easy to find; expand settings, history, and extra notes on demand.
4. **Visible feedback:** rejected moves have a perceptible cue and rollback,
   a non-color status message, and a clear opportunity to keep trying.
5. **Contextual variations:** alternatives sit beside their branching move;
   selected path and comments track the board.
6. **Deliberate progression:** completing a puzzle leaves time to review;
   Next block follows the book's actual order.

These are design recommendations grounded in the reported tasks and code,
not claims from a usability study or external standards review.

## Decisions and alternatives

| Decision | Rationale and tradeoff |
| --- | --- |
| One study shell with explicit Read / Solve / Review states. | Removes route churn and duplicate app bars. A full replacement of reader/domain models is unnecessary. |
| Fixed state-specific action region. | Ensures reachability; reserve its height before sizing the board. On small/large-text displays the board must shrink. |
| One fixed Show solution action to finalize/reveal and enter review. | Gives a clear escape from failed practice. Keep first-error concealed continuation. |
| Read default for previously unset book intent. | Matches ordinary reading; existing saved Solve preferences remain valid. A local Solve action never changes the default. |
| Position-scoped deduplication across the entire attempt. | A/B/A counts two distinct mistakes. Global UCI deduplication would lose mistakes in different positions. |
| Separate scored error and practice mistakes. | Preserves finalized outcomes/timing and avoids rewriting historical metrics. Show distinct practice mistake count with an explicit label. |
| Persist review cursor and answer exposure locally. | Supports returning to the same learning context and honest casual labeling. No imported PGN writes. |
| Use explicit section metadata; neutral identity fallback. | Current index has X-Section. Legacy section reconstruction from titles needs an actual PGN fixture and separate rules; avoid guessing. |
| Keep cycle navigation semantics in its owner. | Book source order and snapshotted cycle order are different. Shared widgets take labeled callbacks rather than choosing order themselves. |

No new packages, network services, engine, or license changes are needed.
Animation feasibility must be checked against the pinned chessground API before
implementation chooses native animation or a small presentation overlay.
