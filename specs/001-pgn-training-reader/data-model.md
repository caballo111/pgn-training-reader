# Data Model: PGN Training Reader

The PGN source is the canonical store of chess content. The local database is a derived searchable index and durable training store. This document describes T040–T048 models and the planned `ImportJob` and `ImportDiagnostic` records. Persisted enum strings are explicit, case-sensitive contracts; unknown values must fail decoding rather than silently default.

## Shared identity conventions

Persisted records use application-generated stable string IDs: source, indexed block, import job/diagnostic, training set/item, cycle, session, attempt, submitted move, and timing segment. Row IDs are not exercise identities. Resolve exercise identity in this order: unique authored `X-ExerciseId` under the collection/source policy; explicit imported mapping; deterministic fallback fingerprint from source identity, block location, starting position, and normalized authored line. File order alone is not permanent identity. Conflicts are diagnosed and retained as distinct records, never silently merged.

Timestamps are wall-clock instants for history; `studyDay` is the calendar day used for grouping. Active durations come from a monotonic clock and exclude time between timing segments. Immutable domain values may be replaced during active state transitions. Finalized attempts are append-only from the user's perspective.

## Content and import

### `PgnSource`

**Identity/fields:** `id`, `displayName`, `accessMode` (`ManagedCopy` or `ExternalReference`), exactly one opaque `managedPath` or `externalReference`, optional `sizeBytes`, `modifiedAt`, `fingerprint`, positive `scannerVersion`, `importState`, nonnegative `safeCheckpoint`, `createdAt`, `updatedAt`.

**Invariants/relationships:** the chosen reference must match the access mode; size and checkpoint are nonnegative. A source owns indexed blocks and import jobs. Fingerprint plus scanner version determines whether source byte locators remain valid. Missing/changed source disables dependent reads pending relink or re-index, without invalidating training history.

**Lifecycle/retention/deletion:** retain unavailable/changed sources for repair. Delete only by deliberate library removal; preserve identities referenced by sets or attempts (for example with tombstones) and do not cascade into training history.

### `PgnBlockIndex`

**Identity/fields:** generated `id`, `sourceId`, inclusive `startOffset`, exclusive `endOffset`, nonnegative source-order `ordinal`; optional standard search headers `event`, `site`, `date`, `round`, `white`, `black`, `result`; explicit `contentType`, `inferredClassification`, nullable original `authoredContentType`; optional `exerciseId`, `section`, `sequence`, `theme`, `difficulty`; `parseStatus`; sanitized optional `diagnosticSummary`.

**Invariants/relationships:** source exists; offsets are nonnegative and `endOffset >= startOffset`; `(sourceId, ordinal)` is unique. Locator is valid only for its source revision. Sets and attempts refer to this stable block row; `exerciseId` is a separately resolved identity hint. Metadata never rewrites source PGN.

**Lifecycle/retention/deletion:** created at safe scanner boundaries. Full parse status progresses from `NotParsed` to `Valid`, `Malformed`, or `Unsupported`. Re-index reconciles stable exercise identities and diagnoses unresolved changes. A referenced block cannot be physically removed; retain an unavailable record/tombstone. Replace unreferenced stale rows only after successful re-index.

### `ContentClassification` / `ContentType`

Current implementation uses `ContentType`: `Puzzle`, `Instruction`, `Demonstration`, `Unsupported`, serialized with those exact values. Valid `X-ContentType` is authoritative. Unknown values remain `Unsupported`, not guessed. Schema version 2 persists `inferredClassification` and the original `authoredContentType` value on each indexed block. Legacy fallback classifies `SetUp=1` plus `FEN` as Puzzle and other blocks as Demonstration; these classifications are marked inferred. A nonstandard variant is Unsupported. A local user override remains part of the later editing workflow. A set item snapshots its selected type so a later reclassification cannot silently change historical training semantics.

### `ChessContent`

**Identity/fields:** ephemeral parse result associated with one `PgnBlockIndex`, no separate ID; ordered header map (including custom tags), nonempty `startingFen`, ordered `rootMoves`, block-level comments, optional verbatim result, `contentType`.

**Invariants/relationships:** preserve authored headers, comments, result and tree order. Root moves are children of an implicit root and can encode alternative first moves. Separate from locators/training state. FEN validity and chess semantics belong to the parser/chess adapter; invalid/unsupported content is not scored as standard chess.

**Lifecycle/deletion:** parse on demand from the source block and discard freely; this value never replaces or mutates canonical PGN.

### `MoveNode`

**Identity/fields:** transient tree path under the block's implicit root; nonempty `san`, `uci`, `fenBefore`, `fenAfter`; ordered comments; ordered NAG integers 0–255; ordered children.

**Invariants/relationships:** one position transition per node; children represent authored continuations/variations in source order. Chess validity is adapter-owned. Nodes belong to one `ChessContent`, are not independent persistence targets, and must not be removed to hide/mutate source solution branches.

### `ImportJob`

