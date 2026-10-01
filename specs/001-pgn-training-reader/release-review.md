# Release review — Phases 16 and 17

Date: 2026-10-01. Application version: `1.0.0+1`. Database schema: **7**.
Scope: hardening and release preparation; Phase 15 is deferred by the owner.
This is a development release candidate, **not accepted for distribution**.
No APK was published and no release signing configuration was introduced.

## Automated evidence

Final host validation used Flutter 3.47.5 / Dart 3.13.4:

| Command | Result |
| --- | --- |
| `flutter test --no-pub test` | All **353** unit, widget and host integration tests passed, including 100-block benchmark smoke. |
| `flutter analyze lib test integration_test tool` | No issues. |
| `dart format --output=none --set-exit-if-changed lib test integration_test tool` | 167 files checked; no changes. |
| `dart run build_runner build` plus generated-file diff | Successful; committed `app_database.g.dart` unchanged. |
| `git diff --check` | Passed. |
| Isolated 10k/100k pipeline benchmarks | Passed; final measurements in performance-results.md. |
| Scanner 10k/100k and 256 MiB comment memory check | Passed. |
| `flutter build apk --debug --no-pub` | Unavailable: “No Android SDK found.” |

An initial full run found a stale, empty generated test asset bundle. Moving the
ignored asset/build caches aside rebuilt the packaged chess images; the goldens
and full rerun passed without changing golden baselines or application assets.

Host unit, widget and workflow integration tests do not substitute for Android device
acceptance. Dependencies are pinned; no new package dependencies were added.
Generated Drift code is checked against the committed file. Sanitized sample
import checks copy bytes, stable locators, legacy Text types, FEN side, accepted
alternatives and reopening the on-disk database.

CI now checks generated database code, formatting/analysis including tools,
the full host suite (with a 100-block benchmark smoke check), and the Android
debug application build. Its optional integration compilation loop does not
establish device tests when the directory is empty.

See accessibility-review.md, resilience-review.md and performance-results.md
for scope-specific evidence and limits.

## Functional requirement traceability (T196)

“Automated” identifies the corresponding regression suite; it does not imply
unlisted physical validation. Partial/pending findings remain release gates.

