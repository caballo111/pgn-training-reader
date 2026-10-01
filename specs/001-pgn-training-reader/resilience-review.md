# Parser and recovery bounds (Phase 16)

The limits below make import memory and parser recursion predictable while
keeping source bytes canonical. The parser does not normalize or rewrite input.

| Input | Limit | Behavior |
| --- | ---: | --- |
| PGN block | 8 MiB | Skip the block with a sanitized size diagnostic; continue at the next scanner boundary. |
| One tag pair | 64 KiB | Mark its block malformed and skip that block. |
| One brace or semicolon comment | 1 MiB | Mark its block malformed; continue scanning the comment without retaining it. |
| Nested variations | 256 levels | Mark the block malformed while tracking delimiters to its recoverable end. |
| Header diagnostics | 32 per block | Retain only the first 32 diagnostics. |
| Import diagnostics | 1,000 per job | Persist and emit at most 1,000 diagnostics; continue scanning and counting indexed/skipped blocks. |

The spec and original T007 research establish bounded parsing, preserved
annotations, and recovery at safe neighboring game boundaries, but do not
specify numeric caps. These values are implementation limits chosen for the
8 MiB indexed-block budget and recursive Dartchess move-tree parser. Raising
them requires checking memory and stack behavior on supported Android devices.

The resilience suite covers injected ENOSPC during managed copy, cancelled
copies removing temporary files, cancelled indexing at a committed checkpoint
followed by resume, preservation of corrupt database bytes, and an interrupted
migration rolling back before a successful retry. See
`test/unit/data/database/recovery_failure_test.dart`,
`test/unit/data/file_access/file_source_test.dart`, and
`test/integration/import_controller_integration_test.dart`. Schema-version
migration fixtures also verify history survives upgrades. Process death itself
is not simulated: the restart test recreates the controller and database
service from the durable indexing checkpoint, which covers the app recovery
contract without device-level Android process eviction.
