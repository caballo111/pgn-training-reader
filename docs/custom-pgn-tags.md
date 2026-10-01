# Custom PGN tags

Source PGN bytes remain canonical. Tags are case sensitive; unknown tags remain
in the parsed headers. This app uses ordinary PGN moves, comments, NAGs,
variations, `SetUp` and `FEN` for chess information. Performance and scores are
stored separately in the local database.

| Tag | Meaning and implemented behavior | Example |
| --- | --- | --- |
| `X-ContentType` | Authoritative behavior: `Puzzle` or `Text`. Legacy `Instruction` and `Demonstration` map to Text; unknown values are Unsupported. | `[X-ContentType "Puzzle"]` |
| `X-ExerciseId` | Authored stable exercise identity. Repeated identities are diagnosed and never silently merged. Missing/invalid identities receive generated identity hints. | `[X-ExerciseId "sample-01"]` |
| `X-Section` | Indexed section label for browsing/set selection. | `[X-Section "Basics"]` |
| `X-Sequence` | Indexed authored sequence metadata; source/set order remains explicit. Use exercise numbers for range selection where available. | `[X-Sequence "12"]` |
| `X-Theme` | Indexed theme filter. | `[X-Theme "Development"]` |
| `X-Difficulty` | Indexed difficulty label; values are author supplied, without a universal rating scale. | `[X-Difficulty "Easy"]` |
| `X-Title` | Meaningful reader display title, ahead of standard header fallbacks. | `[X-Title "Develop a knight"]` |

Without `X-ContentType`, a `SetUp "1"` plus `FEN` block is inferred as Puzzle;
ordinary games are inferred as Text. Inference is shown and can be overridden
in the index without rewriting the PGN. Unsupported variants remain unsupported.

A standalone `✔` token in a move comment is the implemented Key Moves endpoint,
for example `1. e4 {✔}`. It applies only to the accepted branch. All Moves
continues to the authored leaf; Key Moves falls back to the leaf for an unmarked
branch. A marked opponent move requires prediction before Key Moves credit.
Completion policy and reading intent are app settings, not implemented PGN tags.
Unknown solution-policy tags do not change evaluation.

See [sample PGNs](../samples/) for puzzle, legacy instruction/demonstration,
FEN-start and alternative-variation examples. The illustrative opening moves
are authored exercises, not a claim that only those moves are good chess.
