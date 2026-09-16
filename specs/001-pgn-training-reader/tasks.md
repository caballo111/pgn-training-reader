# Tasks: PGN Training Reader

**Feature**: `001-pgn-training-reader`  
**Branch**: `001-pgn-training-reader`  
**Plan**: `specs/001-pgn-training-reader/plan.md`  
**Spec**: `specs/001-pgn-training-reader/spec.md`  
**Constitution**: `.specify/memory/constitution.md`

## Purpose

This task list is intentionally decomposed into small, explicit units that can be assigned to compact coding models such as Luna, Flash-class models, or Qwen 27B-class models. Each task should be completable with limited repository context and should produce a narrow, verifiable change.

## Execution Rules for Coding Agents

For every task:

1. Read `.specify/memory/constitution.md`.
2. Read `specs/001-pgn-training-reader/spec.md` and `specs/001-pgn-training-reader/plan.md`.
3. Read only the files listed in the task plus directly referenced types.
4. Do not add dependencies unless the task explicitly permits it.
5. Do not refactor unrelated code.
6. Do not implement deferred features.
7. Add or update tests in the same task when requested.
8. Run the task's validation commands before finishing.
9. Report changed files, commands run, and unresolved issues.
10. Stop if a required file or decision is missing. Do not invent architecture.

## Task Format

- `[P]` means the task may run in parallel with other `[P]` tasks in the same phase when they touch different files.
- `[US#]` associates the task with a user story.
- Each task names exact or expected file paths.
- A task is complete only when its acceptance checks pass.

## User Stories

- **US1, Import PGN library**: Import a large PGN incrementally and create a searchable local index.
- **US2, Browse and read content**: Browse indexed blocks and read games, instructions, and demonstrations.
- **US3, Solve puzzles**: Solve hidden-solution exercises validated against authored PGN variations.
- **US4, Train in cycles**: Organize exercises into sets and complete cycles across multiple sessions and days.
- **US5, Review progress**: Review transparent accuracy, timing, failures, and cycle comparisons.
- **US6, Preserve and recover data**: Recover from interruption, source changes, migration failures, and app restarts.

---

# Phase 0: Required Specification and Research Gates

> Do not begin application implementation until T001 through T012 are complete.

- [x] T001 Create `specs/001-pgn-training-reader/spec.md` from the accepted feature summary. Include prioritized user stories US1 through US6, acceptance scenarios, functional requirements, edge cases, key entities, and measurable success criteria. Do not include implementation details.
- [x] T002 [P] Create `specs/001-pgn-training-reader/research.md` and document the selected Flutter and Dart versions. Record the exact commands used to verify them and mark the decision date.
- [x] T003 [P] In `research.md`, document compatible pinned versions of `dartchess`, `chessground`, Drift, SQLite support packages, file selection, and path/storage packages. Include license, repository, maintenance status, and platform support for each.
- [x] T004 [P] In `research.md`, document the minimum supported Android API level and the reason for the choice. Include storage-access and dependency constraints.
- [ ] T005 [P] Create a disposable Dart research test under `research/prototypes/dartchess_probe/`. Verify parsing of standard PGN, `SetUp` plus `FEN`, comments, NAGs, one variation, and a nested variation. Record outcomes in `research.md`.
- [ ] T006 [P] Extend the parser probe to test whether unknown `X-` tags are retained and whether PGN export preserves them. Record any preservation adapter required.
- [ ] T007 [P] Create `research/prototypes/pgn_scanner_probe/` with a minimal chunked scanner experiment. Test chunk boundaries inside a tag, brace comment, semicolon comment, move token, and recursive variation. Record findings only; do not copy prototype code into production yet.
- [ ] T008 [P] Create `research/prototypes/android_file_probe/` or a documented manual spike. Verify whether selected Android documents support persistent permission, seek, length, and range reads across at least two document providers available to the team.
- [ ] T009 In `research.md`, choose managed-copy import as the MVP default or justify a different reliable option using T008 results. Document fallback behavior for non-seekable providers.
- [ ] T010 [P] Document the app lifecycle events available for closing active timing segments when the app becomes inactive, detached, or backgrounded. Add the selected lifecycle policy to `research.md`.
- [ ] T011 [P] Define benchmark fixtures and the reference Android test device in `research.md`. Include target PGNs with approximately 10,000 and 100,000 blocks.
- [ ] T012 Review T001 through T011 against the constitution. Add a completed post-research Constitution Check to `plan.md`. Resolve every architecture-changing `NEEDS CLARIFICATION` before continuing.

