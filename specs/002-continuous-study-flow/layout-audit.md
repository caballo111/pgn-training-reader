# Casual and cycle puzzle layout audit

Assessed from the current implementation on 2026-10-02. This is a source-level
layout assessment, not new Android/iOS or golden verification. The maps below
record the state before implementation; the implementation follow-up is
recorded at the end of this document.

## Active solving map

| Area | Casual book practice | Cycle practice | Assessment |
| --- | --- | --- | --- |
| Header | Book/section/block in app bar; mode in a separate padded body row; gear in app bar. | Set/mode/session clock and cycle progress in app bar; pause action. | Context and session controls intentionally differ. Mode placement and header height unnecessarily differ. |
| Flip | Persistent at the right below the board. | Inside More in the footer. | Same board operation moves between locations and requires different effort. Priority 1. |
| Starting turn | Centered in the fixed row shared with Flip. | First child of scrollable details, with 16-pixel padding. | Same information has different distance from the board and scroll behavior. Priority 1. |
| Board space | Reserves a 48-pixel control row for Flip. | Has no board-adjacent control row while solving. | Available board height differs because of control placement; exact board dimensions also depend on viewport/header/details constraints. Priority 1. |
| Footer | Previous, Hint, eye, optional Show move, Next/Back to book. | Hint, eye, optional Show move, More. | Navigation/session differences are intentional. All tokens share a centered Wrap, so common actions shift horizontally between modes rather than retaining a shared assistance area. Priority 1. |
| Footer spacing | 12-pixel top padding in portrait. | Default 4-pixel top padding in portrait. | Unnecessary spacing difference. Both use zero top padding in the ordinary wide layout. Priority 2. |
| Hint escalation | Show move appears as an additional text button after Hint. | Same behavior. | Shared problem: insertion can move subsequent controls or create another footer row on narrow screens/large text. Priority 2. |
| Pause/Skip/More | No manual Pause, Skip, or More. | Pause in app bar; Skip and Flip in More, last in footer. | Intentional mode-specific controls, consistent with latest user direction. Lifecycle pause remains separate from the visible manual controls. |

The common Hint, eye, and Show move controls already share their implementation,
styles, tooltips, and assistance behavior. Rejected variations and authored-text
concealment also use the common solving surface. These are not mode-specific
inconsistencies.

## Solve-to-review map

| Area | Casual | Cycle | Assessment |
| --- | --- | --- | --- |
| Flip | Moves from the right below the board into centered review move controls. | Moves from More into visible review move controls. | Common operation moves at the phase transition in both modes. Keep its board-adjacent location stable. Priority 1. |
| Next | Icon while solving; labeled filled button in review. | No ordinary Next while solving; full-width Next exercise/Finish cycle in review. | Cycle gating and labels intentionally differ. Casual button shape/emphasis changes; stable navigation placement is preferable. Priority 2. |
| Previous | Disabled icon at the first block while solving; absent in review when no previous callback exists. | No previous exercise navigation. | Cycle absence is intentional. Casual boundary treatment is inconsistent and shifts neighboring actions. Priority 2. |
| Retry | Secondary Try again beside book navigation. | Not offered by the cycle owner. | Intentional attempt/scoring difference; do not add cycle retry solely to match layout. |
| Review board controls | Outcome, line navigation, Flip, Return to played line. | Same shared component. | Consistent; outcome remains noninteractive and last. |

## Recommended common structure

1. Put mode in the app bar in both modes. Retain the correct book/cycle context;
   session clock and Pause remain cycle-specific.
2. Use one consistent row below the board for the initial turn caption and
   persistent Flip, in solving and review. Preserve turn semantics and minimum
   touch targets; avoid spending an extra row for the caption.
3. Give Hint/eye/Show move a shared assistance area. Anchor book Previous/Next
   at the footer edges; keep cycle More last. Allow the assistance group to
   adapt without shifting the outer navigation controls.
4. Use one compact spacing baseline for the shared solving footer. The book
   reading footer may retain its own layout because Solve puzzle is its primary
   action.
5. Keep Previous visible but disabled at book boundaries in both phases. Keep
   casual navigation in stable positions as review actions become available.

These recommendations preserve the
intentional mode differences: book source navigation, cycle scoring/order,
session timing/pause, and the absence of a casual Skip/menu.

## Implementation anchors

- `lib/features/puzzle_solver/presentation/puzzle_solving_view.dart`: casual
  board controls, starting-turn placement, shared footer Wrap and conditional
  Show move/More.
- `lib/app/library_puzzle_practice.dart`: separate mode row, book footer
  spacing/navigation, review retry/previous/next callbacks.
- `lib/features/training_session/presentation/active_session_page.dart`: cycle
  app bar, Pause/Resume, review progression, shared solver configuration.
- `lib/features/puzzle_solver/presentation/puzzle_solution_review_view.dart`:
  review controls and footer boundary behavior.
- `lib/shared/presentation/study_layout.dart`: control-height reservation and
  portrait/wide footer spacing.

## Implementation follow-up

Implemented on 2026-10-02 after user authorization:

- Both solving modes use the same fixed board-control row, with centered
  starting-turn caption and trailing Flip. Review and reading anchor Flip in
  that same trailing position, outside the wrapping move controls.
- The shared layout accounts for the trailing Flip slot, wrapped navigation
  rows, and scaled initial caption height. Caption space stays reserved after
  play begins, keeping the solving board stationary.
- Embedded book mode moves into the app bar title row. Casual practice and
  source context remain in its subtitle. A shared typed StudyMode provides the
  reading/solving/review labels in book and cycle headers. Standalone consumers
  retain a body mode label when there is no owning book header.
- Assistance occupies a centered area with reserved widths and label height at
  the active text scale. Hint changes to Show move in its existing slot, keeping
  the eye button stable. Very narrow slots use labeled/tooltip icon actions.
  Book Previous
  and Next stay anchored at the outer edges; cycle More stays last and contains
  Skip. Flip is no longer in More.
- Solving footer spacing uses the shared 4-pixel baseline. Review retains the
  visible disabled Previous at book boundaries. Its Next remains a labeled
  primary action at the right; cycle progression remains full-width.

DRY abstractions: StudyBoardControls owns the common caption/orientation row;
StudyNavigationControls composes it with move navigation; shared previous/next
buttons own tooltips, icons and target sizes across book surfaces; StudyLayout
owns space reservation and footer insets. The reader uses one puzzle builder
with an explicit mode callback rather than separate mode-aware and legacy
builder paths. Scoring, lifecycle handling and progression remain in their
existing owners.

Initial validation used static analysis and diff checks only. A subsequent
authorized refresh regenerated the four phone goldens; all five focused
tests passed during update and again against the saved references. No tests
were added. Android/iOS physical visual acceptance remains pending.
