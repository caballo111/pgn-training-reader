# Implementation Plan: PGN Training Reader

**Branch**: `001-pgn-training-reader`  
**Date**: 2026-09-15  
**Spec**: `specs/001-pgn-training-reader/spec.md`  
**Constitution**: `.specify/memory/constitution.md`  
**Status**: Draft

## Summary

Build an offline-first Flutter application that imports and incrementally indexes large PGN files, presents individual games and instructional blocks, and runs repeatable puzzle-training cycles inspired by the Woodpecker Method. Puzzle solutions remain in standards-compliant PGN move trees but are hidden by the user interface until the attempt ends or the user requests the solution.

The application will use Lichess-maintained Flutter chess components where practical: `dartchess` for PGN and chess rules and `chessground` for board interaction. SQLite, accessed through Drift, will store the derived PGN index, training sets, sessions, attempts, timing, and progress. The source PGN remains canonical for chess content.

## Technical Context

**Language/Version**: Dart 3.x with the current stable Flutter SDK selected and pinned at project initialization  
**Primary Dependencies**: Flutter, `dartchess`, `chessground`, Drift, SQLite, Android document APIs through a maintained Flutter plugin or a narrow platform channel  
**Storage**: User-selected PGN files plus a local versioned SQLite database  
**Testing**: Flutter test, Dart unit tests, integration tests, PGN fixture tests, database migration tests  
**Target Platform**: Android first; architecture must not prevent a future iOS or desktop build  
**Project Type**: Offline-first mobile application  
**Performance Goals**:

- Keep the interface responsive during import and indexing.
- Never load a complete large PGN into memory solely to enumerate games.
- Render board interaction at a perceived 60 fps on supported devices.
- Open an already indexed individual game in under 500 ms at p95 on the reference Android device.
- Load game-list pages in under 250 ms at p95 for a database containing 100,000 indexed entries.
- Update the active timer without rebuilding the complete board or move tree.

**Constraints**:

- Core reading and training must work offline.
- Paused, suspended, closed, and between-day time must not count as active solving time.
- Imported PGN content must not be silently rewritten.
- Solutions and solution comments must not leak before completion, failure, skip, or reveal.
- Android content URIs may not behave like normal seekable file paths.
- Training state and attempt history must survive process termination.
- Reciprocal open-source licenses must be reviewed before distribution.

**Initial Scale/Scope**:

- One local user profile.
- Multiple imported PGN sources.
- At least 100,000 indexed blocks per library database.
- Puzzle, Instruction, and Demonstration content types.
- One active cycle per training set in the MVP.
- No cloud account, synchronization, remote engine, or backend in the MVP.

## Assumptions

1. Flutter is the selected implementation platform, with Android as the first release target.
2. The accepted project summary is the requirements baseline until it is transcribed into `spec.md`.
3. PGN files use UTF-8 where possible; encoding failures are reported and do not silently corrupt content.
4. Puzzle correctness is based on authored PGN main lines and variations, not engine equivalence.
5. A training cycle may be split into any number of sessions across multiple days.
6. Stockfish analysis is deferred, but domain boundaries must allow it later.
7. Authentication, multi-user synchronization, leaderboards, and social functionality are out of scope.

## Constitution Check

### Gate Before Phase 0

- **PGN Fidelity and Portability**: PASS. Source files remain canonical; solution concealment is presentation-only.
- **Explicit Content Semantics**: PASS. The index recognizes `Puzzle`, `Instruction`, and `Demonstration`, with `X-ContentType` authoritative.
- **Large-File and Offline-First Operation**: PASS. Import is incremental and creates an on-demand game index.
- **Deterministic Puzzle Integrity**: PASS. Legal moves come from `dartchess`; authored child variations determine correctness.
- **Attempt History and Honest Timing**: PASS. Cycles, sessions, and attempts are separate persisted entities.
- **Simple, Explainable Scoring**: PASS. MVP metrics are counts, accuracy, active time, and error reasons.
- **Separation of Concerns**: PASS. PGN content, training state, presentation, and future engine integration are separate modules.
- **Local Data Ownership and Recoverability**: PASS. No automatic upload; writes are transactional; interrupted imports are recoverable.
- **MVP Simplicity**: PASS. No backend, account system, remote analysis, or generalized plugin system.

### Required Re-check After Phase 1

Confirm that:

- No solution-bearing move or comment is exposed through reader navigation, accessibility labels, logs, previews, or persisted transient UI state.
- File-source handling does not make byte offsets invalid without detection.
- Attempt records remain append-only when puzzles are retried.
- Storage schema separates source content locators from training state.
- All new dependencies have compatible licenses and active maintenance.

