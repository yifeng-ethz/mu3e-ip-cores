# Agent Notes

- Never modify generated RTL under any `functional/` output directory in-place. If a change is needed, create a copy and ask for approval before wiring it in.
- Semantics-preserving edits for tool/simulator compatibility are OK; functional/behavior changes require explicit approval.
- Shared System Console toolkit sources live under `toolkits/`.
- The FE SciFi toolkit source of truth is `toolkits/fe_scifi/`.
- `online_dpv2` consumes the FE SciFi toolkit through the compatibility path `/home/yifeng/packages/online_dpv2/online/mu3e-ip-cores/toolkits`, which must resolve back to this repo.
- `/home/yifeng/packages/online_dpv2/online/mu3e-ip-cores` is only a compatibility symlink into the deprecated snapshot area. Do not add or update toolkit sources under its `toolkits/` tree.
- For RTL modeling tasks, use the `modeling-rtl` workflow: start from upstream slides/spec/source RTL and analytical truth, then make TLM, RTL simulation, and on-board evidence converge to that abstraction.
- `firmware_builds/systems/system_20260427_testplanphase5/model/` is the durable three-tier model tree (`analytical/`, `tlm/`, `on_board/`, and phase-specific model evidence). `firmware_builds/systems/system_20260427_testplanphase5/script/`, `reports/`, and `signaltap/` are the live board-test locations; canonical test plans live under `firmware_builds/doc/`.
- Treat the Mu3e slides and reviewed upstream source artifacts as truth. If TLM, RTL simulation, and board evidence disagree in an abstracted DISLIN plot, debug the lower level first instead of tuning the high-level model to a bad lower-level observation.
- Phase 4 closure is gated by `firmware_builds/doc/phase4/TEST_PLAN_BASIC.md`: the BASIC-like bucket must include TLM, RTL simulation, on-board, and cross-layer DISLIN evidence for its directed cases before Phase 4 is called closed.

## Phase 4 emulator + histogram verification workflow (TLM -> RTL SIM -> board)

Authoritative catalog: [`firmware_builds/doc/phase4/TEST_PLAN_BASIC.md`](firmware_builds/doc/phase4/TEST_PLAN_BASIC.md).
Closure contract: [`firmware_builds/doc/TEST_PLAN.md`](firmware_builds/doc/TEST_PLAN.md) plus [`firmware_builds/doc/phase4/TEST_PLAN_BASIC.md`](firmware_builds/doc/phase4/TEST_PLAN_BASIC.md).
Publication-grade figure catalog (chief-architect-facing, DISLIN-rendered, 28 sets): [`firmware_builds/doc/phase4/TEST_PLAN_PUBLISH.md`](firmware_builds/doc/phase4/TEST_PLAN_PUBLISH.md). Every figure set is enforced by the codex `scientific-plotting` skill — DISLIN `Warnings: 0`, visual checklist passes, sequential darker-is-worse palette on every loss/risk surface, color-bar height matched, sub-unit decimal digits restored, golden references frozen under `artifacts/publish/golden/`.
Canonical board playbook: [`firmware_builds/doc/TEST_PLAN.md`](firmware_builds/doc/TEST_PLAN.md).

### Wiring contract - required before any rate/latency claim

A rate or latency number measured on any layer is meaningless until the upstream wiring is live and verified. In order:

1. The 8 x `emulator_mutrig_N` instances are reachable through `mm_bridge` and produce monotone `frame_count` / `event_count` (per `firmware_builds/doc/TEST_PLAN.md` section 4.2).
2. The `mutrig_injector` / `charge_injection_pulser` aperture is reachable, and the `coe_inject_pulse` / `coe_inject_masked_pulse` conduits are wired into every emulator (`emulator_mutrig/rtl/emulator_mutrig.sv:55..57`). The injector is armed only inside `RUNNING` (the `INJ_ARM` SignalTap trigger never fires elsewhere).
3. `histogram_ingress_bridge_0` and `histogram_statistics_0` are reachable; the histogram UID returns `0x48495354`; `TOTAL_HITS` advances together with the SWB per-link counter.

If any item fails, no Phase 4 case runs. Document the failure in the case's report; do not proceed by inventing observations from a half-wired chain.

### Upstream slide deck = art-of-truth for delay distribution

The MuTRiG delay distribution we expect to see is fixed by the upstream slides at
`docs/Archive/ethhw_reordering.pdf` (extract `docs/Archive/` from `docs/Archive.zip` once to read the PDFs). Treat these as the architecturally correct shapes:

| Slide | Truth |
|---|---|
| Slide 23 | random-injection latency PDF spans roughly one frame interval (rate-1 example, V ~= 800-1100 cycles) |
| Slide 24 | injection mode 1: header-delay sweep produces a delta pulse at `(FRAME_INTERVAL_SHORT - header_delay)`; full traversal across `[0, FRAME_INTERVAL_SHORT]` as header_delay sweeps |
| Slide 25 | injection mode 2 (rate sweep, `r=1..7`): latency PDF is one block whose right edge grows monotonically; reaches roughly 0-to-2 frames at the wire-speed cap (rate=7) |
| Slide 38 | ingress vs egress (Figure 4(a)): the re-sequencer shifts the block by `T = V` and otherwise preserves the shape |
| Slides 40-42 | ring-CAM fill-level PDFs across rate and inject_interval |

The Python TLM in [`firmware_builds/systems/system_20260427_testplanphase5/model/phase4/scripts/phase4_queue_tlm.py`](firmware_builds/systems/system_20260427_testplanphase5/model/phase4/scripts/phase4_queue_tlm.py) and the HDL TLM in [`firmware_builds/systems/system_20260427_testplanphase5/model/phase4/tlm/phase4_latency_tlm.sv`](firmware_builds/systems/system_20260427_testplanphase5/model/phase4/tlm/phase4_latency_tlm.sv) are calibrated to reproduce these shapes; [`firmware_builds/doc/phase4/MATH_REPORT.md`](firmware_builds/doc/phase4/MATH_REPORT.md) records the constants. Any change to the TLM that breaks agreement with the slides above must be reverted.

### TLM -> RTL SIM -> board, with DISLIN in-situ comparison

For every Phase 4 basic-bucket case (TPB000..TPB100 in `TEST_PLAN_BASIC.md`):

1. Run the TLM form via [`firmware_builds/systems/system_20260427_testplanphase5/model/phase4/scripts/run_phase4_tlm.sh`](firmware_builds/systems/system_20260427_testplanphase5/model/phase4/scripts/run_phase4_tlm.sh) and `scripts/phase4_queue_tlm.py`. The TLM is the architecturally correct shape; do not edit it to fit a measurement.
2. Run the RTL SIM form via [`firmware_builds/systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_e2e.sh`](firmware_builds/systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_e2e.sh) or [`run_dp_hist_rate_sweep.sh`](firmware_builds/systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_hist_rate_sweep.sh) with the case's `TB_DP_*` plusargs.
3. Run the on-board form via [`firmware_builds/systems/system_20260427_testplanphase5/script/run_phase4_emulator.py`](firmware_builds/systems/system_20260427_testplanphase5/script/run_phase4_emulator.py) and [`probe_phase4_stage_counters.py`](firmware_builds/systems/system_20260427_testplanphase5/script/probe_phase4_stage_counters.py).
4. Render the in-situ DISLIN comparison via [`firmware_builds/systems/system_20260427_testplanphase5/model/phase4/scripts/render_phase4_plots.sh`](firmware_builds/systems/system_20260427_testplanphase5/model/phase4/scripts/render_phase4_plots.sh). The comparison must overlay all three layers (TLM + RTL SIM + BOARD) on one plot so disagreements are immediately visible.

When DISLIN shows the three layers do not agree, the disagreement protocol is:

- TLM is treated as truth.
- If RTL SIM disagrees with TLM, debug RTL: `emulator_mutrig/rtl/emulator_mutrig.sv`, `histogram_statistics/rtl/histogram_statistics.vhd`, `histogram_statistics/rtl/coalescing_queue.vhd`, then the integration tb stimulus.
- If on-board disagrees with RTL SIM, debug the integration: flash state, SC bridge address, `histogram_ingress_bridge_0` mode, ping-pong interval, link L2 jitter.
- Never edit the TLM to make a buggy SIM agree with the board, and never edit the SIM to make a buggy board number agree with the TLM.

### Histogram-overflow pre-gate is mandatory before Phase 4 closure

The `histogram_statistics` IP is the rate and latency observation surface for every Phase 4 case. If it overflows under any traffic pattern in the basic bucket, every downstream rate or latency number is unreliable. The pre-gate is the TPBH001..TPBH030 series in `TEST_PLAN_BASIC.md` and proves overflow stays at zero across (iid Poisson, local 8-channel cluster, roaming cluster-8, 50/50 mixed, all-channel injection burst) at the 200 Mhit/s aggregate cap on TLM, standalone tb (`histogram_statistics/tb/`), RTL integration sim, and on-board.

Phase 4 cannot be marked closed until the pre-gate is signed (case TPBH030 PASS in `firmware_builds/systems/system_20260427_testplanphase5/reports/phase4_overflow_pregate_<date>.md`).
