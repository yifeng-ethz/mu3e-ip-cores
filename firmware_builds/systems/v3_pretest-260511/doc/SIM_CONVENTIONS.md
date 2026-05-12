# SIM_CONVENTIONS.md - directed simulation time standard
## Standard window

All UVM directed simulation sequences use a fixed RUNNING stage duration of
exactly 1 ms.

The FEB SciFi directed harness measures this window on the MuTRiG/LVDS timebase:

```text
lvdspll_clk = 125 MHz
tick        = 8 ns
1 ms        = 125000 ticks
```

Therefore the standard plusarg/default is:

```text
RUN_WINDOW_8NS = 125000
```

This rule applies to directed BASIC, EDGE, ERROR, PROF smoke, and cosim sanity
rows unless the test is explicitly named as a long-soak exception.

## What is fixed

Only the RUNNING stage is fixed.

PREPARE, SYNC, TERMINATE, drain, and analyzer settle time may vary by harness.
Those stages can be 100 us to 1 ms, or longer if the design needs it to reach a
clean state before or after RUNNING.

Hit-count comparisons must use the absolute count generated during RUNNING.
For a given rate, source mode, and channel mask, rows are compared directly
without scaling by elapsed time.

## Long-soak exception

Long-soak runs are allowed when they are the point of the test.

A long-soak run must use a sequence/test name that says it is a long soak, for
example `*_longsoak_10s_*`, and the report must state the nonstandard RUNNING
duration. Use this only for stress, aging, queue tail, or rare-event studies.

## Tuning knobs

The usual harness knobs are:

```text
RUN_WINDOW_8NS       fixed at 125000 for directed rows
HIT_PERIOD_8NS       source rate or per-channel period
ASIC_COUNT           active virtual MuTRiG sources
DRAIN_SWB_CYCLES     post-RUNNING SWB drain allowance
FLUSH_FRAMES         post-RUNNING FEB frame flush count
HEADER_SYNC_*        header-sync source alignment controls
```

Look first in the local test or cosim `Makefile`, then in the SystemVerilog
plain testbench plusarg parser if a default is unclear. For the dualport FEB/SWB
cosim sanity wrapper, the user-facing defaults live in
`../v3_pretest-260511-emutype0-dualport-260512/cosim/Makefile`.

## Phase 4.5 OPQ ceiling and theoretical deltas

The Phase 4.5 rate rows use the OPQ ingress bottleneck as the theoretical
delivery ceiling. The operational ceiling is 250 Mhit/s aggregate across all
FEB lanes, per the user directive for this retest. RTL/spec evidence confirms
that this is the intended operational clock target:

- `packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/README.md`
  lists the nominal target clock as 250 MHz and the signoff margin as 275 MHz.
- `packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/opq_native_sv_4lane_signoff.sdc`
  constrains the standalone signoff clock to 3.636364 ns, which is 275 MHz
  and therefore 1.1x the 250 MHz operational target.
- `packet_scheduler/rtl/vhdl_ver/ordered_priority_queue/split/opq/top/opq_top.vhd`
  exposes a single ready/valid egress stream, so the aggregate OPQ delivery
  ceiling is one hit word per OPQ clock.

The sweep therefore uses:

```text
opq_ceiling_hps = 250e6
basic_ceiling_hps = 0.50 * opq_ceiling_hps = 125e6
```

If a future platform runs the OPQ at a different operational clock, update
`OPQ_CEILING_HPS` in `scripts/cotest/phase4_5_sweep.py` and keep this note as
the reason the May 2026 retest used 250 Mhit/s.

## Emulator rate encoding

The emulator rate CSR is 16 bits of 8.8 fixed-point rate. The RTL writes
`cfg_rates_hit_rate` from `frontend_csr.sv`, and `frontend_trigger_engine.sv`
uses that value either as a PRNG threshold or as a 16-bit phase increment. The
periodic-mode carry test proves the exact mapping:

```text
per_active_channel_hps = rate_88fp * 125e6 / 65536
```

This matches the emulator DV notes: `0x0100` launches once per 256
`lvdspll_clk` cycles, and `0x0800` launches eight times per 256 cycles.

For an all-lanes, all-channels row with 8 lanes x 32 channels active:

| rate_88fp | requested aggregate | delivered theoretical at 250 Mhit/s ceiling |
|---|---:|---:|
| `0x0100` | 125.000 Mhit/s | 125.000 Mhit/s |
| `0x0400` | 500.000 Mhit/s | 250.000 Mhit/s |
| `0x0800` | 1000.000 Mhit/s | 250.000 Mhit/s |
| `0x1000` | 2000.000 Mhit/s | 250.000 Mhit/s |
| `0x2000` | 4000.000 Mhit/s | 250.000 Mhit/s |
| `0x4000` | 8000.000 Mhit/s | 250.000 Mhit/s |
| `0x8000` | 16000.000 Mhit/s | 250.000 Mhit/s |

The earlier rough arithmetic that treated `0x8000` as 62.5 Mhit/s aggregate
omitted the active channel multiplier. With the row masks applied, a full
8-lane x 32-channel row at `0x0100` is already exactly at the 50% BASIC/PERF
boundary.

## Phase 4.5 BASIC/PERF buckets

Each Phase 4.5 row carries an explicit `bucket` field:

- `BASIC`: requested aggregate rate is below 50% of the OPQ ceiling
  (`requested_hps < 125e6` for the May 2026 250 MHz OPQ target). These rows are
  expected to be lossless apart from normal tolerance.
- `PERF`: requested aggregate rate is at or above 50% of the OPQ ceiling.
  These rows probe the saturation curve. When `requested_hps > 250e6`, the
  theoretical count is clipped at the OPQ ceiling before deltas are computed.

The row math is:

```text
active_channels = popcount(channel_mask) * popcount(lane_mask)
per_active_channel_hps = rate_88fp * (125e6 / 65536)
requested_hps = per_active_channel_hps * active_channels
requested_hits = requested_hps * run_window_ms / 1000
theoretical_hits = min(requested_hits, opq_ceiling_hps * run_window_ms / 1000)
sim_delta_pct = (sim_total_hits - theoretical_hits) / theoretical_hits * 100
board_delta_pct = (board_total_hits - theoretical_hits) / theoretical_hits * 100
```

The sim and board deltas are independent comparisons against theory. They are
not sim-vs-board deltas. The existing normalized sim-vs-board rate delta may
remain in HTML reports as a secondary cross-check only.
