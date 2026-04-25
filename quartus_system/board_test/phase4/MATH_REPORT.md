# Phase 4 Math Report

Date: 2026-04-25

This report defines the model quantities used by the Phase 4 DISLIN plots and
keeps modeled quantities separate from RTL and board measurements.

## Model Inputs

| Quantity | Value | Meaning |
|---|---:|---|
| `N_LANE` | 8 | enabled emulator lanes |
| `f_clk` | 156.25 MHz | modeled datapath clock |
| `RUN_CYCLES` | 200000 | TLM sample length |
| `RUN_CYCLES / f_clk` | 0.00128 s | TLM sample duration |
| `FRAME_INTERVAL_CYCLES` | 1550 | modeled frame cadence |
| `HIST_ACCEPT_NUM / HIST_ACCEPT_DEN` | 7 / 8 | model histogram acceptance slot ratio |
| rate words | `0x0100..0x8000` | same sweep labels as the board report |

The TLM generator is a calibrated reference model, not the emulator RTL
implementation. It uses a per-lane, per-cycle hit probability

```text
p_gen(R) = min(5 * R, 65535) / 65536
```

where `R` is the integer rate word. The expected generated rate is

```text
lambda_gen(R) = N_LANE * f_clk * p_gen(R)
```

The modeled histogram acceptance cap is

```text
lambda_cap = f_clk * 7 / 8 = 136.718750 Mhit/s
```

The accepted model rate is therefore bounded by

```text
lambda_acc(R) = min(lambda_gen(R), lambda_cap)
```

apart from finite-run random variation and model backlog.

## Latency Model

For a hit generated at clock cycle `c` on lane `l`, the TLM latency is

```text
phase = c mod FRAME_INTERVAL_CYCLES
wait_to_frame = 0 if phase == 0 else FRAME_INTERVAL_CYCLES - phase
pipe_delay = 8 + (l mod 4) + (rng & 7)
latency_cycles = wait_to_frame + pipe_delay
```

This gives a modeled support of 8 to 1567 cycles for the configured run. The
RTL histogram is not expected to match this bin-by-bin; it is an integration
measurement of the actual datapath dispatch bins.

## Axis Definitions

The latency plot uses:

- x-axis: latency in 156.25 MHz clock cycles;
- y-axis: probability per cycle bin, computed as `100 * bin_count / total`.

The throughput plot uses:

- x-axis: `rate_word / 0x0100`;
- y-axis: accepted histogram rate in Mhit/s.

## Numerical Checks

From [`artifacts/phase4_summary.json`](artifacts/phase4_summary.json):

| Quantity | Value |
|---|---:|
| TLM latency total | 249211 |
| TLM latency min / p50 / p90 / p99 / max | 8 / 786 / 1407 / 1547 / 1567 cycles |
| RTL latency total | 1381 |
| RTL latency min / p50 / p90 / p99 / max | 476 / 865 / 1252 / 1580 / 1589 cycles |
| Board knee | `0x1000` |
| Board knee throughput | 135.360020 Mhit/s |
| TLM acceptance cap | 136.718750 Mhit/s |

The board knee is 0.994 percent below the TLM acceptance cap:

```text
(136.718750 - 135.360020) / 136.718750 = 0.00994
```

That agreement is close enough for the current model purpose: locating the
histogram-throughput knee and verifying that the board saturates near the
expected acceptance ceiling without reporting dropped histogram hits.

## Archive Context

`doc/Archive.zip` contains `ethhw_reordering.pdf`,
`ethhw_reordering.pptx`, and `eth_mu3e_jamboree.pptx`. These are used here as
qualitative design context only: they describe bounded waiting, resequencing,
FIFO-induced delay, and measured delay-bound concepts for Mu3e Ethernet-style
ordering. No numeric limit from those slides is treated as direct Phase 4
evidence. The direct numeric evidence in this report comes from generated CSVs,
RTL simulation logs, and board reports.

## DISLIN Outputs

![Phase 4 latency shape](artifacts/phase4_latency_tlm_vs_rtl.png)

![Phase 4 throughput sweep](artifacts/phase4_rate_sweep.png)
