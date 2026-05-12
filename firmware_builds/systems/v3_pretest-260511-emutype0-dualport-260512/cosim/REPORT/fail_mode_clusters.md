# RN.BASIC Fail-Mode Clusters

- Trace CSV: `fail_mode_trace.csv`
- Fail rows tabulated: 160
- Targeted reruns: `fail_mode_rerun/RN.BASIC.062/`, `fail_mode_rerun/RN.BASIC.129/`, `fail_mode_rerun/RN.BASIC.205/`
- First-loss rule: first downstream counter in `emul_mutrig -> mfd_frame -> arb_sel -> rbcam_push -> rbcam_pop -> feb_asm -> swb_ingress -> opq_egress -> rdma_hits -> hist_csr13` that is below `0.95 * theoretical_hits`.

## Cluster Summary

| first_loss_ip | slice | rows | loss mean | loss min | loss max | mean equivalent error | sample rows |
|---|---:|---:|---:|---:|---:|---:|---|
| opq_egress | 1 | 96 | 10936.9 | 204 | 81088 | 28256.0 | RN.BASIC.002, RN.BASIC.003, RN.BASIC.004 |
| emul_mutrig | 2 | 32 | 5886.6 | 138 | 35328 | 0.0 | RN.BASIC.129, RN.BASIC.130, RN.BASIC.131 |
| opq_egress | 4 | 32 | 24429.2 | 8993 | 74407 | 50731.0 | RN.BASIC.177, RN.BASIC.178, RN.BASIC.179 |

## Cluster Detail

### opq_egress / slice 1

- Rows: 96
- Loss counter: mean 10936.9, min 204, max 81088
- Mean equivalent error counter: 28256.0
- Sample rows: RN.BASIC.002, RN.BASIC.003, RN.BASIC.004
- Closure recommendation: FIX (cosim infra patch needed)

The FE-side source, frame-deassembly, arbiter, rbCAM, FEB assembly, SWB ingress, and histogram counters remain at theory while OPQ/RDMA egress falls below the 5% window. The immediate loss is downstream of SWB ingress; the zero arbiter drop counter rules out arb_hit_type0 as the first failing stage. The baseline sweep also drove unselected RN.BASIC lanes/channels into the corun source model because the source model ignored the RN_BASIC masks, so part of this cluster is a sim-infrastructure overload artifact; full-mask rows may still expose a real OPQ/DMA ceiling. Patch the corun source masking first, then retest a low-mask row and a full-mask high-rate row before calling this an RTL ceiling.

Targeted rerun verdict: `RN.BASIC.062` PASS after the corun source model consumed `RN_BASIC_LANE_MASK` and `RN_BASIC_CHANNEL_MASK`. Evidence: `fail_mode_rerun/RN.BASIC.062/RN.BASIC.062/`; csr/hist/rdma all report 245 against 244 theoretical, OPQ egress is 245, and all error counters are zero. Verdict: the low-mask slice-1 failures were cosim source-overload artifacts; full-mask high-rate rows still need a separate ceiling decision before the whole slice-1 cluster can be closed.

### emul_mutrig / slice 2

- Rows: 32
- Loss counter: mean 5886.6, min 138, max 35328
- Mean equivalent error counter: 0.0
- Sample rows: RN.BASIC.129, RN.BASIC.130, RN.BASIC.131
- Closure recommendation: FIX (cosim infra patch needed)

The source-generation counter is already below theory, and all downstream counters preserve that smaller count. This points at the header-sync stimulus model rather than rbCAM, arbiter, SWB, or histogram loss. The corun header-sync generator emits one all-channel burst per virtual short-frame header, which gives about 138 samples per 1 ms instead of the 0x0100 periodic-rate expectation in the row table. Treat this as a cosim/test-infrastructure model mismatch until the headerinfo cadence is explicitly tied to the RN.BASIC theory.

Targeted rerun verdict: `RN.BASIC.129` FAIL in the same signature as baseline. Evidence: `fail_mode_rerun/RN.BASIC.129/RN.BASIC.129/`; source/csr/hist/rdma all conserve 35,328 hits, but theory is 125,000. Verdict: this is not downstream loss; header-sync source cadence is under-generating relative to RN.BASIC theory.

### opq_egress / slice 4

- Rows: 32
- Loss counter: mean 24429.2, min 8993, max 74407
- Mean equivalent error counter: 50731.0
- Sample rows: RN.BASIC.177, RN.BASIC.178, RN.BASIC.179
- Closure recommendation: FIX (cosim infra patch needed)

The emulator-only source and FEB-side counters are at theory, but OPQ/RDMA egress is consistently short while arbiter drops remain zero. The row-to-row shortfall is nearly independent of the poisson/signal ratio, which suggests a downstream OPQ/DMA readout or trace-matching limit rather than a stochastic hit-generation error. As with slice 1, the baseline source model ignored RN_BASIC lane masks, so low-lane rows were overdriven in sim. Re-run after source-mask wiring; if full-mask rows still fail, defer classification to board evidence or debug the SWB OPQ/DMA path.

Targeted rerun verdict: `RN.BASIC.205` PASS after the same source-mask patch. Evidence: `fail_mode_rerun/RN.BASIC.205/RN.BASIC.205/`; csr/hist/rdma all report 15,631 against 15,625 theoretical, OPQ egress is 15,631, and all error counters are zero. Verdict: low-lane slice-4 failures were cosim source-overload artifacts; all-lane emulator-only rows still need a full-mask follow-up or board correlation before accepting an OPQ ceiling.

## Closure Plan

| cluster | recommendation | human input needed |
|---|---|---|
| opq_egress / slice 1 | FIX (cosim infra patch needed) | yes - full-mask high-rate rows need retest/board correlation |
| emul_mutrig / slice 2 | FIX (cosim infra patch needed) | no |
| opq_egress / slice 4 | FIX (cosim infra patch needed) | yes - all-lane emulator-only rows need retest/board correlation |
