# Study and puzzle UI

## Hierarchy

The chess position is the primary content whenever a game or position exists.
Use one page title in a fixed app bar following the Material 3 medium layout. Place navigation and the
content menu in the top toolbar, with the title below. Let the title wrap and
size the header to its text. Reserve header space above the body; keep it
out of the body scroll view. Do not repeat it in the body. Classification
is an editing action in the content type menu, rather than a persistent banner.
Keep PGN headers inside collapsed Game Info. Text without a position uses
a readable column, limited to 720 logical pixels.

During a puzzle, side to move is the immediate instruction. Exercise progress
is secondary. Keep authored solutions and metadata hidden until review.
Each book has a clear `Read` or `Solve` intent. Standalone puzzle interactions
remain visibly separate from cycle-scored progress. In a cycle, use its frozen
completion policy and ordered selection consistently even if the set is later
edited. Choose policy per standalone solve or per cycle, never as a per-book
preference.
Place the live side-to-move label directly above the board in both solving and
review. Keep exercise progress and the frozen cycle policy in the supporting
details pane, so both states retain the same board hierarchy.

## Layout

Use `StudyLayout` for study games, puzzle previews and active puzzles. Center
the board in its region. On portrait phones, use the full available width
and size it independently of scrolling. On wide or landscape screens, put
supporting content beside the board and cap the board at 520 logical pixels. On smaller screens, put that
content below it. Keep the position stationary while supporting content scrolls.
Reader navigation stays directly below the board, with a Flip board icon
after the move buttons. For positions without moves, show only Flip board. Bring the current move into
view as navigation changes. Solution review uses the same shared practice
board frame and current position as the active exercise. Reading and review
reuse the board/moves layout and icon navigation controls; use clickable
notation with a selected-move highlight. Keep move navigation beneath the board,
separate from Next exercise. Future notation stays concealed during solving.

## Spacing and type

Use 16 pixels of page padding, 24 between desktop regions, 12 between related
sections, and 8 between a label and its content. Use theme typography:
`titleMedium` for section headings, `titleSmall` for secondary headings,
`bodyMedium` for notes, and `labelMedium` for variation labels. Avoid redundant
section labels and decorative containers that compete with the board.

## Actions and state

Use filled buttons for starting or resuming practice. Use outlined or text
buttons for secondary actions. Reveal and skip retain confirmation because
they finalize the attempt. Highlight the current move with the theme's
secondary container color. Preserve accessible labels, disabled states and
live announcements of errors.

The first incorrect move finalizes the scored result but leaves practice
interactive and concealed. Explain that the score is final while allowing the
learner to continue. Hints make a completed result Assisted. Showing a move
finalizes as Revealed before advancing the shared board; never present that
attempt later as Passed. Review navigation is user controlled, and moving to
the next exercise requires an explicit **Next** action.

Show a hint by highlighting its origin piece square on the board, rather than
displaying hint prose. Include an accessible description of the granted cue.
After a learner move, briefly display the committed position before playing an
automatic opponent reply; keep gestures disabled throughout that transition.
Keep the first rejected move in notation; repeated incorrect practice moves
provide feedback without adding more rejected entries.

The training-set editor keeps Save visible outside scrolling content. Place
search/filter and bulk selection controls before long previews and results.
Label bulk selection Select all matching results, showing the current count;
fit dropdown labels to the available width and preserve full menu labels where
space permits.

Render long candidate and preview lists lazily in one scroll viewport. Avoid
Columns containing every candidate or nested shrink-wrapped selection lists.
The new-set form must appear while library metadata loads. Bulk selection uses
all matching metadata, while only nearby rows are laid out. Keep metadata
filtering separate from name/selection updates, and publish bulk additions as
one draft update.

For a newly scored first error, keep the solution concealed until the learner
completes continued practice or explicitly reveals it. A legacy finalized
attempt without a saved interaction snapshot may open read-only review.

Use the shared `FlipBoardButton` beneath reader and puzzle boards. Puzzle
supporting panes use 16 pixels of padding on every side, including above the
Practice heading and below its action.