## Project Structure

### Planning Artifacts

```text
specs/001-pgn-training-reader/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── pgn-import-contract.md
│   ├── puzzle-evaluation-contract.md
│   └── training-session-contract.md
└── tasks.md
```

`tasks.md` is not produced by this plan. It should be generated in the next Spec Kit phase after the specification and plan are reviewed.

### Flutter Source

```text
lib/
├── app/
│   ├── app.dart
│   ├── navigation.dart
│   └── dependencies.dart
├── core/
│   ├── errors/
│   ├── logging/
│   ├── time/
│   └── utilities/
├── domain/
│   ├── chess_content/
│   ├── library/
│   ├── training/
│   └── analysis/
├── data/
│   ├── database/
│   ├── pgn/
│   ├── repositories/
│   └── file_access/
├── features/
│   ├── import_library/
│   ├── browse_library/
│   ├── game_reader/
│   ├── puzzle_solver/
│   ├── training_sets/
│   ├── active_session/
│   └── progress_report/
└── shared/
    ├── chessboard/
    ├── widgets/
    └── accessibility/

test/
├── unit/
├── integration/
├── fixtures/
│   └── pgn/
└── golden/

integration_test/
└── training_flow_test.dart
```

## Architectural Decisions

### AD-001: Flutter with Android First

Flutter provides one codebase, strong custom rendering, and access to Lichess-oriented Dart chess libraries. Android-specific storage behavior will be isolated behind a file-source interface, allowing later iOS and desktop implementations without changing domain logic.

### AD-002: Source PGN Is Canonical

The application will not normalize and rewrite an imported PGN during indexing. It will store source identity, source revision information, byte locators where valid, indexed headers, inferred metadata, and parse diagnostics. A selected block will be read from the source and parsed on demand.

### AD-003: Two File-Handling Modes

The importer will support an abstraction with two possible implementations:

1. **Managed copy**: Copy the PGN to application-controlled storage. This is the default MVP path because it enables reliable random access and stable offsets.
2. **Index in place**: Retain persistent access to a selected document when the platform and provider support reliable seek or range reads. This is an extension behind the same interface.

If a provider does not support dependable random access, the application must offer or automatically use a managed copy rather than pretending offsets are reliable.

### AD-004: Incremental PGN Boundary Scanner

A byte-oriented scanner will identify PGN block boundaries without fully parsing all games. The scanner must carry state across buffer boundaries and account for:

- Tag sections and movetext.
- Blank-line conventions.
- Brace comments.
- Semicolon comments.
- Recursive annotation variations.
- Quoted tag values.
- Files that omit ideal spacing between games.

Once a candidate block is isolated, only the metadata needed for the index is parsed. Full move-tree parsing occurs when a block is opened or validated as an exercise.

### AD-005: Drift over SQLite

Drift will provide typed queries, transactions, schema migrations, and testable in-memory databases. The database is a derived index plus durable training store. Imported source content and user attempt history have different lifecycle policies even though they share the same physical database.

### AD-006: `dartchess` Owns Chess Rules

The application will not implement legal move generation, SAN, FEN behavior, or PGN move semantics from scratch. Domain adapters will isolate `dartchess` types from persistence and presentation models.

### AD-007: `chessground` Owns Board Interaction

The board layer will display positions and emit user move intentions. It will not determine puzzle correctness. The puzzle domain service validates legal moves and compares them with the current authored solution-tree node.

### AD-008: Monotonic Active-Time Accounting

Attempt timing will use a monotonic clock while the attempt is active. Persisted timing will consist of accumulated active milliseconds plus state-transition timestamps for audit and recovery. Wall-clock timestamps are for history and day grouping, not duration calculation.

On pause, background, process stop, or navigation away, the current active segment is closed transactionally. On resume, a new segment begins. Time between segments is excluded.

### AD-009: Append-Only Attempt Results

Starting an exercise creates an attempt. Completing, failing, revealing, skipping, timing out, or abandoning finalizes that attempt. Retrying creates a new attempt linked to the same exercise and cycle. Finalized attempts are not mutated into a different historical result.

### AD-010: Analysis Is a Future Adapter

The domain will expose positions and move trees without depending on Stockfish. A future analysis service can consume FEN and return engine lines. No engine output will be treated as authored puzzle truth unless a later specification defines an explicit policy.

## Phase 0: Research and Risk Reduction

Produce `research.md` with decisions and evidence for the following topics:

1. Verify the current Flutter, Dart, `dartchess`, and `chessground` compatibility matrix.
2. Review dependency licenses, especially reciprocal-license obligations for board and future engine distribution.
3. Test `dartchess` behavior for:
   - standard PGNs;
   - `SetUp` and `FEN` starts;
   - comments and NAGs;
   - nested variations;
   - malformed PGNs;
   - PGN writing and unknown-tag preservation.
4. Prototype incremental PGN boundary detection with chunk splits inside tags, comments, and movetext.
5. Measure Android document-provider capabilities for seek/range access and persistent permissions.
6. Compare managed-copy storage costs against index-in-place reliability.
7. Confirm lifecycle hooks needed to close active timing segments when the app backgrounds or terminates.
8. Establish the reference Android device and benchmark dataset sizes.
9. Decide whether custom tags are retained verbatim by the selected parser or require a preservation layer.
10. Define the minimum supported Android version based on dependency and storage API constraints.

### Phase 0 Exit Criteria

- No unresolved `NEEDS CLARIFICATION` remains for a decision that changes the architecture.
- A representative large PGN can be incrementally scanned without memory growth proportional to file size.
- A FEN-start puzzle with variations can be parsed and validated.
- Android file-access behavior has a reliable MVP strategy.
- License risks are documented with an explicit distribution recommendation.

## Phase 1: Domain and Interface Design

### 1. Data Model

Produce `data-model.md` describing at least these entities:

- `PgnSource`
- `PgnBlockIndex`
- `ContentClassification`
- `ChessContent`
- `MoveNode`
- `TrainingSet`
- `TrainingSetItem`
- `Cycle`
- `TrainingSession`
- `PuzzleAttempt`
- `AttemptMove`
- `TimingSegment`
- `ProgressAggregate`
- `ImportJob`
- `ImportDiagnostic`

Each entity must define identity, required fields, invariants, relationships, lifecycle, and deletion behavior.

### 2. Contracts

Produce interface contracts for:

#### PGN import

- Open or copy a source.
- Compute source identity and revision fingerprint.
- Incrementally scan blocks.
- Emit progress.
- Persist checkpoints.
- Resume or restart safely.
- Report malformed or unsupported blocks without losing valid neighbors.

#### Puzzle evaluation

- Initialize from a starting position and solution tree.
- Return side to move and legal destinations.
- Accept a user move.
- Classify it as illegal, accepted continuation, completed solution, or authored-solution mismatch.
- Finalize pass/fail according to the selected attempt policy.
- Reveal the solution and record that reveal.

#### Training session

- Start or resume a cycle.
- Open and close sessions across different days.
- Start, pause, resume, and finalize attempts.
- Select the next pending set item.
- Preserve non-scored instruction and demonstration blocks in set order.
- Calculate transparent progress metrics.

### 3. User Flows

Document and prototype these flows:

1. Select PGN, copy/import, show progress, and browse indexed content.
2. Open a normal game and navigate moves and variations.
3. Open an instruction block without affecting score.
4. Start a training set and solve a puzzle with the solution hidden.
5. Submit a correct authored line and reveal annotations afterward.
6. Make a wrong move under the selected retry policy.
7. Press Show Solution and record `revealed`.
8. Pause in the middle of a cycle, close the app, and resume on another day.
9. Complete a cycle and compare it with an earlier cycle.
10. Detect a changed or missing PGN source and guide recovery.

### 4. Quickstart

Produce `quickstart.md` with:

- Development prerequisites.
- Flutter SDK pinning instructions.
- Dependency bootstrap.
- Database generation commands.
- How to run tests.
- How to load fixture PGNs.
- How to run the Android integration test.
- How to verify no solution leakage.

### Phase 1 Exit Criteria

- Domain entities and invariants are documented.
- Contracts can be tested independently from Flutter widgets.
- Wireframes cover phone-first import, reader, puzzle, session, and report screens.
- The Constitution Check is repeated and passes.
- Error and recovery states are designed, not deferred to implementation.

## Delivery Increments

### Increment 1: Project Foundation

- Initialize Flutter project and pin toolchain.
- Configure linting, formatting, test folders, and CI checks.
- Add Drift database and migration framework.
- Add clock, identifier, logging, and repository abstractions.
- Establish PGN fixtures and benchmark harness.

**Demo outcome:** Application starts, database opens, migrations run, and foundational tests pass.

### Increment 2: PGN Import and Index

