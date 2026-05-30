# Findings — Hist Delay-Mode "no slope=-1" Root Cause (260526-feb-bug012)

**Date:** 2026-05-28 (continuation of `HANDOVER_20260528.md`)
**Method:** live silicon probing (link 2, swb_ring_lock + sc_tool) + RTL forensic on the
exact compiled build (`generated/synthesis/feb_system_v4/synthesis/submodules/`).
**Status:** root cause established with high confidence. No RTL changed.

---

## TL;DR (what was actually wrong with the investigation)

The handover concluded the work was *blocked on real-MuTRiG being silent
(`open_frame_count=0`)*. That framing was a **measurement error**. Several layered
findings:

1. **`open_frame_count=0` is correct, not a fault.** It is the **real-LVDS path**
   frame counter only. The emulator emits *already-parsed* 45-bit hit_type0 packets
   that join the datapath at `merger_hit_type0` (`SOURCE_SEL_DEFAULT=1`=EMU),
   **downstream of `frame_deassembly`**. There is no mux feeding emulator data into
   `frame_rcv_ip`. So with the emulator on, `open_frame_count` can never move.
   *Evidence:* subsys.vhd:5865/6921 (frame_deassembly.decoded_din hard-wired to
   LVDS), 4835-4848 (emu joins at merger), BYTE_STREAM_ENABLE=false subsys.vhd:3912.
   *Confirmed on silicon:* background TYPE0 count histogram saturates all 256 bins
   across 8 ASICs while `open_frame_count` stays 0. **The emulator→hist path is alive.**

2. **The emulator's coarse-timestamp LFSR is bit-exact faithful to the MTS decode.**
   Emulator `prbs15_step = {s[13:0], ~(s[14]^s[13])}` (poly x¹⁵+x¹⁴+1 XNOR, 5 steps/cyc,
   be_mutrig_pkg.sv:53-58) is the *exact* sequence the MTS `cc_lut` ROM
   (`dual_port_rom_init.txt`, 32768 entries, present in build + .qip-registered)
   decodes back to a monotonic count — verified 0 mismatches over the full period.
   So emulator timestamps decode correctly; they are **not random garbage**.

3. **The hist delay-mode measures readout LATENCY, frame-quantized.** Key:
   `delay = (gts_8n − hit_ts) mod 2²¹`, `hit_ts = (cc_out + counter_ov_base_1n6)/5`
   (the MTS absolute reconstructed emission ts), `gts_8n` = free-running hist counter
   at the moment of binning. With **background on**, the measured distribution width
   is **fwhm ≈ 1536c ≈ FRAME_INTERVAL_LONG (1550c)** — i.e. random-phase hits spread
   uniformly over **one frame period**. That width is the signature of
   **frame-quantized readout**: `delay = frame_phase + const`. This is the *same kind*
   of quantity kbriggl's slope=-1 measures (frame phase vs offset). So the metric is
   right in principle.

4. **THE REAL SILICON BUG — SYNC-origin mismatch (non-reproducible offset).** The
   hist `gts_8n` is zeroed by `run_state_cmd=SYNC` (histogram_statistics_v2.vhd:1132),
   while the MTS reconstructed-ts counters (`counter_gts_8n`, `counter_ov_base_1n6`)
   are zeroed by the *separate* MTS run-control `processor_state=RESET,reset_flow=SYNC`
   (mts_processor.vhd:1509,1557). These are two independently-reset counters. Their
   relative offset is **random per SYNC**: measured peak sat at delay ≈ **−1028096**
   (one run) and **+39024** (next run) — a jump of ≈ 2²⁰ cycles. This shifts the whole
   (otherwise frame-phase) distribution to an unpredictable absolute location, almost
   always **outside** the default window `[-1000,+3096)` → reads as **empty**; when it
   grazes the window you get the **erratic peaks** seen yesterday. *Yesterday's "peaks
   move with offset but not slope=-1" was the per-SYNC offset jitter* (the old
   `sweep_ext0_correct.py` re-SYNCs every offset), **not** a header_delay response.

5. **The emulator injector cannot be isolated as a clean fixed-phase source.**
   `inject_pulse` is acted on **only when `engine_occupied`**
   (frontend_trigger_engine.sv:303) — i.e. background/signal must already be in flight.
   **Background-OFF → injector-only → ZERO hits** (confirmed: all 8 delay-space tiles
   empty). And every dispatched hit's coarse ts comes from a *shared free-running LFSR*
   sampled at dispatch (`ts_a <= pending_tcc`, line 177; `geom_stage_tcc <= tcc_anchor`,
   line 441), advancing per dispatch — so a single injected hit's sharp frame-phase
   peak is always buried under the uniform background smear, and `header_delay` does
   not cleanly stamp the hit's frame phase.