**Phase 0 checkpoint**: Specification exists, research decisions are recorded, selected dependencies are pinned, and the constitution gate passes.

---

# Phase 1: Project Foundation

- [ ] T013 Initialize the Flutter project in the repository root for Android first. Use the application package identifier defined in `spec.md`; if absent, stop and report the missing decision.
- [ ] T014 Configure the pinned Flutter SDK mechanism selected in T002. Add the version file and brief setup instructions to `README.md`.
- [ ] T015 [P] Add `analysis_options.yaml` with strict analysis based on the selected Flutter lint package. Do not suppress warnings globally.
- [ ] T016 [P] Add `.editorconfig`, update `.gitignore`, and add repository formatting conventions. Preserve existing repository-specific entries.
- [ ] T017 Add only the dependencies approved in T003 to `pubspec.yaml`. Fetch packages and commit the generated lockfile.
- [ ] T018 Create the source directories defined by the plan under `lib/`, `test/`, and `integration_test/`. Add only minimal library marker files where needed.
- [ ] T019 [P] Create `lib/core/errors/app_failure.dart` with a sealed or equivalent typed failure hierarchy for file, PGN, database, validation, and unsupported-content failures.
- [ ] T020 [P] Create `lib/core/time/app_clock.dart` with an injectable abstraction for wall-clock timestamps and monotonic elapsed time. Add a production implementation and fake test implementation.
- [ ] T021 [P] Create `lib/core/logging/app_logger.dart` with redaction-safe structured logging methods. Do not accept raw PGN text, comments, file paths, content URIs, or solution moves as log fields.
- [ ] T022 [P] Create `lib/core/utilities/id_generator.dart` with injectable random ID generation. Add deterministic fake generation for tests.
- [ ] T023 Create a minimal dependency composition root in `lib/app/dependencies.dart`. Construct abstractions only; feature implementation remains empty.
- [ ] T024 Create `lib/app/app.dart`, `lib/app/navigation.dart`, and `lib/main.dart` with a minimal accessible application shell and placeholder library route.
- [ ] T025 [P] Add CI configuration that runs dependency resolution, formatting check, static analysis, unit tests, and integration-test compilation where feasible.
- [ ] T026 Run formatting, static analysis, and tests. Fix foundation failures without adding feature code.

**Phase 1 checkpoint**: The empty app builds, dependencies are pinned, CI is active, and foundational abstractions have tests.

---

# Phase 2: Persistence Foundation

- [ ] T027 Create `lib/data/database/app_database.dart` using Drift. Set schema version to 1 and configure dependency injection rather than a global singleton.
- [ ] T028 [P] Create the `pgn_sources` table with source ID, display name, access mode, managed path or opaque external reference, size, modified value, fingerprint, scanner version, import state, safe checkpoint, created timestamp, and updated timestamp.
- [ ] T029 [P] Create the `pgn_blocks` table with block ID, source ID, start locator, end locator, ordinal, standard indexed headers, content type, exercise ID, section, sequence, theme, difficulty, parse status, and diagnostic summary.
- [ ] T030 [P] Create the `import_jobs` and `import_diagnostics` tables with progress, checkpoint, counts, cancellation state, severity, block locator, diagnostic code, and sanitized message.
- [ ] T031 [P] Create the `training_sets` and `training_set_items` tables. Preserve explicit order and allow Puzzle, Instruction, and Demonstration items.
- [ ] T032 [P] Create the `cycles` and `training_sessions` tables. Include lifecycle status and wall-clock start/end timestamps.
- [ ] T033 [P] Create the `puzzle_attempts`, `attempt_moves`, and `timing_segments` tables. Include active milliseconds, result, failure reason, wrong-move count, hint count, reveal flag, and immutable completion fields.
- [ ] T034 Create Drift relationships, indexes, and uniqueness constraints. Include source plus ordinal uniqueness and a documented exercise-ID conflict strategy.
- [ ] T035 Generate Drift code using the repository's standard command. Do not hand-edit generated files.
- [ ] T036 [P] Add `test/unit/data/database/schema_v1_test.dart` to verify all tables and required indexes are created.
- [ ] T037 [P] Add `test/unit/data/database/transaction_test.dart` proving that attempt finalization and its final timing segment commit atomically.
- [ ] T038 Create `lib/data/database/database_migrator.dart` with explicit version handling and a backup-before-destructive-migration hook. Version 1 still requires tests for fresh creation.
- [ ] T039 Run database generation, formatting, static analysis, and database tests.

