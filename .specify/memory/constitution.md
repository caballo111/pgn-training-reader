# PGN Training Reader Constitution

<!--
Repository location: .specify/memory/constitution.md
This document governs all specifications, plans, tasks, implementations, and reviews.
-->

## Core Principles

### I. PGN Fidelity and Portability

The application MUST preserve standards-compliant PGN as the canonical representation of chess content. Importing, indexing, viewing, or training from a PGN MUST NOT silently alter its moves, variations, comments, annotations, tags, starting position, or result.

Application-specific metadata MAY use documented custom tags prefixed with `X-`, including `X-ContentType`, `X-ExerciseId`, `X-Section`, `X-Sequence`, `X-Theme`, `X-Difficulty`, and solution-policy fields. Standard PGN tags, `SetUp`, `FEN`, comments, NAGs, and recursive annotation variations MUST be preferred whenever they already express the required meaning.

Hiding a solution is a presentation rule. Implementations MUST NOT remove, corrupt, or rewrite solution moves merely to conceal them during an exercise. Exported PGN MUST remain readable by other conforming chess applications, with graceful loss of application-specific behavior when custom tags are ignored.

**Rationale:** The user's chess material must remain durable, portable, and independent of this application.

### II. Explicit Content Semantics

Every indexed PGN block MUST have an explicit application content type. The initial supported types are:

- `Puzzle`: a scored exercise with a hidden solution.
- `Instruction`: explanatory content that does not affect the score.
- `Demonstration`: an annotated game or line for guided review.

`X-ContentType` is authoritative when present. The importer MAY infer a type for legacy PGNs, but inferred classifications MUST be visibly identified and MUST be editable without modifying unrelated chess content.

Puzzle identity MUST be stable through `X-ExerciseId` or an application-generated persistent identifier. Training sets MUST reference stable exercise identities rather than list positions or transient database row numbers.

The active chess position determines the side to move. The application MUST derive it by replaying the line or reading the active-color field in FEN. It MUST NOT trust a title, player name, comment, or duplicated custom field as the source of truth.

**Rationale:** Explicit semantics prevent fragile heuristics and allow instructions, examples, and exercises to coexist in one PGN collection.

### III. Large-File and Offline-First Operation

The application MUST remain usable with large PGN collections without loading the entire source file or every parsed game into memory. Import must use incremental reading, create a searchable metadata index, and retrieve an individual PGN block on demand.

The initial architecture MUST support:

- Incremental indexing with progress and cancellation.
- Persistent byte ranges or an equivalent random-access locator.
- Paginated or virtualized game lists.
- Resumable indexing or safe restart after interruption.
- Detection of missing or changed source files.
- Background work that does not block board interaction.

Core reading, puzzle solving, scoring, timing, and progress review MUST work offline after content has been imported. Network services MUST NOT be required for the MVP. Remote synchronization, cloud analysis, accounts, leaderboards, and external opening services require separate specifications.

**Rationale:** Local reliability and predictable performance are more important than unnecessary infrastructure.

### IV. Deterministic Puzzle Integrity

Before an exercise is completed, failed, skipped, or explicitly revealed, puzzle mode MUST conceal solution moves, future positions, solution comments, engine lines, and navigation controls that would expose the answer. Introductory instructions MAY remain visible when they are clearly separated from solution annotations.

Legal move validation MUST use a chess-rules library. Puzzle correctness MUST be evaluated against the PGN solution tree, including explicitly encoded acceptable variations. A flat move list is insufficient for the domain model.

The MVP MUST use deterministic acceptance:

- A move is accepted when it is an allowed child of the current solution node.
- Multiple accepted moves are represented as PGN variations.
- Engine-based equivalence MUST NOT replace authored solutions in the MVP.
- Engine-assisted acceptance, if introduced later, MUST be optional, explainable, and separately specified.

The interface MUST clearly show which side is to move. Board orientation MAY follow the side to move or a user preference, but orientation MUST NOT change the underlying position.

**Rationale:** A training result must be reproducible and must not depend on hidden engine thresholds or accidental solution disclosure.

### V. Attempt History, Honest Timing, and Resumable Cycles

The training model MUST distinguish:

