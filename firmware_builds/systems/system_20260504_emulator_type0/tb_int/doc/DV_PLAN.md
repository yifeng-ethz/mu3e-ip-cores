# Integration Testbench: `system_20260504_emulator_type0/tb_int/`

**DUT:** `top_nostp_emulator_type0` (full FEB SciFi single-lane focus build).
**Companion docs:** [`../../doc/SYSTEM_PLAN.md`](../../doc/SYSTEM_PLAN.md), [`DV_HARNESS.md`](DV_HARNESS.md), [`BUG_HISTORY.md`](BUG_HISTORY.md).
**Author:** Mu3e IP team
**Date:** 2026-05-06
**Status:** Draft. Awaits approval before harness construction.

---

## 1. Purpose & Scope

`tb_int/` is the **integration UVM testbench** that verifies the full datapath of `system_20260504_emulator_type0` end-to-end with all IPs in the loop. It is the layer between standalone IP DV (e.g. `mu3e-ip-cores/misc/arb_hit_type0/tb/`) and the on-board bring-up.

The default PROF-INT-002 generated-system tests drive traffic from the generated internal `emulator_mutrig_qsys_lane` instances in the full8lane type0 Qsys system. These default runs use the emulator's direct hit_type0 stream (`BYTE_STREAM_ENABLE=0`) and do not exercise a real external MuTRiG, the LVDS PHY pins, or `mutrig_frame_deassembly`. PROF-INT-002 also has a first virtual-source mode selected by `+TB_INT_SOURCE=virtual_mutrig` / `PROF_INT_002_SOURCE=virtual_mutrig`: it instantiates the tagged `raw_mutrig_frame_top` MuTRiG frame generator and drives the generated decoded-lane 0 adapter input, so the checked datapath becomes `raw_mutrig_frame_top` -> generated decoded-lane adapter -> `mutrig_frame_deassembly` -> `arb_hit_type0` -> `backpressure_fifo` -> `mutrig_timestamp_processor` -> `ring_buffer_cam` -> `histogram_ingress_bridge` -> `histogram_statistics`. This virtual-source path intentionally bypasses LVDS PHY/DPA lock behavior, but it keeps the generated Qsys adapter and frame deassembly path in the loop for pre-rbCAM rate/header-sync evidence.

### In scope

1. **Run-control verification (RC):** `runctl_mgmt_host` ↔ `run_control_splitter` ↔ every IP. Verify `IDLE → RUN_PREP → SYNC → RUNNING → TERMINATING → IDLE` is broadcast correctly and every IP reacts per its own contract.
2. **Slow-control verification (SC):** `sc_hub_v2` ↔ `mm_bridge` ↔ every CSR slave on the focus build. Verify CSR addressing, address-aperture bounds, and read/write atomicity.
3. **Datapath verification (DT):** end-to-end hit tracking from virtual-MuTRiG-emitted hits to histogram-statistics bin counts. Per-bucket FIFO-ledger scoreboard catches dropped, reordered, mis-attributed, and corrupted hits.
4. **Latency measurement at three observation points:** pre-rbCAM (immediately at `ring_buffer_cam` input / aggregate `data_splitter_0_out[0:3]` boundary for both hit-stack subsystems), post-rbCAM (after all eight `ring_buffer_cam` hit_type2 outputs), FEB-egress (both packet scheduler egresses in the 8-lane full-system harness). Latency CDFs, percentiles, and per-source breakdowns computed Python-side from exported CSV.
5. **Histogram cross-check:** compare the scoreboard's reconstructed delay distribution against `histogram_statistics_0`'s bin counts at the same tap point. Mismatch beyond the per-bucket-reconciliation threshold (set per case in `DV_COV.md`) is a fail.
6. **Reusable UVM infra:** every agent, scoreboard, and coverage collector is built so the same harness can be reused for future Mu3e integration testbenches by swapping the DUT-binding interface.

The virtual MuTRiG model in `mutrig_phy_agent` emits directly into per-lane L2 FIFOs (matching the 26.2.x `emulator_mutrig` architecture, which removed L1 staging per `emulator_mutrig/doc/RTL_PLAN.md` §2.1). The real-ASIC 32-channel → 4 L1 FIFO → 1 L2 FIFO RR-arbitration reordering is therefore NOT exercised by this harness; it is deferred to a future harness that uses the real LVDS / `mutrig_frame_deassembly` path with the bring-up SOF on the FEB.

**Basic run-control timing assumption.** In the deployed FEB flow, run-control state changes are driven by C++ software and are normally separated by software-scale time, i.e. orders of milliseconds rather than adjacent FPGA cycles. The integration TB therefore must not qualify a full-pipeline latency run by issuing `RUN_PREPARE` / `SYNC` / `RUNNING` or `TERMINATING` / `IDLE` back-to-back. PROF-INT-002 models this with `TB_INT_RUNCTL_CPP_GAP_CYCLES` (default 125000 cycles = 1 ms at 125 MHz) and must log the observed gap before the next state is driven. Run-control ready is not a command-acceptance contract in this build: commands are broadcast readyless, no slave may backpressure a state transition, and legacy local ready signals are sampled only as diagnostics until a future packet-based ACK path is defined.

**Pre-rbCAM latency sanity assumption.** PROF-INT-002 must first prove the source-to-pre-rbCAM path with ASIC0 only and two fixed channels (`TB_INT_HIT_CHANNEL_LOW=0`, `TB_INT_HIT_CHANNEL_HIGH=1`) before interpreting post-rbCAM or FEB-egress residuals. In `header_sync` mode, a single injected pulse creates exactly two Stage-A hits and two pre-rbCAM records; four pulses must therefore produce eight pre-rbCAM rows. Short-mode MuTRiG frames are 910 cycles, so the effective pulse phase is `TB_INT_INJECT_PHASE_CYCLES % 910`, interpreted as the injection delay after the MuTRiG header seen by the pulse driver. The expected wait-to-pack latency is approximately `910 - effective_phase + fixed_pipeline`: a 100-cycle offset should be near the maximum delay, and increasing the offset toward 800 cycles should reduce the peak nearly linearly toward the minimum delay. Around a 900-cycle offset the pulse is at the next-frame edge; the correct result may be a two-peak distribution with one group captured quickly in the next frame and another group delayed almost a full frame. Offsets greater than 910 cycles fold back modulo 910 and must follow the same effective-phase model. The acceptable debug-stage tolerance is +/-200 cycles, but away from the frame edge the expected shape is a narrow delta-like distribution around each phase point; if the count is not `2 * inject_pulse_count` or if the phase sweep does not follow this modulo-frame model, the run is a source/monitor bug and later rbCAM/FEB conclusions are blocked. In `periodic` mode, when the pulse period is not commensurate with the 910-cycle frame period, the injection phase walks relative to the MuTRiG header and the pre-rbCAM latency should become a plateau over roughly 100-900 cycles at low two-channel rate, widening toward at most two frames only as the typical rate increases.

