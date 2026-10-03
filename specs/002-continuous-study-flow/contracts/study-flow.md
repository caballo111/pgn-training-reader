# Study state, mistake history, and persistence contract

Status: adopted. Normative companion to [spec.md](../spec.md).

## State transitions

| State / event | Durable behavior | Visible result |
| --- | --- | --- |
| Reading / Solve puzzle | Create or restore this block's casual interaction; save reading cursor. | Solving in the current route at accepted/start position. |
| Solving / accepted move | Commit accepted position and authored branch before publishing. Preserve existing automatic-reply rules. | Updated board; concealed future content. |
| Solving / first rejected move | Atomically record score failure, first rejection, and interaction. | Failed result with concealed Keep trying feedback. |
| Failed practice / distinct rejection | Append a practice rejection; leave scored attempt unchanged. | New entry in Your tries; perceptible rejection. |
| Failed practice / repeated rejection | No duplicate rejection; leave score and cursor unchanged. | Feedback and return cue still occur. |
| Solving or failed practice / completion | Finalize unfinished score normally, or retain earlier failed/revealed result. Persist review phase. | Review on the reached accepted branch. |
| Solving / Show solution | Finalize unfinished score as Revealed before exposing answers. Preserve earlier terminal outcome. | In-place review with solution visible; Read becomes available. |
| Review / Try again | Create new attempt identity and clean deduplication set; retain exposure provenance. | In-place solving at start; prior history preserved. |
| Any / Next, Previous, Back | Wait for transition; persist interaction and pause unfinished score before leaving. | Adjacent source block/book; no score erasure. |

Book navigation and cycle navigation are provided by their owning contexts.
Book defaults decide a newly opened puzzle's presentation; completion never
implicitly advances. Mode changes must not silently re-enable a finalized score.

## Position and rejection identity

`mistakeKey = (attemptId, authoredPathBeforeMove, normalizedUci)`.

Use the stable root-to-node authored path at the accepted cursor, with an empty
path at the starting position. Store the FEN before the move for display and
validation. A path identifies a position in this exercise; separate authored
occurrences of an identical FEN remain separate learning points. Promotion
suffix is part of UCI identity; learner/prediction role is retained as metadata.
Canonical UCI validation occurs before deduplication.

Record each key at its first occurrence, searching the entire attempt's saved
practice history. The first scored rejection must also seed this history and
its deduplication set. Repeats still receive feedback. Only accepted entries
advance replay, the authored path, or the automatic reply mechanism.

## Persistence model (interaction version 2)

Extend the existing separate interaction JSON behind
`PuzzleInteractionRepository`, used for casual and cycle practice:

- Existing accepted entries, completion policy, hints, and orientation.
- Explicit interaction phase: solving, failedPractice, review.
- Distinct rejection records: first-seen ordinal, UCI, SAN when legal,
  authored path before move, FEN before move, learner/prediction actor, legal
  flag, and first submission time when available.
- Accepted cursor/path and review cursor/path, independent of reader cursor.
- Nullable `reviewOrientation`, independent of the solving and reader board;
  missing legacy values use the accepted board's orientation. Cursor and
  orientation writes share one serialized queue and are retried before leaving.
- Casual answer-exposure provenance, scoped to block/source revision, separate
  from scored outcome. Record that answers were visible, not a claim that the
  learner actually read or remembers them. Preserve it across casual retries.

Deduplication is derived from saved rejection records, not an independent
mutable cache that can drift. The user-facing **Distinct practice mistakes**
count derives from these records; legacy scored wrongMoveCount and cycle
reports retain their definitions. The first error ends scoring and its active
time; post-failure/review time never extends that finalized duration.

Upgrade version 1 lazily when saving the first version 2 interaction. Replay
its accepted entries to reconstruct the authored cursor before each surviving
rejection, seed distinct keys, and preserve all existing records. Missing
historical timestamps remain unknown. Previously discarded mistakes cannot be
recovered and must not be fabricated. A legacy finalized score with no saved
interaction retains the read-only-review compatibility path.

Store reader cursor and exposure in separate versioned book/block presentation
settings, since reading alone creates no attempt. No SQL schema migration is
expected if existing JSON storage suffices; document and test any deviation
before implementation. Unknown future versions produce a recoverable error
and are not overwritten.

## Rejection presentation

Transient rejection states are evaluating, rejectionCue, returning, ready.
The temporary rejected board is presentation only: the durable accepted FEN
does not change. Commit the rejection before displaying it as a recorded
mistake. For a legal rejection, show the attempted destination for a target
450 ms, then return over approximately 200 ms. A save failure instead restores
the accepted position and shows a save error.

Input and conflicting reveal/advance/retry actions remain locked through this
transition. Reduced motion replaces travel with a static cue and brief hold;
submitted illegal moves use origin/destination feedback without fabricating a
legal position. Background/pause cancels ephemeral animation after durable work
finishes. Restart restores accepted position immediately. Timers, callbacks,
and overlays must not survive disposal or a block change.

## Solution-safe context and review

Safe solving projection supplies book display name, available section, neutral
block identifier/ordinal, mode, side to move, permitted hint, played entries,
and feedback. Arbitrary titles, theme, comments, future positions, or variation
labels cannot enter solving chrome merely because they are metadata.

Only review/explicit reading receives authored solution content. Review branch
selection never changes accepted practice history. Rejected tries remain a
separate list, not children in the authored tree. Persist review selection
independently and keep the accepted path available for Return to played line.