**Phase 2 checkpoint**: Schema version 1 exists, generated code is current, and transaction tests pass.

---

# Phase 3: Domain Models and Contracts

- [ ] T040 [P] Create `lib/domain/chess_content/content_type.dart` with Puzzle, Instruction, Demonstration, and Unsupported values plus strict database serialization.
- [ ] T041 [P] Create `lib/domain/chess_content/pgn_source.dart` and its access-mode enum. Keep platform URI classes out of the domain model.
- [ ] T042 [P] Create `lib/domain/chess_content/pgn_block_index.dart` with immutable indexed metadata and parse status.
- [ ] T043 [P] Create `lib/domain/chess_content/move_node.dart` as an immutable tree node supporting SAN, UCI, FEN before/after, comments, NAGs, and ordered children.
- [ ] T044 [P] Create `lib/domain/chess_content/chess_content.dart` for headers, starting position, root move node, comments, result, and content classification.
- [ ] T045 [P] Create `lib/domain/training/training_set.dart` and `training_set_item.dart` with ordered mixed content.
- [ ] T046 [P] Create `lib/domain/training/cycle.dart`, `training_session.dart`, and lifecycle status enums.
- [ ] T047 [P] Create `lib/domain/training/puzzle_attempt.dart`, `attempt_move.dart`, `timing_segment.dart`, outcome enum, and failure-reason enum.
- [ ] T048 [P] Create `lib/domain/training/progress_aggregate.dart` with raw counts and durations. Do not calculate metrics inside widgets.
- [ ] T049 Create `specs/001-pgn-training-reader/data-model.md`. Document identities, fields, invariants, relationships, state transitions, retention, and deletion behavior for the models created in T040 through T048.
- [ ] T050 [P] Create `lib/domain/library/pgn_source_repository.dart` and `pgn_index_repository.dart` interfaces.
- [ ] T051 [P] Create `lib/domain/chess_content/chess_content_repository.dart` for loading one indexed block as parsed content.
- [ ] T052 [P] Create `lib/domain/training/training_repository.dart` for sets, cycles, sessions, attempts, timing segments, and aggregates.
- [ ] T053 [P] Create `lib/domain/library/pgn_import_service.dart` contract with progress stream, cancellation, resume, and diagnostics.
- [ ] T054 [P] Create `lib/domain/training/puzzle_evaluator.dart` contract with initialize, legal destinations, submit move, reveal, and final state.
- [ ] T055 [P] Create `lib/domain/training/training_session_service.dart` contract with start/resume cycle, open/close session, select next item, pause/resume attempt, and finalize attempt.
- [ ] T056 Write the corresponding contract documents under `specs/001-pgn-training-reader/contracts/` using domain language and explicit preconditions, results, and errors.
- [ ] T057 Add equality, serialization-boundary, and state-invariant tests for all Phase 3 domain types.

**Phase 3 checkpoint**: Domain code has no Flutter widget, Drift, Android, or Stockfish dependency.

---

# Phase 4: File Access and Managed Import

- [ ] T058 [P] Create `lib/data/file_access/file_source.dart` with open-read-stream, copy-to-managed-storage, length, fingerprint input, and range-read operations.
- [ ] T059 [P] Create `lib/data/file_access/file_source_picker.dart` as a platform-neutral selection contract returning an opaque source reference and display metadata.
- [ ] T060 Implement the Android/Flutter file-picker adapter selected in research. Request only required permissions and return no raw platform object to the domain layer.
- [ ] T061 Implement `lib/data/file_access/managed_file_source.dart` for application-controlled PGN copies with reliable range reads.
- [ ] T062 Implement `lib/data/file_access/source_fingerprint.dart` using size, available modified timestamp, and sampled bytes. Document collision limitations in code comments.
- [ ] T063 [P] Add tests for copying, cancellation, insufficient-space failure mapping, range reads, and fingerprint changes.
- [ ] T064 Create `lib/data/repositories/drift_pgn_source_repository.dart` implementing source creation, state updates, relink metadata, and revision invalidation.
- [ ] T065 Add repository tests using a temporary directory and in-memory Drift database.

**Phase 4 checkpoint**: A selected PGN can be copied to managed storage, fingerprinted, reopened, and read by byte range.

---

# Phase 5: Incremental PGN Scanner and Indexer

