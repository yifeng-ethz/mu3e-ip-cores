# TEST_PLAN_PHASE5.md — real-MuTRiG bring-up, frame-format signoff, injector closure

**Revision**: 2026-04-27 / draft-0
**Target**: `mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/syn/feb_system_v3_pipe` on FEB SciFi prototype, with the eight live MuTRiG ASICs replacing the 8-lane `emulator_mutrig`. Build is under `firmware_builds/`.
**Host**: teferi (`yifeng@teferi`, `/dev/mudaq0` via SWB on link 2 — see `TEST_PLAN.md` §0)
**Companions**: [`TEST_PLAN.md`](TEST_PLAN.md) Phases 1..4 · [`phase4/TEST_PLAN_BASIC.md`](phase4/TEST_PLAN_BASIC.md) · [`phase4/TEST_PLAN_PUBLISH.md`](phase4/TEST_PLAN_PUBLISH.md)
**Authoring scope**: this document is plan-only. It does not author or commit any RTL, test scripts, MIDAS hooks, or runner code. Phase-5 closure runs the existing bring-up tooling against a new MuTRiG-backed configuration and adds new SignalTap `.stp` images and report Markdown.

---

## 0. Goal of Phase 5

Phase 5 is the first sign-off on the **real MuTRiG ASIC** end-to-end. Phase 4 closed against the 8-lane `emulator_mutrig` LFSR; Phase 5 reuses the proven datapath and reset/SC plane and exercises the same observation surfaces against eight live MuTRiG ASICs.

The plan is structured as four sequential closures:

1. **Real-MuTRiG bring-up** — load each ASIC's known-good configuration via `mutrig_cfg_ctrl_0` (the MuTRiG Controller IP), sweep the per-channel TTH via the on-IP TTH-Scan-Automation (TSA) routine, and confirm every ASIC reports a stable, decoded MuTRiG frame.
2. **Frame-format signoff with SignalTap (4k × 4 segments)** — capture the FEB egress side and the SWB ingress side over multiple complete packets and prove the deassembled frame is structurally identical at both ends.
3. **Emulator vs real-MuTRiG packet equivalence** — re-run the same emulator stimulus the Phase 4 closure already passed against, capture the egress, and confirm the bit-for-bit framing is identical between emulator and real ASIC at the FEB egress and the SWB ingress (modulo the agreed-upon hit-payload differences listed in §4.4).
4. **Injector + histogram closure** — sweep `mutrig_injector_0` across **every implemented mode** at multiple rates against eight live MuTRiG ASICs and compare the delay PDF and the channel/ASIC rate distribution against `histogram_statistics_0`. The live stimulus catalog has five 64-case groups; closure coverage is reported against the four required BASIC/EDGE/PROF/ERROR buckets in §1.6.

Phase 5 does **not** redo Phase 4 closure on the emulator; Phase 4 is the prerequisite, not part of the Phase 5 evidence.

---

## 1. Prerequisites and references

### 1.1 Hard prerequisites — must be PASS before any Phase-5 case is run

| Prerequisite | Source | Exit criterion |
|---|---|---|
| Phase 1 metadata + bridge audit | [`TEST_PLAN.md`](TEST_PLAN.md) §1 | every UID/version/GIT cross-check passes; `mm_bridge` and `upload_mm_bridge` are reachable end-to-end |
| Phase 2 BIST | [`TEST_PLAN.md`](TEST_PLAN.md) §2 | zero bit-flips across all RW registers and the scratchpad; sc_hub admission/ordering hazards eliminated |
| Phase 3 run-control | [`TEST_PLAN.md`](TEST_PLAN.md) §3 | every reset-link opcode advances the host counter exactly once on both SC and JTAG paths |
| Phase 4 emulator + histogram | [`phase4/TEST_PLAN_BASIC.md`](phase4/TEST_PLAN_BASIC.md) closure contract | TPBH001..TPBH030 pre-gate PASS, TPB000..TPB100 PASS (no residual `OVERFLOW_COUNT`/`DROPPED_HITS`/`UNDERFLOW_COUNT`) |
| FEB SciFi v3 SOF flashed | this repo `firmware_builds/<feb_scifi_v3_project>/output_files/top.sof` | `script/check_ip_metadata.py` clean |
| SWB SOF flashed from `online_sc` | per `TEST_PLAN.md` §0.2 | `/dev/mudaq0` BAR sane; `sc_tool read 0x00000` returns OK |
| MuTRiG configuration bitstreams reviewed | `online_dpv2/online/switching_pc/MIDAS_FEcontrol/Mutrig_FEB.cpp` | a known-good 2662-bit cfg word stream is available for each MuTRiG3 ASIC variant on the SciFi DAB |

If any prerequisite is open, Phase 5 does not start. Phase 4 closure attestation `TPB100` is the named gate.

### 1.2 Authoritative IP and address references (from this repo)

| IP / instance | Address (sc_tool word) | Source of truth |
|---|---|---|
| `mutrig_cfg_ctrl_0.avmm_csr` (MuTRiG Controller CSR) | `0x0FC04` | [`../../mutrig_controller/mutrig_ctrl.vhd`](../../mutrig_controller/mutrig_ctrl.vhd), [`../../mutrig_controller/mutrig_cfg_ctrl.svd`](../../mutrig_controller/mutrig_cfg_ctrl.svd) |
| `mutrig_cfg_ctrl_0` scratchpad host port (cfg bitstream stage) | aliased into `scratch_pad_ram` at `0x00000` | `TEST_PLAN.md` §1.2; controller's own AVMM host port reads it |
| `mutrig_injector_0.csr` | `0x0AC80` | [`../../charge_injection/mutrig_injector_multiheader.vhd`](../../charge_injection/mutrig_injector_multiheader.vhd), [`../../charge_injection/mutrig_injector.svd`](../../charge_injection/mutrig_injector.svd) |
| `charge_injection_pulser_0` (analog pulser) | `0x04C00` (write-only) | `TEST_PLAN.md` §1.5 |
| `histogram_statistics_0.csr` | `0x0A900` | [`../../histogram_statistics/histogram_statistics.svd`](../../histogram_statistics/histogram_statistics.svd) |
| `histogram_statistics_0.hist_bin` | `0x0A800` | same |
| `histogram_ingress_bridge_0.csr` | `0x0AB00` | [`../../histogram_statistics/histogram_ingress_bridge.svd`](../../histogram_statistics/histogram_ingress_bridge.svd) |
| `mutrig_frame_deassembly_0..7.csr` | `0x08240`, `0x08640`, `0x08A40`, `0x08E40`, `0x09240`, `0x09640`, `0x09A40`, `0x09E40` | per AVMM map in `feb_system_v3_pipe.qsys` line 285 |
| `mts_preprocessor_{0,1}.csr` | `0x09000`, `0x0A000` | same map |
| `feb_frame_assembly_{0,1}.csr` | `0x0B400`, `0x0B410` | same map |
| `lvds_rx_controller_pro_0.csr` | `0x08000` | same map |
| `runctl_mgmt_host_0.csr` | `0x0C000`..`0x0C013` | `TEST_PLAN.md` §1.10, §3.1 |

### 1.3 Frame-format constants used in §3 trigger expressions

| Symbol | Value | Reference |
|---|---|---|
| `FRAME_INTERVAL_SHORT` (cycles, 125 MHz emulator domain) | `910` | [`../../emulator_mutrig/rtl/emulator_mutrig_pkg.sv`](../../emulator_mutrig/rtl/emulator_mutrig_pkg.sv) |
| `FRAME_INTERVAL_LONG` | `1550` | same |
| K28.0 (frame header / SOP) | data byte `8'h1C`, K-flag → 9-bit `9'h11C` | [`../../emulator_mutrig/rtl/emulator_mutrig_pkg.sv`](../../emulator_mutrig/rtl/emulator_mutrig_pkg.sv) |
| K28.4 (frame trailer / EOP) | data byte `8'h9C`, K-flag → 9-bit `9'h19C` | same |
| K28.5 (idle / inter-frame comma) | data byte `8'hBC`, K-flag → 9-bit `9'h1BC` | same |
| K23.7 (post-hit-stack sub-header) | per `histogram_ingress_bridge_0.STATUS.post_hit_region` | `histogram_ingress_bridge.svd` |

