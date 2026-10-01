# MVP development release notes — 1.0.0+1

Status: release preparation completed where host validation is available;
Android/reference-device acceptance is pending. This is not a published APK.

## Included

- Managed local PGN imports, incremental indexing, safe cancel/resume,
  searchable metadata and source-change repair.
- Faithful Text reading with comments, NAGs, FEN and authored variations;
  legacy Instruction/Demonstration content remains readable.
- Concealed authored puzzles, automatic opponent replies, strict marked-reply
  prediction, Key Moves/All Moves policies and continued practice after failure.
- Piece hints/Assisted outcomes, explicit move/solution reveal, stable review,
  standalone casual solving separate from timed training cycles.
- Ordered mixed-book sets with bulk selection, lazy lists, durable snapshots,
  multi-session/day cycles, immutable attempt history and transparent reports.
- Phase 16 input/log hardening, semantic timer/outcome labels, layout checks,
  host benchmark evidence, GPL decision and dependency notices.
- Setup, PGN-tag, training-model and privacy docs with sanitized import examples.

## Data compatibility and upgrade notes

Schema **7** migrations retain committed training history. Legacy Instruction
and Demonstration rows map to Text while canonical PGNs/authored headers stay
intact. Prior leaf-completion attempts remain historical All Moves results;
legacy synthetic casual cycles are retained. Unknown historical membership or
policy snapshots cannot support numeric like-for-like comparisons.

Training-history export/restore (Phase 15) is deferred. There is no portable
backup UI; clearing/uninstalling app data can lose history. Reimport restores
content, not attempts. Downgrading the database is unsupported. Review storage
and recovery documentation before installing a different build.

## Known limitations and deferred work

Reference Android performance, physical accessibility, original-book assessment
rechecks and real process-death acceptance remain pending. The board lacks
square-level assistive move entry. Android SDK build validation and device test
harness are unavailable here; release still needs signing and final artifact
license/source delivery review. Main-screen UI, app icon and further board
layout ideas are in specs/backlog.md.

Stockfish, engine-equivalent acceptance, full-game analysis, authoring,
accounts/synchronization, ratings/leaderboards and iOS/desktop release packaging
are deferred. No source book or private user content is included in samples.

See [release-review.md](release-review.md) for requirement evidence and gates.
