# Android Stockfish integration research

Checked 2026-10-09 against pub.dev package metadata and the published source
archives, using the managed environment's approved HTTP proxy. The available
Flutter SDK is `/workspace/toolchains/flutter` at the repository's pinned 3.47.5.

## Recommendation

Use `multistockfish: 0.6.1` from [pub.dev](https://pub.dev/packages/multistockfish/versions/0.6.1),
published 2026-09-29 from [lichess-org/dart-multistockfish](https://github.com/lichess-org/dart-multistockfish).
It bundles real Stockfish 19 C++ engines, including a `light` flavor with an
embedded ~1 MB NNUE file, and declares Android and iOS support. Its Dart SDK
constraint is `^3.7.0`, Flutter is `>=3.3.0`; both fit this app's pinned SDK.
The current transitive native packages resolve to `multistockfish_light 0.1.0`,
`multistockfish_chess 0.6.0`, and `multistockfish_variant 0.4.0`.

Other pub.dev results were weaker fits: `stockfish_for_mobile 1.1.2` has had no
release since 2022; `stockfish_chess_engine 0.8.2` since 2025-02; and
`flutter_stockfish_plugin 1.2.0` since 2025-08. The widely named `stockfish`
1.8.1 archive currently declares Dart `<3.0.0`, which excludes this app's SDK.
`multistockfish` is the best maintained Android choice found and has an explicit
per-engine cancellation and shutdown lifecycle.

## API and bounded UCI use

Create a lazy app adapter around this API:

```dart
final engine = await Stockfish.create(
  flavor: StockfishFlavor.light,
  onStdout: onLine,
);
engine.stdin = 'setoption name Threads value 1';
engine.stdin = 'setoption name MultiPV value 1';
engine.stdin = 'setoption name Hash value 16';
engine.stdin = 'position fen $startingFen moves ${moves.join(' ')}';
engine.stdin = 'go movetime 1000';
// On cancellation, send `stop`; consume output through `bestmove` before
// sending the next position/search command.
await engine.dispose(); // sends `quit`; waits at most five seconds
```

`Stockfish.create()` is `Future<Stockfish>` and completes after the UCI
handshake. Each of its two readiness waits (engine banner and `uciok`) has a
five-second timeout. `stdin` accepts raw UCI strings; `stdout` is a `Stream<String>`;
`onStdout` sees startup output as well. Parse `info depth ... score cp|mate ...
pv ...` for incremental values and `bestmove ...` as request completion. UCI
score is converted from side-to-move to a fixed White perspective by replay
parity from the starting FEN. `stop` is the supported search-cancellation
command; it asks Stockfish to stop, it is not a process kill. The adapter must
wait for the matching `bestmove` before reusing the single UCI session.

The implementation lives in `lib/data/analysis/stockfish_analysis_engine.dart`
behind `AnalysisEngine` in `lib/domain/analysis/analysis_engine.dart`. It
replays every history UCI move against dartchess before engine startup, rejects
control characters and illegal input, validates every displayed PV, and
normalizes cp/mate scores to White's perspective. It fixes `Threads=1`,
`MultiPV=1`, and a 16 MB hash. Routine searches use 1,000 ms; deeper searches
and the engine boundary cap at 5,000 ms. Explicit stop sends `stop` and waits
up to a three-second cancellation grace for `bestmove`; a watchdog fires at the
budget plus two seconds and retires a session that ignores stop. Cancellation
during initialization suppresses any later `position` or `go` command.
`defaultAnalysisEngineFactory()` creates this adapter lazily on Android and
returns an explicit unavailable engine on other targets.

The package runs native engine code off the Flutter UI isolate and manages two
Dart isolates for command and output pipes. It allows one live handle per
flavor; `dispose()` sends `quit`, waits up to five seconds, and abandons a wedged
engine (then gives an exited reader up to one second to stop). Its documented
residual risk is that a native engine which does not exit may retain
process-global state and prevent a later same-flavor engine until app restart.
The adapter serializes creation/disposal across instances, invalidates canceled
request generations, and keeps manual exploration available when startup,
output parsing, or shutdown fails. The controller uses one-second ordinary
searches and caps deeper or externally supplied budgets at five seconds. A
route stop that lands during native startup waits behind the package's
process-wide lifecycle lock. Each startup handshake step is bounded at five
seconds; timeout cleanup can then wait up to five seconds for quit and one
second for the reader to stop. In the slowest handshake path, stopping can
therefore take about sixteen seconds. This is a bounded latency risk; the
adapter does not release the global lock while a create is still in flight.

## Android support and build limitation

The native package uses Android Gradle/CMake and the app's NDK. Its manifest
declares ABI filters `arm64-v8a`, `armeabi-v7a`, and `x86_64`; the CMake target
compiles the Stockfish C++ sources for each ABI and enables the 16 KB Android
page-size linker option. The Android library sets compile SDK 35 and min SDK
21. The light flavor embeds an approximately 1.1 MB NNUE in its native library,
so the app has a real engine without downloading evaluation assets at runtime.
The facade also resolves native chess and Fairy-Stockfish variant plugins even
though this app selects only the light flavor. Their C++ sources are also in
the Android build graph, so the final APK may include extra libraries and build
time; no artifact size claim is possible until an Android build completes.

The published `multistockfish_light 0.1.0` CMakeLists nevertheless executes a
configure-time download from `https://tests.stockfishchess.org/api/nn/nn-61e7af4bb97d.nnue`
and checks its SHA-256, even though the resulting net is embedded in the
library. That host is not in this environment's enforced outbound allowlist.
The two approved GitHub mirror paths checked for the exact net both returned
404: [github.com/official-stockfish/networks/raw/master/nn-61e7af4bb97d.nnue](https://github.com/official-stockfish/networks/raw/master/nn-61e7af4bb97d.nnue)
and [raw.githubusercontent.com/official-stockfish/networks/master/nn-61e7af4bb97d.nnue](https://raw.githubusercontent.com/official-stockfish/networks/master/nn-61e7af4bb97d.nnue).
No approved mirror was found. Therefore an Android build in this
environment cannot be claimed verified; CMake configuration fails until the
upstream model host is approved or the dependency is adjusted to consume the
published source asset offline. This is a packaging/build-time network
dependency, not an app runtime network dependency. The implementation keeps
the engine boundary injectable so another vetted native packaging route can
replace it if needed.

## Licensing and distribution

`multistockfish` and each resolved native package include GNU GPL version 3
license texts. The selected `multistockfish_light` source includes Stockfish's
GPLv3 `Copying.txt` and complete source files under the same publication; the
wrapper and native libraries are incorporated into the Android app. For a
distributed app, preserve the package and Stockfish copyright notices and GPL
texts, provide the corresponding source for the exact wrapper/native revisions
and the scripts needed to build the shipped binaries, and review Android's
installation-information requirements for user devices. Add the notices to
the app's third-party notices and make the source location available to
recipients. The checked-in notice inventory now links the package licenses and
Stockfish's GPLv3 text. It also records the versioned pub.dev source archive and
upstream repository as the corresponding-source locations. The repository is
itself GPL-3.0-or-later, but distribution artifacts still need the dependency
notices and corresponding-source path.

## Sources

- [multistockfish 0.6.1 pub.dev](https://pub.dev/packages/multistockfish/versions/0.6.1)
- [lichess-org/dart-multistockfish](https://github.com/lichess-org/dart-multistockfish)
- [Stockfish](https://stockfishchess.org/) and the bundled native source in
  `multistockfish_light 0.1.0`
- [Pub.dev search for Stockfish](https://pub.dev/api/search?q=stockfish)
- Local Flutter SDK: `/workspace/toolchains/flutter` (Flutter 3.47.5)