### 1.4 Tools used (in `../systems/system_20260427_testplanphase5/script/`)

| Tool | Phase-5 use |
|---|---|
| `sc_tool` | program the MuTRiG controller (load opcodes, poll status), program injector + histogram + ingress-bridge CSRs, snapshot histogram and counters |
| `rc_tool` | issue CMD_RUN_PREPARE/CMD_SYNC/CMD_START_RUN/CMD_END_RUN to gate the histogram interval and any traffic |
| `run_phase4_emulator.py` | reused as the closure runner skeleton — same SC/RC sequence, but with the per-bucket Phase-5 stimulus described in §5; this plan does **not** rewrite the script |
| `probe_phase4_stage_counters.py` | stage-counter snapshot before/after each Phase-5 case |
| `run_signaltap_capture.py` | invoke segmented `.stp` capture from a pre-authored Phase-5 image |
| `check_ip_metadata.py` / `check_sc_bridges.py` | pre-flight gate after the FEB SOF is reflashed for Phase 5 |

The cfg bitstream upload helper used by MIDAS production is `Mutrig_FEB.cpp` in `online_dpv2`. For Phase 5 bring-up under board_test the same bitstream is staged via `sc_tool` block writes into `scratch_pad_ram` and committed via `mutrig_cfg_ctrl_0.OPCODE_STATUS`. No new helper is authored as part of this plan; the existing tools are sufficient.

### 1.5 Document conventions reused from Phase 4

This plan adopts the BASIC catalog conventions from [`phase4/TEST_PLAN_BASIC.md`](phase4/TEST_PLAN_BASIC.md):

- **method** — `D` = directed, `R` = random multi-seed
- **implementation** — `live BOARD` = on-board run via `../systems/system_20260427_testplanphase5/script/`; `live STP` = SignalTap segmented capture; `live CMP` = DISLIN cross-layer / cross-source compare; `planned` = stimulus exists, runner not yet wired
- **stage** — `B` = on-board, `S` = SignalTap segmented capture, `C` = cross-source DISLIN compare against the Phase 4 emulator reference

Phase 5 is on-board-first by construction; the TLM/RTL-SIM rows of Phase 4 are the **reference** that real-MuTRiG cases compare against.

### 1.6 Functional coverage accounting

Phase 5 uses four functional-coverage buckets for board and SignalTap closure:

| Coverage bucket | Required points | Scope |
|---|---:|---|
| BASIC | 64 | Nominal bring-up, consecutive-frame framing, run-control, and one-rate histogram checks. |
| EDGE | 64 | Boundary settings: short/long frames, first/last ASIC, first/last channel, TTH extremes, delay endpoints, and wire-cap edge rates. |
| PROF | 64 | Rate, latency, queue, and sustained-run profiling checkpoints. |
| ERROR | 64 | Negative triggers and fault checkpoints: torn frame, code/disp error, bad timestamp, overflow/drop/underflow, and misconfiguration detection. |

The sign-off target is at least **50% functional coverage** over the 256 required points, with no open failure in any implemented checkpoint. Until the full catalog is implemented, every report must publish both views:

- implemented coverage by bucket: `implemented_pass / 64`
- aggregate coverage: `sum(implemented_pass) / 256`

The existing §5 A..E case catalog remains the live-MuTRiG stimulus catalog. Each case maps to one or more BASIC/EDGE/PROF/ERROR coverage points in the report. SignalTap trigger-condition cases also count as coverage points, but each segmented acquisition is one trigger condition with four consecutive trigger events, per §3.

Current implemented trigger/checkpoint coverage in this revision:

| Bucket | Implemented | Required | Current ratio |
|---|---:|---:|---:|
| BASIC | 6 | 64 | 9.4% |
| EDGE | 1 | 64 | 1.6% |
| PROF | 0 | 64 | 0.0% |
| ERROR | 2 | 64 | 3.1% |
| **Aggregate** | **9** | **256** | **3.5%** |

These counts cover only concrete trigger/checkpoint cases that are enumerated in this document today: the five FEB trigger cases in §3.1 and the four SWB trigger cases in §3.2. Planned §5 stimulus rows do not count toward implemented coverage until the runner, report row, and pass/fail evidence exist.

---

## 2. Real-MuTRiG bring-up via `mutrig_cfg_ctrl_0`

### 2.1 What this stage proves

After SOF reflash and Phases 1..4 PASS, the FEB SciFi v3 still has the eight `emulator_mutrig` cores driving the datapath. Phase 5.A is the act of switching the integration build from emulator-fed to **real-MuTRiG-fed** — by ensuring:

1. The `mutrig_cfg_ctrl_0` IP can stage a 2662-bit cfg bitstream into the IP's internal CFG-mem RAM via DMA from `scratch_pad_ram`, then SPI-write that bitstream into each MuTRiG3.
2. Every MuTRiG returns a frame_header + payload + trailer at the FEB-side `mutrig_frame_deassembly_N.csr` decoder for at least one full integration interval.
3. The TSA (TTH Scan Automation) co-routine sweeps the per-channel threshold and reports a sane, monotonic dark-rate vs threshold curve — which then anchors a known-good operating threshold per ASIC for §3..§5.

### 2.2 mutrig_cfg_ctrl_0 CSR contract

Per [`../../mutrig_controller/mutrig_ctrl.vhd`](../../mutrig_controller/mutrig_ctrl.vhd) and [`../../mutrig_controller/mutrig_cfg_ctrl.svd`](../../mutrig_controller/mutrig_cfg_ctrl.svd), the controller exposes a 4-word CSR aperture:

| Word | Name | Direction | Field layout |
|---|---|---|---|
| `0x00` | `OPCODE_STATUS` | RW | write: `[31:20]=command`, `[19:16]=asic_id`, `[15:0]=cfglen`. Read: `[31:16]=opcode_echo`, `[15:0]=status_word` |
| `0x01` | `OFFSET` | RW | scratchpad word offset where the cfg bitstream begins |
| `0x02` | `MONITOR_SECONDS` | RW | counter integration interval in seconds |
| `0x03` | reserved | — | reads zero |

Opcodes (per `mutrig_ctrl.vhd:202..204`):

