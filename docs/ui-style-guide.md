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

## Layout

Use `StudyLayout` for study games, puzzle previews and active puzzles. Center
the board in its region. On portrait phones, use the full available width
and size it independently of scrolling. On wide or landscape screens, put
supporting content beside the board and cap the board at 520 logical pixels. On smaller screens, put that
content below it. Keep the position stationary while supporting content scrolls.
Reader navigation stays directly below the board, with a Flip board icon
after the move buttons. For positions without moves, show only Flip board. Bring the current move into
view as navigation changes. Solution review should adopt this layout in a
subsequent pass.

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

Use the shared `FlipBoardButton` beneath reader and puzzle boards. Puzzle
supporting panes use 16 pixels of padding on every side, including above the
Practice heading and below its action.
