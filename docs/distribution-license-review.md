# Distribution license review

Decision recorded 2026-10-01 (T186/T187): the project owner selected
**GPL-3.0-or-later** for application code. The complete GPL v3 text is in
`LICENSE`. This is a licensing decision, not approval to publish an APK.

`dartchess` 0.13.1 and `chessground` 10.1.1 ship GPL v3 license text. Treat the
combined application distribution as subject to GPL v3 obligations; the app's
“or later” grant does not broaden a third party's grant. Do not assume a later
GPL version is compatible without reviewing the dependency grants again.
The transitive desktop `dbus` package uses MPL-2.0; retain its notices and make
any covered source modifications available under its applicable terms if it is
shipped. Review secondary-license restrictions for the final artifact rather
than assuming every resolved package is included in an Android build.
Other resolved Dart packages have upstream notices copied into
`docs/third-party-licenses/`; the inventory includes development tools as well
as application packages. MIT, BSD and Apache notices must be retained.

Before distributing a binary:

- Supply the GPL license and appropriate copyright/license notices.
- Make corresponding source for the exact released application and GPL
  components available under the applicable GPL terms, including local changes,
  dependency versions, build scripts and installation information where required.
- Include the Flutter engine/Dart runtime notices and notices for native
  artifacts resolved by the Android build. SQLite is public domain; its wrapper
  packages have separate licenses. Android Gradle and Kotlin tooling are
  Apache-2.0; build tools are not automatically shipped in the APK.
- Inspect the final APK's native libraries and generated Flutter license registry;
  the Dart inventory is not a final APK software bill of materials.
- Use project-owned or properly licensed release artwork and sanitized examples.
  Imported chess books remain user content and must not be bundled without rights.

This repository includes the application license, resolved package notice texts,
and the distribution decision. Final Android artifact/engine notice inspection,
source publication alongside a binary, and release signing remain release gates.
No binary was published during this review.
