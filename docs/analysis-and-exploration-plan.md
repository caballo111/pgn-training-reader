# Analysis and exploration in study flows

Status: proposed product and engineering plan, 2026-10-09. This document does
not change accepted scoring rules or authorize feature implementation.

## Product decision

Let learners explore a position without requiring engine assistance. Keep the
authored book, personal exploration, and engine output distinct in both state
and presentation. A learner should always know whose line they are viewing,
where it began, and how to return to their reading place.

Use two independent controls:

- **Explore position** opens a personal board workspace at the displayed position.
- **Engine: Off / On** reveals evaluations and suggested continuations for that
  workspace or the currently displayed authored position.

Reading remains the primary activity. Exploration is a temporary workspace
within reading or solution review, not a fourth top-level study mode. Turning
the engine off leaves the workspace and its moves intact.

## Reference patterns and their relevance

These observations come from public product documentation, not a hands-on
audit of every current mobile screen.

| Product | Documented pattern | Application here |
| --- | --- | --- |
| [Take Take Take](https://taketaketake.com/) | Game review emphasizes understandable feedback and the story of a game. | Preserve the book's explanatory voice; make engine detail optional. Do not imply that numeric evaluation explains a move's purpose. |
| [Chess.com puzzle help](https://support.chess.com/en/articles/8709001-why-did-the-puzzle-end-where-it-did-i-don-t-get-it) | Analysis helps learners investigate why a puzzle stops before an obvious final result. | Offer exploration after solving/reveal, including continuation beyond the authored leaf. |
| [Lichess study introduction](https://lichess.org/@/lichess/blog/study-chess-the-lichess-way/V0KrLSkA) | Studies retain variations/comments, allow hidden moves for lessons, and support computer evaluation that the owner can disable. | Treat answer visibility and assistance as explicit policies; use a move tree for investigation. |

Lichess's study authoring model is useful inspiration, but this app reads
imported books. Personal exploration should therefore live alongside the
source rather than become an edit to its authored tree.

## Access rules

| Learning context | Explore | Engine | Transition rule |
| --- | --- | --- | --- |
| Reading text with a valid position | Available | Off by default; opt in | Does not create a puzzle attempt. |
| Reading a puzzle with answers already visible | Available | Off by default; opt in | Retain existing answer-exposure provenance. |
| Active concealed solving | Unavailable | Unavailable | Keep puzzle controls and permitted hints. |
| First mistake, continued concealed practice | Unavailable | Unavailable | A finalized failed score is not permission to expose the answer. |
| Completed solving with solution visible | Available | Off by default; opt in | Keep outcome and active solving duration unchanged. |
| Explicit solution reveal | Available after durable reveal | Off by default; opt in | Commit reveal/exposure before showing assistance. |
| Skipped/timed-out/abandoned with answers still concealed | Unavailable | Unavailable | Require an explicit reveal/review transition first. |
| Retry after review | Unavailable during solving | Forced off | Retain previous exposure; never present retry as unseen practice. |

Do not add a disabled engine switch to ordinary solving chrome. Keep **Show
solution** as the established way to leave concealed practice. Reuse its
existing confirmation and persistence behavior. Analysis must not become a
second path around it. Reading an unfinished cycle puzzle must retain the
existing explicit reveal transition.

## Reading interaction

1. The learner navigates authored moves and variations normally. Beneath the
   board, **Explore position** is discoverable beside the existing controls.
   The initial reader board remains static to prevent accidental mode changes.
2. Selecting Explore captures the exact authored path, position, board
   orientation, selected text location, and text scroll offset. The learner
   does not select a second game or navigate to an unrelated analysis screen.
3. Keep the same board in place and make it interactive for both sides. Show
   **Exploring from 12...Nf6** and **Return to reading** directly below it.
   At an initial/FEN-only position, use **Exploring from starting position**.
4. Replace the active notation area with **Your exploration**, anchored to
   that position. The learner can play, undo, redo, select a previous move,
   and create a sibling branch without losing the previous branch.
5. Keep book commentary available as collapsed **Book context at 12...Nf6**.
   It is attached to the origin, never presented as commentary on the newly
   explored position. Desktop may keep it in a clearly labeled adjacent pane;
   phones prioritize the board and personal line.
6. **Return to reading** restores the exact origin and scroll position in one
   action. It does not jump to the main line or beginning of the chapter.
   Preserve the draft and offer **Resume exploration** when at that origin.

While exploring, first/previous/next/last controls traverse the personal tree;
book navigation stays separately labeled. Selecting a move in book context
returns to authored reading at that move, preserving the exploration draft.
It never silently changes the workspace's anchor. Starting an exploration from
a different authored position creates another draft, not a replacement anchor.

Returning to the anchor by undoing all moves does not automatically leave
exploration. Likewise, reaching a position found elsewhere in the book does
not merge trees. Origin paths matter even when FEN positions match.

Android Back exits exploration first, then follows existing page navigation.
Next/Previous exercise saves the draft, stops analysis, and follows the existing
explicit block transition. It does not implicitly advance after a solve.

### Persistence and source integrity

Autosave personal drafts locally, without modifying original PGN bytes,
imported canonical content, comments, NAGs, authored ordering, or scores.
Keep drafts per block/source revision and authored origin path. In the first
release, retain one personal tree per origin; multiple named studies can wait.

On reopening a block, restore normal reading and show a resume affordance;
do not unexpectedly reopen an engine workspace. A process interruption can
recover the draft, but the engine always resumes paused. Save failures should
retain the draft in memory and offer retry before a transition would lose it.

Source deletion or revision changes must not attach a draft to a different
book by matching FEN. Follow library history-retention rules; mark unresolved
anchors unavailable and allow explicit cleanup. Export, if added later, creates
a new personal PGN and never overwrites the book.

## Engine interaction

Allow **Engine: On** during reading without forcing exploration. It evaluates
the displayed authored position; choosing a suggested continuation opens
exploration anchored there. Neither the toggle nor a changing principal
variation moves pieces automatically.

On activation, show a compact evaluation and one candidate line, labeled
**Engine suggestion**. More candidate lines and deeper analysis belong in
secondary controls. Automatic best-move arrows remain off by default; offer
an explicit **Show suggestion** action. This gives users control over revealing
the answer while keeping a simple initial interface.

Keep evaluation perspective fixed to White and explain it accessibly, e.g.
**+1.2, White favored**. Board flipping does not reverse the sign. Mate values
must identify the favored side. Use restrained updates and never announce every
depth change to a screen reader. An evaluation is an estimate, not a promise
that the authored lesson is wrong.

Distinguish **Off**, **Analyzing**, **Ready**, **Paused**, and **Unavailable**.
Off hides engine-derived evaluations, candidate lines, and arrows, including
cached values. Ready means a bounded search finished; it does not mean a solved
position. When moving to another position, immediately clear the previous
evaluation rather than show it against a new board. Cached results may be
labeled as previous analysis until refreshed.

An engine failure leaves manual exploration usable. Explain **Engine
unavailable. You can still explore moves**, with retry. Do not convert failures
into guessed evaluations or silently switch to a remote service.

### Battery and focus policy

- Start off on entering each block and each new exploration/review workspace.
  An explicit enabled state can continue across moves within that workspace.
  Persist power preferences, not an engine-running flag.
- Default to a low-power bounded search: initially test one worker, one
  principal line, and about one second of search after navigation settles.
  These are starting hypotheses for device profiling, not performance promises.
- Offer **Analyze deeper** for the selected position with a finite budget.
  Continuous search, if added, is a secondary explicit option.
- Cancel obsolete work and stop on backgrounding, disposal, block navigation,
  solving/retry, and thermal limits. Returning to the app shows Paused and
  requires explicit resume rather than silently restarting.
- Rapid scrubbing analyzes only the settled position. Never analyze a whole
  book automatically. Keep caches bounded and compute only visible positions.
- When engine output is hidden or assistance is off, search must be stopped,
  not merely visually hidden. Battery saver can reduce the budget with a
  visible paused/reduced-power state when needed.

These defaults encourage independent thinking without a mandatory delay or a
new educational policy gate. Users remain free to request assistance in reading
and visible-solution review.

## Puzzle review interaction

Preserve the current completed/revealed position on entering review. Offer
**Explore position** there; do not automatically reset to the puzzle start.
Keep **Solution**, **Your tries**, and **Your exploration** as distinct content.

Selecting a legal recorded try offers **Explore this try**, rooted at its
recorded pre-move authored path and including the attempted move. This supports
the question "Why doesn't my move work?" without adding that move to the book
or accepted attempt. Illegal tries get an explanation and exploration from the
pre-move position; never fabricate an illegal board.

At an authored solution leaf, exploration can continue with any legal moves.
Engine replies are selected explicitly; the engine does not take an opponent
turn by default. **Play against engine** is a separate future feature.
Returning restores the precise solution/try origin. Analysis never changes
attempt outcome, distinct-mistake count, accepted moves, or scored duration.

Engine alternatives are labeled separately from **Book solution**. An engine
recommendation outside the authored line does not retroactively turn a rejected
move into a passed attempt. Engine-equivalent puzzle validation requires its
own product and scoring decision.

## Engineering shape

The current `StudyMode` reading/solving/review split should remain. Existing
`ReaderNavigationState` and `GameReaderController` replay authored paths;
`MoveNode` retains immutable source annotations. `ReaderBoard` is currently
static. The new workspace should compose with these rather than loosen their
source contracts.

Introduce an `ExplorationSession` with block/revision identity, exact origin
path, origin context (reading/solution/try), personal move tree and cursor,
return snapshot, and orientation. Replay the starting position plus move history
through `dartchess` for legal move input, SAN, repetition and terminal states.
FEN alone is insufficient for repetition history and must not be the only
input to analysis.

Use a separate versioned draft repository. `StudyPresentationStore` currently
accepts only version 1; do not add draft data or bump its version without a
defined compatibility/migration path. Keep large workspace trees separate from
small reading settings and from scored interaction JSON.

Add an engine service boundary supporting start, analyze, stop and dispose, with
structured results for score, depth, principal variations and completion status.
Prototype local native Stockfish on Android in a worker/process away from the
Flutter UI thread. Verify maintained bindings, supported ABIs, engine/network
asset size, startup behavior, cancellation, and GPL distribution obligations
before choosing a package. Offline operation fits the existing product.

A coordinator derives engine eligibility from answer visibility and learning
phase, not from a toggle or terminal attempt outcome alone. It owns the single
active request. Associate every result with workspace, position history,
request generation and engine settings; discard late results from canceled
requests. Use history-aware cache keys, not FEN-only keys. Persist a reveal
successfully before opening any answer-bearing workspace.

## Delivery plan and acceptance

1. **Validate exploration without an engine.** Prototype reading detours and
   review of a wrong try on a portrait phone. Deliver origin labels, personal
   branches, exact return, draft persistence and lifecycle recovery first.
2. **Integrate bounded local analysis.** Add explicit engine opt-in, one line,
   evaluation perspective, eligibility checks, cancellation and paused/error
   states. Profile on a representative lower-power Android device.
3. **Refine only after observed use.** Add deeper search, optional arrows,
   multiple candidate lines and personal export. Defer full-game review,
   coaching prose, engine play and scoring changes to separate decisions.

Use task-based usability sessions: "Try another defense, then continue reading",
"Explain your rejected move", and "Think without engine output". Observe whether
learners understand line ownership, distinguish book comments from their own
position, and recover their place without help. Evaluate with actual phone text
scale and screen-reader navigation, not only a desktop mockup.

Release acceptance requires:

- Original PGN bytes and authored tree remain unchanged through every detour.
- Return restores authored path, comment/scroll location and orientation.
- Manual exploration works offline without an available engine.
- Failed concealed practice never exposes evaluation, arrows or engine lines.
- Reveal save failure cannot open analysis; retry immediately stops assistance.
- Late results never appear on a different position or after disabling analysis.
- Background/disposal stops engine work, verified through process/CPU profiling.
- Promotion, castling, en passant, FEN starts, repetitions and game-ending
  positions work in personal branches.
- Scores and solving time stay unchanged by review/exploration.
- Source revision changes and interrupted saves recover without overwriting
  unsupported versions or attaching drafts to the wrong content.

Battery budgets, startup limits and deeper-search presets should be set from
measured device behavior before release. Success is a learner confidently
testing an idea and returning to the lesson, not maximum engine usage.