### Bottom line
The histogram delay path's *math is correct* and the readout *is* frame-quantized, so
the slope=-1 sawtooth is the right expectation in principle. But on the FEB **emulator**
path it cannot be cleanly demonstrated because (a) the gts/MTS **SYNC origins are
independent → random per-SYNC offset** slides the distribution out of any fixed window,
and (b) the emulator injector **can't be isolated** from background (engine_occupied
gate) so the fixed-phase peak is masked. A faithful slope=-1 demonstration needs the
SYNC-origin fixed AND a clean fixed-phase hit source (real MuTRiG, or an injector RTL
tweak). The handover's instinct that "real MuTRiG is needed" is correct — but the
reason is the SYNC-origin/injector-isolation issues, not `open_frame_count`.

---

## Evidence ledger (silicon)

| Test | Result | Meaning |
|---|---|---|
| `feb_hist_read.py` background TYPE0 count | TOTAL_HITS=0xfffff, 256/256 bins, 8 ASICs | emulator→hist alive |
| `open_frame_count[0..7]` with emu on | all 0 | expected (LVDS-only counter) |
| TYPE1_UP **count** mode (mode0) | sum=9.4M, 9 bins | TYPE1 hits reach hist; MTS reg4 +33M/s |
| TYPE1_UP **delay** mode, window [-1000,+3096) | **0** | delay outside default window |
| Window-position scan (BW=1024, tile 2²¹) | peak at delay≈−1028096 (run A) | distribution exists, far off-window |
| Lean no-resync sweep (bg on) | peak flat ~+39024 (run B), fwhm 1536 | offset jumped 2²⁰ vs run A; width=frame period |
| Background-OFF, injector-only, all tiles | **0 everywhere** | injector needs engine_occupied |

Artifacts: `/tmp/feb_bug012_plots/*.json` and `*.log`; analysis scripts
`/tmp/feb_*.py`, `/tmp/analyze_delay_sweeps.py`.

---

## Fix options (ranked)

1. **RTL — unify the gts reference (correct fix).** Drive the histogram `gts_8n` from
   the MTS `counter_gts_8n` (same SYNC-zeroed origin as `hit_ts`), or otherwise
   guarantee a single SYNC zero shared by both. Then `delay` = pure readout latency,
   reproducible and centered near the small pipeline latency. *Effort:* RTL edit +
   standalone tb + standalone syn + full FEB recompile (~50 min). *Files:*
   histogram_statistics_v2.vhd gts source (≈1261-1270, 1118-1133), the conduit from
   mts_processor (`coe_hit_type1_ts` already carries the MTS-domain ts; add a parallel
   `coe_gts_8n`).

2. **RTL — let the injector fire with the engine idle (enables isolation).** Relax the
   `inject_pulse && engine_occupied` gate (frontend_trigger_engine.sv:303) so an inject
   launches a hit standalone, and stamp that hit's ts from the inject cycle. Then a
   clean fixed-phase injected-hit sweep can show slope=-1 directly on the emulator.
   *Effort:* RTL edit + tb + syn + recompile. Combine with #1.

3. **Real MuTRiG (faithful demonstration).** Real ASICs give clean fixed-phase hits
   with a real monotonic TCC; with #1 applied, the hist delay then shows the expected
   latency / frame-phase behavior. Currently the ASICs are silent — a *physical*
   hardware check (power, firefly/ribbon) is still required (handover §"blocked").

4. **CSR-only — set short_mode + re-center window (diagnostic only).** Set EMU
   MUTRIG_FORMAT short_mode (0x0A bit0) for the 910c wrap, localize the per-SYNC offset
   by tiling, then place the window there. Lets you *see* the distribution, but the
   per-SYNC offset (#4 root cause) makes it non-reproducible — masks, doesn't fix.

---

## Corrections to prior handover / memories

- `open_frame_count=0` is **not** the blocker; the emulator bypasses `frame_rcv`.
- "Emulator TCC is pseudo-random garbage" (a mid-investigation hypothesis) is **wrong**:
  the LFSR is bit-exact decoded by the MTS cc_lut ROM.
- The slope=-1 mismatch is **not** background-noise contamination (tested) nor a window
  size issue alone — it is the **SYNC-origin offset** + **injector-isolation** limits.
- The expected_latency CSR (2000c) is **not** subtracted in the datapath (dead;
  mts_processor.vhd ~2094/2105) — it only feeds a delay-error flag.