- Implement managed-copy import.
- Implement incremental boundary scanner.
- Parse and persist block headers and custom content tags.
- Add import progress, cancellation, diagnostics, and restart behavior.
- Detect source revision changes.

**Demo outcome:** A large PGN is imported without full-file memory loading, and indexed blocks appear in a paginated list.

### Increment 3: Library and Reader

- Add search, filters, and indexed list pagination.
- Parse one selected block into a move tree.
- Render starting position, side to move, moves, comments, and variations.
- Support Instruction and Demonstration presentation.
- Preserve unsupported-content warnings.

**Demo outcome:** User can browse and read individual games and non-scored content offline.

### Increment 4: Puzzle Solver

- Enter puzzle mode based on explicit classification.
- Hide solution moves, annotations, and forward navigation.
- Show side to move and board orientation preference.
- Validate legal moves against authored solution-tree children.
- Support multiple accepted PGN variations.
- Add retry, skip, and reveal behavior.

**Demo outcome:** User can solve a FEN-start or played-position puzzle without accidental solution exposure.

### Increment 5: Sets, Cycles, and Multi-Day Sessions

- Create ordered training sets containing scored and non-scored blocks.
- Start, pause, resume, and finish cycles.
- Split a cycle into multiple sessions across days.
- Persist active-time segments and recover after process termination.
- Finalize append-only attempts with detailed outcome reasons.

**Demo outcome:** User stops midway through a cycle, resumes the next day, and sees correct active time and progress.

### Increment 6: Reporting and Hardening

- Add accuracy, total active time, average, median, errors, and cycle comparison.
- Add per-theme and per-difficulty summaries where metadata exists.
- Add backup/export for training history.
- Complete accessibility pass and large-data performance tests.
- Add database migration and interrupted-write recovery tests.

**Demo outcome:** User completes repeated cycles and can understand improvement without opaque scoring.

## Persistence Strategy

### Source Identity

A source record will include:

- Stable application source ID.
- User-visible filename.
- Access mode: managed copy or external document.
- URI or managed path stored through the file-source adapter.
- File size.
- Last-modified value when available.
- Lightweight revision fingerprint.
- Index schema/scanner version.
- Import state and checkpoint.

A mismatch invalidates locators and triggers re-index or source recovery. Existing attempt history remains linked to stable exercise identities and is not silently deleted.

### Exercise Identity

Identity priority:

1. Valid unique `X-ExerciseId` scoped to the collection or source policy.
2. Explicit imported application mapping.
3. Deterministic fallback fingerprint from source identity, block location, starting position, and normalized authored line.

Duplicate IDs must produce a diagnostic and require a defined conflict policy. File order alone is not identity.

### Transactions

Use transactions for:

- Import checkpoint plus committed index batch.
- Starting or finalizing an attempt.
- Closing a timing segment and updating accumulated duration.
- Advancing cycle progress.
- Database migrations.

## Puzzle Visibility Model

The parsed move tree may exist in memory, but puzzle UI selectors must expose only:

- Starting position.
- Side to move.
- Legal destinations.
- User-played accepted path.
- Non-solution introductory text explicitly allowed by the content model.

The following remain inaccessible until finalization or reveal:

- Future SAN/UCI moves.
- Future board positions.
- Solution comments and NAG explanations.
- Principal variations.
- Accessible labels containing hidden moves.
- Debug logs containing solution moves in production.

A dedicated `PuzzlePresentationState` must be constructed from the domain state rather than passing the complete parsed content directly to widgets.

## Attempt Policy

The MVP should support one configured policy per training set, with a default of **first wrong move finalizes the attempt as failed, but the user may continue in review mode**.

Rules:

- Illegal board interactions do not count as authored-solution mistakes.
- A legal move not present among accepted solution children records `wrong_move`.
- Completing an accepted terminal line without earlier failure records `passed`.
- Show Solution records `revealed` unless the attempt was already finalized.
- Skip records `skipped`.
- Exceeding an enabled limit records `timed_out`.
- Exiting an active attempt prompts for pause when resumable; explicit abandonment records `abandoned`.
- Continuing after failure is review and does not convert the historical failure into a pass.

## Scoring and Reporting

Calculations must be defined once in a domain service and tested with fixed fixtures.

```text
accuracy = passed attempts / finalized scored attempts * 100
average time = sum(active duration of comparable attempts) / count
median time = median(active duration of comparable attempts)
cycle active time = sum(finalized attempt active duration) + eligible active non-puzzle session time
```

Reports must state whether abandoned attempts and timeouts are included. The initial recommendation is to include all finalized scored outcomes in accuracy and show each outcome count separately.