**Identity/fields:** `id`, `sourceId`, `status`, nonnegative `bytesProcessed`, `blocksScanned`, `blocksIndexed`, `blocksSkipped`, `diagnosticCount`, safe byte checkpoint, `cancellationRequested`, `startedAt`, optional `finishedAt`. Counters default to zero. Schema version 2 snapshots `sourceFingerprint`, `scannerVersion`, and `sourceSizeBytes` on the job. Legacy version 1 jobs lack these snapshots and require a safe restart instead of guessing a revision.

**Invariants/relationships:** belongs to one source. Advance checkpoint only at a safe boundary and atomically with its committed index batch. Counts describe this job; cancellation retains committed batches. Plan lifecycle vocabulary: `selecting`, `preparing`, `indexing`, `completed`, `cancelled`, `failed`; selection may be transient before a source/job exists. Terminal states have finish time; running states do not.

**Lifecycle/retention/deletion:** cancelled/failed jobs resume only if the same source revision is available; otherwise restart or repair. Keep completed jobs as operational history. Remove diagnostics with their job; removal of jobs follows deliberate source removal.

### `ImportDiagnostic`

**Identity/fields:** `id`, `importJobId`, severity, optional block ordinal and byte offsets, stable `diagnosticCode`, sanitized actionable message, `createdAt`.

**Invariants/relationships:** belongs to one job; known offsets are nonnegative and ordered. Severity is `info`, `warning`, or `error`; current stable categories are `malformedBlock`, `unsupportedContent`, `invalidEncoding`, `duplicateExerciseId`, `duplicateSource`, `sourceUnavailable`, `sourceChanged`, `storageFailure`, and `other`. Do not store raw PGN text, private paths, or content URIs. Diagnostics cover malformed/unsupported blocks, duplicate exercise IDs, source failures, or recoverable import errors; valid neighboring blocks remain indexable when boundaries are known. The streaming diagnostic value currently carries a single source offset, while the durable table permits a start/end range.

**Lifecycle/retention/deletion:** retain with job for feedback/recovery; delete only with deliberately removed job/source after preserving referenced block/history identities.

## Training records

### `TrainingSet`

**Identity/fields:** `id`, nonblank `name`, status `active` or `archived`, ordered items, `createdAt`, `updatedAt`, optional `archivedAt`.

**Invariants/relationships:** item IDs and positions are unique within the set; positions are explicit and nonnegative; items belong to this set. Contains Puzzle, Instruction, Demonstration, not Unsupported. Owns items and cycles; at most one active cycle per set.

**Lifecycle/retention/deletion:** active sets can be edited/trained; archiving timestamps the set and prevents new cycles but preserves history. Delete with deliberate confirmation; where cycles/attempts exist retain archived record or tombstone and do not cascade history.

### `TrainingSetItem`

**Identity/fields:** `id`, `trainingSetId`, stable indexed `blockId`, nonnegative `position`, selected `contentType`, state (currently `pending`), `addedAt`.

**Invariants/relationships:** belongs to one set and block; `(trainingSetId, position)` unique. Current DB permits the same block at multiple positions. Unsupported items cannot be added. Instruction/Demonstration participate in order but create no scored attempt. Completion is per cycle; the shared set item state is not cycle progress.

**Lifecycle/retention/deletion:** reorder by changing explicit positions. Removing affects future selection only; retain historical cycle/attempt links. If block becomes unavailable, show repair/unavailable state rather than erasing the item/history.

### `Cycle`

**Identity/fields:** `id`, `trainingSetId`, status `pending`/`active`/`completed`/`stopped`, optional `startedAt`, `completedAt`, `stoppedAt`, `createdAt`.

**Invariants/relationships:** belongs to one set. Active requires start; completed requires completion time; stopped requires stop time. Completion/stop times are mutually exclusive and allowed only for matching state. Partial unique index enforces at most one active cycle per set. A cycle has sessions and attempts and may span days.

**Lifecycle/retention/deletion:** pending → active → completed after all items finish, or pending/active → stopped explicitly. Terminal cycles are historical; another pass creates a new record. Preserve with attempts/sessions when set is archived/deleted; delete only an empty cycle without children/history.

### `TrainingSession`

**Identity/fields:** `id`, `cycleId`, status `active`/`paused`/`closed`/`recovered`, `startedAt`, optional `endedAt`, `studyDay`.

**Invariants/relationships:** belongs to a cycle. Closed/recovered require end; active/paused forbid it; end cannot precede start. At most one open active session per cycle (transactional constraint; not currently a DB unique index). Session wall time is not puzzle active time.

**Lifecycle/retention/deletion:** open active, pause/resume, close normally or recover after interruption. Close any active timing segment first. Keep with cycle history; cannot delete while attempts refer to it.

### `PuzzleAttempt`

**Identity/fields:** `id`, puzzle `blockId`, `cycleId`, `sessionId`, status `active`/`paused`/`finalized`, `startedAt`, optional `completedAt`, nonnegative `activeDuration`, `wrongMoveCount`, `hintCount`, optional outcome `passed`/`wrongMove`/`revealed`/`skipped`/`timedOut`/`abandoned`, optional reason `incorrectMove`/`illegalMove`/`timeLimitExceeded`/`userAbandoned`, `revealed`. Status database values are canonical lowercase strings and are decoded strictly.

