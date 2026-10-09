# Implementation validation

Checked 2026-10-09 with pinned Flutter 3.47.5 / Dart 3.13.4. Scoped
implementation used Luna agents at xhigh after the specification, constitution
check, architecture contracts and ordered task list were written.

## Implemented behavior

- Reading and visible puzzle review offer a separate personal exploration tree,
  saved per source/block revision and authored occurrence. Returning restores
  the authored position, orientation and scroll. Explicit engine suggestions
  seed personal moves without changing source PGN or scored history.
- Recorded legal tries seed the attempted move; illegal tries open their prior
  position. Concealed solving and failed continued practice expose no analysis.
- Local Stockfish is lazy and off by default. Searches use one worker, one PV,
  16 MB hash and finite 1s/5s budgets. Navigation cancels obsolete work; lifecycle
  pause hides output and requires explicit resume. Retry cannot override a later
  Off action. Native startup/shutdown have longer bounded package deadlines,
  documented in [engine research](engine-research.md).
- Draft saves are serialized, revision isolated and awaited before departure.
  Errors retain the in-memory draft; unknown stored versions are not overwritten.

## Automated checks

| Check | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test integration_test tool` | Pass, 202 files |
| `flutter analyze lib test integration_test tool` | Pass, no issues |
| `flutter test --no-pub test` | Pass, 455 unit/widget tests |
| Final review scope-isolation regression and review tests | Pass, 4 tests after the final scope guard fix |
| Fake UCI adapter/controller tests | Pass, 10 tests including cancellation, malformed/bound output, score perspective, watchdog, budget clamp and retry race |
| `dart run build_runner build` and generated database diff | Pass, no change to `app_database.g.dart`; no schema migration |
| `git diff --check` | Pass |

The suite covers draft recovery/isolation, legal branching, source/score
preservation, concealment, explicit suggestion seeding, nested return/save waits,
phone layouts at enlarged text, and lifecycle cancellation. Engine unit tests
use an injected UCI transport; they do not prove native Stockfish execution.

The failed-review phone golden was inspected and updated for the Explore action
and compact Engine Off row. Existing scoring/reveal checks pass. Verification
also repaired an existing raw startup exception log rejected by the privacy
audit, kept book-location text stable beside its mode badge, and made played-move
semantics explicit. One existing test file needed formatter normalization.

## Android build blocker

`flutter build apk --debug --no-pub` was attempted. Environment repair supplied
Temurin JDK 21.0.8+9 with `javac`, Android platform 35, the existing platform 36,
NDK 28.2.13676358 and CMake 3.22.1. The retry reached native compilation and
failed at `:multistockfish_light:configureCMakeDebug[arm64-v8a]`.

The pinned dependency downloads `nn-61e7af4bb97d.nnue` from
`https://tests.stockfishchess.org/api/nn/nn-61e7af4bb97d.nnue` during CMake
configuration. The managed network proxy rejects that host with HTTP 403.
CMake reports download status 22 and an empty-file hash instead of its expected
SHA-256. Approved upstream GitHub mirror paths returned 404. The proxy was not
bypassed and the dependency was not silently replaced.

No APK was produced. Integration-test APK compilation is also unverified because
it uses this same native dependency graph. A permitted model-download source or
a vetted offline packaging change is needed before repeating these build gates.
The app itself does not download models or upload positions at runtime.

## Remaining release gates

Run the Android application and integration tests on a physical device, verify
all supported ABIs and package size, and measure cold startup, stop/departure
latency, battery use and thermal behavior. Verify TalkBack, promotion and board
gestures on device. Check final distribution artifacts against the pinned GPL
source/notices and build requirements in the existing license review.

These checks remain open; mocked engine tests and phone goldens are not device
performance or native-engine verification.
