# PGN Training Reader

A local Flutter app for reading PGN books and practicing authored chess puzzles
in repeatable training cycles. Android is the first supported platform.

Import PGN into a managed local copy, browse indexed content, read annotated
moves/variations, or solve concealed puzzles. Build ordered sets across books,
resume cycles across days, and review transparent accuracy and active-time
reports. Casual book practice stays separate from cycle scoring.

Use **Explore position** while reading or reviewing a visible puzzle solution
to try personal variations. **Return to reading/review** restores your place;
saved drafts offer **Resume exploration**. Personal moves never change the book
or a scored attempt. Optional on-device Stockfish analysis starts off, uses a
bounded search, and pauses when the app is inactive. Concealed solving and
continued practice after a mistake do not expose analysis.

Use **Manage library** to add PGN books or delete a book from the active
library. Deletion removes the app's managed copy and preserves saved training
history and set/cycle references; the original selected PGN is untouched.
Re-adding a deleted book creates a new library identity.

Content categories are **Puzzle** and **Text**. Legacy `Instruction` and
`Demonstration` tags map to Text; text study does not create puzzle scores.
Unknown types and unsupported chess variants are diagnosed. Original PGN bytes,
headers, comments, NAGs, FEN positions and authored variations remain canonical.
Custom `X-` tags describe content/identity/filter metadata; see the tag reference.

## Development and documentation

```sh
fvm install
fvm flutter pub get
fvm dart run build_runner build
fvm flutter test --no-pub test
```

`.fvmrc` pins Flutter 3.47.5 with Dart 3.13.4. Use the pinned formatter and
`.editorconfig` conventions (UTF-8, LF, final newline, spaces).

- [Setup, generation, validation and Android commands](specs/001-pgn-training-reader/quickstart.md)
- [Custom PGN tags](docs/custom-pgn-tags.md) and [sanitized samples](samples/)
- [Training model and scoring](docs/training-model.md)
- [Privacy and local storage](docs/privacy-and-data.md)
- [Release review and pending acceptance](specs/001-pgn-training-reader/release-review.md)
- [Future product ideas](specs/backlog.md)
- [Library management specification and compatibility](specs/003-manage-library/spec.md)
- [Personal exploration and local analysis](specs/005-analysis-exploration/spec.md)
- [Analysis implementation validation and native build blocker](specs/005-analysis-exploration/validation.md)

Core workflows need no server or account. Training-history backup/export and
restore (Phase 15) are deferred. Engine-equivalent puzzle validation,
sync/accounts, full-game engine reports and analysis export remain deferred. Device accessibility,
reference performance and final Android release checks remain acceptance gates;
read the release review before distributing a build.

Application code is **GPL-3.0-or-later**; see [LICENSE](LICENSE),
[third-party notices](THIRD_PARTY_NOTICES.md), and
[distribution obligations](docs/distribution-license-review.md).
