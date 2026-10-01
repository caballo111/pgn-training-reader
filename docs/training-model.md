# Training model

A **Collection** (book/source) is an imported PGN and its derived searchable
index. Puzzle entries can be read normally or solved. A remembered per-book
Read/Solve preference changes presentation, without changing classification.

A **Set** is a saved, ordered selection from one or more collections. Select
individual entries, filtered results, exercise ranges or halves, then review
and save. Text entries are included explicitly and never count as puzzle scores.
Removing a set hides/archives its definition; imported content and saved history
are retained. The app explains removal before confirmation.

A **Cycle** is one pass through a snapshot of a set's ordered membership and
completion policy. Editing a set affects future cycles. One active cycle is
allowed per set. A cycle can span sessions and calendar days.

A **Session** is one study period in a cycle. An **Attempt** is a scored puzzle
interaction. Pause, Back, inactivity and restart close active timing segments;
unknown time after termination and time between days are excluded. Wall-clock
start/end timestamps provide history, while summed active segments measure
solving time. Resume restores the saved interaction/cursor before selecting
another exercise.

A first incorrect/illegal submitted move finalizes Wrong move. You can keep
practicing with the solution concealed; later success never changes that score.
Hint highlights a piece and makes successful completion Assisted. Show move or
Show solution finalizes an unfinished attempt as Revealed. Skipped, Timed out
and Abandoned are separate outcomes. Finalized scores remain immutable.

Key Moves finishes at a branch-local `✔` marker, otherwise at its leaf. All
Moves finishes at a leaf. Ordinary authored opponent replies play automatically;
a marked opponent reply in Key Moves requires the learner's prediction.
Review retains the board position/orientation and exposes notation/variations.
Next exercise and Finish cycle require explicit action; review time is unscored.

**Casual solving** from a book is persisted separately, has no timer, creates no
cycle/session rows and never changes cycle aggregates. Legacy synthetic library
cycles retain their old history. Reading an unfinished cycle puzzle reveals it
explicitly before exposing answers.

Accuracy is Passed / all finalized attempts, including Assisted in the
denominator. An empty denominator is unavailable. Reports show raw outcomes,
active durations and assistance; comparisons suppress numeric deltas when cycle
membership or completion policies differ. Unknown legacy snapshots are reported
as unavailable rather than guessed.
