# Personal exploration and local analysis

Status: implemented, 2026-10-09. Automated application checks pass; native
Android build verification is blocked. See [validation](validation.md).
Input: [UX proposal](../../docs/analysis-and-exploration-plan.md).

## Outcomes and scope

Learners can investigate any displayed reading or visible-solution review
position, retain personal branches independently of authored PGN, and return
to their precise reading/review place. Engine assistance is optional and local.
This feature includes manual exploration, durable drafts, reading and puzzle
review integration, bounded Stockfish analysis, and lifecycle-safe cancellation.
It excludes engine-equivalent puzzle scoring, remote services, automatic coach
prose, full-game reports, personal PGN export, and play against the engine.

## Decisions

- Explore position is explicit; normal reading boards stay static.
- Reading/solving/review remain the top-level phases. Exploration is a nested
  workspace; Android Back returns to its origin before leaving the page.
- Engine is off on entering a block/workspace, and may be enabled while reading
  without opening exploration. Suggested moves only play on explicit selection.
- Solution visibility gates assistance. Failed concealed practice, skipped or
  timed-out concealed states, and retries cannot access it, even with final scores.
- A personal tree is stored per block/source revision/origin occurrence. Repeated
  FEN positions are not merged. No draft data enters source PGN or attempt JSON.
- Return preserves authored cursor, orientation and detail scroll. Drafts are
  autosaved; reopening offers resume but defaults to authored reading and engine off.
- The origin's book text is labeled/collapsed while exploring; comments never
  attach to learner-generated positions. On phones personal moves take priority.
- Legal recorded tries may be explored with the attempted move seeded. Illegal
  tries instead open their pre-move position with an explanatory cue.
- One-thread, one-line, roughly one-second search is the default. Analyze deeper
  uses a finite five-second budget. Rapid navigation waits 200 ms before searching.
  Background/inactive/detached, route removal, retry, engine off and navigation
  cancel work and clear output. Foregrounding requires explicit resume.

## Acceptance scenarios

1. Navigate an authored variation, scroll its comments, flip the board, explore
   alternate moves and sibling branches, return: authored path, scroll and
   orientation are restored, and source data is equal to its original value.
2. Reopen the same block/revision/origin: a saved draft can resume with engine off.
   Different revisions and identical FEN at different paths do not share drafts.
3. Explore from a FEN-only block or beyond a solution leaf; legal promotion,
   castling and en passant work, invalid moves do not mutate the tree, and
   terminal positions do not accept further moves.
4. Engine opt-in shows fixed White-perspective evaluation and an explicit
   suggestion. Turning it off hides all engine output and stops search without
   losing personal moves. Flipping does not invert evaluation.
5. Scrub rapidly, disable, background or replace content during initialization
   or search: late results never appear on another position, the engine stops,
   and manual exploration remains responsive/usable on engine failure.
6. First failure with concealed continued practice renders no exploration,
   evaluations, arrows or suggested lines. Reveal persistence must succeed
   before assistance becomes accessible. Retry removes assistance immediately.
7. Explore a recorded try after visible review, return to review, and verify
   original accepted path, rejected history, immutable outcome and duration.
8. Save failure preserves the draft in memory with retry feedback. Workspace
   return/page transitions must not silently discard uncommitted work. Unknown
   future draft versions fail recoverably and are not overwritten.
9. Portrait 320px and enlarged text remain usable without overflow; essential
   return and engine controls stay reachable. Controls have accessible labels;
   engine depth updates do not create repeated screen-reader announcements.

## Failure and performance behavior

No valid position means no analysis control. Missing engine/platform support
shows an actionable unavailable state; manual moves remain available. Source
identity/revision changes cannot recover drafts by FEN. Save and initialization
errors never reveal concealed content or rewrite unsupported stored data.
Only the active visible position is searched. Default budget is 1000 ms,
deeper budget 5000 ms, one worker, one PV and 16 MB engine hash; no whole-book
analysis or unbounded search. Device startup/battery/thermal profiling is a
recorded release gate; automated checks verify lifecycle requests and deadlines.

## Compatibility

Existing scoring, reveal confirmations, casual exposure provenance, cycle
timing, source fidelity, and existing reading settings remain normative.
Existing tests may explicitly disable the new analysis affordances when their
scope is legacy layout, but answer-leakage tests must cover the default product.
