# Compact cycle progress report

## User outcome
A cycle of 222 exercises studied over about 20 days, with multiple sessions per day, remains easy to scan. Users see day totals and deliberately open session details. Missing optional metadata does not clutter the report.

## Requirements and acceptance
- PR-001: Daily sessions are initially collapsed as one section with day and session counts. Opening it shows compact day rows, newest study day first.
- PR-002: Group by the recorded studyDay calendar components (do not reinterpret this calendar key as a timestamp). Each day is collapsed initially and shows its date, session count, attempted count, passed count, and summed active duration, including non-puzzle time.
- PR-003: Expanding a day exposes each session's local start time, status, and existing active-duration and outcome details. Session order is newest start first with deterministic identity tie-breaks. Collapsing and reopening retains access to every session without duplication.
- PR-004: Switching cycles resets expanded section/day state and never displays previous-cycle results while loading.
- PR-005: Hide each empty theme/difficulty section independently; hide the whole metadata area when both are empty. Populated groups remain available. Real loading errors retain Retry.
- PR-006: Preserve score definitions, timing rules, repository data, and cycle comparison. Empty session histories retain their existing helpful message.
- PR-007: Controls use Material accessible expansion semantics and mobile touch targets; summaries wrap at narrow widths and do not rely on color.

## Investigation
Importer indexes documented X-Theme/X-Difficulty fields, and repository groups finalized attempts with nonblank metadata. Missing authored tags or no finalized attempts correctly yield no groups; the existing unavailable messages are presentation clutter. Validate populated-tag behavior and investigate any contrary evidence rather than inventing metadata.

## Validation scenarios
20 days and multiple sessions per day remain behind one collapsed section. Expand section/day and verify aggregate totals and individual outcomes, reverse chronological order, and collapse/reopen. Switch cycles while expanded. Check narrow phone layout. Verify neither, one, and both metadata dimensions populated plus retry after errors.

## Scope
Presentation changes only. No inferred tags, schema changes, scoring changes, dependencies, or broader report redesign. This feature supersedes the old UI test requiring explicit unavailable metadata messages.
