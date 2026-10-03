# Ordered implementation tasks

Status: implementation complete; automated acceptance passed; physical-device review pending.
Authorized on 2026-10-02. Evidence: [validation.md](validation.md).
The subsequent [space refinement](space-refinement.md) has static validation
only; its runtime, visual, and device checks remain pending.
Read the constitution, [spec.md](spec.md), [plan.md](plan.md), and
[contract](contracts/study-flow.md) before implementing. Task IDs are scoped to
feature 002. Each task's acceptance evidence belongs with its implementation.

## Specification alignment

- [x] CS-T01 Adopt this feature's requirements and update 001 `spec.md`
  (FR-023, FR-019a/020/025/026d and relevant scenarios), `data-model.md`,
  `contracts/puzzle-evaluation.md`, and affected plan/tasks links. Mark the
  earlier UX plan as historical with a successor link. Gate: no blanket
  rejection suppression requirement remains in the adopted baseline.
- [x] CS-T02 Review portrait, landscape, and large-text state sketches plus
  Read/Solve/Review transition table. Gate: single-tap entry, visible controls,
  failure continuation, disclosure, exposure provenance, and book/cycle labels
  have explicit accepted behavior before widget implementation.

## History and recovery foundations

- [x] CS-T03 Add interaction version 2 rejection identity and reader/review
  cursor/exposure types in puzzle presentation/application models and local
  storage adapters (`casual_training_repository.dart`, interaction repository
  implementation, existing presentation settings). Gate: version 1 conversion
  preserves history; unknown versions fail safely; no PGN/score rewrite.
- [x] CS-T04 Replace blanket suppression in `puzzle_solver_controller.dart`
  with attempt/path/UCI deduplication. Update
  `test/unit/features/puzzle_solver/puzzle_ux_flow_test.dart` and related
  controller/persistence tests. Gate: A/B/A/C/B, different position,
  promotions, wrong predictions, restart, retry, and failed saves comply.

## Continuous shell and controls

- [x] CS-T05 Add block-scoped flow ownership to `lib/app/navigation.dart`
  and embed reading/solving/review through `library_puzzle_practice.dart` and
  `game_reader_page.dart`. Gate: no extra solve/review push; lifecycle,
  Back/Next/Previous persistence, unfinished restore, terminal review restore,
  answer exposure, and fresh retry identity preserved.
- [x] CS-T06 Add indexed context projection and book-default settings. Modify
  relevant app header and `puzzle_header.dart`. Gate: book/section/neutral block
  identity visible; Casual practice subordinate; no answer-bearing title/theme
  in concealed states; unset defaults Read and saved defaults retained.
- [x] CS-T07 Move essential controls outside detail scrolling using
  `study_layout.dart`, `puzzle_solving_view.dart`, and `puzzle_controls.dart`.
  Gate: 360 × 640, 412 × 915, 640 × 360, text scale 2.0, long history/notes,
  busy/error state and 48 × 48 targets satisfy US2; no duplicate shell controls.

## Rejection and review

- [x] CS-T08 Inspect pinned chessground support, then implement rejection
  cue/hold/return in `puzzle_board.dart` and controller/presentation coordination.
  Gate: fake-time rendering verifies visible attempted move, locked input,
  accepted rollback, reduced motion, save failure, background and disposal;
  accepted opponent delay/prediction semantics remain covered.
- [x] CS-T09 Replace detached review dropdowns with contextual expandable
  branches in `puzzle_solution_review_view.dart` and shared notation widgets.
  Gate: actual chess move numbers, nested alternatives, selected comments,
  reached path/orientation, Your tries, and Return to played line work without
  exposing a tree to active solving.
- [x] CS-T10 Wire persistent Next block/Try again and source-order continuation
  in book flow; integrate shared controls with
  `active_session_page.dart` using cycle-owned labels/order. Gate: mixed content
  opens correctly, no forced solve override, final block says Back to book,
  cycle finishing/order/scoring/timing remain valid.

## Acceptance

- [x] CS-T11 Update targeted widget/unit/integration suites, including
  `library_puzzle_navigation_test.dart`, review/phone layout tests, and
  `puzzle_session_ux_integration_test.dart`. Run static analysis and relevant
  checks after implementation. Gate: complete US1–US5 evidence and no
  outstanding persistence/concealment regression.
- [ ] CS-T12 Perform physical-device review with the original study material;
  record screenshots, rejection timing, section availability and mixed-block
  flow. Gate: user can read → solve/fail → review → next non-puzzle block with
  controls visible and no confusion about result or position. Record any
  timing/layout adjustments and recheck their affected acceptance scenarios.
