# Benchmark record

This document records a reproducible local end-to-end CLI measurement for the
deterministic codec workload. It is intended for regression comparison on the
same machine; it is not a promise about network throughput or a particular
SCADA deployment.

## Workload

The command executes `run_benchmark_workload(10000, 16)`:

- frames: `10,000`
- payload bytes per frame: `16`
- encoded bytes: `220,000`
- deterministic CRC accumulator: `0`

The checksum is an XOR accumulator over the encoded frames. A zero result is a
valid deterministic result for this workload and is asserted by the acceptance
test against the library fixture.

## Environment

- Date: 2026-08-19
- Host: Windows, PowerShell
- Moon: `0.1.20260807`
- Moonc: `v0.10.7+bc794d341 (2026-08-11)`
- Command: `moon run cmd/main -- --benchmark`
- Measurement: five warm local `Measure-Command` runs, with CLI output discarded

## Observed wall time

| run | wall time |
| ---: | ---: |
| 1 | 237.786 ms |
| 2 | 232.711 ms |
| 3 | 244.396 ms |
| 4 | 222.495 ms |
| 5 | 256.368 ms |
| minimum | 222.495 ms |
| median | 237.786 ms |
| mean | 238.751 ms |

## Application workload

The CLI also executes `run_application_workloads(1000)`, covering versioned
station writes, quality-aware telemetry, command dispatch and confirmation,
bounded file inventory, and deterministic heartbeat scenarios. Each workload
completed 1,000 iterations locally:

| workload | accepted | rejected | bytes | checksum |
| --- | ---: | ---: | ---: | ---: |
| database | 1,000 | 0 | 0 | 0 |
| telemetry | 1,000 | 0 | 0 | 1,000 |
| scheduler | 1,000 | 0 | 0 | 1,000 |
| file | 1,000 | 0 | 64,000 | 1,170,276,287 |
| scenario | 1,000 | 0 | 0 | 999 |

Five warm local measurements of
`moon run cmd/main -- --application-benchmark` were:
`235.294 ms`, `216.923 ms`, `249.497 ms`, `246.257 ms`, and
`279.188 ms`; minimum `216.923 ms`, median `246.257 ms`, mean
`245.432 ms`.

The timings include the `moon run` process and cached build/runtime startup.
They should be compared only after keeping the toolchain, workload and host
measurement method fixed.

## Reproduce

```powershell
moon version --all
moon run cmd/main -- --benchmark
1..5 | ForEach-Object {
  Measure-Command { moon run cmd/main -- --benchmark | Out-Null }
}
moon run cmd/main -- --application-benchmark
1..5 | ForEach-Object {
  Measure-Command {
    moon run cmd/main -- --application-benchmark | Out-Null
  }
}
```
