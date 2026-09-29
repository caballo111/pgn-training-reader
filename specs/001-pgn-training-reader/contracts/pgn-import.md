# PGN Import Contract

This contract defines the domain boundary between an import workflow and the
local source, index, and parsed-content repositories. It complements the
interfaces in `lib/domain/library/pgn_import_service.dart`,
`pgn_source_repository.dart`, `pgn_index_repository.dart`, and
`lib/domain/chess_content/chess_content_repository.dart`. The original PGN is
canonical; the index is derived data.

## Preconditions

- A source is registered before it is passed to `PgnImportService.start`.
- A request names a non-empty source ID. The source must be readable and its
  revision must be available for a new import.
- At most one import execution may run for a given source/job at a time. A
  conflicting `start` is reported; it does not create competing checkpoints
  or ambiguous block identities.
- A resume request names a known cancelled or recoverably failed job. Its
  source revision and scanner version must match the values captured by that
  job. If they do not match, the source must be repaired or re-indexed before
  old byte locators are used.
- Search page limits are positive and offsets are non-negative. Text filters
  are case-insensitive substring matches; multiple filters combine with AND.
- Opening a block requires a current source fingerprint/revision and a valid
  indexed locator. A missing or changed source suspends retrieval until
  repaired.

## Operations and results

### Start or resume

`start(sourceId)` and `resume(jobId)` return an operation handle immediately.
The handle exposes progress, sanitized diagnostics, a terminal result, and a
safe cancellation request. Progress reports the phase, indexed-block and
diagnostic counts, cancellation state, a committed safe checkpoint, and byte
progress when measurable. Unmeasurable progress is represented as unknown,
not as a fabricated percentage.

`resume` continues only from the last committed complete-block boundary. It
must produce the same final indexed identities, source order, and count as an
uninterrupted import and must not duplicate previously committed blocks.
Completed imports have no recovery action. Cancelled or failed imports report
one of `resume`, `restart`, or `repairSource`.

An import can complete successfully with zero indexed blocks; empty or
comment-only input is a clear zero-content result, not silent apparent
success. A malformed block may be skipped with a diagnostic when its
boundaries permit later valid blocks to be found. Unknown content types remain
unsupported; duplicate exercise IDs are diagnosed and never silently merged.

### Read index and content

Index lookup returns the matching metadata or `null`. Search returns one
bounded page in stable source-ID then source-ordinal order and a nullable next
offset. Full parsed content lookup reads only the indexed block and returns the
faithful supported chess-content representation or `null` if the ID is not
indexed. It does not rewrite or normalize source bytes.

### Register and update source metadata

Creating a source fails if its ID already exists. Updating an existing source
preserves source identity and creation time. Relinking, revision changes, or
import-state updates must not silently remove dependent index or training
records.

## Atomicity and lifecycle

- Each complete index batch and its import checkpoint are one atomic commit.
  A checkpoint must never point inside an unresolved PGN block.
- Cancellation is a request to stop at a safe boundary. Already committed
  blocks and diagnostics remain available; the active uncommitted batch is
  either committed as a complete batch or discarded.
- Process interruption has the same preservation guarantee as cancellation:
  committed work remains, and the job reports whether it can resume, restart,
  or needs source repair.
- A progress or diagnostic stream ends when the operation's terminal result
  resolves. Diagnostics are persisted so they remain inspectable afterward.
- Source metadata updates, index batches, and checkpoint changes must not
  leave a state that exposes stale locators as current.

## Errors and recovery

| Condition | Contract behavior |
|---|---|
| Unknown source on start or unknown job on resume | Terminal failed result with an actionable diagnostic; no index mutation. |
| Another import is active for the same source/job | Reject/report the conflict; keep the existing operation authoritative. |
| Source missing, inaccessible, or changed | Fail or stop with `repairSource`; preserve committed data and never continue with stale offsets. |
| Source cannot be safely resumed or scanner version changed | Report `restart` or `repairSource` as appropriate; do not guess a checkpoint. |
| Malformed or unsupported block | Record a sanitized diagnostic and continue only if the next block boundary is reliable. |
| Duplicate source or exercise identity | Report conflict/diagnostic; never silently create an ambiguous identity or merge exercises. |
| Invalid encoding | Diagnose without silently replacing/corrupting source text. |
| Storage/database failure | Roll back the uncommitted batch and checkpoint together; preserve earlier commits and provide recovery guidance. |
| Selected block has malformed PGN | Content lookup raises typed `PgnFailure`; it does not return fabricated content. |
| Selected block is an unsupported variant/content | Content lookup raises `UnsupportedContentFailure`, never standard-chess content. |
| Index/locator cannot be read | Content lookup raises `DatabaseFailure`; source access/revision failures raise `FileFailure`. |

Diagnostics must be sanitized: no raw PGN text, comments, solution moves,
unnecessary personal data, paths, or content URIs. They identify a stable
category and, when known, source and byte/block location, and explain a safe
next action.

