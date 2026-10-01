# Quickstart

Use FVM with `.fvmrc`: Flutter **3.47.5**, bundled Dart **3.13.4**. Android's
minimum supported API is 24. Install a compatible Android SDK/JDK 17 and accept
SDK licenses for device builds. Do not upgrade dependencies independently of
the pinned `pubspec.lock` during validation.

```sh
fvm install
fvm flutter pub get
fvm flutter doctor -v
fvm dart run build_runner build
fvm dart format --output=none --set-exit-if-changed lib test integration_test tool
fvm flutter analyze lib test integration_test tool
fvm flutter test --no-pub test
```

After generation, `git diff --exit-code -- lib/data/database/app_database.g.dart`
checks that committed generated code remains current. If Flutter is installed
directly, use its `bin/flutter` and `bin/dart` equivalents of the FVM commands.

## Fixture import and Android acceptance

Copy the sanitized PGNs in `samples/` to the device's Downloads directory. Run
`fvm flutter devices`, then `fvm flutter run -d <device-id>`. Select Import PGN
from the library and choose a sample. Read Text, solve both colors/FEN starts,
create a mixed set, pause/resume across restart and inspect reports. Test toolbar
and system Back, TalkBack, large text, landscape and 320-pixel portrait controls.

```sh
fvm flutter build apk --debug --no-pub
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am force-stop lberrios.pgntrainingreader
```

The repository has host workflow integration coverage inside `test/`; the
`integration_test/` directory currently has no device test entry point and no
`integration_test` SDK dependency. `flutter test integration_test -d <device-id>`
is the command to use after a device harness is added; it is not a passing check
for this release. Record the manual device run in release-review.md and the
open assessment checklist. Force-stop/relaunch verifies durable restart state,
not orderly lifecycle closure alone.

## Benchmarks

```sh
fvm dart run tool/pgn_scanner_memory_benchmark.dart 10000 100000
fvm flutter test --no-pub test/performance/pgn_performance_benchmark_test.dart
fvm flutter test --no-pub --dart-define=PGN_BENCHMARK_BLOCKS=10000 test/performance/pgn_performance_benchmark_test.dart
fvm flutter test --no-pub --dart-define=PGN_BENCHMARK_BLOCKS=100000 test/performance/pgn_performance_benchmark_test.dart
```

The full pipeline benchmark and reproducible host results are documented in
[performance-results.md](performance-results.md). Reference acceptance uses
research.md's Galaxy S25 and original corpus, repeated to exact 10k/100k block
counts without rewriting source blocks. Generated benchmark files stay outside
version control. Synthetic host results cannot establish Android p95/memory or
frame-rate acceptance. Run benchmark smoke checks before release and compare
against the same build, corpus, device and configuration.