| Constant | Hex | Meaning |
|---|---|---|
| `CMD_MUTRIG_ASIC_CFG` | `0x011` | DMA cfg bitstream from `scratch_pad_ram[OFFSET..]` into the IP's CFG-mem partition for `asic_id`, then SPI-write to the MuTRiG. |
| `CMD_MUTRIG_ASIC_TTH_SCAN` | `0x012` | sweep per-channel TTH for `asic_id` over 64 steps; record per-(channel, TTH) hit-rate into the Result RAM exposed at `avs_scanresult_*`. Requires that the MuTRiG was already configured at least once via `CMD_MUTRIG_ASIC_CFG` (per the controller's note). |
| `CMD_MUTRIG_ASIC_TTH_SCAN_ALL` | `0x014` | iterate `CMD_MUTRIG_ASIC_TTH_SCAN` across all 8 ASICs. |

**Important constants** (from `mutrig_ctrl.vhd:201, 210..213`):

- `CFG_MEM_PARTITION_SIZE_WORD = 128` — each ASIC has a 128-word internal cfg-mem partition.
- `CFG_HEADER_LENGTH = 34` bits, `CFG_SINGLE_CH_LENGTH = 71` bits, `CFG_SINGLE_CH_TTH_OFFSET = 24` bits, `CFG_TTH_SETTING_LENGTH = 6` bits, `CFG_N_CH = 32`.
- `MUTRIG_CFG_LENGTH_BIT = 2662` for MuTRiG3.

### 2.3 Bring-up procedure

This is a procedure description; the actual execution wraps `sc_tool` and reuses `run_phase4_emulator.py`'s run-control sequence. **Do not** re-author either tool; only data values change.

1. **Pre-flight**:
    - `script/check_ip_metadata.py` and `script/check_sc_bridges.py` clean.
    - `rc_tool status` reports IDLE (no run armed).
    - Read `mutrig_cfg_ctrl_0.OPCODE_STATUS` (`0x0FC04`) and confirm `[15:0]=0x0000` (idle status).

2. **Stage cfg bitstream** for ASIC `k ∈ {0..7}`:
    - Compute the cfg-bitstream **word stream** from the production text file used by `Mutrig_FEB.cpp` (a sequence of 32-bit words holding the 2662-bit packed bitstream, padded to a word boundary; ⌈2662/32⌉ = 84 words per ASIC).
    - Block-write that word stream into `scratch_pad_ram` at byte offset `OFFSET_BYTE_k = 0x000 + 84*4*k` (so all eight ASIC bitstreams sit back-to-back; each ASIC fits inside the existing scratchpad span, and each word offset stays inside the controller's 11-bit `avm_schpad_address` range).
    - The 2662-bit length is encoded in `cfglen` field of the next opcode write.

3. **Issue `CMD_MUTRIG_ASIC_CFG`** for ASIC `k`:
    - `sc_tool write 0x0FC05 [OFFSET_WORD_k]` (where `OFFSET_WORD_k = OFFSET_BYTE_k / 4`).
    - `sc_tool write 0x0FC04 [(0x011 << 20) | (k << 16) | 2662]`.
    - Poll `OPCODE_STATUS` until `[15:0]` returns to idle. Record `[31:16]` for the opcode echo to confirm the controller acknowledged the write.

4. **Verify decoded frames** at `mutrig_frame_deassembly_k.csr`:
    - Read the per-IP UID/VERSION/STATUS aperture.
    - Confirm the per-IP frame-counter advances over a 100 ms interval (i.e. the deassembler is locked on the live K28.5 idle stream and decoding K28.0 SOPs).
    - If any deassembler does not advance, halt — that ASIC was not configured (most likely scratchpad word stream was wrong), and `Mutrig_FEB.cpp` is the reference for the bit packing.

5. **Optional but mandatory before §5**: `CMD_MUTRIG_ASIC_TTH_SCAN_ALL`:
    - `sc_tool write 0x0FC04 [(0x014 << 20)]`.
    - The TSA increments TTH 0..63 and writes `(per-channel, per-TTH)` rate into the Result RAM exposed via `avs_scanresult_*` (14-bit address aperture).
    - Read out the full 8 × 32 × 64 result block; for each ASIC and each channel, record the TTH knee position. The knee per channel is the candidate operating threshold for that channel.
    - Bind the per-channel threshold into a *known-good* set in the cfg bitstream by re-running step 3 with the updated cfg word stream. Record this stream as the Phase-5 baseline.

6. **Save the baseline**: write the resulting per-ASIC, per-channel TTH table to `../systems/system_20260427_testplanphase5/reports/phase5_mutrig_baseline_<date>.md`. This file is the *only* implementation-bearing artifact this plan calls for, and it is data, not code.

### 2.4 Pass / fail

Phase 5 §2 PASSES when:

- All eight `mutrig_frame_deassembly_k` blocks report incrementing frame counters for at least 100 ms with no reported decoder errors.
- The `histogram_statistics_0` `TOTAL_HITS` advances over a 1 s window with the live MuTRiG-fed datapath.
- The TSA result RAM contains a sane, per-channel monotonic rate-vs-TTH curve for every (ASIC, channel) pair (no zero columns; no flatline rows).
- The baseline cfg word stream is recorded.

Phase 5 §2 FAILS hard if any of the eight ASICs cannot lock its decoded frame within the integration interval — that is the prerequisite gate for §3..§5. A common symptom and its first-pass debug entry point are listed in §6.

---

## 3. Frame-format SignalTap signoff (4096 samples × 4 segments)

Capture two SignalTap image families, one for FEB egress and one for SWB ingress, both configured **4096 sample depth × 4 segments** (segmented capture on Quartus Stp).

**SignalTap segmentation constraint**: one segmented `.stp` acquisition has exactly one trigger condition. The four segments are four consecutive occurrences of that same trigger condition. Do not specify a different trigger for each segment. When several trigger conditions are needed, create several `.stp` trigger-case images or several runs of the same image with the trigger edited between runs.

The goal of the 4×4096 layout is to capture four adjacent frames or four adjacent hit/framing events. The proof is not just "one packet is shaped correctly"; it is that adjacent frame counters, SOP cadence, EOP cadence, and payload/hit counts advance correctly across consecutive frames, which catches common missed-frame, double-SOP, and off-by-one bugs.

### 3.1 SignalTap image #1 — FEB egress

**Image**: `../signaltap/phase5_feb_egress_aso_tx8b1k.stp` (to be authored on first run; this plan does not pre-author the `.stp`).

**Clock domain**: `lvds_rx_28nm_0.outclock` (the same clock that drives `aso_tx8b1k_*` per `feb_system_v3_pipe.qsys` and the Phase 4 trigger map in `TEST_PLAN.md` §4.3).

**Probed signals** (one per row, recorded for all four segments):

| Signal | Width | Source |
|---|---|---|
| `aso_tx8b1k_valid` | 1 | per-lane TX into LVDS PHY (already used in Phase 4 §4.3 SOP/EOP triggers) |
| `aso_tx8b1k_data[8:0]` | 9 | same — bit 8 is K-flag, bits 7:0 are data |
| `mutrig_frame_deassembly_k.frame_counter` | 16 | per-IP frame counter for cross-check |
| `mutrig_frame_deassembly_k.error_flags` | n | decoder error mask |
| `feb_frame_assembly_{0,1}.csr.<frame_id, hit_count>` shadow | n | end-of-pipe FEB frame ID/hit count |
| `runctl_mgmt_host_0.run_state[8:0]` | 9 | one-hot run-state echo |
| `histogram_ingress_bridge_0.live_select_post` + `.post_packet_active` | 2 | confirms ingress is in the expected mode for this capture |

**Trigger-case matrix** (one trigger condition per image/run; each image stores four consecutive trigger events):

| case_id | Trigger condition (1-cycle combinational) | Captures | Coverage bucket |
|---|---|---|---|
| STP5-FEB-BASIC-SOP-L0 | `aso_tx8b1k_valid && aso_tx8b1k_data == 9'h11C` on lane 0 | four consecutive SOP-centered frame windows on lower bank | BASIC |
| STP5-FEB-BASIC-EOP-L0 | `aso_tx8b1k_valid && aso_tx8b1k_data == 9'h19C` on lane 0 | four consecutive EOP-centered frame windows on lower bank | BASIC |
| STP5-FEB-BASIC-SOP-L4 | `aso_tx8b1k_valid && aso_tx8b1k_data == 9'h11C` on lane 4 | four consecutive SOP-centered frame windows on upper bank | BASIC |
| STP5-FEB-EDGE-LONG-SOP | `aso_tx8b1k_valid && aso_tx8b1k_data == 9'h11C` with `csr_short_mode=0` | four consecutive long-frame SOP windows | EDGE |
| STP5-FEB-ERROR-SOP-IN-FRAME | `aso_tx8b1k_valid && aso_tx8b1k_data == 9'h11C && in_frame_q` | should not trigger during a 60 s nominal window; if it does, stores the first four torn-frame events | ERROR |

**Capture position**: 20% post-trigger so each segment retains 3276 cycles of pre-trigger context and ~820 cycles of post-trigger context. For SOP-triggered short-frame captures, this is enough to see the K28.5 idle stream before the SOP, the payload that follows, the EOP, and the next frame boundary context. Across four segments, verify four consecutive trigger events and the adjacent-frame relationships between them.

For ERROR trigger cases, pass is normally "no trigger during the observation window." If a negative trigger fires, all four segments capture consecutive occurrences of that same error condition and the case fails with those captures as debug evidence.

### 3.2 SignalTap image #2 — SWB ingress

**Image**: `../signaltap/phase5_swb_ingress.stp` on the **SWB FPGA**, not the FEB. The SWB build is `online_sc/online/switching_pc/a10_board/output_files/top.sof` (per the FEB ↔ SWB mapping in `~/CLAUDE.md`); this plan does not modify the SWB SOF, but it does add a Phase-5 SignalTap image into the SWB Quartus project (or reuse an existing per-link ingress image if one is already in the SWB tree). The `.stp` author and check-in is a follow-up task in `online_sc`, not in this repo.

**Clock domain**: SWB FEB-link RX recovered clock for link 2 (the SciFi FEB link per `~/CLAUDE.md` `feb_scifi_link_mapping`).

**Probed signals**:

| Signal | Width | Notes |
|---|---|---|
| Per-link 8b/10b decoder `data[7:0]`, `is_k`, `disp_err`, `code_err` | 1+1+1+8 | post-decoded byte stream |
| Per-link RX FIFO `wr_en`, `level[*]`, `full`, `empty` | n | back-pressure state at the SWB ingress |
| Per-link `LINK_LOCKED` bit | 1 | confirms link 2 is locked (the bit in the low link-lock register, not the upper register that contains other boards) |
| SWB-side per-link hit counter shadow | 32 | the same counter `TEST_PLAN.md` §4.4 already references |

**Trigger-case matrix** (one trigger condition per image/run; each image stores four consecutive trigger events):

| case_id | Trigger | Captures | Coverage bucket |
|---|---|---|---|
| STP5-SWB-BASIC-SOP | `is_k && data == 8'h1C` | four consecutive ingress SOP windows | BASIC |
| STP5-SWB-BASIC-EOP | `is_k && data == 8'h9C` | four consecutive ingress EOP windows | BASIC |
| STP5-SWB-BASIC-IDLE-AFTER-PAYLOAD | `is_k && data == 8'hBC && rising_edge(prev_payload_valid)` | four consecutive inter-frame transitions | BASIC |
| STP5-SWB-ERROR-CODE-DISP | `code_err || disp_err` | should not trigger during a 60 s nominal window; if it does, stores the first four decoder-error events | ERROR |

**Same depth and position as §3.1**: 4096 × 4 segments, 20% post-trigger.

### 3.3 What this image proves

The pair of images proves the canonical 8b/10b framing contract end-to-end:

- **K28.5 fill** — the inter-frame stream is K28.5 idles only; SOP and idle-after-payload trigger cases must show solid K28.5 between two K28.0 SOPs.
- **K28.0 SOP at frame boundary** — the four SOP segments capture four adjacent frame starts on the same trigger case.
- **K28.4 EOP closes the frame** — the four EOP segments capture four adjacent frame closes on the same trigger case.
- **No torn frames** — the dedicated torn-frame/error trigger cases do not trigger during the 60 s nominal window.
- **Adjacent frame counter increment** — for consecutive SOP and EOP trigger cases, `mutrig_frame_deassembly_k.frame_counter` and FEB frame ID shadows increment by exactly one between adjacent segments, modulo the documented counter width.
- **Frame interval** — measured cycle distance between consecutive SOP events equals `FRAME_INTERVAL_SHORT` (910) for `csr_short_mode=1` and `FRAME_INTERVAL_LONG` (1550) for `csr_short_mode=0`, within the expected 1-cycle FIFO jitter.
- **Multi-packet repetition** — the four segments are four consecutive events, so an off-by-one timing error, dropped frame, repeated frame counter, or missed EOP in any adjacent pair fails the alignment cross-check.

### 3.4 Pass / fail

Phase 5 §3 PASSES when:

- Both images arm and capture in the same FEB run; the SWB image was armed before the FEB-side stimulus started.
- Every BASIC/EDGE trigger case produces four consecutive segments with clean decoded packet boundaries and K28.0 → payload → K28.4 → K28.5 idle ordering.
- Adjacent segments in each SOP/EOP trigger case show frame counters and frame IDs incrementing by exactly one.
- Dedicated ERROR trigger cases do not fire during the 60 s nominal observation window.
- The cycle distance between consecutive SOP trigger events matches `FRAME_INTERVAL_{SHORT,LONG}` ± 1 cycle.

Phase 5 §3 FAILS if any of:

- A K28.0 lands inside an already-open packet (the FEB torn-frame trigger case fires).
- A code-err or disp-err lands at SWB ingress (the SWB decoder-error trigger case fires).
- Adjacent captured frame counters skip, repeat, or advance by more than one.
- The frame interval drifts beyond ± 4 cycles, indicating a clock-domain or FIFO-overflow hazard on the egress path.

A failure here is treated as a **datapath regression** and routes back to the integration debug ladder in `phase4/TEST_PLAN_BASIC.md` "Disagreement protocol" — debug RTL (`emulator_mutrig.sv` / `mutrig_frame_deassembly`) before debugging the board fabric.

---

## 4. Emulator vs real-MuTRiG packet equivalence

### 4.1 What this stage proves

Phase 4 closure attests that the emulator-fed datapath is correct. Phase 5 §4 attests that the real-MuTRiG datapath produces a frame stream **structurally indistinguishable** from the emulator stream at:

- the FEB egress (post-`feb_frame_assembly`, the same `aso_tx8b1k` capture as §3.1)
- the SWB ingress (post-decoder)

up to a defined set of allowed payload differences (real MuTRiG hits carry real T/E TDC values; emulator hits carry LFSR-synthesized values).

### 4.2 Capture pairs

Two stimulus configurations are run back-to-back with the same SC/RC sequence, the same histogram CSR settings, the same SignalTap trigger-case images from §3, and the **same** segment depth × count:

1. **Emulator stimulus** (Phase 4 reference): write `data_path_subsystem.source_select` (or its functional equivalent in the integration build's mux) to "emulator", program `emulator_mutrig_0..7.csr` for `enable=1, hit_mode=POISSON_IID, short_mode=1, hit_rate=0x0800`. Arm run-control `RUNNING`. Capture `phase5_emut_baseline_egress.stp` and `phase5_emut_baseline_swb.stp`.
2. **Real-MuTRiG stimulus**: write the source select to "real" (the live ASIC path), with §2 baseline cfg already loaded. Same `short_mode`, same per-MuTRiG average rate (achieved on real ASICs by the dark-rate floor at the §2.5 known-good threshold). Capture `phase5_real_egress.stp` and `phase5_real_swb.stp`.

Both image pairs are stored in `../signaltap/` and the equivalence comparison is run as a post-processing pass on the exported CSV — see §4.3.

### 4.3 Comparison rules

| Compare | Real vs Emulator must match |
|---|---|
| K28.5 idle byte count between SOPs | bit-exact |
| K28.0 SOP arrival cadence | within ± 1 cycle of `FRAME_INTERVAL_{SHORT,LONG}` |
| K28.4 EOP cadence | within ± 1 cycle |
| Frame counter increment per second | within ± 1 frame over a 1 s window |
| Per-frame number of K28.0 → K28.4 byte spans | identical distribution shape (Kolmogorov–Smirnov ≤ 0.05 across 1024 frames) |
| Per-frame K28.5 fill ratio inside the SOP-EOP span | identical distribution shape |
| `histogram_ingress_bridge_0.STATUS.post_hit_region` cadence | identical distribution shape |
| `histogram_statistics_0.OVERFLOW_COUNT`, `UNDERFLOW_COUNT`, `DROPPED_HITS` deltas | both must be `delta = 0` |

### 4.4 Allowed payload differences (do not flag as regressions)

| Difference | Reason |
|---|---|
| Hit-record T/E TDC values | real MuTRiG produces analog/T-injected real timestamps; emulator produces LFSR-synthesized values |
| Per-channel hit-rate microstructure | dark-noise rate per real channel is set by the cfg-bitstream TTH and by physical thermal noise; emulator's per-channel rate is the LFSR PRNG |
| CRC byte content | the *byte position* and *width* of the CRC field is identical; the *value* is computed live and will differ |

### 4.5 Pass / fail

Phase 5 §4 PASSES when every "bit-exact / shape-exact" line in §4.3 passes for both image pairs and the histogram counter deltas in the last row are zero. Phase 5 §4 FAILS if any structural compare fails — which is treated as a real-MuTRiG framing regression and routed to the §6 debug ladder.

---

## 5. Injector + histogram closure (5 stimulus groups × 64 cases)

### 5.1 Common configuration

For every Phase-5 §5 case below:

- All eight MuTRiG3 ASICs are configured per §2 baseline cfg.
- `histogram_ingress_bridge_0.CONTROL.select_post` is configured per the case's *primary observable* (delay PDF → post-hit-stack tap; channel/ASIC rate distribution → pre-hit-stack tap; the `histogram_statistics_0.CONTROL.mode` field selects the corresponding update-key extraction).
- `histogram_statistics_0`:
    - `LEFT_BOUND = 0`, `RIGHT_BOUND = 255` for channel/ASIC rate buckets (one bin per global channel ID).
    - `LEFT_BOUND = 0`, `RIGHT_BOUND = 2047` (or `pipe + 2*FRAME_INTERVAL_SHORT`) for delay buckets, with `BIN_WIDTH = 1`.
    - `INTERVAL_CFG` set so that one ping-pong interval contains ≥ 256 hits per active bin in the no-injection background and ≥ 16384 hits per active bin in the injection cases.
    - `apply` written, `apply_pending` polled to clear before run start.
- Run-control: CMD_RUN_PREPARE → CMD_SYNC → CMD_START_RUN, hold for the case's stated duration, then CMD_END_RUN.
- Counters snapshotted before and after each case via `probe_phase4_stage_counters.py`.
- Per-case report row written to `../reports/phase5_injector_<bucket>_<date>.md`.

### 5.2 Implemented mutrig_injector_0 modes (live RTL)

Per the active `scifi_datapath_system_v3_pipe.qsys` instance,
`mutrig_injector_0` is `mutrig_injector_multiheader`. Its
[`../../charge_injection/mutrig_injector_multiheader.vhd`](../../charge_injection/mutrig_injector_multiheader.vhd)
`pulse_arb` and CSR `mode` field expose:

| `mode` | Meaning | RTL state | Notes |
|---|---|---|---|
| `0` | off / onClick available | `coe_inject_pulse <= onclick_injector_pulse` | also the resting state of the IP. |
| `1` | header-synchronized | `coe_inject_pulse <= header_injector_pulse` | armed by `asi_headerinfo_valid && channel == header_ch`; injects after `header_delay` cycles, then `injection_multiplicity` pulses each `pulse_high_cycles` long. |
| `2` | periodic free-running | `coe_inject_pulse <= periodic_injector_pulse` | armed unconditionally inside the IP; fires every `pulse_interval` cycles. |
| `3` | periodic_async | `coe_inject_pulse <= periodic_async_pulse` | generated in the `i_osc_clk` domain and synchronized from the CSR domain; directed RTL sim on 2026-04-27 passed the pre-RBCAM measurement harness with no drops/underflows/overflows. |
| `4` | onclick (transient) | written into `csr.mode`; the write side resets `csr.mode` to 0 after one pulse | observable through onClick path (mode 0 arbiter output). |
| `5` | random / PRNG-driven | `coe_inject_pulse <= random_injector_pulse` | PRBS-rate, pattern, seed, and control registers are CSR words 7..10; directed RTL sim on 2026-04-27 passed the pre-RBCAM measurement harness with no drops/underflows/overflows. |

Phase 5 §5 buckets exercise all live modes: 0+onclick, 1, 2, 3, 4, and 5.

### 5.3 Bucket summary

| Bucket | ID range | Cases | Primary stimulus knob | Primary observable | Driving question |
|---|---|---|---|---|---|
| A | TPB5A01..TPB5A64 | 64 | per-channel TTH (via `mutrig_cfg_ctrl_0` + TSA) | channel/ASIC dark-rate distribution from `histogram_statistics_0` (pre-hit-stack tap, channel-ID key) | does each ASIC's dark-rate vs threshold curve match the TSA RAM and stay below the histogram-overflow ceiling at the operating threshold? |
| B | TPB5B01..TPB5B64 | 64 | software-side **ASIC mask** (gating each MuTRiG's deassembled stream into the histogram path) and **channel mask** (programmed into the ASIC cfg bitstream) at fixed background rate | channel/ASIC rate distribution | does the histogram exactly count the unmasked (ASIC, channel) intersection? |
| C | TPB5C01..TPB5C64 | 64 | mode-1 `header_delay` sweep over the full short-frame interval | delay PDF (post-hit-stack tap, delay key) | is the delay PDF a delta pulse at `FRAME_INTERVAL_SHORT - header_delay` for every header_delay (slide-24 truth on the live ASIC)? |
| D | TPB5D01..TPB5D64 | 64 | mode-2 `pulse_interval` sweep covering 25 Mhit/s wire-floor down to wire-cap | delay PDF + per-MuTRiG accepted rate | does the delay PDF widen monotonically and the per-MuTRiG accepted rate clip exactly at the 25 Mhit/s wire-cap, matching slides 23/25/38? |
| E | TPB5E01..TPB5E64 | 64 | mode-3 async periodic, mode-5 PRNG, mode-4 onClick burst stimulus, ASIC×channel-rate stress | channel/ASIC rate distribution **and** delay PDF | does the histogram correctly observe async, random, one-shot, and skewed-rate injection at the expected rate without overflow or dropped hits? |

The stimulus catalog covers **delay** and **channel/ASIC rate** distributions explicitly per the Phase-5 closure ask, with five 64-case stimulus groups. Each row maps into the BASIC/EDGE/PROF/ERROR functional coverage buckets from §1.6 when reported; the coverage denominator is therefore 256 required functional points, not the 320 stimulus rows.

### 5.4 Bucket A — real-MuTRiG threshold / dark-rate distribution (TPB5A01..TPB5A64)

**Goal**: prove the live-MuTRiG dark-rate distribution at every (ASIC, threshold-step) cell matches the TSA result RAM and is observable on the histogram with no overflow or dropped hits. This is the bucket that anchors the §2 known-good baseline against the histogram observation surface.

**Stimulus**: no injector. `mutrig_injector_0.mode = 0`. Background traffic is the real ASIC dark-rate floor.
**Observable**: channel/ASIC rate distribution. `histogram_statistics_0.CONTROL.mode` set to the channel-ID key extraction; bin width 1; range [0, 255]. `histogram_ingress_bridge_0.select_post = 0` (pre-hit-stack tap, so each channel-tag write is one increment per accepted hit).
**Method**: 64 cells = 8 ASICs × 8 representative TTH steps (`tth ∈ {16, 24, 32, 40, 48, 52, 56, 60}`) chosen from the TSA result-RAM knees identified in §2.5. For each cell, the bitstream of the corresponding ASIC has its 6-bit per-channel TTH field replaced with the cell's TTH value via a fresh `CMD_MUTRIG_ASIC_CFG` (offset, opcode); other ASICs are held at the §2.5 baseline.

| case_id | method | implementation | scenario | primary checks | stage |
|---|---|---|---|---|---|
| TPB5A01 | D | live BOARD | ASIC 0, `tth=16` (low-threshold corner — high dark rate) | only the lane-0 slice (bins 0..31) populated; per-channel rate matches TSA result RAM ± 5%; `OVERFLOW_COUNT delta = 0`; `DROPPED_HITS delta = 0` | B |
| TPB5A02 | D | live BOARD | ASIC 0, `tth=24` | same shape, lower per-channel rate; rate-vs-tth curve monotone | B |
| TPB5A03 | D | live BOARD | ASIC 0, `tth=32` | lane-0 dark-rate at the operating-threshold reference | B |
| TPB5A04 | D | live BOARD | ASIC 0, `tth=40` | lane-0 rate drops further | B |
| TPB5A05 | D | live BOARD | ASIC 0, `tth=48` | lane-0 rate near the floor | B |
| TPB5A06 | D | live BOARD | ASIC 0, `tth=52` | floor; per-channel rate is at the noise-only limit | B |
| TPB5A07 | D | live BOARD | ASIC 0, `tth=56` | floor; cross-check that the histogram floor matches the SWB-side per-link counter (within 1%) | B |
| TPB5A08 | D | live BOARD | ASIC 0, `tth=60` (high-threshold corner) | floor; many channels go quiescent | B |
| TPB5A09..TPB5A16 | D | live BOARD | ASIC 1, `tth ∈ {16, 24, 32, 40, 48, 52, 56, 60}` | only lane-1 slice (bins 32..63) populated; per-channel rate vs TTH monotone | B |
| TPB5A17..TPB5A24 | D | live BOARD | ASIC 2, same TTH grid | only lane-2 slice (bins 64..95) populated | B |
| TPB5A25..TPB5A32 | D | live BOARD | ASIC 3, same TTH grid | only lane-3 slice (bins 96..127) populated | B |
| TPB5A33..TPB5A40 | D | live BOARD | ASIC 4, same TTH grid | only lane-4 slice (bins 128..159) populated | B |
| TPB5A41..TPB5A48 | D | live BOARD | ASIC 5, same TTH grid | only lane-5 slice (bins 160..191) populated | B |
| TPB5A49..TPB5A56 | D | live BOARD | ASIC 6, same TTH grid | only lane-6 slice (bins 192..223) populated | B |
| TPB5A57..TPB5A64 | D | live BOARD | ASIC 7, same TTH grid | only lane-7 slice (bins 224..255) populated; the eighth ASIC closes the per-ASIC sweep | B |

**Bucket A pass aggregator**: every (ASIC, TTH) cell shows a populated lane-slice and a quiescent rest-of-spectrum, the per-channel rate vs TTH curve is monotone (within Poisson 3σ), and no `OVERFLOW_COUNT`/`DROPPED_HITS` advance. Cross-source compare: TSA result RAM ↔ histogram bin RAM; the two must agree within 5%.

### 5.5 Bucket B — ASIC + channel mask sweep at fixed background (TPB5B01..TPB5B64)

**Goal**: prove that the live-MuTRiG datapath responds to ASIC-level and channel-level masking exactly as the emulator did in Phase 4 TPB020..TPB031, but with a richer 64-case grid. The 64 cases are 8 channel-mask patterns × 8 ASIC-enable patterns. The ASIC-enable mask is applied **at the cfg-bitstream level** via TTH-field-effective masking (set channel TTH to 63 to silence) — no source-select hack is used.

**Stimulus**: no injector. Each ASIC's cfg bitstream is rewritten via `CMD_MUTRIG_ASIC_CFG` to encode the desired channel mask in the 32 per-channel TTH slots (TTH=63 → channel quiescent; TTH=baseline → channel active). Each "ASIC enable" group is realized by silencing all channels of the masked-out ASICs.
**Observable**: channel/ASIC rate distribution.

| case_id | method | implementation | scenario (asic_enable, channel_mask) | primary checks | stage |
|---|---|---|---|---|---|
| TPB5B01 | D | live BOARD | asic_enable=0xFF, channel_mask=0xFFFFFFFF — all 8 ASICs, all 32 channels | all 256 bins populated; per-bin rate within Poisson 3σ of the dark-rate baseline | B |
| TPB5B02 | D | live BOARD | asic_enable=0xFF, channel_mask=0x0000FFFF (lower half) | only channels 0..15 of every lane populated | B |
| TPB5B03 | D | live BOARD | asic_enable=0xFF, channel_mask=0xFFFF0000 (upper half) | inverse | B |
| TPB5B04 | D | live BOARD | asic_enable=0xFF, channel_mask=0x55555555 (even) | only even channels per lane populated | B |
| TPB5B05 | D | live BOARD | asic_enable=0xFF, channel_mask=0xAAAAAAAA (odd) | only odd channels per lane populated | B |
| TPB5B06 | D | live BOARD | asic_enable=0xFF, channel_mask=0x00000001 (one channel) | one channel per lane populated; cross-lane rate identical within Poisson tolerance | B |
| TPB5B07 | D | live BOARD | asic_enable=0xFF, channel_mask=0x80000001 (corner pair) | two channels per lane populated | B |
| TPB5B08 | D | live BOARD | asic_enable=0xFF, channel_mask=0x00FF00FF (byte stripe) | byte-stripe channels populated | B |
| TPB5B09..TPB5B16 | D | live BOARD | asic_enable=0x01 (only ASIC 0 active), channel_mask sweep over the same 8 patterns above | only lane-0 slice populated, with the per-pattern channel geometry | B |
| TPB5B17..TPB5B24 | D | live BOARD | asic_enable=0x02 (only ASIC 1), same 8 channel masks | only lane-1 slice populated | B |
| TPB5B25..TPB5B32 | D | live BOARD | asic_enable=0x04 (only ASIC 2), same 8 channel masks | only lane-2 slice populated | B |
| TPB5B33..TPB5B40 | D | live BOARD | asic_enable=0x08 (only ASIC 3), same 8 channel masks | only lane-3 slice populated | B |
| TPB5B41..TPB5B48 | D | live BOARD | asic_enable=0x0F (lower 4 ASICs), same 8 channel masks | only lanes 0..3 populated | B |
| TPB5B49..TPB5B56 | D | live BOARD | asic_enable=0xF0 (upper 4 ASICs), same 8 channel masks | only lanes 4..7 populated | B |
| TPB5B57..TPB5B64 | D | live BOARD | asic_enable=0xAA (alternating ASICs), same 8 channel masks | only lanes 1, 3, 5, 7 populated | B |

**Bucket B pass aggregator**: every (asic_enable, channel_mask) cell produces exactly the predicted bin geometry; non-selected lanes are silent (zero bin advance); `OVERFLOW_COUNT`/`DROPPED_HITS`/`UNDERFLOW_COUNT` deltas all zero. Cross-source compare against Phase 4 TPB020..TPB031 emulator runs: the two histograms must overlay within Poisson 3σ on every populated channel.

### 5.6 Bucket C — mode-1 header_delay sweep on real MuTRiG (TPB5C01..TPB5C64)

**Goal**: extend Phase 4 TPB032..TPB055 (slide-24 truth) onto the live ASIC. Sweep `mutrig_injector_0.header_delay` across the full `FRAME_INTERVAL_SHORT = 910`-cycle frame at 64 evenly-spaced points (stride ≈ 14 cycles).

**Stimulus**: `mutrig_injector_0.mode = 1`, `header_interval = 1`, `injection_multiplicity = 1`, `pulse_high_cycles = 5`. Channel-mask via cfg-bitstream: one channel of one ASIC enabled per case. Background dark-rate from §5.4 baseline (other channels at TTH=63 → silent so they do not pollute the delay PDF).
**Observable**: delay PDF. `histogram_ingress_bridge_0.select_post = 1` (post-hit-stack tap so the histogram sees the resequenced delay key); `histogram_statistics_0.CONTROL.mode` selects the delay-key extraction; `LEFT_BOUND = 0`, `RIGHT_BOUND = 2047`, `BIN_WIDTH = 1`.

| case_id | method | implementation | scenario (active ASIC, channel, header_delay) | primary checks | stage |
|---|---|---|---|---|---|
| TPB5C01 | D | live BOARD | ASIC 0, ch 0, `header_delay = 14` | delay PDF is a delta pulse near 896 cycles ± 16 (`FRAME_INTERVAL_SHORT - header_delay`); width ≤ 120 cycles | B |
| TPB5C02..TPB5C64 | D | live BOARD | sweep `header_delay ∈ {14, 28, 42, ..., 910}` (63 more points), ASIC ID rotates per case (`asic = floor(case_idx / 8) mod 8`), channel ID rotates per case (`channel = case_idx mod 32`) | each case shows one delta pulse at the predicted offset; pulse position vs header_delay is linear with slope -1 and intercept `FRAME_INTERVAL_SHORT`, replicating slide 24's continuous traversal | B |

**Bucket C pass aggregator**: all 64 cases produce a single delta pulse at the predicted offset; the linear fit of (pulse position vs header_delay) has slope -1 ± 0.02 and intercept 910 ± 4 cycles; `OVERFLOW_COUNT delta = 0`. Cross-source compare against Phase 4 TPB032..TPB055 emulator runs: the per-(ASIC, channel) delta-pulse position must overlay within ± 16 cycles.

### 5.7 Bucket D — mode-2 free-running rate sweep on real MuTRiG (TPB5D01..TPB5D64)

**Goal**: extend Phase 4 TPB056..TPB079 (slides 23 / 25 / 38) onto the live ASIC. Sweep `pulse_interval` across the full live range — from a slow background (1 Mhit/s) up to the 25 Mhit/s per-MuTRiG wire-cap — at 64 logarithmically-spaced points.

**Stimulus**: `mutrig_injector_0.mode = 2`, all 8 ASICs active, channel-mask = all 32 channels (per cfg). Per-MuTRiG injected pulse rate r(case) chosen so r(0) = 1 Mhit/s, r(63) = 25 Mhit/s, log-spaced in between.

`pulse_interval ≈ CLK_FREQUENCY / r(case)` where `CLK_FREQUENCY = 125 MHz` per the IP generic.
**Observable**: delay PDF (same histogram setup as §5.6) **and** the per-MuTRiG accepted rate captured via `histogram_statistics_0.TOTAL_HITS` over a fixed integration interval.

| case_id | method | implementation | scenario | primary checks | stage |
|---|---|---|---|---|---|
| TPB5D01 | D | live BOARD | r ≈ 1 Mhit/s | delay PDF a narrow block near 800-1000 cycles; `DROPPED_HITS = 0`; `TOTAL_HITS` advances at ≈ 1 Mhit/s × 8 ASIC | B |
| TPB5D02..TPB5D32 | D | live BOARD | r ∈ log-grid 1..10 Mhit/s (31 points) | delay block widens monotonically; `TOTAL_HITS` rate doubles at each octave; `DROPPED_HITS = 0` | B |
| TPB5D33..TPB5D56 | D | live BOARD | r ∈ log-grid 10..23 Mhit/s (24 points) | block approaches the 0-to-2-frame envelope; `TOTAL_HITS` rate continues to scale; `DROPPED_HITS = 0` | B |
| TPB5D57..TPB5D63 | D | live BOARD | r ∈ {23, 23.5, 24, 24.5, 24.8, 24.9, 25.0} Mhit/s | block fills the `pipe + 2*FRAME_INTERVAL_SHORT` envelope; `TOTAL_HITS` rate plateaus at ≈ 200 Mhit/s aggregate; `DROPPED_HITS` may begin to advance (recorded but not gated below 200 Mhit/s) | B |
| TPB5D64 | D | live BOARD | r > 25 Mhit/s (overshoot, e.g. r = 30 Mhit/s requested) | accepted rate plateaus at the wire-cap; the **excess** is dropped at the MuTRiG side, not at the FEB datapath; `OVERFLOW_COUNT = 0` (this is the proof that the emulator's 25 Mhit/s wire-cap is matched by the real ASIC) | B |

**Bucket D pass aggregator**: the rate-doubling ratio of `TOTAL_HITS` holds 2.0 ± 5% over the log-grid until the wire-cap, where it plateaus at 200 Mhit/s aggregate (8 ASICs × 25 Mhit/s) ± 1%; the delay PDF widens monotonically; `OVERFLOW_COUNT` stays at zero across the full sweep. Cross-source compare against Phase 4 TPB056..TPB079 emulator runs: per-rate delay-block envelope must overlay within ± 5%.

### 5.8 Bucket E — mixed traffic + onClick + ASIC×channel rate stress (TPB5E01..TPB5E64)

**Goal**: prove the histogram observation surface stays correct when multiple injection sources superpose on the live ASIC datapath, and exercise the mode-4 onClick path that Phase 4 did not (Phase 4 used periodic / synchronous modes only).

**Stimulus**:

- TPB5E01..TPB5E08 (8 cases): mode-3 async periodic stimulus. Sweep `pulse_interval` over an 8-point rate grid with `i_osc_clk` as the pulse source; compare the pre-RBCAM rate histogram and the post-hit-stack delay PDF against the mode-2 synchronous sweep at the same requested rates.
- TPB5E09..TPB5E16 (8 cases): mode-5 PRNG stimulus. Sweep `{prbs_rate, prbs_ctrl.match_width, prbs_pattern}` over 8 deterministic seeds/patterns and confirm the accepted hit count follows the expected PRBS match probability within Poisson 3 sigma.
- TPB5E17..TPB5E32 (16 cases): mode-4 onClick stimulus with varying `pulse_high_cycles ∈ {5, 7, 11, 16, 24, 32, 48, 64}` and `injection_multiplicity ∈ {1, 2, 4, 8}` (8 × 4 = 32 combinations, sampled at 16 representative points), single channel.
- TPB5E33..TPB5E48 (16 cases): per-ASIC rate skew. ASIC k gets injection mode-2 at r = k × 3 Mhit/s (k=0..7), the other ASICs at the §5.4 baseline dark-rate. Eight base configurations × two rate scalings (½× and 1×) = 16 cases.
- TPB5E49..TPB5E64 (16 cases): channel-rate stress. Single ASIC with all 32 channels active, mode-2 injection at r ∈ {12, 14, 16, 18, 20, 22, 24, 25} Mhit/s, repeated for two ASICs (ASIC 0 and ASIC 7) — 8 × 2 = 16 cases.

**Observable**: channel/ASIC rate distribution **and** delay PDF, captured in two passes per case (one with `histogram_ingress_bridge_0.select_post = 0`, one with `select_post = 1`).

| case_id | method | implementation | scenario summary | primary checks | stage |
|---|---|---|---|---|---|
| TPB5E01..TPB5E08 | D | live BOARD | mode-3 async periodic sweep | requested rate appears in the channel histogram; delay PDF overlays the mode-2 envelope at matching rate after accounting for async phase; `DROPPED_HITS = 0` | B |
| TPB5E09..TPB5E16 | D | live BOARD | mode-5 PRNG sweep | accepted rate follows PRBS match probability; histogram has no dead bins in the selected ASIC/channel slice; `DROPPED_HITS = 0` | B |
| TPB5E17..TPB5E32 | D | live BOARD | mode-4 onClick (16 (pulse_high_cycles × injection_multiplicity) pairs) | `histogram_statistics_0.TOTAL_HITS` advances by exactly `injection_multiplicity` per click; the channel-ID slice of the histogram contains the expected single-channel population; `INJ_ARM` SignalTap trigger from `TEST_PLAN.md` §4.3 must not fire outside `RUNNING` | B |
| TPB5E33..TPB5E48 | D | live BOARD | per-ASIC rate skew (16 cases) | each lane slice's per-bin rate matches `r_k` for that lane within Poisson 3σ; aggregate `TOTAL_HITS` rate matches the sum; `OVERFLOW_COUNT = 0` | B |
| TPB5E49..TPB5E64 | D | live BOARD | channel-rate stress on ASIC {0, 7} (16 cases) | per-channel rate scales with r linearly until the ASIC channel-aggregate hits the 25 Mhit/s cap; one-channel queueing tail visible in delay PDF beyond `FRAME_INTERVAL_SHORT` (matches Phase 4 TPB069 behaviour on emulator); `OVERFLOW_COUNT = 0` | B |

**Bucket E pass aggregator**: every mode-3 async case overlays the matching mode-2 rate envelope after async-phase accounting; every mode-5 PRNG case matches the configured PRBS probability within Poisson 3σ; every onClick case advances `TOTAL_HITS` by exactly the configured multiplicity; per-ASIC skew cases show no cross-ASIC contamination; channel-rate stress cases stay below `OVERFLOW_COUNT = 0` and `DROPPED_HITS = 0` until the per-ASIC wire-cap is reached, beyond which dropped hits are counted at the MuTRiG side and the FEB-side counters stay at zero. Cross-source compare against Phase 4 emulator equivalents (TPB071, TPB072, TPB084, TPB085, TPB086, TPB087): each Phase-5 case overlays the corresponding Phase-4 case within Poisson 3σ.

### 5.9 Cross-bucket pass aggregator

| Aggregate | Pass when |
|---|---|
| Bucket A | every (ASIC, TTH) cell shows the predicted lane-slice population and rate-vs-TTH monotone, agrees with TSA RAM within 5%, `OVERFLOW_COUNT delta = 0` |
| Bucket B | every (asic_enable, channel_mask) cell exactly matches the predicted bin geometry; cross-source overlay vs Phase 4 TPB020..TPB031 within Poisson 3σ |
| Bucket C | linear delta-pulse fit slope -1, intercept 910 ± 4 cycles; cross-source overlay vs Phase 4 TPB032..TPB055 within ± 16 cycles |
| Bucket D | rate-doubling ratio holds; aggregate clip at 200 Mhit/s; cross-source overlay vs Phase 4 TPB056..TPB079 within 5% |
| Bucket E | superposed distributions match predictions; onClick advances `TOTAL_HITS` exactly; `OVERFLOW_COUNT = 0` and `DROPPED_HITS = 0` everywhere below the wire-cap |
| All buckets | `histogram_statistics_0.OVERFLOW_COUNT delta = 0` across the full Phase-5 §5 sweep; `DROPPED_HITS delta = 0` below wire-cap; `UNDERFLOW_COUNT delta = 0` for the channel buckets |

---

## 6. Failure debug ladder

Phase 5 reuses the disagreement protocol from `phase4/TEST_PLAN_BASIC.md` §"Disagreement protocol" with one substitution: the **TLM is no longer the apex** for §3 onward. The Phase-4-passed **emulator path** is the fixed reference for §3 and §4; for §5, the per-bucket cross-source check is real-MuTRiG vs Phase-4-emulator (the buckets in §5.4..§5.8 each name the Phase-4 cases they overlay against).

| Symptom | First-pass debug entry point |
|---|---|
| §2 some ASICs do not lock decoded frames | `mutrig_cfg_ctrl_0` cfglen / scratchpad word stream — confirm the 84-word block is bit-for-bit the production bitstream from `Mutrig_FEB.cpp`, then check the SPI clock domain (`i_clk_spi`) reset and the SS-N fan-out |
| §3 FEB ERROR trigger case fires (torn frame) | `mutrig_frame_deassembly` decoder error, then `feb_frame_assembly` framing logic, then the `aso_tx8b1k` clock-domain crossing |
| §3 SWB ERROR trigger case fires (code-err / disp-err) | SWB-side 8b/10b decoder, link-2 RX equalization, or the LVDS RX outclock |
| §4 bit-exact compare fails | `aso_tx8b1k` width / K-flag wiring on the lane that diverges; cross-check against the Phase-4-emulator bits at the same byte position |
| §5 Bucket A rate-vs-TTH non-monotone | TSA result-RAM vs cfg-bitstream TTH field offset (`CFG_HEADER_LENGTH + CFG_SINGLE_CH_TTH_OFFSET + CFG_SINGLE_CH_LENGTH*i`); then the per-channel TTH bit-width (`CFG_TTH_SETTING_LENGTH = 6`) |
| §5 Bucket B mask not exact | cfg-bitstream channel-TTH-to-quiet-channel mapping; then the histogram_ingress_bridge `select_post` setting — pre-tap vs post-tap |
| §5 Bucket C delta-pulse position drift | `mutrig_injector_0.header_delay` register width vs frame-boundary capture; then the pre-/post-tap routing via `histogram_ingress_bridge_0` |
| §5 Bucket D rate clipping below 200 Mhit/s | check whether the historical 135 Mhit/s knee from Phase 4 `inputs/board/phase4_emulator_20260425_*` has reappeared — if so, route to Phase 4's open item (board rate-signoff at 200 Mhit/s) |
| §5 Bucket E onClick `TOTAL_HITS` advances by != `injection_multiplicity` | check `proc_onclick_injecter` timer width vs pulse_high_cycles; then the channel-mask cfg encoding |
| Any §5 `OVERFLOW_COUNT` advance | route to Phase 4 TPBH series — Phase 5 closure is gated on TPBH001..TPBH030 PASS, so any new overflow is a regression and Phase 4 evidence is invalidated until the regression is debugged |

---

## 7. Reports and closure attestation

Each Phase-5 stage produces a structured Markdown report under `../reports/`:

| Report | Contents |
|---|---|
| `phase5_mutrig_baseline_<date>.md` | per-(ASIC, channel) known-good TTH from §2.5; the cfg-bitstream baseline word stream pointer; the `mutrig_frame_deassembly_*` lock evidence |
| `phase5_frame_format_egress_<date>.md` | §3.1 SignalTap trigger-case summary, exported segment 0..3 PNG/CSV per trigger condition, adjacent-frame counter increments, frame-interval cycle distance histogram |
| `phase5_frame_format_swb_<date>.md` | §3.2 SignalTap trigger-case summary on the SWB side, adjacent-frame counter increments, code-err/disp-err clean record |
| `phase5_emulator_vs_real_<date>.md` | §4 four-way comparison (FEB egress emulator vs real, SWB ingress emulator vs real) with the §4.3 per-row pass/fail |
| `phase5_injector_bucketA_<date>.md` | TPB5A01..TPB5A64 per-cell results |
| `phase5_injector_bucketB_<date>.md` | TPB5B01..TPB5B64 per-cell results |
| `phase5_injector_bucketC_<date>.md` | TPB5C01..TPB5C64 per-cell results |
| `phase5_injector_bucketD_<date>.md` | TPB5D01..TPB5D64 per-cell results |
| `phase5_injector_bucketE_<date>.md` | TPB5E01..TPB5E64 per-cell results |
| `phase5_closure_<date>.md` | aggregated PASS/FAIL across §2..§5, BASIC/EDGE/PROF/ERROR coverage table as `implemented_pass / 64` per bucket and aggregate `sum(implemented_pass) / 256`, list of any cross-source discrepancies with their numeric ratios, pointer to the TLM/RTL-SIM Phase-4 reference each Phase-5 case overlays against |

The reports are the sign-off artifact; Phase 5 is closed when:

- §2..§5 all PASS per their stage aggregator,
- the closure report is checked into `../reports/`,
- BASIC/EDGE/PROF/ERROR functional coverage is at least 50% aggregate, reported as implemented passing checkpoints over the 256-point requirement,
- every Phase-5 cross-source overlay is within the tolerance documented in the bucket's pass aggregator,
- no Phase-4 Closure invariant (`OVERFLOW_COUNT`, `DROPPED_HITS`, `UNDERFLOW_COUNT` deltas all zero) is violated.

---

## 8. Open items / known caveats

- **One injector instance**: the integration build instantiates a single `mutrig_injector_0` shared across the eight MuTRiG ASICs. Two-source mode-1 + mode-2 superposition is no longer a Phase-5 catalog blocker; if dual-path analog routing is later proven, it can be added as an extension case outside TPB5E01..TPB5E64.
- **SWB-side `.stp` image** lives in the SWB Quartus project (`online_sc/online/switching_pc/a10_board/`), not in this repo. Authoring and check-in of `phase5_swb_ingress.stp` is a follow-up task in `online_sc`. This plan calls out the trigger conditions and the depth/segment configuration; the actual `.stp` author and check-in is expected to land in the SWB tree before §3.2 captures are run.
- **Histogram delay key extraction**: `histogram_statistics_0.CONTROL.mode` selects which slice of the snooped data word is used as the update key. The exact bit slice for the delay key on the post-hit-stack tap is set by `histogram_statistics_0.KEY_LOC` and depends on the `feb_frame_assembly` / hit-stack output layout. The plan above assumes the slice was already pinned during Phase 4 §4.5; if Phase 5 needs a different slice (e.g. delay rather than channel), the slice is pinned per case via the `KEY_LOC` field. The `KEY_LOC` setting per case is part of the per-case configuration; this plan does not enumerate the bit positions because they are stable across Phase 4 → Phase 5.
- **Cfg bitstream packing**: the production cfg-bitstream packing (LSB-first vs MSB-first per word, padding policy at the 2662-bit boundary) is defined in `Mutrig_FEB.cpp`. Phase-5 §2 reuses that packing exactly; this plan does not redefine it.
- **TSA range and stride**: the controller's TSA increments TTH 0..63 (6-bit field). Bucket A samples the 8 representative steps `{16, 24, 32, 40, 48, 52, 56, 60}` to keep the bucket at 64 cases. A finer TTH grid is captured implicitly inside the TSA result-RAM during §2.5 and is reported there; Bucket A is the histogram-side observation cross-check at 8 representative TTH points per ASIC.
