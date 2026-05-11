# v3_pretest-260511 FEB board compile report

## Verdict

FAIL. The first Quartus compile stopped in the Fitter before STA/ASM, so no
timing path, worst setup slack, or per-clock Slow 85C setup/hold table was
generated.

## Compile Summary

| Field | Value |
|---|---|
| Project | `syn/board_projects/fe_scifi_feb_v3/top.qpf` |
| Revision | `top` |
| Device | `5AGXBA7D4F31C5` |
| Quartus | `18.1.0 Build 625 09/12/2018 SJ Standard Edition` |
| Compile status | `Flow Failed - Mon May 11 12:53:24 2026` |
| Fitter status | `Failed - Mon May 11 12:53:23 2026` |
| Total wallclock | `00:50:26` |
| Analysis & Synthesis wallclock | `00:14:21` |
| Fitter wallclock | `00:36:05` |
| Failure stage | Fitter |
| Failure code | `Error (11802): Can't fit design in device` |

## Resource Summary

| Resource | Usage |
|---|---:|
| ALMs | `146,608 / 91,680 (160%)` |
| Total registers | `236,674` |
| M10K / total RAM blocks | `0 / 1,366 (0%)` |
| M20K | `0 (not present on Arria V)` |
| Block memory bits | `2,823,882 / 13,987,840 (20%)` |
| DSP blocks | `0 / 800 (0%)` |
| PLLs | `7 / 21 (33%)` |

## Timing Summary

STA did not run because the Fitter failed. There is no `output_files/top.sta.summary`,
no worst setup slack, and no Slow 85C setup/hold table for this compile.

| Clock | Slow 85C setup slack | Slow 85C hold slack | Note |
|---|---:|---:|---|
| n/a | n/a | n/a | Fitter stopped before Timing Analyzer |

## Bring-up Gate

The FEB debug bring-up timing gate cannot be evaluated because placement failed
before STA. This compile fails the bring-up gate on resources before the
`worst-corner setup slack >= -0.4 ns` timing relaxation can be checked.

## Failure Details

The failing path is the resource fitting path, not a timed register path:

- `output_files/top.fit.summary` reports `Logic utilization (in ALMs) : 146,608 / 91,680 ( 160 % )`.
- `quartus_compile_top_20260511_120148.console.log` reports `Error (11802): Can't fit design in device`.
- `output_files/top.flow.rpt` reports total elapsed time `00:50:26`.

No IP version was reverted, and no ad-hoc timing exception or false-path patch
was applied.

## Evidence

| Artifact | Purpose |
|---|---|
| `output_files/top.fit.summary` | Fitter status and resource summary |
| `output_files/top.flow.rpt` | Flow status, timestamp, and elapsed time |
| `quartus_compile_top_20260511_120148.console.log` | Console log with `Error (11802)` |