**Single-active emulator lane identity assumption.** In single-active `header_sync` source-validation runs, the Stage-A and pre-rbCAM scoreboard lane is the selected physical Qsys emulator lane (`TB_INT_ACTIVE_LANE_MASK`), not the hit_type1 ASIC payload field. This keeps the latency measurement tied to the injected source lane while preserving the raw downstream payload in the monitor record. The payload ASIC field is still useful for datapath debug, but it is not treated as the physical-source selector in this direct internal-emulator profiling mode.

**Source-model and DEBUG_LEVEL contract.** tb_int now treats the three MuTRiG sources as distinct evidence classes. The tagged virtual MuTRiG source-code model at `/home/yifeng/kbriggl-mutrig3-c3cce8d41dcb` (`mutrig-smoke-stable-20260506`) is the simulation golden reference for real MuTRiG digital behavior. The generated `emulator_mutrig` instances are an FPGA/on-board-test compromise that can match useful latency shapes but are not the virtual MuTRiG. The real MuTRiG is the physical ASIC measured on board. `TB_INT_SOURCE=emu_direct` keeps the generated emulator direct stream; `TB_INT_SOURCE=virtual_mutrig` is currently lane0-only and feeds the decoded-byte virtual source into `mutrig_frame_deassembly`. For upgraded datapath IP, `DEBUG_LEVEL=0` keeps the nominal synthesizable data path and monitor payload; `DEBUG_LEVEL=1` adds synthesizable debug observability such as FIFO fill levels; `DEBUG_LEVEL=2` is cumulative and additionally carries per-hit debug metadata for simulation-only OoO scoreboard lineage.

The integration UVM structure mirrors the tagged virtual MuTRiG smoke structure at the analysis boundary rather than by instantiating a second generated Qsys DUT. The nominal `stage_a` / pre-rbCAM / post-rbCAM / FEB monitor path remains the synthesizable-payload check and is the only path exported to the latency CSVs. A separate `debug_source` analysis path samples the first DEBUG_LEVEL=2 sidecar-bearing stream: generated-emulator metadata at the direct emulator hit_type0 output for `emu_direct`, and `mutrig_frame_deassembly` metadata at the decoded virtual MuTRiG hit_type0 output for `virtual_mutrig`. The scoreboard reconciles `debug_source -> pre-rbCAM -> post-rbCAM -> FEB` by sidecar ID as the OoO lineage model, logs debug/no-debug residual mismatches, and treats missing sidecar IDs as a closure blocker rather than silently falling back to FIFO-key identity. This is the tb_int analogue of the virtual MuTRiG primary DEBUG_LEVEL=2 DUT plus shadow no-debug DUT: one shared stimulus sequence, one nominal payload check, one debug-rich lineage check, and explicit cross-check reporting between them.

**Header-sync burst-scan status.** Header-sync source validation must scan phase or per-frame burst multiplicity, not periodic rate; the periodic/rate scan belongs only to `periodic` mode where the injection period walks relative to the 910-cycle frame. The intended full8/full32 header-sync burst reference is phase 100 with all eight ASICs active, all 32 channels enabled, and `1..7` pulses per frame separated by 10 cycles. As of `2026-05-06`, that all-active direct-emulator reference is blocked by BUG-009-H: the generated/direct-emulator observation path does not yet provide a trustworthy multi-active source identity at pre-rbCAM, and the sweep target must fail closed unless each burst produces exactly `128 * burst_count * 8 * 32` pre-rbCAM rows.

### Out of scope

- Quartus place-and-route timing closure (covered by `timing-performance-resources-sign-off` skill).
- SWB / FEB programming (on-board bring-up).
- Multi-lane integration (focus build is single-lane; multi-lane uses `arb_hit_type0_supercore`).
- Histogram **egress** snoop (deferred per user; capture is recorded as an open-item agent slot for a later patch).

---

## 2. UVM Infra (reusable)

All components under `tb_int/uvm/` follow the standard Mu3e UVM agent pattern (driver / monitor / sequencer / agent / config object). Reused components are placed under `tb_int/uvm/common/` so future integration testbenches consume them by import.

### 2.1 Agents

| Agent | Direction | Role |
|---|---|---|
| generated `emulator_mutrig_qsys_lane` source | active source inside the generated Qsys DUT | Current PROF-INT-002 source. Drives the direct internal hit_type0 stream from the generated emulator instances (`BYTE_STREAM_ENABLE=0`) and is controlled by PROF-INT-002 CSR/force plumbing. |
| `raw_mutrig_frame_top` virtual source | active source on generated decoded lane0 in PROF-INT-002 | Tagged MuTRiG source-code frame generator selected with `TB_INT_SOURCE=virtual_mutrig`. It drives decoded 9-bit `{isk, byte}` frame symbols into the generated decoded-lane adapter and exercises `mutrig_frame_deassembly` onward. Lane0-only until source IDs and multi-lane raw-frame scheduling are implemented. |
| `mutrig_phy_agent` | future active source on the LVDS PHY pin pair | Virtual MuTRiG ASIC for the future real-LVDS harness. Generates **byte-stream-encoded** MuTRiG frames at the LVDS data-clock boundary, including 8b/10b encoding, frame headers, hit payloads, frame trailers, and idle K-codes. Emits hits with the canonical 45-bit `hit_type0` layout (`asic[3:0]`, `channel[4:0]`, `T_CC[14:0]`, `T_Fine[4:0]`, `E_CC[14:0]`, `E_Flag[0]`) per `frame_rcv_ip.vhd:580-585`. |
| `runctl_phy_agent` | active source on the synclink AVST 9-bit boundary | Drives `runctl_mgmt_host`'s synclink input with run-state command bytes. |
| `sc_phy_agent` | active master on the SC-bridge AVMM pin boundary | Drives the SC bridge's PCIe-mapped AVMM master. Mirrors what `sc_tool` does in software but at the simulated bus level. |
| `lvds_decoded_monitor` | passive | Used for PROF-INT-002 pre-rbCAM ingress. Eight monitor instances fan into the scoreboard from both hit-stack subsystems' `data_splitter_0_out0_*` through `data_splitter_0_out3_*`. |
| `rbcam_egress_monitor` | passive | Snoops all eight post-`ring_buffer_cam` `aso_hit_type2` boundaries (the **post-rbCAM tap**) across both hit-stack subsystems. |
| `feb_egress_monitor` | passive | Snoops both FEB-egress framed boundaries at the two `feb_frame_assembly` outputs (the **FEB egress tap**). |
| `histogram_csr_monitor` | passive | Periodically polls `histogram_statistics_0`'s bin counters via the SC bridge for cross-check against scoreboard. |
| `l2_fifo_commit_monitor` | passive | Interface-bind monitor. Samples the actual emulator L2 FIFO commit strobe via a `mutrig_l2_commit_if` interface declared in the focus-build wrapper. Assigns the canonical 64-bit `hit_id` at the commit cycle and publishes a `hit_record` to the scoreboard. See §2.3. |