- [ ] T066 Create `lib/data/pgn/scanner/pgn_scanner_state.dart` with explicit state for tag strings, brace comments, semicolon comments, variation depth, line boundaries, and candidate block boundaries.
- [ ] T067 Implement `lib/data/pgn/scanner/pgn_boundary_scanner.dart` as a chunk-consumer that emits complete byte ranges and preserves state between chunks.
- [ ] T068 [P] Add scanner fixture `test/fixtures/pgn/simple_games.pgn` containing two conventional games.
- [ ] T069 [P] Add scanner fixture `test/fixtures/pgn/chunk_boundaries.pgn` containing tags, escaped quotes, brace comments, semicolon comments, and nested variations positioned at tested chunk boundaries.
- [ ] T070 [P] Add scanner fixture `test/fixtures/pgn/malformed_neighbors.pgn` with a malformed block between two valid blocks.
- [ ] T071 Add scanner tests using chunk sizes 1, 2, 7, 64, and 4096 bytes. Assert identical emitted block ranges for every size.
- [ ] T072 Add scanner tests for cancellation and safe checkpoint emission. A checkpoint must never point inside an unresolved candidate block.
- [ ] T073 Create `lib/data/pgn/pgn_header_reader.dart` that extracts tag pairs from one block without parsing the full move tree.
- [ ] T074 Create `lib/data/pgn/content_classifier.dart`. Use valid `X-ContentType` as authoritative, preserve unknown values as Unsupported, and return an explicit inferred flag when fallback rules are used.
- [ ] T075 Create `lib/data/pgn/exercise_identity.dart` implementing the identity priority from the plan. Detect duplicates; never silently merge.
- [ ] T076 Implement `lib/data/pgn/pgn_indexer.dart` to stream a managed source, emit ranges, read headers, classify blocks, batch database writes, emit progress, and persist safe checkpoints.
- [ ] T077 Implement cancellation and resume in the indexer. Resuming must not duplicate committed source-plus-ordinal rows.
- [ ] T078 Implement malformed-block diagnostics and safe continuation when the scanner can establish the next boundary.
- [ ] T079 Create `lib/data/repositories/drift_pgn_index_repository.dart` with paginated queries and indexed filters for player, event, result, content type, section, theme, and difficulty.
- [ ] T080 Add an integration test importing at least 100 fixture blocks and asserting exact count, stable order, correct locators, classifications, and no duplicates after resume.
- [ ] T081 Add a memory benchmark test or executable showing that scanner memory does not grow proportionally with total file size. Document how to run it in `quickstart.md`.

**Phase 5 checkpoint**: Large PGNs can be indexed incrementally with progress, cancellation, diagnostics, and safe resume.

---

# Phase 6: Import User Interface

- [ ] T082 [US1] Create `lib/features/import_library/application/import_controller.dart` with idle, selecting, copying, indexing, cancelled, failed, and completed states.
- [ ] T083 [P] [US1] Create an accessible file-selection view in `lib/features/import_library/presentation/import_page.dart`.
- [ ] T084 [P] [US1] Create progress widgets showing current phase, bytes processed when known, blocks indexed, diagnostics count, and cancellability.
- [ ] T085 [US1] Wire selection, managed copy, indexing, cancellation, and completion through the import controller.
- [ ] T086 [US1] Add clear error states for unsupported file access, insufficient storage, malformed content, cancellation, and database failure. State what data was preserved and what action is available.
- [ ] T087 [US1] Add widget tests for every import-controller state. Do not use a real filesystem in widget tests.
- [ ] T088 [US1] Add an integration test for select fixture, import, cancel, resume, and completion.

**User Story 1 checkpoint**: A user can import a PGN without freezing the app, monitor progress, cancel safely, and resume.

---

# Phase 7: Browse Library and Open Content

