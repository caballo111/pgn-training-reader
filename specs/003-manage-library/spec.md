# Feature specification: Manage library

Date: 2026-10-02. Status: implemented; automated verification complete, manual device acceptance pending.

Replace the Library's **Import PGN** entry point with **Manage library**. From
there, readers can add another PGN book through the existing import flow and
remove an imported book from the active library. Rename is deferred.

This feature extends feature 001 and coexists with proposed feature 002,
[Continuous study flow](../002-continuous-study-flow/spec.md). It does not
change puzzle entry, solving, review, block identity, or cycle navigation
semantics.

## User stories

### US1 — Add another book (P1)

As a reader, I want to add another PGN book while keeping my existing books so
that I can grow my library over time.

Acceptance scenarios:

1. Given the library, when I open **Manage library** and choose **Add book**,
   the existing PGN selection, managed-copy, indexing, progress, cancellation,
   and recovery flow is used.
2. Adding a book does not replace, rename, or alter any existing source,
   indexed block, training history, set, or cycle snapshot.
3. A failed or cancelled add preserves existing books and reports the existing
   import recovery choices.

### US2 — Remove a book deliberately (P1)

As a reader, I want to remove a book I no longer use so that it stops appearing
in my active library, while understanding what happens to its saved history.

Acceptance scenarios:

1. Manage library lists registered books and offers **Remove from library** for
   each. Removal requires a confirmation naming the book and explaining that
   it will leave the active library, its managed app copy will be deleted, and
   its saved training history will remain available in reports while the
   removed book's content is unavailable for study.
2. Cancel leaves the book and source bytes unchanged. Confirm removes it from
   normal book lists, library searches/filters, add-to-set selection, and
   source-order Next/Previous traversal.
3. Removal preserves source ID as a deleted tombstone, indexed block IDs and
   metadata, import diagnostics/jobs, attempts, training sets, and frozen cycle
   membership/order. It never cascades deletion into training history.
4. A saved reference to a removed block remains identifiable and reports that
   its book was removed. It is not silently redirected to a same-named book.
5. Re-importing the same PGN creates a new source identity. It does not revive
   the deleted source or attach old attempts to the new import.
6. Concurrent/active import prevents removal until it reaches a terminal
   state. An open reader/study flow detects removal before its next source
   read/navigation and offers an actionable removed-book message. Feature 002
   cycle snapshots retain their order and history; unavailable content is
   reported at the affected item rather than skipping/reordering it.
7. Managed file cleanup is limited to the app-owned managed copy, after the
   deleted state is durably committed and no import is active. A cleanup
   failure leaves the source deleted and provides a retryable cleanup status;
   it never restores visibility. An external original PGN is never deleted or
   modified.

## Functional requirements

| ID | Requirement |
| --- | --- |
| ML-001 | Replace the Import PGN library action with Manage library. |
| ML-002 | Provide Add book by invoking the existing import workflow without replacing current sources. |
| ML-003 | Provide confirmed Remove from library for an individual imported source. |
| ML-004 | Persist a distinct `deleted` source state; retain source and dependent rows to preserve stable identities and historical references. |
| ML-005 | Exclude deleted sources from ordinary library, source-order traversal, search/filter results, and new training-set selection. |
| ML-006 | Preserve historical attempts, cycle snapshots, sets, block identities, index metadata, and import diagnostics/jobs; never silently remap references. |
| ML-007 | Prevent deleted sources from being relinked, resumed, reindexed, or otherwise returned to active state. Re-import creates a new source ID. |
| ML-008 | Delete only the app-managed PGN copy, guarded by its opaque managed-storage token and managed-root ownership; never delete external references. |
| ML-009 | Commit deleted state before managed-file cleanup. Cleanup failure is recoverable and cannot resurrect the source. |
| ML-010 | Handle active import and open reader/study references without races, stale reads, or implicit traversal changes. |
| ML-011 | Defer source renaming and tombstone restoration. |

## Out of scope

Source renaming, undelete/restore, merging duplicate books, reusing a deleted
source identity, changing PGN content, editing puzzle flow, changing cycle
snapshot semantics, and permanent purge of historical rows are deferred.

## Success criteria

- Readers can add a second book without disturbing the first.
- Confirmed removal hides a book from all active-library entry points and
  source-order navigation.
- No attempts, set items, cycle snapshots, or stable IDs are erased or
  reassigned by removal.
- An external PGN remains byte-for-byte untouched; only the app-managed copy
  can be removed.
- Failed cleanup never makes a removed book active again.

## Compatibility assessment

Feature 002's study flow is compatible: it navigates stable blocks in a
source's order and keeps cycle navigation in its owning context. The deleted
source state must be filtered from new/default library traversal. A study
already referencing a removed source receives an explicit unavailable result;
cycle snapshots preserve order and record unavailable content rather than
silently changing membership. No feature 002 requirement or puzzle behavior
needs to change.
