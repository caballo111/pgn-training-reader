# Space and semantics refinement

User-directed follow-up to feature 002, implemented on 2026-10-02.

## Accepted changes

- Cycle set name, mode, and session clock use the app bar title row; cycle
  progress and available section use its subtitle. One action icon toggles
  pause/resume. The separate metadata strip and pause banner are removed.
- Mode and clock have their own visible slots so they do not disappear at the
  end of a long subtitle. Full title/context remains available through
  semantics and tooltips. Large text has an adaptive toolbar height.
- The shared board frame has no visible turn indicator or side gutter. The
  square uses its full available width; turn information remains semantic.
- At the start of a puzzle, centered White to move / Black to move text appears
  below the board until the first accepted or rejected move. This applies to
  book practice and cycle solving. The caption does not duplicate the board's
  existing turn announcement for assistive technology.
- Review has no selected-move caption above the board. Selected move buttons
  retain selected state, annotation, and activation semantics. The board
  describes its current authored position, including annotations, for screen
  readers.
- Uninterrupted moves share compact wrapping rows. Comments and alternatives
  break a run at their actual branch point. The Return to played line action
  is a labeled icon beside the move-order controls. Interactive targets retain
  a 48-pixel minimum size.
- Rejected moves appear as compact, inset variations beneath the move at their
  actual authored branch point, each with its move number and a red cross.
  The same notation appears during ongoing practice (including before the
  first accepted move) and finalized review, replacing Your tries and its
  count. Repeated submissions at the same position appear once. Attempt rows
  have no button, selection, or navigation semantics; each is announced as an
  Incorrect attempt. Active practice exposes only attempted and accepted moves,
  preserving the gate on future authored content. Review follows the selected
  authored branch; returning to the played line restores its attempt variations.
- Automatic opponent moves have no visible reply suffix. Their provenance,
  and that of shown moves, remains available in semantics.
- Review outcome uses a noninteractive icon in the move navigation group,
  with distinct shapes, contrast-aware color, tooltip, and explicit outcome
  semantics. Failed practice retains its original failed scored result.
  The icon follows all move controls on their right, with inset spacing within
  its existing slot to distinguish status without increasing row width.
- Notes render directly as individually scrollable paragraphs; Puzzle notes
  and Solution line headings are removed. The visible ply counter is removed;
  current position/solution length remains available through semantics.
- Cycle review says Next exercise, or Finish cycle at its end. That primary
  button fills the action row. Book review retains Next block/Back to book
  and its secondary Try again action in one row, with the primary action wider.
- Board sizing reserves the actual number of navigation-control rows, including
  result and Return to played line icons, so wrapping does not bury actions.
- Active solving keeps Hint visible and uses a compact eye icon for Show
  solution, with a tooltip, accessible name, and 48-pixel target. After a hint,
  Show move replaces Hint within a reserved slot, preserving the eye position.
  Cycle Skip puzzle stays in More, always last in the action row. Cycle
  pause/resume lives in the app bar only. Casual practice has no Pause, Skip,
  or More action; Flip stays visible below the board in both modes with a
  48-pixel target, anchored at the right during solving, reading and review.
  The initial turn caption shares that row, without duplicating its semantic
  announcement. Background pause/resume and departure persistence remain active.
- Finalized exercise review hides Pause because its active timer has stopped.
  Resume remains available if background lifecycle handling pauses the session,
  so users can resume before advancing. Active cycle solving/reading retains
  Pause; casual practice has no manual Pause control.
- Book block navigation appears once, in the bottom action area. Reading puts
  Previous on the left, Solve puzzle in the center, and Next/Back to book on
  the right. Active book solving retains compact Previous/Next icons at the
  ends of its assistance controls; review retains Previous beside Try again
  and Next. These use the existing save-before-departure handlers. Cycles do
  not gain book navigation controls.
- Book settings moves into the owning app bar, aligned with its other actions.
  Embedded book mode shares the app bar title row; source context and Casual
  practice use its subtitle. Standalone practice retains its own mode/settings
  row. Both solving modes use the shared 4-pixel footer top inset. Common
  assistance slots remain centered while book Previous/Next or cycle More are
  anchored at the footer edges. Book Previous stays disabled at boundaries in
  both solving and review.
- Reading footer top padding is reduced to 4 pixels, bringing the actions
  closer to the text viewport while retaining minimum touch target sizes.
- The Solution already viewed banner is removed: the exposure marker records
  authored material being available in reading/review, rather than an eye-icon
  click. Persistence and exposure-save failures continue to be handled.
- Casual solving conceals all imported notes, comments, and authored variations
  until completion or explicit Show solution. A first wrong move retains this
  concealment during continued practice, despite its finalized failed score.
  Read is available only in review. Source context, feedback, played moves,
  and rejected attempts remain visible; unstructured imported text is not
  treated as a safe instruction. The presentation projection enforces the
  concealment for explicit solving/failed-practice phases.

## Semantics

Active solving removes the visible policy label (such as Key moves), Moves
played heading, and No moves yet placeholder. Accepted move notation appears
only once available, with a Moves played semantic label. Rejected variations
appear as soon as recorded, even when accepted notation is empty. Feedback,
prediction instructions, hints, errors, and pause state remain available.

The board has a live `White to move` / `Black to move` semantic label without
a visible marker or tooltip. Interactive move tokens expose one label, selected state, and
activation action, avoiding duplicate child announcements. The cycle header
exposes set name, study mode, session active time, and full cycle progress/
section/active time without duplicating tooltip text.

## Validation state

`flutter analyze lib test` and `git diff --check` pass for this refinement.
Existing widget expectations were updated for the new turn tooltips, board
position descriptions, and app-bar controls. No tests were added or run in
this pass. The earlier full-suite results in validation.md describe the
previous UI revision. A later authorized golden refresh regenerated all four
phone snapshots and passed the focused suite's five tests, both during update
and again in comparison mode; see validation.md. Android/iOS physical and
accessibility-device acceptance remain pending.