- [ ] T089 [P] [US2] Create `lib/features/browse_library/application/library_query.dart` with paging, search text, sort, and supported filters.
- [ ] T090 [US2] Create `library_controller.dart` that requests one database page at a time and cancels stale searches.
- [ ] T091 [P] [US2] Create `library_page.dart` with lazy list rendering, empty state, loading state, failure state, and import action.
- [ ] T092 [P] [US2] Create filter controls for content type, section, theme, difficulty, result, and source. Ensure filters work with keyboard and screen reader navigation.
- [ ] T093 [US2] Implement retrieval of the exact selected byte range from managed storage.
- [ ] T094 [US2] Create `lib/data/pgn/dartchess_content_parser.dart` adapter that parses one complete block into the domain `ChessContent` and immutable `MoveNode` tree.
- [ ] T095 [US2] Preserve standard headers, custom headers, comments, NAGs, nested variations, starting FEN, side to move, and result in the parsed domain object.
- [ ] T096 [US2] Return typed failures for malformed PGN and unsupported variants. Do not reinterpret unsupported variants as standard chess.
- [ ] T097 [US2] Implement `drift_chess_content_repository.dart` using the source repository, range reader, and parser adapter.
- [ ] T098 [US2] Add tests proving stored locators return the exact original bytes for the first, middle, and last block.
- [ ] T099 [US2] Add parser-adapter tests for normal game, FEN-start game, comments, NAGs, one variation, nested variations, and unknown tags.

**User Story 2A checkpoint**: User can browse a paginated library and load one correctly parsed block on demand.

---

# Phase 8: Board and Reader Modes

- [ ] T100 [P] [US2] Create `lib/shared/chessboard/chessboard_adapter.dart` that maps domain position, side to move, legal destinations, last move, and orientation into `chessground` inputs.
- [ ] T101 [P] [US2] Create reusable reader navigation state supporting first, previous, next, last, select variation, and return to parent line.
- [ ] T102 [US2] Create `game_reader_controller.dart` that derives the current position from the parsed move tree using `dartchess` and never trusts stored display text for side to move.
- [ ] T103 [P] [US2] Create `reader_board.dart` with board coordinates, orientation control, last-move highlight, and accessible side-to-move label.
- [ ] T104 [P] [US2] Create `move_tree_view.dart` for visible moves, variations, comments, and NAG display in normal reader mode.
- [ ] T105 [P] [US2] Create `instruction_view.dart` for Instruction content. Ensure opening it does not create or modify a puzzle attempt.
- [ ] T106 [P] [US2] Create `demonstration_view.dart` for Demonstration content with board and annotated navigation.
- [ ] T107 [US2] Create `game_reader_page.dart` that selects the correct mode from `ContentType`.
- [ ] T108 [US2] Add widget tests for side-to-move display, navigation, orientation, comments, and variation selection.
- [ ] T109 [US2] Add tests proving Instruction and Demonstration content does not affect training scores.

**User Story 2B checkpoint**: Games, instructions, and demonstrations render correctly and remain non-scored.

---

# Phase 9: Puzzle Evaluation Domain

- [ ] T110 [US3] Create `lib/domain/training/puzzle_state.dart` with not-started, active, failed-review, passed-review, revealed-review, skipped, timed-out, and abandoned states.
- [ ] T111 [US3] Implement `lib/domain/training/authored_line_puzzle_evaluator.dart` using `dartchess` for legality and the current `MoveNode` children for authored acceptance.
- [ ] T112 [US3] Distinguish illegal interaction from a legal move that is absent from authored accepted children. Illegal interaction must not automatically count as a wrong move.
- [ ] T113 [US3] Accept every explicitly authored child variation at the current node. Preserve child order but do not assume only the first child is valid.
- [ ] T114 [US3] Mark the attempt passed only when an accepted terminal solution node is reached without a prior finalized failure or reveal.
- [ ] T115 [US3] Implement the default wrong-move policy: first legal authored mismatch finalizes `wrong_move`; the user may continue only in review mode.
- [ ] T116 [US3] Implement reveal, skip, timeout, and abandon transitions with exact failure reasons.
- [ ] T117 [US3] Reject invalid state transitions, including converting a finalized failed attempt into passed.
- [ ] T118 [US3] Add table-driven evaluator tests for correct main line, correct alternate line, illegal move, wrong legal move, reveal, skip, timeout, abandon, and attempt-after-finalization.
- [ ] T119 [US3] Add FEN-start tests for both White to move and Black to move.

**User Story 3A checkpoint**: Puzzle-result decisions are deterministic and fully tested without widgets or database access.

---

# Phase 10: Puzzle Presentation and Solution Hiding

