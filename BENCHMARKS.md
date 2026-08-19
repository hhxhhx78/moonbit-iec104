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
| 1 | 305.030 ms |
| 2 | 303.149 ms |
| 3 | 336.774 ms |
| 4 | 299.296 ms |
| 5 | 253.868 ms |
| minimum | 253.868 ms |
| median | 303.149 ms |
| mean | 299.623 ms |

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
```
