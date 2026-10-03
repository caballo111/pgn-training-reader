# Implementation and acceptance evidence

The test/golden evidence below records the initial implementation. The later
[space and semantics refinement](space-refinement.md) has clean static analysis;
tests and visual snapshots have not been rerun for that UI revision.

Date: 2026-10-02. Implementation authorized by the user, with Luna agents
assigned to interaction history, solving/layout, and review presentation.

## Delivered behavior

- Book reading, solving, and review share the existing block route. Solve
  starts directly; preferences and completion policy are in Book settings.
- The book header retains book, section when present, and block number.
  Casual practice is subordinate. Concealed solving uses safe context.
- Essential actions remain outside scrolling notes/history. Portrait favors
  board space; short landscape uses adjacent board and detail/action panels.
  Error recovery has a compact Retry action and accessible message details.
- Next block follows source order, including explanatory content. Saved book
  Read/Solve preferences remain separate from the current Solve action.
- Cycle solving shares the controls, feedback, and review improvements while
  retaining cycle ordering, score, timing, and Finish cycle behavior.
- Distinct wrong submissions persist by attempt, authored position, and UCI.
  Repeats are ignored across the entire history; promotion choices and wrong
  predictions remain distinct. First-error score and timing stay immutable.
- Legal rejected moves hold for 450 ms and return over 200 ms. Input is locked
  during the cue. Reduced motion removes the return animation; background,
  disposal, and controller replacement clear transient display state.
- Review alternatives appear beside their branching move, with actual move
  numbers, annotations, selected position, and Return to played line.
- Reader cursor/scroll/orientation, review cursor/orientation, and answer
  exposure persist locally. Retry creates a fresh attempt. Save failures
  retain visible state and prevent leaving/advancing until saved.

## Automated evidence

| Area | Evidence |
| --- | --- |
| History, migration, score integrity | `puzzle_solver_controller_test.dart`, `puzzle_ux_flow_test.dart`: interleaved repeats, restored version 2, version 1 migration, unsupported versions, separate positions, promotions, predictions, failed cursor writes. |
| Same route and mixed source continuation | `library_puzzle_navigation_test.dart`: direct Solve, stable route/context, distinct rejects, immutable score, retry identity, pause/restore, preferences, next instructional block, reclassification cursor saving. |
| Complete screen geometry | `continuous_study_flow_test.dart`: 360 × 640, 412 × 915, 640 × 360 at text scales 1 and 2; pinned solving/review actions; failed exposure saves at both phone orientations with 2× text. |
| Cycle integrity and recovery | `active_session_page_test.dart`, `puzzle_session_ux_integration_test.dart`, `training_session_integration_test.dart`: same size matrix, pause/resume/time, persisted cursor failures blocking Next/Back, retry, cycle continuation. |
| Review branches and notes | `puzzle_solution_review_view_test.dart`: six cases including nested alternatives, restored position/orientation, large text/long notes, compact landscape actions. |
| Rejection display | `puzzle_solving_view_test.dart`: accepted FEN remains durable during cue, 450/200 ms timing, reduced motion, background cancellation, disposal, concealed answers and pause. |
| Presentation store | `study_presentation_store_test.dart`: local round-trip and unsupported versions. |
| Visual regression | Four updated phone golden images: active white, active black, large text, failed review. Generated images inspected; golden suite passes. |

Final checks:

```sh
flutter analyze lib test
flutter test
git diff --check
```

Application and test analysis is clean. The final full test run has 402 passed
tests and one failure. All feature checks pass; the remaining failure is the existing production logging audit for
the unchanged `debugPrint` in `lib/main.dart`.

Unscoped `flutter analyze` also examines the separate
`research/prototypes/dartchess_probe` package, whose unavailable package
resolution produces existing errors. This is outside application/test
analysis; no changes were made to that prototype.

During concurrent library/import edits, an isolated checkout of the baseline
plus this feature was used to validate controller, reader, and integration
behavior. Final checks ran against the shared workspace after those compile
blockers cleared. Host benchmark results do not establish Android performance.

## Golden refresh after layout refinements — 2026-10-02

Regenerated all four puzzle phone reference images for the current shared
board/footer controls and review layout. The focused suite passed all five
tests with `--update-goldens`, then passed all five again without that flag.
The existing raster tolerance was retained. Large-text and failed-review
images were visually inspected; obsolete generated failure images were
removed. This run does not replace the earlier full-suite baseline or physical
device acceptance.

```sh
flutter test --no-pub --update-goldens test/widget/features/puzzle_solver/puzzle_phone_golden_test.dart
flutter test --no-pub test/widget/features/puzzle_solver/puzzle_phone_golden_test.dart
```

## Pending physical acceptance (CS-T12)

No physical phone or original reported study material was available here.
Use the user's phone and book to confirm thumb reach, section availability,
perceived rejection timing, long notes/nested branches, and the sequence
read → solve/fail → review → next non-puzzle block. This remains explicitly
unchecked in tasks.md. Automated geometry and golden checks do not establish
physical-device usability acceptance.