- [ ] T120 [US3] Create `lib/features/puzzle_solver/application/puzzle_presentation_state.dart`. It must not expose future moves, future positions, solution comments, solution NAGs, or hidden variation labels while active.
- [ ] T121 [US3] Create `puzzle_solver_controller.dart` that maps user board moves to the evaluator and persists attempt state through the training repository.
- [ ] T122 [P] [US3] Create `puzzle_header.dart` showing exercise progress and an accessible “White to move” or “Black to move” label derived from the active position.
- [ ] T123 [P] [US3] Create `puzzle_board.dart` with legal interactions only, orientation preference, and no future-move navigation.
- [ ] T124 [P] [US3] Create puzzle controls for Pause, Show solution, Skip, and permitted retry/review actions. Destructive result changes must be clear.
- [ ] T125 [US3] Create the solving view without a visible solution move list. Display only user-played accepted moves while the attempt is active.
- [ ] T126 [US3] Create review mode that reveals the authored solution tree, comments, and navigation only after pass, fail, skip, timeout, abandon, or explicit reveal.
- [ ] T127 [US3] Ensure player names, titles, comments, and metadata identified by the spec as potential hints are hidden or configurable in puzzle mode.
- [ ] T128 [US3] Add widget tests that search visible text and the Flutter semantics tree for hidden SAN, UCI, comments, and variation labels before reveal.
- [ ] T129 [US3] Add tests proving review mode reveals the solution after each final outcome.
- [ ] T130 [US3] Add golden tests for phone puzzle layout with White to move, Black to move, large text scale, and failed-review mode.

**User Story 3B checkpoint**: A user can solve a puzzle, and automated tests prove the solution is absent from visible and accessibility output before reveal.

---

# Phase 11: Training Sets and Ordering

- [ ] T131 [US4] Implement Drift repository methods to create, rename, list, and archive training sets.
- [ ] T132 [US4] Implement adding indexed blocks to a set with stable exercise identity and explicit order.
- [ ] T133 [US4] Implement reorder and removal operations transactionally. Removing an item must not delete source content or historical attempts.
- [ ] T134 [P] [US4] Create `training_set_editor_controller.dart` with add, remove, reorder, save, and validation states.
- [ ] T135 [P] [US4] Create a set editor page that supports Puzzle, Instruction, and Demonstration items and clearly marks which items are scored.
- [ ] T136 [US4] Validate that duplicate item behavior follows `spec.md`. If the spec is silent, stop this task and report the missing rule.
- [ ] T137 [US4] Add repository and widget tests for mixed-content ordering and archive behavior.

**User Story 4A checkpoint**: User can create an ordered mixed-content training set without duplicating source PGN data.

---

# Phase 12: Cycles, Sessions, Multi-Day Resume, and Timing

- [ ] T138 [US4] Implement `lib/domain/training/active_time_tracker.dart` using `AppClock`. Support start segment, pause, resume, close segment, accumulated duration, and recovery.
- [ ] T139 [US4] Add tests proving wall-clock jumps do not affect monotonic active duration while the process is running.
- [ ] T140 [US4] Implement `training_session_service_impl.dart` to start a cycle and open its first session.
- [ ] T141 [US4] Implement selection of the next pending set item while preserving Instruction and Demonstration items in order and excluding them from scored-attempt counts.
- [ ] T142 [US4] Implement session pause and close. Closing must transactionally close the active timing segment.
- [ ] T143 [US4] Implement resume of an incomplete cycle by opening a new session and selecting the unfinished or next item according to the spec.
- [ ] T144 [US4] Implement explicit multi-day support. Store each session's wall-clock day while aggregating only active durations.
- [ ] T145 [US4] Implement lifecycle observer integration that pauses active timing when the application becomes inactive/backgrounded and starts a new segment only after explicit or policy-defined resume.
- [ ] T146 [US4] Implement process-recreation recovery using the last persisted lifecycle boundary. Unknown time after the last safe boundary must not be counted.
- [ ] T147 [US4] Finalize completed attempts append-only. Retrying creates a new attempt linked to the same cycle and exercise.
- [ ] T148 [US4] Complete a cycle only when every required scored item has a finalized outcome and all required ordered content has been traversed according to the spec.
- [ ] T149 [P] [US4] Create `active_session_controller.dart` with loading, active item, paused, completed, and recoverable-failure states.
- [ ] T150 [P] [US4] Create `active_session_page.dart` showing cycle progress, current session active time, cycle active time, and current content.
- [ ] T151 [US4] Add integration test: begin on simulated Monday, solve some puzzles, pause, resume on simulated Tuesday, finish, and assert idle overnight time is excluded.
- [ ] T152 [US4] Add integration test for process termination during an active puzzle and safe recovery without inflated duration.
- [ ] T153 [US4] Add integration test proving retries create new attempts and do not overwrite the first result.

**User Story 4B checkpoint**: One cycle can safely span multiple sessions and days with accurate active time and append-only history.