## Error Handling and Recovery

- **Malformed PGN block**: Store diagnostic, skip or quarantine only that block, continue indexing where boundary recovery is safe.
- **Unsupported variant**: Index metadata, mark unsupported, do not interpret as standard chess.
- **Source missing**: Preserve index and history, disable block opening, offer source relink or managed re-import.
- **Source changed**: Block offset-based reads until re-index completes; preserve training history.
- **Import interrupted**: Resume from last committed safe checkpoint or restart without duplicate rows.
- **Database migration failure**: Roll back, preserve original database, and show recovery instructions.
- **App terminated during attempt**: Close the last timing segment using the most recent persisted lifecycle boundary; never count unknown offline time.
- **Duplicate exercise ID**: Report conflict and apply no silent merge.

## Testing Strategy

### Unit Tests

- Chunk-boundary scanner state transitions.
- Header and custom-tag classification.
- FEN side-to-move derivation.
- Move-tree conversion and variation preservation.
- Puzzle move evaluation.
- Outcome state machine.
- Monotonic timing accumulation.
- Accuracy, average, median, and cycle comparison.
- Source fingerprint and invalidation logic.

### Integration Tests

- Import fixture PGN into SQLite and retrieve exact original block.
- Cancel and resume import without duplicate entries.
- Solve main line and alternate variation.
- Verify wrong move, reveal, skip, timeout, and abandonment outcomes.
- Pause on day one and resume on simulated day two without adding idle time.
- Recover an in-progress attempt after process recreation.
- Change or remove a source and verify safe degradation.
- Run database migrations with preserved attempts.

### UI and Accessibility Tests

- Hidden solution does not appear in visible text, semantics tree, navigation controls, or screenshots.
- Side to move is announced and not color-only.
- Touch controls meet target-size requirements.
- Phone layout remains usable with large text scaling.
- Instruction blocks do not increment puzzle score.
- Screen reader labels do not reveal the solution.

### Performance Tests

Use generated and real-world sanitized fixtures at defined sizes, including 10,000 and 100,000 blocks. Measure:

- Peak memory during import.
- Blocks indexed per second.
- Time to cancel.
- Page-query latency.
- Selected-block open latency.
- Board interaction responsiveness.
- Database growth per indexed block and attempt.

Synthetic fixtures must be clearly labeled and retained only for testing.

## Security, Privacy, and Licensing

- Do not request internet permission unless a later feature requires it.
- Do not upload PGNs, positions, or performance metrics without opt-in.
- Redact local paths, content URIs, and PGN text from production diagnostics.
- Use parameterized Drift queries.
- Validate imported sizes and nesting depth to reduce denial-of-service risk from malformed files.
- Maintain a dependency inventory with package version, source, license, and distribution obligations.
- Complete a GPL compatibility review before publishing through an application store.

## Observability

Local structured diagnostics should include:

- Import job ID.
- Source ID, never raw private path in production logs.
- Scanner version.
- Blocks scanned, indexed, skipped, and diagnosed.
- Operation duration and cancellation state.
- Database migration version.
- Crash-safe lifecycle transitions for active attempts.

Solution moves and user PGN comments must not be logged in production.

## Deferred Work

The following require separate specifications:

- Stockfish local analysis and MultiPV.
- Engine-assisted alternative-move acceptance.
- Full-game automated analysis.
- Cloud synchronization and accounts.
- Multi-device progress merge.
- Shared or downloadable study collections.
- Opening explorer and tablebases.
- Puzzle ratings, streaks, leaderboards, or composite points.
- PGN authoring and visual exercise editor.
- iOS and desktop release packaging.

## Complexity Exceptions

None proposed. If Android document providers cannot support reliable random access, the managed-copy approach remains the MVP rather than introducing a backend or unsafe offset assumptions.

## Plan Completion Criteria

This plan is ready for task generation only when:

1. `spec.md` contains prioritized user stories, acceptance scenarios, functional requirements, edge cases, and measurable success criteria.
2. Phase 0 research decisions are recorded in `research.md`.
3. `data-model.md` and the three contracts are complete.
4. The post-design Constitution Check passes.
5. Minimum Android version and pinned package versions are decided.
6. Licensing has an explicit distribution conclusion.
7. No architecture-changing ambiguity remains.

## Next Spec Kit Step

After reviewing and completing the missing specification and Phase 0/1 artifacts, run:

```text
/speckit.tasks
```

This should generate `specs/001-pgn-training-reader/tasks.md` with dependency-ordered, independently testable implementation tasks.
