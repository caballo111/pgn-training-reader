# Implementation plan: Manage library

Date: 2026-10-02. Status: implemented; automated verification complete, manual device acceptance pending.

Specification: [spec.md](spec.md). Tasks: [tasks.md](tasks.md).

## Product design

The Library app bar opens **Manage library**. The management surface lists
each active book and its import status, offers **Add book**, and places
**Remove from library** in a per-book overflow menu. Removal uses a named,
deliberate confirmation that explains retained history and managed-copy
deletion. Existing picker, copy, index, and recovery UI remains the add flow.
Do not add rename controls.

## Technical approach and ownership

1. Keep current source identity and metadata persistence. Extend
   `PgnSourceRepository` with a transactional removal operation that changes
   only an eligible source from active to `deleted`; preserve the source row,
   block rows, and dependent records. `getById` retains tombstones for
   historical lookup; active source listing excludes them.
2. Ensure `deleted` is terminal in source state transitions. Import start,
   resume, reindex, and verified relink reject deleted sources. Re-import uses
   the normal import controller and generates a new source ID.
3. Exclude deleted sources from default index search and adjacent-block
   navigation, and from training-set candidate lists. Keep direct historical
   lookup able to identify the tombstone and surface an unavailable message.
   Cycle snapshot order remains immutable; unavailable items are not skipped.
4. Coordinate removal with import lifecycle so an active import cannot commit
   new blocks after tombstoning. Serialize source removal with source jobs or
   recheck deleted state at every commit boundary.
5. After the database tombstone commits, ask the managed file repository to
   delete only the token-resolved app-owned copy under its managed root. Never
   accept a raw path from UI/domain input and never delete an external
   reference. Persist or derive retryable cleanup state without making the
   source active; retain the token when cleanup failed.
6. Replace the current Import PGN action in `LibraryPage` with Manage library,
   retaining access to Add book and existing training set navigation.

## Storage and recovery

The `pgn_sources` row is a foreign-key parent of indexed blocks and import
jobs. Hard deletion would break stable identities and risk cascading or
orphaning user history, so this plan uses the existing `import_state` field as
a tombstone value (`deleted`) and introduces no SQL schema migration unless
implementation discovers a concrete need. Training data is never purged.
Managed copy removal is a separate post-commit filesystem action. If cleanup
fails or the process stops after tombstoning, the source stays deleted and a
subsequent management load can retry cleanup. Tombstoning is not rolled back.

## Feature 002 coexistence

No direct requirement conflict exists. Source-order navigation and study
identity remain defined by stable source/block IDs. Active library queries
must omit deleted books. If removal occurs while a study or cycle references
the source, retain its cursor/history/snapshot and present an unavailable
state; do not redirect to a same-name source or mutate a cycle's frozen order.
This behavior belongs to the owning reader/cycle context.

## Constitution Check

| Principle | Proposed compliance |
| --- | --- |
| I — PGN fidelity and portability | Never alter external PGN; only delete the app-owned managed copy through its bounded token. |
| II — Explicit semantics | A distinct terminal deleted state avoids conflating removal with missing/changed repair states. |
| III — Large-file/offline | Reuse existing incremental import and index. Cleanup does not parse or load a book. |
| IV — Puzzle integrity | Removal does not rewrite solutions, attempts, or authored trees; unavailable blocks cannot be played. |
| V — Attempt history | Retain all attempts and cycle snapshots; do not cascade or remap identities. |
| VI — Explainable scoring | No score or report definitions change. |
| VII — Separation | UI requests removal; repository owns state transaction; managed storage owns safe file deletion. |
| VIII — Ownership/recovery | Confirm scope; tombstone before cleanup; cleanup failure remains retryable and cannot resurrect data. |
| IX — MVP simplicity | Reuse current database state field, import flow, and managed storage service; no rename or restore framework. |

No constitution exception is proposed. No dependency, service, or license
change is required. Rename and permanent history purge remain deferred.

## Delivery sequence

1. Add tombstone repository/state protections and guarded managed-copy cleanup.
2. Filter tombstones from active browsing, search, adjacency, and new set
   selection while preserving direct historical identity lookup.
3. Add the management surface and confirmation; route Add book to current
   import behavior.
4. Integrate reader/cycle unavailable handling, then perform acceptance review
   for mixed books, active import, cleanup interruption, and preserved history.

## Verification status

The Manage Library UI suite passed 10 tests plus one recovery-discovery
regression. The final storage-focused suite passed 7 tests: six lifecycle
cases and one normal indexer-resume case. It covers deleted-source
start/resume/reindex rejection, browse/adjacency exclusion, explicit
`source_deleted` content failure, and retained history snapshots. The targeted
storage analyzer completed cleanly.

Earlier broad data/import/browse/manage validation passed 173 tests with one
unrelated logging audit failure in `lib/main.dart`. The full workspace suite
passed 388 tests and failed 7: that logging audit, an active-session assertion,
four puzzle golden/review assertions, and a continuous-study landscape text
scale overflow. These results do not constitute a clean full-suite run; the
reported failures are tracked separately. Manual device acceptance remains
pending.
