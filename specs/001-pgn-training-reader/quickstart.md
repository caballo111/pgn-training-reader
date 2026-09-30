# PGN Scanner Memory Benchmark

Run the scanner benchmark from the repository root with the pinned Flutter
SDK's Dart executable:

```sh
fvm dart tool/pgn_scanner_memory_benchmark.dart
```

By default, it scans generated 10,000-block and 100,000-block PGNs. Each size
runs in a fresh Dart process. The executable generates repeated PGN bytes into
a fixed 64 KiB buffer, sends them to `PgnBoundaryScanner`, counts and discards
each returned range list, and does not create a PGN file or retain all ranges.
It reports total input bytes, block throughput, baseline RSS, peak RSS, and
growth over baseline. On Linux, RSS values come from `/proc/self/status`; other platforms use Dart `ProcessInfo` memory counters.

Each process also streams a 256 MiB brace comment through the scanner using
fixed-size chunks. This checks that the scanner does not retain a huge comment
or line. The benchmark fails if the largest corpus run's RSS growth exceeds
64 MiB or grows more than 24 MiB above the smallest run's growth. RSS sampling
is host dependent; use the same machine and Dart build when comparing results.

To run different block counts, pass them as arguments. An optional million
block run is:

```sh
fvm dart tool/pgn_scanner_memory_benchmark.dart 10000 100000 1000000
```

The workload is synthetic and measures scanner memory and throughput only; it
does not measure parsing, database writes, Android UI memory, or import speed
on a reference device.

Validated on 2026-09-29 in the Linux ARM64 development sandbox with Flutter
3.47.5 / Dart 3.13.4: 10,000, 100,000, and 1,000,000 blocks used 3.5, 10.0,
and 8.6 MiB of additional peak RSS, respectively. Input sizes were 0.4, 4.0,
and 40.1 MiB. The 256 MiB comment stress also passed. These host measurements
support bounded scanner memory; reference Android import targets still require
device measurements.
