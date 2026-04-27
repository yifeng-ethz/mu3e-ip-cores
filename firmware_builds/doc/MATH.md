# MATH.md - Phase-5 latency and rate model sketch

Date: 2026-04-27

This is the lightweight system view that should seed the Phase-5 TLM. Treat it
as a staging document; detailed equations can be expanded after the first live
MuTRiG evidence set.

## Timing Units

- MuTRiG TDC coarse/fine counters originate in the ASIC timing domain.
- The FEB datapath normalizes MuTRiG-local timestamps into the 125 MHz global
  timestamp domain used by the hit stack.
- `emulator_mutrig` uses `FRAME_INTERVAL_SHORT = 910` cycles for short SciFi
  frames.
- MTS delay checks compare the local global timestamp against the corrected
  hit timestamp. The active Phase-5 system sets the expected-latency CSR to
  4096 8 ns ticks for the two MTS preprocessors.

## Stage Model

The full latency model should be written stage by stage:

1. MuTRiG source: physical hit or injected TDC hit creates an ASIC timestamp.
2. LVDS receive and frame deassembly: 8b/10b symbols become `hit_type0` words
   plus CRC/frame/hit error flags.
3. MTS preprocessor: gray-code timestamp decode, overflow/lapse correction,
   divide-by-5 conversion from 1.6 ns ticks to 8 ns plus remainder, optional
   long-hit E-T derivation, and timestamp-delay error sideband.
4. Hit stack: two segmented subsystems buffer/resequence by corrected global
   timestamp.
5. FEB frame assembly and packet scheduling: post-hit-stack words are framed
   for the SWB.
6. Histogram monitor: selected pre/post stream words are binned by
   `histogram_statistics_0` for rate and delay diagnostics.

## Queue-Depth Gate

`histogram_statistics_0` uses `COAL_QUEUE_DEPTH=256`, matching the all-channel
injection bound for eight MuTRiG ASICs:

```text
8 ASICs * 32 channels per ASIC = 256 possible histogram bins per injected frame
```

The model in `histogram_statistics/model/MODEL_REPORT.md` shows why the old
160-entry depth is not safe for adversarial all-channel injection. The Phase-5
build must keep the 256-depth queue, and the standalone TLM/RTL queue gate must
pass before live rate tests are trusted.

Current Phase-5 evidence:

- queue TLM/RTL comparison: 1190 cycles, 0 mismatches;
- standalone histogram DV: 27 pass, 0 fail;
- standalone histogram synthesis: slow-85 setup slack +0.129 ns at 7.273 ns;
- active DP E2E simulation: 7 pass, 0 fail, histogram total 506, dropped 0.

## Lock Interpretation

`testbeam-2025_data_format.pptx` slides 29..35 provide the qualitative truth
table for delay PDFs:

- narrow peak: locked deterministic timing;
- narrow peak plus small hot-noise contribution: mostly locked with noisy
  channels;
- broad distribution: timestamp not trustworthy, typically PLL or receive-side
  lock issue;
- aliased distribution: reduced timestamp width or local timestamp guess mode
  makes the plot visually confusing but still useful as a lock diagnostic.

`eth_mu3e_jamboree.pptx` slides 2..10 are the reference for MuTRiG timestamp to
global timestamp conversion and the resequencing-buffer/network-calculus view.