Every monitor publishes via a `uvm_analysis_port` typed to a **`hit_record`** transaction. The transaction carries the on-wire hit fields plus scoreboard metadata. The `hit_record` schema is:

| Field | Source | Width / type | Role |
|---|---|---|---|
| `hit_id` | `mutrig_phy_agent` Stage-A monitor at FIFO-write commit | 64-bit monotonic counter | Source-of-truth lineage id, assigned at the cycle the hit enters the L2 FIFO inside the virtual MuTRiG. Propagated downstream as `root_hit_id` via FIFO-order matching, but never used as a primary lookup key for reconciliation. Mirrors `tb_int_pkg.sv:3773-3809` `static bit [63:0] next_hit_id`. |
| `key` | derived from on-wire fields | 10-bit struct `{channel[4:0], t_fine[4:0]}` | Primary reconciliation bucket. Excludes T_coarse because T_coarse (`T_CC`, 15 bits) is a free-running counter that wraps every 52.4 µs (≈ 7 short-mode frames), is rewritten by `mutrig_timestamp_processor`, and therefore cannot serve as a per-hit unique discriminator. Mirrors `tb_int_pkg.sv:1117-1138` `hit_key_t`. |
| `lane_id` | observation-point local | int | Per-lane FIFO ledger separator. |
| `seq_in_bucket` | per-(lane, key) FIFO push order | int | Used only for `root_hit_id` propagation downstream, not for matching. |
| `abs_ts` | `$realtime` at observation | 64-bit | Sim-time stamp, recorded for debug-dump and Python-side latency CDF computation (NOT used for SV-side per-hit latency). |
| `feb_id`, `datapath_id` | observation-point local | small ints | Lineage tags for multi-FEB / multi-datapath cases (single-FEB focus build sets these to 0). |
| `payload` | on-wire fields | 45-bit hit_type0 (or 36-bit hit_type2 at downstream stages) | Raw hit. Per wire layout: `asic[44:41]`, `channel[40:36]`, `T_CC[35:21]`, `T_Fine[20:16]`, `E_CC[15:1]`, `E_Flag[0]` per `frame_rcv_ip.vhd:580-585`. |
| `run_origin` | `tb_int_run_window_db.is_stable_origin($time)` | 1-bit | Set if the hit was born inside the stable run window (between `stable_start` and `stable_end`). Used by the strict-window reconciliation pass. |

Per-stage, per-`(lane, key)` FIFO ledgers track observations in arrival order. Each downstream monitor `push_back`s its observation onto the ledger for the same `(lane, key)`. Reconciliation runs at `extract_phase` and at `RUN_TERMINATING`: for every `(lane, key)` bucket, compare upstream-ledger length `up_n` vs downstream-ledger length `dn_n`; matched hits = `min(up_n, dn_n)`, missing = `max(0, up_n - dn_n)`, ghost = `max(0, dn_n - up_n)`. **Ghost is a count residual, not a per-hit hard-fail** — the threshold for fail is set per case in `DV_COV.md`. FIFO order within a bucket is preserved by the point-to-point datapath contract (no in-bucket reordering between Stage A and Stage Pre-RbCAM). Pattern mirrors `tb_int_pkg.sv:1300-1394` (ledger declarations) and `tb_int_pkg.sv:2656-2829` (`reconcile()`). For the failure modes this mechanism was designed to prevent, see `BUG_HISTORY.md` BUG-002-H from `packet_scheduler/tb_int/`, which records how natural-identity exact-match matching falsely reported thousands of missing/ghost hits when T_coarse was projected across stage boundaries incorrectly.

### 2.2 Scoreboard

`tb_int_per_bucket_ledger_scoreboard` consumes analysis-port traffic from all monitors and runs a **per-lane, per-stage, per-`hit_key_t` FIFO-ledger reconciliation engine**:

- Per-lane, per-stage, per-`hit_key_t` FIFO ledgers. Reconciliation is **count parity per `(lane, key)` bucket**, never per-hit lookup.
- The 64-bit `hit_id` is propagated as candidate lineage from Stage A → Pre-RbCAM by FIFO-order matching: the n-th upstream observation in a bucket maps to the n-th downstream observation in the same bucket. At later stages where earlier loss has broken alignment, lineage is reported as `id=?` rather than guessed.
- The ledger is declared as `obs_q_t stage_a_ledger[LANE_COUNT][bit [9:0]]` and equivalents per stage, directly mirroring `tb_int_pkg.sv:1362-1372`.
- **Stage timeout / latency budgets** (derived from jamboree slides 4-10 and confirmed in `packet_scheduler/tb_int/DV_INT_PLAN.md` §3 decision #6; per-stage monitor placement is motivated by precedent bug `R-2026-04-18-01` from `mutrig_timestamp_processor/BUG_HISTORY.md`, where a per-stage pre-rbCAM monitor was the direct method that exposed a wrap-window timestamp reconstruction error causing silent pre-rbCAM drops):
  - **Stage A → Pre-RbCAM:** `[0, 2000]` cycles. Matches the rbCAM ingress accept window (`ring_buffer_cam_v2_core.vhd:788`, default `EXPECTED_LATENCY = 2000`). Hits in Stage A's bucket without matching downstream within 2000 cycles are flagged as dropped.
  - **Pre-RbCAM → Post-RbCAM:** `[2000, 3000]` cycles. Lower bound is `EXPECTED_LATENCY = 2000` (hits held in rbCAM until `gts - expected_latency` catches up; `ring_buffer_cam_v2_core.vhd:1100`). Upper bound adds ≤ 1000 cycles of drain overhead (worst-case SEARCH + LOAD + COUNT + DRAIN for the P4 default: descriptor gap ≤ 16 cycles + SEARCH 6 cycles + LOAD 4 cycles + COUNT ≤ 32 cycles + DRAIN ≤ 512 hits × ~2 cycles, bounded by the TC2 evidence of 382 cycles for 128 hits; `ring-buffer_cam/doc/rtl_note.md`).
  - **Post-RbCAM → FEB egress:** `[4048, 7096]` cycles. Lower bound is post-rbCAM lower (2000) + one frame period (2048 cycles); upper bound is post-rbCAM upper (3000) + two frame periods (4096 cycles) worst-case store-and-forward. **Frame period derivation:** `feb_frame_assembly.N_SHD` is a Qsys instance parameter with `ALLOWED_RANGES {128, 256, 512}` and IP default 256 (`feb_frame_assembly_hw.tcl:100-105`). The Mu3e SciFi convention is **`N_SHD = 128`** (overridden at instantiation in the system Qsys-Tcl), giving 128 sub-headers × 16 datapath cycles per bucket (`d_gts_counter` at `feb_frame_assembly.vhd:1703`: increments every 125 MHz cycle, `ts[11:4] = gts[11:4]`) = **2048 datapath cycles per frame** = `0x800`. Store-and-forward is 1 frame best case (hit arrives at frame start) to 2 frames worst case (hit arrives at end of frame N, waits for frame N+1 to complete and emit). The 8-lane build's Qsys-Tcl recipe must `set_instance_parameter_value feb_frame_assembly_0 N_SHD 128`; the focus build does not instantiate `feb_frame_assembly`, so this stage is observable only when the harness binds against the 8-lane build.
- Per-hit latency is exported to CSV with `hit_id`, per-stage `abs_ts` (when matched), and FIFO-pair indices. Latency CDF and histogram cross-check are computed Python-side from the CSV; the SV-side scoreboard does not produce per-stage CDFs (deferred follow-on work, mirroring `packet_scheduler/tb_int/DV_INT_PLAN.md` §3 decision #6, line 90: "Planned follow-on work. The intended end state is Python-side plotting from CSV keyed by stage-pair reconciliation").

A separate orthogonal `tb_int_run_window_db` (singleton) records `run_start`, `stable_start`, `stable_end`, `run_end` timestamps from the run-control sink. Each Stage-A observation captures `run_origin = is_stable_origin(abs_ts)` at write time. The strict reconciliation pass keys on `root_hit_id` via a `stage_a_run_root_obs[lane]` map and counts losses only for hits born inside the stable window. The all-window pass is best-effort and absorbs deterministic boundary effects of `RUN_PREP` / `TERMINATING` transitions, including drain hits arriving after `RUN_TERMINATING`. Mirrors `tb_int_pkg.sv:160-236` (`tb_int_run_window_db` class declaration) and `tb_int_pkg.sv:4321-4411` (`run_window_db` calls inside the run-control driver). See `BUG_HISTORY.md` BUG-001-H from `packet_scheduler/tb_int/` (cluster-domain long-run cases falsely failed because legally quiet lanes were treated as hard errors — the `run_origin` / strict-window distinction fixed it) and BUG-003-H (sparse stochastic long-run cases falsely failed because silence on a lane with zero emitted hits was not distinguished from loss — the per-lane source-activity guard now correctly keys on `run_origin` within the stable window only).

After every test, the scoreboard exports:

1. Closed-record CSV under `tb_int/sim/<test>/closed_records.csv`. Columns: `hit_id, lane, channel, t_fine, t_coarse, root_hit_id, abs_ts_a, abs_ts_pre_rbcam, abs_ts_post_rbcam, abs_ts_feb_egress, run_origin`. The `lat_<stage>_ps` columns are derived Python-side from `abs_ts_<stage>` differences, not computed SV-side.
2. Drop CSV under `tb_int/sim/<test>/drops.csv`. Columns: `hit_id, lane, key.channel, key.t_fine, t_coarse, last_seen_stage, last_seen_abs_ts, run_state_at_drop, run_origin`. Drops are detected by per-bucket count residuals, not per-hit timeouts; `last_seen_stage` is the latest stage where the hit's bucket position was reconciled.
3. **Histogram-vs-scoreboard cross-check report** at `tb_int/reports/<test>/hist_xcheck_<stage>.md` overlaying the IP histogram with the scoreboard's reconstructed delay distribution.

### 2.3 L2 FIFO commit observer (interface-bind)

The MuTRiG L2 FIFO inside `emulator_mutrig` commits a hit at a deterministic point in its internal pipeline. The commit observer uses **interface-bind only** — no TLM model:

- A SystemVerilog interface declared in the focus-build wrapper at `tb_int/uvm/system_20260504_emulator_type0/`:
  ```systemverilog
  interface mutrig_l2_commit_if (
      input clk,
      input rst,
      input valid,
      input [44:0] payload,
      input [3:0]  lane_id,
      input [4:0]  channel,
      input [14:0] t_coarse,
      input [4:0]  t_fine
  );
  ```
- A `bind` directive in the focus-build TB wrapper probes the actual emulator commit strobe. In the 26.2.x emulator (`be_mutrig_lane_emitter.sv`) the commit condition is `pending_valid & l2_wr_ready` (NOT `commit_strobe`, which is an incorrect name for this signal that does not exist in the 26.2.x source).
- The `tb_int_l2_commit_monitor` samples on `posedge clk` when `valid` pulses: assigns the next monotonic `hit_id` from the static counter (mirroring `tb_int_pkg.sv:3773-3809`), captures `abs_ts = $time`, queries `tb_int_run_window_db::is_stable_origin($time)` for `run_origin`, and writes the analysis-port event.
- No DUT RTL change is needed. No Python-friendly TLM transaction queue is interposed — such a model would decouple the scoreboard from cycle-accurate sim timing and conflicts with the bind-probe pattern established in `packet_scheduler/tb_int/`.
- Cite `tb_int_pkg.sv:3773-3809` (`tb_int_stage_a_monitor` with monotonic `hit_id` counter and `posedge clk` sampling pattern) for the established pattern. The interface signal naming convention follows `tb_int_pkg.sv:3800-3805` (`feb_id`, `datapath_id`, `mutrig_ch`, `payload` fields).

### 2.4 Coverage

Coverage bins reference `hit_key_t` (`{channel[4:0], t_fine[4:0]}`), not the broken `(asic_id, channel, T_coarse, T_fine)` natural-identity tuple:

- **Functional bins** (counter-based; no `covergroup` for Questa FSE portability):
  - Every `(mode, real_fifo_state, emu_fifo_state)` cell remains.
  - virtual MuTRiG mode × hit-rate × cluster-size × channel-mask.
  - run-state transition every-pair coverage.
  - `arb_hit_type0` mode (REAL / EMU / MIX_RR) crossed with watchdog enable.
  - frame-counter ingress/egress reconciliation per source.
- **Per-lane × per-`hit_key_t` reconciliation closure:** every test case must have all `(lane, key)` buckets reconcile to count parity (within the threshold set per case in `DV_COV.md`) at `RUN_TERMINATING`.
- **Run-state transition coverage:** every state-pair (`IDLE→RUN_PREP`, `RUN_PREP→SYNC`, `SYNC→RUNNING`, `RUNNING→TERMINATING`, `TERMINATING→IDLE`, and the shortcut paths) hit at least once via `tb_int_run_window_db` events.
- **Latency CDF coverage** is Python-side, not SV; coverage of per-stage delay percentiles is reported in `tb_int/reports/<test>/latency_<stage>_cdf.png`.
- **Code coverage**: line ≥ 90%, branch ≥ 85%, toggle ≥ 80% across the full focus-build hierarchy under `tb_int/sim/<test>/cov/<test>.ucdb`.

---

## 3. Test Buckets

Four buckets, each with three sections — **RC** (run-control), **SC** (slow-control), **DT** (datapath). Per-bucket case budgets (minimum):

| Bucket | RC | SC | DT | Total | Goal |
|---|---:|---:|---:|---:|---|
| BASIC | 32 | 32 | 128 | **192** | `DV_BASIC.md` — happy-path verification of the full RC/SC/DT axis |
| PROF | 32 | 32 | 128 | **192** | `DV_PROF.md` — sustained throughput, soak, peak rate, peak multiplicity |
| EDGE | 32 | 32 | 128 | **192** | `DV_EDGE.md` — boundary conditions per axis (FIFO full, RBCAM full, exact-cycle transitions, max-channel, max-cluster, sparse / dense, alignment edges) |
| ERROR | 32 | 32 | 128 | **192** | `DV_ERROR.md` — failure injection, bad-CRC frames, dropped frames, run-control mid-flight RESET, watchdog firings, protocol violations |
| **Total** | **128** | **128** | **512** | **768** | |

Per-section ID convention: `<bucket>-<section>-NNN`, e.g. `BASIC-DT-042`, `ERROR-RC-013`. Each case ID is unique within a bucket; case labels never repeat across buckets.

### 3.1 RC (run-control) per-bucket scope (32 cases each)

A single case = one unique run-control combinatorial sequence (a path through the run-state graph). Each case covers:

- **Sequencing**: random combinations of `IDLE → RUN_PREP → SYNC → RUNNING → TERMINATING → IDLE` and shortcuts (`RUN_PREP → RESET`, `SYNC → RESET`, `TERMINATING → RUN_PREP`, etc.). 32 unique paths per bucket.
- **Mid-flight RESET**: `RESET` injected at randomised cycles inside `RUN_PREP` / `SYNC` / `RUNNING` / `TERMINATING`, including hard-reset during functional-reset around the entering and exiting transitions of any state. Verify all IPs return to a consistent post-reset state and the run-control box's `RUN_NUMBER`, frame counters, and other observables react correctly per the `runctl_mgmt_host` contract.
- **Sync stability**: `RUN_SYNC` held for varying durations; verify all IPs stay in sync (no drift in `STATUS.run_state` between consumers).
- **`RUN_NUMBER` tracking**: bump `RUN_NUMBER` across each cycle and confirm `runctl_mgmt_host` records the new number; no off-by-one on `RUN_PREP` vs `IDLE`.

Bucket-specific RC scope:

| Bucket | RC focus |
|---|---|
| BASIC | Clean transitions, deterministic timing |
| PROF | Long `RUNNING` durations (10⁵ cycles), sustained `RUN_NUMBER` increments, watchdog overlap |
| EDGE | Back-to-back state transitions with zero gap, transitions on the same cycle as a CSR write |
| ERROR | Mid-flight RESET while an IP is mid-flush (e.g. `arb_hit_type0` during merge-packet close); back-to-back RESETs without intervening `IDLE`; truncated state words |

### 3.2 SC (slow-control) per-bucket scope (32 cases each)

A single case = one SC-traffic pattern against the focus-build CSR map. 32 cases per bucket cover:

- **Single-word read** of every CSR slave's identity header (`UID`, `META`).
- **Single-word write** of every RW field, with read-back confirmation.
- **Burst read across one slave aperture** (e.g. read all of `arb_hit_type0_0`'s 32 words with a single AVMM burst).
- **Burst read across half a slave aperture** (e.g. `0x00..0x0F` only, then `0x10..0x1F`) with verification that bursts don't cross the slave boundary.
- **Burst write** with mixed read-write addresses inside one burst (must be rejected or sequenced per the SC bridge contract).
- **Cross-slave back-to-back** writes/reads, exercising the `mm_bridge` arbitration.
- **Concurrent SC + RC traffic** (interleaved SC on the SC bridge and RC commands on synclink), proving the two control planes are independent.

Bucket-specific SC scope:

| Bucket | SC focus |
|---|---|
| BASIC | One-shot single-word reads/writes; identity scans; clean bursts inside one aperture |
| PROF | Sustained back-to-back SC traffic at the maximum SC bridge rate; soak |
| EDGE | Burst lengths at boundaries (1, 2, aperture-size, aperture-size minus 1, exactly-half); writes at the very last legal address; reads from undefined addresses |
| ERROR | Burst that overruns aperture (single-slave 4 KB limit); illegal address; write to RO field; read of W1P field; SC during RC `RESET` |

### 3.3 DT (datapath) per-bucket scope (128 cases each)

A single case = one (rate × multiplicity × spatial × temporal × phasing × source-mix) combination of virtual-MuTRiG hits. 128 cases per bucket cover:

- **Rate distribution**: `0` (no hits at all), `1` per frame, `10 kHz`, `100 kHz`, `500 kHz`, `1 MHz`, `2 MHz` per channel; sustained vs short bursts.
- **Multiplicity**: 2-channel cluster, 4, 8, 16, 32 channels; physical cluster (same `T_coarse + T_fine`) vs cluster with fine-time variance (Poisson jitter `0..16` cycles within the cluster).
- **Spatial patterns**: random in channel space; clustered (contiguous channel runs); intermediate (deterministic spacing of 2 / 4 / 8 channels); single-channel hot spot; uniform full-channel; source-split at the convention boundary (real on channel 7, emu on channel 8). The focus build is single-lane with 16 visible channels per source, so SMB-boundary mirroring at channel 128 does not apply here; that dimension is left for the future 8-lane integration TB.
- **Source mix**: real-only (mode REAL), emu-only (mode EMU), MIX_RR with both sources active, single-lane vs cross-lane (one virtual ASIC vs multi-ASIC for cluster generation).
- **Temporal placement around state changes**: no hits after `SYNC` (gate closed), all hits after `SYNC` (gate open), gate hits before `RUNNING` (must be discarded), drain hits after `TERMINATING` (must complete the in-flight frame and propagate `endofrun`).
- **Frame-boundary phasing**: hits aligned to frame start, hits at frame end, hits straddling frame boundary, frames with zero hits.
- **Latency target**: every case asserts the four-stage latency budgets (§2.2) are not exceeded; histogram cross-check at every tap. Mismatch beyond the per-bucket-reconciliation threshold (set per case in `DV_COV.md`) is a fail.

PROF-INT-002 bring-up gates the wider DT scope with the ASIC0/two-channel pre-rbCAM phase ladder above. The first accepted directed checks are `run_prof_int_002_pre_rbcam_latency` and `run_prof_int_002_pre_rbcam_header_sync_phase_sweep_100_900`, which generate `pre_rbcam_records.csv` plus per-case histogram CSV/PNG under `tb_int/sim/<case>/pre_rbcam_hist/`.

Current pre-rbCAM evidence, 2026-05-06: after fixing the emulator signal-offer replay bug, the ASIC0 focused four-pulse check produced 8 rows for channels 0 and 1. The ASIC0 128-pulse phase sweep passed phases 100 through 900 with 256 rows per phase. Phases 100..800 measured median latencies of `821.5, 721.5, 621.5, 521.5, 421.5, 321.5, 221.5, 121.5` cycles, i.e. `910 - phase + 11.5` cycles. Phase 900 showed the expected next-frame edge split with populated bins at 21, 25, and 929 cycles. After enabling non-ASIC0 active-lane controls, the ASIC1 four-pulse phase-100 smoke produced 8 rows with `A->PRE matched/missing/ghost=8/0/0` and latency `min=822`, `p50=822.5`, `max=823` cycles. The ASIC1-7 individual phase-100 sweep then passed all seven runs with 256 rows each, `A->PRE matched/missing/ghost=256/0/0` in every run, and aggregate pre-rbCAM latency min/p05/p50/p95/max = `821/821/822/823/823` cycles.

Virtual MuTRiG bring-up status, 2026-05-06: `PROF_INT_002_SOURCE=virtual_mutrig` compiles the tagged decoded-byte MuTRiG frame source and configures the active arb lane to REAL mode. The first accepted scope is ASIC0/lane0 with `TB_INT_ACTIVE_LANE_MASK=1`; multi-lane virtual MuTRiG mode remains blocked until the source scheduler assigns independent lane identities and monitors can prove aggregate source counts.

The pre-rbCAM source-validation targets run with `TB_INT_LATENCY_SCOPE=pre_rbcam`. That scope keeps the Stage-A -> pre-rbCAM SVA window and FIFO-key scoreboard active, but disables post-rbCAM/FEB-egress SVA guardrails so source-stage contact sheets are not rejected for downstream residuals. Full-pipeline closure must use `TB_INT_LATENCY_SCOPE=full`.

Initial virtual MuTRiG smoke evidence, 2026-05-06: after isolating the tagged MuTRiG VHDL into a dedicated `mutrig_raw` Questa library, the ASIC0/lane0 phase-100 smoke with 16 frames and one pulse/header logged `source=virtual_mutrig`, active arb lane REAL mode, `A=16`, `PRE=16`, and `A->PRE matched/missing/ghost=16/0/0`. The analyzer read 16 pre-rbCAM records and reported a delta-function latency at 837 cycles. The same run still showed downstream residuals (`PRE->POST=11/5/0`, `POST->FEB=11/0/26`), so it is pre-rbCAM source-validation evidence only, not post-rbCAM or FEB-egress closure.

Virtual MuTRiG header-sync burst evidence, 2026-05-06: `plot_prof_int_002_pre_rbcam_virtual_mutrig_header_sync_burst_sweep_phase100` passed for ASIC0/lane0 with 128 RUNNING frames, phase 100, one enabled channel, and `1, 2, 5, 7` pulses/header spaced 10 cycles apart. The pre-rbCAM row-count gate observed exactly `128, 256, 640, 896` rows, with Stage-A -> pre-rbCAM ledger residuals `128/0/0`, `256/0/0`, `640/0/0`, and `896/0/0`. The analyzer reported min/p05/p50/p95/max of `837/837/837/837/837`, `830/830/833.5/837/837`, `811/811/824/837/837`, and `798/798/817/837/837` cycles respectively, matching the expected fixed frame-wait plus 10-cycle burst-spacing contraction. The emitted plots are `tb_int/reports/prof_int_002_pre_rbcam_virtual_mutrig_header_sync_burst_sweep_phase100_dislin/contact_sheet_dislin.png` and `tb_int/reports/prof_int_002_pre_rbcam_virtual_mutrig_header_sync_burst_sweep_phase100_channel_rate_dislin/channel_rate_dislin.png`. The Questa transcript still reports one generated `altsyncram` simulation-model error at time 0 in each run, but UVM reports `UVM_ERROR=0`, `UVM_FATAL=0`, and `*** TEST PASSED ***`; this residual simulator-model noise is not counted as a pre-rbCAM source-contract failure.

Current plot evidence, 2026-05-06: `plot_prof_int_002_pre_rbcam_header_sync_asic1_7_phase100` renders the ASIC1-7 phase-100 pre-rbCAM DISLIN-style latency contact sheets with the requested x-axis range `[-1000, 3096]` cycles and matching endpoint tick labels. It also renders the pre-rbCAM channel-rate contact sheet over the full 8-ASIC global channel range `0..255`, using `global_channel = lane * 32 + channel` and `pre_rbcam_records.csv` as the source. The generated report paths are `tb_int/reports/prof_int_002_pre_rbcam_header_sync_asic1_7_phase100_dislin/contact_sheet_dislin_p1.png`, `tb_int/reports/prof_int_002_pre_rbcam_header_sync_asic1_7_phase100_dislin/contact_sheet_dislin_p2.png`, `tb_int/reports/prof_int_002_pre_rbcam_header_sync_asic1_7_phase100_channel_rate_dislin/channel_rate_dislin_p1.png`, and `tb_int/reports/prof_int_002_pre_rbcam_header_sync_asic1_7_phase100_channel_rate_dislin/channel_rate_dislin_p2.png`.

Blocked plot evidence, 2026-05-06: the full8/full32 header-sync burst sweep at phase 100 is not accepted as a golden reference. Burst1 requested 32768 Stage-A offers and produced only 6656 pre-rbCAM rows; burst2 requested 65536 Stage-A offers and produced only 5632 pre-rbCAM rows. The make target now checks the expected row count before analyzer or DISLIN plotting so no all-active burst sheet is emitted from aliased or incomplete data.

Bucket-specific DT scope:

| Bucket | DT focus |
|---|---|
| BASIC | Smoke (deterministic 16-hit patterns) plus rate sweep (10k / 100k / 500k / 1M kHz at cluster-size 1 / 4 / 8 / 16 / 32) plus spatial sweep |
| PROF | Sustained Poisson at 1 MHz × 32 channels for 10⁵ cycles; cross-source MIX_RR at the documented `1 hit / 3.5 cycles` ceiling; long-soak with mid-run `RUN_NUMBER` bumps |
| EDGE | Cluster-size at the 32-channel maximum with all hits in one frame; back-to-back single-channel saturation; frame-boundary hit straddling; FIFO-full induced drops with the watchdog firing exactly at the timeout boundary |
| ERROR | Bad CRC injected on virtual-MuTRiG frames; dropped frames mid-cluster; `RUN_PREP` mid-frame; emulator and real channels collide on the same channel ID (violates the `[0..7]` / `[8..15]` convention); SOP without EOP; double-EOP without intervening SOP |

`dv-workflow` skill format applies; `dv_bucket_format_check.py` lints every bucket file. Format conforms to per-IP DV docs under `mu3e-ip-cores/misc/arb_hit_type0/tb/DV_*.md`.

---

## 4. Bring-up Order

1. **BASIC bucket first** — RC plumbing, SC plumbing, DT smoke + rate sweep + multiplicity sweep. Every PASS from this bucket is a prerequisite for the higher buckets.
2. **EDGE bucket** — boundary conditions per axis. Catches off-by-one bugs that BASIC misses.
3. **ERROR bucket** — failure injection. Verifies the recovery path for every recorded upstream-bug surface (error counters, syndromes, sticky flags) and the run-control RESET cleanup contract.
4. **PROF bucket** — sustained / soak / peak. Runs last because it depends on BASIC closure and is long-running.
5. **All-buckets continuous-frame** — one final sign-off run that drives every case in case-id order inside one timeframe without DUT reset between cases (per `dv-workflow` skill §9 `all_buckets_frame`).

For per-stage latency reporting, every PROF case automatically refreshes the four CDFs at L2-commit / pre-rbCAM / post-rbCAM / FEB-egress.

---

## 5. Outputs

Per-test artifacts under `tb_int/sim/<test>/`:

- `<test>.log` — raw simulator transcript.
- `closed_records.csv`, `drops.csv` — scoreboard results (columns defined in §2.2).
- `cov/<test>.ucdb` — code + functional coverage.

Per-test reports under `tb_int/reports/<test>/`:

- `latency_l2_commit_cdf.png`, `latency_pre_rbcam_cdf.png`, `latency_post_rbcam_cdf.png`, `latency_feb_egress_cdf.png` — per-stage latency CDFs (Python-side, computed from CSV).
- `hist_xcheck_pre_rbcam.md`, `hist_xcheck_post_rbcam.md`, `hist_xcheck_feb_egress.md` — cross-check vs `histogram_statistics_0` IP at each tap.
- `summary.md` — PASS/FAIL plus per-stage drop count, per-bucket ghost residual count, and the four latency percentiles (p50/p90/p99/p99.9).
- `latency_summary.csv` — histogram-level roll-up for each of pre-rbCAM/post-rbCAM/FEB-egress.

### PROF-INT-002 5s latency workflow and target list

- Capture window definition (applied in all 5s PROF-INT-002 targets):
  - `TB_INT_RUN_CYCLES=625000000` (5 s @125 MHz)
  - `TB_INT_DRAIN_CYCLES=16384`
  - `TB_INT_STABLE_WINDOW_CYCLES=125000000` (1 s stable-origin interval)
  - `TB_INT_STABLE_ONLY_EXPORT=1`
  - `TB_INT_RUNCTL_CPP_GAP_CYCLES=125000` (1 ms software-scale command gap, must be observed in the transcript before the next state)
  - `TB_INT_RUNCTL_SETTLE_TIMEOUT_CYCLES=1250000` (legacy diagnostic budget only; run-control commands do not wait on slave ready)
- 1-lane virtual MuTRiG, 100 kHz/channel, 5s with 1s stable window:
  - Target: `make run_prof_int_002_full_pipeline_100khz_per_channel_1lane_5s`
  - Sim dir: `tb_int/sim/prof_int_002_full_pipeline_100khz_per_channel_1lane_5s/`
  - Plot dir: `tb_int/reports/prof_int_002_full_pipeline_100khz_per_channel_1lane_5s/`
  - Contact sheet: `contact_sheet_dislin.png`
- 8-lane virtual MuTRiG, 100 kHz/channel, 5s with 1s stable window:
  - Target: `make run_prof_int_002_full_pipeline_100khz_per_channel_8lane_5s`
  - Sim dir: `tb_int/sim/prof_int_002_full_pipeline_100khz_per_channel_8lane_5s/`
  - Plot dir: `tb_int/reports/prof_int_002_full_pipeline_100khz_per_channel_8lane_5s/`
  - Contact sheet: `contact_sheet_dislin.png`
  - Monitor scope: eight Stage-A taps, eight pre-rbCAM taps, eight post-rbCAM taps, and two FEB-egress taps feed the same scoreboard.
- Emulator/full RTL path, 100 kHz/channel, 8-lane equivalent, 5s with 1s stable window:
  - Target: `make run_prof_int_002_full_pipeline_100khz_per_channel_emulator_full8lane_5s`
  - Sim dir: `tb_int/sim/prof_int_002_full_pipeline_100khz_per_channel_emulator_full8lane_5s/`
  - Plot dir: `tb_int/reports/prof_int_002_full_pipeline_100khz_per_channel_emulator_full8lane_5s/`
  - Contact sheet: `contact_sheet_dislin.png`
  - Monitor scope: same multi-lane, multi-rbCAM fanout as the 8-lane virtual target.
- Combined 5s convenience target:
  - `make run_prof_int_002_full_pipeline_100khz_per_channel_5s`
  - Executes all three runs above and corresponding plots via `plot_prof_int_002_full_pipeline_100khz_per_channel_5s` dependency chain.

Current validation note, 2026-05-06: the previous bounded short runtime
`make run_prof_int_002_full_pipeline_100khz_per_channel_test PROF_INT_002_RUN_CYCLES=20000 PROF_INT_002_DRAIN_CYCLES=1024 SEED=2`
was not closure evidence for the 5s targets: the scoreboard reported `A=352 PRE=256 POST=64 FEB=52`, `stable_closed=52/352` (14 percent, below the 95 percent gate), run-control was still being interpreted through ready diagnostics, and the generated post-rbCAM/FEB-egress latencies sat outside the rbCAM reference aperture. The root causes are tracked as monitor/run-control integration bugs: PROF-INT-002 was binding only one four-rbCAM hit-stack and one FEB egress, and the full8lane Qsys Tcl had displaced `mts_preprocessor_1.run_ctrl` by reusing the reference out12 slot for `mutrig_frame_deassembly_0.ctrl`. A second short diagnostic after those fixes showed `MTS out=0` with MTS RUNNING and rbCAM GO asserted; that is tracked as a histogram ingress bridge bug where the diagnostic histogram sink could backpressure the primary pre-rbCAM stream. A third short diagnostic after the histogram bridge fix showed `MTS out=30` / `hisb_pre=30` / `PRE=120`, but all rbCAM direct state codes were `9` and `POST=0`; that is tracked as a Qsys generation bug where readyless hit-stack run-control had been materialized through `run_control_cmd_fifo_0..5`, incorrectly allowing local ready to gate forward state commands. The repaired harness must bind eight pre-rbCAM taps, eight post-rbCAM taps, and two FEB-egress taps, while the repaired Qsys Tcl keeps the main run-control splitter at its 16-output limit, cascades out12 through a two-output readyless splitter for `mts_preprocessor_1.run_ctrl` plus `mutrig_frame_deassembly_0.ctrl`, and keeps each hit-stack run-control fanout as a direct readyless broadcast to rbCAM/FEB consumers. During RUNNING, PROF-INT-002 must log `PROF_INT_002_MON_BIND` with Stage-A/pre/post/FEB activity bits, MTS0/1 in/out ready/valid/error bits, hit-stack run-control valid vectors, and MTS/rbCAM CSR state; readiness is not a command-acceptance gate in this build.

### Latency reporter/metric conventions for these runs

- Metric definitions:
  - pre-rbCAM = `abs_ts_pre_rbcam - abs_ts_a`
  - post-rbCAM = `abs_ts_post_rbcam - abs_ts_a`
  - FEB-egress = `abs_ts_feb_egress - abs_ts_a`
- Panel labels:
  - `pre-rbCAM (ring_buffer_cam asi_hit_type1)`
  - `post-rbCAM (ring_buffer_cam hit_type2)`
  - `FEB-egress (packet scheduler egress)`
- Axis labels:
  - x-axis: `signed hit latency bin center [cycles]`
  - y-axis: `hits / bin [% of captured interval]`
- Reporter output requirement:
  - Pre-rbCAM panel must represent the aggregate rbCAM-ingress boundary at both hit-stack subsystems' `data_splitter_0_out0_*` through `out3_*` fanouts.
  - Post-rbCAM and FEB-egress panels must use the corrected expected latency apertures above. Under the 100 kHz/channel typical workload the FIFOs should be empty or near-empty, so post-rbCAM should be near the fixed rbCAM latency and FEB-egress should add only the deterministic frame-store interval; a broad distribution is a datapath or monitor-binding failure, not an accepted workload artifact.
  - Each panel must include total/hits, nonzero bins, peak bin/fraction, black-peak note, green DV-budget note, in-window/out-window counts, and compact two-line title text.

### CSV column reference

**`closed_records.csv`** columns: `hit_id, lane, channel, t_fine, t_coarse, root_hit_id, abs_ts_a, abs_ts_pre_rbcam, abs_ts_post_rbcam, abs_ts_feb_egress, run_origin`.
The `lat_<stage>_ps` columns are derived Python-side from `abs_ts_<stage>` differences; they are not written by the SV scoreboard.

**`drops.csv`** columns: `hit_id, lane, key.channel, key.t_fine, t_coarse, last_seen_stage, last_seen_abs_ts, run_state_at_drop, run_origin`.
Drops are detected by per-bucket count residuals (`up_n > dn_n`), not by per-hit timeouts. `last_seen_stage` is the latest stage where the hit's bucket position was reconciled before the residual was first detected.

---

## 6. Reuse contract

The harness is structured so **future integration testbenches** (e.g. an 8-lane integration tb for the supercore in `system_20260427_testplanphase5/tb_int/` once that lands) can reuse:

- `tb_int/uvm/common/mutrig_phy_agent/` — virtual MuTRiG with parameterised lane count.
- `tb_int/uvm/common/runctl_phy_agent/`, `sc_phy_agent/`.
- `tb_int/uvm/common/l2_fifo_commit_monitor/` — interface-bind monitor (not TLM); assigns `hit_id` at commit, captures `run_origin` from `tb_int_run_window_db`.
- `tb_int/uvm/common/per_bucket_ledger_scoreboard/` — count-parity reconciler keyed on `hit_key_t` (`{channel[4:0], t_fine[4:0]}`); primary pattern from `tb_int_pkg.sv:1300-1394` (ledger declarations) and `tb_int_pkg.sv:2656-2829` (`reconcile()`).
- `tb_int/uvm/common/run_window_db/` — singleton tracking `run_start`, `stable_start`, `stable_end`, `run_end` for the strict reconciliation pass; direct adaptation of `tb_int_pkg.sv:160-236`.
- `tb_int/uvm/common/latency_reporter/` — Python-side; produces the three-stage CDFs and histogram cross-check from the exported CSV.

The DUT-specific layer (focus-build wrapper instantiating the focus build's `.qsys` system, the bind probes for the L2 FIFO commit monitor's `mutrig_l2_commit_if`, and the per-test plumbing) lives at `tb_int/uvm/<system>/`.

---

## 7. Plan drift

Any deviation from this plan is recorded in `BUG_HISTORY.md` with date and rationale.