- **Collection:** imported or curated content.
- **Set:** an ordered selection of exercises and instructional blocks.
- **Cycle:** one complete pass through the exercises in a set.
- **Session:** one active study period within a cycle.
- **Attempt:** one user's interaction with one exercise.

A cycle MAY span multiple sessions and multiple calendar days. Pausing or closing the application MUST preserve progress. Resume behavior MUST continue safely from the unfinished exercise or the next pending exercise, according to recorded state.

Timing MUST distinguish active training time from wall-clock elapsed time. Time spent while paused, suspended, closed, or waiting between days MUST NOT inflate solving time. Each attempt MUST preserve start time, completion time, active duration, outcome, wrong-move count, hint usage, reveal status, and failure reason.

The minimum outcome vocabulary is:

- `passed`
- `wrong_move`
- `revealed`
- `skipped`
- `timed_out`
- `abandoned`

Historical attempts MUST be append-only from the user's perspective. Repeating a puzzle or starting a new cycle creates new attempt records rather than overwriting prior performance.

**Rationale:** The method depends on measuring improvement across repeated cycles, including work split across several days.

### VI. Simple, Explainable Scoring

The MVP MUST prioritize transparent metrics:

- Attempted exercises.
- Passed and failed exercises.
- Accuracy percentage.
- Total active time.
- Average and median time per exercise.
- Wrong moves, hints, reveals, skips, and timeouts.
- Comparison between cycles.

A pass MUST require completion of the authored solution without revealing it. Product specifications MUST explicitly define whether an incorrect move immediately fails the attempt or permits retries. The stored failure reason MUST remain independent from any aggregate score.

Composite points, streak bonuses, ratings, penalties, or gamification MUST NOT be added unless a specification defines the formula, user value, edge cases, and migration impact. The user MUST be able to understand how every displayed metric was calculated.

**Rationale:** Accuracy and speed should be useful training feedback, not an opaque game mechanic.

### VII. Separation of Content, Training, and Presentation

The architecture MUST separate three concerns:

1. **Chess content:** PGN headers, initial position, move tree, comments, NAGs, and variations.
2. **Training state:** sets, ordering, cycles, sessions, attempts, scores, and progress.
3. **Presentation:** reader mode, instruction mode, puzzle mode, board orientation, and revealed or hidden UI state.

PGN stores portable chess content and content classification. The application database stores indexing data, training organization, user progress, timing, and cached analysis. User performance MUST NOT be written into the imported source PGN unless an explicit export feature is requested.

Board, PGN parser, chess rules, persistence, and engine integration MUST be behind clear interfaces so that a viewer can later evolve into a full analysis board without rewriting the library, indexing, or training subsystems.

**Rationale:** This separation supports future Flutter, native Android, desktop, and analysis capabilities while minimizing rework.

### VIII. Local Data Ownership, Safety, and Recoverability

Imported PGNs and training history belong to the user. The application MUST avoid uploading content or telemetry without explicit informed consent. Secrets and personal data MUST NOT be embedded in source code, logs, PGN custom tags, or exported diagnostics.

Database updates affecting progress MUST be transactional. Interrupted imports, app termination, storage loss, duplicate imports, and malformed PGNs MUST fail safely and provide actionable feedback. The application MUST NOT silently discard games, attempts, or comments.

Backup and export of training history MUST be possible before synchronization or account features are considered complete. Destructive actions MUST clearly state their scope and require deliberate user action.

**Rationale:** A local-first training tool must earn trust by preserving both study material and accumulated work.

### IX. MVP Simplicity and Evidence-Based Expansion

The implementation MUST choose the smallest architecture that satisfies the current specification. The MVP MUST NOT require a backend, cloud account, distributed job queue, remote engine, or generalized plugin system.

New abstractions, dependencies, services, and frameworks MUST address a demonstrated requirement. Each plan MUST identify what is deliberately deferred. Future analysis support SHOULD use the same position and move-tree model, but Stockfish integration is not required for the initial PGN reader and training workflow unless included by a feature specification.

Technology choices MUST favor maintained libraries, native performance for board and engine operations, testability, and clear licensing. GPL or other reciprocal dependencies MUST be identified in the implementation plan before distribution decisions are made.

