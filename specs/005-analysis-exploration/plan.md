# Implementation plan

## Constitution Check

I: source PGN/MoveNode remain immutable; separate personal trees. II: only
existing text and visible puzzle review gain controls; side to move comes from
dartchess replay. III: offline local Stockfish, no remote accounts or content
uploads; retrieve drafts by active origin only. IV: eligibility follows solution
visibility, not outcome; acceptance remains authored/deterministic. V–VI: no
score/timer/history mutation. VII: separate domain exploration, draft repository,
engine service and shared presentation. VIII: versioned recoverable writes,
durable save before abandoning work, no secrets/telemetry. IX: native local
engine dependency explicitly researched; defer coaches/export/full-game analysis.
Acceptance covers legality, preservation, isolation, lifecycle and phone layout.
No complexity exception or constitution amendment required.

## Architecture and ownership

- `lib/domain/analysis/exploration_session.dart`: immutable origin plus personal
  legal move tree, navigation, replay and JSON codec. Domain agent owns this and
  its unit tests. Publish interface before dependent UI work.
- `lib/domain/analysis/exploration_repository.dart`: abstract load/save keyed by
  origin. `lib/data/repositories/drift_exploration_repository.dart`: independent
  version-1 app_settings entries (no schema migration). Persist via serial writes;
  source/block/revision identity supplied by owning navigation. Persistence agent
  owns these and repository tests.
- `lib/domain/analysis/analysis_engine.dart`,
  `lib/features/analysis/application/analysis_controller.dart`,
  `lib/data/analysis/stockfish_analysis_engine.dart`: cancellable engine boundary,
  structured evaluation/PV, request generations, bounded/debounced search and
  power lifecycle. Engine agent owns these, dependency and engine tests.
- `lib/features/analysis/presentation/`: shared workspace, interactive board,
  tree navigation and analysis panel. Shared UI agent owns it. Reader agent owns
  TextView integration only. Root owns puzzle review/app composition integration.

Every widget accepts injectable engine factory/repository for tests. Default
repository supplied by application composition, not a platform-global singleton.
Normal reader/review engine controls and workspace use the same engine boundary.
Only the currently active surface owns an engine instance; dispose on switching.
Keep original details scroll controller alive across exploration and restore it
after returning. Source scopes use existing stable block ID plus fingerprint.

## Shared contracts (agents must publish exact APIs)

`ExplorationOrigin`: scopeId, startingFen, authoredPath (indices), authoredMoves
(UCI history from startingFen), label, optional discriminator for a recorded try.
`ExplorationSession`: origin, personal tree/cursor, position (dartchess Chess),
active UCI history including authored history, legal play/navigation, codec.
`ExplorationRepository`: Future<ExplorationSession?> load(ExplorationOrigin),
Future<void> save(ExplorationSession).
`AnalysisEngine`: analyze(startingFen, moves, budget) stream of structured results,
stop, dispose. Factory callable with no args. Results use White-relative score,
legal UCI principal variation and depth. Controller owns stale-result protection.
`ExplorationWorkspace`: origin, optional repository/engineFactory, orientation,
optional initialMoveUci, bookContext widget, onReturn; parent retains exact cursor
and scroll. Workspace return awaits persistence; nested Back behaves the same.
`AnalysisPanel`: startingFen, moves, engineFactory, onExploreSuggestion(List<String>).

## Dependencies, storage, licensing and validation

Resolve Stockfish package/version and native support in engine-research.md before
adding it. App is GPL-3.0-or-later; preserve engine and wrapper notices/licenses,
and document corresponding native source in distribution review. No SQL schema
migration; existing version-1 StudyPresentationStore and attempt JSON unchanged.
Draft versions are validated before overwrite; retained source revision keys
prevent wrong-content recovery. Engine state is never durably enabled.

Use pinned Flutter 3.47.5. Domain/persistence tests first, fake-engine controller
tests for races/stop/errors, reader/review widgets and integration for concealment,
then repository CI format/analyze/test/generated-code/Android build gates.
Record environmental or baseline failures without presenting checks as passed.
Physical Android battery/thermal tests remain release gates unless a device is
available; do not substitute mocked tests for measured power claims.
