# Implementation plan

Use existing async report views and Material ExpansionTile. Group raw session aggregates by recorded study day and calculate summary counts/time with ProgressCalculator, preserving all raw definitions. Outer section and day disclosures bound the initial report height. Reset async/disclosure state on cycle or repository changes; ignore previous FutureBuilder data while waiting. Hide empty metadata sections independently and conditionally insert spacing.

## Constitution Check
PGN fidelity and explicit semantics: no source changes or inferred metadata. Offline and large-file operation: existing cycle-scoped repository reads; no extra parsing or queries; grouping is linear with sorting by day/session. Deterministic integrity and transparent progress: preserve all existing counters and timing. Architecture: view-only changes, no storage migration. Accessibility: Material disclosure controls and wrapping summaries, phone validation. Tests cover interaction and data visibility. No exceptions.

## Dependencies, licensing, storage, performance
Existing Flutter/Material only; no new licensing or dependency obligations. No persistence/schema changes. For the representative 20-day cycle only one disclosure renders initially; session detail is visible only on expansion.