---

# Phase 13: Scoring and Progress Reports

- [ ] T154 [US5] Create `lib/domain/training/progress_calculator.dart` as the single implementation of accuracy, total active time, average, median, outcome counts, and cycle comparison.
- [ ] T155 [US5] Define denominator behavior for abandoned attempts, skips, and timeouts exactly as stated in `spec.md`. If the spec is ambiguous, stop and report it.
- [ ] T156 [US5] Add fixed-fixture unit tests for zero attempts, one attempt, mixed outcomes, even-count median, odd-count median, retries, and multi-session cycle totals.
- [ ] T157 [US5] Implement repository queries for cycle summary, session summary, exercise history, theme summary, and difficulty summary.
- [ ] T158 [P] [US5] Create `progress_report_controller.dart` with cycle selection and comparison state.
- [ ] T159 [P] [US5] Create a cycle summary view with attempted, passed, failed, accuracy, total active time, average, median, and separate outcome counts.
- [ ] T160 [P] [US5] Create a daily sessions view listing each session's date, active duration, attempted count, and outcome counts.
- [ ] T161 [P] [US5] Create a cycle comparison view showing transparent deltas in accuracy and active time. Do not add composite scores.
- [ ] T162 [US5] Create theme and difficulty summaries only when metadata exists. Show an explicit unavailable state otherwise.
- [ ] T163 [US5] Add widget tests proving all displayed metrics match the tested calculator output.

**User Story 5 checkpoint**: Users can understand results and improvement without opaque scoring.

---

# Phase 14: Source Change Detection and Recovery

- [ ] T164 [US6] Check source fingerprint before opening locators from external or managed sources.
- [ ] T165 [US6] When a source is missing, preserve its index and history, disable block opening, and expose relink or re-import actions.
- [ ] T166 [US6] When a source fingerprint changes, block offset reads until re-index completes. Do not silently read stale offsets.
- [ ] T167 [US6] Implement re-index with stable exercise-ID reconciliation. Preserve attempts linked by unique `X-ExerciseId`; report unresolved fallback-identity changes.
- [ ] T168 [US6] Add duplicate exercise-ID conflict UI and diagnostics. Do not silently merge two exercises.
- [ ] T169 [US6] Add integration tests for missing source, changed source, successful relink, stable-ID history preservation, and unresolved identity conflicts.

**User Story 6A checkpoint**: Source problems degrade safely without deleting training history.

---

# Phase 15: Backup and Export of Training History

- [ ] T170 [US6] Define a versioned, documented training-history export format in `specs/001-pgn-training-reader/contracts/training-history-export.md`. Exclude raw PGN content unless explicitly selected.
- [ ] T171 [US6] Implement export of sets, set items, cycles, sessions, attempts, outcomes, timing segments, and stable exercise references.
- [ ] T172 [US6] Redact internal managed paths, content URIs, and diagnostic details from export.
- [ ] T173 [US6] Implement import validation for the same schema behind a preview step. Do not write data before validation succeeds.
- [ ] T174 [US6] Implement transactional restore with duplicate and source-reference reporting.
- [ ] T175 [US6] Add round-trip tests and invalid-version tests.
- [ ] T176 [US6] Create minimal export and restore UI with deliberate confirmation for destructive conflict policies.

**User Story 6B checkpoint**: Training history can be exported and restored without exposing device-specific private paths.

---

# Phase 16: Accessibility, Performance, and Hardening

- [ ] T177 [P] Audit every screen for labels, focus order, large text, touch-target size, and non-color status indicators. Record results in `specs/001-pgn-training-reader/accessibility-review.md`.
- [ ] T178 [P] Add semantics tests for side to move, timer, outcome, import progress, and puzzle controls.
- [ ] T179 [P] Add a static production-log audit test or lint check that prevents calls containing raw PGN, comments, SAN solution lines, paths, or URIs.
- [ ] T180 Add malformed-input limits for tag length, comment size, variation depth, block size, and diagnostic count. Values must come from `spec.md` or documented research.
- [ ] T181 Add performance instrumentation for import throughput, query latency, selected-block load latency, and peak-memory sampling.
- [ ] T182 Run the 10,000-block benchmark and record results in `specs/001-pgn-training-reader/performance-results.md`.
- [ ] T183 Run the 100,000-block benchmark and record results. If a target fails, create a focused remediation task rather than broad optimization.
- [ ] T184 Optimize only measured bottlenecks. Each optimization must include a before/after benchmark and regression test where practical.
- [ ] T185 Test app behavior with low storage, cancelled import, corrupted database copy, interrupted migration, and process death.
- [ ] T186 Add a dependency and license inventory to `THIRD_PARTY_NOTICES.md` or the repository's chosen notice format.
- [ ] T187 Complete the distribution-license review required by the constitution and record the application licensing decision.

