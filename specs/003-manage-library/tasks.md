# Ordered implementation tasks

Status: implemented; automated verification complete, manual device acceptance pending. Read the project constitution,
[specification](spec.md), and [plan](plan.md) before implementation.

## Source lifecycle and managed cleanup

- [x] ML-T01 Extend `PgnSourceRepository` with a transactional remove operation
  and define `deleted` as terminal. Preserve source creation/identity and all
  indexed blocks, import jobs/diagnostics, attempts, sets, and cycle records.
  Gate: repeated removal is safe; deleted sources cannot be relinked, resumed,
  reindexed, or mutated back to active; new imports get a distinct ID.
- [x] ML-T02 Coordinate removal with imports and database commit boundaries.
  Gate: an active job prevents removal or is safely terminalized before the
  tombstone; no later batch can repopulate a deleted source.
- [x] ML-T03 Add guarded managed-copy deletion through the existing managed
  storage interface. Persist/retry cleanup status after the database tombstone
  and keep the source deleted on failure. Gate: token traversal attacks,
  outside-root paths, external references, duplicate retries, and interruption
  cannot delete user files or resurrect a source.

## Active library visibility and management surface

- [x] ML-T04 Exclude deleted sources from ordinary source lists, block search,
  filters, source-order Next/Previous traversal, and training-set candidate
  selection. Retain direct lookup for historical rows. Gate: active library
  omits deleted content; saved references resolve to a clear removed state;
  feature 002 cycle snapshots keep order and do not silently skip items.
- [x] ML-T05 Replace the Import PGN action with Manage library and provide
  Add book through the existing import controller/flow. Gate: adding a second
  source leaves all prior content and history unchanged.
- [x] ML-T06 Show books and per-book Remove from library action. Add a
  confirmation that names the book and clearly explains active-library removal,
  managed-copy deletion, and retained history that remains available in
  reports. Gate: cancel is side-effect free; confirm removes content from the
  active library; failures show actionable status.

## Study integration and acceptance

- [x] ML-T07 Handle source deletion observed during an open reader/study flow
  with an explicit unavailable message and safe current-position persistence.
  Gate: no stale content read, same-name remap, or changed cycle ordering.
- [x] ML-T08 Add repository, query, lifecycle, UI, and migration-regression
  coverage. Verify external PGN remains untouched, managed copies are cleaned
  only within app storage, history remains linked to original block IDs, and
  re-import creates a new identity. Run targeted checks and static analysis.
- [ ] ML-T09 Complete manual device acceptance for adding a second book,
  confirming/canceling removal, cleanup retry visibility, and retained history
  messaging on the target phone. Gate: removal is understandable and reachable,
  and the library remains usable after add, remove, and cleanup failure.

## Deferred

Renaming, undelete, permanent purge, and history reassignment are not tasks in
this feature.

## Verification record

Automated checks:

- Manage Library UI: 10 tests passed, plus 1 recovery-discovery regression.
- Storage-focused suite: 7 tests passed (6 lifecycle and 1 normal indexer
  resume). Deleted-source start/resume/reindex, browse/adjacency exclusion,
  explicit `source_deleted` content failure, and retained history snapshots
  were verified.
- Targeted storage analyzer: clean.
- Combined data/import/browse/manage run: 173 passed, with 1 unrelated logging
  audit failure in `lib/main.dart`.
- Full workspace suite: 388 passed, 7 failed. The failures are the logging
  audit, an active-session assertion, four puzzle golden/review assertions, and
  one continuous-study landscape text-scale overflow. These findings are being
  tracked separately; this is not a clean full-suite result.

Automated feature tasks ML-T01 through ML-T08 are complete. Manual device
acceptance (ML-T09) remains pending. The broad and full-workspace failures
above are recorded without claiming a clean full-suite result.
