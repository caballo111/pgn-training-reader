# PGN Training Reader

An offline-first Flutter app for reading PGN libraries and training with chess
puzzles.

## Content types

The library and training sets use two content types: **Puzzle** and **Text**.
Puzzles are solved and scored. Text is study material, including lessons and
annotated games; it is read and explicitly completed without creating puzzle
attempts or scores. Text entries may include positions, moves, and variations
for board navigation.

PGN files that use the legacy `X-ContentType` values `Instruction` or
`Demonstration` are read as Text. New files should use `X-ContentType "Text"`.

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
