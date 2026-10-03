# Implementation plan: Continuous study flow

Date: 2026-10-02. Status: adopted; implementation authorized on 2026-10-02.

Specification: [spec.md](spec.md). Assessment: [research.md](research.md).
State/data contract: [contracts/study-flow.md](contracts/study-flow.md).
Ordered tasks: [tasks.md](tasks.md).

## Product design

Use one book study shell, with a compact context header, board/content area,
and persistent action region. Read, Solve, and Review are explicit modes on
the same block. Content-only blocks use the space for text.

```text
Book name                  [Book settings]
Section, when available · Block 24
Casual practice · Solving
┌───────────────────────────────────────┐
│                  Board                │
└───────────────────────────────────────┘ ◯
Feedback / selected move navigation
Scrollable notes, notation, or Your tries
─────────────────────────────────────────
State-specific actions (always reachable)
```

| Mode | Persistent actions | Secondary controls / details |
| --- | --- | --- |
| Reading puzzle | Solve puzzle; Previous/Next block | Book preferences; board move navigation when reading solutions. |
| Solving / failed practice | Hint; Show solution | More: Pause, Skip, practice options, Previous/Next block; contextual Show move after hint; compact Flip near board. |
| Review | Next block (Back to book at end); Try again | Board first/previous/next/last, alternatives, Return to played line, Previous block, reading detail. |
| Reading non-puzzle | Previous/Next block | Existing notation/comments and board navigation if present. |

Fixed means outside the notes/history scroll view; secondary actions may be in
an accessible menu. One shared chrome owner prevents duplicate top/bottom
controls. Show assistance consequence beside the relevant action/menu rather
than repeating a paragraph below every move history. Remove 1-of-1 progress in
single casual solving; use neutral block identity. Cycle mode keeps its useful
progress and timing.

The accepted space refinement places cycle title, item/section context, mode,
and session clock in the app bar, with one pause/resume icon. The turn dot sits
in a narrow gutter at the active side's corner and moves when orientation
changes; its explicit semantics replaces the previous side-to-move text row.
Review removes its selected-move caption, keeps selected move and position
semantics, groups uninterrupted move tokens in compact wrapping rows, and
renders recorded wrong moves as informational text. See [space-refinement.md](space-refinement.md).

## Technical approach and ownership

1. Replace the casual `Navigator.push` entry with a block-scoped presentation
   coordinator owned by the existing book route in `lib/app/navigation.dart`.
   It coordinates reading, controller lifecycle, review, navigation, and safe
   persistence; chess acceptance remains in the evaluator/controller.
2. Refactor `LibraryPuzzlePractice` as an embedded surface. Remove its chooser
   entry gate and `_CasualPuzzlePage` route shell when the unified owner can
   preserve all lifecycle behavior. `GameReaderPage` owns book chrome or
   delegates it to one new study shell, avoiding nested Scaffolds.
3. Extend `StudyLayout` with explicit header/action slots or compose them in
   the shell. Calculate board size after reserved controls/header/SafeArea
   height. Details scroll independently; wide views retain board and details
   side by side. Text scaling takes actual action layout into account.
4. Pass an allowlisted context projection from source/index metadata to
   solving and review. Use source displayName and X-Section, with a neutral
   Block N fallback. Do not display raw theme/answer comments before reveal.
5. Introduce explicit rejection identity/history in interaction version 2.
   Replace blanket `suppressRepeatedWrongPractice` with position-aware
   deduplication. Save later distinct rejects via interaction storage, never
   `recordSubmittedMove` on a finalized scored attempt.
6. Add rejection feedback phase to controller/presentation coordination.
   Inspect pinned chessground animation options first; use native support if
   suitable or a small board-local overlay. Do not place a rejected FEN into
   accepted replay/history. Preserve accepted-reply delay and prediction rules.
7. Refactor review notation into a solution-safe move-tree presentation using
   common move-button styling. Reuse reader navigation ideas without passing
   full `ChessContent` into concealed solver widgets. Existing reader tree
   needs adaptation for branch collapse and nested-path clarity; simply
   embedding it would not satisfy review requirements.
8. Shared solving/review widgets accept labeled navigation callbacks. Casual
   routes say Next block; cycle pages retain set order and Finish cycle. Test
   shared behavior without merging these navigation policies.