| Requirement | Evidence | Validation and remaining work |
| --- | --- | --- |
| FR-001 | [import_controller_integration_test.dart](../../test/integration/import_controller_integration_test.dart) | Automated; Android provider recheck pending |
| FR-002 | [pgn_indexer_integration_test.dart](../../test/integration/pgn_indexer_integration_test.dart) | Automated + host benchmark; reference scale pending |
| FR-003 | [import_page_test.dart](../../test/widget/import_library/import_page_test.dart) | Automated |
| FR-004 | [pgn_indexer_integration_test.dart](../../test/integration/pgn_indexer_integration_test.dart) | Automated |
| FR-005 | [drift_chess_content_repository_test.dart](../../test/unit/data/repositories/drift_chess_content_repository_test.dart) | Automated |
| FR-006 | [pgn_indexer_integration_test.dart](../../test/integration/pgn_indexer_integration_test.dart) | Automated |
| FR-007 | [drift_pgn_index_repository_test.dart](../../test/unit/data/repositories/drift_pgn_index_repository_test.dart) | Automated |
| FR-008 | [drift_pgn_index_repository_test.dart](../../test/unit/data/repositories/drift_pgn_index_repository_test.dart) | Automated + synthetic 100k benchmark; reference device pending |
| FR-009 | [pgn_indexer_diagnostics_test.dart](../../test/unit/data/pgn/pgn_indexer_diagnostics_test.dart) | Automated |
| FR-010 | [pgn_indexer_diagnostics_test.dart](../../test/unit/data/pgn/pgn_indexer_diagnostics_test.dart) | Repeated IDs remain separate and flagged; source-level duplicate-import UX not implemented |
| FR-011 | [release_samples_integration_test.dart](../../test/integration/release_samples_integration_test.dart) | Automated byte-range fidelity; original assessment book recheck pending |
| FR-012 | [chess_content_parser_test.dart](../../test/unit/data/pgn/chess_content_parser_test.dart) | Automated |
| FR-013 | [pgn_header_reader_test.dart](../../test/unit/data/pgn/pgn_header_reader_test.dart) | Automated; docs/custom-pgn-tags.md documents implemented tags |
| FR-014 | [content_classifier_test.dart](../../test/unit/data/pgn/content_classifier_test.dart) | Automated |
| FR-015 | [drift_pgn_index_repository_test.dart](../../test/unit/data/repositories/drift_pgn_index_repository_test.dart) | Automated persisted local overrides |
| FR-016 | [schema_v6_migration_test.dart](../../test/unit/data/database/schema_v6_migration_test.dart) | Automated legacy Instruction/Demonstration to Text compatibility |
| FR-017 | [fen_start_puzzle_evaluator_test.dart](../../test/unit/domain/fen_start_puzzle_evaluator_test.dart) | Automated both active colors |
| FR-018 | [chess_content_parser_test.dart](../../test/unit/data/pgn/chess_content_parser_test.dart) | Automated |
| FR-019 | [move_tree_view_test.dart](../../test/widget/features/game_reader/move_tree_view_test.dart) | Automated notation/variation navigation; physical assessment pending |
| FR-019a | [game_reader_page_test.dart](../../test/widget/features/game_reader/game_reader_page_test.dart) | Automated previous/next source boundaries |
| FR-020 | [non_scored_reader_test.dart](../../test/widget/features/game_reader/non_scored_reader_test.dart) | Automated reading intent and non-scored Text |
| FR-021 | [puzzle_presentation_state_test.dart](../../test/unit/features/puzzle_solver/puzzle_presentation_state_test.dart) | Automated projection/concealment; device assistive-tech inspection pending |
| FR-022 | [authored_line_puzzle_evaluator_test.dart](../../test/unit/domain/authored_line_puzzle_evaluator_test.dart) | Automated authored alternatives and legality |
| FR-023 | [puzzle_ux_flow_test.dart](../../test/unit/features/puzzle_solver/puzzle_ux_flow_test.dart) | Automated immutable first failure and continued practice |
| FR-024 | [puzzle_ux_flow_test.dart](../../test/unit/features/puzzle_solver/puzzle_ux_flow_test.dart) | Automated Passed/Assisted/Revealed and other outcomes |
| FR-025 | [puzzle_board_test.dart](../../test/widget/features/puzzle_solver/puzzle_board_test.dart) | Partial: descriptive board label; square-level accessible move entry remains absent |
| FR-026 | [puzzle_solving_view_test.dart](../../test/widget/features/puzzle_solver/puzzle_solving_view_test.dart) | Automated visual hint and concealment |
| FR-026a | [puzzle_ux_flow_test.dart](../../test/unit/features/puzzle_solver/puzzle_ux_flow_test.dart) | Automated reveal before shared-board move |
| FR-026b | [puzzle_ux_flow_test.dart](../../test/unit/features/puzzle_solver/puzzle_ux_flow_test.dart) | Automated markers, fallback, replies and prediction; original book/device pending |
| FR-026c | [puzzle_session_ux_integration_test.dart](../../test/integration/puzzle_session_ux_integration_test.dart) | Automated durable failed practice and finalized history |
| FR-026d | [library_puzzle_navigation_test.dart](../../test/widget/app/library_puzzle_navigation_test.dart) | Automated book intent and casual/cycle separation |
| FR-027 | [training_set_editor_page_test.dart](../../test/widget/features/training_sets/training_set_editor_page_test.dart) | Automated narrow/large lists/save/bulk safeguards |
| FR-028 | [drift_training_set_repository_test.dart](../../test/unit/data/repositories/drift_training_set_repository_test.dart) | Automated single active cycle constraint |
| FR-029 | [puzzle_cycle_persistence_test.dart](../../test/unit/data/repositories/puzzle_cycle_persistence_test.dart) | Automated frozen snapshots/cursor and recreation |
| FR-030 | [training_session_integration_test.dart](../../test/integration/training_session_integration_test.dart) | Automated session wall timestamps separate from active time |
| FR-031 | [drift_training_repository_test.dart](../../test/unit/data/repositories/drift_training_repository_test.dart) | Automated stored attempt fields |
| FR-032 | [training_session_integration_test.dart](../../test/integration/training_session_integration_test.dart) | Automated timing exclusion; force-stop/Android lifecycle pending |
| FR-033 | [puzzle_session_ux_integration_test.dart](../../test/integration/puzzle_session_ux_integration_test.dart) | Automated immutable finalized history/recreation |
| FR-034 | [training_session_integration_test.dart](../../test/integration/training_session_integration_test.dart) | Automated durable resume/abandon |
| FR-035 | [progress_calculator_test.dart](../../test/unit/domain/progress_calculator_test.dart) | Automated independent text/puzzle completion |
| FR-036 | [progress_calculator_test.dart](../../test/unit/domain/progress_calculator_test.dart) | Automated raw counts, active durations and statistics |
| FR-037 | [progress_calculator_test.dart](../../test/unit/domain/progress_calculator_test.dart) | Automated Passed denominator and empty-state accuracy |
| FR-038 | [progress_report_page_test.dart](../../test/widget/features/progress_reports/progress_report_page_test.dart) | Automated mismatch warning/suppressed deltas |
| FR-039 | [transaction_test.dart](../../test/unit/data/database/transaction_test.dart) | Automated atomic finalization |
| FR-040 | [drift_pgn_source_repository_test.dart](../../test/unit/data/repositories/drift_pgn_source_repository_test.dart) | Automated committed history preservation; recovery_failure_test.dart verifies corruption preservation and migration rollback/retry |
| FR-041 | [training_sets_page_test.dart](../../test/widget/features/training_sets/training_sets_page_test.dart) | Automated removal confirmation/history retention; portable export deferred, no sync/accounts |
| FR-042 | [production_log_audit_test.dart](../../test/unit/data/logging/production_log_audit_test.dart) | Automated production-log audit; sanitized diagnostics |

## Success criterion traceability

