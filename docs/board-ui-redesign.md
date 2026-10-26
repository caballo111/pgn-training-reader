# Board UI redesign

The board is the visual focus. Move stepping sits immediately below it, followed by scrollable book text or review notes. A fixed bottom icon toolbar keeps the primary actions reachable while notes scroll, and its navigation never moves:

1. Previous block, anchored to the leading edge.
2. Up to two contextual actions at the center: mode toggle, Reset board, and Analyze position in priority order. They crossfade in place, with a fade and slight rise when the surface appears.
3. Overflow menu for every remaining action, between the center cluster and Next.
4. Next block (or back to the book at the end), anchored to the trailing edge.

Every available icon has a tooltip and an accessible label, and retains a 48px minimum target. Unavailable navigation keeps its slot but is disabled, so Previous and Next never shift. A toolbar with no actions at all takes no space. When more than two contextual actions are available, or the pane is too narrow to clear the anchors, the extras move into the overflow menu. Flip board, Compact board, and context-specific assistance always live in the overflow menu. Scored attempts retain their grading boundaries: analysis is available after finalization; reset/read controls are hidden where no safe transition exists. Casual practice can switch to reading after recording the exposure and can restart after recording the abandoned attempt.

Analyze replaces the reading/review surface with the interactive analysis board. The header's back arrow saves the draft and returns to the originating reading/review position. The engine controls live inside this mode. Reset returns to the analysis origin while preserving the variation tree; clearing the tree is a separate action with Undo.

Move arrows are passive overlays, work with either board orientation, remove duplicates, and display at most three distinct moves. Reading/solving can show the last played move. Active solving never draws upcoming solution moves. Analysis prioritizes the selected continuation and can show sibling variations. The current engine exposes one principal variation, so its first legal move is the one engine candidate shown. Later plies of that line are never presented as alternative moves from the current position. Stale/hidden/off engine output clears its arrow.

Block transitions keep the outgoing block painted while the target loads. A puzzle initializes offstage, then replaces the old page once ready, preserving its initialized state. Input, keyboard focus, and system back are blocked during this transition. Setup failures promote a working Retry view. Hidden solving stays paused and resumes only when visible and the app is in the foreground. Each transition saves the outgoing presentation once; the old page is disposed after promotion.

## Validation

| User requirement | Regression evidence |
|---|---|
| “add arrows for moves and engine suggestions, lets do 3 arrows max.” | `sanitizes malformed and duplicate moves and caps at three`; `publishes one legal current engine move and clears stale arrows`; `analysis arrows follow selected move before sibling alternatives and flip with the board` |
| “text beneath board.” | `phone reading keeps notes below board and icon actions at bottom` |
| “i think we should go for icon buttons.” | `previous and next stay anchored while context changes` |
| “a more button, pick hamburguer or 3 dots, pick left or right, if neccessary.” | `center keeps at most two contextual actions and overflows the rest` |
| “a back block button.” | `prose-only reader keeps previous and next block actions`; `previous and next stay anchored while context changes` |
| “a button that toggles between read mode and solve mode (could be a book and attack icon, kind of swords i think it is)” | `solving swaps the contextual action to the book`; `review toolbar returns to reading mode through its accessible action`; `reading cursor survives solving and returning to reading` |
| “a reset button, and analyze button and a next button.” | `center keeps at most two contextual actions and overflows the rest`; `Reset board returns to the authored origin and preserves the selected tree`; `Analyze snapshots the selected origin and orientation` |
| “analysis navigates to analysis board, there is back arrow to exit this mode.” | `Analyze opens the saved current-origin exploration`; `header menu clears exploration with undo while return stays in the header`; `return waits for the latest draft write` |
| “in the bottom bar, when controls are not usable, do not shown them.” (superseded by the anchored toolbar) | `disabled navigation keeps its slot from moving`; `toolbar with no actions takes no space` |
| “for analysis, use a microscope icon” | `center keeps at most two contextual actions and overflows the rest` checks the Analyze position entry when it is overflowed; the failed-review snapshot shows it inline |
| “persistent bottom toolbar; previous left, next right, contextual actions in the center; fade and slight upward entrance; crossfade on change; overflow for secondary actions; no movement in previous and next.” | `previous and next stay anchored while context changes` (asserts both anchors and the centered cluster before and after a crossfade); `contextual action rises and fades into its reserved slot`; `center keeps at most two contextual actions and overflows the rest`; `narrow panes fall back to one center action`; `disabled navigation keeps its slot from moving` |
| “is it normal a flickering when moving through blocks?” | `library puzzle transitions keep content visible through delayed setup` checks intermediate visible content, no visible spinner, safe back handling, single save, and failure recovery; `staged solving remains paused while hidden until the app resumes` checks background timing |

`flutter test --reporter expanded`: **510 passed**, exit 0. `flutter analyze`: **No issues found**, exit 0. Updated the reading and puzzle review snapshots after visually inspecting their changed layouts. Screenshot tolerances are unchanged. This verification uses widget tests and rendered snapshots, not an Android device walkthrough.

Previews: [Reading](../test/golden/board_ui/reading.png), [Analysis](../test/golden/board_ui/analysis.png).
