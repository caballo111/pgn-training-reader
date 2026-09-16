# PGN scanner probe

This is a disposable research experiment for T007. It is intentionally not a
production scanner: it only detects top-level `[Event ...]` block starts and
records byte ranges. It carries lexical state across `consume` calls for tag
strings, brace comments, semicolon comments, and recursive variations.

Run it with:

```text
/Users/lberrios/Source/flutter/bin/cache/dart-sdk/bin/dart run bin/probe.dart
```

The probe compares chunk sizes 1, 2, 7, 64, and 4096, and also places an
explicit split inside each required construct.
