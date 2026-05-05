# Integration Testbench: `system_20260504_emulator_type0/tb_int/`

**DUT:** `top_nostp_emulator_type0` (full FEB SciFi single-lane focus build).
**Companion docs:** [`../../doc/SYSTEM_PLAN.md`](../../doc/SYSTEM_PLAN.md), [`DV_HARNESS.md`](DV_HARNESS.md), [`BUG_HISTORY.md`](BUG_HISTORY.md).
**Author:** Mu3e IP team
**Date:** 2026-05-04
**Status:** Draft. Awaits approval before harness construction.

---

## 1. Purpose & Scope

`tb_int/` is the **integration UVM testbench** that verifies the full datapath of `system_20260504_emulator_type0` end-to-end with all IPs in the loop. It is the layer between standalone IP DV (e.g. `mu3e-ip-cores/misc/arb_hit_type0/tb/`) and the on-board bring-up.

The testbench drives traffic at the **upstream LVDS PHY boundary** with a virtual MuTRiG model, runs through the integrated datapath inside the focus build (`emulator_mutrig_qsys_lane`, `lvds_rx_controller_pro`, `mutrig_frame_deassembly`, `arb_hit_type0`, `backpressure_fifo`, `mutrig_timestamp_processor`, `ring_buffer_cam`, `histogram_ingress_bridge`, `histogram_statistics`), and reconciles every hit end-to-end through a per-bucket FIFO-ledger scoreboard.

### In scope

1. **Run-control verification (RC):** `runctl_mgmt_host` ↔ `run_control_splitter` ↔ every IP. Verify `IDLE → RUN_PREP → SYNC → RUNNING → TERMINATING → IDLE` is broadcast correctly and every IP reacts per its own contract.
2. **Slow-control verification (SC):** `sc_hub_v2` ↔ `mm_bridge` ↔ every CSR slave on the focus build. Verify CSR addressing, address-aperture bounds, and read/write atomicity.
3. **Datapath verification (DT):** end-to-end hit tracking from virtual-MuTRiG-emitted hits to histogram-statistics bin counts. Per-bucket FIFO-ledger scoreboard catches dropped, reordered, mis-attributed, and corrupted hits.
4. **Latency measurement at three observation points:** pre-rbCAM (after `arb_hit_type0` → before `ring_buffer_cam`), post-rbCAM (after `ring_buffer_cam`), FEB egress (after `packet_scheduler` framing). Latency CDFs, percentiles, and per-source breakdowns computed Python-side from exported CSV.
5. **Histogram cross-check:** compare the scoreboard's reconstructed delay distribution against `histogram_statistics_0`'s bin counts at the same tap point. Mismatch beyond the per-bucket-reconciliation threshold (set per case in `DV_COV.md`) is a fail.
6. **Reusable UVM infra:** every agent, scoreboard, and coverage collector is built so the same harness can be reused for future Mu3e integration testbenches by swapping the DUT-binding interface.

The virtual MuTRiG model in `mutrig_phy_agent` emits directly into per-lane L2 FIFOs (matching the 26.2.x `emulator_mutrig` architecture, which removed L1 staging per `emulator_mutrig/doc/RTL_PLAN.md` §2.1). The real-ASIC 32-channel → 4 L1 FIFO → 1 L2 FIFO RR-arbitration reordering is therefore NOT exercised by this harness; it is deferred to a future harness that uses the real LVDS / `mutrig_frame_deassembly` path with the bring-up SOF on the FEB.

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
| `mutrig_phy_agent` | active source on the LVDS PHY pin pair | Virtual MuTRiG ASIC. Generates **byte-stream-encoded** MuTRiG frames at the LVDS data-clock boundary, including 8b/10b encoding, frame headers, hit payloads, frame trailers, and idle K-codes. Emits hits with the canonical 45-bit `hit_type0` layout (`asic[3:0]`, `channel[4:0]`, `T_CC[14:0]`, `T_Fine[4:0]`, `E_CC[14:0]`, `E_Flag[0]`) per `frame_rcv_ip.vhd:580-585`. |
| `runctl_phy_agent` | active source on the synclink AVST 9-bit boundary | Drives `runctl_mgmt_host`'s synclink input with run-state command bytes. |
| `sc_phy_agent` | active master on the SC-bridge AVMM pin boundary | Drives the SC bridge's PCIe-mapped AVMM master. Mirrors what `sc_tool` does in software but at the simulated bus level. |
| `lvds_decoded_monitor` | passive | Snoops the post-deassembly `aso_hit_type0` boundary inside the lane's `mutrig_datapath_subsystem` (the **pre-rbCAM tap**). |
| `rbcam_egress_monitor` | passive | Snoops the post-`ring_buffer_cam` `aso_hit_type2` boundary (the **post-rbCAM tap**). |
| `feb_egress_monitor` | passive | Snoops the FEB-egress framed boundary at `feb_frame_assembly` output (the **FEB egress tap**). |
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
