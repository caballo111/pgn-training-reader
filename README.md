# PGN Training Reader

An offline-first Flutter app for reading PGN libraries and training with chess
puzzles.

## Development setup

Install [FVM](https://fvm.app/documentation/getting-started/installation), then
from the repository root install the Flutter SDK version pinned in `.fvmrc` and
fetch packages:

```sh
fvm install
fvm flutter pub get
```

Run Flutter and Dart commands through FVM so they use the pinned SDK, for
example `fvm flutter run` or `fvm dart format .`. The pin currently uses the
latest stable Flutter release, 3.47.5.

Generate Drift database code after changing the schema:

```sh
fvm dart run build_runner build
```

## Formatting conventions

`.editorconfig` sets UTF-8 encoding, LF line endings, final newlines, and
space-based indentation. Dart, YAML, JSON, and Markdown use two-space
indentation; Gradle and Kotlin use four spaces. Use the pinned Dart formatter
(`fvm dart format .`) as the authority for Dart formatting. Markdown trailing
spaces are preserved for intentional line breaks.