## Delivery sequence

| Phase | Deliverable | Acceptance gate |
| --- | --- | --- |
| 0 | Adopt feature requirements, reconcile 001 policies, review state/layout sketches. | No contradictions about wrong moves, disclosure, next-block intent, or scoring. |
| 1 | Versioned interaction history and rejection deduplication. | A/B/A/C/B, restart, promotion, different position, failed-write cases pass; score unchanged. |
| 2 | One study shell, direct solve, contextual header, fixed controls and defaults. | Single action/route; small-screen/large-text controls visible; safe leaving/restoring. |
| 3 | Rejection hold/return and reduced motion. | Cue visible, accepted position durable, input serialized, disposal/background safe. |
| 4 | In-place review with contextual branches and explicit Next block. | Nested variations, reached path, comments, retry, non-puzzle continuation work. |
| 5 | Integration and physical-device acceptance. | End-to-end reading → solve/fail → review → instruction/game; lifecycle and cycle regression gates pass. |

Phases 1–4 form one user-facing release; partial work must not be described as
the completed continuous flow. Build foundations first, then validate the
complete experience against the requested sequence.

## Storage, compatibility, performance, and dependencies

Existing Flutter, dartchess, chessground, Drift, and SQLite are sufficient;
no added dependency or licensing change is planned. Imported PGN remains
unchanged. Extend existing casual/cycle interaction JSON and presentation
settings with explicit versions and lazy legacy conversion. Preserve all
scored attempt IDs and aggregate metric definitions. Never recreate previously
discarded mistakes. Preserve saved per-book Read/Solve values; unset books use
Read. Existing unfinished interactions retain their policy on restore.

Load only current-block content and indexed context/adjacent metadata. No
full-source parse or list scan to produce a header. Retain baseline p95 indexed
block-open target under 500 ms on the reference Android device. For already
loaded content, show a busy/direct-solving response within 100 ms and target
interactive solving within 500 ms at p95. Intentional rejection hold/return is
measured separately from persistence/input processing. Cap rendered move
history/notes using lazy sections rather than growing nested shrink-wrapped
trees without bounds.

## Planned validation

Unit: distinct rejection keys, restart/legacy conversion, repeat feedback,
scored immutability, exposure state, accepted replay, and durable-write failure.

Widget: direct Solve, stable route/header, essential actions without scrolling,
no answer disclosure through context/accessibility, adaptive geometry, nested
variation selection/return, and temporary rejection rendering with fake time.

Integration: reading a mixed book → solve → fail → distinct mistakes → review
→ next instruction → next puzzle; retries, preference behavior, last block,
background/process recovery, concurrent input, failed navigation writes, and
cycle order/timing isolation. Use existing suites as regression anchors, then
run relevant checks once implementation exists.

Manual acceptance on the reported phone: thumb reach, actual rejection hold
and travel, 2.0 text scale, long comments, nested alternatives, source without
section tags, and book position after Back. Screenshot comparison helps
confirm hierarchy; automated checks do not replace this acceptance.

## Constitution Check

| Principle | Proposed compliance |
| --- | --- |
| I — PGN fidelity | Presentation/history changes only; preserve source/tree/comments. |
| II — Explicit semantics | Stable block/attempt identity and existing classification; metadata fallback never invents content. |
| III — Large-file/offline | Current block and indexed neighbors only; all state local and offline. |
| IV — Puzzle integrity | Authored legal acceptance; safe context; concealed failed practice until completion/reveal. |
| V — Attempt history/timing | First error stays finalized; later practice history separate; pause/restore stays durable. |
| VI — Explainable scoring | No new score formula; label practice mistakes distinctly from scored errors. |
| VII — Separation | Shell owns mode, evaluator owns chess, repositories own score/interaction storage. |
| VIII — Ownership/recovery | Transactional first error; separate later writes; failures retain committed state; no uploads. |
| IX — Simplicity | Reuse existing stack/components; defer engine, batches, arbitrary legacy inference. |

Accessibility and phone-priority gates are explicit in US2 and US3. No
constitution exception or amendment is proposed. Feature 001's conflicting
lower-level suppression rule must be reconciled before implementation.