**Phase 16 checkpoint**: Accessibility, performance, resilience, and license obligations are documented and tested.

---

# Phase 17: Documentation and Release Readiness

- [ ] T188 Create `specs/001-pgn-training-reader/quickstart.md` with pinned setup, code generation, test, fixture import, benchmark, and Android integration-test commands.
- [ ] T189 Update `README.md` with project purpose, supported content types, custom PGN tags, local-first behavior, and current limitations.
- [ ] T190 Create `docs/custom-pgn-tags.md` documenting `X-ContentType`, `X-ExerciseId`, `X-Section`, `X-Sequence`, `X-Theme`, `X-Difficulty`, and every implemented custom tag, including examples.
- [ ] T191 Create `docs/training-model.md` explaining Collection, Set, Cycle, Session, Attempt, active time, and multi-day behavior.
- [ ] T192 Create `docs/privacy-and-data.md` explaining where PGNs, indexes, attempts, diagnostics, and exports are stored.
- [ ] T193 Add sanitized sample PGNs for Puzzle, Instruction, Demonstration, FEN-start exercise, and alternative accepted variations.
- [ ] T194 Run full formatting, static analysis, unit tests, widget tests, integration tests, database generation checks, and benchmark smoke tests.
- [ ] T195 Perform a final Constitution Check and record it in `plan.md` or a release review artifact.
- [ ] T196 Verify every functional requirement and success criterion in `spec.md`. Link each one to passing tests or documented manual validation.
- [ ] T197 Prepare the MVP release notes with implemented features, known limitations, deferred analysis features, data compatibility, and upgrade notes.

---

# Dependencies and Recommended Execution Order

```text
Phase 0 specification and research
  -> Phase 1 foundation
  -> Phase 2 persistence
  -> Phase 3 domain/contracts
  -> Phase 4 file access
  -> Phase 5 scanner/indexer
  -> Phase 6 import UI
  -> Phase 7 library/parser
  -> Phase 8 reader
  -> Phase 9 puzzle domain
  -> Phase 10 puzzle UI
  -> Phase 11 training sets
  -> Phase 12 sessions/timing
  -> Phase 13 reporting
  -> Phase 14 recovery
  -> Phase 15 backup/export
  -> Phase 16 hardening
  -> Phase 17 release readiness
```

## Parallel Work Guidance

After Phase 3 is stable:

- File-access work can proceed separately from pure puzzle-evaluator work.
- Reader widgets can proceed after the parser contract is stable using fixture domain objects.
- Reporting widgets can proceed after `ProgressAggregate` is stable using fake repositories.
- Accessibility tests can be added alongside each screen rather than postponed.
- Documentation tasks may proceed once their corresponding behavior is stable.

Do not parallelize tasks that modify the same Drift schema, generated database files, navigation file, or dependency composition root.

---

# Small-Model Handoff Template

Use this template when assigning one task to a coding model:

```text
Implement task T### only.

Required reading:
- .specify/memory/constitution.md
- specs/001-pgn-training-reader/spec.md
- specs/001-pgn-training-reader/plan.md
- specs/001-pgn-training-reader/tasks.md, task T### only

Allowed files:
- <list exact files from the task>
- directly generated files, only if the task requires generation

Requirements:
- Do not add dependencies.
- Do not refactor unrelated code.
- Add the tests required by T###.
- Run formatting, static analysis, and the narrowest relevant test command.

Return:
1. Summary of implementation.
2. Files changed.
3. Commands and test results.
4. Any blocker or ambiguity. Do not guess missing requirements.
```

# Definition of Done

The feature is complete when:

- All applicable tasks are checked.
- User stories US1 through US6 pass their independent checkpoints.
- The full test suite passes.
- Performance targets are measured and met or explicitly accepted through governance.
- Solution leakage tests pass for visible and accessibility output.
- Multi-day timing tests prove idle intervals are excluded.
- Attempt history remains append-only.
- Source changes cannot cause silent stale-offset reads.
- Training history can be backed up and restored.
- Dependency licenses and distribution obligations are documented.
- The final Constitution Check passes.
