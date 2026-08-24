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
valid deterministic result for this workload and is asserted by the
deterministic test suite against the library fixture.

## Environment

- Date: 2026-08-24
- Host: Windows, PowerShell
- Moon: `0.1.20260819`
- Moonc: `v0.10.9+6e6c44045 (2026-08-19)`
- Command: `moon run cmd/main -- --benchmark`
- Measurement: one warm-up run followed by five warm local `Measure-Command` runs, with CLI output discarded

## Observed wall time

| run | wall time |
| ---: | ---: |
| 1 | 195.744 ms |
| 2 | 235.101 ms |
| 3 | 250.838 ms |
| 4 | 261.851 ms |
| 5 | 333.655 ms |
| minimum | 195.744 ms |
| median | 250.838 ms |
| mean | 255.438 ms |

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
`297.058 ms`, `288.387 ms`, `268.057 ms`, `361.885 ms`, and
`589.697 ms`; minimum `268.057 ms`, median `297.058 ms`, mean
`361.017 ms`.

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
