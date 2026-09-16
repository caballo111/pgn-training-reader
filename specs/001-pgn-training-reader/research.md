# Research: PGN Training Reader

**Feature**: `001-pgn-training-reader`  
**Decision date**: 2026-09-15  
**Scope completed**: T002-T004

## T002 — Flutter and Dart versions

### Decision

Use the stable Flutter SDK checkout already available to the project:

- Flutter `3.47.4` (stable)
- Dart `3.13.3` (the Dart SDK bundled with that Flutter checkout)
- Android-first application target

The project should pin Flutter `3.47.4` with the repository's version-management
mechanism during T014. Dart must not be installed or managed independently for
the Flutter application; it is supplied by the pinned Flutter SDK.

Flutter 3.47 is the current stable feature release recorded by the official
Flutter release documentation, and Dart 3.13 is the corresponding stable Dart
release. The local checkout is on the `stable` branch and is tagged
`3.47.4`; its bundled SDK reports `3.13.3` in
`bin/cache/dart-sdk/version`.

### Verification commands

Commands run from the repository root:

```text
git -C /Users/lberrios/Source/flutter describe --tags --always --dirty
git -C /Users/lberrios/Source/flutter show -s --format='%D' HEAD
git -C /Users/lberrios/Source/flutter rev-parse --abbrev-ref HEAD
sed -n '1,40p' /Users/lberrios/Source/flutter/bin/cache/dart-sdk/version
```

Observed values:

```text
3.47.4-dirty
HEAD -> stable, tag: 3.47.4, origin/stable
stable
3.13.3
```

`flutter --version` and `dart --version` were also attempted. The sandbox
prevented the SDK wrapper from updating files under
`/Users/lberrios/Source/flutter/bin/cache`, so the version files and Git
metadata above are the authoritative local verification for this research
task. The dirty marker belongs to the pre-existing SDK checkout and is not a
change to this repository.

Evidence:

- [Flutter stable release notes](https://docs.flutter.dev/release/release-notes)
- [Flutter 3.47 release documentation](https://docs.flutter.dev/release/whats-new)
- [Dart 3.13 changelog](https://dart.dev/changelog)
- [Dart SDK installation guidance](https://dart.dev/get-dart)

## T003 — Dependency compatibility matrix

The following are the candidate pins for the initial `pubspec.yaml`. Exact
versions are recorded here so dependency resolution in T017 can verify the
matrix instead of silently selecting a newer major release. The generated
`pubspec.lock` remains the final resolved record.

| Package | Pin | Role | License | Repository | Maintenance and platform evidence |
| --- | --- | --- | --- | --- | --- |
| `dartchess` | `0.13.1` | Chess rules, FEN/SAN, PGN read/write, move-tree parsing | GPL-3.0 | [lichess-org/dartchess](https://github.com/lichess-org/dartchess) | Pub.dev marks it active; published three months before this decision; Android, iOS, Linux, macOS, and Windows; native-only, no web support. |
| `chessground` | `10.1.1` | Flutter board rendering and interaction | GPL-3.0 | [lichess-org/flutter-chessground](https://github.com/lichess-org/flutter-chessground) | Pub.dev marks it active; published two months before this decision; Android, iOS, Linux, macOS, and Windows. It deliberately contains no chess rules, which keeps evaluation in the domain adapter. |
| `drift` | `2.35.0` | Typed SQLite persistence, queries, transactions, migrations | MIT | [simolus3/drift](https://github.com/simolus3/drift) | Pub.dev marks it active; published six days before this decision; Android, iOS, Linux, macOS, Windows, and web. |
| `drift_flutter` | `0.3.1` | Flutter database opening and native storage integration | MIT | [simolus3/drift](https://github.com/simolus3/drift) | Pub.dev marks it active; published two months before this decision; Android, iOS, Linux, macOS, Windows, and web. It uses `path_provider` for the native application-documents location by default. |
| `drift_dev` | `2.35.0` | Drift code generation and schema tooling | MIT | [simolus3/drift](https://github.com/simolus3/drift) | Pub.dev marks it active; published five days before this decision; Dart/Flutter development dependency. Keep the version aligned with `drift`. |
| `sqlite3` | `3.6.0` | Bundled SQLite bindings used by Drift | MIT | [simolus3/sqlite3.dart](https://github.com/simolus3/sqlite3.dart) | Pub.dev marks it active; published two days before this decision; prebuilt native support for Android armv7a, arm64, x86, and x64, plus iOS, macOS, Linux, Windows, and web. |
| `file_picker` | `13.1.0` | Native file selection with extension filtering and byte-stream access | MIT | [vicajilau/flutter_file_picker](https://github.com/vicajilau/flutter_file_picker) | Pub.dev marks it active; published within a day of this decision; Android, iOS, Linux, macOS, Windows, and web. The v13 API exposes `readAsByteStream()` and moves length lookup to an async method, which fits managed-copy import. Verify the new maintainer/repository history before release. |
| `path_provider` | `2.1.6` | Application-controlled database and managed-copy directories | BSD-3-Clause | [flutter/packages path_provider](https://github.com/flutter/packages/tree/main/packages/path_provider/path_provider) | Flutter-owned and active; published three months before this decision; Android SDK 24+, iOS 13+, Linux, macOS 10.15+, and Windows 10+. |
| `path` | `1.9.1` | Cross-platform path joining and normalization | BSD-3-Clause | [dart-lang/path](https://github.com/dart-lang/path) | Dart SDK-owned and intentionally low-churn; active/stable; Android, iOS, Linux, macOS, Windows, and web. |

Compatibility conclusion:

- Flutter 3.47.4/Dart 3.13.3 is newer than the minimum Dart SDK advertised
  by `dartchess` (Dart 3.3) and is suitable for the selected package line.
- Drift 2.35.0, `drift_flutter` 0.3.1, and `drift_dev` 2.35.0 are selected as
  one aligned family. `sqlite3_flutter_libs` is intentionally excluded:
  version 0.6.0 is obsolete and the package documentation directs users of
  SQLite 3.x to use `sqlite3` directly.
- `file_picker` is suitable for selection and streaming, but the Android
  adapter must still be tested for persistent document permissions, seek, and
  range-read behavior in T008. The MVP must copy selected content into
  app-controlled storage before indexing.
- `dartchess` and `chessground` are reciprocal-license dependencies. Their
  GPL-3.0 terms must be reviewed before distributing a closed-source or
  proprietary build. The current plan may use them for development, but a
  distribution decision is required before release; this is not silently
  treated as an MIT/BSD-compatible dependency set.

Package evidence:

- [dartchess](https://pub.dev/packages/dartchess)
- [chessground](https://pub.dev/packages/chessground)
- [drift](https://pub.dev/packages/drift)
- [drift_flutter](https://pub.dev/packages/drift_flutter)
- [drift_dev](https://pub.dev/packages/drift_dev)
- [sqlite3](https://pub.dev/packages/sqlite3)
- [sqlite3_flutter_libs deprecation notice](https://pub.dev/packages/sqlite3_flutter_libs)
- [file_picker](https://pub.dev/packages/file_picker)
- [path_provider](https://pub.dev/packages/path_provider)
- [path](https://pub.dev/packages/path)

## T004 — Minimum supported Android API

### Decision

Set `minSdk` to Android API **24** (Android 7.0), and use the Flutter
3.47.4-generated Android project defaults for compile and target SDK values.

### Reasoning

1. Flutter 3.47.4's Android Gradle utility defines the generated minimum as
   API 24. This keeps the app on the supported default rather than overriding
   the framework with an older compatibility target.
2. The selected `path_provider` 2.1.6 explicitly supports Android SDK 24+.
   It is required for durable application-controlled database and managed-copy
   directories.
3. `file_picker` historically supports API 21+, so it does not force a
   higher minimum, but it does not remove the API 24 constraint established by
   Flutter and `path_provider`.
4. API 24 provides the Android document/storage behavior needed for the
   managed-copy MVP without granting broad filesystem permissions. The picker
   returns an opaque provider reference; the adapter reads it and copies the
   bytes into the app's private documents directory. T008 must still verify
   persistent URI access, stream length, seek/range support, and behavior across
   at least two document providers.
5. The app does not need broad external-storage access for the MVP. App-private
   storage avoids legacy storage permissions and makes database/source recovery
   behavior more predictable. Any future index-in-place mode remains
   conditional on provider capabilities and will not lower `minSdk`.

Local framework evidence:

```text
rg -n "minSdkVersionInt|minSdkVersion" \
  /Users/lberrios/Source/flutter/packages/flutter_tools/lib/src/android/gradle_utils.dart
```

This located `minSdkVersionInt = 24` and `minSdkVersion = '24'` in the
Flutter 3.47.4 checkout.

Additional evidence:

- [Flutter breaking-change index](https://docs.flutter.dev/release/breaking-changes)
- [path_provider Android support matrix](https://pub.dev/packages/path_provider)
- [file_picker compatibility chart](https://pub.dev/packages/file_picker)
- [Android Storage Access Framework overview](https://developer.android.com/guide/topics/providers/document-provider)

### T002-T004 exit status

Complete. These decisions do not require a change to the architecture in
`plan.md`. T008 remains the required empirical check for provider-specific
seek and persistent-permission behavior before implementation of file access.