**Invariants/relationships:** active or paused iff status is nonterminal and outcome and completion time are both absent; finalized iff status is finalized and both outcome and completion time are present. Completion cannot precede start. Belongs to one puzzle, cycle, session and owns moves/timing segments. Final result and closing segment commit atomically. A retry creates a new attempt. Failure reason is required for wrongMove/timedOut/abandoned and absent for passed/revealed/skipped. Revealed outcome requires `revealed=true`. Solution inspection after a wrong move does not convert its outcome to revealed.

FR-023 has precedence: any **submitted** illegal move immediately finalizes as `wrongMove` with `illegalMove`; a legal move outside current authored solution children immediately finalizes as `wrongMove` with `incorrectMove`. Count each as a wrong move. A non-submitted illegal board interaction is not an attempt move. Passing requires completing an authored terminal line without reveal.

**Lifecycle/retention/deletion:** active ↔ paused as needed, then exactly one terminal outcome; process recovery resumes the same unfinished identity if safe. Finalized records are append-only from the user's perspective. Delete only for explicit user erasure, together with child records and with clear history-removal semantics.

### `AttemptMove`

**Identity/fields:** `id`, `attemptId`, unique nonnegative `ordinal` per attempt, nonempty canonical move string (evaluator submits UCI), `legal`, `accepted`, `submittedAt`.

**Invariants/relationships:** belongs to one attempt, ordered by submission. Accepted implies legal and authored solution-child match at current node. Submitted illegal moves remain recorded as legal=false/accepted=false and trigger FR-023 finalization. Preserve after attempt finalization.

**Lifecycle/retention/deletion:** append on submission; delete only as part of explicit owning attempt/history erasure.

### `TimingSegment`

**Identity/fields:** `id`, `attemptId`, `startedAt`, optional paired `endedAt` and `activeDuration`.

**Invariants/relationships:** belongs to one attempt. Open has neither end nor duration; closed has both. End cannot precede start and duration is nonnegative. At most one open segment per attempt. Attempt active duration equals the sum of closed segments (maintain consistently/transactionally); pauses, inactivity, app closure and time between sessions are excluded.

**Lifecycle/retention/deletion:** open on start/resume; close on pause, finalization, or lifecycle boundary. Recovery uses the last persisted lifecycle boundary and never counts unknown offline time. Retain for audit; delete only with explicit attempt erasure.

### `ProgressAggregate`

**Identity/fields:** derived immutable value scoped by caller to a set/cycle/selected attempts, with no persisted identity. Raw counts: passed, wrong-move outcomes, revealed, skipped, timed out, abandoned, individual wrong moves, hints, completed non-puzzle items; one active duration per finalized puzzle attempt; separate eligible non-puzzle active duration.

**Invariants/relationships:** all counts/durations nonnegative; attempt-duration count equals the sum of finalized outcome counts. Projection of attempt/session/item records, never a substitute. Accuracy, averages, medians and comparison are calculated outside this value. No attempts means unmeasured accuracy, not 0%.

**Lifecycle/retention/deletion:** recompute as required; discard freely. Recalculate after explicit transactional corrections to source history.

## Relationships

```text
PgnSource 1 ── * PgnBlockIndex 1 ── * TrainingSetItem * ── 1 TrainingSet
    │                  │                                      │
    └── * ImportJob    └── * PuzzleAttempt * ── 1 Cycle ──────┘
             │                              │       │
             └── * ImportDiagnostic         │       └── * TrainingSession
                                            ├── * AttemptMove
                                            └── * TimingSegment
```

`ChessContent` is parsed from one block; `MoveNode` is nested in that value. Classification belongs to the block and is snapshotted by set items. `ProgressAggregate` is derived. Current SQLite foreign keys have no cascade clauses; repository deletion logic must enforce the retention rules explicitly.

## Persistence and known gaps

- Database timestamps are Unix microseconds; source locators are byte offsets; durations map to integer milliseconds.
- Classification provenance/override, per-cycle non-puzzle completion, an `ImportJob` source-revision snapshot and status enum, aggregate scope, and active non-puzzle session timing are not fully represented in T040–T048 models/current schema. Define persistence/contracts before relying on them.
- DB/domain checks do not yet enforce every cross-record condition: one active session per cycle, one open segment per attempt, outcome/reason combinations, or consistency between source locator and current revision. Enforce transactionally or add constraints/indexes.
- Set status defaults to `active`; set-item state defaults to `pending`. Strict enum decoding must not silently convert unknown data.

## Schema version 2 migration

Phase 5 adds classification provenance and import revision snapshots through an additive migration from version 1. Existing source, index, and training rows remain intact. Existing blocks default to `inferredClassification=false`; their authored type is unknown until re-indexed. Legacy jobs cannot resume without revision snapshots.