**Rationale:** The project should reach a useful release quickly without creating a dead end or overengineering speculative features.

## Quality and Testing Standards

Every feature specification MUST include acceptance criteria and failure behavior. Implementations MUST include tests at the lowest practical level.

Mandatory test coverage areas are:

- PGN parsing and preservation of tags, comments, NAGs, and variations.
- FEN handling and correct side-to-move derivation.
- Incremental indexing across buffer boundaries and malformed input.
- Retrieval of the correct game from its stored locator.
- Solution-tree validation, including alternative accepted variations.
- Prevention of solution leakage before reveal or completion.
- Session pause, resume, app termination, and multi-day continuation.
- Active-time calculation excluding paused and suspended time.
- Attempt outcome and scoring calculations.
- Database migrations and recovery from interrupted writes.

Golden or fixture-based tests SHOULD use small, human-readable PGNs representing normal games, FEN-start puzzles, nested variations, comments, instructions, malformed blocks, and Unicode metadata.

Performance requirements MUST be measurable. Plans concerning large files MUST define representative file sizes, memory limits, indexing targets, and list-navigation expectations rather than using terms such as "fast" or "large" without thresholds.

## User Experience Standards

The application MUST make the current mode unmistakable: reading, instruction, demonstration, or puzzle solving. Puzzle mode MUST prominently show the side to move and the current exercise's progress while avoiding accidental hints.

Long-running operations MUST show progress and remain cancellable where safe. Errors MUST explain what happened, what data was preserved, and what the user can do next.

Accessibility MUST be considered in every UI specification. Meaning MUST NOT rely only on color. Board coordinates, side to move, outcomes, timers, and controls MUST have accessible labels. Touch targets MUST be suitable for mobile use.

Phone layouts MUST prioritize the board and essential controls. Larger screens MAY show the board, notation, instructions, and analysis side by side, but all core workflows MUST remain available on a phone.

## Data and Compatibility Standards

The application database is a derived index and training store, not a replacement for the source PGN. Schema migrations MUST be versioned and backward compatible whenever feasible.

Custom PGN tags MUST be documented in the repository. Unknown standard or custom tags MUST be preserved when practical. Unsupported chess variants or malformed positions MUST be reported as unsupported rather than silently interpreted as standard chess.

Exercise ordering MUST use stable explicit sequence metadata or set membership records. File order MAY be used as an import default, but it MUST NOT be the sole persistent identity of an exercise.

## Development Workflow and Review Gates

The required workflow is:

1. Update this constitution only when project-wide governance changes.
2. Create a feature specification describing user outcomes and acceptance criteria.
3. Resolve material ambiguities before planning.
4. Produce an implementation plan with architecture, dependencies, licensing, storage, performance, and migration implications.
5. Generate ordered, testable tasks.
6. Implement with tests and validate against the specification and this constitution.

Every implementation plan MUST include a **Constitution Check** covering all applicable principles. Any violation requires an explicit **Complexity Exception** containing:

- The principle being violated.
- Why the requirement cannot be met otherwise.
- Simpler alternatives considered.
- Scope and duration of the exception.
- A removal or review condition.

Unjustified violations block implementation.

## Governance

This constitution is the highest project-level engineering and product-governance document. Feature specifications, plans, tasks, code, and reviews MUST comply with it. When documents conflict, this constitution prevails unless it is formally amended.

Amendments MUST:

1. Describe the proposed change and motivation.
2. Identify affected specifications, data, tests, and implementation plans.
3. Define migration or compatibility steps when behavior or stored data changes.
4. Update the semantic version and amendment date.
5. Be reviewed before dependent implementation begins.

Versioning follows semantic versioning:

- **MAJOR:** removal or incompatible redefinition of a governing principle.
- **MINOR:** addition of a principle or materially expanded mandatory guidance.
- **PATCH:** clarification, wording improvement, or non-semantic correction.

Compliance MUST be reviewed during specification, planning, and code review. Deferred work MUST be recorded explicitly and MUST NOT be represented as completed behavior.

**Version:** 1.0.0  
**Ratified:** 2026-09-14  
**Last Amended:** 2026-09-14
