# Product ideas backlog

Capture ideas here before they become requirements. An idea does not authorize
implementation or change the accepted feature specification. When selected,
write or amend a feature spec, then its plan and tasks; link the backlog entry
to those artifacts and update its status. Use assessment-issues.md for defects
found during acceptance, rather than mixing defects with future product ideas.

| ID | Idea | Status | Next decision |
| --- | --- | --- | --- |
| IDEA-001 | Improve the main/library screen UI: clearer hierarchy, book browsing and primary actions. | Proposed, 2026-10-01 | Define the desired browsing flow and visual examples in a UI feature spec. |
| IDEA-002 | Add a distinctive application icon and Android launcher/adaptive icon assets. | Proposed, 2026-10-01 | Choose visual direction and artwork rights; generate platform assets in a dedicated task. |
| IDEA-003 | Improve board screen layout to maximize usable study content and keep buttons accessible. | Partially addressed by Phase 16 accessibility work; visual redesign proposed | Use accessibility-review.md and physical phone feedback to define any remaining layout spec. |
| IDEA-004 | Training-history backup/export and validated restore (original Phase 15). | Deferred by owner, 2026-10-01 | Revisit before account/synchronization work or when portable history backup becomes a priority. |
| IDEA-005 | Explore authored positions and review tries with optional local engine analysis. | Implemented; native Android verification blocked, 2026-10-09 | Complete the build and device gates in [validation](005-analysis-exploration/validation.md). |

The scope decision to proceed with Phases 16/17 while deferring Phase 15 is
recorded in 001-pgn-training-reader/tasks.md and release-review.md. Export and
restore are not represented as completed MVP behavior.
