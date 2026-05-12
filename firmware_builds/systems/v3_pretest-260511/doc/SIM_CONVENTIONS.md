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
