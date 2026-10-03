# Privacy and local data

Core import, reading, solving and progress work offline. There is no account,
cloud synchronization, analytics upload or remote engine in this version.
Selecting a file through Android's document picker can involve the provider the
user chooses (including a provider's own network access); the app copies the
selected bytes into its own storage for reliable offline reads.

Managed PGNs live under the platform application-documents directory in
`managed_pgn_sources/<opaque-token>.pgn`. Temporary copies are promoted only
after completion; cancellation/failure discards an unfinished copy. Original
selected files are not rewritten. Index/source records retain the opaque
reference, revision fingerprint, safe checkpoint and classification metadata.

Drift opens `pgn_training_reader` in its platform default application-documents
location. The schema is currently version 7. SQLite stores the derived index,
import jobs/diagnostics, sets, snapshots, cycles, sessions, immutable attempts,
moves and timing segments. `app_settings` stores reading intent and separate
casual/practice interaction state. Exact OS paths are internal and not a public
portability contract. No shared-storage permission is needed for managed copies.

Diagnostic messages are sanitized; production log fields exclude PGN text,
comments, solutions, file paths and content URIs. Source fingerprints sample
bytes rather than prove cryptographic whole-file identity; changed sources
require repair/re-indexing before stale offsets can be read.

**Training-history export and restore are deferred (Phase 15).** There is no
portable history export file or restore UI. Uninstalling/clearing app data can
remove managed content and history; reimporting a book cannot reconstruct scores.
Android OS backup behavior is separate from an implemented portable app backup.
Set removal preserves history/content and is confirmed; it is not a data wipe.
Do not promise history portability until the deferred feature is implemented.

**Manage library** supports adding another PGN and deliberately removing a
book. Removal keeps a deleted source record, indexed identities, training
sets, cycle snapshots, and attempts so historical references are preserved.
The book becomes unavailable for reading or new training selections. Only its
app-managed copy is deleted; the original selected file is untouched. If
managed-copy cleanup fails, the book stays removed and cleanup can be retried.
Re-importing creates a new source identity and does not restore old scores or
cycle content. Book renaming and restoration are deferred.
