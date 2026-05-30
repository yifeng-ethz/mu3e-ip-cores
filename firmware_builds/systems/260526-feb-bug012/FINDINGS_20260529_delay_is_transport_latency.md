# FINDINGS 2026-05-29 — delay-mode histograms TRANSPORT LATENCY, not in-frame phase

## TL;DR

The histogram delay-mode (`delay = gts_8n - hit_ts`) on the FEB v4 datapath
measures **transport latency** (arrival_gts − absolute-emission_ts), which is
**invariant to the injector `header_delay`** by construction. The flat slope
observed on silicon (+1350 ± 60 cyc across the entire `header_delay` sweep) is
**correct**, not a bug and not a measurement artifact. The kbriggl SIM reference
slope = −1 is a **different observable** — in-frame phase
(`frame_base − emission`) — which the MTS deliberately removes by absolutizing
the timestamp. The earlier transient "centroid slope ≈ −0.29" was peak/centroid
noise on a small background-subtracted feature; with a clean single-lane,
long-dwell sweep the slope is unambiguously flat (cen slope ≈ +0.01,
p05 ≈ +0.07, peak just jitters ±700 with no trend).

## Evidence

### RTL (the deciding code)

1. **Emitted timestamp is absolute.** `mutrig_injector_multiheader.vhd` only
   emits a bare 1-wire `coe_inject_pulse` at `(header + header_delay)` — it
   carries **no timestamp**. The emulator trigger engine stamps the hit:
   `frontend_trigger_engine.sv:441  geom_stage_tcc <= tcc_anchor;`
   `tcc_anchor` is the **free-running** PRBS15 coarse anchor sampled at dispatch
   (not re-zeroed per frame). The MTS then reconstructs
   `hit_out_debug_timestamp = (cc + counter_ov_base_1n6)/5`
   (`mts_processor.vhd:2112`), i.e. it **adds the frame overflow base**
   (`counter_ov_base_1n6`, line 818/1517-1548) → the emission ts is **absolute**.

2. **Subtracted reference is also absolute (arrival).** The gts-unify exports
   `coe_hit_arrival_gts_8n <= counter_gts_8n` (`mts_processor.vhd:2294`).
   `counter_gts_8n` (line 823, 1570-1577) is a **free-running** global counter,
   +1/cycle — i.e. the hit's **arrival** time, not a frame anchor.

3. Therefore `delay = counter_gts_8n − hit_out_debug_timestamp
   = (H + d + L) − (H + d) = L` (transport latency). The frame phase `d`
   (= `header_delay`) cancels. The MTS already computes exactly this internally
   as its `debug_ts` (line 2366:
   `debug_delay_delta16(counter_gts_8n, tcc_div_quotient_d)`).

### Silicon (FEB SciFi, link 2, post gts-unify SOF)

| sweep | config | cen slope | p05 slope | peak slope |
|---|---|---|---|---|
| `/tmp/feb_bug012_plots/p05_singlelane.json` | LANE_EN=0x01, bg=0x80000, hdr_int=8, dwell=2.2, win[-4096,+4096) BW=32 | **+0.011** | +0.073 | −0.025 (noise) |
| `/tmp/feb_bug012_plots/p05_sweep.json` | LANE_EN=0xFF, bg=0x40000 | flat | −0.076 | n/a |
| idle (bg OFF) | E_BACKGROUND=0 & E_CENTRAL=0 | EMPTY — injector rides the frame hit stream; no hit source ⇒ no injected hits |

Injected-feature centroid stays at +1350 ± 60 cyc for every `header_delay` in
0..960. The −0.29/−0.39 seen in one earlier `delay_slope_strong.json` run was the
diff peak/centroid bouncing on a ~2-3k-count feature, not a real trend.

## Why kbriggl shows slope −1 and this datapath does not

- **kbriggl (real MuTRiG3 model)** measures **in-frame phase**: the coarse
  counter is read **relative to the frame header** (wraps at FRAME_INTERVAL_SHORT
  = 910). Injecting later in the frame ⇒ larger in-frame ts ⇒ smaller
  `(frame_anchor − ts)` ⇒ slope −1, wrap at 910. (memory:
  `project_kbriggl_offset_scan_reference`.)
- **This datapath** measures **absolute arrival − absolute emission** = latency.
  The MTS reconstruction (`+ counter_ov_base`) and the free-running arrival
  counter both re-absolutize, so the frame phase cancels. This was true **before
  and after** the gts-unify — the original hist used its own SYNC-zeroed
  free-running counter sampled at arrival, which is also arrival-relative. The
  gts-unify only removed the ±2^20 per-SYNC offset wander (the real BUG-012-R);
  it did not change the observable *type*. The "expected slope −1" premise
  conflated kbriggl's in-frame-phase scan with this datapath's latency histogram.

## To actually reproduce slope −1 (in-frame phase) — requires RTL + recompile

Need a **frame-anchored** reference instead of the per-hit arrival gts. Options
(all ~1-signal MTS export + hist re-point, same scope as the gts-unify, then a
~50 min FEB recompile + reflash):

1. **Export the frame base** `counter_ov_base_1n6/5` co-sampled on the hit beat;
   hist computes `frame_base − hit_ts` ⇒ delay = −d (slope −1, wraps at the
   frame interval), and it is **stable** (same MTS epoch as emission).
2. **Export the raw in-frame coarse** `cc_out/5` directly; histogram it as the
   delay key ⇒ peak at `d` (slope +1), wrap at frame interval.
3. **CSR-selectable reference** (arrival gts vs frame base) following the
   existing CTRL[3:2] source-select pattern, so the hist can do **both** the
   latency histogram (current) and the in-frame-phase histogram.

The current transport-latency histogram remains valid and useful for readout-
latency monitoring; in-frame phase is the additional physics observable.
