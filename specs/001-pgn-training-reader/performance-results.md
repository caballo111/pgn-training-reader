# Performance benchmark results

Recorded: 2026-10-01. These final measurements were rerun after parser and
recovery hardening and the passing full suite, with no concurrent test workload.

## Benchmark method

Run the sanitized host benchmark with the pinned Flutter SDK:

```sh
flutter test --dart-define=PGN_BENCHMARK_BLOCKS=10000 test/performance/pgn_performance_benchmark_test.dart
flutter test --dart-define=PGN_BENCHMARK_BLOCKS=100000 test/performance/pgn_performance_benchmark_test.dart
```

Each command runs one target in a fresh Flutter test process. The normal
performance test defaults to 100 blocks; use the two commands above for the
full run. The harness writes a generated PGN to a temporary managed-source
location, imports it with `DriftPgnImportService`, queries the disk-backed
Drift index, and loads the final indexed block 100 times through
`DriftChessContentRepository`. A selected-block load includes the index lookup,
source fingerprint check, byte-range read, UTF-8 decode, and PGN parse. The
query latency samples are 100 paginated index searches spread across the source.
RSS is sampled every 10 ms from just before database setup through these
operations; peak RSS is sampled, not a guaranteed process maximum.

The generated source contains repeated, sanitized, 84-byte complete PGN blocks.
It is useful for measuring scanner/index scaling but does not represent the
larger and varied blocks in the Woodpecker corpus described in `research.md`.
These measurements ran on a Linux aarch64 host (`Linux sbx-kit-codex-pgn-training-reader
7.0.14`, Flutter 3.47.5, Dart 3.13.4). They are not reference Android device
results and cannot establish Android timing or memory targets.

## Results

| Blocks | Source size | Import | Throughput | Search p50 / p95 | Selected-block load p50 / p95 | Baseline RSS | Sampled peak RSS | RSS growth |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 10,000 | 840,000 B | 2,693 ms | 3,713 blocks/s | 422 / 565 µs | 1,226 / 1,493 µs | 171,606,016 B | 191,807,488 B | 20,201,472 B (19.3 MiB) |
| 100,000 | 8,400,000 B | 26,011 ms | 3,844 blocks/s | 1,951 / 4,410 µs | 1,250 / 1,771 µs | 183,074,816 B | 210,501,632 B | 27,426,816 B (26.2 MiB) |

Both imports indexed the expected number of blocks with zero diagnostics. The
larger generated source increased sampled RSS growth by about 6.9 MiB and took
26.0 seconds on this host. The 100,000-block host run is below the plan's
10-minute import time and 512 MiB peak-process ceiling as observed here, but
the plan applies those targets to the reference Galaxy S25 and representative
PGN data, so this host result does not satisfy that device check.

No performance optimization was made from these host measurements. The
synthetic blocks are small, and the reference-device corpus run is still needed
before drawing conclusions about a measured application bottleneck. No
before/after optimization claim is made.

## Pending reference-device run

The reference-device measurement still needs the source corpus and Galaxy S25
identified in `research.md` (SM-S931B, Android 16/API 36). Generate exact
10,000 and 100,000 block fixtures from that corpus outside version control,
then record model, OS/API level, build, app build, import throughput, query and
selected-block load p95, and peak process RSS. The current benchmark harness
uses synthetic 84-byte blocks and a host process; it does not generate the
Woodpecker-derived fixtures or run on Android.

## Scanner-only memory regression

The existing isolated scanner benchmark also passed after input hardening:

```sh
fvm dart run tool/pgn_scanner_memory_benchmark.dart 10000 100000
```

On this host, 10k/100k short blocks used 4.2/2.5 MiB sampled RSS growth. The
256 MiB single-comment stress input used 2.7/2.2 MiB growth respectively. The
large comment is now diagnosed as over-limit input; this scanner-only stress
still verifies that consuming rejected bytes does not retain the comment.
Largest-run growth stayed below the harness's 28.2 MiB comparison bound. This
measures the streaming scanner, not the full pipeline or Android UI.