| Criterion | Evidence | Validation and remaining work |
| --- | --- | --- |
| SC-001 | [pgn_indexer_integration_test.dart](../../test/integration/pgn_indexer_integration_test.dart) | Synthetic host 10k/100k measured; original corpus on reference S25 pending |
| SC-002 | [pgn_indexer_integration_test.dart](../../test/integration/pgn_indexer_integration_test.dart) | Automated exact count/order/ranges, malformed-neighbor diagnostics |
| SC-003 | [pgn_indexer_resume_test.dart](../../test/unit/data/pgn/pgn_indexer_resume_test.dart) | Automated interruption/resume equivalence and no duplication |
| SC-004 | [drift_pgn_index_repository_test.dart](../../test/unit/data/repositories/drift_pgn_index_repository_test.dart) | Host p95 recorded in performance-results.md; reference S25 <250 ms pending |
| SC-005 | [drift_chess_content_repository_test.dart](../../test/unit/data/repositories/drift_chess_content_repository_test.dart) | Host load p95 in performance-results.md; reference S25 <500 ms pending |
| SC-006 | [chess_content_parser_test.dart](../../test/unit/data/pgn/chess_content_parser_test.dart) | Automated FEN, headers, comments, annotations, Unicode and recursive variations |
| SC-007 | [authored_line_puzzle_evaluator_test.dart](../../test/unit/domain/authored_line_puzzle_evaluator_test.dart) | Automated deterministic authored legal moves/alternatives |
| SC-008 | [puzzle_presentation_state_test.dart](../../test/unit/features/puzzle_solver/puzzle_presentation_state_test.dart) | Automated hidden projection and widget output; device accessibility inspection pending |
| SC-009 | [training_session_integration_test.dart](../../test/integration/training_session_integration_test.dart) | Automated multi-day active-time exclusion and durable recovery |
| SC-010 | [transaction_test.dart](../../test/unit/data/database/transaction_test.dart) | Automated atomic timing/finalization, finalized immutability |
| SC-011 | [drift_pgn_source_repository_test.dart](../../test/unit/data/repositories/drift_pgn_source_repository_test.dart) | Automated injected failures/durable recovery; real force-stop and storage hardware pending |
| SC-012 | [active_session_page_test.dart](../../test/widget/features/training_session/active_session_page_test.dart) | Partial automated semantic/layout coverage; square interaction and physical TalkBack acceptance pending |

## Final Constitution Check (T195)

- I — PGN fidelity: automated parser/copy/range checks preserve canonical bytes;
  input bounds diagnose unsupported oversized constructs rather than rewrite them.
- II — Semantics: authored tags remain authoritative; legacy Instruction and
  Demonstration are supported through the Text reader while original headers
  are retained. Both FEN active colors and stable identities are covered.
- III — Large-file/offline operation: implementation and host scale evidence
  exist. Reference corpus/device throughput, memory, p95 and board frame-rate
  acceptance remain pending; no exception accepts unmeasured targets.
- IV — Puzzle integrity: authored legal alternatives, hidden safe projections,
  branch-local endpoints and assistance are covered. Physical accessibility
  output inspection remains pending.
- V — History/timing: durable cursor/snapshots, immutable scores and segment
  exclusion are covered; Android process-death walkthrough remains pending.
- VI — Scoring: raw counts, Assisted, explicit denominator, unavailable empty
  accuracy and incompatible comparison warnings are covered.
- VII — Boundaries: content, training persistence and presentation stay separate;
  no engine, backend or new package was added.
- VIII — Ownership/recovery: local-only storage, sanitized diagnostics/logs and
  transaction/recovery checks are covered. Owner deferred portable export;
  no sync/account functionality exists, so the export-before-sync rule remains
  applicable to future work. Uninstall/history-portability limitations are explicit.
- IX — Simplicity/licensing: fixes follow measured/audited findings; GPL-3.0-or-later
  decision and package notices are recorded. Final APK notices/source availability
  and release signing must be resolved before distribution.

Result: implementation review complete; release acceptance remains **pending**
for the gates below. No performance or accessibility exception is approved.

## Outstanding release gates

1. Build/install with Android SDK; use a real release signing configuration
   (the generated release configuration currently uses debug signing).
2. Recheck the physical assessment findings and Phase 18 T198–T202 with the
   original PGN on the Samsung S25. Check both toolbar/system Back, restart,
   delayed opponent replies, assisted/failure continuation and set/report flows.
3. Measure research.md's original-corpus 10k/100k fixtures on the reference device,
   including peak RSS, p95 query/full content load, and board responsiveness.
4. Perform TalkBack/large-font/focus/touch checks. The board currently exposes
   a descriptive label, not square-level nonvisual move entry; see accessibility review.
5. Review final APK/native/engine notices and deliver exact corresponding source
   with the binary under the recorded GPL terms.
6. Add an actual Android integration-test harness if automated device coverage
   is required. `integration_test/` currently has no runnable test entry point.

Future main-screen design, app icon and remaining board UX ideas are recorded
in [the backlog](../backlog.md). They are not release acceptance claims.
